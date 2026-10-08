import 'package:equatable/equatable.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/result.dart';
import '../entities/lead.dart';
import '../entities/rag_answer.dart';
import '../repositories/embedding_repository.dart';
import '../repositories/llm_repository.dart';
import '../repositories/vector_store_repository.dart';
import '../services/rag_prompt_builder.dart';

class QueryRagParams extends Equatable {
  const QueryRagParams({
    required this.question,
    required this.activeSources,
    this.topK = RagDefaults.topK,
    this.minSimilarity = RagDefaults.minSimilarity,
  });

  final String question;
  final Set<LeadSource> activeSources;
  final int topK;
  final double minSimilarity;

  @override
  List<Object?> get props => [question, activeSources, topK, minSimilarity];
}

/// Pipeline RAG de prospection :
/// question → embedding → recherche de similarité → filtrage → prompt
/// augmenté → génération LLM.
///
/// Ne lève jamais d'exception métier : chaque échec est remonté en [Err] pour
/// que la présentation affiche un état d'erreur précis.
class QueryRagUseCase {
  QueryRagUseCase({
    required EmbeddingRepository embeddingRepository,
    required VectorStoreRepository vectorStoreRepository,
    required LlmRepository llmRepository,
    RagPromptBuilder promptBuilder = const RagPromptBuilder(),
    DateTime Function()? clock,
  })  : _embeddingRepository = embeddingRepository,
        _vectorStoreRepository = vectorStoreRepository,
        _llmRepository = llmRepository,
        _promptBuilder = promptBuilder,
        _clock = clock ?? DateTime.now;

  final EmbeddingRepository _embeddingRepository;
  final VectorStoreRepository _vectorStoreRepository;
  final LlmRepository _llmRepository;
  final RagPromptBuilder _promptBuilder;

  /// Injectable pour rendre le filtrage des appels d'offres expirés
  /// déterministe dans les tests.
  final DateTime Function() _clock;

  static const String _noMatchAnswer =
      'Aucune opportunité suffisamment pertinente n\'a été trouvée dans les '
      'sources actives. Essayez d\'élargir la zone géographique ou le secteur, '
      'd\'activer d\'autres sources, ou lancez une synchronisation pour '
      'récupérer les dernières publications.';

  Future<Result<RagAnswer>> call(QueryRagParams params) async {
    final question = params.question.trim();

    final validationFailure = _validate(question, params);
    if (validationFailure != null) return Err(validationFailure);

    // 1. Vectorisation de la question.
    final List<double> queryVector;
    switch (await _embeddingRepository.embedQuery(question)) {
      case Ok(:final value):
        queryVector = value;
      case Err(:final failure):
        return Err(failure);
    }

    // 2. Recherche de similarité, filtrée par source côté vector store.
    final List<ScoredLead> candidates;
    switch (await _vectorStoreRepository.searchSimilar(
      vector: queryVector,
      sources: params.activeSources,
      topK: params.topK,
    )) {
      case Ok(:final value):
        candidates = value;
      case Err(:final failure):
        return Err(failure);
    }

    // 3. Filtrage métier. Le filtre de source est ré-appliqué par défense en
    //    profondeur : un index mal configuré ne doit pas exposer une source
    //    que l'utilisateur a désactivée.
    final now = _clock();
    final relevantLeads = candidates
        .where((c) => c.score >= params.minSimilarity)
        .where((c) => params.activeSources.contains(c.lead.source))
        .where((c) => !c.lead.isExpiredAt(now))
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    // Sans contexte, le LLM n'est pas appelé : il produirait des
    // « opportunités » hallucinées, et c'est un appel facturé inutile.
    if (relevantLeads.isEmpty) {
      return Ok(
        RagAnswer(
          answer: _noMatchAnswer,
          sources: const <ScoredLead>[],
          isGrounded: false,
          generatedAt: now,
        ),
      );
    }

    // 4. Construction du prompt augmenté.
    final prompt = _promptBuilder.build(
      question: question,
      leads: relevantLeads,
      now: now,
    );

    // 5. Génération de la réponse finale.
    switch (await _llmRepository.generate(
      systemInstruction: prompt.systemInstruction,
      userPrompt: prompt.userPrompt,
    )) {
      case Ok(:final value):
        final answer = value.trim();
        if (answer.isEmpty) {
          return const Err(ServerFailure('Le modèle a renvoyé une réponse vide. Réessayez.'));
        }
        return Ok(
          RagAnswer(
            answer: answer,
            sources: prompt.includedLeads,
            isGrounded: true,
            generatedAt: _clock(),
          ),
        );
      case Err(:final failure):
        return Err(failure);
    }
  }

  Failure? _validate(String question, QueryRagParams params) {
    if (question.isEmpty) {
      return const ValidationFailure('Veuillez saisir une question.');
    }
    if (question.length > RagDefaults.maxQuestionLength) {
      return const ValidationFailure(
        'Question trop longue (${RagDefaults.maxQuestionLength} caractères maximum).',
      );
    }
    if (params.activeSources.isEmpty) {
      return const ValidationFailure(
        'Aucune source active. Activez au moins une source dans l\'écran Sources.',
      );
    }
    if (params.topK <= 0 || params.minSimilarity < 0 || params.minSimilarity > 1) {
      return const ValidationFailure('Paramètres de recherche invalides.');
    }
    return null;
  }
}

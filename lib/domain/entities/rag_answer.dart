import 'package:equatable/equatable.dart';

import 'lead.dart';

class RagAnswer extends Equatable {
  const RagAnswer({
    required this.answer,
    required this.sources,
    required this.isGrounded,
    required this.generatedAt,
  });

  final String answer;

  /// Uniquement les documents réellement injectés dans le prompt : afficher
  /// des sources tronquées par la limite de contexte induirait l'utilisateur
  /// en erreur sur ce qui a fondé la réponse.
  final List<ScoredLead> sources;

  /// `false` quand aucune donnée pertinente n'a été trouvée et que la réponse
  /// est un message système, pas une synthèse du LLM.
  final bool isGrounded;
  final DateTime generatedAt;

  @override
  List<Object?> get props => [answer, sources, isGrounded, generatedAt];
}

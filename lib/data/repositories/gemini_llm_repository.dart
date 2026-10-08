import '../../core/errors/exceptions.dart';
import '../../core/network/json_http_client.dart';
import '../../core/network/result_guard.dart';
import '../../core/utils/result.dart';
import '../../domain/repositories/llm_repository.dart';

/// Génération via l'API Gemini (`generateContent`).
class GeminiLlmRepository implements LlmRepository {
  const GeminiLlmRepository({
    required JsonHttpClient client,
    required String apiKey,
    required String model,
    this.fallbackModel = 'gemini-flash-latest',
  })  : _client = client,
        _apiKey = apiKey,
        _model = model;

  final JsonHttpClient _client;
  final String _apiKey;
  final String _model;

  /// Utilisé quand le modèle principal est saturé (503) ou ne répond pas à
  /// temps : les pics de charge Gemini sont fréquents et passagers, et
  /// l'alias `latest` pointe vers une autre capacité de service.
  final String? fallbackModel;

  @override
  Future<Result<String>> generate({
    required String systemInstruction,
    required String userPrompt,
  }) {
    return guardResult('Gemini', () async {
      final fallback = fallbackModel;
      try {
        return await _generateWith(_model, systemInstruction, userPrompt);
      } on AppException catch (error) {
        if (fallback == null || fallback == _model || !_isTransient(error)) rethrow;
        return _generateWith(fallback, systemInstruction, userPrompt);
      }
    });
  }

  static bool _isTransient(AppException error) => switch (error) {
        NetworkException() => true,
        ServerException(:final statusCode) => statusCode == 500 || statusCode == 503,
        _ => false,
      };

  Future<String> _generateWith(
    String model,
    String systemInstruction,
    String userPrompt,
  ) async {
    final body = await _client.postJson(
      Uri.https(
        'generativelanguage.googleapis.com',
        '/v1beta/models/$model:generateContent',
      ),
      // En en-tête plutôt qu'en paramètre `?key=` : l'URL finit dans les
      // journaux des proxys et des outils de debug réseau.
      headers: {'x-goog-api-key': _apiKey},
      body: {
        'systemInstruction': {
          'parts': [
            {'text': systemInstruction},
          ],
        },
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': userPrompt},
            ],
          },
        ],
        // Température basse : on attend une synthèse fidèle des documents,
        // pas de la créativité.
        'generationConfig': {'temperature': 0.2},
      },
    );

    if (body is! Map<String, dynamic>) {
      throw const ParsingException('Réponse Gemini inattendue.');
    }

    final feedback = body['promptFeedback'];
    if (feedback is Map<String, dynamic> && feedback['blockReason'] != null) {
      throw const ServerException('Requête bloquée par les filtres de sécurité Gemini.');
    }

    final candidates = body['candidates'];
    final first = candidates is List<Object?> && candidates.isNotEmpty ? candidates.first : null;
    if (first is! Map<String, dynamic>) {
      throw const ParsingException('Aucune réponse candidate renvoyée par Gemini.');
    }

    final content = first['content'];
    final parts = content is Map<String, dynamic> ? content['parts'] : null;
    final text = (parts is List<Object?> ? parts : const <Object?>[])
        .whereType<Map<String, dynamic>>()
        // Les modèles « thinking » peuvent renvoyer leur raisonnement dans
        // des parts marquées `thought` : il ne doit pas être affiché.
        .where((part) => part['thought'] != true)
        .map((part) => part['text'])
        .whereType<String>()
        .join();

    // MAX_TOKENS renvoie un texte tronqué mais exploitable ; les autres
    // motifs (SAFETY, RECITATION…) sans texte sont un échec.
    if (text.trim().isEmpty) {
      throw ServerException('Réponse Gemini vide (${first['finishReason'] ?? 'motif inconnu'}).');
    }
    return text;
  }
}

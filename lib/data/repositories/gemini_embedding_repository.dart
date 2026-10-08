import '../../core/constants/app_constants.dart';
import '../../core/errors/exceptions.dart';
import '../../core/network/json_http_client.dart';
import '../../core/network/result_guard.dart';
import '../../core/utils/result.dart';
import '../../domain/repositories/embedding_repository.dart';

/// Embeddings de requête via l'API Gemini (`embedContent`).
///
/// Le modèle et la dimension doivent être ceux de l'Edge Function
/// `sync-leads`, qui vectorise les documents.
class GeminiEmbeddingRepository implements EmbeddingRepository {
  const GeminiEmbeddingRepository({
    required JsonHttpClient client,
    required String apiKey,
    required String model,
    int dimensions = EmbeddingDefaults.dimensions,
  })  : _client = client,
        _apiKey = apiKey,
        _model = model,
        _dimensions = dimensions;

  final JsonHttpClient _client;
  final String _apiKey;
  final String _model;
  final int _dimensions;

  @override
  Future<Result<List<double>>> embedQuery(String text) {
    return guardResult('Gemini', () async {
      final body = await _client.postJson(
        Uri.https(
          'generativelanguage.googleapis.com',
          '/v1beta/models/$_model:embedContent',
        ),
        // En en-tête plutôt qu'en paramètre `?key=` : l'URL finit dans les
        // journaux des proxys et des outils de debug réseau.
        headers: {'x-goog-api-key': _apiKey},
        body: {
          'content': {
            'parts': [
              {'text': text},
            ],
          },
          // Pendant de RETRIEVAL_DOCUMENT utilisé à l'ingestion.
          'taskType': 'RETRIEVAL_QUERY',
          'outputDimensionality': _dimensions,
        },
      );

      final embedding = body is Map<String, dynamic> ? body['embedding'] : null;
      final values = embedding is Map<String, dynamic> ? embedding['values'] : null;
      if (values is! List<Object?>) {
        throw const ParsingException('Embedding absent de la réponse Gemini.');
      }

      final vector = values.whereType<num>().map((v) => v.toDouble()).toList();
      // Une dimension différente de celle de l'index ferait échouer la RPC
      // avec une erreur SQL opaque : on échoue ici avec un message clair.
      if (vector.length != _dimensions) {
        throw ConfigurationException(
          'Embedding de dimension ${vector.length}, $_dimensions attendue.',
        );
      }
      return vector;
    });
  }
}

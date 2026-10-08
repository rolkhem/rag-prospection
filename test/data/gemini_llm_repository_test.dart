import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rag_prospection/core/errors/failures.dart';
import 'package:rag_prospection/core/network/json_http_client.dart';
import 'package:rag_prospection/core/utils/result.dart';
import 'package:rag_prospection/data/repositories/gemini_llm_repository.dart';

GeminiLlmRepository _repository(MockClientHandler handler) => GeminiLlmRepository(
      client: JsonHttpClient(client: MockClient(handler)),
      apiKey: 'test-key',
      model: 'gemini-2.5-flash',
    );

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json'},
    );

void main() {
  test('envoie la clé en en-tête et ignore les parts de raisonnement', () async {
    late http.Request sent;
    final repository = _repository((request) async {
      sent = request;
      return _json({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': 'raisonnement interne', 'thought': true},
                {'text': 'Opportunité forte [1].'},
              ],
            },
            'finishReason': 'STOP',
          },
        ],
      });
    });

    final result = await repository.generate(systemInstruction: 'sys', userPrompt: 'question');

    expect((result as Ok<String>).value, 'Opportunité forte [1].');
    expect(sent.headers['x-goog-api-key'], 'test-key');
    expect(sent.url.queryParameters, isNot(contains('key')));
    final body = jsonDecode(sent.body) as Map<String, dynamic>;
    expect(body['systemInstruction'], {
      'parts': [
        {'text': 'sys'},
      ],
    });
  });

  test('traduit un prompt bloqué en échec serveur', () async {
    final repository = _repository(
      (_) async => _json({
        'promptFeedback': {'blockReason': 'SAFETY'},
      }),
    );

    final result = await repository.generate(systemInstruction: 's', userPrompt: 'u');

    expect((result as Err<String>).failure, isA<ServerFailure>());
  });

  test('traduit un 403 en erreur de configuration', () async {
    final repository = _repository((_) async => _json({'error': 'denied'}, 403));

    final result = await repository.generate(systemInstruction: 's', userPrompt: 'u');

    expect((result as Err<String>).failure, isA<ConfigurationFailure>());
  });
}

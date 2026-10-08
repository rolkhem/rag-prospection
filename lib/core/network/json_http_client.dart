import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../constants/app_constants.dart';
import '../errors/exceptions.dart';

/// Client JSON minimal partagé par les repositories de la couche `data`.
///
/// Ne lève que des [AppException] : chaque repository n'a ainsi qu'une seule
/// famille d'erreurs à convertir en `Failure` (voir `guardResult`).
class JsonHttpClient {
  JsonHttpClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<Object?> postJson(
    Uri uri, {
    required Object? body,
    Map<String, String> headers = const {},
    Duration timeout = NetworkDefaults.requestTimeout,
  }) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json',
              ...headers,
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw NetworkException('Délai dépassé pour ${uri.host}.');
    } on SocketException catch (error) {
      throw NetworkException('Hôte injoignable ${uri.host} : ${error.message}');
    } on http.ClientException catch (error) {
      throw NetworkException('Échec de la requête vers ${uri.host} : ${error.message}');
    }

    // `response.body` décode en latin-1 quand l'en-tête omet le charset :
    // les accents des avis BOAMP seraient corrompus.
    final text = utf8.decode(response.bodyBytes, allowMalformed: true);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ServerException(
        '${uri.host} a répondu ${response.statusCode} : ${_truncate(text, 300)}',
        statusCode: response.statusCode,
      );
    }

    if (text.trim().isEmpty) return null;
    try {
      return jsonDecode(text);
    } on FormatException {
      throw ParsingException('Réponse non JSON de ${uri.host}.');
    }
  }

  void close() => _client.close();

  static String _truncate(String text, int max) =>
      text.length <= max ? text : '${text.substring(0, max)}…';
}

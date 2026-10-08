import 'package:flutter/foundation.dart';

import '../errors/exceptions.dart';
import '../errors/failures.dart';
import '../utils/result.dart';

/// Exécute [body] et convertit toute [AppException] en [Failure] lisible.
///
/// [service] apparaît dans les messages utilisateur (« Gemini », « Supabase »)
/// pour que le commercial sache quel maillon a échoué. Le détail technique
/// n'est que journalisé : il peut contenir des fragments de réponse serveur.
Future<Result<T>> guardResult<T>(String service, Future<T> Function() body) async {
  try {
    return Ok(await body());
  } on AppException catch (error) {
    debugPrint('[$service] $error');
    return Err(_toFailure(service, error));
  }
}

Failure _toFailure(String service, AppException error) => switch (error) {
      NetworkException() => const NetworkFailure(),
      ParsingException() => ParsingFailure('Réponse illisible de $service.'),
      ConfigurationException(:final message) => ConfigurationFailure(message),
      ServerException(:final statusCode) => switch (statusCode) {
          400 => ServerFailure('Requête refusée par $service.', statusCode: statusCode),
          401 || 403 => ConfigurationFailure(
              'Accès refusé par $service : vérifiez la clé API dans le fichier .env.',
            ),
          404 => ConfigurationFailure(
              'Ressource $service introuvable : la migration ou la fonction est-elle déployée ?',
            ),
          429 => ServerFailure(
              'Quota $service atteint. Patientez quelques instants avant de réessayer.',
              statusCode: statusCode,
            ),
          _ => ServerFailure(
              '$service est momentanément indisponible. Réessayez.',
              statusCode: statusCode,
            ),
        },
    };

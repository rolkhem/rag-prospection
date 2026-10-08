/// Exceptions techniques levées par la couche `data` uniquement.
///
/// Elles ne doivent jamais franchir la frontière des repositories : chaque
/// implémentation les convertit en `Failure` encapsulé dans un `Result`.
sealed class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

final class ServerException extends AppException {
  const ServerException(super.message, {this.statusCode});

  final int? statusCode;
}

final class NetworkException extends AppException {
  const NetworkException(super.message);
}

final class ParsingException extends AppException {
  const ParsingException(super.message);
}

final class ConfigurationException extends AppException {
  const ConfigurationException(super.message);
}

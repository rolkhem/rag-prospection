import 'package:equatable/equatable.dart';

/// Échecs métier exposés au domaine et à la présentation.
///
/// `sealed` force la présentation à traiter chaque cas de manière exhaustive
/// via `switch`, ce qui évite qu'un nouveau type d'échec passe inaperçu.
/// Les messages sont rédigés pour être affichés tels quels à l'utilisateur.
sealed class Failure extends Equatable {
  const Failure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

final class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

final class NetworkFailure extends Failure {
  const NetworkFailure([
    super.message = 'Connexion réseau indisponible. Vérifiez votre accès internet.',
  ]);
}

final class ServerFailure extends Failure {
  const ServerFailure(super.message, {this.statusCode});

  final int? statusCode;

  @override
  List<Object?> get props => [message, statusCode];
}

final class ConfigurationFailure extends Failure {
  const ConfigurationFailure(super.message);
}

final class ParsingFailure extends Failure {
  const ParsingFailure([
    super.message = 'Réponse du serveur illisible.',
  ]);
}

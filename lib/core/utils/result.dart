import '../errors/failures.dart';

/// Résultat explicite d'une opération faillible.
///
/// Préféré aux exceptions pour les frontières domaine/présentation : la
/// signature rend l'échec visible et le `switch` exhaustif oblige l'appelant
/// à le traiter, sans dépendance externe (dartz, fpdart).
sealed class Result<T> {
  const Result();
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.failure);

  final Failure failure;
}

import 'package:equatable/equatable.dart';

sealed class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object?> get props => [];
}

final class ChatQuestionSubmitted extends ChatEvent {
  const ChatQuestionSubmitted(this.question);

  final String question;

  @override
  List<Object?> get props => [question];
}

/// Relance la dernière question en échec sans dupliquer la bulle utilisateur.
final class ChatRetryRequested extends ChatEvent {
  const ChatRetryRequested();
}

final class ChatHistoryCleared extends ChatEvent {
  const ChatHistoryCleared();
}

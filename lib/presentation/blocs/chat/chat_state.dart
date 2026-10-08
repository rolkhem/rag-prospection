import 'package:equatable/equatable.dart';

import '../../../domain/entities/chat_message.dart';

enum ChatStatus { initial, loading, success, failure }

/// État unique avec statut plutôt qu'une classe par état : l'historique des
/// messages doit survivre à chaque transition Loading → Success/Error, ce qui
/// obligerait sinon à le recopier dans chaque sous-classe.
class ChatState extends Equatable {
  const ChatState({
    this.status = ChatStatus.initial,
    this.messages = const <ChatMessage>[],
    this.errorMessage,
    this.pendingQuestion,
  });

  final ChatStatus status;
  final List<ChatMessage> messages;
  final String? errorMessage;

  /// Question en cours ou en échec, conservée pour permettre le réessai.
  final String? pendingQuestion;

  bool get isLoading => status == ChatStatus.loading;
  bool get hasError => status == ChatStatus.failure && errorMessage != null;

  /// Les getters nullables permettent de distinguer « ne pas modifier »
  /// (paramètre omis) de « remettre à null » (`() => null`).
  ChatState copyWith({
    ChatStatus? status,
    List<ChatMessage>? messages,
    String? Function()? errorMessage,
    String? Function()? pendingQuestion,
  }) {
    return ChatState(
      status: status ?? this.status,
      messages: messages ?? this.messages,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      pendingQuestion: pendingQuestion != null ? pendingQuestion() : this.pendingQuestion,
    );
  }

  @override
  List<Object?> get props => [status, messages, errorMessage, pendingQuestion];
}

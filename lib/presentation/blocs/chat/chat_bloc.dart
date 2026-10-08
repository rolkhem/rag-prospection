import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/result.dart';
import '../../../domain/entities/chat_message.dart';
import '../../../domain/repositories/source_preferences_repository.dart';
import '../../../domain/usecases/query_rag_usecase.dart';
import 'chat_event.dart';
import 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  ChatBloc({
    required QueryRagUseCase queryRag,
    required SourcePreferencesRepository sourcePreferences,
    Uuid uuid = const Uuid(),
  })  : _queryRag = queryRag,
        _sourcePreferences = sourcePreferences,
        _uuid = uuid,
        super(const ChatState()) {
    // `droppable` ignore les envois pendant une requête en cours : un double
    // tap ne doit pas déclencher deux pipelines RAG facturés en parallèle.
    on<ChatQuestionSubmitted>(_onQuestionSubmitted, transformer: droppable());
    on<ChatRetryRequested>(_onRetryRequested, transformer: droppable());
    on<ChatHistoryCleared>(_onHistoryCleared);
  }

  final QueryRagUseCase _queryRag;
  final SourcePreferencesRepository _sourcePreferences;
  final Uuid _uuid;

  Future<void> _onQuestionSubmitted(
    ChatQuestionSubmitted event,
    Emitter<ChatState> emit,
  ) async {
    final question = event.question.trim();
    if (question.isEmpty || state.isLoading) return;

    final userMessage = ChatMessage(
      id: _uuid.v4(),
      role: ChatRole.user,
      content: question,
      createdAt: DateTime.now(),
    );

    emit(
      state.copyWith(
        status: ChatStatus.loading,
        messages: [...state.messages, userMessage],
        errorMessage: () => null,
        pendingQuestion: () => question,
      ),
    );

    await _runQuery(question, emit);
  }

  Future<void> _onRetryRequested(
    ChatRetryRequested event,
    Emitter<ChatState> emit,
  ) async {
    final question = state.pendingQuestion;
    if (question == null || state.isLoading) return;

    emit(state.copyWith(status: ChatStatus.loading, errorMessage: () => null));
    await _runQuery(question, emit);
  }

  Future<void> _runQuery(String question, Emitter<ChatState> emit) async {
    // Lu à chaque requête plutôt que mis en cache : l'utilisateur a pu
    // modifier ses sources dans l'écran dédié entre deux questions.
    final activeSources = await _sourcePreferences.getEnabledSources();

    final result = await _queryRag(
      QueryRagParams(question: question, activeSources: activeSources),
    );

    switch (result) {
      case Ok(value: final answer):
        final reply = ChatMessage(
          id: _uuid.v4(),
          role: ChatRole.assistant,
          content: answer.answer,
          createdAt: answer.generatedAt,
          sources: answer.sources,
          isGrounded: answer.isGrounded,
        );
        emit(
          state.copyWith(
            status: ChatStatus.success,
            messages: [...state.messages, reply],
            pendingQuestion: () => null,
          ),
        );
      case Err(:final failure):
        emit(
          state.copyWith(
            status: ChatStatus.failure,
            errorMessage: () => failure.message,
          ),
        );
    }
  }

  void _onHistoryCleared(ChatHistoryCleared event, Emitter<ChatState> emit) {
    // Effacer pendant une requête ferait atterrir la réponse dans un fil vide.
    if (state.isLoading) return;
    emit(const ChatState());
  }
}

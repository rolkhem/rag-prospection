import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../blocs/chat/chat_bloc.dart';
import '../blocs/chat/chat_event.dart';
import '../blocs/chat/chat_state.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/empty_chat_view.dart';
import '../widgets/error_banner.dart';
import '../widgets/message_bubble.dart';
import '../widgets/typing_indicator.dart';

/// Écran A — Dashboard & Chat RAG.
///
/// Le [ChatBloc] est fourni par un ancêtre (voir `main.dart`) afin que
/// l'historique survive à la navigation vers l'écran Sources.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _submit([String? preset]) {
    final question = (preset ?? _inputController.text).trim();
    if (question.isEmpty) return;
    context.read<ChatBloc>().add(ChatQuestionSubmitted(question));
    _inputController.clear();
  }

  /// Exécuté après le frame suivant : `maxScrollExtent` n'intègre le nouveau
  /// message qu'une fois celui-ci mis en page.
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const _ChatAppBar(),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: BlocConsumer<ChatBloc, ChatState>(
                listenWhen: (previous, current) =>
                    previous.messages.length != current.messages.length ||
                    previous.status != current.status,
                listener: (_, __) => _scrollToBottom(),
                buildWhen: (previous, current) =>
                    previous.messages != current.messages ||
                    previous.isLoading != current.isLoading,
                builder: (context, state) {
                  if (state.messages.isEmpty && !state.isLoading) {
                    return EmptyChatView(onSuggestionSelected: _submit);
                  }
                  return _MessageList(
                    state: state,
                    scrollController: _scrollController,
                  );
                },
              ),
            ),
            BlocBuilder<ChatBloc, ChatState>(
              buildWhen: (previous, current) =>
                  previous.hasError != current.hasError ||
                  previous.errorMessage != current.errorMessage,
              builder: (context, state) {
                final message = state.errorMessage;
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: state.hasError && message != null
                      ? ErrorBanner(
                          key: const ValueKey('chat_error_banner'),
                          message: message,
                          onRetry: () => context.read<ChatBloc>().add(const ChatRetryRequested()),
                        )
                      : const SizedBox.shrink(),
                );
              },
            ),
            BlocSelector<ChatBloc, ChatState, bool>(
              selector: (state) => state.isLoading,
              builder: (context, isLoading) => ChatInputBar(
                controller: _inputController,
                isLoading: isLoading,
                onSubmit: _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({required this.state, required this.scrollController});

  final ChatState state;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final messages = state.messages;

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: messages.length + (state.isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= messages.length) return const TypingIndicator();
        final message = messages[index];
        return MessageBubble(key: ValueKey(message.id), message: message);
      },
    );
  }
}

class _ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ChatAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 4);

  Future<void> _confirmClear(BuildContext context) async {
    final bloc = context.read<ChatBloc>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('Effacer la conversation ?'),
        content: const Text('L\'historique et les sources affichées seront supprimés.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Effacer'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) bloc.add(const ChatHistoryCleared());
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      titleSpacing: 16,
      title: const Row(
        children: [
          _AppBarLogo(),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Prospection IA',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              Text(
                'BOAMP · TED · DECP · LinkedIn · X',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          key: const Key('open_sources_button'),
          tooltip: 'Sources & filtres',
          icon: const Icon(Icons.tune_rounded),
          onPressed: () => Navigator.of(context).pushNamed(AppRoutes.sources),
        ),
        BlocSelector<ChatBloc, ChatState, bool>(
          selector: (state) => state.messages.isNotEmpty && !state.isLoading,
          builder: (context, canClear) => IconButton(
            key: const Key('clear_chat_button'),
            tooltip: 'Effacer la conversation',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: canClear ? () => _confirmClear(context) : null,
          ),
        ),
        const SizedBox(width: 4),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(4),
        child: _LoadingProgressBar(),
      ),
    );
  }
}

class _AppBarLogo extends StatelessWidget {
  const _AppBarLogo();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(gradient: AppColors.userBubble, shape: BoxShape.circle),
      child: Padding(
        padding: EdgeInsets.all(7),
        child: Icon(Icons.radar_rounded, size: 20, color: Colors.white),
      ),
    );
  }
}

/// Barre de progression fine sous l'AppBar : feedback global de chargement
/// visible même quand l'indicateur de saisie est hors écran.
class _LoadingProgressBar extends StatelessWidget {
  const _LoadingProgressBar();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ChatBloc, ChatState, bool>(
      selector: (state) => state.isLoading,
      builder: (context, isLoading) => SizedBox(
        height: 4,
        child: isLoading
            ? const LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                color: AppColors.accent,
                minHeight: 2,
              )
            : const Divider(height: 1, thickness: 1),
      ),
    );
  }
}

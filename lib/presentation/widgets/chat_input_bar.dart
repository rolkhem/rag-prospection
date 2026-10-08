import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';

class ChatInputBar extends StatelessWidget {
  const ChatInputBar({
    super.key,
    required this.controller,
    required this.isLoading,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                key: const Key('chat_input_field'),
                controller: controller,
                enabled: !isLoading,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                textCapitalization: TextCapitalization.sentences,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(RagDefaults.maxQuestionLength),
                ],
                onSubmitted: (_) => onSubmit(),
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14.5),
                decoration: const InputDecoration(
                  hintText: 'Ex : PME cherchant un prestataire cybersécurité en Île-de-France',
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Écoute le contrôleur directement pour activer le bouton à la
            // frappe sans reconstruire tout l'écran via le BLoC.
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                final canSend = !isLoading && value.text.trim().isNotEmpty;
                return _SendButton(enabled: canSend, onPressed: onSubmit);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        gradient: enabled ? AppColors.userBubble : null,
        color: enabled ? null : AppColors.surfaceElevated,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        key: const Key('chat_send_button'),
        tooltip: 'Envoyer',
        onPressed: enabled ? onPressed : null,
        icon: Icon(
          Icons.arrow_upward_rounded,
          color: enabled ? Colors.white : AppColors.textMuted,
        ),
      ),
    );
  }
}

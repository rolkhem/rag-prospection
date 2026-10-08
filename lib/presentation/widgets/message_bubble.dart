import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/lead.dart';
import 'lead_source_card.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final maxWidth = MediaQuery.sizeOf(context).width * 0.84;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: isUser
                ? _UserBubble(text: message.content)
                : _AssistantBubble(text: message.content, isGrounded: message.isGrounded),
          ),
          if (!isUser && message.sources.isNotEmpty) _SourcesCarousel(sources: message.sources),
        ],
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: AppColors.userBubble,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.4),
        ),
      ),
    );
  }
}

class _AssistantBubble extends StatelessWidget {
  const _AssistantBubble({required this.text, required this.isGrounded});

  final String text;
  final bool isGrounded;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        border: Border.all(color: isGrounded ? AppColors.border : AppColors.warning.withValues(alpha: 0.4)),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(18),
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isGrounded ? Icons.auto_awesome_rounded : Icons.search_off_rounded,
                size: 14,
                color: isGrounded ? AppColors.accent : AppColors.warning,
              ),
              const SizedBox(width: 6),
              Text(
                isGrounded ? 'Analyse IA' : 'Aucune donnée pertinente',
                style: TextStyle(
                  color: isGrounded ? AppColors.accent : AppColors.warning,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Gemini répond en Markdown (titres, gras, listes) : affiché brut,
          // le texte était truffé de `###` et `**`. Sélectionnable car les
          // commerciaux copient souvent un extrait vers leur CRM ou un e-mail.
          MarkdownBody(
            data: text,
            selectable: true,
            softLineBreak: true,
            styleSheet: _markdownStyle(context),
            // Pas d'images distantes : une URL injectée dans une source
            // scrapée déclencherait sinon une requête réseau arbitraire.
            imageBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

MarkdownStyleSheet _markdownStyle(BuildContext context) {
  const body = TextStyle(color: AppColors.textPrimary, fontSize: 14.5, height: 1.5);
  const heading = TextStyle(
    color: AppColors.textPrimary,
    fontWeight: FontWeight.w700,
    height: 1.35,
  );

  return MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
    p: body,
    listBullet: body,
    strong: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
    em: const TextStyle(fontStyle: FontStyle.italic),
    // Titres volontairement modestes : la bulle est étroite et les réponses
    // contiennent un titre par opportunité.
    h1: heading.copyWith(fontSize: 17),
    h2: heading.copyWith(fontSize: 16),
    h3: heading.copyWith(fontSize: 15, color: AppColors.accent),
    h4: heading.copyWith(fontSize: 14.5),
    blockSpacing: 10,
    listIndent: 20,
    horizontalRuleDecoration: const BoxDecoration(
      border: Border(top: BorderSide(color: AppColors.border)),
    ),
    code: const TextStyle(
      color: AppColors.accent,
      backgroundColor: AppColors.background,
      fontFamily: 'monospace',
      fontSize: 13,
    ),
    blockquoteDecoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(8),
      border: const Border(left: BorderSide(color: AppColors.primary, width: 3)),
    ),
  );
}

class _SourcesCarousel extends StatelessWidget {
  const _SourcesCarousel({required this.sources});

  final List<ScoredLead> sources;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 6, left: 2),
          child: Text(
            '${sources.length} source${sources.length > 1 ? 's' : ''} utilisée${sources.length > 1 ? 's' : ''}',
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: sources.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) => LeadSourceCard(
              key: ValueKey(sources[index].lead.id),
              scoredLead: sources[index],
              reference: index + 1,
            ),
          ),
        ),
      ],
    );
  }
}

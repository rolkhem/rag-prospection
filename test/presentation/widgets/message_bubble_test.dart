import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rag_prospection/core/theme/app_theme.dart';
import 'package:rag_prospection/domain/entities/chat_message.dart';
import 'package:rag_prospection/presentation/widgets/message_bubble.dart';

void main() {
  testWidgets('rend le Markdown de la réponse au lieu des balises brutes', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: MessageBubble(
            message: ChatMessage(
              id: '1',
              role: ChatRole.assistant,
              content: '### 1. Audit SI — Mairie de Lyon [1]\n\n* **Échéance :** 2026-11-16',
              createdAt: DateTime(2026, 10, 8),
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('1. Audit SI', findRichText: true), findsOneWidget);
    expect(find.textContaining('###', findRichText: true), findsNothing);
    expect(find.textContaining('**', findRichText: true), findsNothing);
  });
}

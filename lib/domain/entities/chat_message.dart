import 'package:equatable/equatable.dart';

import 'lead.dart';

enum ChatRole { user, assistant }

class ChatMessage extends Equatable {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.sources = const <ScoredLead>[],
    this.isGrounded = true,
  });

  final String id;
  final ChatRole role;
  final String content;
  final DateTime createdAt;
  final List<ScoredLead> sources;
  final bool isGrounded;

  bool get isUser => role == ChatRole.user;

  @override
  List<Object?> get props => [id, role, content, createdAt, sources, isGrounded];
}

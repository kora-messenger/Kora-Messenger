/// Role of a message in an AI conversation.
enum MessageRole { user, assistant, system }

/// A message in a Kora AI conversation.
class ConversationMessage {
  final String id;
  final String conversationId;
  final MessageRole role;
  final String content;
  final DateTime createdAt;
  final String? attachmentType;
  final String? attachmentPreview;

  ConversationMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.createdAt,
    this.attachmentType,
    this.attachmentPreview,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'conversationId': conversationId,
    'role': role.name,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
    'attachmentType': attachmentType,
    'attachmentPreview': attachmentPreview,
  };

  factory ConversationMessage.fromJson(Map<String, dynamic> json) => ConversationMessage(
    id: json['id'] as String,
    conversationId: json['conversationId'] as String,
    role: MessageRole.values.firstWhere((r) => r.name == json['role'], orElse: () => MessageRole.user),
    content: json['content'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    attachmentType: json['attachmentType'] as String?,
    attachmentPreview: json['attachmentPreview'] as String?,
  );
}

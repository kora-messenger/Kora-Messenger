/// Response from AI operations.
class AIResponse {
  final bool success;
  final String content;
  final String? conversationId;
  final String? messageId;
  final String? error;
  final int? tokensUsed;
  final String? model;
  final int? remainingUsage;

  AIResponse({
    required this.success,
    required this.content,
    this.conversationId,
    this.messageId,
    this.error,
    this.tokensUsed,
    this.model,
    this.remainingUsage,
  });

  factory AIResponse.fromJson(Map<String, dynamic> json) => AIResponse(
    success: json['success'] as bool? ?? false,
    content: json['reply'] as String? ?? json['content'] as String? ?? '',
    conversationId: json['conversationId'] as String?,
    messageId: json['messageId'] as String?,
    error: json['error'] as String?,
    tokensUsed: json['usage']?['total_tokens'] as int?,
    model: json['model'] as String?,
    remainingUsage: json['remaining'] as int?,
  );
}

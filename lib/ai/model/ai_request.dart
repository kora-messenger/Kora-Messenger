/// Request model for AI operations.
class AIRequest {
  final String conversationId;
  final String message;
  final List<Map<String, dynamic>>? history;
  final List<AIAttachment>? attachments;
  final String? userId;
  final String? userEmail;
  final String feature; // 'conversation', 'writing', 'reply_suggestions', etc.
  final Map<String, dynamic>? metadata;
  final bool stream;

  AIRequest({
    required this.conversationId,
    required this.message,
    this.history,
    this.attachments,
    this.userId,
    this.userEmail,
    this.feature = 'conversation',
    this.metadata,
    this.stream = true,
  });

  Map<String, dynamic> toJson() => {
    'intent': feature,
    'message': message,
    'conversationId': conversationId,
    'history': history ?? [],
    'attachments': attachments?.map((a) => a.toJson()).toList(),
    'userContext': {
      if (userId != null) 'userId': userId,
      if (userEmail != null) 'email': userEmail,
    },
    'stream': stream,
    if (metadata != null) 'metadata': metadata,
  };
}

/// Attachment for AI requests — supports images, audio, video frames, files.
class AIAttachment {
  final String type;
  final String? base64;
  final String? mimeType;
  final String? transcript;
  final String? filePath;
  final String? fileName;

  AIAttachment({
    required this.type,
    this.base64,
    this.mimeType,
    this.transcript,
    this.filePath,
    this.fileName,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    if (base64 != null) 'base64': base64,
    if (mimeType != null) 'mimeType': mimeType,
    if (transcript != null) 'transcript': transcript,
    if (fileName != null) 'fileName': fileName,
  };
}

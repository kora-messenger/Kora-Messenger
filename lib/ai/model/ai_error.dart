/// Error types for AI operations.
enum AIErrorType {
  networkUnavailable,
  aiUnavailable,
  timeout,
  rateLimit,
  authenticationFailure,
  invalidRequest,
  unsupportedFile,
  voiceProcessingFailure,
  streamingInterruption,
  unknown,
}

/// Structured AI error with user-friendly messages.
class AIError {
  final AIErrorType type;
  final String message;
  final String? details;
  final bool isRetryable;

  AIError({
    required this.type,
    required this.message,
    this.details,
    this.isRetryable = true,
  });

  /// Human-readable error message for the UI.
  String get userMessage {
    switch (type) {
      case AIErrorType.networkUnavailable:
        return 'No internet connection. Please check your network and try again.';
      case AIErrorType.aiUnavailable:
        return 'Kora AI is temporarily unavailable. Please try again in a moment.';
      case AIErrorType.timeout:
        return 'The request took too long. Please try again.';
      case AIErrorType.rateLimit:
        return 'You\'ve reached the usage limit for this feature. Try again later or upgrade to Premium.';
      case AIErrorType.authenticationFailure:
        return 'Authentication failed. Please log in again.';
      case AIErrorType.invalidRequest:
        return 'The request was invalid. Please try a different message.';
      case AIErrorType.unsupportedFile:
        return 'This file type is not supported. Please use PDF, TXT, DOC, images, or other supported formats.';
      case AIErrorType.voiceProcessingFailure:
        return 'Voice processing failed. Please check your microphone and try again.';
      case AIErrorType.streamingInterruption:
        return 'The response was interrupted. Tap retry to continue.';
      case AIErrorType.unknown:
        return 'Kora AI couldn\'t complete that request. Please try again.';
    }
  }

  /// Create an AIError from an exception.
  factory AIError.fromException(Object e) {
    final msg = e.toString();
    if (msg.contains('Socket') || msg.contains('Network') || msg.contains('Failed host')) {
      return AIError(type: AIErrorType.networkUnavailable, message: msg, isRetryable: true);
    }
    if (msg.contains('timeout') || msg.contains('Timeout')) {
      return AIError(type: AIErrorType.timeout, message: msg, isRetryable: true);
    }
    if (msg.contains('429') || msg.contains('rate') || msg.contains('limit')) {
      return AIError(type: AIErrorType.rateLimit, message: msg, isRetryable: false);
    }
    if (msg.contains('401') || msg.contains('403') || msg.contains('auth')) {
      return AIError(type: AIErrorType.authenticationFailure, message: msg, isRetryable: false);
    }
    return AIError(type: AIErrorType.unknown, message: msg, isRetryable: true);
  }
}

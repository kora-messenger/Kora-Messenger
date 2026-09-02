/// Stream events for AI response streaming.
/// The UI listens to these events to progressively display AI responses.
sealed class AIStreamEvent {}

/// Generation has started.
class AIStreamStarted extends AIStreamEvent {}

/// A chunk of text has been received.
class AIStreamTextDelta extends AIStreamEvent {
  final String text;
  AIStreamTextDelta(this.text);
}

/// The complete message has been generated.
class AIStreamMessageCompleted extends AIStreamEvent {
  final String messageId;
  final String fullText;
  AIStreamMessageCompleted(this.messageId, this.fullText);
}

/// An error occurred during streaming.
class AIStreamError extends AIStreamEvent {
  final String message;
  final bool isRetryable;
  AIStreamError(this.message, {this.isRetryable = true});
}

/// Generation was stopped (user cancelled or server stopped).
class AIStreamStopped extends AIStreamEvent {}

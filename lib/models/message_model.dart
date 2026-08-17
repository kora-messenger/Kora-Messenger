import 'chat_models.dart';

/// Message type — text, image, voice, file, system.
enum KoraMessageType {
  text,
  image,
  voice,
  file,
  system,
}

/// A single message in a Kora conversation.
class KoraMessage {
  final String id;
  final String text;
  final DateTime timestamp;
  final bool isMe; // true = outgoing, false = incoming
  final KoraMessageType type;
  final MessageStatus status;
  final String? replyToId; // if this is a reply
  final String? replyToText;
  final String? replyToName;
  final String? reaction; // emoji reaction (single for now)
  final String? voiceDuration; // "0:12" etc, for voice messages
  final String? attachmentName; // for file messages

  const KoraMessage({
    required this.id,
    required this.text,
    required this.timestamp,
    required this.isMe,
    this.type = KoraMessageType.text,
    this.status = MessageStatus.none,
    this.replyToId,
    this.replyToText,
    this.replyToName,
    this.reaction,
    this.voiceDuration,
    this.attachmentName,
  });

  KoraMessage copyWith({
    String? id,
    String? text,
    DateTime? timestamp,
    bool? isMe,
    KoraMessageType? type,
    MessageStatus? status,
    String? replyToId,
    String? replyToText,
    String? replyToName,
    String? reaction,
    String? voiceDuration,
    String? attachmentName,
  }) {
    return KoraMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      isMe: isMe ?? this.isMe,
      type: type ?? this.type,
      status: status ?? this.status,
      replyToId: replyToId ?? this.replyToId,
      replyToText: replyToText ?? this.replyToText,
      replyToName: replyToName ?? this.replyToName,
      reaction: reaction ?? this.reaction,
      voiceDuration: voiceDuration ?? this.voiceDuration,
      attachmentName: attachmentName ?? this.attachmentName,
    );
  }
}

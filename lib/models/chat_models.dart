import 'package:flutter/material.dart';

/// Badge types shown next to a contact/account name across Kora.
/// Kept consistent everywhere a name + badge pairing appears.
enum KoraBadgeType {
  none,
  officialPurple, // Official Kora accounts (Support, AI Assistant, etc.)
  premiumBlue, // Kora Premium subscribers
}

/// Delivery/read status shown on the sender's own outgoing messages.
enum MessageStatus {
  none, // incoming message, or draft
  unsent, // outgoing message that failed to send — shows retry option (WhatsApp UNSENT)
  pendingOffline, // recorded locally, waiting for network to upload
  sent, // single check
  delivered, // double check
  read, // double check, purple
}

/// Fine-grained transfer state for an outgoing voice note that hasn't
/// finished uploading yet (i.e. its [MessageStatus] is [MessageStatus.pendingOffline]).
///
/// - [uploading]: an upload attempt is actively in flight — shows a
///   circular progress ring with a tap-to-cancel X in the middle.
/// - [notSent]: the attempt was cancelled (or a manual retry failed
///   while offline) — shows a tap-to-retry arrow icon. The note stays
///   in the background sync queue and auto-uploads the moment
///   connectivity returns, with no action needed from the user.
enum VoiceTransferState {
  uploading,
  notSent,
}

/// A single conversation entry in the Home chat list.
class ChatPreview {
  final String id;
  final String name;
  final String? avatarAsset; // local asset path, takes priority
  final String? avatarUrl; // remote url fallback
  final String? recipientEmail;
  final String lastMessage;
  final DateTime timestamp;
  final int unreadCount;
  final MessageStatus status;
  final KoraBadgeType badge;
  final bool isMuted;
  final bool isPinned;
  final bool isArchived;
  final bool isOnline;
  final bool isTyping;

  /// True when the last message in this conversation is a voice note.
  /// Drives the Home row to render a mic icon + "Voice message (0:09)"
  /// instead of showing (empty) raw text.
  final bool isVoiceLastMessage;

  /// Duration string ("0:09") for the last message, when
  /// [isVoiceLastMessage] is true.
  final String? lastVoiceDuration;

  /// The other participant's account email, when known — used to wire
  /// up calls and other email-addressed backend actions from a chat
  /// opened via search.

  const ChatPreview({
    required this.id,
    required this.name,
    this.avatarAsset,
    this.avatarUrl,
    this.recipientEmail,
    required this.lastMessage,
    required this.timestamp,
    this.unreadCount = 0,
    this.status = MessageStatus.none,
    this.badge = KoraBadgeType.none,
    this.isMuted = false,
    this.isPinned = false,
    this.isArchived = false,
    this.isOnline = false,
    this.isTyping = false,
    this.isVoiceLastMessage = false,
    this.lastVoiceDuration,
  });
}

/// Kora's brand color for each badge type.
class KoraBadgeColors {
  static const Color official = Color(0xFF8B5CF6); // purple
  static const Color premium = Color(0xFF3B82F6); // blue
}

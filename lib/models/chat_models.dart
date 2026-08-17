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
  sent, // single check
  delivered, // double check
  read, // double check, purple
}

/// A single conversation entry in the Home chat list.
class ChatPreview {
  final String id;
  final String name;
  final String? avatarAsset; // local asset path, takes priority
  final String? avatarUrl; // remote url fallback
  final String lastMessage;
  final DateTime timestamp;
  final int unreadCount;
  final MessageStatus status;
  final KoraBadgeType badge;
  final bool isMuted;
  final bool isPinned;
  final bool isOnline;
  final bool isTyping;

  const ChatPreview({
    required this.id,
    required this.name,
    this.avatarAsset,
    this.avatarUrl,
    required this.lastMessage,
    required this.timestamp,
    this.unreadCount = 0,
    this.status = MessageStatus.none,
    this.badge = KoraBadgeType.none,
    this.isMuted = false,
    this.isPinned = false,
    this.isOnline = false,
    this.isTyping = false,
  });
}

/// Kora's brand color for each badge type.
class KoraBadgeColors {
  static const Color official = Color(0xFF8B5CF6); // purple
  static const Color premium = Color(0xFF3B82F6); // blue
}

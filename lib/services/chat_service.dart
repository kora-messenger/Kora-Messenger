import '../models/chat_models.dart';
import '../models/message_model.dart';
import 'message_service.dart';
import 'conversation_directory.dart';

/// Builds the Home chat list from real persisted conversations.
///
/// Kora Support and Kora AI appear in the chat list (not pinned) — they're
/// the built-in AI assistants. Every chat's pinned/muted/archived state
/// lives in [ConversationDirectoryService] and is preserved across app
/// runs. All other chats are built from the messages stored by
/// [MessageService] and the display metadata registered in
/// [ConversationDirectoryService] when a chat screen opens.
enum _ChatListFilter { main, archived, locked }

class ChatService {
  List<ChatPreview> cachedChats = [];
  static final ChatService instance = ChatService._();
  ChatService._();

  static const Map<String, String> _builtinAiChats = {
    'kora_support': 'Kora Support',
    'kora_ai': 'Kora AI',
    'kora_notifications': 'Kora Notifications',
  };

  static const Map<String, String> _builtinAiAvatars = {
    'kora_support': 'assets/images/kora_ai_avatar.png',
    'kora_ai': 'assets/images/kora_support_avatar.png',
    'kora_notifications': 'kora_icon',
  };

  static const Map<String, String> _builtinAiPlaceholders = {
    'kora_support': 'Welcome to Kora Messenger!',
    'kora_ai': 'Ask me anything — inside or outside Kora.',
    'kora_notifications': 'Service messages from Kora',
  };

  /// Makes sure Kora Support and Kora AI always have a directory entry
  /// so their pin/mute/archive state persists exactly like any other
  /// chat instead of resetting on every app run.
  Future<void> _ensureBuiltinChatsRegistered() async {
    for (final chatId in _builtinAiChats.keys) {
      final existing = await ConversationDirectoryService.instance.get(chatId);
      if (existing == null) {
        await ConversationDirectoryService.instance.upsert(
          chatId: chatId,
          name: _builtinAiChats[chatId]!,
          avatarAsset: _builtinAiAvatars[chatId],
          badge: KoraBadgeType.officialPurple,
        );
      }
    }
  }

  /// Returns the current chat list, sorted: pinned chats first, then
  /// everything else by most recent message timestamp. Archived and
  /// locked chats are excluded — see [getArchivedChats]/[getLockedChats].
  Future<List<ChatPreview>> getChats() async {
    final chats = await _buildChats(_ChatListFilter.main);
    cachedChats = chats;
    return chats;
    return _buildChats(_ChatListFilter.main);
  }

  /// Returns chats the user has archived, most recent first. Locked
  /// chats never show here even if also archived — Lock always wins.
  Future<List<ChatPreview>> getArchivedChats() async {
    return _buildChats(_ChatListFilter.archived);
  }

  /// Returns chats the user has locked — only reachable through the
  /// biometric-gated Locked Chats screen, regardless of archive state.
  Future<List<ChatPreview>> getLockedChats() async {
    return _buildChats(_ChatListFilter.locked);
  }

  /// A mute set with a duration (8 hours / 1 week) can expire. This
  /// checks the stored `mutedUntil` timestamp and, if it has passed,
  /// auto-unmutes (persisting the change) so stale mutes don't linger.
  /// "Always" mutes have no `mutedUntil` and never expire here.
  bool _effectiveMuted(String chatId, Map<String, dynamic> meta) {
    final rawMuted = meta['isMuted'] as bool? ?? false;
    if (!rawMuted) return false;
    final untilMs = meta['mutedUntil'] as int?;
    if (untilMs == null) return true; // "Always"
    final until = DateTime.fromMillisecondsSinceEpoch(untilMs);
    if (DateTime.now().isBefore(until)) return true;
    // Expired — fire-and-forget auto-unmute so the next read is clean.
    ConversationDirectoryService.instance.setMuted(chatId, false);
    return false;
  }

  /// "Mark as unread" from the overflow menu sets a `forcedUnread`
  /// flag rather than a real unseen message — this surfaces it as an
  /// unread badge (1) until the chat is opened again, without lying
  /// about actual message read-receipts.
  int _effectiveUnreadCount(String chatId, Map<String, dynamic> meta) {
    final real = MessageService.instance.unreadCountFor(chatId);
    if (real > 0) return real;
    final forced = meta['forcedUnread'] as bool? ?? false;
    return forced ? 1 : 0;
  }

  Future<List<ChatPreview>> _buildChats(_ChatListFilter filter) async {
    await _ensureBuiltinChatsRegistered();

    final ms = MessageService.instance;
    final directory = await ConversationDirectoryService.instance.getAll();
    final chats = <ChatPreview>[];

    for (final entry in directory.entries) {
      final chatId = entry.key;
      final meta = entry.value;
      final isArchived = meta['isArchived'] as bool? ?? false;
      final isLocked = meta['isLocked'] as bool? ?? false;
      switch (filter) {
        case _ChatListFilter.main:
          if (isArchived || isLocked) continue;
          break;
        case _ChatListFilter.archived:
          if (!isArchived || isLocked) continue;
          break;
        case _ChatListFilter.locked:
          if (!isLocked) continue;
          break;
      }

      final recipientEmail = meta['recipientEmail'] as String?;
      final isBuiltinAi = _builtinAiChats.containsKey(chatId);

      final msgs = await ms.loadMessages(chatId);
      if (msgs.isEmpty && !isBuiltinAi) continue; // no messages yet — don't show empty row

      final last = msgs.isNotEmpty ? msgs.last : null;
      final isVoice = last?.type == KoraMessageType.voice;

      final String lastMessageText;
      final DateTime timestamp;
      if (last != null) {
        lastMessageText = isVoice
            ? 'Voice message${last.voiceDuration != null ? ' (${last.voiceDuration})' : ''}'
            : last.text;
        timestamp = last.timestamp;
      } else {
        lastMessageText = _builtinAiPlaceholders[chatId] ?? '';
        timestamp = DateTime.now();
      }

      chats.add(ChatPreview(
        id: chatId,
        name: meta['name'] as String? ?? chatId,
        avatarAsset: meta['avatarAsset'] as String?,
        avatarUrl: meta['avatarUrl'] as String?,
        recipientEmail: recipientEmail,
        lastMessage: lastMessageText,
        timestamp: timestamp,
        unreadCount: _effectiveUnreadCount(chatId, meta),
        badge: KoraBadgeType.values[meta['badge'] as int? ?? 0],
        isOnline: meta['isOnline'] as bool? ?? false,
        isPinned: meta['isPinned'] as bool? ?? false,
        isMuted: _effectiveMuted(chatId, meta),
        status: last != null && last.isMe ? last.status : MessageStatus.none,
        isVoiceLastMessage: isVoice,
        lastVoiceDuration: last?.voiceDuration,
      ));
    }

    return chats;
  }
}

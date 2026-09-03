import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_models.dart';
import 'chat_sync_service.dart';
import 'message_service.dart';

/// Lightweight directory mapping a chatId → the display metadata needed
/// to render it as a Home screen row (name, avatar, badge, online state)
/// plus the user's per-chat preferences (pinned, muted, archived).
///
/// Kora's message storage ([MessageService]) only knows chat IDs and
/// messages — it has no concept of "who is this" or "did the user pin
/// this chat". Whenever a chat screen opens for a real contact,
/// [KoraChatScreen] registers/updates an entry here so [ChatService]
/// can rebuild that conversation's Home row on every app run, even
/// after the contact's info screen isn't on screen anymore.
class ConversationDirectoryService {
  static final ConversationDirectoryService instance =
      ConversationDirectoryService._();
  ConversationDirectoryService._();

  static const _kKey = 'kora_conversation_directory';

  Map<String, Map<String, dynamic>> _entries = {};
  bool _loaded = false;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        _entries = map.map(
          (k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map)),
        );
      } catch (_) {
        _entries = {};
      }
    }
    _loaded = true;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKey, jsonEncode(_entries));
  }

  /// Sync all conversations to the cloud (called after upsert).
  Future<void> _syncToCloud(String chatId, Map<String, dynamic> meta) async {
    await ChatSyncService.instance.syncConversation(
      chatId: chatId,
      name: meta['name'] as String? ?? chatId,
      avatarAsset: _nonEmpty(meta['avatarAsset'] as String?),
      avatarUrl: meta['avatarUrl'] as String?,
      badge: KoraBadgeType.values[meta['badge'] as int? ?? 0],
      isOnline: meta['isOnline'] as bool? ?? false,
      recipientEmail: meta['recipientEmail'] as String?,
    );
  }

  /// Registers/updates a conversation's display metadata. Safe to call
  /// every time a chat screen opens — it's a cheap upsert.
  ///
  /// This only touches display fields (name/avatar/badge/online). Any
  /// existing pinned/muted/archived preference for [chatId] is preserved
  /// so re-opening a chat never silently unpins/unmutes/unarchives it.
  Future<void> upsert({
    required String chatId,
    required String name,
    String? avatarAsset,
    String? avatarUrl,
    String? recipientEmail,
    KoraBadgeType badge = KoraBadgeType.none,
    bool isOnline = false,
    bool isGroupChat = false,
  }) async {
    await _ensureLoaded();
    final existing = _entries[chatId] ?? <String, dynamic>{};
    _entries[chatId] = {
      ...existing,
      'name': name,
      'avatarAsset': avatarAsset,
      'avatarUrl': avatarUrl,
      'recipientEmail': recipientEmail ?? existing['recipientEmail'],
      'badge': badge.index,
      'isOnline': isOnline,
      'isPinned': existing?['isPinned'] as bool? ?? false,
      'isMuted': existing?['isMuted'] as bool? ?? false,
      'isArchived': existing?['isArchived'] as bool? ?? false,
      'isGroupChat': isGroupChat || (existing?['isGroupChat'] as bool? ?? false),
    };
    await _persist();
    _syncToCloud(chatId, _entries[chatId]!);
  }

  /// Returns all known chatIds with their metadata.
  Future<Map<String, Map<String, dynamic>>> getAll() async {
    await _ensureLoaded();
    return Map.unmodifiable(_entries);
  }

  /// Deterministic 1:1 chatId shared by BOTH participants:
  /// 'dm__' + both emails sorted alphabetically and joined with '__'.
  /// Alice and Bob each compute the same id for their shared thread,
  /// so a conversation is one continuous chat on both sides — even
  /// across reinstalls and devices.
  static String deterministicChatId(String emailA, String emailB) {
    final a = emailA.trim().toLowerCase();
    final b = emailB.trim().toLowerCase();
    final pair = [a, b]..sort();
    return 'dm__${pair.join('__')}';
  }

  /// Finds the existing chatId for a 1:1 contact, if any — so tapping
  /// a contact never forks a second thread for the same person.
  Future<String?> findByRecipientEmail(String recipientEmail) async {
    await _ensureLoaded();
    final needle = recipientEmail.trim().toLowerCase();
    for (final entry in _entries.entries) {
      final re = (entry.value['recipientEmail'] as String?)?.toLowerCase();
      if (re != null && re.isNotEmpty && re == needle) {
        return entry.key;
      }
    }
    return null;
  }

  /// Resolves the chatId to use when opening a 1:1 chat with a contact.
  ///
  /// The deterministic shared chatId is ALWAYS authoritative: both
  /// participants independently compute the same id, so a conversation
  /// is one continuous thread on both sides — even across reinstalls
  /// and devices. Any legacy thread previously created for the same
  /// contact (under a random/legacy chatId) is migrated into the
  /// deterministic thread first: messages merge (no duplicates), the
  /// chat's pinned/muted/archived/locked preferences carry over, and
  /// the old local + cloud copies are cleared.
  ///
  /// Falls back to [fallback] (e.g. the contact's koraId) only when the
  /// contact has no email (manual/phone-only contacts) — a
  /// deterministic id can't be computed then.
  static Future<String> resolveDmChatId({
    required String? recipientEmail,
    required String myEmail,
    required String fallback,
  }) async {
    if (recipientEmail == null ||
        recipientEmail.trim().isEmpty ||
        myEmail.trim().isEmpty) {
      return fallback;
    }
    final target = deterministicChatId(myEmail, recipientEmail);
    await instance.migrateLegacyDmToDeterministic(
      myEmail: myEmail,
      recipientEmail: recipientEmail,
      targetChatId: target,
    );
    return target;
  }

  /// Upgrades every legacy 1:1 thread for [recipientEmail] onto the
  /// deterministic [targetChatId]:
  /// - merges the legacy thread's messages into the target thread
  ///   (by messageId, so nothing duplicates),
  /// - carries over the legacy thread's display metadata and
  ///   pinned/muted/archived/locked/favorite preferences,
  /// - deletes the legacy directory entry and its cloud copy,
  /// - re-syncs the merged thread to the cloud.
  ///
  /// Idempotent and safe to call on every DM open / poll restore.
  static const _reservedChatIds = {
    'kora_support',
    'kora_ai',
    'kora_notifications',
  };

  Future<void> migrateLegacyDmToDeterministic({
    required String myEmail,
    required String recipientEmail,
    required String targetChatId,
  }) async {
    await _ensureLoaded();
    final needle = recipientEmail.trim().toLowerCase();
    if (needle.isEmpty) return;
    // Consistency guard: the target must be exactly the id both
    // participants compute from the same email pair.
    if (targetChatId != deterministicChatId(myEmail, recipientEmail)) {
      return;
    }

    final legacyIds = <String>[];
    for (final entry in _entries.entries) {
      if (_reservedChatIds.contains(entry.key)) continue;
      if (entry.key == targetChatId) continue;
      if ((entry.value['isGroupChat'] as bool?) ?? false) continue;
      final re = (entry.value['recipientEmail'] as String?)?.toLowerCase();
      if (re != null && re.isNotEmpty && re == needle) {
        legacyIds.add(entry.key);
      }
    }
    if (legacyIds.isEmpty) return;

    // Merge every legacy thread into the deterministic one.
    for (final legacyId in legacyIds) {
      final legacy = _entries[legacyId];
      if (legacy != null) {
        await MessageService.instance.migrateChat(legacyId, targetChatId);

        // Carry metadata + preferences over into the target entry.
        final target = _entries[targetChatId] ?? <String, dynamic>{};
        _entries[targetChatId] = {
          ...legacy,
          ...target,
          // Prefer the target's display fields; inherit from legacy
          // only when the target never set them.
          'name': (target['name'] as String?)?.isNotEmpty == true
              ? target['name']
              : legacy['name'],
          'avatarAsset': _nonEmpty(target['avatarAsset'] as String?) ?? _nonEmpty(legacy['avatarAsset'] as String?),
          'avatarUrl': target['avatarUrl'] ?? legacy['avatarUrl'],
          'badge': (target['badge'] as int?) ?? (legacy['badge'] as int?) ?? 0,
          'isOnline': (target['isOnline'] as bool?) ??
              (legacy['isOnline'] as bool?) ??
              false,
          'recipientEmail': legacy['recipientEmail'],
          // Preferences: keep whichever thread had them turned on.
          'isPinned': (target['isPinned'] as bool? ?? false) ||
              (legacy['isPinned'] as bool? ?? false),
          'isMuted': (target['isMuted'] as bool? ?? false) ||
              (legacy['isMuted'] as bool? ?? false),
          'mutedUntil': target['mutedUntil'] ?? legacy['mutedUntil'],
          'isArchived': (target['isArchived'] as bool? ?? false) ||
              (legacy['isArchived'] as bool? ?? false),
          'isLocked': (target['isLocked'] as bool? ?? false) ||
              (legacy['isLocked'] as bool? ?? false),
          'isFavorite': (target['isFavorite'] as bool? ?? false) ||
              (legacy['isFavorite'] as bool? ?? false),
          'forcedUnread': (target['forcedUnread'] as bool? ?? false) ||
              (legacy['forcedUnread'] as bool? ?? false),
          'isGroupChat': false,
        };
        _entries.remove(legacyId);
      }
    }
    await _persist();

    // Clear the legacy cloud copies (this user's side; the contact's
    // device runs this same deterministic migration and clears theirs).
    for (final legacyId in legacyIds) {
      await ChatSyncService.instance.clearChatOnCloud(legacyId);
    }

    // Push the merged thread's metadata to the cloud.
    final merged = _entries[targetChatId];
    if (merged != null) {
      await _syncToCloud(targetChatId, merged);
    }
  }

  Future<Map<String, dynamic>?> get(String chatId) async {
    await _ensureLoaded();
    return _entries[chatId];
  }

  /// Pin/unpin [chatId] on the Home screen. No-op if the chat has no
  /// directory entry yet (nothing to pin).
  Future<void> setPinned(String chatId, bool pinned) async {
    await _ensureLoaded();
    final existing = _entries[chatId];
    if (existing == null) return;
    existing['isPinned'] = pinned;
    await _persist();
  }

  /// Mute/unmute notifications for [chatId]. When muting, [until]
  /// sets an expiry (e.g. now + 8 hours, now + 1 week); leave it null
  /// for "Always" (mutes indefinitely until manually unmuted).
  Future<void> setMuted(String chatId, bool muted, {DateTime? until}) async {
    await _ensureLoaded();
    final existing = _entries[chatId];
    if (existing == null) return;
    existing['isMuted'] = muted;
    if (muted && until != null) {
      existing['mutedUntil'] = until.millisecondsSinceEpoch;
    } else {
      existing.remove('mutedUntil');
    }
    await _persist();
  }

  /// Archive/unarchive [chatId] — archived chats are hidden from the
  /// main Home list and shown in the Archived Chats screen instead.
  Future<void> setArchived(String chatId, bool archived) async {
    await _ensureLoaded();
    final existing = _entries[chatId];
    if (existing == null) return;
    existing['isArchived'] = archived;
    await _persist();
  }

  /// Lock/unlock [chatId] — locked chats are hidden from BOTH the main
  /// Home list and the Archived Chats screen, and only reachable via
  /// the biometric-gated Locked Chats screen.
  Future<void> setLocked(String chatId, bool locked) async {
    await _ensureLoaded();
    final existing = _entries[chatId];
    if (existing == null) return;
    existing['isLocked'] = locked;
    await _persist();
  }

  /// Favorite/unfavorite [chatId].
  Future<void> setFavorite(String chatId, bool favorite) async {
    await _ensureLoaded();
    final existing = _entries[chatId];
    if (existing == null) return;
    existing['isFavorite'] = favorite;
    await _persist();
  }

  /// Manually forces [chatId] to show as unread on the Home screen
  /// even though every message has actually been seen. Cleared
  /// automatically the next time the chat is opened.
  Future<void> setForcedUnread(String chatId, bool forced) async {
    await _ensureLoaded();
    final existing = _entries[chatId];
    if (existing == null) return;
    existing['forcedUnread'] = forced;
    await _persist();
  }

  /// Fully removes [chatId]'s directory entry (used alongside
  /// [MessageService.deleteChat] when the user deletes a conversation).
  Future<void> remove(String chatId) async {
    await _ensureLoaded();
    _entries.remove(chatId);
    await _persist();
  }
}


/// Empty strings from cloud records mean "no value" — normalize to null
/// so downstream image loaders never see an empty asset path.
String? _nonEmpty(String? v) => (v != null && v.isNotEmpty) ? v : null;

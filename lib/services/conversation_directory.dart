import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_models.dart';
import 'chat_sync_service.dart';

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
      avatarAsset: meta['avatarAsset'] as String?,
      avatarUrl: meta['avatarUrl'] as String?,
      badge: KoraBadgeType.values[meta['badge'] as int? ?? 0],
      isOnline: meta['isOnline'] as bool? ?? false,
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
    KoraBadgeType badge = KoraBadgeType.none,
    bool isOnline = false,
  }) async {
    await _ensureLoaded();
    final existing = _entries[chatId] ?? <String, dynamic>{};
    _entries[chatId] = {
      ...existing,
      'name': name,
      'avatarAsset': avatarAsset,
      'avatarUrl': avatarUrl,
      'badge': badge.index,
      'isOnline': isOnline,
    };
    await _persist();
    _syncToCloud(chatId, _entries[chatId]!);
  }

  /// Returns all known chatIds with their metadata.
  Future<Map<String, Map<String, dynamic>>> getAll() async {
    await _ensureLoaded();
    return Map.unmodifiable(_entries);
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

  /// Mute/unmute notifications for [chatId].
  Future<void> setMuted(String chatId, bool muted) async {
    await _ensureLoaded();
    final existing = _entries[chatId];
    if (existing == null) return;
    existing['isMuted'] = muted;
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

  /// Fully removes [chatId]'s directory entry (used alongside
  /// [MessageService.deleteChat] when the user deletes a conversation).
  Future<void> remove(String chatId) async {
    await _ensureLoaded();
    _entries.remove(chatId);
    await _persist();
  }
}

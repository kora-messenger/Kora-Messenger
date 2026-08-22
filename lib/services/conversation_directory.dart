import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_models.dart';

/// Lightweight directory mapping a chatId → the display metadata needed
/// to render it as a Home screen row (name, avatar, badge, online state).
///
/// Kora's message storage ([MessageService]) only knows chat IDs and
/// messages — it has no concept of "who is this". Whenever a chat
/// screen opens for a real contact, [KoraChatScreen] registers/updates
/// an entry here so [ChatService] can rebuild that conversation's Home
/// row on every app run, even after the contact's info screen isn't
/// on screen anymore.
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

  /// Registers/updates a conversation's display metadata. Safe to call
  /// every time a chat screen opens — it's a cheap upsert.
  Future<void> upsert({
    required String chatId,
    required String name,
    String? avatarAsset,
    String? avatarUrl,
    KoraBadgeType badge = KoraBadgeType.none,
    bool isOnline = false,
  }) async {
    await _ensureLoaded();
    _entries[chatId] = {
      'name': name,
      'avatarAsset': avatarAsset,
      'avatarUrl': avatarUrl,
      'badge': badge.index,
      'isOnline': isOnline,
    };
    await _persist();
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
}

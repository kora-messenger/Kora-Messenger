import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Per-chat screenshot blocking service.
///
/// Stores a set of chatIds for which screenshot blocking (FLAG_SECURE)
/// is enabled. When active, the chat screen wraps itself in SecureScreen
/// to prevent screenshots and screen recording.
class AntiScreenshotService {
  static const _key = 'kora_anti_screenshot_chats';

  static AntiScreenshotService? _instance;
  static AntiScreenshotService get instance {
    _instance ??= AntiScreenshotService._();
    return _instance!;
  }
  AntiScreenshotService._();

  /// Returns true if screenshot blocking is enabled for [chatId].
  Future<bool> isEnabled(String chatId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    return list.contains(chatId);
  }

  /// Enable or disable screenshot blocking for [chatId].
  Future<void> setEnabled(String chatId, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    if (enabled && !list.contains(chatId)) {
      list.add(chatId);
    } else if (!enabled) {
      list.remove(chatId);
    }
    await prefs.setStringList(_key, list);
  }

  /// Toggle and return the new state.
  Future<bool> toggle(String chatId) async {
    final current = await isEnabled(chatId);
    await setEnabled(chatId, !current);
    return !current;
  }

  /// Get all chatIds with screenshot blocking enabled.
  Future<Set<String>> getEnabledChats() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    return list.toSet();
  }
}

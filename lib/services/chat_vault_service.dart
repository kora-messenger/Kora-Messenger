import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Service managing Biometric Chat Vault settings, secret code storage,
/// auto-lock timer, and per-chat vault options (blocking screenshots, hiding media).
class ChatVaultService {
  static final ChatVaultService instance = ChatVaultService._();
  ChatVaultService._();

  static const String _kSecretCodeHash = 'kora_vault_secret_code_hash';
  static const String _kHideLockedChats = 'kora_vault_hide_locked_chats';
  static const String _kAutoLockTimer = 'kora_vault_autolock_timer'; // Minutes: 0=never, 1=1m, 5=5m, 30=30m
  static const String _kLastUnlockedTime = 'kora_vault_last_unlocked';
  static const String _kBlockScreenshots = 'kora_vault_block_screenshots';
  static const String _kHideMediaFromGallery = 'kora_vault_hide_media_gallery';

  /// Computes a hash of the secret code so plaintext is never saved on device.
  String _hashSecretCode(String code) {
    final bytes = utf8.encode('kora_vault_salt_$code');
    var hash = 0x811c9dc5;
    for (var i = 0; i < bytes.length; i++) {
      hash ^= bytes[i];
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16);
  }

  /// Sets or updates the secret code (4-8 characters).
  Future<void> setSecretCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    final hash = _hashSecretCode(code);
    await prefs.setString(_kSecretCodeHash, hash);
  }

  /// Verifies if the typed string matches the saved secret code.
  Future<bool> verifySecretCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    final storedHash = prefs.getString(_kSecretCodeHash);
    if (storedHash == null || storedHash.isEmpty) return false;
    return storedHash == _hashSecretCode(code);
  }

  /// Checks if a secret code has been set.
  Future<bool> hasSecretCode() async {
    final prefs = await SharedPreferences.getInstance();
    final storedHash = prefs.getString(_kSecretCodeHash);
    return storedHash != null && storedHash.isNotEmpty;
  }

  /// Clears/removes the secret code.
  Future<void> removeSecretCode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSecretCodeHash);
    await setHidden(false);
  }

  /// Returns true if locked chats folder is hidden from the chat list.
  Future<bool> isHidden() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kHideLockedChats) ?? false;
  }

  /// Sets whether the locked chats folder is hidden from the main chat list.
  Future<void> setHidden(bool hidden) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHideLockedChats, hidden);
  }

  /// Sets the auto-lock timer in minutes (0 = never, 1 = 1 min, 5 = 5 min, 30 = 30 min).
  Future<void> setAutoLockTimer(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kAutoLockTimer, minutes);
  }

  /// Gets the current auto-lock timer in minutes (default 0 = never).
  Future<int> getAutoLockTimer() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kAutoLockTimer) ?? 0;
  }

  /// Records timestamp when vault was unlocked.
  Future<void> recordUnlocked() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLastUnlockedTime, DateTime.now().millisecondsSinceEpoch);
  }

  /// Checks if auto-lock timer has expired.
  Future<bool> shouldAutoLock() async {
    final prefs = await SharedPreferences.getInstance();
    final timer = prefs.getInt(_kAutoLockTimer) ?? 0;
    if (timer <= 0) return false;

    final lastUnlocked = prefs.getInt(_kLastUnlockedTime) ?? 0;
    if (lastUnlocked == 0) return true;

    final elapsedMs = DateTime.now().millisecondsSinceEpoch - lastUnlocked;
    final timerMs = timer * 60 * 1000;
    return elapsedMs >= timerMs;
  }

  /// Checks if screenshot blocking is enabled for locked chats.
  Future<bool> isBlockScreenshotsEnabled({String? chatId}) async {
    final prefs = await SharedPreferences.getInstance();
    if (chatId != null) {
      final val = prefs.getBool('${_kBlockScreenshots}_$chatId');
      if (val != null) return val;
    }
    return prefs.getBool(_kBlockScreenshots) ?? true;
  }

  /// Sets screenshot blocking preference for locked chats.
  Future<void> setBlockScreenshots(bool enabled, {String? chatId}) async {
    final prefs = await SharedPreferences.getInstance();
    if (chatId != null) {
      await prefs.setBool('${_kBlockScreenshots}_$chatId', enabled);
    } else {
      await prefs.setBool(_kBlockScreenshots, enabled);
    }
  }

  /// Checks if hiding media from gallery is enabled for locked chats.
  Future<bool> isHideMediaFromGalleryEnabled({String? chatId}) async {
    final prefs = await SharedPreferences.getInstance();
    if (chatId != null) {
      final val = prefs.getBool('${_kHideMediaFromGallery}_$chatId');
      if (val != null) return val;
    }
    return prefs.getBool(_kHideMediaFromGallery) ?? true;
  }

  /// Sets hide media from gallery preference for locked chats.
  Future<void> setHideMediaFromGallery(bool enabled, {String? chatId}) async {
    final prefs = await SharedPreferences.getInstance();
    if (chatId != null) {
      await prefs.setBool('${_kHideMediaFromGallery}_$chatId', enabled);
    } else {
      await prefs.setBool(_kHideMediaFromGallery, enabled);
    }
  }
}

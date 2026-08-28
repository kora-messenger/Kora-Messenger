import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'kora_encryption_service.dart';

/// Manages the local user session using shared_preferences.
///
/// When the user logs in, their session data is saved locally so that
/// on the next app launch, they go straight to the home screen instead
/// of seeing the welcome screen.
///
/// When they log out, the session is cleared.
class SessionManager {
  static const String _sessionKey = 'kora_session';

  static SessionManager? _instance;
  static SessionManager get instance => _instance ??= SessionManager._();
  SessionManager._();

  /// Cached email for current session (sync access from detection system).
  String _cachedEmail = '';
  String get currentEmail => _cachedEmail;

  /// Cached user object (sync access from detection system).
  KoraUserSession? _cachedUser;
  KoraUserSession? get currentUser => _cachedUser;

  /// Saves session and updates cache.
  Future<void> saveSession(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, jsonEncode(userData));
    _cachedEmail = userData['email'] as String? ?? '';
    _cachedUser = KoraUserSession.fromMap(userData);
    // Publish E2EE public keys so others can encrypt messages to this user
    final email = userData['email'] as String?;
    if (email != null && email.isNotEmpty) {
      await _publishE2eeKeys(email);
    }
  }

  Future<void> _publishE2eeKeys(String email) async {
    try {
      await KoraEncryptionService.instance.init();
      await KoraEncryptionService.instance.publishPublicKey(email);
    } catch (_) {}
  }

  /// Loads session from storage and caches it for sync access.
  /// Call this on app startup before navigating to home.
  Future<Map<String, dynamic>?> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      _cachedEmail = data['email'] as String? ?? '';
      _cachedUser = KoraUserSession.fromMap(data);
      return data;
    } catch (_) {
      return null;
    }
  }

  /// Clears the saved session (logout).
  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
    _cachedEmail = '';
    _cachedUser = null;
  }

  /// Updates the existing session with new/changed fields.
  Future<void> updateSession(Map<String, dynamic> updates) async {
    final existing = await loadSession();
    if (existing == null) return;
    final merged = {...existing, ...updates};
    await saveSession(merged);
  }
}

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

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

  /// Saves the user session locally.
  Future<void> saveSession(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, jsonEncode(userData));
  }

  /// Loads the saved session, or null if none exists.
  Future<Map<String, dynamic>?> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Clears the saved session (logout).
  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }

  /// Returns true if a session exists.
  Future<bool> hasSession() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_sessionKey);
  }
}

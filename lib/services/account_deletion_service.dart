import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../config/kora_api.dart';
import 'voice_vector_store.dart';

/// Secure account deletion service.
///
/// Permanently wipes:
/// 1. User's phone registration (FCM tokens, device records)
/// 2. Public Voice Vector Matrix file from cloud storage
/// 3. KoraUser account record
/// 4. All conversation history and messages
///
/// This action is irreversible and triggers a secure API call
/// to the backend that performs the wipe server-side.
class AccountDeletionService {
  static final AccountDeletionService instance = AccountDeletionService._();
  AccountDeletionService._();

  /// Permanently delete the user's account and all associated data.
  ///
  /// [userEmail] — the account email
  /// [userKoraId] — the Kora ID
  /// [confirmPassword] — user must re-enter password for confirmation
  ///
  /// Returns (true, null) on success, (false, errorMessage) on failure.
  Future<(bool, String?)> deleteAccount({
    required String userEmail,
    required String userKoraId,
    required String confirmPassword,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(KoraApi.authEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'deleteAccount',
          'email': userEmail,
          'koraId': userKoraId,
          'confirmPassword': confirmPassword,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          // Clear local voice vector
          await _clearLocalData();
          return (true, null);
        } else {
          return (false, data['message'] as String? ?? 'Deletion failed');
        }
      } else {
        return (false, 'Server error. Please try again.');
      }
    } catch (e) {
      debugPrint('[AccountDeletion] error: $e');
      return (false, 'Network error. Please check your connection.');
    }
  }

  /// Clear all local data related to the user.
  Future<void> _clearLocalData() async {
    try {
      // Clear voice vector cache
      VoiceVectorStore.instance.clearCache();

      // Clear local voice vector storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('kora_my_voice_vector');
      await prefs.remove('kora_custom_voices');
      await prefs.remove('kora_selected_voice');
      await prefs.remove('kora_translation_pref_lang');
      await prefs.remove('kora_call_translation');
      await prefs.clear();
    } catch (e) {
      debugPrint('[AccountDeletion] local clear error: $e');
    }
  }
}


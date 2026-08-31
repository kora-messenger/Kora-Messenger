import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/kora_api.dart';
import '../models/voice_vector.dart';

/// Stores and retrieves VoiceVectors from the server.
///
/// VoiceVectors are PUBLIC data — they contain no spoken words,
/// no transcript, just mathematical acoustic features. Safe to
/// store on the server's public profile directory.
class VoiceVectorStore {
  static final VoiceVectorStore instance = VoiceVectorStore._();
  VoiceVectorStore._();

  final Map<String, VoiceVector> _cache = {};
  static const _kLocalKey = 'kora_my_voice_vector';

  /// Publish the user's VoiceVector to their public profile on the server.
  Future<bool> publishVoiceVector(VoiceVector vector) async {
    try {
      // Store locally for immediate access
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLocalKey, jsonEncode(vector.toJson()));

      // Upload to server — the vector is just JSON math, no audio/words
      final response = await http.post(
        Uri.parse(KoraApi.e2eeKeysEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'publishVoiceVector',
          'voiceVector': vector.toJson(),
        }),
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[VoiceVectorStore] publish error: $e');
      // Local storage still succeeded even if server upload fails
      return false;
    }
  }

  /// Fetch another user's VoiceVector from the server.
  Future<VoiceVector?> fetchVoiceVector(String userEmail) async {
    if (userEmail.isEmpty) return null;
    if (_cache.containsKey(userEmail)) return _cache[userEmail];

    try {
      final response = await http.post(
        Uri.parse(KoraApi.e2eeKeysEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'fetchVoiceVector',
          'userEmail': userEmail,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['voiceVector'] != null) {
          final vector = VoiceVector.fromJson(data['voiceVector'] as Map<String, dynamic>);
          _cache[userEmail] = vector;
          return vector;
        }
      }
    } catch (e) {
      debugPrint('[VoiceVectorStore] fetch error: $e');
    }

    return null;
  }

  /// Get the current user's locally stored VoiceVector.
  Future<VoiceVector?> getMyVoiceVector() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_kLocalKey);
      if (json != null) {
        return VoiceVector.fromJson(jsonDecode(json) as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('[VoiceVectorStore] getMy error: $e');
    }
    return null;
  }

  /// Check if the user has a voice vector profile.
  Future<bool> hasVoiceVector() async {
    return (await getMyVoiceVector()) != null;
  }

  /// Permanently delete the user's Voice Vector from cloud storage.
  /// Called during account deletion.
  Future<void> deleteVoiceVector(String userEmail) async {
    try {
      final response = await http.delete(
        Uri.parse('\${KoraApi.baseUrl}/koraVoiceVector'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': userEmail}),
      ).timeout(const Duration(seconds: 10));
      debugPrint('[VoiceVectorStore] delete status: \${response.statusCode}');
    } catch (e) {
      debugPrint('[VoiceVectorStore] delete error: $e');
    }
  }

  void clearCache() {
    _cache.clear();
  }
}

import 'package:http/http.dart' as http;
import 'dart:convert';

/// Central API configuration for Kora Messenger.
///
/// When you get your own domain, change [baseUrl] here — everything else
/// in the codebase references this constant. No scattered URLs.
class KoraApi {
  /// Base URL for the Kora backend.
  /// Temporary: Base44 backend function.
  /// Future: 'https://api.koramessenger.com' (or your domain)
  static const String baseUrl = 'https://solas-463874c8.base44.app/functions';

  /// Auth endpoint (handles signup, login, verification, password reset, profile)
  static const String authEndpoint = '$baseUrl/koraAuth';

  /// Generic POST to the auth endpoint
  static Future<Map<String, dynamic>> post(Map<String, dynamic> body) async {
    return postTo(authEndpoint, body);
  }

  /// Generic POST to any endpoint
  static Future<Map<String, dynamic>> postTo(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final response = await http
        .post(
          Uri.parse(endpoint),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}

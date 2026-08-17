/// Central API configuration for Kora Messenger.
///
/// When you get your own domain, change [baseUrl] here — everything else
/// in the codebase references this constant. No scattered URLs.
class KoraApi {
  /// Base URL for the Kora backend.
  /// Temporary: Base44 backend function.
  /// Future: 'https://api.koramessenger.com' (or your domain)
  static const String baseUrl = 'https://solas-463874c8.base44.app/functions';

  /// Auth endpoint (handles signup, login, verification, password reset)
  static const String authEndpoint = '$baseUrl/koraAuth';

  /// Generic POST helper
  static Future<Map<String, dynamic>> post(Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse(authEndpoint),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}

// Re-exports so callers don't need separate imports
export 'package:http/http.dart' show http;
export 'dart:convert' show jsonEncode, jsonDecode;

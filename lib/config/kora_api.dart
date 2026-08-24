import 'dart:convert';

import 'package:http/http.dart' as http;

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

  /// Email change endpoint — two-step verification flow (old email → new email).
  /// Temporary: Base44 backend function.
  /// Future: 'https://api.koramessenger.com/email-change' (or your domain)
  static const String emailChangeEndpoint = '$baseUrl/koraEmailChange';

  /// Call signaling endpoint — WebRTC offer/answer/ICE exchange.
  /// Temporary: Base44 backend function.
  /// Future: 'https://api.koramessenger.com/call-signal' (or your domain)
  static const String callSignalingEndpoint = '$baseUrl/koraCallSignal';

  /// Translation endpoint — translates text between languages.
  /// Temporary: Base44 backend function.
  /// Future: 'https://api.koramessenger.com/translate' (or your domain)
  static const String translateEndpoint = '$baseUrl/koraTranslate';

  /// User lookup endpoint — check if username or Kora ID is registered.
  /// Temporary: Base44 backend function.
  /// Future: 'https://api.koramessenger.com/lookup' (or your domain)
  static const String lookupEndpoint = '$baseUrl/koraLookup';

  /// Crash report endpoint — receives crash data and creates a GitHub Issue.
  /// Temporary: Base44 backend function.
  /// Future: 'https://api.koramessenger.com/crash-report' (or your domain)
  static const String crashReportEndpoint = '$baseUrl/koraCrashReport';

  /// Automated detection system — monitors activity, suspends accounts,

  /// File upload endpoint — avatar and media uploads.
  /// Temporary: Base44 backend function.
  /// Future: 'https://api.koramessenger.com/upload' (or your domain)
  static const String uploadEndpoint = '$baseUrl/koraUpload';
  /// checks suspension status, and handles appeals.
  static const String autoDetectEndpoint = '$baseUrl/koraAutoDetect';

  /// Payment endpoint — initialize Paystack transactions.
  /// Temporary: Base44 backend function.
  /// Future: 'https://api.koramessenger.com/payment/init' (or your domain)
  static const String paymentInitEndpoint = '$baseUrl/koraInitPayment';

  /// Payment verification endpoint — verify Paystack transactions.
  /// Temporary: Base44 backend function.
  /// Future: 'https://api.koramessenger.com/payment/verify' (or your domain)
  static const String paymentVerifyEndpoint = '$baseUrl/koraVerifyPayment';

  /// Chat sync endpoint — persist messages & conversations to the database.
  /// Temporary: Base44 backend function.
  /// Future: 'https://api.koramessenger.com/chat-sync' (or your domain)
  static const String chatSyncEndpoint = '$baseUrl/koraChatSync';

  /// Kora AI Server base URL — legacy local dev server.
  /// Only the writing/reply-suggestions/summarize/transcribe/analyze
  /// endpoints below still point here (they have client-side fallbacks).
  /// Temporary: local dev server for testing.
  /// Future: 'https://ai.koramessenger.com' (or your domain)
  static const String aiServerUrl = 'http://10.0.2.2:5000';

  /// Kora AI Chat & Support — live Base44 backend function (OpenRouter).
  /// Both chat and support hit the same deployed endpoint; the body's
  /// 'chatType' field ('ai' or 'support') selects the system prompt.
  /// Temporary: Base44 backend function.
  /// Future: 'https://api.koramessenger.com/ai/chat' (or your domain)
  static const String aiChatSupportEndpoint = '$baseUrl/koraAiChat';
  static const String aiChatEndpoint = aiChatSupportEndpoint;
  static const String aiSupportEndpoint = aiChatSupportEndpoint;
  static const String aiHealthEndpoint = '$aiServerUrl/api/ai/health';

  /// Kora AI feature endpoints (writing assistant, reply suggestions, etc.)
  /// Still on the legacy local URL — not part of this fix; each of these
  /// has a graceful client-side fallback in AiFeaturesService.
  static const String aiWritingEndpoint = '$aiServerUrl/api/ai/writing';
  static const String aiReplySuggestionsEndpoint = '$aiServerUrl/api/ai/reply-suggestions';
  static const String aiSummarizeChatEndpoint = '$aiServerUrl/api/ai/summarize-chat';
  static const String aiTranscribeEndpoint = '$aiServerUrl/api/ai/transcribe';
  static const String aiAnalyzeImageEndpoint = '$aiServerUrl/api/ai/analyze-image';
  static const String aiAnalyzeFileEndpoint = '$aiServerUrl/api/ai/analyze-file';

  /// Auth token for the AI server.
  /// Must match KORA_AUTH_TOKEN in the server's .env file.
  static const String aiAuthToken = 'kora-ai-server-token';

  /// Legal documents — hosted on GitHub Pages.
  /// When you get your .com domain, change these to e.g.
  /// 'https://koramessenger.com/privacy-policy'
  static const String legalBaseUrl = 'https://24bada2.github.io/Kora-Messenger-Docs';
  static const String privacyPolicyUrl = '$legalBaseUrl/privacy-policy.html';
  static const String termsOfServiceUrl = '$legalBaseUrl/terms-of-service.html';
  static const String communityGuidelinesUrl = '$legalBaseUrl/community-guidelines.html';
  static const String aiPolicyUrl = '$legalBaseUrl/ai-policy.html';
  static const String learnMoreUrl = '$legalBaseUrl/index.html';

  /// Link shared when inviting a friend to Kora — swap this for the
  /// real app-store / website link once available.
  static const String inviteDownloadUrl = '$legalBaseUrl/index.html';

  /// Blocking / unblocking / reporting help page — linked from the
  /// "Learn more" text in the Block confirmation dialog.
  static const String blockingInfoUrl = '$legalBaseUrl/blocking-and-reporting.html';

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

  /// POST to a Kora AI endpoint (includes Bearer auth)
  static Future<Map<String, dynamic>> postToAi(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final response = await http
        .post(
          Uri.parse(endpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $aiAuthToken',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 120));
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}

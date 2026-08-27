import 'dart:convert';

import 'package:http/http.dart' as http;

/// Central API configuration for Kora Messenger.
///
/// Sensitive values (backend URL, AI auth token) are injected at compile
/// time via --dart-define flags. They are NOT hardcoded in source.
/// When you get your own domain, update the GitHub Secret KORA_BACKEND_URL
/// — everything else references [baseUrl] automatically.
class KoraApi {
  /// Base URL for the Kora backend.
  /// Injected at compile time via --dart-define=KORA_BACKEND_URL=...
  /// Fallback is a dummy placeholder so the app doesn't crash in dev
  /// if the define is missing (it'll just fail network calls gracefully).
  static const String baseUrl = String.fromEnvironment(
    'KORA_BACKEND_URL',
    defaultValue: 'https://placeholder.invalid/functions',
  );

  /// Auth endpoint (handles signup, login, verification, password reset, profile)
  static const String authEndpoint = '$baseUrl/koraAuth';

  /// Email change endpoint — two-step verification flow (old email → new email).
  static const String emailChangeEndpoint = '$baseUrl/koraEmailChange';

  /// Call signaling endpoint — WebRTC offer/answer/ICE exchange.
  static const String callSignalingEndpoint = '$baseUrl/koraCallSignal';

  /// Translation endpoint — translates text between languages.
  static const String translateEndpoint = '$baseUrl/koraTranslate';

  /// User lookup endpoint — check if username or Kora ID is registered.
  static const String lookupEndpoint = '$baseUrl/koraLookup';
  static const String lookupByEmailEndpoint = '$baseUrl/koraLookupByEmail';

  /// Link device endpoint — QR-based device pairing (generate token + link).
  static const String linkDeviceEndpoint = '$baseUrl/koraLinkDevice';

  /// Crash report endpoint — receives crash data and creates a GitHub Issue.
  static const String crashReportEndpoint = '$baseUrl/koraCrashReport';

  /// File upload endpoint — avatar and media uploads.
  static const String uploadEndpoint = '$baseUrl/koraUpload';

  /// Automated detection system — monitors activity, suspends accounts,
  /// checks suspension status, and handles appeals.
  static const String autoDetectEndpoint = '$baseUrl/koraAutoDetect';

  /// Payment endpoint — initialize Paystack transactions.
  static const String paymentInitEndpoint = '$baseUrl/koraInitPayment';

  /// Subscription recovery endpoint — re-check premium status from DB.
  static const String recoverSubscriptionEndpoint = '$baseUrl/koraRecoverSubscription';

  /// Payment verification endpoint — verify Paystack transactions.
  static const String paymentVerifyEndpoint = '$baseUrl/koraVerifyPayment';

  /// Chat sync endpoint — persist messages & conversations to the database.
  static const String chatSyncEndpoint = '$baseUrl/koraChatSync';

  /// Kora AI Server base URL — legacy local dev server.
  /// Only the writing/reply-suggestions/summarize/transcribe/analyze
  /// endpoints below still point here (they have client-side fallbacks).
  static const String aiServerUrl = 'http://10.0.2.2:5000';

  /// Kora AI Chat & Support — live backend function (OpenRouter).
  /// Both chat and support hit the same deployed endpoint; the body's
  /// 'chatType' field ('ai' or 'support') selects the system prompt.
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
  /// Injected at compile time via --dart-define=KORA_AI_AUTH_TOKEN=...
  /// Must match KORA_AUTH_TOKEN in the server's .env file.
  static const String aiAuthToken = String.fromEnvironment(
    'KORA_AI_AUTH_TOKEN',
    defaultValue: '',
  );

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

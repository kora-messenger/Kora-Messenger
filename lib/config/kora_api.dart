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

  /// GPT-powered streaming translation endpoint (batch + SSE streaming).
  /// Models AI Phone's /phone/ai/call/v3/gptTrans/stream architecture.
  static const String gptTransEndpoint = '$baseUrl/koraGptTrans';

  /// User lookup endpoint — check if username or Kora ID is registered.
  static const String lookupEndpoint = '$baseUrl/koraLookup';
  static const String lookupByEmailEndpoint = '$baseUrl/koraLookupByEmail';

  /// Link device endpoint — QR-based device pairing (generate token + link).
  static const String linkDeviceEndpoint = '$baseUrl/koraLinkDevice';

  /// Web companion pairing endpoint — QR-based web login (like WhatsApp Web).
  static const String webPairEndpoint = '$baseUrl/koraWebPair';

  /// Crash report endpoint — receives crash data and creates a GitHub Issue.
  static const String crashReportEndpoint = '$baseUrl/koraCrashReport';
  static const String serviceNotificationEndpoint = '$baseUrl/koraServiceNotification';
  static const String antiSpamEndpoint = '$baseUrl/koraAntiSpam';

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

  /// Kora AI feature endpoints (writing assistant, reply suggestions, chat summary)
  /// Now deployed as a single backend function — koraAiFeatures.
  /// Each request includes a 'feature' field: 'writing' | 'reply_suggestions' | 'summarize'.
  static const String aiFeaturesEndpoint = '$baseUrl/koraAiFeatures';

  /// Legacy endpoint aliases (kept for compatibility with existing service code).
  static const String aiWritingEndpoint = aiFeaturesEndpoint;
  static const String aiReplySuggestionsEndpoint = aiFeaturesEndpoint;
  static const String aiSummarizeChatEndpoint = aiFeaturesEndpoint;
  static const String aiTranscribeEndpoint = aiFeaturesEndpoint;
  static const String aiAnalyzeImageEndpoint = aiFeaturesEndpoint;
  static const String aiAnalyzeFileEndpoint = aiFeaturesEndpoint;

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
  static const String legalBaseUrl = 'https://kora-messenger.github.io/Kora-Messenger-Docs';
  static const String privacyPolicyUrl = '$legalBaseUrl/privacy-policy.html';
  static const String termsOfServiceUrl = '$legalBaseUrl/terms-of-service.html';
  static const String communityGuidelinesUrl = '$legalBaseUrl/community-guidelines.html';
  static const String aiPolicyUrl = '$legalBaseUrl/ai-policy.html';
  static const String e2eePolicyUrl = '$legalBaseUrl/e2ee-policy.html';

  /// E2EE key exchange endpoint for public key publish/lookup.
  static const String e2eeKeysEndpoint = '$baseUrl/koraE2eeKeys';
  static const String learnMoreUrl = '$legalBaseUrl/index.html';

  /// Link shared when inviting a friend to Kora — swap this for the
  /// real app-store / website link once available.
  static const String inviteDownloadUrl = '$legalBaseUrl/index.html';

  /// Base URL for call links — swap to your .com domain when deployed.
  /// Used by the Call Link screen to generate shareable call URLs.
  static const String callLinkBaseUrl =
      String.fromEnvironment('KORA_CALL_LINK_BASE', defaultValue: 'https://kora.chat');

  /// Base URL for channel invite links — swap to your .com domain when deployed.
  static const String channelBaseUrl =
      String.fromEnvironment('KORA_CHANNEL_BASE', defaultValue: 'https://kora.app');

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

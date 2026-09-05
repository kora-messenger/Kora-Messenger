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
    defaultValue: 'https://solas-463874c8.base44.app/functions',
  );

  /// Self-hosted auth base (Render → koramessenger.com later).
  /// Auth is the first service migrated off Base44: when KORA_AUTH_URL is
  /// set at build time, ALL authentication (signup, login, verification,
  /// password reset, profile) runs on our own infrastructure, while the
  /// remaining endpoints keep using [baseUrl] until each one migrates.
  static const String _authBase = String.fromEnvironment(
    'KORA_AUTH_URL',
    defaultValue: '',
  );

  /// Auth endpoint (handles signup, login, verification, password reset, profile)
  static String get authEndpoint =>
      _authBase.isEmpty ? '$baseUrl/koraAuth' : '$_authBase/koraAuth';

  /// Self-hosted chat-sync base — second service migrated off Base44.
  /// When KORA_CHAT_URL is set at build time, all message/conversation
  /// persistence runs on our own infrastructure.
  static const String _chatBase = String.fromEnvironment(
    'KORA_CHAT_URL',
    defaultValue: '',
  );

  /// Self-hosted upload base — third service migrated off Base44.
  static const String _uploadBase = String.fromEnvironment(
    'KORA_UPLOAD_URL',
    defaultValue: '',
  );

  /// Self-hosted settings-sync base — fourth service migrated off Base44.
  static const String _settingsBase = String.fromEnvironment(
    'KORA_SETTINGS_URL',
    defaultValue: '',
  );

  /// Self-hosted base for every service migrated after settings-sync.
  /// All remaining endpoints live on the same host, so one dart-define
  /// covers them all. Per-service overrides can be added later if any
  /// service ever moves to dedicated infrastructure.
  static const String _selfBase = String.fromEnvironment(
    'KORA_SELF_URL',
    defaultValue: '',
  );

  /// Email change endpoint — two-step verification flow (old email → new email).
  static String get emailChangeEndpoint =>
      _selfBase.isEmpty ? '$baseUrl/koraEmailChange' : '$_selfBase/koraEmailChange';

  /// Call signaling endpoint — WebRTC offer/answer/ICE exchange.
  static String get callSignalingEndpoint =>
      _selfBase.isEmpty ? '$baseUrl/koraCallSignal' : '$_selfBase/koraCallSignal';

  /// Translation endpoint — translates text between languages.
  static String get translateEndpoint =>
      _selfBase.isEmpty ? '$baseUrl/koraTranslate' : '$_selfBase/koraTranslate';

  /// GPT-powered streaming translation endpoint (batch + SSE streaming).
  /// Models AI Phone's /phone/ai/call/v3/gptTrans/stream architecture.
  static String get gptTransEndpoint =>
      _selfBase.isEmpty ? '$baseUrl/koraGptTrans' : '$_selfBase/koraGptTrans';

  /// User lookup endpoint — check if username or Kora ID is registered.
  /// Lookups read the same user data as auth, so they follow the same
  /// self-hosted override (see [_authBase]).
  static String get lookupEndpoint =>
      _authBase.isEmpty ? '$baseUrl/koraLookup' : '$_authBase/koraLookup';
  static String get lookupByEmailEndpoint =>
      _authBase.isEmpty ? '$baseUrl/koraLookupByEmail' : '$_authBase/koraLookupByEmail';

  /// Link device endpoint — QR-based device pairing (generate token + link).
  static String get linkDeviceEndpoint =>
      _selfBase.isEmpty ? '$baseUrl/koraLinkDevice' : '$_selfBase/koraLinkDevice';

  /// Web companion pairing endpoint — QR-based web login (like WhatsApp Web).
  static String get webPairEndpoint =>
      _selfBase.isEmpty ? '$baseUrl/koraWebPair' : '$_selfBase/koraWebPair';

  /// Crash report endpoint — receives crash data and creates a GitHub Issue.
  static String get crashReportEndpoint =>
      _selfBase.isEmpty ? '$baseUrl/koraCrashReport' : '$_selfBase/koraCrashReport';
  static String get serviceNotificationEndpoint =>
      _selfBase.isEmpty ? '$baseUrl/koraServiceNotification' : '$_selfBase/koraServiceNotification';
  static String get antiSpamEndpoint =>
      _selfBase.isEmpty ? '$baseUrl/koraAntiSpam' : '$_selfBase/koraAntiSpam';

  /// File upload endpoint — avatar and media uploads.
  /// Upload endpoint — follows the self-hosted override (see [_uploadBase]).
  static String get uploadEndpoint =>
      _uploadBase.isEmpty ? '$baseUrl/koraUpload' : '$_uploadBase/koraUpload';

  /// Automated detection system — monitors activity, suspends accounts,
  /// checks suspension status, and handles appeals.
  static String get autoDetectEndpoint =>
      _selfBase.isEmpty ? '$baseUrl/koraAutoDetect' : '$_selfBase/koraAutoDetect';

  /// Payment endpoint — initialize Paystack transactions.
  static String get paymentInitEndpoint =>
      _selfBase.isEmpty ? '$baseUrl/koraInitPayment' : '$_selfBase/koraInitPayment';

  /// Subscription recovery endpoint — re-check premium status from DB.
  static String get recoverSubscriptionEndpoint =>
      _selfBase.isEmpty ? '$baseUrl/koraRecoverSubscription' : '$_selfBase/koraRecoverSubscription';

  /// Payment verification endpoint — verify Paystack transactions.
  static String get paymentVerifyEndpoint =>
      _selfBase.isEmpty ? '$baseUrl/koraVerifyPayment' : '$_selfBase/koraVerifyPayment';

  /// Google Play Billing purchase verification — verifies Play Store
  /// purchases and grants premium (follows the self-hosted override).
  static String get playBillingEndpoint =>
      _selfBase.isEmpty ? '$baseUrl/koraPlayBilling' : '$_selfBase/koraPlayBilling';

  /// Chat sync endpoint — persist messages & conversations to the database.
  /// Chat sync endpoint — follows the self-hosted override (see [_chatBase]).
  static String get chatSyncEndpoint =>
      _chatBase.isEmpty ? '$baseUrl/koraChatSync' : '$_chatBase/koraChatSync';

  /// Settings sync endpoint — Telegram-style cloud settings:
  /// every preference (theme, notifications, privacy, wallpapers...)
  /// follows the account to any device automatically.
  /// Settings sync endpoint — follows the override (see [_settingsBase]).
  static String get settingsSyncEndpoint =>
      _settingsBase.isEmpty ? '$baseUrl/koraSettingsSync' : '$_settingsBase/koraSettingsSync';

  /// Kora AI Server base URL — legacy local dev server.
  /// Only the writing/reply-suggestions/summarize/transcribe/analyze
  /// endpoints below still point here (they have client-side fallbacks).
  static const String aiServerUrl = 'http://10.0.2.2:5000';

  /// Kora AI Chat & Support — live backend function (OpenRouter).
  /// Both chat and support hit the same deployed endpoint; the body's
  /// 'chatType' field ('ai' or 'support') selects the system prompt.
  static String get aiChatSupportEndpoint =>
      _selfBase.isEmpty ? '$baseUrl/koraAiChat' : '$_selfBase/koraAiChat';
  static String get aiChatEndpoint => aiChatSupportEndpoint;
  static String get aiSupportEndpoint => aiChatSupportEndpoint;
  static const String aiHealthEndpoint = '$aiServerUrl/api/ai/health';

  /// Kora AI feature endpoints (writing assistant, reply suggestions, chat summary)
  /// Now deployed as a single backend function — koraAiFeatures.
  /// Each request includes a 'feature' field: 'writing' | 'reply_suggestions' | 'summarize'.
  static String get aiFeaturesEndpoint =>
      _selfBase.isEmpty ? '$baseUrl/koraAiFeatures' : '$_selfBase/koraAiFeatures';

  /// Kora AI Orchestrator — centralized AI operation coordinator.
  /// Routes requests by intent (conversation, translation, summarization, etc.)
  /// Uses Model Adapter pattern for provider abstraction.
  static String get aiOrchestratorEndpoint =>
      _selfBase.isEmpty ? '$baseUrl/koraAiOrchestrator' : '$_selfBase/koraAiOrchestrator';

  /// Kora AI Conversation Management — server-side conversation storage.
  /// Handles: create, list, get, delete, rename conversations + messages.
  static String get aiConversationEndpoint =>
      _selfBase.isEmpty ? '$baseUrl/koraAiConversation' : '$_selfBase/koraAiConversation';

  /// Legacy endpoint aliases (kept for compatibility with existing service code).
  static String get aiWritingEndpoint => aiFeaturesEndpoint;
  static String get aiReplySuggestionsEndpoint => aiFeaturesEndpoint;
  static String get aiSummarizeChatEndpoint => aiFeaturesEndpoint;
  static String get aiTranscribeEndpoint => aiFeaturesEndpoint;
  static String get aiAnalyzeImageEndpoint => aiFeaturesEndpoint;
  static String get aiAnalyzeFileEndpoint => aiFeaturesEndpoint;

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
  static const String eulaUrl = '$legalBaseUrl/eula.html';
  static const String cookiePolicyUrl = '$legalBaseUrl/cookie-policy.html';
  static const String premiumTermsUrl = '$legalBaseUrl/premium-terms.html';
  static const String accountDeletionPolicyUrl = '$legalBaseUrl/account-deletion-policy.html';
  static const String blockingAndReportingUrl = '$legalBaseUrl/blocking-and-reporting.html';
  static const String gdprPrivacyPolicyUrl = '$legalBaseUrl/gdpr-privacy-policy.html';
  static const String supplementalTermsUrl = '$legalBaseUrl/supplemental-terms.html';
  static const String channelsGuidelinesUrl = '$legalBaseUrl/channels-guidelines.html';
  static const String faceHandsEffectsUrl = '$legalBaseUrl/face-hands-effects-privacy.html';

  /// E2EE key exchange endpoint for public key publish/lookup.
  static String get e2eeKeysEndpoint =>
      _selfBase.isEmpty ? '$baseUrl/koraE2eeKeys' : '$_selfBase/koraE2eeKeys';

  /// Push notification endpoints — FCM token registration and push delivery.
  static String get pushRegisterEndpoint =>
      _selfBase.isEmpty ? '$baseUrl/koraPushRegister' : '$_selfBase/koraPushRegister';
  static String get pushUnregisterEndpoint =>
      _selfBase.isEmpty ? '$baseUrl/koraPushUnregister' : '$_selfBase/koraPushUnregister';
  static String get pushSendEndpoint =>
      _selfBase.isEmpty ? '$baseUrl/koraPushSend' : '$_selfBase/koraPushSend';
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
  static const String blockingInfoUrl = blockingAndReportingUrl;

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

import 'package:shared_preferences/shared_preferences.dart';

import 'chat_service.dart';
import 'chat_sync_service.dart';
import 'conversation_directory.dart';
import 'incoming_call_service.dart';
import 'message_service.dart';
import 'service_notification_service.dart';
import 'settings_sync_service.dart';

/// Wipes the ACTIVE account's data from this device — used on logout,
/// account deletion, and account switching.
///
/// Kora is cloud-first: every account's chats, media, and settings live
/// on the cloud, so wiping the local copy is safe — the next account
/// (or the same account logging back in) simply pulls its own data
/// fresh from the cloud.
///
/// WITHOUT this purge, a second account logging in on the same device
/// would inherit the previous account's conversations, messages,
/// contacts, premium state, business profile, and theme — a serious
/// privacy leak between accounts.
class AccountPurgeService {
  AccountPurgeService._();
  static final AccountPurgeService instance = AccountPurgeService._();

  /// Account-scoped SharedPreferences keys that must not survive a
  /// logout/switch. Device-level keys (device id/name, backup PIN,
  /// multi-account list, one-time welcome/trial flags, network stats,
/// app lock) are intentionally KEPT.
  static const List<String> _accountKeys = [
    // Contacts & social data
    'kora_contacts',
    'kora_favorites',
    'kora_scheduled_list',
    'kora_blocked_accounts_json',
    'kora_my_stickers',

    // Identity & premium state (re-fetched from the cloud on login)
    'kora_is_premium',
    'kora_username',
    'kora_phone_number',

    // Business profile (per-account)
    'kora_business_profile',
    'kora_business_templates',
    'kora_business_labels',
    'kora_business_hours',
    'kora_business_greeting',
    'kora_business_away',
    'kora_business_catalog',

    // Theme (synced per-account via SettingsSyncService — purging it
    // also prevents the previous account's theme values from being
    // pushed into the NEXT account's cloud settings blob)
    'kora_chat_theme_id',
    'kora_app_icon_index',
    'kora_app_theme_color',
    'kora_custom_sent_bubble',
    'kora_custom_received_bubble',
    'kora_wallpaper_asset_path',
    'kora_wallpaper_image_path',
    'kora_wallpaper_color',
    'kora_wallpaper_dim_level',

    // Personal voice / translation data
    'kora_voice_uploads',
    'kora_call_recordings',
    'kora_call_feedback',
    'kora_translation_cache',
    'kora_translation_pref_lang',
    'kora_my_voice_vector',
    'kora_custom_voices',
    'kora_selected_voice',
    'kora_call_translation',

    // Per-account service state
    'kora_service_notif_last_seen',
    'kora_support_active_conversation',
    'kora_ai_active_conversation',
  ];

  /// Runs the full purge. Call BEFORE navigating away from the
  /// logged-in session, right after the session is cleared (or, when
  /// switching accounts, right before restoring the new account's
  /// data).
  Future<void> purgeActiveAccount() async {
    // 1. Stop background pollers first so nothing re-writes stale
    //    state while we're wiping.
    try { ChatSyncService.instance.stopPolling(); } catch (_) {}
    try { ServiceNotificationService.instance.dispose(); } catch (_) {}
    try { IncomingCallService.instance.stop(); } catch (_) {}
    try { SettingsSyncService.instance.stopPeriodicSync(); } catch (_) {}

    // 2. Message history — disk stores + in-memory cache.
    try { await MessageService.instance.clearAll(); } catch (_) {}

    // 3. Conversation directory — disk + in-memory entries.
    try { await ConversationDirectoryService.instance.reset(); } catch (_) {}

    // 4. Chat list in-memory cache.
    try { ChatService.instance.cachedChats = []; } catch (_) {}

    // 5. Account-scoped SharedPreferences keys.
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in _accountKeys) {
        await prefs.remove(key);
      }
    } catch (_) {}
  }
}

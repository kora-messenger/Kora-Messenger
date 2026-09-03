import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'session_manager.dart';
import 'chat_sync_service.dart';
import 'settings_sync_service.dart';
import 'account_purge_service.dart';
import 'service_notification_service.dart';
import '../theme/chat_theme_provider.dart';

/// Telegram-style multi-account manager.
///
/// Kora stores multiple logged-in accounts locally, keyed by email, and
/// tracks which one is currently "active". Switching accounts is instant —
/// no re-login required — because the full session for every added account
/// stays cached on-device.
///
/// Limits (mirrors Telegram's own account-limit mechanic, but with Kora's
/// numbers): Telegram allows 3 accounts free / 4 with Premium. Kora raises
/// this to 4 free / 6 with Premium. If ANY locally-added account has an
/// active Premium subscription, the higher limit applies device-wide —
/// same rule Telegram uses.
class AccountsManager {
  static const String _accountsKey = 'kora_accounts';
  static const String _activeEmailKey = 'kora_active_account_email';

  static const int freeAccountLimit = 4;
  static const int premiumAccountLimit = 6;

  static AccountsManager? _instance;
  static AccountsManager get instance => _instance ??= AccountsManager._();
  AccountsManager._();

  /// Returns all locally stored accounts (full session maps), most
  /// recently active first.
  Future<List<Map<String, dynamic>>> getAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_accountsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveAccounts(List<Map<String, dynamic>> accounts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accountsKey, jsonEncode(accounts));
  }

  /// Returns the email of the currently active account, if any.
  Future<String?> getActiveEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeEmailKey);
  }

  Future<void> _setActiveEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeEmailKey, email);
  }

  /// Whether any currently-stored account has an active Premium
  /// subscription. Determines the account-count ceiling for the whole
  /// device, exactly like Telegram's "any Premium account raises the
  /// limit for all of them" behavior.
  Future<bool> _anyAccountIsPremium() async {
    final accounts = await getAccounts();
    for (final acc in accounts) {
      if (acc['isPremium'] == true) return true;
    }
    return false;
  }

  /// The maximum number of accounts allowed on this device right now.
  Future<int> maxAccountsAllowed() async {
    final premium = await _anyAccountIsPremium();
    return premium ? premiumAccountLimit : freeAccountLimit;
  }

  /// Whether another account can be added right now.
  Future<bool> canAddMore() async {
    final accounts = await getAccounts();
    final max = await maxAccountsAllowed();
    return accounts.length < max;
  }

  /// Adds a new account (or updates it if the email already exists) and
  /// makes it the active account. Also mirrors it into [SessionManager]
  /// so the rest of the app (which reads SessionManager directly) sees
  /// the newly active account immediately.
  Future<void> addOrUpdateAccount(Map<String, dynamic> user) async {
    final email = (user['email'] as String?)?.toLowerCase().trim() ?? '';
    if (email.isEmpty) return;

    final accounts = await getAccounts();
    final existingIndex = accounts.indexWhere(
      (a) => (a['email'] as String?)?.toLowerCase().trim() == email,
    );

    final entry = {...user, 'email': email, '_savedAt': DateTime.now().toIso8601String()};

    if (existingIndex >= 0) {
      accounts[existingIndex] = entry;
    } else {
      accounts.add(entry);
    }

    await _saveAccounts(accounts);
    await _setActiveEmail(email);
    await SessionManager.instance.saveSession(entry);
  }

  /// Switches to an already-added account. Restarts the sync/notification
  /// services under the new email so chats, calls, and status pick up the
  /// right account's data. Returns the full session map for the account
  /// that became active, or null if the email wasn't found.
  Future<Map<String, dynamic>?> switchAccount(String email) async {
    final normalized = email.toLowerCase().trim();
    final accounts = await getAccounts();
    final match = accounts.firstWhere(
      (a) => (a['email'] as String?)?.toLowerCase().trim() == normalized,
      orElse: () => <String, dynamic>{},
    );
    if (match.isEmpty) return null;

    // Stop services for the outgoing account before swapping session data.
    ChatSyncService.instance.stopPolling();
    ServiceNotificationService.instance.dispose();

    // Wipe the outgoing account's local data (chats, messages,
    // contacts, premium state, theme) BEFORE restoring the incoming
    // account's cloud data — otherwise the two accounts' conversation
    // lists merge on this device.
    await AccountPurgeService.instance.purgeActiveAccount();

    await _setActiveEmail(normalized);
    await SessionManager.instance.saveSession(match);

    await ChatThemeProvider.instance.load();
    await ChatThemeProvider.instance.syncPremiumFromSession(match);

    ChatSyncService.instance.setUserEmail(normalized);
    ChatSyncService.instance.setSenderName((match['fullName'] as String?) ?? '');

    // Pull the new account's chats fresh from the cloud, then resume
    // live polling under the new identity.
    await ChatSyncService.instance.restoreFromCloud();
    ChatSyncService.instance.startPolling();
    // Telegram-style cloud settings for the switched account
    await SettingsSyncService.instance.syncNow();
    SettingsSyncService.instance.startPeriodicSync();
    ServiceNotificationService.instance.init();

    return match;
  }

  /// Removes a locally-added account entirely (log out of just that
  /// account, keeping the others). If it was the active account, the
  /// caller is responsible for switching to another one afterward.
  Future<void> removeAccount(String email) async {
    final normalized = email.toLowerCase().trim();
    final accounts = await getAccounts();
    accounts.removeWhere(
      (a) => (a['email'] as String?)?.toLowerCase().trim() == normalized,
    );
    await _saveAccounts(accounts);
  }

  /// One-time migration: if the legacy single-session key already has a
  /// user logged in but the multi-account list doesn't exist yet, seed
  /// the accounts list with that single session so existing users don't
  /// lose anything when this feature ships.
  Future<void> ensureMigrated() async {
    final accounts = await getAccounts();
    if (accounts.isNotEmpty) return;

    final session = await SessionManager.instance.loadSession();
    if (session == null) return;

    final email = (session['email'] as String?)?.toLowerCase().trim() ?? '';
    if (email.isEmpty) return;

    await _saveAccounts([
      {...session, 'email': email, '_savedAt': DateTime.now().toIso8601String()},
    ]);
    await _setActiveEmail(email);
  }
}

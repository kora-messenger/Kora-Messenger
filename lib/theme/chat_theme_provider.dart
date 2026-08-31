import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kora Messenger owner accounts — these always have Premium active,
/// free forever, regardless of subscription/payment status. Checked
/// against the saved session email on every app launch and login.
const Set<String> kOwnerEmails = {
  'goodluckijezie9@gmail.com',
  'ijeziegoodluck7@gmail.com',
  'ijeziegoodluck4@gmail.com',
  'ijeziegoodluck96@gmail.com',
};

/// A chat theme preset — defines bubble colors and wallpaper.
class ChatThemePreset {
  final String id;
  final String name;
  final Color sentBubble;
  final Color receivedBubble;
  final Color wallpaper;
  final Color sentTextColor;
  final Color receivedTextColor;

  const ChatThemePreset({
    required this.id,
    required this.name,
    required this.sentBubble,
    required this.receivedBubble,
    required this.wallpaper,
    this.sentTextColor = Colors.white,
    this.receivedTextColor = const Color(0xFF1A1A2E),
  });
}

/// 7 default chat themes — like WhatsApp's preset themes.
const List<ChatThemePreset> kDefaultChatThemes = [
  ChatThemePreset(
    id: 'default',
    name: 'Kora Default',
    sentBubble: Color(0xFF6C63FF),
    receivedBubble: Color(0xFFFFFFFF),
    wallpaper: Color(0xFFF7F8FC),
    sentTextColor: Colors.white,
    receivedTextColor: Color(0xFF1A1A2E),
  ),
  ChatThemePreset(
    id: 'midnight',
    name: 'Midnight',
    sentBubble: Color(0xFF4A90D9),
    receivedBubble: Color(0xFF1E293B),
    wallpaper: Color(0xFF0B1120),
    sentTextColor: Colors.white,
    receivedTextColor: Color(0xFFE2E8F0),
  ),
  ChatThemePreset(
    id: 'coral',
    name: 'Coral',
    sentBubble: Color(0xFFF97316),
    receivedBubble: Color(0xFFFFE4D6),
    wallpaper: Color(0xFFFFF5EE),
    sentTextColor: Colors.white,
    receivedTextColor: Color(0xFF7C2D12),
  ),
  ChatThemePreset(
    id: 'forest',
    name: 'Forest',
    sentBubble: Color(0xFF16A34A),
    receivedBubble: Color(0xFFD1FAE5),
    wallpaper: Color(0xFFF0FDF4),
    sentTextColor: Colors.white,
    receivedTextColor: Color(0xFF14532D),
  ),
  ChatThemePreset(
    id: 'rose',
    name: 'Rose',
    sentBubble: Color(0xFFE11D48),
    receivedBubble: Color(0xFFFFE4E6),
    wallpaper: Color(0xFFFFF1F2),
    sentTextColor: Colors.white,
    receivedTextColor: Color(0xFF881337),
  ),
  ChatThemePreset(
    id: 'ocean',
    name: 'Ocean',
    sentBubble: Color(0xFF0EA5E9),
    receivedBubble: Color(0xFFDBEAFE),
    wallpaper: Color(0xFFF0F9FF),
    sentTextColor: Colors.white,
    receivedTextColor: Color(0xFF1E3A8A),
  ),
  ChatThemePreset(
    id: 'sand',
    name: 'Sand',
    sentBubble: Color(0xFFA16207),
    receivedBubble: Color(0xFFFEF3C7),
    wallpaper: Color(0xFFFFFBEB),
    sentTextColor: Colors.white,
    receivedTextColor: Color(0xFF78350F),
  ),
];

/// The default wallpaper asset — a warm cream doodle pattern matching
/// the classic WhatsApp look. Used automatically when the active chat
/// theme is "Default".
const String kDefaultWallpaperAsset = 'assets/wallpapers/kora_default_pro.webp';

/// 20 app theme colors (Premium feature).
const List<Color> kAppThemeColors = [
  Color(0xFF8B5CF6),
  Color(0xFF3B82F6),
  Color(0xFF06B6D4),
  Color(0xFF10B981),
  Color(0xFF22C55E),
  Color(0xFF84CC16),
  Color(0xFFEAB308),
  Color(0xFFF97316),
  Color(0xFFEF4444),
  Color(0xFFEC4899),
  Color(0xFFF43F5E),
  Color(0xFFD946EF),
  Color(0xFFA855F7),
  Color(0xFF6366F1),
  Color(0xFF0EA5E9),
  Color(0xFF14B8A6),
  Color(0xFF64748B),
  Color(0xFF7C3AED),
  Color(0xFF0891B2),
  Color(0xFF4F46E5),
];

/// Light solid wallpaper colors.
const List<Color> kSolidWallpaperColors = [
  Color(0xFFFFFFFF),
  Color(0xFFF5F5FA),
  Color(0xFFECE5DD),
  Color(0xFFFFF5EE),
  Color(0xFFF0FDF4),
  Color(0xFFFFF1F2),
  Color(0xFFF0F9FF),
  Color(0xFFFFFBEB),
  Color(0xFFFAF5FF),
  Color(0xFFFDF4FF),
  Color(0xFFECFDF5),
  Color(0xFFFFF7ED),
  Color(0xFFF0FDFA),
  Color(0xFFFEF9C3),
  Color(0xFFE0F2FE),
  Color(0xFFFCE7F3),
  Color(0xFFEDE9FE),
  Color(0xFFD1FAE5),
  Color(0xFFE2E8F0),
  Color(0xFFF1F5F9),
];

/// Chat bubble colors.
const List<Color> kChatBubbleColors = [
  Color(0xFF8B5CF6),
  Color(0xFF3B82F6),
  Color(0xFF06B6D4),
  Color(0xFF10B981),
  Color(0xFF22C55E),
  Color(0xFFEAB308),
  Color(0xFFF97316),
  Color(0xFFEF4444),
  Color(0xFFEC4899),
  Color(0xFFA855F7),
  Color(0xFF6366F1),
  Color(0xFF0EA5E9),
  Color(0xFF14B8A6),
  Color(0xFF64748B),
  Color(0xFFD946EF),
  Color(0xFFF43F5E),
  Color(0xFF7C3AED),
  Color(0xFF0891B2),
  Color(0xFF4F46E5),
  Color(0xFF1A1A2E),
];

/// Centralized chat theme manager.
/// Persists: selected chat theme, custom bubble color, custom wallpaper,
/// and app theme color (Premium).
class ChatThemeProvider extends ChangeNotifier {
  static final ChatThemeProvider instance = ChatThemeProvider._();
  ChatThemeProvider._();

  static const _kThemeId = 'kora_chat_theme_id';
  static const _kCustomSentBubble = 'kora_custom_sent_bubble';
  static const _kCustomReceivedBubble = 'kora_custom_received_bubble';
  static const _kWallpaperColor = 'kora_wallpaper_color';
  static const _kWallpaperImagePath = 'kora_wallpaper_image_path';
  static const _kWallpaperAssetPath = 'kora_wallpaper_asset_path';
  static const _kWallpaperDimLevel = 'kora_wallpaper_dim_level';
  static const _kAppThemeColor = 'kora_app_theme_color';
  static const _kIsPremium = 'kora_is_premium';
  static const _kAppIconIndex = 'kora_app_icon_index';

  String _themeId = 'default';
  Color? _customSentBubble;
  Color? _customReceivedBubble;
  Color? _wallpaperColor;
  String? _wallpaperImagePath;
  String? _wallpaperAssetPath;
  double _wallpaperDimLevel = 0.0;
  Color _appThemeColor = const Color(0xFF8B5CF6);
  bool _isPremium = false;
  bool _isOwnerAccount = false;
  int _appIconIndex = 0;

  String get themeId => _themeId;
  Color? get customSentBubble => _customSentBubble;
  Color? get customReceivedBubble => _customReceivedBubble;
  Color? get wallpaperColor => _wallpaperColor;
  String? get wallpaperImagePath => _wallpaperImagePath;
  String? get wallpaperAssetPath => _wallpaperAssetPath;
  double get wallpaperDimLevel => _wallpaperDimLevel;
  Color get appThemeColor => _appThemeColor;
  bool get isPremium => _isPremium;

  /// True when the logged-in session belongs to one of the hardcoded
  /// Kora owner accounts (see [kOwnerEmails]). Owner accounts get the
  /// official purple Kora badge instead of the blue Premium badge,
  /// since they represent Kora itself rather than a paying subscriber.
  bool get isOwnerAccount => _isOwnerAccount;

  int get appIconIndex => _appIconIndex;

  /// Called after a successful payment to activate premium across the app.
  /// Updates the in-memory state, persists it, and notifies all listeners
  /// so every premium-gated screen reacts immediately.
  Future<void> markPremium() async {
    _isPremium = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kIsPremium, true);
    notifyListeners();
  }

  /// Called when premium expires or is revoked.
  Future<void> revokePremium() async {
    _isPremium = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kIsPremium, false);
    notifyListeners();
  }

  /// Syncs premium status from the backend session into local storage.
  /// Called after login/registration (and on every app launch, once a
  /// fresh profile fetch succeeds) so the device always reflects the
  /// account's true backend premium state — trial, paid, expired, or
  /// manually revoked by an admin. The backend is always the source of
  /// truth here; a stale local cache must never keep showing Premium
  /// once the backend says it's gone.
  Future<void> syncPremiumFromSession(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();

    // Owner accounts are always premium
    final email = (userData['email'] as String?)?.toLowerCase().trim() ?? '';
    if (kOwnerEmails.contains(email)) {
      _isPremium = true;
      _isOwnerAccount = true;
      await prefs.setBool(_kIsPremium, true);
      notifyListeners();
      return;
    }
    _isOwnerAccount = false;

    final isPremium = userData['isPremium'] == true;
    final premiumExpiresAt = userData['premiumExpiresAt'] as String?;
    final premiumSource = userData['premiumSource'] as String? ?? '';

    if (isPremium) {
      _isPremium = true;
      await prefs.setBool(_kIsPremium, true);
      await prefs.setBool('is_premium', true); // legacy key some code reads
      // Sync the expiry from the backend so it persists across devices
      if (premiumExpiresAt != null) {
        final expiryMs = DateTime.parse(premiumExpiresAt).millisecondsSinceEpoch;
        await prefs.setInt('premium_expiry', expiryMs);
      } else {
        await prefs.remove('premium_expiry');
      }
      if (premiumSource.isNotEmpty) {
        await prefs.setString('premium_plan', premiumSource);
      }
    } else {
      // Backend says this account is NOT premium — revoke locally too,
      // even if a stale local trial/payment flag or a not-yet-expired
      // cached expiry timestamp says otherwise. Clears every key any
      // premium-checking code path reads (ChatThemeProvider + legacy
      // PaymentService keys) so nothing can keep showing Premium.
      _isPremium = false;
      await prefs.setBool(_kIsPremium, false);
      await prefs.setBool('is_premium', false);
      await prefs.remove('premium_expiry');
      await prefs.remove('premium_plan');
      await prefs.remove('premium_payment_ref');
      await prefs.remove('premium_activated_at');
    }
    notifyListeners();
  }

  ChatThemePreset get activeTheme {
    final preset = kDefaultChatThemes.firstWhere(
      (t) => t.id == _themeId,
      orElse: () => kDefaultChatThemes[0],
    );
    return ChatThemePreset(
      id: preset.id,
      name: preset.name,
      sentBubble: _customSentBubble ?? preset.sentBubble,
      receivedBubble: _customReceivedBubble ?? preset.receivedBubble,
      wallpaper: _wallpaperColor ?? preset.wallpaper,
      sentTextColor: preset.sentTextColor,
      receivedTextColor: preset.receivedTextColor,
    );
  }

  /// Whether the active theme should use the default doodle wallpaper
  /// asset. True when the user is on the "default" theme AND hasn't
  /// set a custom wallpaper (image, asset, or solid color override).
  bool get usesDefaultWallpaperAsset {
    if (_themeId != 'default') return false;
    if (_wallpaperImagePath != null) return false;
    if (_wallpaperAssetPath != null) return false;
    if (_wallpaperColor != null) return false;
    return true;
  }

  /// The default wallpaper asset path (the milk doodle pattern).
  /// Used by the chat screen when [usesDefaultWallpaperAsset] is true.
  String get defaultWallpaperAsset => kDefaultWallpaperAsset;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _themeId = prefs.getString(_kThemeId) ?? 'default';
    final sentVal = prefs.getInt(_kCustomSentBubble);
    _customSentBubble = sentVal != null ? Color(sentVal) : null;
    final recvVal = prefs.getInt(_kCustomReceivedBubble);
    _customReceivedBubble = recvVal != null ? Color(recvVal) : null;
    final wallVal = prefs.getInt(_kWallpaperColor);
    _wallpaperColor = wallVal != null ? Color(wallVal) : null;
    _wallpaperImagePath = prefs.getString(_kWallpaperImagePath);
    _wallpaperAssetPath = prefs.getString(_kWallpaperAssetPath);
    _wallpaperDimLevel = prefs.getDouble(_kWallpaperDimLevel) ?? 0.0;
    final appVal = prefs.getInt(_kAppThemeColor);
    _appThemeColor = appVal != null ? Color(appVal) : const Color(0xFF8B5CF6);
    _isPremium = prefs.getBool(_kIsPremium) ?? false;
    _appIconIndex = prefs.getInt(_kAppIconIndex) ?? 0;

    // Owner accounts are always Premium — free forever — and get the
    // official Kora badge instead of the Premium subscriber badge.
    _isOwnerAccount = _isOwnerSession(prefs);
    if (_isOwnerAccount) {
      _isPremium = true;
    } else if (_isPremium) {
      // Non-owner: check if premium has expired.
      // PaymentService stores expiry as millisecondsSinceEpoch in 'premium_expiry'.
      // MessageService trial stores it the same way.
      // A value of 0 means "never expires" (owner override set elsewhere).
      final expiryMs = prefs.getInt('premium_expiry') ?? 0;
      if (expiryMs > 0) {
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now > expiryMs) {
          // Premium expired — lock all premium features.
          _isPremium = false;
          prefs.setBool(_kIsPremium, false);
          // Also clear the legacy key if present.
          prefs.setBool('is_premium', false);
        }
      }
    }

    notifyListeners();
  }

  /// Checks the saved login session against the hardcoded owner email
  /// list. Owner accounts always get Premium, no subscription needed.
  bool _isOwnerSession(SharedPreferences prefs) {
    try {
      final raw = prefs.getString('kora_session');
      if (raw == null || raw.isEmpty) return false;
      final session = jsonDecode(raw) as Map<String, dynamic>;
      final email = (session['email'] as String?)?.toLowerCase().trim();
      return email != null && kOwnerEmails.contains(email);
    } catch (_) {
      return false;
    }
  }

  Future<void> setChatTheme(String id) async {
    _themeId = id;
    _customSentBubble = null;
    _customReceivedBubble = null;
    _wallpaperColor = null;
    _wallpaperImagePath = null;
    _wallpaperAssetPath = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeId, id);
    await prefs.remove(_kCustomSentBubble);
    await prefs.remove(_kCustomReceivedBubble);
    await prefs.remove(_kWallpaperColor);
    await prefs.remove(_kWallpaperImagePath);
    await prefs.remove(_kWallpaperAssetPath);
    notifyListeners();
  }

  Future<void> setCustomSentBubble(Color color) async {
    _customSentBubble = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kCustomSentBubble, color.toARGB32());
    notifyListeners();
  }

  Future<void> setCustomReceivedBubble(Color color) async {
    _customReceivedBubble = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kCustomReceivedBubble, color.toARGB32());
    notifyListeners();
  }

  Future<void> setWallpaperColor(Color color) async {
    _wallpaperColor = color;
    _wallpaperImagePath = null;
    _wallpaperAssetPath = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kWallpaperColor, color.toARGB32());
    await prefs.remove(_kWallpaperImagePath);
    await prefs.remove(_kWallpaperAssetPath);
    notifyListeners();
  }

  Future<void> setWallpaperImage(String path) async {
    _wallpaperImagePath = path;
    _wallpaperColor = null;
    _wallpaperAssetPath = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kWallpaperImagePath, path);
    await prefs.remove(_kWallpaperColor);
    await prefs.remove(_kWallpaperAssetPath);
    notifyListeners();
  }

  /// Applies a bundled preset wallpaper (asset image shipped with the app).
  Future<void> setWallpaperAsset(String assetPath) async {
    _wallpaperAssetPath = assetPath;
    _wallpaperColor = null;
    _wallpaperImagePath = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kWallpaperAssetPath, assetPath);
    await prefs.remove(_kWallpaperColor);
    await prefs.remove(_kWallpaperImagePath);
    notifyListeners();
  }

  /// Adjusts how much the wallpaper is dimmed (0 = full brightness,
  /// 1 = fully dark), similar to WhatsApp's wallpaper brightness slider.
  Future<void> setWallpaperDimLevel(double value) async {
    _wallpaperDimLevel = value.clamp(0.0, 1.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kWallpaperDimLevel, _wallpaperDimLevel);
    notifyListeners();
  }

  Future<void> setAppThemeColor(Color color) async {
    if (!_isPremium) return;
    _appThemeColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kAppThemeColor, color.toARGB32());
    notifyListeners();
  }

  Future<void> resetAppTheme() async {
    _appThemeColor = const Color(0xFF8B5CF6);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAppThemeColor);
    notifyListeners();
  }

  Future<void> setAppIcon(int index) async {
    if (!_isPremium) return;
    _appIconIndex = index;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kAppIconIndex, index);
    notifyListeners();
  }

  /// Resets the app icon back to the free Default icon (index 0).
  /// Always allowed — no Premium needed to go back to Default.
  Future<void> resetAppIcon() async {
    _appIconIndex = 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kAppIconIndex, 0);
    notifyListeners();
  }

  Future<void> setPremium(bool value) async {
    _isPremium = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kIsPremium, value);
    notifyListeners();
  }
}

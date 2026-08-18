import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    name: 'Default',
    sentBubble: Color(0xFF8B5CF6),
    receivedBubble: Color(0xFFFFFFFF),
    wallpaper: Color(0xFFECE5DD),
    sentTextColor: Colors.white,
    receivedTextColor: Color(0xFF1A1A2E),
  ),
  ChatThemePreset(
    id: 'midnight',
    name: 'Midnight',
    sentBubble: Color(0xFF6366F1),
    receivedBubble: Color(0xFF1E293B),
    wallpaper: Color(0xFF0F172A),
    sentTextColor: Colors.white,
    receivedTextColor: Colors.white,
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
  static const _kAppThemeColor = 'kora_app_theme_color';
  static const _kIsPremium = 'kora_is_premium';
  static const _kAppIconIndex = 'kora_app_icon_index';

  String _themeId = 'default';
  Color? _customSentBubble;
  Color? _customReceivedBubble;
  Color? _wallpaperColor;
  String? _wallpaperImagePath;
  Color _appThemeColor = const Color(0xFF8B5CF6);
  bool _isPremium = false;
  int _appIconIndex = 0;

  String get themeId => _themeId;
  Color? get customSentBubble => _customSentBubble;
  Color? get customReceivedBubble => _customReceivedBubble;
  Color? get wallpaperColor => _wallpaperColor;
  String? get wallpaperImagePath => _wallpaperImagePath;
  Color get appThemeColor => _appThemeColor;
  bool get isPremium => _isPremium;
  int get appIconIndex => _appIconIndex;

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
    final appVal = prefs.getInt(_kAppThemeColor);
    _appThemeColor = appVal != null ? Color(appVal) : const Color(0xFF8B5CF6);
    _isPremium = prefs.getBool(_kIsPremium) ?? false;
    _appIconIndex = prefs.getInt(_kAppIconIndex) ?? 0;
    notifyListeners();
  }

  Future<void> setChatTheme(String id) async {
    _themeId = id;
    _customSentBubble = null;
    _customReceivedBubble = null;
    _wallpaperColor = null;
    _wallpaperImagePath = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeId, id);
    await prefs.remove(_kCustomSentBubble);
    await prefs.remove(_kCustomReceivedBubble);
    await prefs.remove(_kWallpaperColor);
    await prefs.remove(_kWallpaperImagePath);
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kWallpaperColor, color.toARGB32());
    await prefs.remove(_kWallpaperImagePath);
    notifyListeners();
  }

  Future<void> setWallpaperImage(String path) async {
    _wallpaperImagePath = path;
    _wallpaperColor = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kWallpaperImagePath, path);
    await prefs.remove(_kWallpaperColor);
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

  Future<void> setPremium(bool value) async {
    _isPremium = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kIsPremium, value);
    notifyListeners();
  }
}

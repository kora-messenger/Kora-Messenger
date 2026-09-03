import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/kora_colors.dart';
import '../../theme/chat_theme_provider.dart';
import '../archived_chats_screen.dart';
import 'chat_transfer_screen.dart';
import 'default_chat_theme_screen.dart';
import 'wallpaper_screen.dart';

/// Chat settings screen — matches WhatsApp's Settings > Chats layout.
///
/// Sections: Display, Archived Chats, Chat History, Media Visibility,
/// Messages, Calls.
class ChatSettingsScreen extends StatefulWidget {
  const ChatSettingsScreen({super.key});

  @override
  State<ChatSettingsScreen> createState() => _ChatSettingsScreenState();
}

class _ChatSettingsScreenState extends State<ChatSettingsScreen> {
  bool _keepArchived = true;
  bool _mediaVisibility = true;
  bool _enterIsSend = false;
  bool _showCallHistory = true;
  bool _isLoading = true;
  String _themeMode = 'system';
  String _mediaQuality = 'auto';

  final _themeProvider = ChatThemeProvider.instance;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _themeProvider.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _themeProvider.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _keepArchived = prefs.getBool('keep_chats_archived') ?? true;
        _mediaVisibility = prefs.getBool('media_visibility') ?? true;
        _enterIsSend = prefs.getBool('enter_is_send') ?? false;
        _showCallHistory = prefs.getBool('show_call_history') ?? true;
        _themeMode = prefs.getString('theme_mode') ?? 'system';
        _mediaQuality = prefs.getString('media_upload_quality') ?? 'auto';
        _isLoading = false;
      });
    }
  }

  Future<void> _setPref(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _setStringPref(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final card = KoraColors.cardFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);
    final border = KoraColors.borderFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          'Chats',
          style: TextStyle(
            color: textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: KoraColors.purple))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              children: [
                _sectionLabel('DISPLAY', textMuted),
                _themeRow(context, card, textPrimary, textSecondary, textMuted, border),
                _navTile(
                  context,
                  icon: Icons.wallpaper_rounded,
                  title: 'Wallpaper',
                  card: card,
                  textPrimary: textPrimary,
                  textMuted: textMuted,
                  border: border,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const WallpaperScreen()),
                  ),
                ),
                _navTile(
                  context,
                  icon: Icons.palette_outlined,
                  title: 'Default chat theme',
                  card: card,
                  textPrimary: textPrimary,
                  textMuted: textMuted,
                  border: border,
                  trailing: _chatThemeSwatch(),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DefaultChatThemeScreen()),
                  ),
                ),

                const SizedBox(height: 24),

                _sectionLabel('ARCHIVED CHATS', textMuted),
                _navTile(
                  context,
                  icon: Icons.archive_outlined,
                  title: 'Archived chats',
                  card: card,
                  textPrimary: textPrimary,
                  textMuted: textMuted,
                  border: border,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ArchivedChatsScreen()),
                  ),
                ),
                _toggleTile(
                  icon: Icons.lock_outline_rounded,
                  title: 'Keep chats archived',
                  subtitle: 'Archived chats will stay archived when new messages arrive',
                  value: _keepArchived,
                  card: card,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  textMuted: textMuted,
                  border: border,
                  onChanged: (v) {
                    setState(() => _keepArchived = v);
                    _setPref('keep_chats_archived', v);
                  },
                ),

                const SizedBox(height: 24),

                _sectionLabel('CHAT HISTORY', textMuted),
                _navTile(
                  context,
                  icon: Icons.qr_code_scanner_rounded,
                  title: 'Transfer chat',
                  card: card,
                  textPrimary: textPrimary,
                  textMuted: textMuted,
                  border: border,
                  onTap: () => _transferChat(context),
                ),
                _navTile(
                  context,
                  icon: Icons.ios_share_rounded,
                  title: 'Export chat',
                  card: card,
                  textPrimary: textPrimary,
                  textMuted: textMuted,
                  border: border,
                  onTap: () => _exportChat(context),
                ),
                _navTile(
                  context,
                  icon: Icons.cleaning_services_rounded,
                  title: 'Clear all chats',
                  card: card,
                  textPrimary: textPrimary,
                  textMuted: textMuted,
                  border: border,
                  iconColor: KoraColors.red,
                  titleColor: KoraColors.red,
                  onTap: () => _confirmClearAll(context),
                ),
                _navTile(
                  context,
                  icon: Icons.delete_outline_rounded,
                  title: 'Delete all chats',
                  card: card,
                  textPrimary: textPrimary,
                  textMuted: textMuted,
                  border: border,
                  iconColor: KoraColors.red,
                  titleColor: KoraColors.red,
                  onTap: () => _confirmDeleteAll(context),
                ),

                const SizedBox(height: 24),

                _sectionLabel('MEDIA VISIBILITY', textMuted),
                _toggleTile(
                  icon: Icons.image_outlined,
                  title: 'Show recently downloaded media',
                  subtitle: 'Newly downloaded media will appear in your gallery',
                  value: _mediaVisibility,
                  card: card,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  textMuted: textMuted,
                  border: border,
                  onChanged: (v) {
                    setState(() => _mediaVisibility = v);
                    _setPref('media_visibility', v);
                  },
                ),

                const SizedBox(height: 24),

                _sectionLabel('MESSAGES', textMuted),
                _toggleTile(
                  icon: Icons.keyboard_return_rounded,
                  title: 'Enter is send',
                  subtitle: 'Enter key will send your message',
                  value: _enterIsSend,
                  card: card,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  textMuted: textMuted,
                  border: border,
                  onChanged: (v) {
                    setState(() => _enterIsSend = v);
                    _setPref('enter_is_send', v);
                  },
                ),
                _navTile(
                  context,
                  icon: Icons.hd_outlined,
                  title: 'Media upload quality',
                  card: card,
                  textPrimary: textPrimary,
                  textMuted: textMuted,
                  border: border,
                  trailing: Text(
                    _mediaQualityLabel(_mediaQuality),
                    style: TextStyle(color: textSecondary, fontSize: 13),
                  ),
                  onTap: () => _showQualityPicker(context, card, textPrimary, textSecondary, textMuted, border),
                ),



                const SizedBox(height: 24),

                _sectionLabel('CALLS', textMuted),
                _toggleTile(
                  icon: Icons.phone_outlined,
                  title: 'Show call history',
                  subtitle: 'Show call info in chats',
                  value: _showCallHistory,
                  card: card,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  textMuted: textMuted,
                  border: border,
                  onChanged: (v) {
                    setState(() => _showCallHistory = v);
                    _setPref('show_call_history', v);
                  },
                ),

                const SizedBox(height: 24),
              ],
            ),
    );
  }

  String _themeLabel(String mode) {
    switch (mode) {
      case 'light':
        return 'Light';
      case 'dark':
        return 'Dark';
      default:
        return 'System default';
    }
  }

  String _mediaQualityLabel(String q) {
    switch (q) {
      case 'standard':
        return 'Standard';
      case 'best':
        return 'Best quality';
      default:
        return 'Auto';
    }
  }

  Widget _sectionLabel(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 0, 10),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _navTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color card,
    required Color textPrimary,
    required Color textMuted,
    required Color border,
    Color iconColor = KoraColors.purple,
    Color? titleColor,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: 0.5),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 19),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: titleColor ?? textPrimary,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (trailing != null) trailing,
              if (trailing == null && onTap != null)
                Icon(Icons.chevron_right, color: textMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toggleTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Color card,
    required Color textPrimary,
    required Color textSecondary,
    required Color textMuted,
    required Color border,
    Color iconColor = KoraColors.purple,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 19),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: textSecondary, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Switch.adaptive(
              value: value,
              activeColor: KoraColors.purple,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _themeRow(
    BuildContext context,
    Color card,
    Color textPrimary,
    Color textSecondary,
    Color textMuted,
    Color border,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: InkWell(
        onTap: () => _showThemePicker(context, card, textPrimary, textSecondary, textMuted, border),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: 0.5),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: KoraColors.purple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.brightness_6_outlined, color: KoraColors.purple, size: 19),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Theme',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                _themeLabel(_themeMode),
                style: TextStyle(color: textSecondary, fontSize: 13.5),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right, color: textMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showThemePicker(
    BuildContext context,
    Color card,
    Color textPrimary,
    Color textSecondary,
    Color textMuted,
    Color border,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: KoraColors.backgroundFor(Theme.of(context).brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Theme',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _themeOption(ctx, 'System default', 'system', Icons.brightness_auto_outlined, textPrimary, textSecondary),
              _themeOption(ctx, 'Light', 'light', Icons.light_mode_outlined, textPrimary, textSecondary),
              _themeOption(ctx, 'Dark', 'dark', Icons.dark_mode_outlined, textPrimary, textSecondary),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _themeOption(
    BuildContext ctx,
    String label,
    String value,
    IconData icon,
    Color textPrimary,
    Color textSecondary,
  ) {
    final selected = _themeMode == value;
    return ListTile(
      leading: Icon(icon, color: selected ? KoraColors.purple : textSecondary, size: 22),
      title: Text(
        label,
        style: TextStyle(
          color: selected ? KoraColors.purple : textPrimary,
          fontSize: 15.5,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      trailing: selected
          ? Icon(Icons.check_circle, color: KoraColors.purple, size: 22)
          : Icon(Icons.radio_button_unchecked, color: textSecondary, size: 20),
      onTap: () {
        setState(() => _themeMode = value);
        _setStringPref('theme_mode', value);
        Navigator.pop(ctx);
      },
    );
  }

  void _showQualityPicker(
    BuildContext context,
    Color card,
    Color textPrimary,
    Color textSecondary,
    Color textMuted,
    Color border,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: KoraColors.backgroundFor(Theme.of(context).brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Media upload quality',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _qualityOption(ctx, 'Auto', 'auto', textPrimary, textSecondary, 'Best for most media'),
              _qualityOption(ctx, 'Standard', 'standard', textPrimary, textSecondary, 'Faster, uses less data'),
              _qualityOption(ctx, 'Best quality', 'best', textPrimary, textSecondary, 'Highest resolution'),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _qualityOption(
    BuildContext ctx,
    String label,
    String value,
    Color textPrimary,
    Color textSecondary,
    String desc,
  ) {
    final selected = _mediaQuality == value;
    return ListTile(
      title: Text(
        label,
        style: TextStyle(
          color: selected ? KoraColors.purple : textPrimary,
          fontSize: 15.5,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      subtitle: Text(desc, style: TextStyle(color: textSecondary, fontSize: 12.5)),
      trailing: selected
          ? Icon(Icons.check_circle, color: KoraColors.purple, size: 22)
          : Icon(Icons.radio_button_unchecked, color: textSecondary, size: 20),
      onTap: () {
        setState(() => _mediaQuality = value);
        _setStringPref('media_upload_quality', value);
        Navigator.pop(ctx);
      },
    );
  }

  Widget _chatThemeSwatch() {
    final theme = _themeProvider.activeTheme;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: theme.wallpaper,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06), width: 0.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 14,
            height: 4,
            margin: const EdgeInsets.only(left: 4),
            decoration: BoxDecoration(
              color: theme.receivedBubble,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 3),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              width: 18,
              height: 4,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: theme.sentBubble,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _exportChat(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    showModalBottomSheet(
      context: context,
      backgroundColor: KoraColors.surfaceFor(brightness),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        final textPrimary = KoraColors.textPrimaryFor(brightness);
        final textMuted = KoraColors.textMutedFor(brightness);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 36, height: 4, decoration: BoxDecoration(color: textMuted.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text('Export Chat', style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('Select a chat to export. Choose whether to include media files.',
                  style: TextStyle(color: textMuted, fontSize: 14), textAlign: TextAlign.center),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.chat, color: KoraColors.purple),
              title: Text('Export with media', style: TextStyle(color: textPrimary)),
              subtitle: Text('Includes photos, videos, and documents', style: TextStyle(color: textMuted, fontSize: 13)),
              onTap: () { Navigator.pop(ctx); _performExport(context, true); },
            ),
            ListTile(
              leading: Icon(Icons.description_outlined, color: KoraColors.purple),
              title: Text('Export without media', style: TextStyle(color: textPrimary)),
              subtitle: Text('Text messages only (smaller file)', style: TextStyle(color: textMuted, fontSize: 13)),
              onTap: () { Navigator.pop(ctx); _performExport(context, false); },
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  void _performExport(BuildContext context, bool withMedia) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(withMedia ? 'Exporting chat with media...' : 'Exporting chat (text only)...'),
        backgroundColor: KoraColors.purple,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'Share',
          textColor: Colors.white,
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _transferChat(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChatTransferScreen()),
    );
  }

  void _confirmClearAll(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KoraColors.cardFor(brightness),
        title: Text(
          'Clear all chats?',
          style: TextStyle(color: KoraColors.textPrimaryFor(brightness)),
        ),
        content: Text(
          'This will permanently delete all messages from all conversations. This cannot be undone.',
          style: TextStyle(color: KoraColors.textSecondaryFor(brightness)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: KoraColors.textSecondaryFor(brightness)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('All chats cleared'),
                  backgroundColor: KoraColors.purple,
                ),
              );
            },
            child: const Text('Clear', style: TextStyle(color: KoraColors.red)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAll(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KoraColors.cardFor(brightness),
        title: Text(
          'Delete all chats?',
          style: TextStyle(color: KoraColors.textPrimaryFor(brightness)),
        ),
        content: Text(
          'This will permanently delete all conversations, including messages, media, and contacts. This cannot be undone.',
          style: TextStyle(color: KoraColors.textSecondaryFor(brightness)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: KoraColors.textSecondaryFor(brightness)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('All chats deleted'),
                  backgroundColor: KoraColors.red,
                ),
              );
            },
            child: const Text('Delete', style: TextStyle(color: KoraColors.red)),
          ),
        ],
      ),
    );
  }
}

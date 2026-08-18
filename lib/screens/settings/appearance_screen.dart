import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import '../../theme/chat_theme_provider.dart';
import 'default_chat_theme_screen.dart';
import 'chat_bubble_color_screen.dart';
import 'wallpaper_screen.dart';
import 'app_theme_screen.dart';

/// Appearance settings — chat themes, bubble colors, wallpaper, app theme.
class AppearanceScreen extends StatefulWidget {
  const AppearanceScreen({super.key});

  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen> {
  final _themeProvider = ChatThemeProvider.instance;

  @override
  void initState() {
    super.initState();
    _themeProvider.addListener(_onChanged);
  }

  @override
  void dispose() {
    _themeProvider.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);
    final border = KoraColors.borderFor(brightness);
    final card = KoraColors.cardFor(brightness);

    final theme = _themeProvider.activeTheme;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        
        title: Text(
          'Appearance',
          style: TextStyle(
            color: textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            // ── Default chat theme ──
            _sectionLabel('DEFAULT CHAT THEME', textMuted),
            const SizedBox(height: 8),
            _themeCard(
              context,
              brightness: brightness,
              card: card,
              border: border,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              theme: theme,
            ),
            const SizedBox(height: 28),

            // ── Customize ──
            _sectionLabel('CUSTOMIZE', textMuted),
            const SizedBox(height: 8),
            _settingTile(
              brightness: brightness,
              card: card,
              border: border,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              icon: Icons.chat_bubble_outline,
              iconColor: _themeProvider.customSentBubble ?? theme.sentBubble,
              title: 'Chat bubble',
              subtitle: 'Choose a color for your chat bubbles',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChatBubbleColorScreen()),
                );
              },
            ),
            const SizedBox(height: 8),
            _settingTile(
              brightness: brightness,
              card: card,
              border: border,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              icon: Icons.image_outlined,
              iconColor: KoraColors.purple,
              title: 'Wallpaper',
              subtitle: 'Choose from gallery or solid color',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WallpaperScreen()),
                );
              },
            ),
            const SizedBox(height: 28),

            // ── Kora Premium ──
            _sectionLabel('KORA PREMIUM', textMuted),
            const SizedBox(height: 8),
            _settingTile(
              brightness: brightness,
              card: card,
              border: border,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              icon: Icons.palette_outlined,
              iconColor: _themeProvider.appThemeColor,
              title: 'App theme',
              subtitle: _themeProvider.isPremium
                  ? 'Choose from 20 premium colors'
                  : 'Premium feature — unlock to customize',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AppThemeScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
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

  Widget _themeCard(
    BuildContext context, {
    required Brightness brightness,
    required Color card,
    required Color border,
    required Color textPrimary,
    required Color textSecondary,
    required ChatThemePreset theme,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DefaultChatThemeScreen()),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border, width: 0.5),
        ),
        child: Column(
          children: [
            // Mini chat preview
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.wallpaper,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Column(
                children: [
                  // Received bubble
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: theme.receivedBubble,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(14),
                          topRight: Radius.circular(14),
                          bottomRight: Radius.circular(14),
                          bottomLeft: Radius.circular(4),
                        ),
                      ),
                      child: Text(
                        'Hey! How are you?',
                        style: TextStyle(
                          color: theme.receivedTextColor,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Sent bubble
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: theme.sentBubble,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(14),
                          topRight: Radius.circular(14),
                          bottomLeft: Radius.circular(14),
                          bottomRight: Radius.circular(4),
                        ),
                      ),
                      child: Text(
                        'I\'m great, thanks!',
                        style: TextStyle(
                          color: theme.sentTextColor,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Label
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(Icons.gradient, color: KoraColors.purple, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Default chat theme',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'The chat bubble and wallpaper will both change.',
                          style: TextStyle(color: textSecondary, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: textSecondary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingTile({
    required Brightness brightness,
    required Color card,
    required Color border,
    required Color textPrimary,
    required Color textSecondary,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: card,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: 0.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 15,
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
              Icon(Icons.chevron_right, color: textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../../theme/kora_colors.dart';
import '../../theme/chat_theme_provider.dart';
import 'default_chat_theme_screen.dart';
import 'app_theme_screen.dart';
import 'app_icon_screen.dart';
import 'premium_subscribe_sheet.dart';
import 'billing_screen.dart';

/// Appearance settings — entry point for chat theme, app icon, and
/// app theme. Wallpaper and chat bubble color now live inside the
/// "Default chat theme" screen, since changing either one is really
/// part of customizing the chat theme.
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

  void _showPremiumSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (context) => const PremiumSubscribeSheet(),
    ).then((result) {
      if (result == true && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BillingScreen()),
        );
      }
    });
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
    final isPremium = _themeProvider.isPremium;
    final selectedIcon = kKoraIconDefs[_themeProvider.appIconIndex];

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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // ── Default chat theme ──
            _row(
              card: card,
              border: border,
              icon: Icons.chat_outlined,
              iconColor: KoraColors.purple,
              title: 'Default chat theme',
              textPrimary: textPrimary,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DefaultChatThemeScreen()),
                );
              },
              trailing: _chatThemePreview(theme),
            ),
            const SizedBox(height: 28),

            // ── Kora Premium ──
            Row(
              children: [
                Icon(Icons.workspace_premium_rounded, color: KoraColors.purple, size: 15),
                const SizedBox(width: 6),
                Text(
                  'KORA PREMIUM',
                  style: TextStyle(
                    color: textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _row(
              card: card,
              border: border,
              icon: Icons.apps_outlined,
              iconColor: KoraColors.purple,
              title: 'App icon',
              textPrimary: textPrimary,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AppIconScreen()),
                );
              },
              trailing: _appIconPreview(selectedIcon),
            ),
            const SizedBox(height: 8),
            _row(
              card: card,
              border: border,
              icon: Icons.palette_outlined,
              iconColor: KoraColors.purple,
              title: 'App theme',
              textPrimary: textPrimary,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AppThemeScreen()),
                );
              },
              trailing: _appThemePreview(_themeProvider.appThemeColor),
            ),

            if (!isPremium) ...[
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(color: textSecondary, fontSize: 13, height: 1.4),
                    children: [
                      const TextSpan(
                        text: 'Subscribe to Kora Premium to change your app icon, theme and more. ',
                      ),
                      TextSpan(
                        text: 'Explore benefits',
                        style: const TextStyle(color: KoraColors.purple, fontWeight: FontWeight.w700),
                        recognizer: TapGestureRecognizer()..onTap = _showPremiumSheet,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row({
    required Color card,
    required Color border,
    required IconData icon,
    required Color iconColor,
    required String title,
    required Color textPrimary,
    required VoidCallback onTap,
    required Widget trailing,
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
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }

  /// Small preview swatch for "Default chat theme" — mimics a tiny
  /// chat view using the active theme's wallpaper + bubble colors.
  Widget _chatThemePreview(ChatThemePreset theme) {
    return Container(
      width: 40,
      height: 40,
      padding: const EdgeInsets.all(5),
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
            width: 16,
            height: 5,
            decoration: BoxDecoration(
              color: theme.receivedBubble,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 3),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              width: 20,
              height: 5,
              decoration: BoxDecoration(
                color: theme.sentBubble,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Small preview thumbnail for "App icon" — shows the currently
  /// selected Kora icon's gradient or asset image.
  Widget _appIconPreview(KoraIconDef icon) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 32,
        height: 32,
        child: icon.assetPath != null
            ? Image.asset(icon.assetPath!, fit: BoxFit.cover)
            : Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: icon.gradient!,
                  ),
                ),
                child: const Center(
                  child: Text(
                    'K',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  /// Small color-circle preview for "App theme".
  Widget _appThemePreview(Color color) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black.withValues(alpha: 0.06), width: 0.5),
      ),
    );
  }
}

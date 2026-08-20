import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import '../../theme/chat_theme_provider.dart';
import 'wallpaper_screen.dart';
import 'chat_bubble_color_screen.dart';
import 'chat_theme_preview_screen.dart';

/// Shows the 7 default chat themes, plus the Wallpaper and Chat bubble
/// customization tiles (moved here from the Appearance screen — both
/// are really about customizing the chat theme, so they belong together).
class DefaultChatThemeScreen extends StatefulWidget {
  const DefaultChatThemeScreen({super.key});

  @override
  State<DefaultChatThemeScreen> createState() => _DefaultChatThemeScreenState();
}

class _DefaultChatThemeScreenState extends State<DefaultChatThemeScreen> {
  final _provider = ChatThemeProvider.instance;

  @override
  void initState() {
    super.initState();
    _provider.addListener(_onChanged);
  }

  @override
  void dispose() {
    _provider.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  void _openPreview(int index) {
    final backgrounds = kDefaultChatThemes
        .map((t) => PreviewBackground(color: t.wallpaper, bubbleColor: t.sentBubble))
        .toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatThemePreviewScreen(
          backgrounds: backgrounds,
          initialIndex: index,
          initialBubbleColor: kDefaultChatThemes[index].sentBubble,
          hintText: 'Swipe left or right to preview more themes ✨',
          onApply: (bg, bubbleColor, dimLevel) {
            final matchIndex = kDefaultChatThemes.indexWhere(
              (t) => bg.color != null && t.wallpaper.toARGB32() == bg.color!.toARGB32(),
            );
            final matched = matchIndex != -1 ? kDefaultChatThemes[matchIndex] : kDefaultChatThemes[index];
            _provider.setChatTheme(matched.id);
            if (bubbleColor.toARGB32() != matched.sentBubble.toARGB32()) {
              _provider.setCustomSentBubble(bubbleColor);
            }
            _provider.setWallpaperDimLevel(dimLevel);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final card = KoraColors.cardFor(brightness);
    final border = KoraColors.borderFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);

    final theme = _provider.activeTheme;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          'Default chat theme',
          style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Text(
                'The chat bubble and wallpaper will both change.',
                style: TextStyle(color: textSecondary, fontSize: 13),
              ),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.82,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              ),
              itemCount: kDefaultChatThemes.length,
              itemBuilder: (context, index) {
                final t = kDefaultChatThemes[index];
                final isSelected = _provider.themeId == t.id;
                return _themeCard(
                  context,
                  theme: t,
                  isSelected: isSelected,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  onTap: () => _openPreview(index),
                );
              },
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'CUSTOMIZE',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            _customizeTile(
              context,
              card: card,
              border: border,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              icon: Icons.chat_bubble_outline,
              iconColor: _provider.customSentBubble ?? theme.sentBubble,
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
            _customizeTile(
              context,
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
          ],
        ),
      ),
    );
  }

  Widget _customizeTile(
    BuildContext context, {
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

  Widget _themeCard(
    BuildContext context, {
    required ChatThemePreset theme,
    required bool isSelected,
    required Color textPrimary,
    required Color textSecondary,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? KoraColors.purple : Colors.transparent,
            width: 2.5,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: theme.wallpaper,
            borderRadius: BorderRadius.circular(13),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Mini chat preview
              Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.receivedBubble,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                          bottomLeft: Radius.circular(4),
                        ),
                      ),
                      child: Text(
                        'Hi there!',
                        style: TextStyle(color: theme.receivedTextColor, fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.sentBubble,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(4),
                        ),
                      ),
                      child: Text(
                        'Hello!',
                        style: TextStyle(color: theme.sentTextColor, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
              // Label + check
              Row(
                children: [
                  Expanded(
                    child: Text(
                      theme.name,
                      style: TextStyle(
                        color: theme.wallpaper.computeLuminance() > 0.5
                            ? const Color(0xFF1A1A2E)
                            : Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: KoraColors.purple,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 14),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

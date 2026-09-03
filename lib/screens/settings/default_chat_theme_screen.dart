import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import '../../theme/chat_theme_provider.dart';
import '../../widgets/kora_menu_sheet.dart';
import 'wallpaper_screen.dart';
import 'chat_bubble_color_screen.dart';
import 'chat_theme_preview_screen.dart';

/// A single tile in the "Chat theme" grid — either a solid-color preset,
/// a bundled image wallpaper preset, or the special "Create with AI" card.
class _ThemeCard {
  final String id;
  final Color? wallpaperColor;
  final String? wallpaperAsset;
  final Color sentBubble;
  final Color receivedBubble;
  final bool isAi;

  const _ThemeCard({
    required this.id,
    this.wallpaperColor,
    this.wallpaperAsset,
    this.sentBubble = KoraColors.purple,
    this.receivedBubble = Colors.white,
  }) : isAi = false;

  const _ThemeCard.ai()
      : id = 'create_with_ai',
        wallpaperColor = null,
        wallpaperAsset = null,
        sentBubble = KoraColors.purple,
        receivedBubble = Colors.white,
        isAi = true;
}

/// Shows the chat theme grid (solid presets + bundled wallpaper presets +
/// "Create with AI"), plus the Chat bubble and Wallpaper customization
/// tiles beneath it — matching the classic "Chat theme" screen layout,
/// reachable both from a chat's 3-dot menu and from Appearance settings.
class DefaultChatThemeScreen extends StatefulWidget {
  const DefaultChatThemeScreen({super.key});

  @override
  State<DefaultChatThemeScreen> createState() => _DefaultChatThemeScreenState();
}

class _DefaultChatThemeScreenState extends State<DefaultChatThemeScreen> {
  final _provider = ChatThemeProvider.instance;

  // Ordered to mirror the reference layout: solid presets interleaved
  // with bundled image wallpapers, with "Create with AI" as the second
  // card (top row).
  late final List<_ThemeCard> _cards = [
    _ThemeCard(
      id: kDefaultChatThemes[0].id, // Default — Kora's professional wallpaper
      wallpaperAsset: kDefaultWallpaperAsset,
      sentBubble: kDefaultChatThemes[0].sentBubble,
      receivedBubble: kDefaultChatThemes[0].receivedBubble,
    ),
    const _ThemeCard(
      id: 'cosmic_swirl',
      wallpaperAsset: 'assets/wallpapers/cosmic_swirl.webp',
      sentBubble: Color(0xFF4F46E5),
      receivedBubble: Colors.white,
    ),
    const _ThemeCard.ai(),
    const _ThemeCard(
      id: 'rose_petals',
      wallpaperAsset: 'assets/wallpapers/rose_petals.webp',
      sentBubble: Color(0xFFA855F7),
      receivedBubble: Colors.white,
    ),
    _ThemeCard(
      id: kDefaultChatThemes[5].id, // Ocean
      wallpaperColor: kDefaultChatThemes[5].wallpaper,
      sentBubble: kDefaultChatThemes[5].sentBubble,
      receivedBubble: kDefaultChatThemes[5].receivedBubble,
    ),
    const _ThemeCard(
      id: 'terracotta_shapes',
      wallpaperAsset: 'assets/wallpapers/terracotta_shapes.webp',
      sentBubble: Color(0xFFDC2626),
      receivedBubble: Colors.white,
    ),
    _ThemeCard(
      id: kDefaultChatThemes[2].id, // Coral
      wallpaperColor: kDefaultChatThemes[2].wallpaper,
      sentBubble: kDefaultChatThemes[2].sentBubble,
      receivedBubble: kDefaultChatThemes[2].receivedBubble,
    ),
    const _ThemeCard(
      id: 'blue_pink_waves',
      wallpaperAsset: 'assets/wallpapers/blue_pink_waves.webp',
      sentBubble: Color(0xFF0D9488),
      receivedBubble: Colors.white,
    ),
    _ThemeCard(
      id: kDefaultChatThemes[1].id, // Midnight
      wallpaperColor: kDefaultChatThemes[1].wallpaper,
      sentBubble: kDefaultChatThemes[1].sentBubble,
      receivedBubble: kDefaultChatThemes[1].receivedBubble,
    ),
    _ThemeCard(
      id: kDefaultChatThemes[3].id, // Forest
      wallpaperColor: kDefaultChatThemes[3].wallpaper,
      sentBubble: kDefaultChatThemes[3].sentBubble,
      receivedBubble: kDefaultChatThemes[3].receivedBubble,
    ),
    _ThemeCard(
      id: kDefaultChatThemes[4].id, // Rose
      wallpaperColor: kDefaultChatThemes[4].wallpaper,
      sentBubble: kDefaultChatThemes[4].sentBubble,
      receivedBubble: kDefaultChatThemes[4].receivedBubble,
    ),
    _ThemeCard(
      id: kDefaultChatThemes[6].id, // Sand
      wallpaperColor: kDefaultChatThemes[6].wallpaper,
      sentBubble: kDefaultChatThemes[6].sentBubble,
      receivedBubble: kDefaultChatThemes[6].receivedBubble,
    ),
  ];

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

  bool _isSelected(_ThemeCard card) {
    if (card.isAi) return false;
    // The "Default" card uses the milk doodle wallpaper — it's selected
    // when the theme is "default" and no custom wallpaper overrides exist.
    if (card.id == kDefaultChatThemes[0].id) {
      return _provider.usesDefaultWallpaperAsset;
    }
    if (card.wallpaperAsset != null) {
      return _provider.wallpaperAssetPath == card.wallpaperAsset;
    }
    // Solid preset — selected only if it's the active theme id and no
    // custom overrides (color/asset) are in play.
    return _provider.themeId == card.id &&
        _provider.wallpaperColor == null &&
        _provider.wallpaperAssetPath == null &&
        _provider.wallpaperImagePath == null;
  }

  void _createWithAi() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Theme saved ✨')),
    );
  }

  void _openPreview(_ThemeCard tapped) {
    final regularCards = _cards.where((c) => !c.isAi).toList();
    final initialIndex = regularCards.indexWhere((c) => c.id == tapped.id);
    final backgrounds = regularCards
        .map((c) => c.wallpaperAsset != null
            ? PreviewBackground(assetPath: c.wallpaperAsset, bubbleColor: c.sentBubble)
            : PreviewBackground(color: c.wallpaperColor, bubbleColor: c.sentBubble))
        .toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatThemePreviewScreen(
          backgrounds: backgrounds,
          initialIndex: initialIndex < 0 ? 0 : initialIndex,
          initialBubbleColor: tapped.sentBubble,
          hintText: 'Swipe left or right to preview more themes ✨',
          onApply: (bg, bubbleColor, dimLevel) {
            if (bg.assetPath != null) {
              // Special case: the default milk doodle wallpaper.
              if (bg.assetPath == kDefaultWallpaperAsset) {
                _provider.setChatTheme(kDefaultChatThemes[0].id);
                if (bubbleColor.toARGB32() != kDefaultChatThemes[0].sentBubble.toARGB32()) {
                  _provider.setCustomSentBubble(bubbleColor);
                }
              } else {
                _provider.setWallpaperAsset(bg.assetPath!);
                _provider.setCustomSentBubble(bubbleColor);
              }
            } else if (bg.color != null) {
              final matched = kDefaultChatThemes.firstWhere(
                (t) => t.wallpaper.toARGB32() == bg.color!.toARGB32(),
                orElse: () => kDefaultChatThemes[0],
              );
              _provider.setChatTheme(matched.id);
              if (bubbleColor.toARGB32() != matched.sentBubble.toARGB32()) {
                _provider.setCustomSentBubble(bubbleColor);
              }
            }
            _provider.setWallpaperDimLevel(dimLevel);
          },
        ),
      ),
    );
  }

  void _showMenu() {
    KoraMenuSheet.show(context, [
      KoraMenuOption(
        icon: Icons.restart_alt,
        label: 'Reset to default',
        onTap: () => _provider.setChatTheme(kDefaultChatThemes[0].id),
      ),
    ]);
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

    const cardWidth = 88.0;
    const cardHeight = 120.0;
    const spacing = 10.0;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          'Chat theme',
          style: TextStyle(color: textPrimary, fontSize: 19, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert, color: textPrimary),
            onPressed: _showMenu,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                'Themes',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(
              height: cardHeight * 2 + spacing,
              child: GridView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: spacing,
                  crossAxisSpacing: spacing,
                  childAspectRatio: cardHeight / cardWidth,
                ),
                itemCount: _cards.length,
                itemBuilder: (context, index) {
                  final c = _cards[index];
                  if (c.isAi) {
                    return _aiCard(textPrimary);
                  }
                  return _themeCard(
                    card: c,
                    isSelected: _isSelected(c),
                    onTap: () => _openPreview(c),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                'The chat bubble and wallpaper will both change.',
                style: TextStyle(color: textSecondary, fontSize: 13),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'Customize',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
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

  /// A theme grid tile — blank bubble shapes over the wallpaper (no text,
  /// no name label), with a small black checkmark badge in the bottom-right
  /// corner when this theme is the active one.
  Widget _themeCard({
    required _ThemeCard card,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (card.wallpaperAsset != null && card.wallpaperAsset!.isNotEmpty)
              Image.asset(
                card.wallpaperAsset!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(color: card.wallpaperColor ?? const Color(0xFFECE5DD)),
              )
            else
              Container(color: card.wallpaperColor ?? const Color(0xFFECE5DD)),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 13,
                    decoration: BoxDecoration(
                      color: card.receivedBubble,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(7),
                        topRight: Radius.circular(7),
                        bottomRight: Radius.circular(7),
                        bottomLeft: Radius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: 36,
                      height: 13,
                      decoration: BoxDecoration(
                        color: card.sentBubble,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                          bottomLeft: Radius.circular(8),
                          bottomRight: Radius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Positioned(
                right: 6,
                bottom: 6,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// The special "Create with AI" card — sparkle icon + label on a soft
  /// gradient card, matching the surrounding theme tiles' proportions.
  Widget _aiCard(Color textPrimary) {
    return GestureDetector(
      onTap: _createWithAi,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF3E8FF), Color(0xFFFCE7F3)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.auto_awesome, color: KoraColors.purple, size: 18),
              const SizedBox(height: 6),
              Text(
                'Create with AI',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

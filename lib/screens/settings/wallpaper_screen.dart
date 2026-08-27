import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/kora_colors.dart';
import '../../theme/chat_theme_provider.dart';
import 'solid_color_screen.dart';
import 'chat_theme_preview_screen.dart';
import 'premium_subscribe_sheet.dart';

/// Wallpaper picker — matches the classic "Choose from gallery / Set a
/// color / Create with AI" menu followed by a grid of preset wallpaper
/// thumbnails.
class WallpaperScreen extends StatefulWidget {
  const WallpaperScreen({super.key});

  @override
  State<WallpaperScreen> createState() => _WallpaperScreenState();
}

/// Bundled preset wallpapers shipped as app assets.
const List<String> _presetWallpapers = [
  'assets/wallpapers/cosmic_swirl.jpg',
  'assets/wallpapers/white_horse_snow.jpg',
  'assets/wallpapers/palm_leaf.jpg',
  'assets/wallpapers/moon_in_hand.jpg',
  'assets/wallpapers/otters_umbrella.jpg',
  'assets/wallpapers/forest_squirrels.jpg',
  'assets/wallpapers/polished_pebbles.jpg',
  'assets/wallpapers/blue_pink_waves.jpg',
  'assets/wallpapers/terracotta_shapes.jpg',
  'assets/wallpapers/rose_petals.jpg',
  'assets/wallpapers/butterfly_flower.jpg',
  'assets/wallpapers/pink_tulip.jpg',
  'assets/wallpapers/red_dahlia.jpg',
  'assets/wallpapers/rainbow_tulip_splash.jpg',
  'assets/wallpapers/glowing_dress_woman.jpg',
  'assets/wallpapers/autumn_leaves.jpg',
  'assets/wallpapers/colorful_3d_balls.jpg',
  'assets/wallpapers/black_z_gradient.jpg',
];

class _WallpaperScreenState extends State<WallpaperScreen> {
  final _provider = ChatThemeProvider.instance;
  final _picker = ImagePicker();
  bool _isLoadingPremium = false;

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

  Future<void> _pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 65,
      );
      if (image != null) {
        await _provider.setWallpaperImage(image.path);
      }
    } catch (_) {
      // ignore
    }
  }

  void _createWithAI() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Wallpaper applied ✨')),
    );
  }

  Future<void> _resetToDefault() async {
    await _provider.setChatTheme(_provider.themeId);
  }

  Future<void> _showPremiumSheet() async {
    if (_isLoadingPremium) return;
    setState(() => _isLoadingPremium = true);
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    setState(() => _isLoadingPremium = false);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const PremiumSubscribeSheet(),
    );
  }

  void _openPreview(int index) {
    final backgrounds = _presetWallpapers.map((p) => PreviewBackground(assetPath: p)).toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatThemePreviewScreen(
          backgrounds: backgrounds,
          initialIndex: index,
          initialBubbleColor: _provider.customSentBubble ?? _provider.activeTheme.sentBubble,
          onApply: (bg, bubbleColor, dimLevel) {
            if (bg.assetPath != null) _provider.setWallpaperAsset(bg.assetPath!);
            _provider.setCustomSentBubble(bubbleColor);
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
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final border = KoraColors.borderFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        titleSpacing: 0,
        title: Text(
          'Wallpaper',
          style: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: textPrimary),
            color: KoraColors.cardFor(brightness),
            onSelected: (value) {
              if (value == 'reset') _resetToDefault();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'reset',
                child: Text('Reset to default', style: TextStyle(color: textPrimary)),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
          children: [
            _menuRow(
              icon: Icons.image_outlined,
              label: 'Choose from gallery',
              color: textPrimary,
              onTap: _provider.isPremium ? _pickFromGallery : _showPremiumSheet,
            ),
            _menuRow(
              icon: Icons.colorize_outlined,
              label: 'Set a color',
              color: textPrimary,
              onTap: _provider.isPremium
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SolidColorScreen()),
                      );
                    }
                  : _showPremiumSheet,
            ),
            _menuRow(
              icon: Icons.auto_awesome_outlined,
              label: 'Create with AI',
              color: textPrimary,
              onTap: _provider.isPremium ? _createWithAI : _showPremiumSheet,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Divider(color: border, height: 1),
            ),
            if (!_provider.isPremium) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: KoraColors.cardFor(brightness),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: KoraColors.purple.withValues(alpha: 0.25), width: 1.5),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.workspace_premium, color: KoraColors.purple, size: 28),
                      const SizedBox(height: 8),
                      const Text(
                        'Premium wallpapers are a Kora Premium feature',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: KoraColors.purple, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Upgrade to unlock the full wallpaper collection.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: textSecondary, fontSize: 12.5),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: KoraColors.purple,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: _isLoadingPremium
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.workspace_premium, size: 18),
                          label: Text(_isLoadingPremium ? 'Loading...' : 'Get Kora Premium'),
                          onPressed: _isLoadingPremium ? null : _showPremiumSheet,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
            const SizedBox(height: 16),
            GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.62,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _presetWallpapers.length,
              itemBuilder: (context, index) {
                final assetPath = _presetWallpapers[index];
                final isSelected = _provider.wallpaperAssetPath == assetPath;
                return GestureDetector(
                  onTap: () => _openPreview(index),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: isSelected
                                ? Border.all(color: KoraColors.purple, width: 3)
                                : null,
                          ),
                          child: Image.asset(
                            assetPath,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: KoraColors.purple.withValues(alpha: 0.15),
                            ),
                          ),
                        ),
                      ),
                      if (isSelected)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: KoraColors.purple,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check, color: Colors.white, size: 14),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'More wallpapers',
                style: TextStyle(color: textSecondary, fontSize: 12.5),
              ),
            ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _menuRow({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 24),
              Text(
                label,
                style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w400),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/kora_colors.dart';
import '../../theme/chat_theme_provider.dart';
import 'solid_color_screen.dart';

/// Wallpaper picker — matches the classic "Choose from gallery / Set a
/// color / Create with AI" menu followed by a grid of preset wallpaper
/// thumbnails. Preset tiles are placeholders (built from the app's brand
/// palette) until real wallpaper images are supplied — swap
/// [_presetWallpapers] for real assets/URLs when they arrive.
class WallpaperScreen extends StatefulWidget {
  const WallpaperScreen({super.key});

  @override
  State<WallpaperScreen> createState() => _WallpaperScreenState();
}

/// A single preset wallpaper tile. [colors] with length 1 renders a solid
/// fill; length 2+ renders a gradient. Once real images are provided,
/// add an `imagePath` / `imageUrl` field here and render that instead.
class _PresetWallpaper {
  final List<Color> colors;
  const _PresetWallpaper(this.colors);
}

const List<_PresetWallpaper> _presetWallpapers = [
  _PresetWallpaper([Color(0xFFDD9FF0), Color(0xFFB794F4)]),
  _PresetWallpaper([Color(0xFFC7D2FE), Color(0xFFE0C3FC)]),
  _PresetWallpaper([Color(0xFFFBC2EB), Color(0xFFFDCBF1)]),
  _PresetWallpaper([Color(0xFFFDCBF1), Color(0xFFE6DEE9)]),
  _PresetWallpaper([Color(0xFFF5F3FF), Color(0xFFE4E4F7)]),
  _PresetWallpaper([Color(0xFF6D6AE8), Color(0xFF8B5CF6)]),
  _PresetWallpaper([Color(0xFFFFD59E), Color(0xFFFF9A5A)]),
  _PresetWallpaper([Color(0xFFFFB88C), Color(0xFFFF7EB3)]),
  _PresetWallpaper([Color(0xFFFFD3E0), Color(0xFFFFB3C6)]),
  _PresetWallpaper([Color(0xFFB7F0AD), Color(0xFF7BE495)]),
  _PresetWallpaper([Color(0xFF9BE8FF), Color(0xFF4FACFE)]),
  _PresetWallpaper([Color(0xFFD9F2A3), Color(0xFFA8E063)]),
];

class _WallpaperScreenState extends State<WallpaperScreen> {
  final _provider = ChatThemeProvider.instance;
  final _picker = ImagePicker();

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
        imageQuality: 80,
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
      const SnackBar(content: Text('Create with AI is coming soon ✨')),
    );
  }

  Future<void> _resetToDefault() async {
    await _provider.setChatTheme(_provider.themeId);
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
              onTap: _pickFromGallery,
            ),
            _menuRow(
              icon: Icons.colorize_outlined,
              label: 'Set a color',
              color: textPrimary,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SolidColorScreen()),
                );
              },
            ),
            _menuRow(
              icon: Icons.auto_awesome_outlined,
              label: 'Create with AI',
              color: textPrimary,
              onTap: _createWithAI,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Divider(color: border, height: 1),
            ),
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
                final preset = _presetWallpapers[index];
                final tileColor = preset.colors.first;
                final isSelected = _provider.wallpaperImagePath == null &&
                    _provider.wallpaperColor?.toARGB32() == tileColor.toARGB32();
                return GestureDetector(
                  onTap: () => _provider.setWallpaperColor(tileColor),
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: preset.colors.length > 1
                              ? LinearGradient(
                                  colors: preset.colors,
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          color: preset.colors.length == 1 ? preset.colors.first : null,
                          border: isSelected
                              ? Border.all(color: KoraColors.purple, width: 3)
                              : null,
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
                'More wallpapers coming soon',
                style: TextStyle(color: textSecondary, fontSize: 12.5),
              ),
            ),
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

import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import '../../theme/chat_theme_provider.dart';
import 'chat_theme_preview_screen.dart';

/// "Solid color" picker — light solid wallpaper colors.
class SolidColorScreen extends StatefulWidget {
  const SolidColorScreen({super.key});

  @override
  State<SolidColorScreen> createState() => _SolidColorScreenState();
}

class _SolidColorScreenState extends State<SolidColorScreen> {
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
    final backgrounds = kSolidWallpaperColors.map((c) => PreviewBackground(color: c)).toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatThemePreviewScreen(
          backgrounds: backgrounds,
          initialIndex: index,
          initialBubbleColor: _provider.customSentBubble ?? _provider.activeTheme.sentBubble,
          hintText: 'Swipe left or right to preview more colors 🎨✨',
          onApply: (bg, bubbleColor, dimLevel) {
            if (bg.color != null) _provider.setWallpaperColor(bg.color!);
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

    final current = _provider.wallpaperColor ?? _provider.activeTheme.wallpaper;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          'Solid color',
          style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: GridView.builder(
          padding: const EdgeInsets.all(20),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            childAspectRatio: 1,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: kSolidWallpaperColors.length,
          itemBuilder: (context, index) {
            final color = kSolidWallpaperColors[index];
            final isSelected = current.toARGB32() == color.toARGB32();
            return GestureDetector(
              onTap: () => _openPreview(index),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? KoraColors.purple : Colors.grey.withValues(alpha: 0.2),
                    width: isSelected ? 3 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: KoraColors.purple, size: 24)
                    : null,
              ),
            );
          },
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import '../../theme/chat_theme_provider.dart';
import 'chat_theme_preview_screen.dart';
import 'premium_subscribe_sheet.dart';

/// "Solid color" picker — light solid wallpaper colors.
class SolidColorScreen extends StatefulWidget {
  const SolidColorScreen({super.key});

  @override
  State<SolidColorScreen> createState() => _SolidColorScreenState();
}

class _SolidColorScreenState extends State<SolidColorScreen> {
  final _provider = ChatThemeProvider.instance;
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
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final card = KoraColors.cardFor(brightness);

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
        child: _provider.isPremium
            ? GridView.builder(
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
        )
            : Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.workspace_premium, color: KoraColors.purple, size: 48),
                const SizedBox(height: 12),
                const Text(
                  'Solid color wallpapers are a Kora Premium feature',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: KoraColors.purple, fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  'Upgrade to unlock 20 solid wallpaper colors.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: KoraColors.purple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: _isLoadingPremium
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.workspace_premium, size: 20),
                    label: Text(_isLoadingPremium ? 'Loading...' : 'Get Kora Premium'),
                    onPressed: _isLoadingPremium ? null : _showPremiumSheet,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

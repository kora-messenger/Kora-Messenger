import 'dart:io';
import 'package:flutter/material.dart';
import '../../theme/chat_theme_provider.dart';
import '../../theme/kora_colors.dart';

/// A single page the Preview screen can swipe through — either a bundled
/// asset image, a picked gallery image, or a solid color. Chat-theme
/// presets can also carry their own bubble color so swiping updates both
/// wallpaper and bubble together.
class PreviewBackground {
  final String? assetPath;
  final String? imagePath;
  final Color? color;
  final Color? bubbleColor;

  const PreviewBackground({this.assetPath, this.imagePath, this.color, this.bubbleColor});
}

/// Builds a [PreviewBackground] that mirrors whatever wallpaper is
/// currently active, so single-item previews (e.g. from the Chat bubble
/// screen) show the real wallpaper instead of a placeholder.
PreviewBackground currentPreviewBackground(ChatThemeProvider p) {
  if (p.wallpaperAssetPath != null) return PreviewBackground(assetPath: p.wallpaperAssetPath);
  if (p.wallpaperImagePath != null) return PreviewBackground(imagePath: p.wallpaperImagePath);
  return PreviewBackground(color: p.activeTheme.wallpaper);
}

/// Shared full-screen preview — opens when the user taps a wallpaper, a
/// chat theme preset, or a chat bubble color. Lets them swipe through
/// options, cycle the bubble accent color (bottom-left), and dim the
/// wallpaper via a brightness slider (bottom-right) before confirming.
class ChatThemePreviewScreen extends StatefulWidget {
  final List<PreviewBackground> backgrounds;
  final int initialIndex;
  final Color initialBubbleColor;
  final bool allowSwipe;
  final String? hintText;
  final String descriptionText;
  final void Function(PreviewBackground background, Color bubbleColor, double dimLevel) onApply;

  const ChatThemePreviewScreen({
    super.key,
    required this.backgrounds,
    this.initialIndex = 0,
    required this.initialBubbleColor,
    this.allowSwipe = true,
    this.hintText = 'Swipe left or right to preview more wallpapers 🖼️✨',
    this.descriptionText = 'This will replace your existing default chat theme. Only you see your chat themes.',
    required this.onApply,
  });

  @override
  State<ChatThemePreviewScreen> createState() => _ChatThemePreviewScreenState();
}

class _ChatThemePreviewScreenState extends State<ChatThemePreviewScreen> {
  late final PageController _pageController;
  late int _currentIndex;
  late Color _bubbleColor;
  double _dimLevel = 0;
  bool _showDimSlider = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _bubbleColor = widget.initialBubbleColor;
    _dimLevel = ChatThemeProvider.instance.wallpaperDimLevel;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _cycleBubbleColor() {
    final idx = kChatBubbleColors.indexWhere((c) => c.toARGB32() == _bubbleColor.toARGB32());
    final next = kChatBubbleColors[(idx + 1) % kChatBubbleColors.length];
    setState(() => _bubbleColor = next);
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
      final bg = widget.backgrounds[index];
      if (bg.bubbleColor != null) _bubbleColor = bg.bubbleColor!;
    });
  }

  void _confirm() {
    widget.onApply(widget.backgrounds[_currentIndex], _bubbleColor, _dimLevel);
    Navigator.pop(context);
  }

  Widget _buildBackground(PreviewBackground bg) {
    // Empty (but non-null) asset paths would throw "Unable to load asset: ''".
    if (bg.assetPath != null && bg.assetPath!.isNotEmpty) {
      return Image.asset(
        bg.assetPath!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => Container(color: bg.color ?? KoraColors.purple),
      );
    } else if (bg.assetPath != null && bg.assetPath!.isEmpty) {
      return Container(color: bg.color ?? KoraColors.purple);
    } else if (bg.imagePath != null) {
      return Image.file(File(bg.imagePath!), fit: BoxFit.cover, width: double.infinity, height: double.infinity);
    }
    return Container(color: bg.color ?? const Color(0xFFECE5DD));
  }

  @override
  Widget build(BuildContext context) {
    const chromeColor = Colors.white;
    const chromeShadow = [
      Shadow(color: Color(0x59000000), blurRadius: 6, offset: Offset(0, 1)),
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            physics: widget.allowSwipe && widget.backgrounds.length > 1
                ? const BouncingScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            itemCount: widget.backgrounds.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) => _buildBackground(widget.backgrounds[index]),
          ),
          IgnorePointer(
            child: Container(color: Colors.black.withValues(alpha: _dimLevel * 0.75)),
          ),
          // Top bar — pinned to the very top of the screen. Must be
          // wrapped in Positioned (not a plain Stack child) because the
          // Stack uses fit: StackFit.expand, which would otherwise
          // stretch this Row to fill the whole screen height and
          // vertically center its contents instead of keeping them at
          // the top.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: chromeColor, shadows: chromeShadow),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(
                      'Preview',
                      style: TextStyle(
                        color: chromeColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        shadows: chromeShadow,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _confirm,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: const BoxDecoration(color: Color(0xFF25D366), shape: BoxShape.circle),
                        child: const Icon(Icons.check, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Chat mockup
          Positioned(
            top: 84,
            left: 16,
            right: 16,
            child: Column(
              children: [
                _todayChip(),
                const SizedBox(height: 14),
                if (widget.hintText != null) ...[
                  _receivedBubble(widget.hintText!),
                  const SizedBox(height: 8),
                ],
                _sentBubble(),
              ],
            ),
          ),
          // Brightness slider overlay
          if (_showDimSlider)
            Positioned(
              right: 20,
              bottom: 92,
              child: _dimSlider(),
            ),
          // Bottom control bar
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              color: Colors.white,
              padding: EdgeInsets.fromLTRB(20, 14, 20, 14 + MediaQuery.of(context).padding.bottom),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: _cycleBubbleColor,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _bubbleColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black.withValues(alpha: 0.15), width: 1.5),
                      ),
                    ),
                  ),
                  if (widget.backgrounds.length > 1) _dotsIndicator() else const SizedBox(),
                  GestureDetector(
                    onTap: () => setState(() => _showDimSlider = !_showDimSlider),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _showDimSlider ? Colors.black : const Color(0xFFF0F0F0),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.dark_mode_outlined,
                        color: _showDimSlider ? Colors.white : Colors.black87,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _todayChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text('Today', style: TextStyle(color: Color(0xFF667085), fontSize: 12, fontWeight: FontWeight.w500)),
    );
  }

  Widget _receivedBubble(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(14),
            topRight: Radius.circular(14),
            bottomRight: Radius.circular(14),
            bottomLeft: Radius.circular(4),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 1))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(text, style: const TextStyle(color: Color(0xFF111B21), fontSize: 14)),
            const SizedBox(height: 2),
            const Text('6:12 AM', style: TextStyle(color: Color(0xFF9AA0A6), fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _sentBubble() {
    final isLight = _bubbleColor.computeLuminance() > 0.5;
    final textColor = isLight ? const Color(0xFF111B21) : Colors.white;
    final subColor = isLight ? const Color(0xFF667781) : Colors.white70;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _bubbleColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(14),
            topRight: Radius.circular(14),
            bottomLeft: Radius.circular(14),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(widget.descriptionText, style: TextStyle(color: textColor, fontSize: 14)),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('6:12 AM', style: TextStyle(color: subColor, fontSize: 11)),
                const SizedBox(width: 4),
                Icon(Icons.done_all, size: 14, color: isLight ? const Color(0xFF53BDEB) : Colors.lightBlueAccent),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dotsIndicator() {
    const maxDots = 7;
    final total = widget.backgrounds.length;
    final count = total < maxDots ? total : maxDots;
    final maxStart = (total - maxDots).clamp(0, total);
    final start = (_currentIndex - maxDots ~/ 2).clamp(0, maxStart);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final idx = start + i;
        final active = idx == _currentIndex;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 8 : 6,
          height: active ? 8 : 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? Colors.black87 : Colors.black26,
          ),
        );
      }),
    );
  }

  Widget _dimSlider() {
    const trackHeight = 190.0;
    const thumbSize = 46.0;
    return Column(
      children: [
        Container(
          width: 46,
          height: trackHeight,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(23),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8)],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final range = constraints.maxHeight - thumbSize;
              final thumbTop = _dimLevel * range;
              void updateFromLocalY(double y) {
                final ratio = (y / constraints.maxHeight).clamp(0.0, 1.0);
                setState(() => _dimLevel = ratio);
              }
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: (d) => updateFromLocalY(d.localPosition.dy),
                onTapDown: (d) => updateFromLocalY(d.localPosition.dy),
                child: Stack(
                  children: [
                    Positioned(
                      top: thumbTop,
                      left: 0,
                      right: 0,
                      child: Container(
                        width: thumbSize,
                        height: thumbSize,
                        decoration: const BoxDecoration(color: Color(0xFF1A1A1A), shape: BoxShape.circle),
                        child: const Icon(Icons.brightness_6, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => setState(() => _dimLevel = 0),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6)],
            ),
            child: const Icon(Icons.wb_sunny_outlined, color: Colors.black87, size: 18),
          ),
        ),
      ],
    );
  }
}

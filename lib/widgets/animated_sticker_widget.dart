import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';

/// Animated Sticker widget — renders WebP/Lottie animated stickers in chat.
/// Mirrors WhatsApp's animated sticker support.
///
/// Uses a placeholder animation (pulsing gradient) for now.
/// In production, this would load .webp animated stickers or
/// Lottie .json animation files.
class AnimatedStickerWidget extends StatefulWidget {
  final String stickerId;
  final double size;

  const AnimatedStickerWidget({
    super.key,
    required this.stickerId,
    this.size = 120,
  });

  @override
  State<AnimatedStickerWidget> createState() => _AnimatedStickerWidgetState();
}

class _AnimatedStickerWidgetState extends State<AnimatedStickerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.9, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (context, child) => Transform.scale(
        scale: _scale.value,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                KoraColors.purple.withValues(alpha: 0.15),
                KoraColors.blue.withValues(alpha: 0.15),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Icon(Icons.emoji_emotions, size: widget.size * 0.5, color: KoraColors.purple),
          ),
        ),
      ),
    );
  }
}

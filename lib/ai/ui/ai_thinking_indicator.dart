import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';

/// Animated thinking indicator shown while AI is generating a response.
class AIThinkingIndicator extends StatefulWidget {
  const AIThinkingIndicator({super.key});
  @override
  State<AIThinkingIndicator> createState() => _AIThinkingIndicatorState();
}

class _AIThinkingIndicatorState extends State<AIThinkingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 1200), vsync: this)..repeat();
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: KoraColors.surfaceFor(brightness),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16), topRight: Radius.circular(16), bottomRight: Radius.circular(16),
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (int i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            AnimatedBuilder(
              animation: _controller,
              builder: (_, __) {
                final t = _controller.value;
                final delay = i * 0.2;
                final opacity = ((t - delay) % 1.0).clamp(0.0, 1.0);
                return Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    color: KoraColors.purple.withValues(alpha: 0.3 + opacity * 0.5),
                    shape: BoxShape.circle,
                  ),
                );
              },
            ),
          ],
        ]),
      ),
    );
  }
}

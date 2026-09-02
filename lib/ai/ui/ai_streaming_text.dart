import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';

/// Displays streaming text with a blinking cursor.
class AIStreamingText extends StatefulWidget {
  final String text;
  const AIStreamingText({super.key, required this.text});
  @override
  State<AIStreamingText> createState() => _AIStreamingTextState();
}

class _AIStreamingTextState extends State<AIStreamingText>
    with SingleTickerProviderStateMixin {
  late AnimationController _cursorController;

  @override
  void initState() {
    super.initState();
    _cursorController = AnimationController(duration: const Duration(milliseconds: 500), vsync: this)..repeat(reverse: true);
  }

  @override
  void dispose() { _cursorController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: KoraColors.surfaceFor(brightness),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16), topRight: Radius.circular(16), bottomRight: Radius.circular(16),
          ),
        ),
        child: widget.text.isEmpty
          ? Row(mainAxisSize: MainAxisSize.min, children: [
              for (int i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                _buildDot(i),
              ],
            ])
          : RichText(text: TextSpan(
              style: TextStyle(color: KoraColors.textPrimaryFor(brightness), fontSize: 15, height: 1.4),
              children: [
                TextSpan(text: widget.text),
                WidgetSpan(child: AnimatedBuilder(
                  animation: _cursorController,
                  builder: (_, __) => Opacity(
                    opacity: _cursorController.value,
                    child: const Text('▌', style: TextStyle(color: KoraColors.purple)),
                  ),
                )),
              ],
            )),
      ),
    );
  }

  Widget _buildDot(int i) => Container(
    width: 8, height: 8,
    decoration: BoxDecoration(
      color: KoraColors.purple.withValues(alpha: 0.3 + i * 0.2),
      shape: BoxShape.circle,
    ),
  );
}

import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';

/// Voice input button with hold-to-talk gesture.
class AIVoiceButton extends StatefulWidget {
  final VoidCallback onStart;
  final VoidCallback onStop;
  final bool disabled;
  const AIVoiceButton({super.key, required this.onStart, required this.onStop, this.disabled = false});
  @override
  State<AIVoiceButton> createState() => _AIVoiceButtonState();
}

class _AIVoiceButtonState extends State<AIVoiceButton> {
  bool _isHolding = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: widget.disabled ? null : (_) { setState(() => _isHolding = true); widget.onStart(); },
      onLongPressEnd: widget.disabled ? null : (_) { setState(() => _isHolding = false); widget.onStop(); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: _isHolding ? 56 : 40,
        height: _isHolding ? 56 : 40,
        decoration: BoxDecoration(
          color: _isHolding ? KoraColors.purple : KoraColors.purple.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.mic, color: _isHolding ? Colors.white : KoraColors.purple, size: 20),
      ),
    );
  }
}

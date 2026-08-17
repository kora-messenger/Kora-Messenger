import 'package:flutter/material.dart';
import '../theme/kora_colors.dart';

/// Kora's primary pill button — solid purple with glow.
class KoraButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isSecondary;

  const KoraButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.isSecondary = false,
  });

  @override
  State<KoraButton> createState() => _KoraButtonState();
}

class _KoraButtonState extends State<KoraButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null || widget.isLoading;
    final bgColor = widget.isSecondary
        ? KoraColors.darkPill
        : (isDisabled ? KoraColors.purple.withValues(alpha: 0.4) : KoraColors.purple);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: isDisabled ? null : widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(32),
          boxShadow: widget.isSecondary || isDisabled
              ? null
              : [
                  BoxShadow(
                    color: KoraColors.purple.withValues(alpha: _isPressed ? 0.15 : 0.35),
                    blurRadius: _isPressed ? 10 : 20,
                    offset: Offset(0, _isPressed ? 2 : 8),
                  ),
                ],
        ),
        child: Center(
          child: widget.isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: widget.isSecondary ? FontWeight.w600 : FontWeight.w700,
                    color: isDisabled ? Colors.white60 : Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}

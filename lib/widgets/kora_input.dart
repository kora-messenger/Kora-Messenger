import 'package:flutter/material.dart';
import '../theme/kora_colors.dart';

/// Reusable styled text field for Kora's screens.
/// Dark surface, rounded corners, purple focus accent.
/// When [adaptive] is true, colors respond to the current theme brightness.
class KoraInput extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final int maxLines;
  final int? maxLength;
  final bool readOnly;
  final bool adaptive;
  final VoidCallback? onTap;
  final String? hintText;
  final ValueChanged<String>? onChanged;

  const KoraInput({
    super.key,
    required this.label,
    required this.controller,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.suffixIcon,
    this.prefixIcon,
    this.maxLines = 1,
    this.maxLength,
    this.readOnly = false,
    this.adaptive = false,
    this.onTap,
    this.hintText,
    this.onChanged,
  });

  @override
  State<KoraInput> createState() => _KoraInputState();
}

class _KoraInputState extends State<KoraInput> {
  bool _obscure = false;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _obscure = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = !widget.adaptive ||
        Theme.of(context).brightness == Brightness.dark;

    final fillColor = isDark
        ? KoraColors.darkCard
        : KoraColors.lightCard;
    final textColor = isDark
        ? Colors.white
        : const Color(0xFF1A1A2E);
    final labelColor = isDark
        ? const Color(0xFF6B6B80)
        : const Color(0xFF9A9AB0);
    const labelFocused = KoraColors.purple;
    final hintColor = isDark
        ? const Color(0xFF4A4A5E)
        : const Color(0xFFB0B0C0);
    final borderIdle = isDark
        ? const Color(0xFF2E2E42)
        : const Color(0xFFE2E2EC);

    return Focus(
      onFocusChange: (focused) => setState(() => _hasFocus = focused),
      child: TextFormField(
        controller: widget.controller,
        obscureText: _obscure,
        keyboardType: widget.keyboardType,
        validator: widget.validator,
        maxLines: widget.obscureText ? 1 : widget.maxLines,
        maxLength: widget.maxLength,
        readOnly: widget.readOnly,
        onChanged: widget.onChanged,
        onTap: widget.onTap,
        style: TextStyle(
          color: textColor,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: widget.label,
          labelStyle: TextStyle(
            color: _hasFocus ? labelFocused : labelColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          hintText: widget.hintText ?? widget.label,
          hintStyle: TextStyle(color: hintColor, fontSize: 15),
          filled: true,
          fillColor: fillColor,
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          prefixIcon: widget.prefixIcon,
          suffixIcon: widget.obscureText
              ? GestureDetector(
                  onTap: () => setState(() => _obscure = !_obscure),
                  child: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: const Color(0xFF6B6B80),
                    size: 22,
                  ),
                )
              : widget.suffixIcon,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: _hasFocus ? KoraColors.purple : borderIdle,
              width: 1.5,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: KoraColors.purple, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.redAccent, width: 2),
          ),
        ),
      ),
    );
  }
}

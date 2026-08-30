import 'package:flutter/material.dart';
import '../theme/kora_colors.dart';
import '../services/suspicious_link_service.dart';

/// Suspicious Link Warning — inline warning banner shown in chat when
/// a message contains a potentially dangerous link.
/// Mirrors WhatsApp's "This link contains suspicious content" warning.
class SuspiciousLinkWarning extends StatelessWidget {
  final LinkWarning warning;
  final VoidCallback? onProceed;
  final VoidCallback? onCancel;

  const SuspiciousLinkWarning({
    super.key,
    required this.warning,
    this.onProceed,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: brightness == Brightness.dark
            ? const Color(0x33D63031)
            : const Color(0x1AD63031),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD63031), width: 0.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFD63031), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Suspicious Link',
                  style: TextStyle(
                    color: Color(0xFFD63031),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  warning.message,
                  style: TextStyle(
                    color: brightness == Brightness.dark ? Colors.white70 : const Color(0xFF666666),
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          if (onProceed != null)
            TextButton(
              onPressed: onProceed,
              child: const Text('Open', style: TextStyle(color: Color(0xFFD63031), fontSize: 13, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}

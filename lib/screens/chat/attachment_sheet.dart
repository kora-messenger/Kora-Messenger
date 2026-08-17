import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';

/// Attachment type options in Kora's attachment panel.
class KoraAttachmentType {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const KoraAttachmentType({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

/// Kora's attachment sheet — a clean bottom panel with a grid of
/// attachment options. Not a copy of WhatsApp's attachment menu.
class AttachmentSheet extends StatelessWidget {
  const AttachmentSheet({super.key});

  static void show(BuildContext context, List<KoraAttachmentType> types) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _AttachmentSheetContent(types: types),
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _AttachmentSheetContent extends StatelessWidget {
  final List<KoraAttachmentType> types;

  const _AttachmentSheetContent({required this.types});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final card = KoraColors.cardFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);

    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: textMuted.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: types.map((t) {
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    t.onTap();
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: t.color.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(t.icon, color: t.color, size: 26),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        t.label,
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

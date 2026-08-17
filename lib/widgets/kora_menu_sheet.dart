import 'package:flutter/material.dart';
import '../theme/kora_colors.dart';

/// A single option row inside Kora's contextual menus.
class KoraMenuOption {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const KoraMenuOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });
}

/// Kora's three-dot / contextual menu — a rounded sheet dropped from the
/// top-right, styled distinctly from a generic Material popup menu.
class KoraMenuSheet extends StatelessWidget {
  final List<KoraMenuOption> options;

  const KoraMenuSheet({super.key, required this.options});

  static void show(BuildContext context, List<KoraMenuOption> options) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => _MenuOverlay(
        options: options,
        onDismiss: () => entry.remove(),
      ),
    );

    overlay.insert(entry);
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _MenuOverlay extends StatelessWidget {
  final List<KoraMenuOption> options;
  final VoidCallback onDismiss;

  const _MenuOverlay({required this.options, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final card = KoraColors.cardFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: onDismiss,
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.black.withValues(alpha: 0.15)),
          ),
        ),
        Positioned(
          top: 78,
          right: 16,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 230,
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: options.map((opt) {
                  final color = opt.color ?? textPrimary;
                  return InkWell(
                    onTap: () {
                      onDismiss();
                      opt.onTap();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                      child: Row(
                        children: [
                          Icon(opt.icon, size: 20, color: color),
                          const SizedBox(width: 14),
                          Text(
                            opt.label,
                            style: TextStyle(
                              color: color,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

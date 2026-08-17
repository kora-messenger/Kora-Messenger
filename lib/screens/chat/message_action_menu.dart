import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';

/// Actions available when long-pressing a message in Kora.
enum KoraMessageAction {
  reply,
  react,
  copy,
  forward,
  translate,
  delete,
  select,
}

/// The reaction picker row shown at the top of the long-press menu.
const _quickReactions = ['❤️', '😂', '👍', '😮', '😢', '🙏'];

/// Shows Kora's message action menu as an overlay near the tapped message.
/// Includes a quick-reaction row + contextual actions (reply, copy, etc.)
void showKoraMessageActionMenu(
  BuildContext context, {
  required GlobalKey messageKey,
  required bool isMe,
  required ValueChanged<String> onReact,
  required VoidCallback onReply,
  required VoidCallback onCopy,
  required VoidCallback onForward,
  required VoidCallback onTranslate,
  required VoidCallback onDelete,
}) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;

  entry = OverlayEntry(
    builder: (context) => _MessageActionOverlay(
      messageKey: messageKey,
      isMe: isMe,
      onDismiss: () => entry.remove(),
      onReact: (emoji) {
        entry.remove();
        onReact(emoji);
      },
      onReply: () {
        entry.remove();
        onReply();
      },
      onCopy: () {
        entry.remove();
        onCopy();
      },
      onForward: () {
        entry.remove();
        onForward();
      },
      onTranslate: () {
        entry.remove();
        onTranslate();
      },
      onDelete: () {
        entry.remove();
        onDelete();
      },
    ),
  );

  overlay.insert(entry);
}

class _MessageActionOverlay extends StatelessWidget {
  final GlobalKey messageKey;
  final bool isMe;
  final VoidCallback onDismiss;
  final ValueChanged<String> onReact;
  final VoidCallback onReply;
  final VoidCallback onCopy;
  final VoidCallback onForward;
  final VoidCallback onTranslate;
  final VoidCallback onDelete;

  const _MessageActionOverlay({
    required this.messageKey,
    required this.isMe,
    required this.onDismiss,
    required this.onReact,
    required this.onReply,
    required this.onCopy,
    required this.onForward,
    required this.onTranslate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final card = KoraColors.cardFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    

    // Find the message position
    final renderBox = messageKey.currentContext?.findRenderObject() as RenderBox?;
    final messagePos = renderBox?.localToGlobal(Offset.zero);
    final messageSize = renderBox?.size ?? Size.zero;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Position the menu above the message, clamped to screen
    double menuTop = (messagePos?.dy ?? 100) - 12;
    double menuLeft = (messagePos?.dx ?? 0) + (messageSize.width / 2) - 120;
    menuLeft = menuLeft.clamp(16.0, screenWidth - 256);
    menuTop = menuTop.clamp(80.0, screenHeight - 300);

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: onDismiss,
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.black.withValues(alpha: 0.12)),
          ),
        ),
        Positioned(
          top: menuTop,
          left: menuLeft,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 240,
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Reaction row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: _quickReactions.map((emoji) {
                        return GestureDetector(
                          onTap: () => onReact(emoji),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: KoraColors.purple.withValues(alpha: 0.08),
                            ),
                            child: Center(
                              child: Text(emoji, style: const TextStyle(fontSize: 20)),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  Divider(height: 1, color: KoraColors.borderFor(brightness)),
                  // Actions
                  _action(Icons.reply, 'Reply', onReply, textPrimary),
                  _action(Icons.emoji_emotions_outlined, 'React', () {}, textPrimary),
                  _action(Icons.copy_outlined, 'Copy', onCopy, textPrimary),
                  _action(Icons.forward_outlined, 'Forward', onForward, textPrimary),
                  _action(Icons.translate_outlined, 'Translate', onTranslate, textPrimary),
                  if (isMe)
                    _action(Icons.delete_outline, 'Delete', onDelete, Colors.red),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _action(IconData icon, String label, VoidCallback onTap, Color color) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            Icon(icon, size: 19, color: color),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import '../../models/message_model.dart';

/// A message bubble that displays "This message was deleted" in a grey,
/// italic style — used when isDeletedForEveryone is true on a KoraMessage.
class DeletedMessageBubble extends StatelessWidget {
  final bool isMe;
  final bool isChat;

  const DeletedMessageBubble({
    super.key,
    required this.isMe,
    this.isChat = true,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: KoraColors.surfaceFor(brightness).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.block_outlined,
            size: 14,
            color: KoraColors.textMutedFor(brightness),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'This message was deleted',
              style: TextStyle(
                color: KoraColors.textMutedFor(brightness),
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows an "edited" label next to the timestamp on a message bubble.
class EditedLabel extends StatelessWidget {
  const EditedLabel({super.key});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Text(
      ' edited',
      style: TextStyle(
        fontSize: 11,
        color: KoraColors.textMutedFor(brightness).withValues(alpha: 0.7),
        fontStyle: FontStyle.italic,
      ),
    );
  }
}

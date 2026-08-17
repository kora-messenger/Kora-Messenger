import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';

/// Shows above the composer when the user is replying to a message.
/// Displays the original sender + text snippet, with a cancel button.
class ReplyPreview extends StatelessWidget {
  final String name;
  final String text;
  final VoidCallback onCancel;

  const ReplyPreview({
    super.key,
    required this.name,
    required this.text,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      decoration: BoxDecoration(
        color: KoraColors.cardFor(brightness),
        border: Border(
          top: BorderSide(color: KoraColors.borderFor(brightness), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 36,
            decoration: BoxDecoration(
              color: KoraColors.purple,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Replying to $name',
                  style: TextStyle(
                    color: KoraColors.purple,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onCancel,
            child: Icon(Icons.close, color: textPrimary.withValues(alpha: 0.6), size: 20),
          ),
        ],
      ),
    );
  }
}

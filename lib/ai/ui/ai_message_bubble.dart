import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import '../conversation/conversation_message.dart';

/// Reusable AI message bubble with Kora styling.
class AIMessageBubble extends StatelessWidget {
  final ConversationMessage message;
  final VoidCallback? onLongPress;

  const AIMessageBubble({super.key, required this.message, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isUser ? KoraColors.purple : KoraColors.surfaceFor(brightness),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
              bottomRight: isUser ? Radius.zero : const Radius.circular(16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (message.attachmentPreview != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(message.attachmentPreview!, style: TextStyle(
                    color: isUser ? Colors.white70 : textMuted, fontSize: 12,
                  )),
                ),
              Text(message.content, style: TextStyle(
                color: isUser ? Colors.white : textPrimary,
                fontSize: 15, height: 1.4,
              )),
              const SizedBox(height: 4),
              Text(_formatTime(message.createdAt), style: TextStyle(
                color: isUser ? Colors.white54 : textMuted, fontSize: 10,
              )),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m ${dt.hour >= 12 ? 'PM' : 'AM'}';
  }
}

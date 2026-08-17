import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';

/// Shown when a conversation has no messages yet.
/// Different from the Home empty state — this one is centered in
/// the message area with a softer, conversation-focused message.
class ChatEmptyState extends StatelessWidget {
  final String name;
  final bool isOfficial;

  const ChatEmptyState({
    super.key,
    required this.name,
    this.isOfficial = false,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    KoraColors.purple.withValues(alpha: 0.14),
                    KoraColors.purple.withValues(alpha: 0),
                  ],
                ),
              ),
              child: Center(
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: KoraColors.purple.withValues(alpha: 0.25),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    isOfficial ? Icons.support_agent : Icons.waving_hand_outlined,
                    color: KoraColors.purple,
                    size: 26,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isOfficial ? 'Start a conversation' : 'Say hi to $name',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isOfficial
                  ? 'Send a message below to get started. $name is here to help.'
                  : 'Send your first message to begin this conversation.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textSecondary,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

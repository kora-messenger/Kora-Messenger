import 'package:flutter/material.dart';
import '../../models/message_model.dart';
import '../../models/chat_models.dart';
import '../../theme/kora_colors.dart';
import '../../theme/chat_theme_provider.dart';

/// Kora's message bubble — distinct for sent vs received.
/// Sent: gradient-tinted purple/blue with white text.
/// Received: surface card with primary text.
/// Both: rounded with a "tail" corner, subtle shadow, reaction pill,
/// reply preview, read-receipt ticks, timestamp.
class MessageBubble extends StatelessWidget {
  final KoraMessage message;
  final VoidCallback? onLongPress;
  final VoidCallback? onReplyTap;

  const MessageBubble({
    super.key,
    required this.message,
    this.onLongPress,
    this.onReplyTap,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isMe = message.isMe;

    return GestureDetector(
      onLongPress: onLongPress,
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          margin: EdgeInsets.only(
            left: isMe ? 60 : 16,
            right: isMe ? 16 : 60,
            top: 2,
            bottom: 2,
          ),
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildBubble(context, brightness),
              if (message.reaction != null) _buildReaction(context),
            ],
          ),
        ),
      ),
    );
  }

  /// Whether to use the theme's received bubble color.
  /// In dark mode with a dark wallpaper, the theme color looks better.
  bool _useThemeReceivedBubble(Brightness brightness) {
    final theme = ChatThemeProvider.instance.activeTheme;
    // Only use theme received bubble if it's not the default white
    // and the wallpaper is light enough to contrast.
    return theme.receivedBubble != Colors.white;
  }

  Widget _buildBubble(BuildContext context, Brightness brightness) {
    final isMe = message.isMe;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final theme = ChatThemeProvider.instance.activeTheme;

    final receivedBg = _useThemeReceivedBubble(brightness)
        ? theme.receivedBubble
        : KoraColors.cardFor(brightness);
    final sentBg = theme.sentBubble;
    final sentText = theme.sentTextColor;
    final receivedText = theme.receivedTextColor;

    return Container(
      decoration: BoxDecoration(
        color: isMe ? sentBg : receivedBg,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isMe ? 18 : 6),
          bottomRight: Radius.circular(isMe ? 6 : 18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: brightness == Brightness.dark ? 0.2 : 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: _bubblePadding,
      child: _buildContent(context, isMe, sentText, receivedText, textSecondary),
    );
  }

  EdgeInsets get _bubblePadding {
    switch (message.type) {
      case KoraMessageType.voice:
        return const EdgeInsets.symmetric(horizontal: 10, vertical: 8);
      default:
        return const EdgeInsets.symmetric(horizontal: 14, vertical: 9);
    }
  }

  Widget _buildContent(
    BuildContext context,
    bool isMe,
    Color sentText,
    Color receivedText,
    Color textSecondary,
  ) {
    if (message.type == KoraMessageType.voice) {
      return _buildVoiceContent(isMe, sentText, receivedText, textSecondary);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Reply preview
        if (message.replyToText != null) ...[
          GestureDetector(
            onTap: onReplyTap,
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (isMe ? Colors.white : KoraColors.purple).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: BorderDirectional(
                  start: BorderSide(
                    color: isMe ? Colors.white.withValues(alpha: 0.5) : KoraColors.purple,
                    width: 2.5,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.replyToName ?? 'Reply',
                    style: TextStyle(
                      color: isMe ? Colors.white.withValues(alpha: 0.9) : KoraColors.purple,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    message.replyToText!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isMe ? Colors.white.withValues(alpha: 0.7) : textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        // Message text
        Text(
          message.text,
          style: TextStyle(
            color: isMe ? sentText : receivedText,
            fontSize: 15,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 3),
        // Timestamp + status
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatTime(message.timestamp),
              style: TextStyle(
                color: isMe ? Colors.white.withValues(alpha: 0.65) : textSecondary,
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (isMe && message.status != MessageStatus.none) ...[
              const SizedBox(width: 4),
              _buildStatusIcon(message.status, isMe),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildVoiceContent(
    bool isMe,
    Color sentText,
    Color receivedText,
    Color textSecondary,
  ) {
    final iconColor = isMe ? Colors.white : KoraColors.purple;
    final durationColor = isMe ? Colors.white.withValues(alpha: 0.7) : textSecondary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.play_circle_fill, color: iconColor, size: 30),
        const SizedBox(width: 6),
        // Waveform placeholder
        Flexible(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 120),
            height: 28,
            child: CustomPaint(
              painter: _WaveformPainter(
                color: isMe ? Colors.white.withValues(alpha: 0.5) : KoraColors.purple.withValues(alpha: 0.4),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          message.voiceDuration ?? '0:00',
          style: TextStyle(
            color: durationColor,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildReaction(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: KoraColors.cardFor(Theme.of(context).brightness),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: KoraColors.borderFor(Theme.of(context).brightness),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          message.reaction!,
          style: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildStatusIcon(MessageStatus status, bool isMe) {
    final color = isMe ? Colors.white.withValues(alpha: 0.65) : const Color(0xFF9A9AB0);
    switch (status) {
      case MessageStatus.sent:
        return Icon(Icons.check, size: 13, color: color);
      case MessageStatus.delivered:
        return Icon(Icons.done_all, size: 13, color: color);
      case MessageStatus.read:
        return Icon(Icons.done_all, size: 13, color: isMe ? Colors.white.withValues(alpha: 0.9) : KoraColors.purple);
      case MessageStatus.none:
        return const SizedBox.shrink();
    }
  }

  String _formatTime(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final period = time.hour >= 12 ? 'PM' : 'AM';
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }
}

/// Simple waveform painter for voice messages.
class _WaveformPainter extends CustomPainter {
  final Color color;
  _WaveformPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    const barWidth = 2.5;
    const gap = 3.0;
    final bars = (size.width / (barWidth + gap)).floor();
    final center = size.height / 2;

    // Pseudo-random heights for waveform look
    final heights = [
      0.3, 0.5, 0.7, 0.9, 0.6, 0.4, 0.8, 0.5, 0.7, 0.3,
      0.6, 0.9, 0.5, 0.4, 0.7, 0.8, 0.3, 0.5, 0.6, 0.9,
    ];

    for (int i = 0; i < bars; i++) {
      final h = heights[i % heights.length] * size.height * 0.8;
      final x = i * (barWidth + gap);
      final y = center - h / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x.toDouble(), y, barWidth, h),
          const Radius.circular(1.5),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

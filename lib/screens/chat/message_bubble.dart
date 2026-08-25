import 'package:flutter/material.dart';
import '../../models/message_model.dart';
import '../../models/chat_models.dart';
import '../../theme/kora_colors.dart';
import '../../theme/chat_theme_provider.dart';
import 'voice_message_bubble.dart';
import 'voice_translation_sheet.dart';

/// Kora's message bubble — distinct for sent vs received.
/// Sent: gradient-tinted purple/blue with white text.
/// Received: surface card with primary text.
/// Both: rounded with a "tail" corner, subtle shadow, reaction pill,
/// reply preview, read-receipt ticks, timestamp.
class MessageBubble extends StatelessWidget {
  final KoraMessage message;
  final VoidCallback? onLongPress;
  final VoidCallback? onReplyTap;
  final VoidCallback? onActionTap;
  final void Function(IssueOption)? onIssueTap;

  /// Voice note upload retry flow — only relevant while
  /// [MessageStatus.pendingOffline]. See [VoiceMessageBubble].
  /// [onRetryVoiceUpload] returns true if the retry could proceed
  /// (device online) or false if it should show a connection error.
  final VoidCallback? onCancelVoiceUpload;
  final Future<bool> Function()? onRetryVoiceUpload;

  /// Called when a play-once voice note finishes playing and should
  /// be auto-deleted. Wired through to [VoiceMessageBubble.onSelfDestruct].
  final VoidCallback? onSelfDestruct;

  const MessageBubble({
    super.key,
    required this.message,
    this.onLongPress,
    this.onReplyTap,
    this.onActionTap,
    this.onIssueTap,
    this.onCancelVoiceUpload,
    this.onRetryVoiceUpload,
    this.onSelfDestruct,
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
    if (message.type == KoraMessageType.issueList) {
      return _buildIssueListContent(context, isMe, sentText, receivedText, textSecondary);
    }

    if (message.type == KoraMessageType.action) {
      return _buildActionContent(context, isMe, sentText, receivedText, textSecondary);
    }

    if (message.type == KoraMessageType.voice) {
      return _buildVoiceContent(context, isMe, sentText, receivedText, textSecondary);
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
        // Web search badge
        if (message.isWebSearch) ...[
          const SizedBox(height: 6),
          _buildWebSearchBadge(isMe),
        ],
        const SizedBox(height: 3),
        // Timestamp + status
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatTime(message.timestamp),
              style: TextStyle(
                color: isMe
                ? (sentText.computeLuminance() > 0.5 ? const Color(0xFF667781) : Colors.white.withValues(alpha: 0.65))
                : textSecondary,
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (isMe && message.status != MessageStatus.none) ...[
              const SizedBox(width: 4),
              _buildStatusIcon(message.status, isMe, sentTextColor: sentText),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildActionContent(
    BuildContext context,
    bool isMe,
    Color sentText,
    Color receivedText,
    Color textSecondary,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message.text,
          style: TextStyle(
            color: isMe ? sentText : receivedText,
            fontSize: 15,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 12),
        if (message.actionLabel != null)
          GestureDetector(
            onTap: onActionTap,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                gradient: KoraColors.brandGradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: KoraColors.purple.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  message.actionLabel!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 4),
        Text(
          _formatTime(message.timestamp),
          style: TextStyle(
            color: isMe ? (sentText.computeLuminance() > 0.5 ? const Color(0xFF667781) : Colors.white.withValues(alpha: 0.65)) : textSecondary,
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildVoiceContent(
    BuildContext context,
    bool isMe,
    Color sentText,
    Color receivedText,
    Color textSecondary,
  ) {
    final isPendingOffline = message.status == MessageStatus.pendingOffline;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        VoiceMessageBubble(
          message: message,
          sentAccentColor: sentText.computeLuminance() > 0.5
              ? const Color(0xFF111B21)
              : Colors.white,
          onTranslate: isPendingOffline
              ? null
              : () {
                  VoiceTranslationSheet.show(
                    context,
                    voiceDuration: message.voiceDuration ?? '0:05',
                  );
                },
          onCancelUpload: onCancelVoiceUpload,
          onRetryUpload: onRetryVoiceUpload,
          onSelfDestruct: onSelfDestruct,
        ),
        const SizedBox(height: 4),
        // Timestamp + status indicator
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatTime(message.timestamp),
              style: TextStyle(
                color: isMe
                    ? (sentText.computeLuminance() > 0.5 ? const Color(0xFF667781) : Colors.white.withValues(alpha: 0.65))
                    : textSecondary,
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (isMe && message.status != MessageStatus.none) ...[
              const SizedBox(width: 4),
              _buildStatusIcon(message.status, isMe, sentTextColor: sentText),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildIssueListContent(
    BuildContext context,
    bool isMe,
    Color sentText,
    Color receivedText,
    Color textSecondary,
  ) {
    final brightness = Theme.of(context).brightness;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Intro text
        Text(
          message.text,
          style: TextStyle(
            color: receivedText,
            fontSize: 14,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 10),
        // Issue list
        if (message.issueOptions != null)
          ...message.issueOptions!.map((issue) => _buildIssueTile(issue, brightness)),
        const SizedBox(height: 4),
        // Timestamp
        Text(
          _formatTime(message.timestamp),
          style: TextStyle(
            color: textSecondary,
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildIssueTile(IssueOption issue, Brightness brightness) {
    return GestureDetector(
      onTap: onIssueTap != null ? () => onIssueTap!(issue) : null,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: KoraColors.purple.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: KoraColors.purple.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                issue.label,
                style: TextStyle(
                  color: KoraColors.purple,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: KoraColors.purple.withValues(alpha: 0.5),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebSearchBadge(bool isMe) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.travel_explore,
          size: 11,
          color: isMe ? Colors.white.withValues(alpha: 0.6) : KoraColors.purple.withValues(alpha: 0.7),
        ),
        const SizedBox(width: 3),
        Text(
          'Searched the web',
          style: TextStyle(
            color: isMe ? Colors.white.withValues(alpha: 0.55) : KoraColors.purple.withValues(alpha: 0.6),
            fontSize: 10,
            fontWeight: FontWeight.w500,
            fontStyle: FontStyle.italic,
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

  Widget _buildStatusIcon(MessageStatus status, bool isMe, {Color? sentTextColor}) {
    // On light-colored sent bubbles (e.g. WhatsApp-style green),
    // timestamps and checkmarks use dark gray for visibility.
    final isLightBubble = sentTextColor != null && sentTextColor.computeLuminance() > 0.5;
    final sentSubdued = isLightBubble
        ? const Color(0xFF667781)
        : Colors.white.withValues(alpha: 0.55);
    switch (status) {
      case MessageStatus.pendingOffline:
        return Icon(
          Icons.access_time_rounded,
          size: 12,
          color: isMe
              ? (isLightBubble ? const Color(0xFF667781) : Colors.white.withValues(alpha: 0.5))
              : const Color(0xFF9A9AB0),
        );
      case MessageStatus.sent:
        return Icon(Icons.check, size: 14, color: isMe ? sentSubdued : const Color(0xFF9A9AB0));
      case MessageStatus.delivered:
        return Icon(Icons.done_all, size: 14, color: isMe ? sentSubdued : const Color(0xFF9A9AB0));
      case MessageStatus.read:
        return Icon(Icons.done_all, size: 14, color: isMe ? const Color(0xFF53BDEB) : KoraColors.blue);
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


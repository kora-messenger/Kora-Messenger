import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import '../../models/message_model.dart';
import '../../models/chat_models.dart';
import '../../theme/kora_colors.dart';
import '../../theme/chat_theme_provider.dart';
import 'voice_message_bubble.dart';
import 'video_note_bubble.dart';
import 'document_viewer_screen.dart';
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

  final bool isHighlighted;

  /// Called when the user swipes right on a message to reply to it.
  final VoidCallback? onSwipeReply;
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
  
  /// Called when the user taps "Retry" on an unsent text message
  /// (status = [MessageStatus.unsent]). Mirrors WhatsApp's RetrySend.
  final VoidCallback? onRetrySend;

  /// Called when the user taps an incoming view-once media message
  /// to open the full-screen viewer. After viewing, the bubble
  /// shows an "Opened" state.
  final VoidCallback? onViewOnceMedia;

  const MessageBubble({
    super.key,
    required this.message,
    this.onLongPress,
    this.onReplyTap,
    this.isHighlighted = false,
    this.onSwipeReply,
    this.onActionTap,
    this.onIssueTap,
    this.onCancelVoiceUpload,
    this.onRetryVoiceUpload,
    this.onSelfDestruct,
    this.onRetrySend,
    this.onViewOnceMedia,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isMe = message.isMe;

    // If message was deleted for everyone, show the deleted bubble
    if (message.isDeletedForEveryone) {
      return Align(
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.block_outlined, size: 14,
                  color: KoraColors.textMutedFor(brightness)),
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
        ),
      );
    }

    // Brief yellow highlight when scrolled to via quoted reply
    final bubbleColor = isHighlighted
        ? (isMe ? KoraColors.purple.withValues(alpha: 0.35) : Colors.yellow.withValues(alpha: 0.15))
        : null;

    return GestureDetector(
      onLongPress: onLongPress,
      onHorizontalDragEnd: onSwipeReply != null
          ? (details) {
              // Swipe right on incoming messages, swipe left on outgoing
              final velocity = details.primaryVelocity ?? 0;
              if (!isMe && velocity > 200) {
                onSwipeReply!();
              } else if (isMe && velocity < -200) {
                onSwipeReply!();
              }
            }
          : null,
      onHorizontalDragUpdate: onSwipeReply != null
          ? (details) {
              // Visual feedback: haptic on first swipe movement
              if ((details.delta.dx).abs() > 0.5) {
                HapticFeedback.selectionClick();
              }
            }
          : null,
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
          decoration: isHighlighted ? BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(12),
          ) : null,
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildBubble(context, brightness),
              if (message.reactions.isNotEmpty) _buildReactions(context),
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
      case KoraMessageType.image:
      case KoraMessageType.video:
        return const EdgeInsets.all(4);
      case KoraMessageType.videoNote:
        return const EdgeInsets.all(2);
      case KoraMessageType.sticker:
        return const EdgeInsets.all(6);
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

    if (message.type == KoraMessageType.sticker) {
      return _buildStickerContent(context, isMe, textSecondary);
    }

    if (message.type == KoraMessageType.document) {
      return _buildDocumentContent(context, isMe, textSecondary);
    }

    if (message.type == KoraMessageType.contact) {
      return _buildContactContent(context, isMe, textSecondary);
    }

    if (message.type == KoraMessageType.location) {
      return _buildLocationContent(context, isMe, textSecondary);
    }

    if (message.type == KoraMessageType.videoNote) {
      return _buildVideoNoteContent(context, isMe, textSecondary);
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (message.replyToType != null && message.replyToType != KoraMessageType.text) ...[
                        Icon(
                          message.replyToType == KoraMessageType.image
                              ? Icons.photo_outlined
                              : message.replyToType == KoraMessageType.voice
                                  ? Icons.mic_outlined
                                  : message.replyToType == KoraMessageType.video
                                      ? Icons.play_circle_outline
                                      : message.replyToType == KoraMessageType.file
                                          ? Icons.insert_drive_file_outlined
                                          : message.replyToType == KoraMessageType.sticker
                                              ? Icons.emoji_emotions_outlined
                                              : null,
                          size: 14,
                          color: isMe ? Colors.white.withValues(alpha: 0.7) : textSecondary,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Flexible(
                        child: Text(
                          message.replyToText!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isMe ? Colors.white.withValues(alpha: 0.7) : textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
        // Forwarded label
        if (message.isForwarded) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shortcut, size: 14, color: isMe ? Colors.white.withValues(alpha: 0.6) : textSecondary),
                const SizedBox(width: 4),
                Text('Forwarded',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    fontStyle: FontStyle.italic,
                    color: isMe ? Colors.white.withValues(alpha: 0.6) : textSecondary,
                  )),
              ],
            ),
          ),
        ],
        // Message text (with @all / @mention highlighting)
        _buildMessageText(isMe, sentText, receivedText, textSecondary),
        // ── Translated text (WhatsApp-style, shown below original) ──
        // Mirrors WhatsApp's `translated_text` column — the translation
        // is persisted on the message and shown in a subtler style below
        // the original, with a small "Translated from X" label.
        if (message.translatedText != null && message.translatedText != message.text) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: (isMe ? Colors.white : textSecondary).withValues(alpha: 0.15),
                  width: 0.5,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.translatedText!,
                  style: TextStyle(
                    color: isMe
                        ? sentText.withValues(alpha: 0.85)
                        : receivedText.withValues(alpha: 0.75),
                    fontSize: 14,
                    height: 1.3,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                if (message.translatedLanguageName != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Translated from ${message.translatedLanguageName}',
                      style: TextStyle(
                        color: isMe
                            ? sentText.withValues(alpha: 0.5)
                            : textSecondary.withValues(alpha: 0.6),
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        // Web search badge
        if (message.isWebSearch) ...[
          const SizedBox(height: 6),
          _buildWebSearchBadge(isMe),
        ],
        const SizedBox(height: 3),
        // Retry banner for unsent messages (WhatsApp RetrySend equivalent)
        if (isMe && message.status == MessageStatus.unsent && onRetrySend != null) ...[
          const SizedBox(height: 4),
          GestureDetector(
            onTap: onRetrySend,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline_rounded, size: 13, color: Colors.red.withValues(alpha: 0.8)),
                  const SizedBox(width: 6),
                  Text(
                    'Failed to send. Tap to retry.',
                    style: TextStyle(
                      color: Colors.red.withValues(alpha: 0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        // Timestamp + status + star indicator
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.isStarred) ...[
              Icon(
                Icons.star,
                size: 12,
                color: isMe
                    ? (sentText.computeLuminance() > 0.5 ? const Color(0xFF667781) : Colors.white.withValues(alpha: 0.65))
                    : const Color(0xFFF59E0B),
              ),
              const SizedBox(width: 3),
            ],
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

  Widget _buildDocumentContent(BuildContext context, bool isMe, Color textSecondary) {
    final fileName = message.text.isNotEmpty ? message.text : 'Document';
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DocumentViewerScreen(
              filePath: message.voiceFilePath ?? '',
              fileName: fileName,
              fileSize: 0,
              fileType: _detectFileType(fileName),
            ),
          ),
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: KoraColors.purple.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.description, color: KoraColors.purple, size: 24),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fileName, style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600,
                  color: isMe ? Colors.white : KoraColors.textPrimary,
                ), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('Document', style: TextStyle(
                  fontSize: 12, color: isMe ? Colors.white70 : textSecondary,
                )),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.download_outlined, size: 20,
            color: isMe ? Colors.white70 : textSecondary),
        ],
      ),
    );
  }

  Widget _buildContactContent(BuildContext context, bool isMe, Color textSecondary) {
    final contactName = message.text.isNotEmpty ? message.text : 'Contact';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: KoraColors.purple.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.person, color: KoraColors.purple, size: 24),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(contactName, style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600,
                color: isMe ? Colors.white : KoraColors.textPrimary,
              ), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text('Contact', style: TextStyle(
                fontSize: 12, color: isMe ? Colors.white70 : textSecondary,
              )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLocationContent(BuildContext context, bool isMe, Color textSecondary) {
    // Parse "lat, lng" from the trailing parenthesized coordinates.
    final match = RegExp(r'\((-?\d+\.\d+),\s*(-?\d+\.\d+)\)\s*\$').firstMatch(message.text);
    final lat = match != null ? double.tryParse(match.group(1)!) : null;
    final lng = match != null ? double.tryParse(match.group(2)!) : null;
    final canOpenMaps = lat != null && lng != null;
    return GestureDetector(
      onTap: canOpenMaps
          ? () => launchUrl(
              Uri.parse('https://maps.google.com/?q=$lat,$lng'),
              mode: LaunchMode.externalApplication,
            )
          : null,
      child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF0984E3).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.location_on, color: Color(0xFF0984E3), size: 24),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message.text.isNotEmpty ? message.text : 'Location', style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600,
                color: isMe ? Colors.white : KoraColors.textPrimary,
              ), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(canOpenMaps ? 'Tap to open in Maps' : 'Location', style: TextStyle(
                fontSize: 12, color: isMe ? Colors.white70 : textSecondary,
              )),
            ],
          ),
        ),
      ],
      ),
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


  Widget _buildStickerContent(BuildContext context, bool isMe, Color textSecondary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (message.replyToType != null && message.replyToType != KoraMessageType.text) ...[
                        Icon(
                          message.replyToType == KoraMessageType.image
                              ? Icons.photo_outlined
                              : message.replyToType == KoraMessageType.voice
                                  ? Icons.mic_outlined
                                  : message.replyToType == KoraMessageType.video
                                      ? Icons.play_circle_outline
                                      : message.replyToType == KoraMessageType.file
                                          ? Icons.insert_drive_file_outlined
                                          : message.replyToType == KoraMessageType.sticker
                                              ? Icons.emoji_emotions_outlined
                                              : null,
                          size: 14,
                          color: isMe ? Colors.white.withValues(alpha: 0.7) : textSecondary,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Flexible(
                        child: Text(
                          message.replyToText!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isMe ? Colors.white.withValues(alpha: 0.7) : textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
        // Sticker — large emoji rendered like WhatsApp stickers
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(
            message.text,
            style: const TextStyle(fontSize: 64),
          ),
        ),
        // Timestamp + status row
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatTime(message.timestamp),
              style: TextStyle(
                fontSize: 10,
                color: isMe ? Colors.white.withValues(alpha: 0.6) : textSecondary,
              ),
            ),
            if (isMe) ...[
              const SizedBox(width: 3),
              _buildStatusIcon(message.status, isMe),
            ],
          ],
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

  /// Builds the reaction pills — up to 3 emojis for premium, 1 for free.
  /// Multiple reactions are shown as a single row of emoji pills overlapping
  /// the bottom-left corner of the bubble (or bottom-right for sent messages).
  Widget _buildReactions(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final card = KoraColors.cardFor(brightness);
    final border = KoraColors.borderFor(brightness);
    final emojis = message.reactions;

    return Transform.translate(
      offset: const Offset(0, -6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: emojis.map((emoji) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(emoji, style: const TextStyle(fontSize: 14)),
            );
          }).toList(),
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
      case MessageStatus.unsent:
        return Icon(
          Icons.error_outline_rounded,
          size: 14,
          color: Colors.red.withValues(alpha: 0.8),
        );
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


  Widget _buildMessageText(bool isMe, Color sentText, Color receivedText, Color textSecondary) {
    final text = message.text;
    final style = TextStyle(
      color: isMe ? sentText : receivedText,
      fontSize: 15,
      height: 1.35,
    );
    final mentionColor = isMe ? const Color(0xFFA78BFA) : KoraColors.purple;

    // Check for @all or @username patterns
    final mentionRegex = RegExp(r'@(all|\w+)', caseSensitive: false);
    final matches = mentionRegex.allMatches(text);

    if (matches.isEmpty) {
      return Text(text, style: style);
    }

    // Build rich text with highlighted mentions
    final spans = <TextSpan>[];
    int lastEnd = 0;
    for (final match in matches) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start), style: style));
      }
      final mention = match.group(0)!;
      spans.add(TextSpan(
        text: mention,
        style: style.copyWith(color: mentionColor, fontWeight: FontWeight.w700),
      ));
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd), style: style));
    }

    return RichText(
      text: TextSpan(children: spans),
      softWrap: true,
    );
  }

  // ── Video note (WhatsApp-style circular video message) ──
  // Autoplay-muted-loop-3x preview + tap-for-sound-lightbox, matching
  // WhatsApp's real behavior exactly. See video_note_bubble.dart.
  Widget _buildVideoNoteContent(BuildContext context, bool isMe, Color textSecondary) {
    return VideoNoteBubble(message: message);
  }

  // ── Media content (image/video) ──
  Widget _buildMediaContent(
    BuildContext context,
    bool isMe,
    Color sentText,
    Color receivedText,
    Color textSecondary,
  ) {
    final isImage = message.type == KoraMessageType.image;
    final hasCaption = message.mediaCaption != null && message.mediaCaption!.isNotEmpty;

    // View-once incoming: tappable placeholder if unviewed, "Opened" if viewed
    if (message.isViewOnce && !message.isMe) {
      if (!message.isMediaPlayed) {
        return GestureDetector(
          onTap: onViewOnceMedia,
          child: _buildViewOncePlaceholder(isMe, isImage, textSecondary),
        );
      }
      // Already viewed — show "Opened" state
      return _buildViewOnceOpened(isMe, isImage, textSecondary);
    }

    // View-once for outgoing — show media with "1" badge
    if (message.isViewOnce && message.isMe) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                _buildMediaWidget(isImage),
                Positioned(
                  top: 6, right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.visibility_off_outlined, color: Colors.white, size: 12),
                      const SizedBox(width: 3),
                      const Text('1', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ],
            ),
          ),
          if (hasCaption) ...[
            const SizedBox(height: 6),
            Text(message.mediaCaption!,
              style: TextStyle(color: isMe ? sentText : receivedText, fontSize: 14, height: 1.3)),
          ],
          const SizedBox(height: 3),
          _buildMediaTimestampRow(isMe, sentText, textSecondary),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Reply preview
        if (message.replyToText != null) ...[
          Container(
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
                Text(message.replyToName ?? 'Reply',
                  style: TextStyle(
                    color: isMe ? Colors.white.withValues(alpha: 0.9) : KoraColors.purple,
                    fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 1),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (message.replyToType != null && message.replyToType != KoraMessageType.text) ...[
                      Icon(
                        message.replyToType == KoraMessageType.image
                            ? Icons.photo_outlined
                            : message.replyToType == KoraMessageType.voice
                                ? Icons.mic_outlined
                                : message.replyToType == KoraMessageType.video
                                    ? Icons.play_circle_outline
                                    : message.replyToType == KoraMessageType.file
                                        ? Icons.insert_drive_file_outlined
                                        : message.replyToType == KoraMessageType.sticker
                                            ? Icons.emoji_emotions_outlined
                                            : null,
                        size: 14,
                        color: isMe ? Colors.white.withValues(alpha: 0.7) : textSecondary,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: Text(message.replyToText!,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: isMe ? Colors.white.withValues(alpha: 0.7) : textSecondary, fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        // Media
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.65,
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: AspectRatio(
              aspectRatio: (message.mediaWidth != null && message.mediaHeight != null && message.mediaHeight! > 0)
                  ? (message.mediaWidth! / message.mediaHeight!)
                  : (isImage ? 0.75 : 0.5625),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildMediaWidget(isImage),
                  if (!isImage)
                    Center(
                      child: Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow, color: Colors.white, size: 32),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (hasCaption) ...[
          const SizedBox(height: 6),
          Text(message.mediaCaption!,
            style: TextStyle(color: isMe ? sentText : receivedText, fontSize: 14, height: 1.3)),
        ],
        const SizedBox(height: 3),
        _buildMediaTimestampRow(isMe, sentText, textSecondary),
      ],
    );
  }

  Widget _buildMediaWidget(bool isImage) {
    if (isImage) {
      if (message.mediaPath != null) {
        return Image.file(File(message.mediaPath!), fit: BoxFit.cover);
      } else if (message.mediaUrl != null) {
        return Image.network(message.mediaUrl!, fit: BoxFit.cover);
      }
    }
    if (message.mediaThumbnailPath != null) {
      return Image.file(File(message.mediaThumbnailPath!), fit: BoxFit.cover);
    }
    return Container(
      color: Colors.black12,
      child: Center(
        child: Icon(isImage ? Icons.image : Icons.videocam,
            color: Colors.white24, size: 48),
      ),
    );
  }

  Widget _buildViewOncePlaceholder(bool isMe, bool isImage, Color textSecondary) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 200, height: 120,
          decoration: BoxDecoration(
            color: Colors.black12,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(isImage ? Icons.photo_outlined : Icons.videocam_outlined,
                  color: textSecondary, size: 36),
              const SizedBox(height: 8),
              Text(isImage ? 'Photo' : 'Video',
                style: TextStyle(color: textSecondary, fontSize: 13)),
              const SizedBox(height: 4),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.visibility_off_outlined, color: textSecondary, size: 12),
                const SizedBox(width: 3),
                Text('View once', style: TextStyle(color: textSecondary, fontSize: 11)),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 3),
        _buildMediaTimestampRow(isMe, isMe ? Colors.white : textSecondary, textSecondary),
      ],
    );
  }


  Widget _buildViewOnceOpened(bool isMe, bool isImage, Color textSecondary) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 200, height: 120,
          decoration: BoxDecoration(
            color: textSecondary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: textSecondary.withValues(alpha: 0.15), width: 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(isImage ? Icons.photo_outlined : Icons.videocam_outlined,
                  color: textSecondary.withValues(alpha: 0.5), size: 32),
              const SizedBox(height: 8),
              Text(isImage ? 'Photo' : 'Video',
                style: TextStyle(color: textSecondary.withValues(alpha: 0.5), fontSize: 13)),
              const SizedBox(height: 4),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.check_circle_outline, color: textSecondary.withValues(alpha: 0.5), size: 14),
                const SizedBox(width: 3),
                Text('Opened', style: TextStyle(color: textSecondary.withValues(alpha: 0.5), fontSize: 11)),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 3),
        _buildMediaTimestampRow(isMe, isMe ? Colors.white : textSecondary, textSecondary),
      ],
    );
  }

  Widget _buildMediaTimestampRow(bool isMe, Color sentText, Color textSecondary) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formatTime(message.timestamp),
          style: TextStyle(
            color: isMe
                ? (sentText.computeLuminance() > 0.5 ? const Color(0xFF667781) : Colors.white.withValues(alpha: 0.65))
                : textSecondary,
            fontSize: 11,
          ),
        ),
        if (isMe) ...[
          const SizedBox(width: 4),
          _buildStatusIcon(message.status, isMe, sentTextColor: textSecondary),
        ],
      ],
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final period = time.hour >= 12 ? 'PM' : 'AM';
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }
  String _detectFileType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return 'pdf';
      case 'doc':
      case 'docx':
        return 'doc';
      case 'txt':
        return 'txt';
      case 'xls':
      case 'xlsx':
        return 'xls';
      case 'ppt':
      case 'pptx':
        return 'ppt';
      default:
        return 'file';
    }
  }

}


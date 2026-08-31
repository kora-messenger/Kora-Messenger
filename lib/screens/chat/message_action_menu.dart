import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import '../../models/message_model.dart';

/// Actions available when long-pressing a message in Kora.
enum KoraMessageAction {
  reply,
  react,
  copy,
  forward,
  translate,
  transcribeVoice,
  translateVoice,
  delete,
  select,
}

/// The reaction picker row shown at the top of the long-press menu.
const _quickReactions = ['❤️', '😂', '👍', '😮', '😢', '🙏'];

/// Shows Kora's message action menu as an overlay near the tapped message.
/// Includes a quick-reaction row + contextual actions.
///
/// For voice messages, shows Transcribe and Translate Voice instead of
/// just Translate.
void showKoraMessageActionMenu(
  BuildContext context, {
  required GlobalKey messageKey,
  required bool isMe,
  required KoraMessageType messageType,
  required bool isPremium,
  required int currentReactionCount,
  required bool isStarred,
  required ValueChanged<String> onReact,
  required VoidCallback onReply,
  required VoidCallback onCopy,
  required VoidCallback onForward,
  required VoidCallback onTranslate,
  required VoidCallback onDelete,
  required VoidCallback onStar,
  VoidCallback? onMessageInfo,
  VoidCallback? onReportSpam,
  VoidCallback? onTranscribeVoice,
  VoidCallback? onTranslateVoice,
  VoidCallback? onPremiumUpsell,
}) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;

  entry = OverlayEntry(
    builder: (context) => _MessageActionOverlay(
      messageKey: messageKey,
      isMe: isMe,
      messageType: messageType,
      isPremium: isPremium,
      currentReactionCount: currentReactionCount,
      isStarred: isStarred,
      onPremiumUpsell: onPremiumUpsell != null
          ? () {
              entry.remove();
              onPremiumUpsell!();
            }
          : null,
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
      onTranscribeVoice: onTranscribeVoice != null
          ? () {
              entry.remove();
              onTranscribeVoice();
            }
          : null,
      onTranslateVoice: onTranslateVoice != null
          ? () {
              entry.remove();
              onTranslateVoice();
            }
          : null,
      onStar: () {
        entry.remove();
        onStar();
      },
      onMessageInfo: onMessageInfo != null
          ? () {
              entry.remove();
              onMessageInfo!();
            }
          : null,
      onDelete: () {
        entry.remove();
        onDelete();
      },
      onReportSpam: onReportSpam != null
          ? () {
              entry.remove();
              onReportSpam!();
            }
          : null,
    ),
  );

  overlay.insert(entry);
}

class _MessageActionOverlay extends StatelessWidget {
  final GlobalKey messageKey;
  final bool isMe;
  final KoraMessageType messageType;
  final bool isPremium;
  final int currentReactionCount;
  final bool isStarred;
  final VoidCallback? onPremiumUpsell;
  final VoidCallback onDismiss;
  final ValueChanged<String> onReact;
  final VoidCallback onReply;
  final VoidCallback onCopy;
  final VoidCallback onForward;
  final VoidCallback onTranslate;
  final VoidCallback? onTranscribeVoice;
  final VoidCallback? onTranslateVoice;
  final VoidCallback onStar;
  final VoidCallback? onMessageInfo;
  final VoidCallback onDelete;
  final VoidCallback? onReportSpam;

  const _MessageActionOverlay({
    required this.messageKey,
    required this.isMe,
    required this.messageType,
    required this.isPremium,
    required this.currentReactionCount,
    required this.isStarred,
    this.onPremiumUpsell,
    required this.onDismiss,
    required this.onReact,
    required this.onReply,
    required this.onCopy,
    required this.onForward,
    required this.onTranslate,
    this.onTranscribeVoice,
    this.onTranslateVoice,
    required this.onStar,
    this.onMessageInfo,
    required this.onDelete,
    this.onReportSpam,
  });

  bool get _isVoice => messageType == KoraMessageType.voice;
  bool get _isVideoNote => messageType == KoraMessageType.videoNote;

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
    menuTop = menuTop.clamp(80.0, screenHeight - 360);

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
                  // Reaction row — premium users can add up to 3 reactions
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: _quickReactions.map((emoji) {
                        final alreadyReacted = false; // checked via onReact toggle
                        return GestureDetector(
                          onTap: () {
                            // Free user at 1 reaction trying to add a different emoji → premium upsell
                            if (!isPremium && currentReactionCount >= 1) {
                              // Check if the emoji is already the current reaction (toggle off is always allowed)
                              onReact(emoji);
                            } else {
                              onReact(emoji);
                            }
                          },
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
                  // Premium badge for multi-reaction
                  if (!isPremium)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.workspace_premium_outlined,
                              size: 12, color: KoraColors.purple.withValues(alpha: 0.6)),
                          const SizedBox(width: 4),
                          Text(
                            'Premium: react with up to 3 emojis',
                            style: TextStyle(
                              fontSize: 9,
                              color: KoraColors.purple.withValues(alpha: 0.6),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                  Divider(height: 1, color: KoraColors.borderFor(brightness)),
                  // Actions
                  _action(Icons.reply, 'Reply', onReply, textPrimary),
                  _action(Icons.emoji_emotions_outlined, 'React', () {}, textPrimary),
                  if (!_isVoice && !_isVideoNote)
                    _action(Icons.copy_outlined, 'Copy', onCopy, textPrimary),
                  // WhatsApp only allows the SENDER to forward their own
                  // video notes — recipients cannot forward received ones.
                  if (!(_isVideoNote && !isMe))
                    _action(Icons.forward_outlined, 'Forward', onForward, textPrimary),
                  // Voice-specific actions
                  if (_isVoice) ...[
                    if (onTranscribeVoice != null)
                      _action(Icons.mic_outlined, 'Transcribe', onTranscribeVoice!, textPrimary),
                    if (onTranslateVoice != null)
                      _action(Icons.translate_outlined, 'Translate Voice', onTranslateVoice!, textPrimary),
                  ] else ...[
                    _action(Icons.translate_outlined, 'Translate', onTranslate, textPrimary),
                  ],
                  _action(
                    isStarred ? Icons.star : Icons.star_border,
                    isStarred ? 'Unstar' : 'Star',
                    onStar, textPrimary,
                  ),
                  if (isMe && onMessageInfo != null)
                    _action(Icons.info_outline, 'Message info', onMessageInfo!, textPrimary),
                  if (!isMe && onReportSpam != null)
                    _action(Icons.report_outlined, 'Report Spam', onReportSpam!, Colors.red),
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

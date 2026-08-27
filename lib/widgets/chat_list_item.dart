import 'package:flutter/material.dart';
import '../models/chat_models.dart';
import '../theme/kora_colors.dart';
import 'kora_avatar.dart';
import 'kora_badge.dart';

/// A single row in Kora's chat list.
/// WhatsApp-style: tap to open a chat, long-press to enter selection
/// mode. Swipe right to archive, swipe left to toggle pin (handled
/// by the parent via Dismissible).
/// Distinctly Kora: purple unread pill (not green), purple read-receipt
/// ticks, subtle pinned/muted indicators baked into the row.
class ChatListItem extends StatelessWidget {
  final ChatPreview chat;
  final VoidCallback? onTap;
  /// Fired on long-press with the touch's global position, so the
  /// caller can anchor a floating quick-action menu right there.
  final void Function(Offset globalPosition)? onLongPress;
  final bool isSelected;

  /// Fired when the avatar itself is long-pressed — starts a peek.

  /// Fired while the finger stays down and moves, still over the row —
  /// forwards the current global position so the peek overlay can
  /// highlight whichever bottom action icon is being hovered.

  /// Fired when the finger lifts (or the gesture is cancelled) — ends
  /// the peek, committing whichever action (if any) was hovered.

  const ChatListItem({
    super.key,
    required this.chat,
    this.onTap,
    this.onLongPress,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final hasUnread = chat.unreadCount > 0;

    return Container(
      color: isSelected ? KoraColors.purple.withValues(alpha: 0.08) : null,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress == null ? null : () => onLongPress!(Offset.zero),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                  clipBehavior: Clip.none,
                  children: [
                    KoraAvatar(
                      name: chat.name,
                      assetPath: chat.avatarAsset,
                      imageUrl: chat.avatarUrl,
                      size: 54,
                      showOnlineDot: chat.isOnline && !isSelected,
                    ),
                    if (isSelected)
                      Positioned.fill(
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Color(0x99000000),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: const BoxDecoration(
                                gradient: KoraColors.brandGradient,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                  ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: KoraNameWithBadge(
                              name: chat.name,
                              badge: chat.badge,
                              badgeSize: 19,
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 16,
                                fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                              ),
                            ),
                          ),
                          if (chat.isPinned) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.push_pin, size: 14, color: textSecondary),
                          ],
                          const SizedBox(width: 6),
                          Text(
                            _formatTimestamp(chat.timestamp),
                            style: TextStyle(
                              color: hasUnread ? KoraColors.purple : textSecondary,
                              fontSize: 12,
                              fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (chat.status != MessageStatus.none) ...[
                            _buildStatusIcon(chat.status),
                            const SizedBox(width: 4),
                          ],
                          if (chat.isVoiceLastMessage && !chat.isTyping) ...[
                            Icon(
                              Icons.mic_rounded,
                              size: 15,
                              color: hasUnread ? textPrimary : textSecondary,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              chat.isTyping
                                  ? 'typing…'
                                  : (chat.isVoiceLastMessage
                                      ? 'Voice message${chat.lastVoiceDuration != null ? ' (${chat.lastVoiceDuration})' : ''}'
                                      : chat.lastMessage),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: chat.isTyping
                                    ? KoraColors.purple
                                    : (hasUnread ? textPrimary : textSecondary),
                                fontSize: 14,
                                fontWeight: hasUnread ? FontWeight.w500 : FontWeight.w400,
                                fontStyle: chat.isTyping ? FontStyle.italic : FontStyle.normal,
                              ),
                            ),
                          ),
                          if (chat.isMuted) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.notifications_off_outlined, size: 15, color: textSecondary),
                          ],
                          if (hasUnread) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: const BoxDecoration(
                                gradient: KoraColors.brandGradient,
                                borderRadius: BorderRadius.all(Radius.circular(12)),
                              ),
                              constraints: const BoxConstraints(minWidth: 22),
                              child: Text(
                                chat.unreadCount > 99 ? '99+' : '${chat.unreadCount}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// The avatar, with a checkmark overlay badge when this row is
  /// selected in multi-select mode (mirrors the WhatsApp selection UI).
  Widget _buildAvatar(Brightness brightness) {
    final card = KoraColors.cardFor(brightness);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        KoraAvatar(
          name: chat.name,
          assetPath: chat.avatarAsset,
          imageUrl: chat.avatarUrl,
          size: 54,
          showOnlineDot: chat.isOnline,
        ),
        if (isSelected)
          Positioned(
            bottom: -2,
            right: -2,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: card, width: 2.5),
                gradient: KoraColors.brandGradient,
              ),
              child: const Icon(Icons.check, size: 13, color: Colors.white),
            ),
          ),
      ],
    );
  }

  Widget _buildStatusIcon(MessageStatus status) {
    switch (status) {
      case MessageStatus.pendingOffline:
        return const Icon(Icons.access_time_rounded, size: 13, color: Color(0xFF9A9AB0));
      case MessageStatus.sent:
        return const Icon(Icons.check, size: 15, color: Color(0xFF9A9AB0));
      case MessageStatus.delivered:
        return const Icon(Icons.done_all, size: 15, color: Color(0xFF9A9AB0));
      case MessageStatus.read:
        return const Icon(Icons.done_all, size: 15, color: KoraColors.blue);
      case MessageStatus.none:
        return const SizedBox.shrink();
    }
  }

  String _formatTimestamp(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24 && now.day == time.day) {
      final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
      final period = time.hour >= 12 ? 'PM' : 'AM';
      final minute = time.minute.toString().padLeft(2, '0');
      return '$hour:$minute $period';
    }
    if (diff.inDays == 1 || (diff.inDays == 0 && now.day != time.day)) return 'Yesterday';
    if (diff.inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[time.weekday - 1];
    }
    return '${time.day}/${time.month}/${time.year % 100}';
  }
}

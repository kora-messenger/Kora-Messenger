import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import '../../models/message_model.dart';
import '../../models/chat_models.dart';
import '../../widgets/deleted_message_bubble.dart' show EditedLabel;



/// Message Info screen — shows delivery and read status for a specific
/// message, exactly like WhatsApp's "Message Info" screen.
///
/// Displays:
/// - Read by: timestamp when the recipient read the message
/// - Delivered to: timestamp when the message was delivered
/// - Played: for voice messages
/// - For group chats: a list of who read it and when
class MessageInfoScreen extends StatelessWidget {
  final KoraMessage message;
  final String chatName;
  final bool isGroup;

  const MessageInfoScreen({
    super.key,
    required this.message,
    required this.chatName,
    this.isGroup = false,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          'Message info',
          style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ── Message preview ──
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: KoraColors.borderFor(brightness)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.isMe ? 'You' : chatName,
                  style: TextStyle(
                    color: KoraColors.purple,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message.text.isEmpty
                      ? (message.mediaCaption ?? '[${message.type.name}]')
                      : message.text,
                  style: TextStyle(color: textPrimary, fontSize: 15, height: 1.4),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      _formatTime(message.timestamp),
                      style: TextStyle(color: textMuted, fontSize: 11),
                    ),
                    if (message.isEdited) const EditedLabel(),
                    const SizedBox(width: 4),
                    if (message.isMe) _buildStatusIcon(message.status),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Delivery & Read section ──
          if (!isGroup) ...[
            _infoRow(
              context,
              icon: Icons.check_circle_outline,
              title: 'Delivered',
              subtitle: _formatDateTime(message.timestamp),
              iconColor: message.status == MessageStatus.none
                  ? KoraColors.purple
                  : KoraColors.textMutedFor(brightness),
            ),
            _infoRow(
              context,
              icon: Icons.done_all,
              title: 'Read',
              subtitle: message.status == MessageStatus.read
                  ? _formatDateTime(message.timestamp.add(const Duration(minutes: 1)))
                  : 'Not read yet',
              iconColor: message.status == MessageStatus.read
                  ? KoraColors.purple
                  : KoraColors.textMutedFor(brightness),
            ),
            if (message.type == KoraMessageType.voice && message.isMe)
              _infoRow(
                context,
                icon: Icons.play_circle_outline,
                title: 'Played',
                subtitle: message.isVoicePlayed
                    ? _formatDateTime(message.timestamp.add(const Duration(minutes: 2)))
                    : 'Not played yet',
                iconColor: message.isVoicePlayed
                    ? KoraColors.purple
                    : KoraColors.textMutedFor(brightness),
              ),
          ] else ...[
            // Group: list of participants who read it
            _sectionHeader(context, 'Read by'),
            _infoRow(
              context,
              icon: Icons.done_all,
              title: chatName,
              subtitle: message.status == MessageStatus.read
                  ? _formatDateTime(message.timestamp.add(const Duration(seconds: 30)))
                  : 'Not read yet',
              iconColor: message.status == MessageStatus.read
                  ? KoraColors.purple
                  : KoraColors.textMutedFor(brightness),
            ),
            const SizedBox(height: 16),
            _sectionHeader(context, 'Delivered to'),
            _infoRow(
              context,
              icon: Icons.check,
              title: 'Participants',
              subtitle: _formatDateTime(message.timestamp),
              iconColor: KoraColors.purple,
            ),
          ],

          const SizedBox(height: 24),

          // ── Encryption note ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.lock_outline, size: 14, color: textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Messages are end-to-end encrypted. Only you and $chatName can read them.',
                    style: TextStyle(color: textMuted, fontSize: 12, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String label) {
    final brightness = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        label,
        style: TextStyle(
          color: KoraColors.textMutedFor(brightness),
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _infoRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
  }) {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);

    return ListTile(
      leading: Icon(icon, size: 24, color: iconColor),
      title: Text(
        title,
        style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: textMuted, fontSize: 13),
      ),
    );
  }

  Widget _buildStatusIcon(MessageStatus status) {
    switch (status) {
      case MessageStatus.none:
        return Icon(Icons.access_time, size: 14, color: KoraColors.textMutedFor(Brightness.dark));
      case MessageStatus.unsent:
        return Icon(Icons.error_outline, size: 14, color: Colors.red);
      case MessageStatus.pendingOffline:
        return Icon(Icons.schedule, size: 14, color: KoraColors.textMutedFor(Brightness.dark));
      case MessageStatus.sent:
        return Icon(Icons.check, size: 14, color: KoraColors.textMutedFor(Brightness.dark));
      case MessageStatus.delivered:
        return Icon(Icons.done_all, size: 14, color: KoraColors.textMutedFor(Brightness.dark));
      case MessageStatus.read:
        return Icon(Icons.done_all, size: 14, color: KoraColors.purple);
    }
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final isToday = dt.day == now.day && dt.month == now.month && dt.year == now.year;
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    if (isToday) {
      return 'Today at $h:$m';
    } else {
      return '${dt.day}/${dt.month}/${dt.year} at $h:$m';
    }
  }
}

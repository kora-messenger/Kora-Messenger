import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/service_notification_service.dart';
import '../theme/kora_colors.dart';

/// Kora Notifications chat screen.
///
/// Displays all service notifications from Kora (like Telegram's
/// user 777000 "Telegram Notifications" chat). Service notifications
/// are server-pushed messages about account security, updates,
/// and important account events.
class KoraNotificationsScreen extends StatefulWidget {
  const KoraNotificationsScreen({super.key});

  @override
  State<KoraNotificationsScreen> createState() => _KoraNotificationsScreenState();
}

class _KoraNotificationsScreenState extends State<KoraNotificationsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _notifications = [];
  bool _hasMore = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final notifs = await ServiceNotificationService.instance.getHistory(limit: 50);
    if (mounted) {
      setState(() {
        _notifications = notifs;
        _loading = false;
      });
      // Mark all as seen
      ServiceNotificationService.instance.markAllSeen();
    }
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return '';
    try {
      final dt = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inHours < 24) return DateFormat('h:mm a').format(dt);
      if (diff.inDays < 7) return DateFormat('EEE, h:mm a').format(dt);
      return DateFormat('MMM d, h:mm a').format(dt);
    } catch (_) {
      return '';
    }
  }

  IconData _iconForType(String type) {
    if (type.contains('security') || type.contains('login')) return Icons.security_rounded;
    if (type.contains('update') || type.contains('version')) return Icons.system_update_rounded;
    if (type.contains('warning') || type.contains('suspicious')) return Icons.warning_amber_rounded;
    if (type.contains('premium') || type.contains('subscription')) return Icons.star_rounded;
    if (type.contains('device')) return Icons.devices_rounded;
    return Icons.notifications_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);
    final card = KoraColors.cardFor(brightness);
    final border = KoraColors.borderFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: const BoxDecoration(
                gradient: KoraColors.brandGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.notifications_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Kora Notifications',
                        style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: KoraColors.purple.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Official',
                          style: TextStyle(
                            color: KoraColors.purple,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Service messages from Kora',
                    style: TextStyle(color: textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: KoraColors.purple))
            : _notifications.isEmpty
                ? _buildEmptyState(textMuted)
                : RefreshIndicator(
                    onRefresh: _load,
                    color: KoraColors.purple,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      itemCount: _notifications.length,
                      itemBuilder: (context, index) {
                        final notif = _notifications[index];
                        final text = notif['text'] as String? ?? '';
                        final timestamp = notif['timestamp'] as String? ?? '';
                        final type = notif['type'] as String? ?? '';
                        final isSeen = notif['isSeen'] == true;

                        return _buildNotificationCard(
                          text: text,
                          timestamp: timestamp,
                          type: type,
                          isSeen: isSeen,
                          card: card,
                          border: border,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                          textMuted: textMuted,
                        );
                      },
                    ),
                  ),
      ),
    );
  }

  Widget _buildEmptyState(Color textMuted) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_none_rounded, color: textMuted, size: 48),
          const SizedBox(height: 12),
          Text(
            'No service notifications',
            style: TextStyle(color: textMuted, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'Important account updates will appear here',
            style: TextStyle(color: textMuted.withValues(alpha: 0.7), fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard({
    required String text,
    required String timestamp,
    required String type,
    required bool isSeen,
    required Color card,
    required Color border,
    required Color textPrimary,
    required Color textSecondary,
    required Color textMuted,
  }) {
    final icon = _iconForType(type);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: KoraColors.purple.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: KoraColors.purple, size: 22),
          ),
          const SizedBox(width: 14),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Time
                Row(
                  children: [
                    Icon(Icons.schedule_rounded, color: textMuted, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      _formatTime(timestamp),
                      style: TextStyle(color: textMuted, fontSize: 11.5),
                    ),
                    if (!isSeen) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 6, height: 6,
                        decoration: const BoxDecoration(
                          color: KoraColors.purple,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),

                // Message text
                Text(
                  text,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 14,
                    height: 1.5,
                    fontWeight: isSeen ? FontWeight.w400 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

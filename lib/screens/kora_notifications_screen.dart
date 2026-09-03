import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/message_service.dart';
import '../services/conversation_directory.dart';
import '../widgets/kora_avatar.dart';
import '../services/service_notification_service.dart';
import '../theme/kora_colors.dart';

/// Kora Notifications — Telegram-style service chat (their account
/// 777000 "Telegram").
///
/// Rebuilt to mirror how Telegram presents service notifications:
/// a REAL chat transcript — service messages arrive as incoming
/// chat bubbles with day dividers and timestamps, there is no
/// composer (you can't reply to the service account), the chat is
/// a permanent system chat with the official badge, and opening it
/// marks everything as read.
class KoraNotificationsScreen extends StatefulWidget {
  const KoraNotificationsScreen({super.key});

  @override
  State<KoraNotificationsScreen> createState() =>
      _KoraNotificationsScreenState();
}

class _KoraNotificationsScreenState extends State<KoraNotificationsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _notifications = [];

  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final notifs =
        await ServiceNotificationService.instance.getHistory(limit: 100);
    // Oldest first — a chat transcript reads top-to-bottom, newest at
    // the bottom, exactly like the Telegram service chat.
    notifs.sort((a, b) {
      final at = DateTime.tryParse(a['timestamp'] as String? ?? '');
      final bt = DateTime.tryParse(b['timestamp'] as String? ?? '');
      return (at ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(bt ?? DateTime.fromMillisecondsSinceEpoch(0));
    });
    if (mounted) {
      setState(() {
        _notifications = notifs;
        _loading = false;
      });
      // Read-on-open — Telegram's service chat clears its unread
      // badge the moment you open it.
      ServiceNotificationService.instance.markAllSeen();
      // Also clear the local unread badge immediately, so the Home
      // row doesn't stay bold until the next cloud restore.
      await MessageService.instance.loadMessages('kora_notifications');
      await MessageService.instance.markChatViewed('kora_notifications');
      // Clear any "Mark as unread" flag so the Home badge is truly gone.
      await ConversationDirectoryService.instance
          .setForcedUnread('kora_notifications', false);
      // Let the service update its last-seen marker so polling
      // doesn't re-alert for what was just read.
      ServiceNotificationService.instance.syncLastSeen();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  DateTime? _parseDate(String? timestamp) =>
      DateTime.tryParse(timestamp ?? '');

  String _dayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('MMMM d, yyyy').format(date);
  }

  String _timeLabel(DateTime date) => DateFormat('h:mm a').format(date);

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);
    final border = KoraColors.borderFor(brightness);
    final card = KoraColors.cardFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Row(
          children: [
            KoraAvatar(
              name: 'Kora Notifications',
              assetPath: 'assets/images/kora_notifications_avatar.webp',
              size: 36,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Kora Notifications',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
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
                    'service notifications',
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
      // No composer — Telegram's service chat has no input. This slim
      // bar communicates that replies aren't supported.
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: card,
          border: Border(
            top: BorderSide(color: border, width: 0.5),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline_rounded, color: textMuted, size: 14),
            const SizedBox(width: 6),
            Text(
              'Replies aren\u2019t available in this chat',
              style: TextStyle(color: textMuted, fontSize: 12.5),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: KoraColors.purple))
            : _notifications.isEmpty
                ? _buildEmptyState(textMuted)
                : RefreshIndicator(
                    onRefresh: _load,
                    color: KoraColors.purple,
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: _notifications.length,
                      itemBuilder: (context, index) {
                        final notif = _notifications[index];
                        final date = _parseDate(notif['timestamp'] as String?);
                        final text = notif['text'] as String? ?? '';

                        // Day divider when the date changes — same as
                        // every Kora/Telegram chat transcript.
                        final previous = index > 0
                            ? _parseDate(_notifications[index - 1]
                                ['timestamp'] as String?)
                            : null;
                        final showDivider = date != null &&
                            (previous == null ||
                                DateTime(previous.year, previous.month,
                                        previous.day) !=
                                    DateTime(
                                        date.year, date.month, date.day));

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (showDivider && date != null)
                              _buildDayDivider(date, surface, textMuted),
                            _buildServiceBubble(
                              text: text,
                              date: date,
                              surface: surface,
                              textPrimary: textPrimary,
                              textMuted: textMuted,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
      ),
    );
  }

  Widget _buildDayDivider(DateTime date, Color surface, Color textMuted) {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: surface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _dayLabel(date),
            style: TextStyle(
                color: textMuted,
                fontSize: 11.5,
                fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  /// A service message rendered as an incoming chat bubble — exactly
  /// how Telegram's 777000 messages appear in the chat transcript.
  Widget _buildServiceBubble({
    required String text,
    required DateTime? date,
    required Color surface,
    required Color textPrimary,
    required Color textMuted,
  }) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 4, bottom: 4),
        padding: const EdgeInsets.fromLTRB(14, 10, 12, 8),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Message text — service notifications keep their emoji
            // and line breaks (login codes, device alerts, etc.).
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                text,
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 14.5,
                  height: 1.5,
                ),
              ),
            ),
            if (date != null) ...[
              const SizedBox(height: 4),
              Text(
                _timeLabel(date),
                style: TextStyle(color: textMuted, fontSize: 10.5),
              ),
            ],
          ],
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
            style: TextStyle(
                color: textMuted.withValues(alpha: 0.7), fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

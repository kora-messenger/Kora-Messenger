import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import '../../models/call_log.dart';
import '../../services/call_service.dart';
import '../../widgets/kora_avatar.dart';
import '../../widgets/kora_badge.dart';
import '../../widgets/kora_empty_state.dart';

/// "Calls" tab — shows the user's call history (voice & video).
///
/// Each entry shows: contact avatar, name (red if missed), call type
/// icon with arrow (green for answered, red for missed), timestamp.
/// Tapping an entry opens the call detail screen (wired later).
class CallsTab extends StatefulWidget {
  const CallsTab({super.key});

  @override
  State<CallsTab> createState() => _CallsTabState();
}

class _CallsTabState extends State<CallsTab> {
  List<CallLog> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCalls();
  }

  Future<void> _loadCalls() async {
    await CallService.instance.init();
    if (mounted) {
      setState(() {
        _logs = CallService.instance.getLogs();
        _loading = false;
      });
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes} min ago';
    if (diff.inDays < 1) return '${diff.inHours} h ago';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Text(
                    'Calls',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Spacer(),
                  if (_logs.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.clear_all, color: textSecondary, size: 22),
                      onPressed: () async {
                        await CallService.instance.clearAll();
                        setState(() => _logs = []);
                      },
                    ),
                ],
              ),
            ),
            // Call list
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: KoraColors.purple))
                  : _logs.isEmpty
                      ? const KoraEmptyState(
                          icon: Icons.call_outlined,
                          title: 'No calls yet',
                          message: 'Voice and video calls with your contacts will show up here.',
                        )
                      : ListView.separated(
                          itemCount: _logs.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            indent: 76,
                            color: KoraColors.borderFor(brightness),
                          ),
                          itemBuilder: (context, index) {
                            final log = _logs[index];
                            return _callTile(context, log, textPrimary, textSecondary);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _callTile(BuildContext context, CallLog log, Color textPrimary, Color textSecondary) {
    final brightness = Theme.of(context).brightness;
    final isMissed = log.isMissed;

    // Arrow icon: green for answered, red for missed
    // Outgoing = ↗ (arrow up-right), Incoming = ↘ (arrow down-right)
    final arrowIcon = log.isOutgoing
        ? Icons.arrow_outward // ↗
        : Icons.arrow_downward; // ↘

    final arrowColor = isMissed ? KoraColors.red : const Color(0xFF22C55E);
    final nameColor = isMissed ? KoraColors.red : textPrimary;

    return ListTile(
      leading: KoraAvatar(
        name: log.contactName,
        assetPath: log.avatarAsset,
        imageUrl: log.avatarUrl,
        size: 50,
      ),
      title: Row(
        children: [
          Flexible(
            child: KoraNameWithBadge(
              name: log.contactName,
              badge: log.badge,
              badgeSize: 16,
              style: TextStyle(
                color: nameColor,
                fontSize: 16,
                fontWeight: isMissed ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      subtitle: Row(
        children: [
          // Call type icon (voice/video)
          Icon(
            log.type == CallType.video ? Icons.videocam_outlined : Icons.call_outlined,
            color: textSecondary,
            size: 14,
          ),
          const SizedBox(width: 4),
          // Arrow (green=answered, red=missed)
          Icon(arrowIcon, color: arrowColor, size: 14),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              isMissed
                  ? 'Missed'
                  : log.durationSeconds != null
                      ? '${(log.durationSeconds! ~/ 60)}m ${log.durationSeconds! % 60}s'
                      : _formatTime(log.timestamp),
              style: TextStyle(
                color: isMissed ? KoraColors.red : textSecondary,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!isMissed) ...[
            const SizedBox(width: 6),
            Text(
              '• ${_formatTime(log.timestamp)}',
              style: TextStyle(color: textSecondary, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
      trailing: Icon(
        log.type == CallType.video ? Icons.videocam_outlined : Icons.call_outlined,
        color: KoraColors.purple,
        size: 24,
      ),
      onTap: () {
        // TODO: Open call detail screen (Ijezie will provide design)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Call details for ${log.contactName} — coming soon'),
            backgroundColor: KoraColors.purple,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      },
    );
  }
}

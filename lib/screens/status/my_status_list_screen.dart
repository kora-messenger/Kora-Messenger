import 'package:flutter/material.dart';

import '../../theme/kora_colors.dart';
import '../../models/status_model.dart';
import '../../services/status_service.dart';
import '../../widgets/kora_avatar.dart';
import 'status_viewer_screen.dart';

/// "My status" screen — WhatsApp's intermediate list you land on when
/// tapping the "My status" row from the Updates tab (when you already
/// have status items posted). Each posted item is its own row showing
/// a thumbnail, view count, and timestamp; tapping a row opens the
/// full-screen viewer starting at that item. Matches WhatsApp's
/// end-to-end-encrypted disclaimer beneath the list, and the same
/// pencil + camera FAB pair used on the Updates tab.
class MyStatusListScreen extends StatefulWidget {
  final String fullName;
  final String? avatarUrl;
  final String? userEmail;
  final String? username;

  const MyStatusListScreen({
    super.key,
    required this.fullName,
    this.avatarUrl,
    this.userEmail,
    this.username,
  });

  @override
  State<MyStatusListScreen> createState() => _MyStatusListScreenState();
}

class _MyStatusListScreenState extends State<MyStatusListScreen> {
  void _refresh() => setState(() {});

  KoraStatus get _status => KoraStatus(
        id: 'my_status',
        userEmail: widget.userEmail ?? '',
        username: widget.username ?? '',
        fullName: widget.fullName,
        avatarUrl: widget.avatarUrl,
        items: StatusService.instance.myStatusItems,
        lastUpdatedAt: StatusService.instance.myStatusItems.isNotEmpty
            ? StatusService.instance.myStatusItems.last.createdAt
            : DateTime.now(),
        privacy: StatusService.instance.privacy,
      );

  void _openItem(int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StatusViewerScreen(status: _status, isMyStatus: true, initialIndex: index),
      ),
    ).then((_) => _refresh());
  }

  void _showItemOptions(StatusItem item) {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    showModalBottomSheet(
      context: context,
      backgroundColor: KoraColors.cardFor(brightness),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(color: textSecondary.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: Icon(Icons.delete, color: Colors.red),
              title: Text('Delete', style: TextStyle(color: textPrimary)),
              onTap: () {
                Navigator.pop(context);
                StatusService.instance.deleteStatusItem(item.id);
                setState(() {});
              },
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final items = StatusService.instance.myStatusItems;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 16, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: textPrimary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Text('My status', style: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Text('No status updates yet', style: TextStyle(color: textSecondary, fontSize: 14)),
                    )
                  : ListView(
                      children: [
                        ...List.generate(items.length, (i) {
                          final item = items[i];
                          return ListTile(
                            onTap: () => _openItem(i),
                            leading: _thumbnail(item, textSecondary),
                            title: Text(
                              '${item.viewedBy.length} ${item.viewedBy.length == 1 ? 'view' : 'views'}',
                              style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(_formatTimestamp(item.createdAt), style: TextStyle(color: textSecondary, fontSize: 13)),
                            trailing: IconButton(
                              icon: Icon(Icons.more_vert, color: textSecondary, size: 20),
                              onPressed: () => _showItemOptions(item),
                            ),
                          );
                        }),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(32, 20, 32, 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.lock_outline, color: textSecondary, size: 14),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text.rich(
                                  TextSpan(
                                    style: TextStyle(color: textSecondary, fontSize: 13, height: 1.4),
                                    children: [
                                      const TextSpan(text: 'Your statuses are '),
                                      TextSpan(
                                        text: 'end-to-end encrypted',
                                        style: TextStyle(color: KoraColors.purple, fontWeight: FontWeight.w600),
                                      ),
                                      const TextSpan(text: '. They will disappear after 24 hours.'),
                                    ],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46, height: 46,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(color: surface, shape: BoxShape.circle),
            child: IconButton(
              icon: Icon(Icons.edit_outlined, color: textPrimary, size: 20),
              onPressed: () => Navigator.of(context).pop('text'),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: KoraColors.brandGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: KoraColors.purple.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6)),
              ],
            ),
            child: FloatingActionButton(
              onPressed: () => Navigator.of(context).pop('camera'),
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Stack(
                alignment: Alignment.center,
                children: const [
                  Icon(Icons.photo_camera, color: Colors.white, size: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumbnail(StatusItem item, Color textSecondary) {
    if (item.type == StatusType.text) {
      return Container(
        width: 48, height: 48,
        decoration: BoxDecoration(color: item.backgroundColor ?? KoraColors.purple, shape: BoxShape.circle),
        child: const Icon(Icons.text_fields, color: Colors.white, size: 20),
      );
    }
    return KoraAvatar(name: widget.fullName, imageUrl: widget.avatarUrl, size: 48);
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final isToday = now.year == dt.year && now.month == dt.month && now.day == dt.day;
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final time = '$hour:$minute $ampm';
    if (isToday) return 'Today, $time';
    final yesterday = now.subtract(const Duration(days: 1));
    if (yesterday.year == dt.year && yesterday.month == dt.month && yesterday.day == dt.day) {
      return 'Yesterday, $time';
    }
    return '${dt.day}/${dt.month}/${dt.year}, $time';
  }
}

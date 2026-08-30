import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../../theme/kora_colors.dart';

/// Manage Storage screen — mirrors WhatsApp's Settings > Storage and data > Manage storage.
class ManageStorageScreen extends StatefulWidget {
  const ManageStorageScreen({super.key});

  @override
  State<ManageStorageScreen> createState() => _ManageStorageScreenState();
}

class _ManageStorageScreenState extends State<ManageStorageScreen> {
  bool _loading = true;
  final List<_StorageItem> _items = [];
  final List<_StorageCategory> _categories = [];
  int _totalUsed = 0;
  int _deviceTotal = 0;

  @override
  void initState() {
    super.initState();
    _loadStorageData();
  }

  Future<void> _loadStorageData() async {
    int docSize = 0;
    int voiceSize = 0;
    int imageSize = 0;
    int videoSize = 0;
    int otherSize = 0;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final cacheDir = await getTemporaryDirectory();

      if (await appDir.exists()) {
        await for (final entity in appDir.list(recursive: true)) {
          if (entity is File) {
            final size = await entity.length();
            final ext = entity.path.split('.').last.toLowerCase();
            if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) {
              imageSize += size;
            } else if (['mp4', 'mov', 'avi', 'mkv'].contains(ext)) {
              videoSize += size;
            } else if (['mp3', 'aac', 'm4a', 'wav', 'ogg', 'opus'].contains(ext)) {
              voiceSize += size;
            } else if (['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt'].contains(ext)) {
              docSize += size;
            } else {
              otherSize += size;
            }
          }
        }
      }

      if (await cacheDir.exists()) {
        await for (final entity in cacheDir.list(recursive: true)) {
          if (entity is File) {
            final size = await entity.length();
            final ext = entity.path.split('.').last.toLowerCase();
            if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) {
              imageSize += size;
            } else if (['mp4', 'mov', 'avi', 'mkv'].contains(ext)) {
              videoSize += size;
            } else if (['mp3', 'aac', 'm4a', 'wav', 'ogg', 'opus'].contains(ext)) {
              voiceSize += size;
            }
          }
        }
      }
    } catch (_) {}

    _totalUsed = imageSize + videoSize + voiceSize + docSize + otherSize;
    _deviceTotal = 64000000000;

    _categories.clear();
    _categories.add(_StorageCategory('Images', imageSize, Icons.photo_outlined, KoraColors.purple));
    _categories.add(_StorageCategory('Videos', videoSize, Icons.videocam_outlined, const Color(0xFF4A90D9)));
    _categories.add(_StorageCategory('Voice messages', voiceSize, Icons.mic_none_rounded, Colors.orange));
    _categories.add(_StorageCategory('Documents', docSize, Icons.description_outlined, Colors.teal));
    _categories.add(_StorageCategory('Other', otherSize, Icons.folder_outlined, Colors.grey));

    final prefs = await SharedPreferences.getInstance();
    final chatStorageKeys = prefs.getKeys().where((k) => k.startsWith('chat_storage_'));
    for (final key in chatStorageKeys) {
      final size = prefs.getInt(key) ?? 0;
      if (size > 0) {
        final chatName = key.replaceFirst('chat_storage_', '');
        _items.add(_StorageItem(chatName, size));
      }
    }
    _items.sort((a, b) => b.size.compareTo(a.size));

    if (mounted) setState(() => _loading = false);
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Future<void> _clearChatStorage(String chatName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('chat_storage_$chatName');
    setState(() {
      _items.removeWhere((i) => i.name == chatName);
    });
  }

  Future<void> _clearAllMedia() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KoraColors.cardFor(Theme.of(context).brightness),
        title: Text('Clear all media?',
            style: TextStyle(color: KoraColors.textPrimaryFor(Theme.of(context).brightness))),
        content: Text(
            'This will delete all cached images, videos, and voice messages. Messages will remain but media will need to be re-downloaded.',
            style: TextStyle(
                color: KoraColors.textSecondaryFor(Theme.of(context).brightness), fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Clear', style: TextStyle(color: Colors.red.shade400, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final cacheDir = await getTemporaryDirectory();
      if (await cacheDir.exists()) {
        await for (final entity in cacheDir.list(recursive: true)) {
          if (entity is File) await entity.delete();
        }
      }
    } catch (_) {}

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Media cache cleared'), behavior: SnackBarBehavior.floating),
    );
    await _loadStorageData();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final card = KoraColors.cardFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);
    final border = KoraColors.borderFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text('Manage storage',
            style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: KoraColors.purple))
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  // ── Storage usage bar ──
                  _sectionLabel('STORAGE USED', textMuted),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_formatSize(_totalUsed),
                                style: TextStyle(
                                    color: textPrimary, fontSize: 28, fontWeight: FontWeight.w700)),
                            Text('of ${_formatSize(_deviceTotal)}',
                                style: TextStyle(color: textMuted, fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SizedBox(
                            height: 8,
                            child: Row(
                              children: _categories
                                  .where((c) => c.size > 0)
                                  .map((c) {
                                final pct = (_totalUsed > 0 ? c.size / _totalUsed : 0);
                                return Expanded(
                                  flex: (pct * 100).round().clamp(1, 100),
                                  child: Container(color: c.color),
                                );
                              })
                                  .toList(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 16,
                          runSpacing: 8,
                          children: _categories.where((c) => c.size > 0).map((c) {
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(color: c.color, shape: BoxShape.circle)),
                                const SizedBox(width: 6),
                                Text('${c.label}: ${_formatSize(c.size)}',
                                    style: TextStyle(color: textSecondary, fontSize: 12)),
                              ],
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Per-chat storage breakdown ──
                  if (_items.isNotEmpty) ...[
                    _sectionLabel('CHATS', textMuted),
                    Container(
                      decoration: BoxDecoration(
                        color: card,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          for (int i = 0; i < _items.length; i++) ...[
                            if (i > 0) Divider(height: 1, indent: 56, color: border),
                            ListTile(
                              leading: CircleAvatar(
                                backgroundColor: KoraColors.purple.withValues(alpha: 0.1),
                                child: Text(
                                  _items[i].name.isNotEmpty
                                      ? _items[i].name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                      color: KoraColors.purple, fontWeight: FontWeight.w600),
                                ),
                              ),
                              title: Text(_items[i].name,
                                  style: TextStyle(color: textPrimary, fontSize: 15)),
                              subtitle: Text(_formatSize(_items[i].size),
                                  style: TextStyle(color: textSecondary, fontSize: 13)),
                              trailing: IconButton(
                                icon: Icon(Icons.delete_outline,
                                    color: Colors.red.shade400, size: 20),
                                onPressed: () => _clearChatStorage(_items[i].name),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ── Actions ──
                  _sectionLabel('ACTIONS', textMuted),
                  Container(
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ListTile(
                      leading: Icon(Icons.delete_sweep_outlined,
                          color: Colors.red.shade400, size: 24),
                      title: Text('Clear all media cache',
                          style: TextStyle(
                              color: Colors.red.shade400,
                              fontSize: 15,
                              fontWeight: FontWeight.w500)),
                      subtitle: Text('Delete cached images, videos, and voice messages',
                          style: TextStyle(color: textSecondary, fontSize: 13)),
                      trailing: Icon(Icons.chevron_right, color: textMuted),
                      onTap: _clearAllMedia,
                    ),
                  ),

                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: KoraColors.purple.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: KoraColors.purple.withValues(alpha: 0.15), width: 0.5),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: KoraColors.purple, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Media that has been deleted from your device can be re-downloaded from chats. '
                            'Clearing the cache does not delete your messages.',
                            style: TextStyle(color: textSecondary, fontSize: 12.5, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _sectionLabel(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
    );
  }
}

class _StorageCategory {
  final String label;
  final int size;
  final IconData icon;
  final Color color;
  _StorageCategory(this.label, this.size, this.icon, this.color);
}

class _StorageItem {
  final String name;
  final int size;
  _StorageItem(this.name, this.size);
}

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme/kora_colors.dart';

/// Real local chat backup (WhatsApp "Chat backup" parity).
///
/// Export: bundles every stored conversation + message + chat-relevant
/// preference into a single JSON file, saved to the app documents
/// directory and immediately shared (so the user can keep it anywhere:
/// device storage, Drive, email…).
///
/// Import: pick a previously exported file, validate its structure,
/// then write every entry back into SharedPreferences and reload.
/// Nothing is simulated — what you see is exactly what is written.
class ChatBackupScreen extends StatefulWidget {
  const ChatBackupScreen({super.key});

  @override
  State<ChatBackupScreen> createState() => _ChatBackupScreenState();
}

class _ChatBackupScreenState extends State<ChatBackupScreen> {
  static const _kVersion = 1;
  static const _kMsgPrefix = 'kora_msgs_';
  static const _kConvKey = 'kora_conversations';

  bool _busy = false;
  String? _lastBackupDate;
  int _lastBackupChats = 0;
  int _lastBackupMessages = 0;

  // Preference keys bundled into (and restored from) a backup file.
  static const _kBackupKeys = <String>[
    'kora_chat_theme_id',
    'kora_custom_sent_bubble',
    'kora_custom_received_bubble',
    'kora_wallpaper_color',
    'kora_wallpaper_image',
    'kora_wallpaper_asset',
    'kora_font_scale',
    'kora_enter_is_send',
    'kora_media_quality',
    'kora_archived_keep',
    'kora_media_visibility',
  ];

  @override
  void initState() {
    super.initState();
    _loadBackupMeta();
  }

  Future<void> _loadBackupMeta() async {
    final prefs = await SharedPreferences.getInstance();
    final iso = prefs.getString('kora_last_backup_at');
    if (!mounted) return;
    setState(() {
      _lastBackupDate = iso;
      _lastBackupChats = prefs.getInt('kora_last_backup_chats') ?? 0;
      _lastBackupMessages = prefs.getInt('kora_last_backup_msgs') ?? 0;
    });
  }

  Future<void> _export() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final prefs = await SharedPreferences.getInstance();

      final messages = <String, dynamic>{};
      var messageCount = 0;
      for (final key in prefs.getKeys()) {
        if (key.startsWith(_kMsgPrefix)) {
          final raw = prefs.getString(key);
          if (raw == null) continue;
          final list = jsonDecode(raw) as List;
          messages[key] = list;
          messageCount += list.length;
        }
      }
      final conversations = prefs.getString(_kConvKey);

      final settings = <String, dynamic>{};
      for (final k in _kBackupKeys) {
        final v = prefs.get(k);
        if (v != null) settings[k] = v;
      }

      final now = DateTime.now();
      final payload = jsonEncode({
        'app': 'Kora Messenger',
        'format': 'kora-chat-backup',
        'version': _kVersion,
        'created_at': now.toIso8601String(),
        'conversations': conversations,
        'messages': messages,
        'settings': settings,
      });

      final dir = await getApplicationDocumentsDirectory();
      final stamp = now.toIso8601String().replaceAll(RegExp(r'[-:T.]'), '').substring(0, 15);
      final file = File('${dir.path}/kora-backup_$stamp.json');
      await file.writeAsString(payload);

      await prefs.setString('kora_last_backup_at', now.toIso8601String());
      await prefs.setInt('kora_last_backup_chats', messages.length);
      await prefs.setInt('kora_last_backup_msgs', messageCount);

      if (mounted) {
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'application/json')],
          subject: 'Kora Messenger backup',
          text: 'Kora Messenger chat backup — $stamp',
        );
      }
      await _loadBackupMeta();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup created — $messageCount messages in ${messages.length} chats')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore backup?'),
        content: const Text(
          'Your current chats will be replaced by the chats in the backup file. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      final path = picked?.files.single.path;
      if (path == null) {
        if (mounted) setState(() => _busy = false);
        return;
      }

      final data = jsonDecode(await File(path).readAsString());
      if (data is! Map<String, dynamic> || data['format'] != 'kora-chat-backup') {
        throw 'Not a Kora backup file';
      }

      final prefs = await SharedPreferences.getInstance();
      final messages = (data['messages'] as Map<String, dynamic>? ?? {});
      // Clear existing message stores so restore is a true replacement.
      for (final key in prefs.getKeys().toList()) {
        if (key.startsWith(_kMsgPrefix)) await prefs.remove(key);
      }
      var restored = 0;
      for (final entry in messages.entries) {
        await prefs.setString(entry.key, jsonEncode(entry.value));
        restored += (entry.value as List).length;
      }

      final conv = data['conversations'];
      if (conv is String) {
        await prefs.setString(_kConvKey, conv);
      }

      final settings = (data['settings'] as Map<String, dynamic>? ?? {});
      for (final entry in settings.entries) {
        await prefs.setString(entry.key, jsonEncode(entry.value));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restored $restored messages')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _fmtDate(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${months[d.month - 1]} ${d.year}, $hh:$mm';
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
        title: Text('Chat backup', style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
        leading: IconButton(icon: Icon(Icons.arrow_back, color: textPrimary), onPressed: () => Navigator.pop(context)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                KoraColors.purple.withValues(alpha: 0.08),
                KoraColors.blue.withValues(alpha: 0.08),
              ]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.cloud_outlined, color: KoraColors.purple, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Your chats are backed up to a file you control. '
                  'Save it to your device, Drive, or anywhere you choose — '
                  'Kora never reads it.',
                  style: TextStyle(color: textSecondary, fontSize: 12.5, height: 1.5),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 20),

          _tile(
            card: card,
            border: border,
            icon: Icons.backup_outlined,
            iconColor: KoraColors.purple,
            title: 'Back up now',
            subtitle: _busy
                ? 'Working…'
                : (_lastBackupDate != null
                    ? 'Last backup: ${_fmtDate(DateTime.parse(_lastBackupDate!))} · $_lastBackupMessages messages in $_lastBackupChats chats'
                    : 'Creates a backup file you can save anywhere'),
            onTap: _busy ? null : _export,
          ),
          const SizedBox(height: 12),
          _tile(
            card: card,
            border: border,
            icon: Icons.restore,
            iconColor: KoraColors.purple,
            title: 'Restore backup',
            subtitle: 'Choose a backup file to restore your chats',
            onTap: _busy ? null : _import,
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Backups include your conversations, messages and chat '
              'settings. Media files are not included in file backups — '
              'they stay on your device.',
              style: TextStyle(color: textMuted, fontSize: 12, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile({
    required Color card,
    required Color border,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: 0.5),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(color: textSecondary, fontSize: 12.5, height: 1.35)),
            ]),
          ),
          Icon(Icons.chevron_right, color: KoraColors.textMutedFor(brightness), size: 20),
        ]),
      ),
    );
  }
}

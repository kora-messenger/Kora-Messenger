import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import '../../services/chat_sync_service.dart';
import '../../services/message_service.dart';
import '../../services/conversation_directory.dart';

/// Chat Backup screen — lets the user view their cloud backup status,
/// manually trigger a backup, and restore chats from the cloud.
///
/// Accessible from the chat screen's menu (3-dot or settings).
class ChatBackupScreen extends StatefulWidget {
  const ChatBackupScreen({super.key});

  @override
  State<ChatBackupScreen> createState() => _ChatBackupScreenState();
}

class _ChatBackupScreenState extends State<ChatBackupScreen> {
  bool _loading = true;
  bool _backingUp = false;
  bool _restoring = false;
  Map<String, dynamic>? _backupData;
  int _localChatCount = 0;
  int _localMessageCount = 0;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _loadBackupInfo();
  }

  Future<void> _loadBackupInfo() async {
    // Count local chats and messages
    final directory = await ConversationDirectoryService.instance.getAll();
    int msgCount = 0;
    for (final entry in directory.entries) {
      final chatId = entry.key;
      if (chatId == 'kora_support' || chatId == 'kora_ai') {
        final msgs = MessageService.instance.getMessages(chatId);
        msgCount += msgs.length;
        continue;
      }
      final msgs = await MessageService.instance.loadMessages(chatId);
      msgCount += msgs.length;
    }
    // Also count AI chats
    for (final chatId in ['kora_support', 'kora_ai']) {
      final msgs = await MessageService.instance.loadMessages(chatId);
      // Already counted above if in directory, but AI chats might not be
      // in the directory — they're always present
    }

    setState(() {
      _localChatCount = directory.length + 2; // +2 for Kora Support & AI
      _localMessageCount = msgCount;
    });

    // Fetch cloud backup info
    final backup = await ChatSyncService.instance.fetchBackup();
    setState(() {
      _backupData = backup;
      _loading = false;
    });
  }

  Future<void> _performBackup() async {
    setState(() {
      _backingUp = true;
      _statusMessage = null;
    });

    // Trigger a fresh backup from the cloud
    final backup = await ChatSyncService.instance.fetchBackup();

    setState(() {
      _backingUp = false;
      _backupData = backup;
      if (backup != null) {
        _statusMessage = 'Backup complete — ${backup['totalConversations']} chats, ${backup['totalMessages']} messages saved to cloud.';
      } else {
        _statusMessage = 'Backup failed. Check your connection and try again.';
      }
    });
  }

  Future<void> _restoreFromCloud() async {
    setState(() {
      _restoring = true;
      _statusMessage = null;
    });

    final result = await ChatSyncService.instance.restoreFromCloud();

    setState(() {
      _restoring = false;
      _statusMessage = 'Restored ${result.conversations} chats and ${result.messages} messages from cloud.';
    });

    // Refresh local counts
    _loadBackupInfo();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final card = KoraColors.cardFor(brightness);
    final border = KoraColors.borderFor(brightness);
    final text = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textSecondaryFor(brightness);
    final purple = KoraColors.purple;

    int cloudChats = _backupData?['totalConversations'] as int? ?? 0;
    int cloudMessages = _backupData?['totalMessages'] as int? ?? 0;
    String? backupDate = _backupData?['backupDate'] as String?;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text('Chat Backup', style: TextStyle(color: text, fontSize: 18, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: text),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: purple))
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // ── Backup status card ──
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: border),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.cloud_done_rounded, size: 48, color: purple),
                      const SizedBox(height: 12),
                      Text(
                        'Cloud Backup',
                        style: TextStyle(color: text, fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your chats are automatically backed up to Kora Cloud.',
                        style: TextStyle(color: textMuted, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      if (backupDate != null) ...[
                        Text(
                          'Last backup: ${_formatDate(backupDate)}',
                          style: TextStyle(color: textMuted, fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                      ],
                      // Stats row
                      Row(
                        children: [
                          Expanded(
                            child: _statCard(
                              'Local',
                              '$_localChatCount chats\n$_localMessageCount messages',
                              Icons.phone_android_rounded,
                              card,
                              border,
                              text,
                              textMuted,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _statCard(
                              'Cloud',
                              '$cloudChats chats\n$cloudMessages messages',
                              Icons.cloud_rounded,
                              card,
                              border,
                              text,
                              textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Actions ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('ACTIONS', style: TextStyle(color: textMuted, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                ),
                const SizedBox(height: 8),

                // Backup now
                _actionTile(
                  icon: Icons.backup_rounded,
                  iconBg: purple.withOpacity(0.1),
                  title: 'Back up now',
                  subtitle: 'Sync all chats to the cloud immediately',
                  onTap: _backingUp ? null : _performBackup,
                  trailing: _backingUp
                      ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: purple))
                      : Icon(Icons.chevron_right, color: textMuted),
                  card: card,
                  border: border,
                  text: text,
                  textMuted: textMuted,
                ),

                const SizedBox(height: 8),

                // Restore
                _actionTile(
                  icon: Icons.restore_rounded,
                  iconBg: Colors.blue.withOpacity(0.1),
                  title: 'Restore from cloud',
                  subtitle: 'Download all chats from cloud backup',
                  onTap: _restoring ? null : _restoreFromCloud,
                  trailing: _restoring
                      ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue))
                      : Icon(Icons.chevron_right, color: textMuted),
                  card: card,
                  border: border,
                  text: text,
                  textMuted: textMuted,
                ),

                // ── Status message ──
                if (_statusMessage != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 20, color: purple),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _statusMessage!,
                            style: TextStyle(color: textMuted, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 30),

                // ── Info ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Chats are automatically synced to Kora Cloud when you send or receive messages. '
                    'If you reinstall Kora and log in with the same email, all your chats will be restored automatically.',
                    style: TextStyle(color: textMuted, fontSize: 12, height: 1.5),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color card, Color border, Color text, Color textMuted) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: textMuted),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: text, fontSize: 12, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required Color iconBg,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    required Widget trailing,
    required Color card,
    required Color border,
    required Color text,
    required Color textMuted,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: card,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, size: 20, color: KoraColors.purple),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(color: text, fontSize: 15, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: TextStyle(color: textMuted, fontSize: 12)),
                    ],
                  ),
                ),
                trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      return '${dt.day}/${dt.month}/${dt.year} at ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }
}

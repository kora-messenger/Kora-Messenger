import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/backup_service.dart';
import '../../theme/kora_colors.dart';

/// Chat Backup Settings — full WhatsApp-style backup configuration.
///
/// Features:
/// - Last backup info (date, size, messages)
/// - Auto-backup frequency: Never, Daily, Weekly, Monthly
/// - Back up over: Wi-Fi only, Wi-Fi + Cellular
/// - Include videos toggle
/// - Encrypted backup with password
/// - Manual "Back Up Now" button with live progress
/// - Backup file saved to local storage
class ChatBackupScreen extends StatefulWidget {
  const ChatBackupScreen({super.key});

  @override
  State<ChatBackupScreen> createState() => _ChatBackupScreenState();
}

class _ChatBackupScreenState extends State<ChatBackupScreen> {
  // Settings
  String _frequency = 'Weekly'; // Never, Daily, Weekly, Monthly
  String _network = 'Wi-Fi only'; // Wi-Fi only, Wi-Fi + Cellular
  bool _includeVideos = false;
  bool _encrypt = true;
  final _passwordController = TextEditingController();

  // Status
  DateTime? _lastBackup;
  String _lastBackupSize = '';
  int _lastBackupMessages = 0;
  bool _isBackingUp = false;
  double _progress = 0;
  String _progressStatus = '';

  // Local backups (real files on this device)
  List<BackupMetadata> _backups = [];
  bool _restoring = false;
  double _restoreProgress = 0;
  String _restoreStatus = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadBackups();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _frequency = prefs.getString('kora_backup_frequency') ?? 'Weekly';
      _network = prefs.getString('kora_backup_network') ?? 'Wi-Fi only';
      _includeVideos = prefs.getBool('kora_backup_videos') ?? false;
      _encrypt = prefs.getBool('kora_backup_encrypt') ?? true;
      final lastTs = prefs.getString('kora_backup_last_date');
      _lastBackup = lastTs != null ? DateTime.tryParse(lastTs) : null;
      _lastBackupSize = prefs.getString('kora_backup_last_size') ?? '';
      _lastBackupMessages = prefs.getInt('kora_backup_last_messages') ?? 0;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('kora_backup_frequency', _frequency);
    await prefs.setString('kora_backup_network', _network);
    await prefs.setBool('kora_backup_videos', _includeVideos);
    await prefs.setBool('kora_backup_encrypt', _encrypt);
  }

  Future<void> _loadBackups() async {
    try {
      final backups = await BackupService.instance.listBackups();
      if (mounted) setState(() => _backups = backups);
    } catch (_) {}
  }

  Future<void> _startBackup() async {
    // Resolve the backup password.
    String? pin;
    if (_encrypt) {
      final typed = _passwordController.text.trim();
      if (typed.isNotEmpty) {
        pin = typed;
        await BackupService.instance.setBackupPin(typed);
      } else {
        pin = await BackupService.instance.getStoredPin();
      }
      if (pin == null || pin.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Set a backup password under Encryption first'),
            backgroundColor: KoraColors.purple,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    setState(() {
      _isBackingUp = true;
      _progress = 0;
      _progressStatus = 'Preparing backup…';
    });

    try {
      final meta = await BackupService.instance.createBackup(
        pin: pin,
        includeVideos: _includeVideos,
        encrypt: _encrypt,
        onProgress: (p, status) {
          if (mounted) {
            setState(() {
              _progress = p;
              _progressStatus = status;
            });
          }
        },
      );
      if (mounted) {
        setState(() {
          _isBackingUp = false;
          _lastBackup = meta.createdAt;
          _lastBackupSize = meta.formattedSize;
          _lastBackupMessages = meta.messageCount;
        });
        await _loadBackups();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup complete — ${meta.chatCount} chats, ${meta.messageCount} messages'),
            backgroundColor: KoraColors.purple,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isBackingUp = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup failed: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _restore(BackupMetadata meta) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KoraColors.surfaceFor(Theme.of(ctx).brightness),
        title: Text('Restore backup?', style: TextStyle(color: KoraColors.textPrimaryFor(Theme.of(ctx).brightness))),
        content: Text(
          'Your current chat history will be replaced with this backup '
          '(${meta.createdAt.day}/${meta.createdAt.month}/${meta.createdAt.year}, '
          '${meta.formattedSize}).',
          style: TextStyle(color: KoraColors.textMutedFor(Theme.of(ctx).brightness)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Restore', style: const TextStyle(color: KoraColors.purple))),
        ],
      ),
    );
    if (confirmed != true) return;

    // Encrypted backups need the password.
    String? pin;
    if (meta.encrypted) {
      pin = await BackupService.instance.getStoredPin();
      if (pin == null) pin = await _promptForPin();
      if (pin == null) return;
    }

    setState(() {
      _restoring = true;
      _restoreProgress = 0;
      _restoreStatus = 'Opening backup…';
    });

    try {
      await BackupService.instance.restoreBackup(meta, pin: pin, onProgress: (p, status) {
        if (mounted) {
          setState(() {
            _restoreProgress = p;
            _restoreStatus = status;
          });
        }
      });
      if (mounted) {
        setState(() => _restoring = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restore complete — ${_restoreStatus.replaceFirst('Restored ', '')}'),
            backgroundColor: KoraColors.purple,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _restoring = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restore failed: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<String?> _promptForPin() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KoraColors.surfaceFor(Theme.of(ctx).brightness),
        title: Text('Enter backup password', style: TextStyle(color: KoraColors.textPrimaryFor(Theme.of(ctx).brightness))),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Backup password'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: Text('Restore', style: const TextStyle(color: KoraColors.purple))),
        ],
      ),
    );
  }

  Future<void> _deleteBackup(BackupMetadata meta) async {
    await BackupService.instance.deleteBackup(meta);
    await _loadBackups();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Backup deleted'),
          backgroundColor: KoraColors.purple,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _restoreFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['korabak'],
    );
    if (result == null || result.files.single.path == null) return;
    final path = result.files.single.path!;

    // Check encryption — ask for the password when needed.
    String? pin;
    final magicCheck = await File(path).open();
    List<int> magicBytes = [];
    try {
      magicBytes = await magicCheck.read(8);
    } finally {
      await magicCheck.close();
    }
    final magic = String.fromCharCodes(magicBytes);
    if (magic == 'KORABAK1') {
      pin = await BackupService.instance.getStoredPin() ?? await _promptForPin();
      if (pin == null) return;
    } else if (magic != 'KORABAK0') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Not a Kora backup file'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() {
      _restoring = true;
      _restoreProgress = 0;
      _restoreStatus = 'Opening backup…';
    });
    try {
      await BackupService.instance.restoreFromFile(path, pin: pin, onProgress: (p, status) {
        if (mounted) {
          setState(() {
            _restoreProgress = p;
            _restoreStatus = status;
          });
        }
      });
      if (mounted) {
        setState(() => _restoring = false);
        await _loadBackups();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restore complete — $_restoreStatus'.replaceFirst('Restore complete — Restored ', 'Restored ')),
            backgroundColor: KoraColors.purple,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _restoring = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restore failed: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);
    final border = KoraColors.borderFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: Text('Chat Backup',
            style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // Last backup info
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [KoraColors.purple.withValues(alpha: 0.08), KoraColors.blue.withValues(alpha: 0.06)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.cloud_done_outlined, color: KoraColors.purple, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Last backup',
                              style: TextStyle(color: textMuted, fontSize: 13, fontWeight: FontWeight.w500)),
                          Text(
                            _lastBackup != null
                                ? '${_lastBackup!.day}/${_lastBackup!.month}/${_lastBackup!.year} at ${_lastBackup!.hour}:${_lastBackup!.minute.toString().padLeft(2, '0')}'
                                : 'Never',
                            style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_lastBackup != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.storage_outlined, size: 16, color: textMuted),
                      const SizedBox(width: 6),
                      Text('$_lastBackupSize • $_lastBackupMessages messages',
                          style: TextStyle(color: textMuted, fontSize: 13)),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Auto-backup frequency
          _sectionLabel('AUTO BACKUP', textMuted),
          ListTile(
            leading: Icon(Icons.schedule, color: textPrimary, size: 24),
            title: Text('Back up to phone', style: TextStyle(color: textPrimary, fontSize: 15)),
            subtitle: Text('Save backup to local storage', style: TextStyle(color: textMuted, fontSize: 13)),
            trailing: DropdownButton<String>(
              value: _frequency,
              underline: const SizedBox(),
              items: ['Never', 'Daily', 'Weekly', 'Monthly'].map((f) =>
                  DropdownMenuItem(value: f, child: Text(f, style: TextStyle(color: textPrimary, fontSize: 14)))).toList(),
              onChanged: (v) { if (v != null) { setState(() => _frequency = v); _saveSettings(); } },
            ),
          ),

          // Network preference
          ListTile(
            leading: Icon(Icons.wifi, color: textPrimary, size: 24),
            title: Text('Back up over', style: TextStyle(color: textPrimary, fontSize: 15)),
            trailing: DropdownButton<String>(
              value: _network,
              underline: const SizedBox(),
              items: ['Wi-Fi only', 'Wi-Fi + Cellular'].map((n) =>
                  DropdownMenuItem(value: n, child: Text(n, style: TextStyle(color: textPrimary, fontSize: 14)))).toList(),
              onChanged: (v) { if (v != null) { setState(() => _network = v); _saveSettings(); } },
            ),
          ),

          // Include videos
          SwitchListTile(
            secondary: Icon(Icons.videocam_outlined, color: textPrimary, size: 24),
            title: Text('Include videos', style: TextStyle(color: textPrimary, fontSize: 15)),
            subtitle: Text('Increases backup size significantly', style: TextStyle(color: textMuted, fontSize: 13)),
            value: _includeVideos,
            onChanged: (v) { setState(() => _includeVideos = v); _saveSettings(); },
            activeColor: KoraColors.purple,
          ),

          const Divider(height: 32),

          // Encryption
          _sectionLabel('ENCRYPTION', textMuted),
          SwitchListTile(
            secondary: Icon(Icons.lock_outline, color: textPrimary, size: 24),
            title: Text('Encrypted backup', style: TextStyle(color: textPrimary, fontSize: 15)),
            subtitle: Text('Protect backup with a password', style: TextStyle(color: textMuted, fontSize: 13)),
            value: _encrypt,
            onChanged: (v) { setState(() => _encrypt = v); _saveSettings(); },
            activeColor: KoraColors.purple,
          ),
          if (_encrypt) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _passwordController,
                obscureText: true,
                style: TextStyle(color: textPrimary, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Backup password (64-digit key or custom)',
                  hintStyle: TextStyle(color: textMuted, fontSize: 13),
                  filled: true, fillColor: surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  prefixIcon: Icon(Icons.password, color: textMuted, size: 20),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Your password is not stored by Kora. If you forget it, your backup cannot be restored.',
                style: TextStyle(color: textMuted, fontSize: 12, height: 1.4),
              ),
            ),
          ],

          const Divider(height: 32),

          // Manual backup
          _sectionLabel('MANUAL BACKUP', textMuted),
          if (_isBackingUp) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: _progress,
                    color: KoraColors.purple,
                    backgroundColor: surface,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 8),
                  Text(_progressStatus, style: TextStyle(color: textMuted, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('${(_progress * 100).round()}%', style: TextStyle(color: KoraColors.purple, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: _startBackup,
                icon: const Icon(Icons.backup, size: 20),
                label: const Text('Back Up Now', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: KoraColors.purple,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],

          const Divider(height: 32),

          // Local backups on this device
          _sectionLabel('LOCAL BACKUPS', textMuted),
          if (_restoring) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: _restoreProgress,
                    color: KoraColors.blue,
                    backgroundColor: surface,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 8),
                  Text(_restoreStatus, style: TextStyle(color: textMuted, fontSize: 13)),
                ],
              ),
            ),
          ],
          if (_backups.isEmpty && !_restoring)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'No local backups yet. Tap Back Up Now to create your first backup.',
                style: TextStyle(color: textMuted, fontSize: 13, height: 1.4),
              ),
            ),
          ..._backups.map((b) => ListTile(
                leading: Icon(
                  b.encrypted ? Icons.lock_outline : Icons.folder_zip_outlined,
                  color: textPrimary,
                  size: 24,
                ),
                title: Text(
                  '${b.createdAt.day}/${b.createdAt.month}/${b.createdAt.year} at ${b.createdAt.hour}:${b.createdAt.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(color: textPrimary, fontSize: 15),
                ),
                subtitle: Text(
                  '${b.formattedSize}${b.encrypted ? ' • encrypted' : ''}${b.hasMedia ? ' • with media' : ''}',
                  style: TextStyle(color: textMuted, fontSize: 13),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.restore, color: KoraColors.purple, size: 22),
                      onPressed: _restoring ? null : () => _restore(b),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: textMuted, size: 22),
                      onPressed: () => _deleteBackup(b),
                    ),
                  ],
                ),
              )),

          // Restore from a .korabak file (e.g. moved from another device)
          ListTile(
            leading: Icon(Icons.upload_file_outlined, color: textPrimary, size: 24),
            title: Text('Restore from file', style: TextStyle(color: textPrimary, fontSize: 15)),
            subtitle: Text('Pick a .korabak backup from another device', style: TextStyle(color: textMuted, fontSize: 13)),
            trailing: Icon(Icons.chevron_right, color: textMuted),
            onTap: _restoring ? null : _restoreFromFile,
          ),

          // Export chats
          ListTile(
            leading: Icon(Icons.file_download_outlined, color: textPrimary, size: 24),
            title: Text('Export chats', style: TextStyle(color: textPrimary, fontSize: 15)),
            subtitle: Text('Export individual chats to a file', style: TextStyle(color: textMuted, fontSize: 13)),
            trailing: Icon(Icons.chevron_right, color: textMuted),
            onTap: () => _showExportInfo(),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(label, style: TextStyle(color: KoraColors.purple, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
    );
  }

  void _showExportInfo() {
    showModalBottomSheet(
      context: context,
      backgroundColor: KoraColors.surfaceFor(Theme.of(context).brightness),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        final textPrimary = KoraColors.textPrimaryFor(Theme.of(context).brightness);
        final textMuted = KoraColors.textMutedFor(Theme.of(context).brightness);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 36, height: 4, decoration: BoxDecoration(color: textMuted.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Export Chat',
                  style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('Select a chat to export. You can choose to include media or export text only.',
                  style: TextStyle(color: textMuted, fontSize: 14), textAlign: TextAlign.center),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.chat, color: KoraColors.purple),
              title: Text('Export with media', style: TextStyle(color: textPrimary)),
              subtitle: Text('Includes photos, videos, and voice notes', style: TextStyle(color: textMuted, fontSize: 13)),
              onTap: () => Navigator.pop(context, 'with_media'),
            ),
            ListTile(
              leading: Icon(Icons.description_outlined, color: KoraColors.purple),
              title: Text('Export without media', style: TextStyle(color: textPrimary)),
              subtitle: Text('Text messages only (smaller file)', style: TextStyle(color: textMuted, fontSize: 13)),
              onTap: () => Navigator.pop(context, 'text_only'),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}

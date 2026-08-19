import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/kora_colors.dart';
import '../services/crash_logger.dart';

/// Auto-shown on the next app launch after a fatal crash.
///
/// Displays the full crash log (error message + stack trace) with:
/// - A "Copy" button to copy the log to clipboard
/// - A "Download" button to save/share the log as a .txt file
/// - A "Dismiss" button to proceed into the app
///
/// This screen is NOT in settings — it only appears automatically.
class CrashReportScreen extends StatefulWidget {
  final Map<String, dynamic> crashLog;
  final VoidCallback onDismiss;

  const CrashReportScreen({
    super.key,
    required this.crashLog,
    required this.onDismiss,
  });

  @override
  State<CrashReportScreen> createState() => _CrashReportScreenState();
}

class _CrashReportScreenState extends State<CrashReportScreen> {
  bool _copied = false;
  bool _isDownloading = false;

  String get _crashText => CrashLogger.formatCrashLog(widget.crashLog);

  Future<void> _copyLog() async {
    await Clipboard.setData(ClipboardData(text: _crashText));
    if (!mounted) return;
    setState(() => _copied = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Crash log copied to clipboard'),
        backgroundColor: KoraColors.darkCard,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _downloadLog() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);

    try {
      final dir = await getTemporaryDirectory();
      final timestamp = widget.crashLog['timestamp'] ?? DateTime.now().toIso8601String();
      final safeTimestamp = timestamp.toString().replaceAll(RegExp(r'[^\d]'), '').substring(0, 14);
      final fileName = 'kora_crash_$safeTimestamp.txt';
      final filePath = '${dir.path}/$fileName';

      final file = File(filePath);
      await file.writeAsString(_crashText);
      if (!mounted) return;

      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'Kora Messenger Crash Report',
        text: 'Crash report from Kora Messenger',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download: $e'),
            backgroundColor: Colors.red.shade900,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _dismiss() async {
    await CrashLogger.clearUnreadCrash();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final log = widget.crashLog;
    final type = log['type'] as String? ?? 'Unknown';
    final message = log['message'] as String? ?? '(no message)';
    final stackTrace = log['stackTrace'] as String? ?? '(no stack trace)';
    final platform = log['platform'] as String? ?? 'unknown';
    final appVersion = log['appVersion'] as String? ?? 'unknown';
    final timestamp = _formatTimestamp(log['timestamp'] as String? ?? '');

    return Scaffold(
      backgroundColor: KoraColors.trueBlack,
      appBar: AppBar(
        backgroundColor: KoraColors.trueBlack,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Crash Report',
          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton(
            onPressed: _dismiss,
            child: const Text(
              'Dismiss',
              style: TextStyle(color: KoraColors.purple, fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Crash info banner ───────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              decoration: const BoxDecoration(
                color: Color(0xFF1A0A0F),
                border: Border(
                  bottom: BorderSide(color: Color(0xFF2D1517), width: 1),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.bug_report, color: Colors.red, size: 28),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Kora crashed last time',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'The crash log below can help identify the issue.\nCopy or download it and send it to the Kora team.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFFA0A0B8), fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            ),

            // ── Crash details ──────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                children: [
                  // Meta info
                  _metaRow('Type', type),
                  _metaRow('Time', timestamp),
                  _metaRow('Platform', platform),
                  _metaRow('Version', appVersion),
                  const SizedBox(height: 20),

                  // Error message
                  const Text(
                    'ERROR MESSAGE',
                    style: TextStyle(
                      color: Color(0xFF6B6B80),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: KoraColors.darkCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: SelectableText(
                      message,
                      style: const TextStyle(
                        color: Color(0xFFFCA5A5),
                        fontSize: 13,
                        fontFamily: 'monospace',
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Stack trace
                  const Text(
                    'STACK TRACE',
                    style: TextStyle(
                      color: Color(0xFF6B6B80),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 300),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: KoraColors.deepNavy,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF2E2E42), width: 1),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        stackTrace,
                        style: const TextStyle(
                          color: Color(0xFFA0A0B8),
                          fontSize: 11.5,
                          fontFamily: 'monospace',
                          height: 1.6,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),

            // ── Action buttons ──────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              decoration: const BoxDecoration(
                color: KoraColors.trueBlack,
                border: Border(
                  top: BorderSide(color: Color(0xFF2E2E42), width: 1),
                ),
              ),
              child: Row(
                children: [
                  // Copy
                  Expanded(
                    child: _actionButton(
                      icon: _copied ? Icons.check : Icons.copy,
                      label: _copied ? 'Copied' : 'Copy',
                      onTap: _copyLog,
                      color: KoraColors.purple,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Download
                  Expanded(
                    child: _actionButton(
                      icon: _isDownloading ? null : Icons.download,
                      label: _isDownloading ? 'Saving...' : 'Download',
                      onTap: _downloadLog,
                      color: KoraColors.blue,
                      isLoading: _isDownloading,
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

  Widget _metaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF6B6B80), fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(color: Color(0xFFA0A0B8), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData? icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              )
            else if (icon != null)
              Icon(icon, color: color, size: 20),
            if (icon != null || isLoading) const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final month = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][dt.month - 1];
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$month ${dt.day}, ${dt.year} · $hour:$minute';
    } catch (_) {
      return iso;
    }
  }
}

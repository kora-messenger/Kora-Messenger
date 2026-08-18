import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import '../../services/crash_logger.dart';

/// Shows all recorded crash logs with full stack traces.
/// Accessible from the Profile tab → "Crash Logs".
class CrashLogsScreen extends StatefulWidget {
  const CrashLogsScreen({super.key});

  @override
  State<CrashLogsScreen> createState() => _CrashLogsScreenState();
}

class _CrashLogsScreenState extends State<CrashLogsScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final logs = await CrashLogger.getAll();
    if (mounted) {
      setState(() {
        _logs = logs;
        _loading = false;
      });
    }
  }

  Future<void> _clearLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: KoraColors.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Clear crash logs?',
          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'This will permanently delete all stored crash logs.',
          style: TextStyle(color: Color(0xFFA0A0B8), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFFA0A0B8))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear', style: TextStyle(color: KoraColors.purple, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await CrashLogger.clearAll();
      _loadLogs();
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final card = KoraColors.cardFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Crash Logs',
          style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_logs.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_outline, color: textMuted),
              onPressed: _clearLogs,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: KoraColors.purple))
          : _logs.isEmpty
              ? _emptyState(textMuted)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: _logs.length,
                  itemBuilder: (context, index) => _crashCard(
                    _logs[index],
                    card,
                    textPrimary,
                    textSecondary,
                    textMuted,
                  ),
                ),
    );
  }

  Widget _emptyState(Color muted) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 56, color: muted.withValues(alpha: 0.4)),
          const SizedBox(height: 14),
          Text(
            'No crashes recorded',
            style: TextStyle(color: muted, fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'The app is running smoothly.',
            style: TextStyle(color: muted.withValues(alpha: 0.6), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _crashCard(
    Map<String, dynamic> log,
    Color card,
    Color textPrimary,
    Color textSecondary,
    Color textMuted,
  ) {
    final timestamp = _formatTimestamp(log['timestamp'] as String? ?? '');
    final type = log['type'] as String? ?? 'Unknown';
    final message = log['message'] as String? ?? '(no message)';
    final stackTrace = log['stackTrace'] as String? ?? '(no stack trace)';
    final platform = log['platform'] as String? ?? 'unknown';
    final appVersion = log['appVersion'] as String? ?? 'unknown';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ExpansionTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _typeColor(type).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                type,
                style: TextStyle(
                  color: _typeColor(type),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message.split('\n').first,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: textPrimary, fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '$timestamp  ·  v$appVersion  ·  $platform',
            style: TextStyle(color: textMuted, fontSize: 11),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Message',
                  style: TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(color: textSecondary, fontSize: 12.5, height: 1.4),
                ),
                const SizedBox(height: 12),
                Text(
                  'Stack Trace',
                  style: TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: KoraColors.deepNavy.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    stackTrace,
                    style: TextStyle(
                      color: textSecondary.withValues(alpha: 0.8),
                      fontSize: 11,
                      fontFamily: 'monospace',
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _typeColor(String type) {
    if (type.startsWith('FlutterError')) return Colors.orange;
    if (type.startsWith('IsolateError')) return Colors.red;
    if (type.startsWith('Zone')) return Colors.amber;
    return KoraColors.purple;
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

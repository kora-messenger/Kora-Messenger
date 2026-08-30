import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/kora_colors.dart';

/// Network Usage screen — mirrors WhatsApp's Settings > Storage and data > Network usage.
///
/// Shows data sent/received broken down by type:
/// - Messages sent/received
/// - Media sent/received (images, videos, audio, documents)
/// - Total bytes sent/received
/// - Call data usage
/// - Reset statistics
class NetworkUsageScreen extends StatefulWidget {
  const NetworkUsageScreen({super.key});

  @override
  State<NetworkUsageScreen> createState() => _NetworkUsageScreenState();
}

class _NetworkUsageScreenState extends State<NetworkUsageScreen> {
  bool _loading = true;

  // Usage counters
  int _msgSent = 0;
  int _msgReceived = 0;
  int _bytesSent = 0;
  int _bytesReceived = 0;
  int _mediaSent = 0;
  int _mediaReceived = 0;
  int _callsData = 0;
  int _statusData = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _msgSent = prefs.getInt('net_msg_sent') ?? 0;
        _msgReceived = prefs.getInt('net_msg_received') ?? 0;
        _bytesSent = prefs.getInt('net_bytes_sent') ?? 0;
        _bytesReceived = prefs.getInt('net_bytes_received') ?? 0;
        _mediaSent = prefs.getInt('net_media_sent') ?? 0;
        _mediaReceived = prefs.getInt('net_media_received') ?? 0;
        _callsData = prefs.getInt('net_calls_data') ?? 0;
        _statusData = prefs.getInt('net_status_data') ?? 0;
        _loading = false;
      });
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Future<void> _resetStats() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KoraColors.cardFor(Theme.of(context).brightness),
        title: Text('Reset network usage?',
            style: TextStyle(color: KoraColors.textPrimaryFor(Theme.of(context).brightness))),
        content: Text('This will reset all network usage statistics to zero.',
            style: TextStyle(
                color: KoraColors.textSecondaryFor(Theme.of(context).brightness), fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Reset', style: TextStyle(color: Colors.red.shade400, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('net_msg_sent');
    await prefs.remove('net_msg_received');
    await prefs.remove('net_bytes_sent');
    await prefs.remove('net_bytes_received');
    await prefs.remove('net_media_sent');
    await prefs.remove('net_media_received');
    await prefs.remove('net_calls_data');
    await prefs.remove('net_status_data');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Network usage reset'), behavior: SnackBarBehavior.floating),
    );
    await _loadStats();
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
        title: Text('Network usage',
            style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: textPrimary, size: 22),
            onPressed: _resetStats,
            tooltip: 'Reset statistics',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: KoraColors.purple))
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  // ── Total summary ──
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [KoraColors.purple, const Color(0xFF4A90D9)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        Text('Total network usage',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14)),
                        const SizedBox(height: 8),
                        Text(_formatBytes(_bytesSent + _bytesReceived),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _summaryItem('Sent', _formatBytes(_bytesSent), Icons.arrow_upward),
                            Container(width: 1, height: 36, color: Colors.white.withValues(alpha: 0.3)),
                            _summaryItem('Received', _formatBytes(_bytesReceived), Icons.arrow_downward),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Breakdown ──
                  _sectionLabel('BREAKDOWN', textMuted),
                  Container(
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        _breakdownRow(
                          card, textPrimary, textSecondary, textMuted, border,
                          Icons.chat_bubble_outline, 'Messages sent', '$_msgSent', KoraColors.purple,
                        ),
                        _breakdownRow(
                          card, textPrimary, textSecondary, textMuted, border,
                          Icons.download_outlined, 'Messages received', '$_msgReceived', KoraColors.purple,
                        ),
                        _breakdownRow(
                          card, textPrimary, textSecondary, textMuted, border,
                          Icons.image_outlined, 'Media sent', _formatBytes(_mediaSent), const Color(0xFF4A90D9),
                        ),
                        _breakdownRow(
                          card, textPrimary, textSecondary, textMuted, border,
                          Icons.download_for_offline_outlined, 'Media received', _formatBytes(_mediaReceived), const Color(0xFF4A90D9),
                        ),
                        _breakdownRow(
                          card, textPrimary, textSecondary, textMuted, border,
                          Icons.phone_outlined, 'Call data', _formatBytes(_callsData), Colors.orange,
                        ),
                        _breakdownRow(
                          card, textPrimary, textSecondary, textMuted, border,
                          Icons.circle_outlined, 'Status data', _formatBytes(_statusData), Colors.teal,
                          isLast: true,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Message statistics ──
                  _sectionLabel('MESSAGE STATISTICS', textMuted),
                  Container(
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        _statRow(card, textPrimary, textSecondary, textMuted, border,
                            'Total messages sent', _msgSent.toString()),
                        _statRow(card, textPrimary, textSecondary, textMuted, border,
                            'Total messages received', _msgReceived.toString(),
                            isLast: true),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Reset button ──
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: _resetStats,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red.shade400,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: Colors.red.withValues(alpha: 0.3), width: 0.5),
                        ),
                      ),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Reset statistics',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _summaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.8), size: 18),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
      ],
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

  Widget _breakdownRow(
    Color card, Color textPrimary, Color textSecondary, Color textMuted, Color border,
    IconData icon, String label, String value, Color iconColor,
    {bool isLast = false}
  ) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: iconColor, size: 22),
          title: Text(label, style: TextStyle(color: textPrimary, fontSize: 15)),
          trailing: Text(value,
              style: TextStyle(color: textSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
        ),
        if (!isLast) Divider(height: 1, indent: 56, color: border),
      ],
    );
  }

  Widget _statRow(
    Color card, Color textPrimary, Color textSecondary, Color textMuted, Color border,
    String label, String value,
    {bool isLast = false}
  ) {
    return Column(
      children: [
        ListTile(
          title: Text(label, style: TextStyle(color: textPrimary, fontSize: 15)),
          trailing: Text(value,
              style: TextStyle(color: textSecondary, fontSize: 15, fontWeight: FontWeight.w600)),
        ),
        if (!isLast) Divider(height: 1, indent: 16, color: border),
      ],
    );
  }
}

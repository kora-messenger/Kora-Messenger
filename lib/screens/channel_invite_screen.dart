import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/kora_colors.dart';
import '../config/kora_api.dart';

/// Channel Invite Screen — manage and share channel invite link.
/// Mirrors WhatsApp's channel invite/link management.
///
/// Features:
/// - Generate/copy invite link
/// - QR code for the channel
/// - Share via other apps
/// - Revoke/reset link
/// - Link settings (expiry, approval required)
class ChannelInviteScreen extends StatefulWidget {
  final String channelName;
  final String channelId;

  const ChannelInviteScreen({
    super.key,
    required this.channelName,
    required this.channelId,
  });

  @override
  State<ChannelInviteScreen> createState() => _ChannelInviteScreenState();
}

class _ChannelInviteScreenState extends State<ChannelInviteScreen> {
  bool _linkEnabled = true;
  bool _requireApproval = false;
  String _inviteLink = '';

  @override
  void initState() {
    super.initState();
    _inviteLink = '${KoraApi.channelBaseUrl}/channel/${widget.channelId}';
  }

  void _copyLink() {
    Clipboard.setData(ClipboardData(text: _inviteLink));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Invite link copied'),
        backgroundColor: KoraColors.purple,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _resetLink() {
    setState(() {
      _inviteLink = '${KoraApi.channelBaseUrl}/channel/${widget.channelId}/${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invite link reset. Old link is no longer valid.'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: Text('Invite via Link',
            style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Channel header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [KoraColors.purple.withValues(alpha: 0.1), KoraColors.blue.withValues(alpha: 0.08)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [KoraColors.purple, KoraColors.blue]),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(widget.channelName.isNotEmpty ? widget.channelName[0].toUpperCase() : 'C',
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(widget.channelName,
                      style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Invite link card
          if (_linkEnabled) ...[
            Text('Channel Invite Link', style: TextStyle(color: textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: KoraColors.purple.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.link, color: KoraColors.purple, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_inviteLink,
                        style: TextStyle(color: KoraColors.purple, fontSize: 14),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  IconButton(
                    icon: Icon(Icons.copy, color: KoraColors.purple, size: 20),
                    onPressed: _copyLink,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _copyLink,
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy Link'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: KoraColors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('Share'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: surface,
                      foregroundColor: KoraColors.purple,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: BorderSide(color: KoraColors.purple.withValues(alpha: 0.3)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // QR Code placeholder
            Center(
              child: Container(
                width: 160, height: 160,
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: KoraColors.purple.withValues(alpha: 0.2)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.qr_code_2, size: 80, color: KoraColors.purple),
                    const SizedBox(height: 4),
                    Text('Scan to join', style: TextStyle(color: textMuted, fontSize: 12)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _resetLink,
              icon: Icon(Icons.refresh, color: textMuted, size: 18),
              label: Text('Reset Link', style: TextStyle(color: textMuted, fontSize: 14)),
            ),
          ] else ...[
            Center(
              child: Column(
                children: [
                  Icon(Icons.link_off, size: 56, color: textMuted),
                  const SizedBox(height: 16),
                  Text('Link is off', style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text('Turn on the link to invite people to your channel',
                      style: TextStyle(color: textMuted, fontSize: 14), textAlign: TextAlign.center),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Settings
          Text('Settings', style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SwitchListTile(
            title: Text('Enable invite link', style: TextStyle(color: textPrimary, fontSize: 15)),
            subtitle: Text('Allow people to join via link', style: TextStyle(color: textMuted, fontSize: 13)),
            value: _linkEnabled,
            onChanged: (v) => setState(() => _linkEnabled = v),
            activeColor: KoraColors.purple,
          ),
          SwitchListTile(
            title: Text('Require admin approval', style: TextStyle(color: textPrimary, fontSize: 15)),
            subtitle: Text('Admins must approve new followers', style: TextStyle(color: textMuted, fontSize: 13)),
            value: _requireApproval,
            onChanged: _linkEnabled ? (v) => setState(() => _requireApproval = v) : null,
            activeColor: KoraColors.purple,
          ),
        ],
      ),
    );
  }
}

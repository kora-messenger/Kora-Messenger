import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';

/// Transfer Chats screen — WhatsApp's Settings > Chats > Transfer chats
/// entry point.
///
/// Kora transfers chats through the encrypted Kora cloud: chats are
/// backed up from this device and restored automatically when the same
/// account signs in on a new phone. No local device-to-device QR/Wi-Fi
/// transfer is simulated — this screen explains the real flow.
class ChatTransferScreen extends StatelessWidget {
  const ChatTransferScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);

    final steps = const [
      ('1', 'Back up your chats on this phone',
          'Your chat history is backed up to the encrypted Kora cloud from Settings > Chats > Backup.'),
      ('2', 'Install Kora on your new phone',
          'Download Kora Messenger and open it. You don\'t need to keep this phone nearby.'),
      ('3', 'Sign in with your account',
          'When you log in on the new phone, your chats restore from the cloud automatically.'),
    ];

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: Text('Transfer chats',
            style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 12),
          Icon(Icons.cloud_done_outlined, size: 56, color: KoraColors.purple),
          const SizedBox(height: 16),
          Text('Move your chats to a new phone',
              textAlign: TextAlign.center,
              style: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            'Your chat history, photos, videos, and voice messages are backed up to the encrypted Kora cloud and restore automatically when you sign in on your new phone.',
            textAlign: TextAlign.center,
            style: TextStyle(color: textMuted, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 28),
          ...steps.map((step) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: KoraColors.borderFor(brightness), width: 0.5),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: KoraColors.brandGradient,
                        shape: BoxShape.circle,
                      ),
                      child: Text(step.$1,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(step.$2,
                              style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(step.$3,
                              style: TextStyle(color: textMuted, fontSize: 12.5, height: 1.4)),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: KoraColors.purple.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: KoraColors.purple),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Make sure your last backup is up to date before switching phones. Messages sent after your last backup won\'t transfer.',
                    style: TextStyle(color: KoraColors.purple, fontSize: 12, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

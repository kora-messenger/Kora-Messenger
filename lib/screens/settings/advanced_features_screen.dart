import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';

export 'chat_backup_screen.dart';
export 'chat_transfer_screen.dart';
export 'qr_transfer_screen.dart';

/// Channel Admin screen — manage a channel as an admin.
/// Mirrors WhatsApp Channel admin features.
class ChannelAdminScreen extends StatelessWidget {
  final String channelName;

  const ChannelAdminScreen({super.key, required this.channelName});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: Text('Channel Admin',
            style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          ListTile(
            leading: Icon(Icons.people_outline, color: KoraColors.purple),
            title: Text('Followers', style: TextStyle(color: textPrimary)),
            subtitle: Text('0 followers', style: TextStyle(color: textMuted, fontSize: 13)),
          ),
          ListTile(
            leading: Icon(Icons.person_add_outlined, color: KoraColors.purple),
            title: Text('Add admin', style: TextStyle(color: textPrimary)),
          ),
          ListTile(
            leading: Icon(Icons.link, color: KoraColors.purple),
            title: Text('Channel link', style: TextStyle(color: textPrimary)),
            subtitle: Text('Copy invite link', style: TextStyle(color: textMuted, fontSize: 13)),
          ),
          ListTile(
            leading: Icon(Icons.emoji_emotions, color: KoraColors.purple),
            title: Text('Reactions', style: TextStyle(color: textPrimary)),
            subtitle: Text('Allow reactions', style: TextStyle(color: textMuted, fontSize: 13)),
          ),
          ListTile(
            leading: Icon(Icons.delete_outline, color: Colors.red),
            title: Text('Delete channel', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

/// Community Directory screen — browse all communities the user has joined.
/// Mirrors WhatsApp's Community Directory feature.
class CommunityDirectoryScreen extends StatelessWidget {
  const CommunityDirectoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: Text('Communities',
            style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.groups_outlined, size: 56, color: KoraColors.purple),
            const SizedBox(height: 16),
            Text('No communities yet',
                style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Join or create a community to get started',
                style: TextStyle(color: textMuted, fontSize: 14)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Feature coming soon"), behavior: SnackBarBehavior.floating)); },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New Community'),
              style: ElevatedButton.styleFrom(
                backgroundColor: KoraColors.purple, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Age Verification screen — verify user is 13+ for compliance.
/// Mirrors WhatsApp's age verification feature.
class AgeVerificationScreen extends StatefulWidget {
  const AgeVerificationScreen({super.key});

  @override
  State<AgeVerificationScreen> createState() => _AgeVerificationScreenState();
}

class _AgeVerificationScreenState extends State<AgeVerificationScreen> {
  int _age = 18;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: Text('Age Verification',
            style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.cake, size: 56, color: KoraColors.purple),
            const SizedBox(height: 16),
            Text('Verify your age',
                style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('You must be at least 13 years old to use Kora Messenger.',
                textAlign: TextAlign.center,
                style: TextStyle(color: textMuted, fontSize: 14, height: 1.4)),
            const SizedBox(height: 32),
            Text('$_age years old',
                style: TextStyle(color: KoraColors.purple, fontSize: 28, fontWeight: FontWeight.w700)),
            Slider(
              value: _age.toDouble(), min: 13, max: 100, divisions: 87,
              onChanged: (v) => setState(() => _age = v.round()),
              activeColor: KoraColors.purple,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, _age),
                style: ElevatedButton.styleFrom(
                  backgroundColor: KoraColors.purple, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Confirm Age', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

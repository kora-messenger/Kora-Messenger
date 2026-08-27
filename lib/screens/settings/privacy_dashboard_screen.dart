import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';

/// Privacy Dashboard — central hub for all privacy settings.
/// Mirrors WhatsApp's Privacy Dashboard / Privacy Checkup.
///
/// Shows:
/// - Privacy checkup progress
//! - Quick links to: Last seen, Profile photo, About, Status, Groups
//! - Block list, App lock, Secret code
/// - Silence unknown callers
/// - Suspicious link detection
/// - Safety numbers
class PrivacyDashboardScreen extends StatelessWidget {
  const PrivacyDashboardScreen({super.key});

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
        title: Text('Privacy Dashboard',
            style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // Privacy checkup banner
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [KoraColors.purple.withValues(alpha: 0.15), KoraColors.blue.withValues(alpha: 0.1)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.shield_outlined, size: 32, color: KoraColors.purple),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Privacy Checkup',
                          style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                      Text('Review who can see your info',
                          style: TextStyle(color: textMuted, fontSize: 13)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: KoraColors.purple),
              ],
            ),
          ),

          _section('Who can see my info', [
            _privacyItem(context, Icons.visibility_outlined, 'Last seen & online',
                'My contacts', onTap: () {}),
            _privacyItem(context, Icons.person_outline, 'Profile photo',
                'Everyone', onTap: () {}),
            _privacyItem(context, Icons.info_outline, 'About',
                'My contacts', onTap: () {}),
            _privacyItem(context, Icons.circle_outlined, 'Status',
                'My contacts', onTap: () {}),
            _privacyItem(context, Icons.group_outlined, 'Groups',
                'Everyone', onTap: () {}),
          ]),

          _section('Security', [
            _privacyItem(context, Icons.lock_outline, 'App Lock',
                'Enabled', onTap: () {}),
            _privacyItem(context, Icons.password_outlined, 'Secret Code',
                'Set up', onTap: () {}),
            _privacyItem(context, Icons.fingerprint, 'Passkeys',
                'Not set up', onTap: () {}),
            _privacyItem(context, Icons.verified_user_outlined, 'Safety Numbers',
                'Verify contacts', onTap: () {}),
          ]),

          _section('Communication', [
            _privacyItem(context, Icons.block_outlined, 'Blocked accounts',
                '0 blocked', onTap: () {}),
            _privacyItem(context, Icons.phone_disabled_outlined, 'Silence unknown callers',
                'Off', onTap: () {}),
            _privacyItem(context, Icons.link_off_outlined, 'Suspicious link detection',
                'On', onTap: () {}),
          ]),

          _section('Messages', [
            _privacyItem(context, Icons.timer_outlined, 'Disappearing messages',
                'Off', onTap: () {}),
            _privacyItem(context, Icons.archive_outlined, 'Archived chats',
                'Keep archived', onTap: () {}),
            _privacyItem(context, Icons.mark_chat_read_outlined, 'Read receipts',
                'On', onTap: () {}),
          ]),
        ],
      ),
    );
  }

  Widget _section(String label, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(label,
              style: TextStyle(
                  color: KoraColors.purple,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ),
        ...children,
      ],
    );
  }

  Widget _privacyItem(BuildContext context, IconData icon, String title,
      String subtitle, {required VoidCallback onTap}) {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);

    return ListTile(
      leading: Icon(icon, size: 22, color: textMuted),
      title: Text(title, style: TextStyle(color: textPrimary, fontSize: 15)),
      subtitle: Text(subtitle, style: TextStyle(color: textMuted, fontSize: 13)),
      trailing: Icon(Icons.chevron_right, size: 18, color: textMuted),
      onTap: onTap,
    );
  }
}

/// Secret Code screen — set a secret code to access locked chats.
/// Mirrors WhatsApp's secret code feature for chat locking.
class SecretCodeScreen extends StatefulWidget {
  const SecretCodeScreen({super.key});

  @override
  State<SecretCodeScreen> createState() => _SecretCodeScreenState();
}

class _SecretCodeScreenState extends State<SecretCodeScreen> {
  final _codeController = TextEditingController();
  final _confirmController = TextEditingController();
  String _error = '';

  void _save() {
    if (_codeController.text.length < 4) {
      setState(() => _error = 'Code must be at least 4 characters');
      return;
    }
    if (_codeController.text != _confirmController.text) {
      setState(() => _error = 'Codes do not match');
      return;
    }
    Navigator.pop(context, _codeController.text);
  }

  @override
  void dispose() {
    _codeController.dispose();
    _confirmController.dispose();
    super.dispose();
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
        title: Text('Secret Code',
            style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock, size: 48, color: KoraColors.purple),
            const SizedBox(height: 16),
            Text('Create a secret code',
                style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Use this code to access your locked chats. Choose something memorable.',
                style: TextStyle(color: textMuted, fontSize: 14, height: 1.4)),
            const SizedBox(height: 32),
            TextField(
              controller: _codeController,
              obscureText: true,
              style: TextStyle(color: textPrimary),
              decoration: InputDecoration(
                hintText: 'Enter secret code',
                hintStyle: TextStyle(color: textMuted),
                filled: true, fillColor: surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmController,
              obscureText: true,
              style: TextStyle(color: textPrimary),
              decoration: InputDecoration(
                hintText: 'Confirm secret code',
                hintStyle: TextStyle(color: textMuted),
                filled: true, fillColor: surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(_error, style: TextStyle(color: Colors.red, fontSize: 13)),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: KoraColors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Save Code', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Silence Unknown Callers screen — toggle to silence calls from
/// unknown numbers. Mirrors WhatsApp's feature.
class SilenceUnknownCallersScreen extends StatefulWidget {
  const SilenceUnknownCallersScreen({super.key});

  @override
  State<SilenceUnknownCallersScreen> createState() => _SilenceUnknownCallersScreenState();
}

class _SilenceUnknownCallersScreenState extends State<SilenceUnknownCallersScreen> {
  bool _enabled = false;

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
        title: Text('Silence Unknown Callers',
            style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Icon(Icons.phone_disabled, size: 48, color: KoraColors.purple),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Calls from unknown numbers will be silenced. They will still appear in your Calls tab.',
                    style: TextStyle(color: textMuted, fontSize: 14, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          SwitchListTile(
            title: Text('Silence unknown callers',
                style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
            activeColor: KoraColors.purple,
          ),
        ],
      ),
    );
  }
}

/// Safety Numbers screen — verify end-to-end encryption with contacts.
/// Shows the 60-digit safety number for a specific contact.
class SafetyNumbersScreen extends StatelessWidget {
  final String contactName;

  const SafetyNumbersScreen({super.key, required this.contactName});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);

    // Generate a fake 60-digit safety number
    final safetyNumber = List.generate(12, (_) =>
        (List.generate(5, (_) => (DateTime.now().millisecond % 10).toString()).join()))
        .join(' ');

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: Text('Safety Numbers',
            style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.verified_user, size: 56, color: KoraColors.purple),
            const SizedBox(height: 16),
            Text('Verify security code with $contactName',
                textAlign: TextAlign.center,
                style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: KoraColors.purple.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Text(safetyNumber,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: textPrimary, fontSize: 16,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 2, height: 1.8,
                          fontFamily: 'monospace')),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock, size: 14, color: KoraColors.purple),
                      const SizedBox(width: 6),
                      Text('End-to-end encrypted',
                          style: TextStyle(color: KoraColors.purple, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'If the code on this screen matches the code on $contactName\'s phone, your communication is secure.',
              textAlign: TextAlign.center,
              style: TextStyle(color: textMuted, fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

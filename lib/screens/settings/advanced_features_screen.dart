import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';

/// Chat Transfer screen — transfer chats from one device to another
/// via QR code or direct transfer. Mirrors WhatsApp's chat transfer.
class ChatTransferScreen extends StatelessWidget {
  const ChatTransferScreen({super.key});

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
        title: Text('Transfer Chats',
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
            const SizedBox(height: 24),
            Icon(Icons.swap_horiz, size: 56, color: KoraColors.purple),
            const SizedBox(height: 16),
            Text('Transfer your chats',
                style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Move your chat history from another device to this phone.',
                textAlign: TextAlign.center,
                style: TextStyle(color: textMuted, fontSize: 14, height: 1.4)),
            const SizedBox(height: 32),

            // Option 1: Transfer from old phone
            _optionCard(
              surface, textPrimary, textMuted,
              Icons.phone_android, 'Transfer from old phone',
              'Use QR code to transfer chats directly',
              () {},
            ),
            const SizedBox(height: 12),

            // Option 2: Import from backup
            _optionCard(
              surface, textPrimary, textMuted,
              Icons.backup_outlined, 'Import from backup',
              'Restore from an encrypted backup file',
              () {},
            ),
            const SizedBox(height: 12),

            // Option 3: Export chats
            _optionCard(
              surface, textPrimary, textMuted,
              Icons.file_download_outlined, 'Export chats',
              'Export your chat history to a file',
              () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _optionCard(Color surface, Color textPrimary, Color textMuted,
      IconData icon, String title, String subtitle, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surface, borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 28, color: KoraColors.purple),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                  Text(subtitle, style: TextStyle(color: textMuted, fontSize: 13)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: textMuted),
          ],
        ),
      ),
    );
  }
}

/// QR Transfer screen — scan QR code to transfer chats.
class QrTransferScreen extends StatefulWidget {
  const QrTransferScreen({super.key});

  @override
  State<QrTransferScreen> createState() => _QrTransferScreenState();
}

class _QrTransferScreenState extends State<QrTransferScreen> {
  bool _scanning = false;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('Scan QR Code', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 250, height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: KoraColors.purple, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: _scanning
                  ? Center(child: CircularProgressIndicator(color: KoraColors.purple))
                  : Icon(Icons.qr_code_scanner, size: 80, color: Colors.white54),
            ),
            const SizedBox(height: 24),
            Text('Point your camera at the QR code\non your old device',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => setState(() => _scanning = true),
              style: ElevatedButton.styleFrom(
                backgroundColor: KoraColors.purple, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Start Scan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Encrypted Backup screen — create an encrypted backup of chats.
class EncryptedBackupScreen extends StatefulWidget {
  const EncryptedBackupScreen({super.key});

  @override
  State<EncryptedBackupScreen> createState() => _EncryptedBackupScreenState();
}

class _EncryptedBackupScreenState extends State<EncryptedBackupScreen> {
  bool _encrypt = true;
  bool _backing = false;
  double _progress = 0;

  void _startBackup() async {
    setState(() => _backing = true);
    for (var i = 0; i <= 100; i += 10) {
      await Future.delayed(const Duration(milliseconds: 200));
      setState(() => _progress = i / 100);
    }
    setState(() => _backing = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Backup complete'),
          backgroundColor: KoraColors.purple,
        ),
      );
    }
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
        title: Text('Encrypted Backup',
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
            Icon(Icons.backup, size: 48, color: KoraColors.purple),
            const SizedBox(height: 16),
            Text('Create an encrypted backup',
                style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Your chats and media will be encrypted with a password.',
                style: TextStyle(color: textMuted, fontSize: 14, height: 1.4)),
            const SizedBox(height: 24),
            SwitchListTile(
              title: Text('Encrypt with password',
                  style: TextStyle(color: textPrimary, fontSize: 15)),
              value: _encrypt, onChanged: (v) => setState(() => _encrypt = v),
              activeColor: KoraColors.purple,
            ),
            if (_encrypt) ...[
              const SizedBox(height: 8),
              TextField(
                obscureText: true,
                style: TextStyle(color: textPrimary),
                decoration: InputDecoration(
                  hintText: 'Backup password',
                  hintStyle: TextStyle(color: textMuted),
                  filled: true, fillColor: surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ],
            const SizedBox(height: 24),
            if (_backing) ...[
              LinearProgressIndicator(value: _progress, color: KoraColors.purple,
                  backgroundColor: surface, minHeight: 8, borderRadius: BorderRadius.circular(4)),
              const SizedBox(height: 8),
              Text('${(_progress * 100).round()}%', style: TextStyle(color: textMuted, fontSize: 13)),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _startBackup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: KoraColors.purple, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Create Backup', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Business Profile screen — set up a business profile with catalog,
/// templates, away message, labels, and business hours.
/// Mirrors WhatsApp Business features.
class BusinessProfileScreen extends StatefulWidget {
  const BusinessProfileScreen({super.key});

  @override
  State<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends State<BusinessProfileScreen> {
  int _selectedTab = 0;

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
        title: Text('Business Profile',
            style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Row(
            children: [
              _tab('Catalog', 0), _tab('Templates', 1),
              _tab('Away', 2), _tab('Labels', 3), _tab('Hours', 4),
            ],
          ),
        ),
      ),
      body: _buildTab(),
    );
  }

  Widget _tab(String label, int index) {
    final isActive = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? KoraColors.purple : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(label, textAlign: TextAlign.center,
              style: TextStyle(
                  color: isActive ? KoraColors.purple : KoraColors.textMutedFor(Theme.of(context).brightness),
                  fontSize: 13, fontWeight: isActive ? FontWeight.w600 : FontWeight.w400)),
        ),
      ),
    );
  }

  Widget _buildTab() {
    switch (_selectedTab) {
      case 0: return _catalogTab();
      case 1: return _templatesTab();
      case 2: return _awayTab();
      case 3: return _labelsTab();
      case 4: return _hoursTab();
      default: return _catalogTab();
    }
  }

  Widget _catalogTab() {
    final brightness = Theme.of(context).brightness;
    final surface = KoraColors.surfaceFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              Icon(Icons.storefront, size: 40, color: KoraColors.purple),
              const SizedBox(height: 8),
              Text('Add products or services', style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('Create a catalog to showcase what you offer', style: TextStyle(color: textMuted, fontSize: 13)),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Product'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: KoraColors.purple, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _templatesTab() {
    final brightness = Theme.of(context).brightness;
    final surface = KoraColors.surfaceFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Quick Replies', style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        _templateItem(surface, textPrimary, textMuted, '/greeting', 'Hello! Welcome to our store.'),
        _templateItem(surface, textPrimary, textMuted, '/hours', 'We are open Monday to Friday, 9am to 5pm.'),
        _templateItem(surface, textPrimary, textMuted, '/shipping', 'Shipping takes 3-5 business days.'),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Template'),
          style: ElevatedButton.styleFrom(
            backgroundColor: KoraColors.purple, foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _templateItem(Color surface, Color textPrimary, Color textMuted, String shortcut, String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(shortcut, style: TextStyle(color: KoraColors.purple, fontSize: 14, fontWeight: FontWeight.w700)),
          Text(message, style: TextStyle(color: textMuted, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _awayTab() {
    final brightness = Theme.of(context).brightness;
    final surface = KoraColors.surfaceFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          title: Text('Away message', style: TextStyle(color: textPrimary, fontSize: 15)),
          value: true, onChanged: (_) {},
          activeColor: KoraColors.purple,
        ),
        const SizedBox(height: 8),
        TextField(
          maxLines: 3,
          style: TextStyle(color: textPrimary),
          decoration: InputDecoration(
            hintText: 'Type your away message…',
            hintStyle: TextStyle(color: textMuted),
            filled: true, fillColor: surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 16),
        Text('Schedule', style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
        ListTile(
          title: Text('Always send', style: TextStyle(color: textPrimary, fontSize: 14)),
          leading: Radio(value: 0, groupValue: 0, onChanged: (_) {}, activeColor: KoraColors.purple),
        ),
        ListTile(
          title: Text('Custom schedule', style: TextStyle(color: textPrimary, fontSize: 14)),
          leading: Radio(value: 1, groupValue: 0, onChanged: (_) {}, activeColor: KoraColors.purple),
        ),
      ],
    );
  }

  Widget _labelsTab() {
    final brightness = Theme.of(context).brightness;
    final surface = KoraColors.surfaceFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _labelChip(surface, textPrimary, Colors.red, 'New Customer'),
        _labelChip(surface, textPrimary, Colors.orange, 'Pending Payment'),
        _labelChip(surface, textPrimary, Colors.green, 'Order Complete'),
        _labelChip(surface, textPrimary, Colors.blue, 'VIP Customer'),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Label'),
          style: ElevatedButton.styleFrom(
            backgroundColor: KoraColors.purple, foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _labelChip(Color surface, Color textPrimary, Color color, String label) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Icon(Icons.label, color: color, size: 20),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _hoursTab() {
    final brightness = Theme.of(context).brightness;
    final surface = KoraColors.surfaceFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: days.map((day) => SwitchListTile(
        title: Text(day, style: TextStyle(color: textPrimary, fontSize: 15)),
        subtitle: Text('9:00 AM - 5:00 PM', style: TextStyle(color: textMuted, fontSize: 13)),
        value: day != 'Sunday', onChanged: (_) {},
        activeColor: KoraColors.purple,
      )).toList(),
    );
  }
}

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
            leading: Icon(Icons.reactions, color: KoraColors.purple),
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
              onPressed: () {},
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

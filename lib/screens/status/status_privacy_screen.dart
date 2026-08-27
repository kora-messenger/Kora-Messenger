import 'package:flutter/material.dart';

import '../../theme/kora_colors.dart';
import '../../models/status_model.dart';
import '../../services/status_service.dart';

/// WhatsApp-style Status privacy settings screen.
///
/// Lets the user choose who can see their status updates:
/// - My contacts (default)
/// - My contacts except...
/// - Only share with...
class StatusPrivacyScreen extends StatefulWidget {
  const StatusPrivacyScreen({super.key});

  @override
  State<StatusPrivacyScreen> createState() => _StatusPrivacyScreenState();
}

class _StatusPrivacyScreenState extends State<StatusPrivacyScreen> {
  StatusPrivacy _selected = StatusPrivacy.myContacts;

  @override
  void initState() {
    super.initState();
    _selected = StatusService.instance.privacy;
  }

  Future<void> _save() async {
    await StatusService.instance.setPrivacy(_selected);
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Status privacy updated'),
          backgroundColor: KoraColors.purple,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final border = KoraColors.borderFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text('Status privacy', style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Status privacy',
            style: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose who can see your status updates. Changes apply to all future status updates.',
            style: TextStyle(color: textSecondary, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 24),
          _privacyOption(
            title: 'My contacts',
            subtitle: 'All your contacts can see your status',
            value: StatusPrivacy.myContacts,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            border: border,
          ),
          _privacyOption(
            title: 'My contacts except...',
            subtitle: 'All contacts except those you exclude',
            value: StatusPrivacy.myContactsExcept,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            border: border,
          ),
          _privacyOption(
            title: 'Only share with...',
            subtitle: 'Only selected contacts can see your status',
            value: StatusPrivacy.onlyShareWith,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            border: border,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: KoraColors.purple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('Done', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _privacyOption({
    required String title,
    required String subtitle,
    required StatusPrivacy value,
    required Color textPrimary,
    required Color textSecondary,
    required Color border,
  }) {
    final isSelected = _selected == value;
    return GestureDetector(
      onTap: () => setState(() => _selected = value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? KoraColors.purple.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? KoraColors.purple : border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: textSecondary, fontSize: 13)),
                ],
              ),
            ),
            Radio<StatusPrivacy>(
              value: value,
              groupValue: _selected,
              onChanged: (v) => setState(() => _selected = v ?? StatusPrivacy.myContacts),
              activeColor: KoraColors.purple,
            ),
          ],
        ),
      ),
    );
  }
}

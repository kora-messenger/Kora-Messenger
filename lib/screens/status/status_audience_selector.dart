import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import '../../models/status_model.dart';

/// Status Audience Selector — choose who can see each individual status.
/// Mirrors WhatsApp's per-status audience picker.
///
/// Shows a bottom sheet with:
/// - My contacts (default)
/// - My contacts except...
/// - Only share with...
/// - Tap a contact to include/exclude
class StatusAudienceSelector extends StatefulWidget {
  final StatusPrivacy currentPrivacy;
  final List<String> excludedIds;
  final List<String> includedIds;
  final ValueChanged<StatusAudience> onSelected;

  const StatusAudienceSelector({
    super.key,
    this.currentPrivacy = StatusPrivacy.myContacts,
    this.excludedIds = const [],
    this.includedIds = const [],
    required this.onSelected,
  });

  @override
  State<StatusAudienceSelector> createState() => _StatusAudienceSelectorState();
}

class _StatusAudienceSelectorState extends State<StatusAudienceSelector> {
  late StatusPrivacy _privacy;
  late List<String> _excluded;
  late List<String> _included;

  @override
  void initState() {
    super.initState();
    _privacy = widget.currentPrivacy;
    _excluded = List.from(widget.excludedIds);
    _included = List.from(widget.includedIds);
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
        title: Text('Status Audience',
            style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: Icon(Icons.close, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () {
              widget.onSelected(StatusAudience(
                privacy: _privacy,
                excludedContactIds: _excluded,
                includedContactIds: _included,
              ));
              Navigator.pop(context);
            },
            child: Text('Done', style: TextStyle(color: KoraColors.purple, fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Who can see this status?',
              style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('This applies to this status only. Your default privacy is separate.',
              style: TextStyle(color: textMuted, fontSize: 13)),
          const SizedBox(height: 24),

          // Privacy options
          _privacyOption(
            icon: Icons.contacts_outlined,
            title: 'My contacts',
            subtitle: 'All contacts can see this status',
            value: StatusPrivacy.myContacts,
            surface: surface, textPrimary: textPrimary, textMuted: textMuted,
          ),
          _privacyOption(
            icon: Icons.contacts_outlined,
            title: 'My contacts except...',
            subtitle: _excluded.isEmpty
                ? 'Exclude specific contacts'
                : '${_excluded.length} contact${_excluded.length == 1 ? "" : "s"} excluded',
            value: StatusPrivacy.myContactsExcept,
            surface: surface, textPrimary: textPrimary, textMuted: textMuted,
            onTap: () => _showContactPicker(isExclude: true),
          ),
          _privacyOption(
            icon: Icons.person_outline,
            title: 'Only share with...',
            subtitle: _included.isEmpty
                ? 'Select specific contacts'
                : '${_included.length} contact${_included.length == 1 ? "" : "s"} selected',
            value: StatusPrivacy.onlyShareWith,
            surface: surface, textPrimary: textPrimary, textMuted: textMuted,
            onTap: () => _showContactPicker(isExclude: false),
          ),

          const SizedBox(height: 24),

          // Info note
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
                    'Status updates disappear after 24 hours. You can delete a status at any time.',
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

  Widget _privacyOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required StatusPrivacy value,
    required Color surface, required Color textPrimary, required Color textMuted,
    VoidCallback? onTap,
  }) {
    final isSelected = _privacy == value;
    return ListTile(
      leading: Icon(icon, color: isSelected ? KoraColors.purple : textMuted, size: 24),
      title: Text(title, style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: TextStyle(color: textMuted, fontSize: 13)),
      trailing: Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
          color: isSelected ? KoraColors.purple : textMuted),
      onTap: () {
        setState(() => _privacy = value);
        if (onTap != null && (value == StatusPrivacy.myContactsExcept || value == StatusPrivacy.onlyShareWith)) {
          onTap();
        }
      },
    );
  }

  void _showContactPicker({required bool isExclude}) {
    // In production, this opens a contact picker screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isExclude ? 'Select contacts to exclude' : 'Select contacts to share with'),
        backgroundColor: KoraColors.purple,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class StatusAudience {
  final StatusPrivacy privacy;
  final List<String> excludedContactIds;
  final List<String> includedContactIds;

  StatusAudience({
    required this.privacy,
    this.excludedContactIds = const [],
    this.includedContactIds = const [],
  });
}

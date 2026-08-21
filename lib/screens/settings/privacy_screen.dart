import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/kora_colors.dart';

/// Privacy settings screen — controls who can see your activity,
/// read receipts, blocked contacts, and other privacy options.
class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

/// Visibility options for privacy fields.
enum PrivacyVisibility { everyone, myContacts, nobody }

extension PrivacyVisibilityLabel on PrivacyVisibility {
  String get label {
    switch (this) {
      case PrivacyVisibility.everyone:
        return 'Everyone';
      case PrivacyVisibility.myContacts:
        return 'My Contacts';
      case PrivacyVisibility.nobody:
        return 'Nobody';
    }
  }
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  // Visibility settings
  PrivacyVisibility _lastSeen = PrivacyVisibility.everyone;
  PrivacyVisibility _profilePhoto = PrivacyVisibility.everyone;
  PrivacyVisibility _about = PrivacyVisibility.everyone;

  // Toggles
  bool _readReceipts = true;
  bool _typingIndicator = true;

  // Group / call privacy
  PrivacyVisibility _whoCanAddToGroups = PrivacyVisibility.myContacts;
  PrivacyVisibility _whoCanCall = PrivacyVisibility.everyone;

  // Saved keys
  static const _prefsPrefix = 'kora_privacy_';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lastSeen = _loadVisibility(prefs, 'last_seen');
      _profilePhoto = _loadVisibility(prefs, 'profile_photo');
      _about = _loadVisibility(prefs, 'about');
      _readReceipts = prefs.getBool('${_prefsPrefix}read_receipts') ?? true;
      _typingIndicator = prefs.getBool('${_prefsPrefix}typing_indicator') ?? true;
      _whoCanAddToGroups = _loadVisibility(prefs, 'who_can_add_groups');
      _whoCanCall = _loadVisibility(prefs, 'who_can_call');
    });
  }

  PrivacyVisibility _loadVisibility(SharedPreferences prefs, String key) {
    final value = prefs.getString('$_prefsPrefix$key');
    return PrivacyVisibility.values.firstWhere(
      (e) => e.name == value,
      orElse: () => PrivacyVisibility.everyone,
    );
  }

  Future<void> _saveVisibility(String key, PrivacyVisibility value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefsPrefix$key', value.name);
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefsPrefix$key', value);
  }

  void _showVisibilityPicker({
    required String title,
    required String? subtitle,
    required PrivacyVisibility current,
    required ValueChanged<PrivacyVisibility> onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: KoraColors.cardFor(Theme.of(context).brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final brightness = Theme.of(context).brightness;
        final textPrimary = KoraColors.textPrimaryFor(brightness);
        final textSecondary = KoraColors.textSecondaryFor(brightness);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      subtitle,
                      style: TextStyle(color: textSecondary, fontSize: 13, height: 1.4),
                    ),
                  ),
                )
              else
                const SizedBox(height: 12),
              ...PrivacyVisibility.values.map((v) {
                return RadioListTile<PrivacyVisibility>(
                  value: v,
                  groupValue: current,
                  activeColor: KoraColors.purple,
                  title: Text(
                    v.label,
                    style: TextStyle(color: textPrimary, fontSize: 15),
                  ),
                  onChanged: (selected) {
                    if (selected != null) {
                      onSelected(selected);
                      Navigator.pop(context);
                    }
                  },
                );
              }),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);
    final card = KoraColors.cardFor(brightness);
    final border = KoraColors.borderFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          'Privacy',
          style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            // ── Header icon ─────────────────────────────────
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: KoraColors.brandGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.privacy_tip_outlined, color: Colors.white, size: 34),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Control your privacy',
              textAlign: TextAlign.center,
              style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose who can see your information and how others interact with you on Kora.',
              textAlign: TextAlign.center,
              style: TextStyle(color: textSecondary, fontSize: 13.5, height: 1.5),
            ),
            const SizedBox(height: 28),

            // ── VISIBILITY section ───────────────────────────
            _sectionLabel('VISIBILITY', textMuted),
            _navTile(
              icon: Icons.access_time_rounded,
              title: 'Last Seen & Online',
              subtitle: _lastSeen.label,
              current: _lastSeen,
              onSelected: (v) {
                setState(() => _lastSeen = v);
                _saveVisibility('last_seen', v);
              },
              card: card,
              border: border,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            _navTile(
              icon: Icons.account_circle_outlined,
              title: 'Profile Photo',
              subtitle: _profilePhoto.label,
              current: _profilePhoto,
              onSelected: (v) {
                setState(() => _profilePhoto = v);
                _saveVisibility('profile_photo', v);
              },
              card: card,
              border: border,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            _navTile(
              icon: Icons.info_outline_rounded,
              title: 'About',
              subtitle: _about.label,
              current: _about,
              onSelected: (v) {
                setState(() => _about = v);
                _saveVisibility('about', v);
              },
              card: card,
              border: border,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),

            const SizedBox(height: 24),

            // ── MESSAGING section ───────────────────────────
            _sectionLabel('MESSAGING', textMuted),
            _toggleTile(
              icon: Icons.done_all_rounded,
              title: 'Read Receipts',
              subtitle: 'Send and receive blue ticks for read messages',
              value: _readReceipts,
              onChanged: (v) {
                setState(() => _readReceipts = v);
                _saveBool('read_receipts', v);
              },
              card: card,
              border: border,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            _toggleTile(
              icon: Icons.edit_rounded,
              title: 'Typing Indicator',
              subtitle: 'Show others when you are typing',
              value: _typingIndicator,
              onChanged: (v) {
                setState(() => _typingIndicator = v);
                _saveBool('typing_indicator', v);
              },
              card: card,
              border: border,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),

            const SizedBox(height: 24),

            // ── GROUPS & CALLS section ──────────────────────
            _sectionLabel('GROUPS & CALLS', textMuted),
            _navTile(
              icon: Icons.group_add_outlined,
              title: 'Who Can Add Me to Groups',
              subtitle: _whoCanAddToGroups.label,
              current: _whoCanAddToGroups,
              onSelected: (v) {
                setState(() => _whoCanAddToGroups = v);
                _saveVisibility('who_can_add_groups', v);
              },
              card: card,
              border: border,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            _navTile(
              icon: Icons.call_outlined,
              title: 'Who Can Call Me',
              subtitle: _whoCanCall.label,
              current: _whoCanCall,
              onSelected: (v) {
                setState(() => _whoCanCall = v);
                _saveVisibility('who_can_call', v);
              },
              card: card,
              border: border,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),

            const SizedBox(height: 24),

            // ── CONTACTS section ────────────────────────────
            _sectionLabel('CONTACTS', textMuted),
            _actionTile(
              icon: Icons.block_rounded,
              iconColor: KoraColors.red,
              title: 'Blocked Contacts',
              subtitle: 'Manage blocked numbers and accounts',
              onTap: () => _showComingSoon('Blocked contacts'),
              card: card,
              border: border,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              textMuted: textMuted,
            ),

            const SizedBox(height: 24),

            // ── Info note ──────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: KoraColors.purple.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: KoraColors.purple.withValues(alpha: 0.2), width: 0.5),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: KoraColors.purple, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your privacy settings apply to your Kora Messenger account across all your devices. Changes take effect immediately.',
                      style: TextStyle(color: textSecondary, fontSize: 12.5, height: 1.5),
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

  // ── Widgets ──────────────────────────────────────────

  Widget _sectionLabel(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  /// A tile that opens a visibility picker (Everyone / My Contacts / Nobody).
  Widget _navTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required PrivacyVisibility current,
    required ValueChanged<PrivacyVisibility> onSelected,
    required Color card,
    required Color border,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: card,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _showVisibilityPicker(
            title: title,
            subtitle: null,
            current: current,
            onSelected: onSelected,
          ),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border, width: 0.5),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: KoraColors.purple.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: KoraColors.purple, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                              color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Text(subtitle, style: TextStyle(color: textSecondary, fontSize: 12.5)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: textSecondary, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// A toggle tile for boolean settings.
  Widget _toggleTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color card,
    required Color border,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: KoraColors.purple.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: KoraColors.purple, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: TextStyle(color: textSecondary, fontSize: 12.5)),
                ],
              ),
            ),
            Switch.adaptive(
              value: value,
              activeTrackColor: KoraColors.purple,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }

  /// A simple action tile (tap to navigate).
  Widget _actionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color card,
    required Color border,
    required Color textPrimary,
    required Color textSecondary,
    required Color textMuted,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: card,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border, width: 0.5),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                              color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Text(subtitle, style: TextStyle(color: textSecondary, fontSize: 12.5)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: textMuted, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature — coming soon'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: KoraColors.purple,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

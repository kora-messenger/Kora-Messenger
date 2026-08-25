import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/kora_colors.dart';
import '../../config/kora_api.dart';
import '../../services/session_manager.dart';
import 'devices_screen.dart';

/// Privacy settings screen — controls who can see your personal info,
/// read receipts, disappearing messages, app lock, and advanced privacy.
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
  // ── Visibility settings ──────────────────────────────
  PrivacyVisibility _lastSeen = PrivacyVisibility.everyone;
  PrivacyVisibility _profilePhoto = PrivacyVisibility.everyone;
  PrivacyVisibility _about = PrivacyVisibility.myContacts;
  PrivacyVisibility _links = PrivacyVisibility.myContacts;
  PrivacyVisibility _status = PrivacyVisibility.myContacts;
  PrivacyVisibility _groups = PrivacyVisibility.everyone;

  // ── Toggles ──────────────────────────────────────────
  bool _readReceipts = true;
  bool _silenceUnknownCallers = false;
  bool _allowCameraEffects = false;
  bool _protectIpInCalls = true;
  bool _disableLinkPreviews = false;

  // ── Other ────────────────────────────────────────────
  String _defaultMessageTimer = 'Off';
  bool _appLockEnabled = false;
  bool _chatLockEnabled = false;
  int? _deviceCount;

  static const _prefsPrefix = 'kora_privacy_';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadDeviceCount();
  }

  Future<void> _loadDeviceCount() async {
    try {
      final email = SessionManager.instance.currentEmail;
      if (email.isEmpty) return;
      final result = await KoraApi.post({'action': 'listDevices', 'email': email});
      if (result['success'] == true && mounted) {
        final devices = result['devices'] as List? ?? [];
        setState(() => _deviceCount = devices.length);
      }
    } catch (_) {
      // Silently ignore — the tile just won't show a count badge.
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lastSeen = _loadVisibility(prefs, 'last_seen');
      _profilePhoto = _loadVisibility(prefs, 'profile_photo');
      _about = _loadVisibility(prefs, 'about');
      _links = _loadVisibility(prefs, 'links');
      _status = _loadVisibility(prefs, 'status');
      _groups = _loadVisibility(prefs, 'groups');
      _readReceipts = prefs.getBool('${_prefsPrefix}read_receipts') ?? true;
      _silenceUnknownCallers = prefs.getBool('${_prefsPrefix}silence_unknown_callers') ?? false;
      _allowCameraEffects = prefs.getBool('${_prefsPrefix}camera_effects') ?? false;
      _protectIpInCalls = prefs.getBool('${_prefsPrefix}protect_ip') ?? true;
      _disableLinkPreviews = prefs.getBool('${_prefsPrefix}disable_link_previews') ?? false;
      _defaultMessageTimer = prefs.getString('${_prefsPrefix}msg_timer') ?? 'Off';
      _appLockEnabled = prefs.getBool('${_prefsPrefix}app_lock') ?? false;
      _chatLockEnabled = prefs.getBool('${_prefsPrefix}chat_lock') ?? false;
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

  Future<void> _saveString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefsPrefix$key', value);
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
                final isSelected = v == current;
                return ListTile(
                  onTap: () {
                    onSelected(v);
                    Navigator.pop(context);
                  },
                  leading: Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: isSelected ? KoraColors.purple : textSecondary,
                    size: 22,
                  ),
                  title: Text(
                    v.label,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                );
              }),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _showTimerPicker() {
    final options = ['Off', '24 hours', '7 days', '90 days'];
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
                    'Default message timer',
                    style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Start new chats with messages that disappear after a chosen duration.',
                    style: TextStyle(color: textSecondary, fontSize: 13, height: 1.4),
                  ),
                ),
              ),
              ...options.map((opt) {
                final isSelected = opt == _defaultMessageTimer;
                return ListTile(
                  onTap: () {
                    setState(() => _defaultMessageTimer = opt);
                    _saveString('msg_timer', opt);
                    Navigator.pop(context);
                  },
                  leading: Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: isSelected ? KoraColors.purple : textSecondary,
                    size: 22,
                  ),
                  title: Text(
                    opt,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
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
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            // ── Privacy checkup banner ──────────────────────
            _privacyCheckupCard(textPrimary, textSecondary),
            const SizedBox(height: 20),

            // ── WHO CAN SEE MY PERSONAL INFO ───────────────
            _sectionLabel('Who can see my personal info', textMuted),
            _navTile(
              icon: Icons.access_time_rounded,
              title: 'Last seen and online',
              subtitle: _lastSeen.label,
              current: _lastSeen,
              onSelected: (v) {
                setState(() => _lastSeen = v);
                _saveVisibility('last_seen', v);
              },
            ),
            _navTile(
              icon: Icons.account_circle_outlined,
              title: 'Profile photo',
              subtitle: _profilePhoto.label,
              current: _profilePhoto,
              onSelected: (v) {
                setState(() => _profilePhoto = v);
                _saveVisibility('profile_photo', v);
              },
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
            ),
            _navTile(
              icon: Icons.link_rounded,
              title: 'Links',
              subtitle: _links.label,
              current: _links,
              onSelected: (v) {
                setState(() => _links = v);
                _saveVisibility('links', v);
              },
            ),
            _navTile(
              icon: Icons.circle_outlined,
              title: 'Status',
              subtitle: _status.label,
              current: _status,
              onSelected: (v) {
                setState(() => _status = v);
                _saveVisibility('status', v);
              },
            ),

            const SizedBox(height: 18),

            // ── Read receipts ──────────────────────────────
            _switchTile(
              icon: Icons.done_all_rounded,
              title: 'Read receipts',
              subtitle: 'If you turn off read receipts, you won\'t send or receive them. Read receipts are always sent for group chats.',
              value: _readReceipts,
              onChanged: (v) {
                setState(() => _readReceipts = v);
                _saveBool('read_receipts', v);
              },
              isLongSubtitle: true,
            ),

            const SizedBox(height: 18),

            // ── DISAPPEARING MESSAGES ──────────────────────
            _sectionLabel('Disappearing messages', textMuted),
            _simpleNavTile(
              icon: Icons.timer_outlined,
              title: 'Default message timer',
              subtitle: _defaultMessageTimer,
              onTap: _showTimerPicker,
            ),
            _simpleNavTile(
              icon: Icons.timer_outlined,
              title: 'Default timer for new chats',
              subtitle: _defaultMessageTimer,
              onTap: _showTimerPicker,
            ),

            const SizedBox(height: 18),

            // ── Groups & Calls ─────────────────────────────
            _sectionLabel('Groups & Calls', textMuted),
            _navTile(
              icon: Icons.group_add_outlined,
              title: 'Groups',
              subtitle: _groups.label,
              current: _groups,
              onSelected: (v) {
                setState(() => _groups = v);
                _saveVisibility('groups', v);
              },
            ),
            _simpleNavTile(
              icon: Icons.location_on_outlined,
              title: 'Live location',
              subtitle: 'None',
              onTap: () => _showComingSoon('Live location'),
            ),
            _switchTile(
              icon: Icons.phone_in_talk_outlined,
              title: 'Silence unknown callers',
              subtitle: 'Calls from unknown numbers will be silenced. You\'ll see them in your Calls list.',
              value: _silenceUnknownCallers,
              onChanged: (v) {
                setState(() => _silenceUnknownCallers = v);
                _saveBool('silence_unknown_callers', v);
              },
              isLongSubtitle: true,
            ),

            const SizedBox(height: 18),

            // ── Contacts ────────────────────────────────────
            _sectionLabel('Contacts', textMuted),
            _simpleNavTile(
              icon: Icons.block_rounded,
              title: 'Blocked accounts',
              subtitle: 'None',
              onTap: () => _showComingSoon('Blocked accounts'),
            ),
            _simpleNavTile(
              icon: Icons.people_outline_rounded,
              title: 'Kora contacts',
              subtitle: 'Manage your contacts on Kora',
              onTap: () => _showComingSoon('Kora contacts'),
            ),

            const SizedBox(height: 18),

            // ── Security ──────────────────────────────────
            _sectionLabel('Security', textMuted),
            _deviceNavTile(
              icon: Icons.devices_other_rounded,
              title: 'Devices',
              count: _deviceCount,
              subtitle: 'Review the list of devices where you are logged in to your Kora account.',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DevicesScreen()),
              ).then((_) => _loadDeviceCount()),
            ),
            _simpleNavTile(
              icon: Icons.lock_outline_rounded,
              title: 'App lock',
              subtitle: _appLockEnabled ? 'Enabled' : 'Disabled',
              onTap: () => _showComingSoon('App lock setup'),
            ),
            _simpleNavTile(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Chat lock',
              subtitle: _chatLockEnabled ? 'Enabled' : 'Disabled',
              onTap: () => _showComingSoon('Chat lock setup'),
            ),

            const SizedBox(height: 18),

            // ── Camera effects ─────────────────────────────
            _switchTile(
              icon: Icons.camera_alt_outlined,
              title: 'Allow camera effects',
              subtitle: 'Use effects in video calls. Learn more',
              value: _allowCameraEffects,
              onChanged: (v) {
                setState(() => _allowCameraEffects = v);
                _saveBool('camera_effects', v);
              },
              isLongSubtitle: false,
            ),

            const SizedBox(height: 18),

            // ── Advanced ───────────────────────────────────
            _sectionLabel('Advanced', textMuted),
            _switchTile(
              icon: Icons.security_outlined,
              title: 'Protect IP address in calls',
              subtitle: 'Hide your IP address from the people you call.',
              value: _protectIpInCalls,
              onChanged: (v) {
                setState(() => _protectIpInCalls = v);
                _saveBool('protect_ip', v);
              },
              isLongSubtitle: false,
            ),
            _switchTile(
              icon: Icons.link_off_outlined,
              title: 'Disable link previews',
              subtitle: 'Link previews will not be generated for messages you send.',
              value: _disableLinkPreviews,
              onChanged: (v) {
                setState(() => _disableLinkPreviews = v);
                _saveBool('disable_link_previews', v);
              },
              isLongSubtitle: false,
            ),

            const SizedBox(height: 20),

            // ── Footer note ────────────────────────────────
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
                      'Changes to your privacy settings apply across all your devices and take effect immediately.',
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

    // ── Helper widgets defined below build() ──────────────
  }

  // ── Widgets ─────────────────────────────────────────────

  Widget _privacyCheckupCard(Color textPrimary, Color textSecondary) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: KoraColors.brandGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Text(
                'Privacy checkup',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Take a quick guided tour of your privacy settings to make sure they\'re right for you.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _showComingSoon('Privacy checkup'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                ),
              ),
              child: const Text('Get started', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  /// A navigation tile with a count badge (e.g. "Devices  4"), matching
  /// Telegram's Devices row: title + count on one line, description below.
  Widget _deviceNavTile({
    required IconData icon,
    required String title,
    required int? count,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final card = KoraColors.cardFor(brightness);
    final border = KoraColors.borderFor(brightness);

    return _cardWrapper(
      card: card,
      border: border,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: KoraColors.purple, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(title,
                              style: TextStyle(
                                  color: textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
                        ),
                        if (count != null)
                          Text(
                            '$count',
                            style: const TextStyle(
                                color: KoraColors.purple, fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(color: textSecondary, fontSize: 12.5, height: 1.4)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
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
  }) {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final card = KoraColors.cardFor(brightness);
    final border = KoraColors.borderFor(brightness);

    return _cardWrapper(
      card: card,
      border: border,
      child: InkWell(
        onTap: () => _showVisibilityPicker(
          title: title,
          subtitle: null,
          current: current,
          onSelected: onSelected,
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: KoraColors.purple, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(color: textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: textSecondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  /// A simple navigation tile (no visibility picker, just tap → action).
  Widget _simpleNavTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final card = KoraColors.cardFor(brightness);
    final border = KoraColors.borderFor(brightness);

    return _cardWrapper(
      card: card,
      border: border,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: KoraColors.purple, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(color: textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: textSecondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  /// A switch tile for boolean settings.
  Widget _switchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isLongSubtitle,
  }) {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final card = KoraColors.cardFor(brightness);
    final border = KoraColors.borderFor(brightness);

    return _cardWrapper(
      card: card,
      border: border,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: KoraColors.purple, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: isLongSubtitle ? 12.5 : 13,
                      height: 1.4,
                    ),
                  ),
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

  /// Shared card wrapper.
  Widget _cardWrapper({
    required Color card,
    required Color border,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Container(
        decoration: BoxDecoration(
          color: card,
          border: Border(
            top: BorderSide(color: border, width: 0.5),
            bottom: BorderSide(color: border, width: 0.5),
          ),
        ),
        child: child,
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

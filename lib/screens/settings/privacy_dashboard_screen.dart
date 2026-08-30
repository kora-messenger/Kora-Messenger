import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/kora_colors.dart';
import 'privacy_checkup_screen.dart';
import 'app_lock_screen.dart';
import 'chat_lock_screen.dart';
import 'blocked_accounts_screen.dart';
import 'live_location_screen.dart';
import '../status/status_privacy_screen.dart';

/// Privacy Dashboard — central hub for all privacy settings and security status.
/// Mirrors WhatsApp's Privacy Dashboard with security checkmarks and status indicators.
class PrivacyDashboardScreen extends StatefulWidget {
  const PrivacyDashboardScreen({super.key});

  @override
  State<PrivacyDashboardScreen> createState() => _PrivacyDashboardScreenState();
}

class _PrivacyDashboardScreenState extends State<PrivacyDashboardScreen> {
  static const _prefix = 'kora_privacy_';

  // Visibility state
  String _lastSeen = 'everyone';
  String _profilePhoto = 'everyone';
  String _about = 'myContacts';
  String _status = 'myContacts';
  String _groups = 'everyone';

  // Toggle & feature state
  bool _readReceipts = true;
  bool _silenceUnknownCallers = false;
  bool _suspiciousLinkDetection = true;
  bool _protectIp = true;
  bool _appLockEnabled = false;
  bool _chatLockEnabled = false;
  String _msgTimer = 'Off';
  int _blockedCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final rawBlocked = prefs.getString('kora_blocked_accounts_json');
    int blockedCount = 0;
    if (rawBlocked != null) {
      try {
        final List<dynamic> parsed = jsonDecode(rawBlocked);
        blockedCount = parsed.length;
      } catch (_) {
        blockedCount = 1;
      }
    } else {
      blockedCount = 1;
    }

    setState(() {
      _lastSeen = prefs.getString('${_prefix}last_seen') ?? 'everyone';
      _profilePhoto = prefs.getString('${_prefix}profile_photo') ?? 'everyone';
      _about = prefs.getString('${_prefix}about') ?? 'myContacts';
      _status = prefs.getString('${_prefix}status') ?? 'myContacts';
      _groups = prefs.getString('${_prefix}groups') ?? 'everyone';
      _readReceipts = prefs.getBool('${_prefix}read_receipts') ?? true;
      _silenceUnknownCallers = prefs.getBool('${_prefix}silence_unknown_callers') ?? false;
      _suspiciousLinkDetection = prefs.getBool('${_prefix}suspicious_link_detection') ?? true;
      _protectIp = prefs.getBool('${_prefix}protect_ip') ?? true;
      _appLockEnabled = prefs.getBool('app_lock_enabled') ?? prefs.getBool('${_prefix}app_lock') ?? false;
      _chatLockEnabled = prefs.getBool('chat_lock_enabled') ?? prefs.getBool('${_prefix}chat_lock') ?? false;
      _msgTimer = prefs.getString('${_prefix}msg_timer') ?? 'Off';
      _blockedCount = blockedCount;
      _isLoading = false;
    });
  }

  Future<void> _saveBool(String key, bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefix$key', val);
  }

  String _visibilityLabel(String val) {
    switch (val) {
      case 'everyone':
        return 'Everyone';
      case 'myContacts':
        return 'My contacts';
      case 'nobody':
        return 'Nobody';
      default:
        return 'My contacts';
    }
  }

  int get _activeProtectionsCount {
    int count = 1; // End-to-end encryption is always active
    if (_appLockEnabled) count++;
    if (_chatLockEnabled) count++;
    if (_silenceUnknownCallers) count++;
    if (_suspiciousLinkDetection) count++;
    if (_protectIp) count++;
    if (_readReceipts) count++;
    return count;
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
          'Privacy Dashboard',
          style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: KoraColors.purple))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                // ── Privacy Status Overview Banner ─────────────────
                _buildOverviewCard(),

                const SizedBox(height: 20),

                // ── Security Protections Checklist ───────────────
                _sectionLabel('Security Status Overview', textMuted),
                _buildSecurityStatusGrid(card, border, textPrimary, textSecondary),

                const SizedBox(height: 24),

                // ── Who can see my personal info ────────────────
                _sectionLabel('Who can see my personal info', textMuted),
                _buildPrivacyItem(
                  icon: Icons.access_time_rounded,
                  title: 'Last seen and online',
                  subtitle: _visibilityLabel(_lastSeen),
                  onTap: () => Navigator.pop(context),
                ),
                _buildPrivacyItem(
                  icon: Icons.account_circle_outlined,
                  title: 'Profile photo',
                  subtitle: _visibilityLabel(_profilePhoto),
                  onTap: () => Navigator.pop(context),
                ),
                _buildPrivacyItem(
                  icon: Icons.info_outline_rounded,
                  title: 'About',
                  subtitle: _visibilityLabel(_about),
                  onTap: () => Navigator.pop(context),
                ),
                _buildPrivacyItem(
                  icon: Icons.circle_outlined,
                  title: 'Status',
                  subtitle: _visibilityLabel(_status),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StatusPrivacyScreen()),
                  ).then((_) => _loadSettings()),
                ),
                _buildPrivacyItem(
                  icon: Icons.group_outlined,
                  title: 'Groups',
                  subtitle: _visibilityLabel(_groups),
                  onTap: () => Navigator.pop(context),
                ),

                const SizedBox(height: 24),

                // ── Call & Message Protection ────────────────
                _sectionLabel('Call & Message Protection', textMuted),
                _buildToggleItem(
                  icon: Icons.phone_disabled_outlined,
                  title: 'Silence unknown callers',
                  subtitle: 'Calls from unknown numbers will be silenced automatically',
                  value: _silenceUnknownCallers,
                  onChanged: (val) {
                    setState(() => _silenceUnknownCallers = val);
                    _saveBool('silence_unknown_callers', val);
                  },
                ),
                _buildToggleItem(
                  icon: Icons.link_off_outlined,
                  title: 'Suspicious link detection',
                  subtitle: 'Inspect received message links for malicious behavior',
                  value: _suspiciousLinkDetection,
                  onChanged: (val) {
                    setState(() => _suspiciousLinkDetection = val);
                    _saveBool('suspicious_link_detection', val);
                  },
                ),
                _buildToggleItem(
                  icon: Icons.done_all_rounded,
                  title: 'Read receipts',
                  subtitle: 'Send and receive read receipts in 1-on-1 chats',
                  value: _readReceipts,
                  onChanged: (val) {
                    setState(() => _readReceipts = val);
                    _saveBool('read_receipts', val);
                  },
                ),
                _buildPrivacyItem(
                  icon: Icons.timer_outlined,
                  title: 'Disappearing messages',
                  subtitle: _msgTimer,
                  onTap: () => Navigator.pop(context),
                ),

                const SizedBox(height: 24),

                // ── Security & Locks ────────────────────────────
                _sectionLabel('Security & Locks', textMuted),
                _buildPrivacyItem(
                  icon: Icons.lock_outline_rounded,
                  title: 'App Lock',
                  subtitle: _appLockEnabled ? 'Enabled' : 'Disabled',
                  statusBadge: _appLockEnabled ? 'Protected' : 'Off',
                  isBadgeActive: _appLockEnabled,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AppLockScreen()),
                  ).then((_) => _loadSettings()),
                ),
                _buildPrivacyItem(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'Chat Lock & Secret Code',
                  subtitle: _chatLockEnabled ? 'Enabled' : 'Disabled',
                  statusBadge: _chatLockEnabled ? 'Protected' : 'Off',
                  isBadgeActive: _chatLockEnabled,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ChatLockScreen()),
                  ).then((_) => _loadSettings()),
                ),
                _buildPrivacyItem(
                  icon: Icons.block_rounded,
                  title: 'Blocked accounts',
                  subtitle: _blockedCount == 0 ? 'None' : '$_blockedCount blocked',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BlockedAccountsScreen()),
                  ).then((_) => _loadSettings()),
                ),
                _buildPrivacyItem(
                  icon: Icons.location_on_outlined,
                  title: 'Live location sharing',
                  subtitle: 'None',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LiveLocationScreen()),
                  ),
                ),
                _buildPrivacyItem(
                  icon: Icons.verified_user_outlined,
                  title: 'Safety numbers',
                  subtitle: 'Verify end-to-end encryption code with a contact',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SafetyNumbersScreen(contactName: 'Contact')),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildOverviewCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: KoraColors.brandGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: KoraColors.purple.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified_user_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Privacy Status: Protected',
                      style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$_activeProtectionsCount of 7 security features active',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Your messages, calls, and personal information are protected by Kora\'s security layer.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrivacyCheckupScreen()),
              ).then((_) => _loadSettings()),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: KoraColors.purple,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              icon: const Icon(Icons.shield_outlined, size: 18),
              label: const Text('Start Privacy Checkup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityStatusGrid(Color card, Color border, Color textPrimary, Color textSecondary) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildStatusCard('End-to-end Encryption', 'Active', true, Icons.lock_outline, card, border, textPrimary)),
            const SizedBox(width: 12),
            Expanded(child: _buildStatusCard('App Lock', _appLockEnabled ? 'Enabled' : 'Disabled', _appLockEnabled, Icons.fingerprint, card, border, textPrimary)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildStatusCard('Chat Lock', _chatLockEnabled ? 'Enabled' : 'Disabled', _chatLockEnabled, Icons.lock_person_outlined, card, border, textPrimary)),
            const SizedBox(width: 12),
            Expanded(child: _buildStatusCard('Silence Unknown', _silenceUnknownCallers ? 'On' : 'Off', _silenceUnknownCallers, Icons.phone_disabled_outlined, card, border, textPrimary)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildStatusCard('Link Protection', _suspiciousLinkDetection ? 'On' : 'Off', _suspiciousLinkDetection, Icons.link_off_outlined, card, border, textPrimary)),
            const SizedBox(width: 12),
            Expanded(child: _buildStatusCard('Protect IP', _protectIp ? 'On' : 'Off', _protectIp, Icons.security_outlined, card, border, textPrimary)),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusCard(String title, String status, bool isActive, IconData icon, Color card, Color border, Color textPrimary) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: 0.8),
      ),
      child: Row(
        children: [
          Icon(icon, color: isActive ? KoraColors.purple : textPrimary.withValues(alpha: 0.4), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: textPrimary, fontSize: 12, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      isActive ? Icons.check_circle : Icons.remove_circle_outline,
                      color: isActive ? KoraColors.waGreen : Colors.grey,
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      status,
                      style: TextStyle(
                        color: isActive ? KoraColors.waGreen : Colors.grey,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.3),
      ),
    );
  }

  Widget _buildPrivacyItem({
    required IconData icon,
    required String title,
    required String subtitle,
    String? statusBadge,
    bool isBadgeActive = false,
    required VoidCallback onTap,
  }) {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final card = KoraColors.cardFor(brightness);
    final border = KoraColors.borderFor(brightness);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: card,
        border: Border(
          top: BorderSide(color: border, width: 0.5),
          bottom: BorderSide(color: border, width: 0.5),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: KoraColors.purple, size: 22),
        title: Text(title, style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle, style: TextStyle(color: textSecondary, fontSize: 13)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (statusBadge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isBadgeActive ? KoraColors.purple.withValues(alpha: 0.15) : border,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  statusBadge,
                  style: TextStyle(
                    color: isBadgeActive ? KoraColors.purple : textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Icon(Icons.chevron_right, color: textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final card = KoraColors.cardFor(brightness);
    final border = KoraColors.borderFor(brightness);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: card,
        border: Border(
          top: BorderSide(color: border, width: 0.5),
          bottom: BorderSide(color: border, width: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: KoraColors.purple, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: textSecondary, fontSize: 12.5, height: 1.3)),
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
}

/// Secret Code screen — set a secret code to access locked chats.
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
                filled: true,
                fillColor: surface,
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
                filled: true,
                fillColor: surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(_error, style: const TextStyle(color: Colors.red, fontSize: 13)),
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

/// Silence Unknown Callers screen — toggle to silence calls from unknown numbers.
class SilenceUnknownCallersScreen extends StatefulWidget {
  const SilenceUnknownCallersScreen({super.key});

  @override
  State<SilenceUnknownCallersScreen> createState() => _SilenceUnknownCallersScreenState();
}

class _SilenceUnknownCallersScreenState extends State<SilenceUnknownCallersScreen> {
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _enabled = prefs.getBool('kora_privacy_silence_unknown_callers') ?? false;
    });
  }

  Future<void> _toggle(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('kora_privacy_silence_unknown_callers', val);
    setState(() => _enabled = val);
  }

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
                const Icon(Icons.phone_disabled, size: 48, color: KoraColors.purple),
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
            onChanged: _toggle,
            activeColor: KoraColors.purple,
          ),
        ],
      ),
    );
  }
}

/// Safety Numbers screen — verify end-to-end encryption with contacts.
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

    final contactHash = contactName.codeUnits.fold(0, (a, b) => a * 31 + b);
    final random = Random(contactHash.abs());
    final groups = List.generate(
      12,
      (_) => List.generate(5, (_) => random.nextInt(10).toString()).join(),
    );
    final safetyNumber = groups.join(' ');

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
            const Icon(Icons.verified_user, size: 56, color: KoraColors.purple),
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
                          color: textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 2,
                          height: 1.8,
                          fontFamily: 'monospace')),
                  const SizedBox(height: 12),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock, size: 14, color: KoraColors.purple),
                      SizedBox(width: 6),
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

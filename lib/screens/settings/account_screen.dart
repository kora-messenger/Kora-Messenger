import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import '../../services/session_manager.dart';
import '../../config/kora_api.dart';

/// Account settings screen — security, account details, and data management.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  Map<String, dynamic>? _session;
  bool _loading = true;
  bool _requestingInfo = false;
  bool _deletingAccount = false;
  bool _loggingOut = false;
  String _confirmDeleteText = '';

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final session = await SessionManager.instance.loadSession();
    if (mounted) {
      setState(() {
        _session = session;
        _loading = false;
      });
    }
  }

  // ── 3-dot menu actions ──────────────────────────────────────

  Future<void> _requestAccountInfo() async {
    if (_session == null) return;

    setState(() => _requestingInfo = true);

    try {
      final result = await KoraApi.post({
        'action': 'requestAccountInfo',
        'userId': _session!['id'],
        'email': _session!['email'],
      });

      if (!mounted) return;
      setState(() => _requestingInfo = false);

      if (result['success'] == true) {
        _showInfoDialog(result);
      } else {
        _showError(result['error'] as String? ?? 'Failed to retrieve account info.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _requestingInfo = false);
      _showError('Network error. Check your connection and try again.');
    }
  }

  void _showInfoDialog(Map<String, dynamic> data) {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final card = KoraColors.cardFor(brightness);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.download_done_rounded, color: KoraColors.purple, size: 24),
                    const SizedBox(width: 10),
                    Text(
                      'Your Account Info',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _infoRow('Name', _session!['fullName']?.toString() ?? 'N/A', textPrimary, textSecondary),
                _infoRow('Username', '@${_session!['username']?.toString() ?? 'N/A'}', textPrimary, textSecondary),
                _infoRow('Kora ID', _session!['koraId']?.toString() ?? 'N/A', textPrimary, textSecondary),
                _infoRow('Email', _session!['email']?.toString() ?? 'N/A', textPrimary, textSecondary),
                _infoRow('Account Created', data['accountCreated']?.toString() ?? 'N/A', textPrimary, textSecondary),
                _infoRow('Devices', data['deviceCount']?.toString() ?? '1', textPrimary, textSecondary),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: TextButton.styleFrom(
                      foregroundColor: KoraColors.purple,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, Color textPrimary, Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: TextStyle(color: textSecondary, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation() {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final card = KoraColors.cardFor(brightness);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
                    const SizedBox(width: 10),
                    Text(
                      'Delete Account?',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'This action is permanent and irreversible. Your profile, messages, premium features, and chat history will be permanently deleted.',
                  style: TextStyle(color: textSecondary, fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 12),
                Text(
                  'Type DELETE to confirm.',
                  style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                TextField(
                  autofocus: true,
                  style: TextStyle(color: textPrimary),
                  decoration: InputDecoration(
                    hintText: 'DELETE',
                    hintStyle: TextStyle(color: KoraColors.hintFor(brightness)),
                    filled: true,
                    fillColor: KoraColors.surfaceFor(brightness),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: KoraColors.borderFor(brightness)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red),
                    ),
                  ),
                  onChanged: (value) {
                    _confirmDeleteText = value;
                  },
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: TextButton.styleFrom(
                          foregroundColor: textSecondary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          if (_confirmDeleteText == 'DELETE') {
                            Navigator.pop(ctx);
                            _deleteAccount();
                          }
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteAccount() async {
    if (_session == null) return;

    setState(() => _deletingAccount = true);

    try {
      final result = await KoraApi.post({
        'action': 'deleteAccount',
        'userId': _session!['id'],
        'email': _session!['email'],
      });

      if (!mounted) return;

      if (result['success'] == true) {
        await SessionManager.instance.clearSession();

        if (!mounted) return;

        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      } else {
        setState(() => _deletingAccount = false);
        _showError(result['error'] as String? ?? 'Failed to delete account. Please try again.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _deletingAccount = false);
      _showError('Network error. Check your connection and try again.');
    }
  }

  // ── Logout ──────────────────────────────────────────────────

  Future<void> _logout() async {
    setState(() => _loggingOut = true);

    try {
      await SessionManager.instance.clearSession();

      if (!mounted) return;

      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loggingOut = false);
      _showError('Failed to log out. Please try again.');
    }
  }

  // ── Helpers ─────────────────────────────────────────────────

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature is coming soon.'),
        backgroundColor: KoraColors.purple,
        behavior: SnackBarBehavior.floating,
      ),
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
          'Account',
          style: TextStyle(
            color: textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: textPrimary),
            color: card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            onSelected: (value) {
              if (value == 'request_info') {
                _requestAccountInfo();
              } else if (value == 'delete') {
                _showDeleteConfirmation();
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem<String>(
                value: 'request_info',
                child: Row(
                  children: [
                    Icon(Icons.download_outlined, color: KoraColors.purple, size: 20),
                    const SizedBox(width: 12),
                    Text('Request Account Info',
                        style: TextStyle(color: textPrimary, fontSize: 14)),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: [
                    const Icon(Icons.delete_forever_outlined, color: Colors.red, size: 20),
                    const SizedBox(width: 12),
                    Text('Delete Account',
                        style: TextStyle(color: Colors.red.shade400, fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: KoraColors.purple))
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  // ── Account details card ──────────────────────
                  if (_session != null) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: card,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: border, width: 0.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  gradient: KoraColors.brandGradient,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Center(
                                  child: Text(
                                    (_session!['fullName']?.toString() ?? 'K')[0].toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _session!['fullName']?.toString() ?? 'Kora User',
                                      style: TextStyle(
                                        color: textPrimary,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '@${_session!['username']?.toString() ?? 'user'}',
                                      style: TextStyle(color: textSecondary, fontSize: 13.5),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      _session!['koraId']?.toString() ?? '',
                                      style: TextStyle(color: textMuted, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ── SECURITY section ───────────────────────────
                  _sectionLabel('SECURITY', textMuted),
                  _actionTile(
                    context,
                    icon: Icons.key_rounded,
                    iconColor: KoraColors.purple,
                    title: 'Passkeys',
                    subtitle: 'Passwordless sign-in with passkeys',
                    trailing: _buildToggle(false),
                    onTap: () => _showComingSoon('Passkeys'),
                  ),
                  _actionTile(
                    context,
                    icon: Icons.email_outlined,
                    iconColor: KoraColors.purple,
                    title: 'Email Address',
                    subtitle: _session?['email']?.toString() ?? 'N/A',
                    onTap: () => _showComingSoon('Email management'),
                    trailing: Icon(Icons.chevron_right, color: textMuted),
                  ),
                  _actionTile(
                    context,
                    icon: Icons.shield_outlined,
                    iconColor: KoraColors.purple,
                    title: '2FA Verification',
                    subtitle: 'Two-factor authentication for extra security',
                    trailing: _buildToggle(false),
                    onTap: () => _showComingSoon('2FA verification'),
                  ),
                  _actionTile(
                    context,
                    icon: Icons.notifications_active_outlined,
                    iconColor: KoraColors.purple,
                    title: 'Security Notifications',
                    subtitle: 'Alerts about suspicious activity',
                    trailing: _buildToggle(true),
                    onTap: () => _showComingSoon('Security notifications'),
                  ),

                  const SizedBox(height: 24),

                  // ── YOUR ACCOUNT section ───────────────────────
                  _sectionLabel('YOUR ACCOUNT', textMuted),
                  _actionTile(
                    context,
                    icon: Icons.alternate_email_rounded,
                    iconColor: KoraColors.purple,
                    title: '@ Username',
                    subtitle: '@${_session?['username']?.toString() ?? 'user'}',
                    onTap: () => _showComingSoon('Username editing'),
                    trailing: Icon(Icons.chevron_right, color: textMuted),
                  ),
                  _actionTile(
                    context,
                    icon: Icons.phone_outlined,
                    iconColor: KoraColors.purple,
                    title: 'Change Phone Number',
                    subtitle: _session?['phoneNumber']?.toString() ?? 'Not set',
                    onTap: () => _showComingSoon('Phone number change'),
                    trailing: Icon(Icons.chevron_right, color: textMuted),
                  ),

                  const SizedBox(height: 32),

                  // ── Logout button ─────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: _loggingOut ? null : _logout,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red.shade400,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: Colors.red.withValues(alpha: 0.3), width: 0.5),
                        ),
                      ),
                      child: _loggingOut
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.logout_rounded, size: 18),
                                const SizedBox(width: 8),
                                const Text('Log Out', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 20),

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
                            'Manage your security settings and account details here. Use the menu above to request account info or delete your account.',
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

  // ── Widgets ─────────────────────────────────────────────────

  Widget _buildToggle(bool value) {
    return Switch.adaptive(
      value: value,
      onChanged: (v) {
        // Coming soon — just show the snackbar
        _showComingSoon('This setting');
      },
      activeColor: KoraColors.purple,
    );
  }

  Widget _sectionLabel(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _actionTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Color? titleColor,
    Widget? trailing,
  }) {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final card = KoraColors.cardFor(brightness);
    final border = KoraColors.borderFor(brightness);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
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
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: titleColor ?? textPrimary,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(color: textSecondary, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        ),
      ),
    );
  }
}

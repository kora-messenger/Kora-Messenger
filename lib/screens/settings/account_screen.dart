import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import '../../services/session_manager.dart';
import '../../config/kora_api.dart';
import 'passkeys_screen.dart';
import 'two_factor_screen.dart';
import 'security_notifications_screen.dart';
import 'email_address_screen.dart';

/// Account settings screen — security shortcuts and account details.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  Map<String, dynamic>? _session;
  bool _loading = true;
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

    try {
      final result = await KoraApi.post({
        'action': 'requestAccountInfo',
        'userId': _session!['id'],
        'email': _session!['email'],
      });

      if (!mounted) return;

      if (result['success'] == true) {
        _showInfoDialog(result);
      } else {
        _showError(result['error'] as String? ?? 'Failed to retrieve account info.');
      }
    } catch (e) {
      if (!mounted) return;
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
        _showError(result['error'] as String? ?? 'Failed to delete account. Please try again.');
      }
    } catch (e) {
      if (!mounted) return;
      _showError('Network error. Check your connection and try again.');
    }
  }

  // ── Logout ──────────────────────────────────────────────────

  Future<void> _logout() async {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final card = KoraColors.cardFor(brightness);

    // 1. Show confirmation dialog asking 'Log out of this device?'
    final confirm = await showDialog<bool>(
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
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: KoraColors.purple.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: KoraColors.purple,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Log out of this device?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'You will need to sign in again to access your messages and account settings.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: TextButton.styleFrom(
                          foregroundColor: textSecondary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: KoraColors.borderFor(brightness)),
                          ),
                        ),
                        child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: KoraColors.purple,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.w700)),
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

    // 2. If user taps Cancel, do nothing
    if (confirm != true) return;

    if (!mounted) return;

    // Set loading state
    setState(() => _loggingOut = true);

    // 3. Show loading dialog / overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (loadingCtx) => Dialog(
        backgroundColor: card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: KoraColors.purple,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Logging out...',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      // Get deviceId and deviceName from SharedPreferences (fallback: 'Unknown Device')
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('kora_device_id') ?? 'Unknown Device';
      final deviceName = prefs.getString('kora_device_name') ?? 'Unknown Device';

      final email = _session?['email']?.toString() ?? '';
      final userId = _session?['id']?.toString() ?? '';

      // 4. Call backend API (KoraApi.post) with action 'logout'
      await KoraApi.post({
        'action': 'logout',
        'email': email,
        'userId': userId,
        'deviceId': deviceId,
        'deviceName': deviceName,
      });
    } catch (e) {
      // Continue clearing session locally even if network fails
    }

    try {
      await SessionManager.instance.clearSession();
    } catch (e) {
      // Ignore local clear errors
    }

    if (!mounted) return;

    // Pop the loading dialog
    Navigator.of(context, rootNavigator: true).pop();

    setState(() => _loggingOut = false);

    // 5. Show success popup dialog with checkmark icon and OK button
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (successCtx) => Dialog(
        backgroundColor: card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: KoraColors.purple.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: KoraColors.purple,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'You have been logged out successfully',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(successCtx).pop();
                      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: KoraColors.purple,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Navigation ────────────────────────────────────────────────

  void _openPasskeys() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const PasskeysScreen()));
  }

  void _openTwoFactor() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const TwoFactorScreen()));
  }

  void _openSecurityNotifications() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const SecurityNotificationsScreen()));
  }

  Future<void> _openAddEmail() async {
    if (_session == null) return;

    final userId = _session!['id']?.toString();
    if (userId == null) return;

    final currentEmail = _session?['email']?.toString() ?? '';
    final isVerified = _session?['isVerified'] == true;

    final newEmail = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => EmailAddressScreen(
          userId: userId,
          email: currentEmail,
          isVerified: isVerified,
        ),
      ),
    );

    if (newEmail != null && mounted) {
      setState(() {
        _session = {..._session!, 'email': newEmail};
      });
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
                  // ── SECURITY section ───────────────────────────
                  _sectionLabel('SECURITY', textMuted),
                  _actionTile(
                    context,
                    icon: Icons.key_rounded,
                    iconColor: KoraColors.purple,
                    title: 'Passkeys',
                    subtitle: 'Passwordless sign-in with passkeys',
                    onTap: _openPasskeys,
                    trailing: Icon(Icons.chevron_right, color: textMuted),
                  ),
                  _actionTile(
                    context,
                    icon: Icons.email_outlined,
                    iconColor: KoraColors.purple,
                    title: 'Email Address',
                    subtitle: _session?['email']?.toString() ?? 'N/A',
                    onTap: _openAddEmail,
                    trailing: Icon(Icons.chevron_right, color: textMuted),
                  ),
                  _actionTile(
                    context,
                    icon: Icons.shield_outlined,
                    iconColor: KoraColors.purple,
                    title: '2FA Verification',
                    subtitle: 'Two-factor authentication for extra security',
                    onTap: _openTwoFactor,
                    trailing: Icon(Icons.chevron_right, color: textMuted),
                  ),
                  _actionTile(
                    context,
                    icon: Icons.notifications_active_outlined,
                    iconColor: KoraColors.purple,
                    title: 'Security Notifications',
                    subtitle: 'Alerts about suspicious activity',
                    onTap: _openSecurityNotifications,
                    trailing: Icon(Icons.chevron_right, color: textMuted),
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

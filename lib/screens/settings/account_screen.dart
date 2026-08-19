import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import '../../services/session_manager.dart';
import '../../config/kora_api.dart';

/// Account settings screen — request account info, delete account,
/// and view account details.
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

  String _confirmDeleteText = '';

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
        // Clear local session
        await SessionManager.instance.clearSession();

        if (!mounted) return;

        // Navigate to welcome screen, removing all previous routes
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade800,
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
                          const SizedBox(height: 16),
                          Divider(color: border, height: 1),
                          const SizedBox(height: 14),
                          _detailRow(Icons.email_outlined, _session!['email']?.toString() ?? 'N/A', textPrimary, textSecondary),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ── DATA section ──────────────────────────────
                  _sectionLabel('DATA', textMuted),
                  _actionTile(
                    context,
                    icon: Icons.download_outlined,
                    iconColor: KoraColors.purple,
                    title: 'Request Account Info',
                    subtitle: 'Download a copy of your account data',
                    onTap: _requestingInfo ? null : _requestAccountInfo,
                    trailing: _requestingInfo
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: KoraColors.purple))
                        : Icon(Icons.chevron_right, color: textMuted),
                  ),

                  const SizedBox(height: 24),

                  // ── DANGER section ─────────────────────────────
                  _sectionLabel('DANGER ZONE', textMuted),
                  _actionTile(
                    context,
                    icon: Icons.delete_forever_outlined,
                    iconColor: Colors.red,
                    title: 'Delete Account',
                    subtitle: 'Permanently erase your account and all data',
                    onTap: _deletingAccount ? null : _showDeleteConfirmation,
                    titleColor: Colors.red,
                    trailing: _deletingAccount
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
                        : Icon(Icons.chevron_right, color: textMuted),
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
                            'Account deletion is permanent and irreversible. Your profile, messages, and premium features cannot be recovered once deleted.',
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

  Widget _detailRow(IconData icon, String value, Color textPrimary, Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(value, style: TextStyle(color: textPrimary, fontSize: 14)),
          ),
        ],
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

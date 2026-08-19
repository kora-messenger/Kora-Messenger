import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../../theme/kora_colors.dart';
import '../../services/auth_service.dart';
import '../../services/session_manager.dart';
import '../passkey_learn_more_screen.dart';

/// Passkeys settings screen — create, list, and delete device passkeys.
///
/// Flow when adding a passkey:
///   1. User taps "Add a Passkey"
///   2. A 3-second loading dialog appears at center of screen
///   3. After loading, a bottom sheet shows the user's phone number (if
///      they added one) or their email — this is the "passkey identity"
///   4. Tapping that identity triggers the device biometric/PIN prompt
///   5. On success → "Passkey created" popup, passkey is saved to backend
///   6. On failure → error message
class PasskeysScreen extends StatefulWidget {
  const PasskeysScreen({super.key});

  @override
  State<PasskeysScreen> createState() => _PasskeysScreenState();
}

class _PasskeysScreenState extends State<PasskeysScreen> {
  final _auth = AuthService.instance;
  final _localAuth = LocalAuthentication();

  bool _enabled = false;
  bool _loading = false;
  String? _userEmail;
  String? _userPhone;
  List<Map<String, dynamic>> _passkeys = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final session = await SessionManager.instance.loadSession();
    if (session != null) {
      setState(() {
        _userEmail = session['email']?.toString();
        _userPhone = session['phoneNumber']?.toString();
      });
      // Check if passkeys are already enabled
      if (_userEmail != null && _userEmail!.isNotEmpty) {
        final result = await _auth.listPasskeys(email: _userEmail!);
        if (mounted) {
          setState(() {
            _passkeys = result.passkeys;
            _enabled = result.passkeys.isNotEmpty;
          });
        }
      }
    }
  }

  // ── Add Passkey flow ──────────────────────────────────────

  Future<void> _addPasskey() async {
    if (_userEmail == null || _userEmail!.isEmpty) {
      _showError('Could not find your account. Please restart the app.');
      return;
    }

    // Step 1: Show loading dialog for 3 seconds
    setState(() => _loading = true);
    _showLoadingDialog();

    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    // Dismiss the loading dialog
    Navigator.of(context).pop();

    // Step 2: Show the identity sheet (phone or email)
    _showIdentitySheet();
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (dialogContext) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            backgroundColor: KoraColors.darkCard,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    color: KoraColors.purple,
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Setting up Passkey...',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Preparing secure enrollment',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showIdentitySheet() {
    final identity = (_userPhone != null && _userPhone!.isNotEmpty)
        ? _userPhone
        : _userEmail;
    final isPhone = _userPhone != null && _userPhone!.isNotEmpty;

    showModalBottomSheet(
      context: context,
      backgroundColor: KoraColors.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3A3A4E),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: KoraColors.brandGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.fingerprint, color: Colors.white, size: 28),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Confirm your identity',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tap below to authenticate with your device biometric or PIN.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFFA0A0B8), fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 24),
                // Tappable identity card
                GestureDetector(
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _triggerBiometric();
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: KoraColors.darkSurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: KoraColors.purple.withValues(alpha: 0.3), width: 1),
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
                          child: Icon(
                            isPhone ? Icons.phone_rounded : Icons.email_rounded,
                            color: KoraColors.purple,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isPhone ? 'Phone Number' : 'Email',
                                style: const TextStyle(color: Color(0xFFA0A0B8), fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                identity ?? '',
                                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Color(0xFF6B6B80), size: 22),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Color(0xFFA0A0B8), fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _triggerBiometric() async {
    try {
      final available = await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();

      if (!available) {
        _showError('Biometric authentication is not available on this device.');
        return;
      }

      final didAuth = await _localAuth.authenticate(
        localizedReason: 'Authenticate to create a Passkey for Kora',
        options: const AuthenticationOptions(
          biometricOnly: false,
        ),
      );

      if (!mounted) return;

      if (didAuth) {
        // Biometric succeeded → create passkey on backend
        final result = await _auth.createPasskey(email: _userEmail!);

        if (!mounted) return;

        if (result.success) {
          setState(() {
            _enabled = true;
            _loading = false;
          });
          // Refresh passkey list
          _refreshPasskeys();
          _showSuccessPopup('Passkey created');
        } else {
          setState(() => _loading = false);
          _showError(result.error ?? 'Failed to create passkey');
        }
      } else {
        setState(() => _loading = false);
        _showError('Authentication failed. Please try again.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showError('Authentication error. Please try again.');
      }
    }
  }

  Future<void> _refreshPasskeys() async {
    if (_userEmail == null) return;
    final result = await _auth.listPasskeys(email: _userEmail!);
    if (mounted) {
      setState(() {
        _passkeys = result.passkeys;
        _enabled = result.passkeys.isNotEmpty;
      });
    }
  }

  // ── Toggle passkeys on/off ──────────────────────────────

  Future<void> _togglePasskeys(bool value) async {
    if (_userEmail == null) return;

    if (value && _passkeys.isEmpty) {
      // Turning on but no passkeys yet → start the add flow
      _addPasskey();
      return;
    }

    if (!value) {
      // Turning off → need to confirm, then disable
      final confirmed = await _showConfirmDialog(
        title: 'Turn off Passkeys?',
        message: 'You won\'t be able to sign in with your device biometrics. Your password will still work.',
        confirmText: 'Turn Off',
      );
      if (confirmed) {
        final result = await _auth.setPasskeysEnabled(email: _userEmail!, enabled: false);
        if (result.success) {
          setState(() => _enabled = false);
        }
      } else {
        // Revert the switch
        setState(() {});
      }
    } else {
      final result = await _auth.setPasskeysEnabled(email: _userEmail!, enabled: true);
      if (result.success) {
        setState(() => _enabled = true);
      }
    }
  }

  // ── Delete Passkey ────────────────────────────────────────

  void _showDeleteOption(String passkeyId, String deviceName, String createdAt) {
    showModalBottomSheet(
      context: context,
      backgroundColor: KoraColors.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: const Color(0xFF3A3A4E), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
              ),
              title: const Text('Delete', style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _confirmDelete(passkeyId, deviceName);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(String passkeyId, String deviceName) async {
    final confirmed = await _showConfirmDialog(
      title: 'Delete this Passkey?',
      message: 'You will no longer be able to sign in with $deviceName using biometrics. Your password will still work as a backup.',
      confirmText: 'Delete',
      isDestructive: true,
    );

    if (confirmed && _userEmail != null) {
      final result = await _auth.deletePasskey(email: _userEmail!, passkeyId: passkeyId);
      if (mounted) {
        if (result.success) {
          _showSuccessPopup('Passkey deleted');
          _refreshPasskeys();
        } else {
          _showError(result.error ?? 'Failed to delete passkey');
        }
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────

  Future<bool> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmText,
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: KoraColors.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
        content: Text(message, style: const TextStyle(color: Color(0xFFA0A0B8), fontSize: 14, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFFA0A0B8), fontSize: 15, fontWeight: FontWeight.w500)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              confirmText,
              style: TextStyle(
                color: isDestructive ? Colors.red : KoraColors.purple,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showSuccessPopup(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final nav = Navigator.of(dialogContext);
        Future.delayed(const Duration(seconds: 2), () {
          if (nav.canPop()) {
            nav.pop();
          }
        });
        return AlertDialog(
          backgroundColor: KoraColors.darkCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: KoraColors.purple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.check_circle, color: KoraColors.purple, size: 30),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatDate(String? createdAt) {
    if (createdAt == null || createdAt.isEmpty) return 'Unknown date';
    try {
      final dt = DateTime.parse(createdAt);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return 'Unknown date';
    }
  }

  String _platformIcon(String platform) {
    if (platform.toLowerCase().contains('ios')) return 'iOS';
    if (platform.toLowerCase().contains('android')) return 'Android';
    return platform.isNotEmpty ? platform : 'Device';
  }

  // ── Build ─────────────────────────────────────────────────

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
          'Passkeys',
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
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: KoraColors.brandGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.key_rounded, color: Colors.white, size: 34),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Sign in without a password',
              textAlign: TextAlign.center,
              style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Use Face ID, your fingerprint, or your device PIN to sign in to Kora instantly and securely — no password needed.',
              textAlign: TextAlign.center,
              style: TextStyle(color: textSecondary, fontSize: 13.5, height: 1.5),
            ),
            const SizedBox(height: 28),

            // ── Toggle ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: border, width: 0.5),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: KoraColors.purple.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.key_rounded, color: KoraColors.purple, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Use Passkeys',
                            style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 3),
                        Text(_enabled ? 'Enabled' : 'Disabled',
                            style: TextStyle(color: textSecondary, fontSize: 12.5)),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: _enabled,
                    activeTrackColor: KoraColors.purple,
                    onChanged: (v) => _togglePasskeys(v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Passkey list ──
            if (_enabled) ...[
              Text(
                'YOUR PASSKEYS',
                style: TextStyle(color: textMuted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5),
              ),
              const SizedBox(height: 10),
              if (_passkeys.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: border, width: 0.5),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.fingerprint, color: textMuted, size: 28),
                      const SizedBox(height: 10),
                      Text('No passkeys added yet',
                          style: TextStyle(color: textSecondary, fontSize: 13.5)),
                    ],
                  ),
                )
              else
                ..._passkeys.map((p) => _passkeyCard(p, card, border, textPrimary, textSecondary, textMuted)),

              const SizedBox(height: 16),
              if (_passkeys.isEmpty)
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: _loading ? null : _addPasskey,
                    style: TextButton.styleFrom(
                      foregroundColor: KoraColors.purple,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: KoraColors.purple, width: 1),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Add a Passkey', style: TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 20),
            ],

            // ── Description + Learn more ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: KoraColors.purple.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: KoraColors.purple.withValues(alpha: 0.2), width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: KoraColors.purple, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Passkeys are stored securely on your device and never leave it. Your password still works as a backup sign-in method.',
                          style: TextStyle(color: textSecondary, fontSize: 12.5, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const PasskeyLearnMoreScreen()),
                        );
                      },
                      child: Text(
                        'Learn more',
                        style: TextStyle(
                          color: KoraColors.purple,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
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

  Widget _passkeyCard(Map<String, dynamic> p, Color card, Color border, Color textPrimary, Color textSecondary, Color textMuted) {
    final deviceName = p['deviceName']?.toString() ?? 'Unknown Device';
    final createdAt = p['createdAt']?.toString();
    final platform = p['platform']?.toString() ?? '';
    final passkeyId = p['id']?.toString() ?? '';

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
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: KoraColors.purple.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.fingerprint, color: KoraColors.purple, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(deviceName,
                      style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(
                    'Created ${_formatDate(createdAt)} · ${_platformIcon(platform)}',
                    style: TextStyle(color: textMuted, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            // 3-dot menu
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: textSecondary, size: 22),
              color: KoraColors.darkCard,
              onSelected: (value) {
                if (value == 'delete') {
                  _showDeleteOption(passkeyId, deviceName, createdAt ?? '');
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: Colors.red, size: 20),
                      SizedBox(width: 10),
                      Text('Delete', style: TextStyle(color: Colors.red, fontSize: 15)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

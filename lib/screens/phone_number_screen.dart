import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/kora_colors.dart';
import '../theme/chat_theme_provider.dart';
import '../services/auth_service.dart';
import '../services/session_manager.dart';
import '../services/chat_sync_service.dart';
import '../widgets/kora_button.dart';
import 'profile_setup_screen.dart';

/// Optional phone number step — shown after email verification, before
/// profile setup. The user can enter their phone number or skip entirely.
class PhoneNumberScreen extends StatefulWidget {
  final String email;
  final Map<String, dynamic>? userData;

  const PhoneNumberScreen({
    super.key,
    required this.email,
    this.userData,
  });

  @override
  State<PhoneNumberScreen> createState() => _PhoneNumberScreenState();
}

class _PhoneNumberScreenState extends State<PhoneNumberScreen> {
  final _phoneController = TextEditingController();
  final _auth = AuthService.instance;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _continue({bool skip = false}) async {
    final phone = skip ? '' : _phoneController.text.trim();

    if (!skip && phone.isNotEmpty) {
      final cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
      if (!RegExp(r'^\+?\d{7,15}$').hasMatch(cleaned)) {
        setState(() => _errorMessage = 'Enter a valid phone number');
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (!skip && phone.isNotEmpty) {
      final userId = widget.userData?['id']?.toString() ?? '';
      if (userId.isNotEmpty) {
        final result = await _auth.savePhoneNumber(
          userId: userId,
          phoneNumber: phone,
        );
        if (result.success && result.user != null) {
          await SessionManager.instance.saveSession(result.user!);
          await ChatThemeProvider.instance.load();
        // Set user email for cloud chat sync
        final session = await SessionManager.instance.loadSession();
        if (session != null && session['email'] != null) {
          ChatSyncService.instance.setUserEmail(session['email'] as String);
        } // Refresh owner/premium status for badge + gating
        }
      }
    }

    if (!mounted) return;
    _navigateNext(phone: skip ? '' : _phoneController.text.trim());
  }

  void _navigateNext({required String phone}) {
    final userData = Map<String, dynamic>.from(widget.userData ?? {});
    userData['phoneNumber'] = phone;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ProfileSetupScreen(
          email: widget.email,
          userData: userData,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final card = KoraColors.cardFor(brightness);
    final border = KoraColors.borderFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          'Phone Number',
          style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          gradient: KoraColors.brandGradient,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.phone_rounded, color: Colors.white, size: 34),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Add your phone number',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This is optional. Adding a phone number helps with account recovery and lets contacts find you on Kora.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: textSecondary, fontSize: 14, height: 1.5),
                    ),
                    const SizedBox(height: 32),
                    Container(
                      decoration: BoxDecoration(
                        color: card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: border, width: 0.5),
                      ),
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(20),
                        ],
                        style: TextStyle(color: textPrimary, fontSize: 16),
                        decoration: InputDecoration(
                          hintText: '+1 234 567 890',
                          hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.5), fontSize: 16),
                          prefixIcon: Icon(Icons.phone_outlined, color: textSecondary, size: 22),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                      ),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      "We won't share your phone number with anyone without your permission.",
                      style: TextStyle(color: textSecondary.withValues(alpha: 0.7), fontSize: 12.5, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              decoration: BoxDecoration(
                color: bg,
                border: Border(top: BorderSide(color: border, width: 0.5)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  KoraButton(
                    label: 'Continue',
                    isLoading: _isLoading,
                    onPressed: () => _continue(),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _isLoading ? null : () => _continue(skip: true),
                    child: Text(
                      'Skip for now',
                      style: TextStyle(color: textSecondary, fontSize: 15, fontWeight: FontWeight.w500),
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
}

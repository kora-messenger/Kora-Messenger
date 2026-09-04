import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../../services/session_manager.dart';
import '../../theme/kora_colors.dart';

/// 2-step phone number change screen: enter new number -> auto-verify code.
class PhoneNumberChangeScreen extends StatefulWidget {
  const PhoneNumberChangeScreen({super.key});

  @override
  State<PhoneNumberChangeScreen> createState() => _PhoneNumberChangeScreenState();
}

class _PhoneNumberChangeScreenState extends State<PhoneNumberChangeScreen> {
  int _step = 1; // 1: enter number, 2: verify code
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  String? _phoneError;
  String? _codeError;
  bool _isVerifying = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _submitPhoneNumber() async {
    final phone = _phoneController.text.trim();
    if (phone.length < 7) {
      setState(() => _phoneError = 'Please enter a valid phone number');
      return;
    }
    setState(() {
      _phoneError = null;
      _isVerifying = true;
    });

    // Send a real verification code to the account's email address.
    final email = SessionManager.instance.currentEmail;
    final result = await AuthService().sendVerificationCode(email, type: 'phone_change');
    if (!mounted) return;
    if (result.success) {
      setState(() {
        _isVerifying = false;
        _step = 2;
      });
    } else {
      setState(() {
        _isVerifying = false;
        _phoneError = result.error ?? 'Could not send the code. Try again.';
      });
    }
  }

  void _onCodeChanged(String val) async {
    if (val.length == 6) {
      setState(() => _isVerifying = true);
      final email = SessionManager.instance.currentEmail;
      final auth = AuthService();
      final verify = await auth.verifyCode(email: email, code: val, type: 'phone_change');

      if (verify.success) {
        final user = SessionManager.instance.currentUser;
        final save = await auth.savePhoneNumber(
          userId: user?.id ?? '', phoneNumber: _phoneController.text.trim());
        if (!mounted) return;
        if (save.success) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('kora_phone_number', _phoneController.text.trim());
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Phone number changed successfully!')),
            );
            Navigator.pop(context, _phoneController.text.trim());
          }
        } else {
          setState(() {
            _isVerifying = false;
            _codeError = save.error ?? 'Could not save the new number. Try again.';
          });
        }
      } else {
        setState(() {
          _isVerifying = false;
          _codeError = 'Invalid code. Try again';
        });
      }
    } else {
      if (_codeError != null) {
        setState(() => _codeError = null);
      }
    }
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
          'Change number',
          style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () {
            if (_step == 2) {
              setState(() => _step = 1);
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _step == 1
            ? _buildStep1(card, border, textPrimary, textSecondary)
            : _buildStep2(card, border, textPrimary, textSecondary),
      ),
    );
  }

  Widget _buildStep1(Color card, Color border, Color textPrimary, Color textSecondary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Enter your new phone number',
          style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Changing your phone number will migrate your account info, groups & settings.',
          style: TextStyle(color: textSecondary, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          style: TextStyle(color: textPrimary, fontSize: 16),
          decoration: InputDecoration(
            labelText: 'New phone number',
            labelStyle: TextStyle(color: textSecondary),
            hintText: '+1 555 019 2834',
            hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.5)),
            errorText: _phoneError,
            filled: true,
            fillColor: card,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: KoraColors.purple, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: KoraColors.purple,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
            onPressed: _submitPhoneNumber,
            child: const Text('Next', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2(Color card, Color border, Color textPrimary, Color textSecondary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Verify phone number',
          style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter the 6-digit code we sent to ${SessionManager.instance.currentEmail}. Wrong number?',
          style: TextStyle(color: textSecondary, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          onChanged: _onCodeChanged,
          style: TextStyle(color: textPrimary, fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: '000000',
            hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.3), letterSpacing: 8),
            errorText: _codeError,
            counterText: '',
            filled: true,
            fillColor: card,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: KoraColors.purple, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (_isVerifying)
          const Center(
            child: Column(
              children: [
                CircularProgressIndicator(color: KoraColors.purple),
                SizedBox(height: 12),
                Text('Verifying code...', style: TextStyle(color: KoraColors.purple)),
              ],
            ),
          ),
      ],
    );
  }
}

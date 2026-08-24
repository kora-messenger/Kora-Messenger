import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import 'add_email_screen.dart';

/// "Email address" screen — the summary view shown when the user taps
/// Email Address from Account settings. Shows the current email plus
/// a verified badge. Tapping the edit pencil opens [AddEmailScreen] to
/// change it.
///
/// Mirrors the reference design (WhatsApp-style) themed with Kora's
/// purple-to-blue brand identity.
class EmailAddressScreen extends StatefulWidget {
  final String userId;
  final String email;
  final bool isVerified;

  const EmailAddressScreen({
    super.key,
    required this.userId,
    required this.email,
    this.isVerified = true,
  });

  @override
  State<EmailAddressScreen> createState() => _EmailAddressScreenState();
}

class _EmailAddressScreenState extends State<EmailAddressScreen> {
  late String _email = widget.email;
  late bool _isVerified = widget.isVerified;

  Future<void> _openEditEmail() async {
    final newEmail = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => AddEmailScreen(
          userId: widget.userId,
          currentEmail: _email,
        ),
      ),
    );

    if (newEmail != null && mounted) {
      setState(() {
        _email = newEmail;
        _isVerified = true; // freshly confirmed via code verification
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.of(context).pop(_email),
        ),
        title: Text(
          'Email address',
          style: TextStyle(
            color: textPrimary,
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              RichText(
                text: TextSpan(
                  style: TextStyle(color: textSecondary, fontSize: 14.5, height: 1.5),
                  children: [
                    const TextSpan(
                      text: 'Email helps us verify your account or reach you in '
                          'case of security or support issues. Your email address '
                          "won't be visible to others. ",
                    ),
                    TextSpan(
                      text: 'Learn more',
                      style: TextStyle(
                        color: KoraColors.purple,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Email',
                style: TextStyle(
                  color: textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _email,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: _openEditEmail,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(Icons.edit_outlined, size: 20, color: textMuted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_isVerified)
                Row(
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF22C55E),
                      ),
                      child: const Icon(Icons.check, size: 12, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Verified',
                      style: TextStyle(
                        color: Color(0xFF22C55E),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Icon(Icons.error_outline, size: 18, color: textMuted),
                    const SizedBox(width: 8),
                    Text(
                      'Not verified',
                      style: TextStyle(
                        color: textMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

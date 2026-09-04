import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../config/kora_api.dart';
import '../theme/kora_colors.dart';

/// Suspension screen — shown when a user's account has been suspended
/// by the automated detection system for violating Community Guidelines.
///
/// Displays the reason, time remaining, and an appeal button.
/// The user is locked out of the app until the suspension expires
/// or an appeal is approved by the Kora owner.
class SuspensionScreen extends StatefulWidget {
  final String email;
  final String suspensionReason;
  final bool isPermanent;
  final String? expiresAt;
  final int? hoursRemaining;
  final String appealStatus; // 'none', 'pending', 'approved', 'denied'

  const SuspensionScreen({
    super.key,
    required this.email,
    required this.suspensionReason,
    this.isPermanent = false,
    this.expiresAt,
    this.hoursRemaining,
    this.appealStatus = 'none',
  });

  @override
  State<SuspensionScreen> createState() => _SuspensionScreenState();
}

class _SuspensionScreenState extends State<SuspensionScreen> {
  bool _isSubmittingAppeal = false;
  bool _appealSubmitted = false;
  String? _appealError;
  final _appealController = TextEditingController();

  @override
  void dispose() {
    _appealController.dispose();
    super.dispose();
  }

  String _formatTimeRemaining() {
    if (widget.isPermanent) return 'Permanent';

    final hours = widget.hoursRemaining ?? 0;
    if (hours <= 0) return 'Expiring soon';

    if (hours >= 24) {
      final days = hours ~/ 24;
      final remainingHours = hours % 24;
      if (remainingHours == 0) return '$days day${days > 1 ? 's' : ''} remaining';
      return '$days day${days > 1 ? 's' : ''} $remainingHours hr remaining';
    }
    return '$hours hour${hours > 1 ? 's' : ''} remaining';
  }

  Future<void> _submitAppeal() async {
    if (_appealController.text.trim().isEmpty) {
      setState(() => _appealError = 'Please enter a message explaining why you believe this suspension is incorrect.');
      return;
    }

    setState(() {
      _isSubmittingAppeal = true;
      _appealError = null;
    });

    try {
      final response = await http.post(
        Uri.parse(KoraApi.autoDetectEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'submitAppeal',
          'email': widget.email,
          'appealMessage': _appealController.text.trim(),
        }),
      );

      final data = jsonDecode(response.body);

      if (mounted) {
        if (data['success'] == true) {
          setState(() {
            _appealSubmitted = true;
            _isSubmittingAppeal = false;
          });
        } else {
          setState(() {
            _appealError = data['error'] ?? 'Failed to submit appeal. Please try again.';
            _isSubmittingAppeal = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _appealError = 'Network error. Please check your connection and try again.';
          _isSubmittingAppeal = false;
        });
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

    final showAppealPending = widget.appealStatus == 'pending' || _appealSubmitted;
    final showAppealDenied = widget.appealStatus == 'denied';

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Column(
              children: [
                const SizedBox(height: 40),

                // Suspension icon
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.gpp_maybe_outlined,
                    size: 52,
                    color: Color(0xFFEF4444),
                  ),
                ),
                const SizedBox(height: 28),

                // Title
                Text(
                  "This account can't use Kora",
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),

                // Subtitle — community guidelines violation
                Text(
                  "Some activity on your account may not have followed our Terms of Service.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 15,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 28),

                // Suspension details card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: border, width: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Reason
                      Text(
                        'Reason',
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.suspensionReason,
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 14.5,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Duration
                      Row(
                        children: [
                          Icon(Icons.schedule_outlined, size: 18, color: textSecondary),
                          const SizedBox(width: 8),
                          Text(
                            'Duration',
                            style: TextStyle(color: textSecondary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                          ),
                          const Spacer(),
                          Text(
                            _formatTimeRemaining(),
                            style: TextStyle(
                              color: widget.isPermanent ? const Color(0xFFEF4444) : KoraColors.purple,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      if (!widget.isPermanent) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: KoraColors.purple.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, size: 16, color: KoraColors.purple),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "You'll be able to use Kora soon.",
                                  style: TextStyle(
                                    color: textSecondary,
                                    fontSize: 12.5,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Appeal section
                if (showAppealPending) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: KoraColors.purple.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: KoraColors.purple.withValues(alpha: 0.2), width: 0.5),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.hourglass_top_rounded, size: 36, color: KoraColors.purple),
                        const SizedBox(height: 12),
                        Text(
                          'Appeal Submitted',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your review request has been received. Most reviews are completed within 24 hours.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 14,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (showAppealDenied) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.2), width: 0.5),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.close_rounded, size: 36, color: const Color(0xFFEF4444)),
                        const SizedBox(height: 12),
                        Text(
                          'Appeal Denied',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.isPermanent
                              ? "We've completed your review and found this account's activity did not follow our terms of service."
                              : "We've completed your review and found this account's activity did not follow our terms of service.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 14,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Appeal form
                  Text(
                    'You can request a review if you think there has been a mistake.',
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _appealController,
                    maxLines: 4,
                    style: TextStyle(color: textPrimary, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Tell us why you believe this suspension is incorrect...',
                      hintStyle: TextStyle(color: textSecondary, fontSize: 14),
                      filled: true,
                      fillColor: card,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: border, width: 0.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: border, width: 0.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: KoraColors.purple, width: 1),
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                  if (_appealError != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _appealError!,
                      style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Appeal button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSubmittingAppeal ? null : _submitAppeal,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: KoraColors.purple,
                        disabledBackgroundColor: KoraColors.purple.withValues(alpha: 0.4),
                        foregroundColor: Colors.white,
                        disabledForegroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isSubmittingAppeal
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : const Text(
                              'Request a review',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                ],
                const SizedBox(height: 32),

                // Community guidelines link
                TextButton(
                  onPressed: () { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Appeal submitted. We will review it."), behavior: SnackBarBehavior.floating)); },
                  child: Text(
                    'Read Community Guidelines',
                    style: TextStyle(
                      color: KoraColors.purple,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

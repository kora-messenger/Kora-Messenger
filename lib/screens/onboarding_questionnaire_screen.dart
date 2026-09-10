import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/crash_logger.dart';
import '../theme/kora_colors.dart';
import 'kora_home_screen.dart';

/// Onboarding Questionnaire — shown once, to brand-new accounts only.
///
/// Appears right after profile setup (or right after first sign-in for
/// accounts that finished profile setup but haven't done this yet).
/// Answers are saved to the account, so completion survives sign-out
/// and syncs across every device. Existing accounts created before this
/// feature are treated as already onboarded and never see this screen.
class OnboardingQuestionnaireScreen extends StatefulWidget {
  final String userId;

  const OnboardingQuestionnaireScreen({super.key, required this.userId});

  @override
  State<OnboardingQuestionnaireScreen> createState() =>
      _OnboardingQuestionnaireScreenState();
}

class _OnboardingQuestionnaireScreenState
    extends State<OnboardingQuestionnaireScreen> {
  final AuthService _auth = AuthService.instance;

  static const _kUseForOptions = [
    'Friends & family',
    'Work',
    'Communities',
    'Channels',
    'Business',
    'Just exploring',
  ];

  static const _kHeardFromOptions = [
    'A friend invited me',
    'App store',
    'Social media',
    'Online search',
    'Other',
  ];

  final Set<String> _useFor = <String>{};
  String? _heardFrom;
  bool _saving = false;

  bool get _canContinue => _useFor.isNotEmpty && !_saving;

  Future<void> _continue() async {
    if (!_canContinue) return;
    setState(() => _saving = true);
    try {
      final result = await _auth.saveQuestionnaire(
        userId: widget.userId,
        answers: {
          'useFor': _useFor.toList(),
          if (_heardFrom != null) 'heardFrom': _heardFrom!,
          'completedAt': DateTime.now().toUtc().toIso8601String(),
        },
      );
      if (!mounted) return;
      if (result.success) {
        // Straight into Kora — isNewUser keeps the welcome moment alive.
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const KoraHomeScreen(isNewUser: true)),
          (route) => false,
        );
      } else {
        setState(() => _saving = false);
        _showError(result.error ?? 'Could not save your answers. Please try again.');
      }
    } catch (e, stack) {
      await CrashLogger.log(e, stackTrace: stack, context: 'OnboardingQuestionnaire');
      if (mounted) {
        setState(() => _saving = false);
        _showError('Something went wrong. Please try again.');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: KoraColors.darkCard,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KoraColors.trueBlack,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    _buildHeader(),
                    const SizedBox(height: 32),
                    _buildQuestion(
                      index: '1',
                      question: 'What will you use Kora for?',
                      hint: 'Pick as many as you like',
                      child: _buildMultiSelect(),
                    ),
                    const SizedBox(height: 28),
                    _buildQuestion(
                      index: '2',
                      question: 'How did you hear about Kora?',
                      hint: 'Optional',
                      child: _buildSingleSelect(),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(gradient: KoraColors.brandGradient),
              child: const Center(
                child: Text(
                  'K',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Welcome to Kora',
              style: TextStyle(
                color: KoraColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'A few quick questions — takes 20 seconds. '
          'This helps us tailor your experience.',
          style: TextStyle(
            color: KoraColors.textSecondary,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildQuestion({
    required String index,
    required String question,
    required String hint,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '$index.',
              style: const TextStyle(
                color: KoraColors.purple,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                question,
                style: const TextStyle(
                  color: KoraColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          hint,
          style: const TextStyle(color: KoraColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 14),
        child,
      ],
    );
  }

  Widget _buildMultiSelect() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final option in _kUseForOptions)
          _buildChip(
            label: option,
            selected: _useFor.contains(option),
            onTap: () => setState(() {
              if (_useFor.contains(option)) {
                _useFor.remove(option);
              } else {
                _useFor.add(option);
              }
            }),
          ),
      ],
    );
  }

  Widget _buildSingleSelect() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final option in _kHeardFromOptions)
          _buildChip(
            label: option,
            selected: _heardFrom == option,
            onTap: () => setState(() {
              _heardFrom = _heardFrom == option ? null : option;
            }),
          ),
      ],
    );
  }

  Widget _buildChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? KoraColors.purple.withValues(alpha: 0.18) : KoraColors.darkCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? KoraColors.purple : KoraColors.darkCard,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? KoraColors.textPrimary : KoraColors.textSecondary,
            fontSize: 14,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: _canContinue ? KoraColors.brandGradient : null,
          color: _canContinue ? null : KoraColors.darkCard,
          borderRadius: BorderRadius.circular(14),
        ),
        child: TextButton(
          onPressed: _continue,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            foregroundColor: _canContinue ? Colors.white : KoraColors.textSecondary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : const Text(
                  'Continue',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
        ),
      ),
    );
  }
}

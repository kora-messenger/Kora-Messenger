import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/kora_colors.dart';

/// Guided multi-step Privacy Checkup screen cycling through:
/// 1. Last Seen visibility
/// 2. Profile Photo visibility
/// 3. Read Receipts
/// 4. Done step.
class PrivacyCheckupScreen extends StatefulWidget {
  const PrivacyCheckupScreen({super.key});

  @override
  State<PrivacyCheckupScreen> createState() => _PrivacyCheckupScreenState();
}

class _PrivacyCheckupScreenState extends State<PrivacyCheckupScreen> {
  int _currentStep = 0;
  bool _isLoading = true;

  // Preferences state matching privacy_screen.dart
  String _lastSeen = 'everyone';
  String _profilePhoto = 'everyone';
  bool _readReceipts = true;

  static const String _prefix = 'kora_privacy_';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lastSeen = prefs.getString('${_prefix}last_seen') ?? 'everyone';
      _profilePhoto = prefs.getString('${_prefix}profile_photo') ?? 'everyone';
      _readReceipts = prefs.getBool('${_prefix}read_receipts') ?? true;
      _isLoading = false;
    });
  }

  Future<void> _saveCurrentStep() async {
    final prefs = await SharedPreferences.getInstance();
    if (_currentStep == 0) {
      await prefs.setString('${_prefix}last_seen', _lastSeen);
    } else if (_currentStep == 1) {
      await prefs.setString('${_prefix}profile_photo', _profilePhoto);
    } else if (_currentStep == 2) {
      await prefs.setBool('${_prefix}read_receipts', _readReceipts);
    }
  }

  void _nextStep() async {
    await _saveCurrentStep();
    if (_currentStep < 3) {
      setState(() {
        _currentStep++;
      });
    } else {
      Navigator.pop(context);
    }
  }

  void _skipStep() {
    if (_currentStep < 3) {
      setState(() {
        _currentStep++;
      });
    } else {
      Navigator.pop(context);
    }
  }

  String _visibilityLabel(String value) {
    switch (value) {
      case 'everyone':
        return 'Everyone';
      case 'myContacts':
        return 'My Contacts';
      case 'nobody':
        return 'Nobody';
      default:
        return 'Everyone';
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
          'Privacy checkup',
          style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: KoraColors.purple))
          : Column(
              children: [
                // Step Indicator Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: List.generate(4, (index) {
                      final isActive = index <= _currentStep;
                      return Expanded(
                        child: Container(
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: isActive ? KoraColors.purple : border,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: _buildStepContent(card, border, textPrimary, textSecondary),
                  ),
                ),

                // Bottom Navigation Buttons
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: bg,
                    border: Border(top: BorderSide(color: border)),
                  ),
                  child: Row(
                    children: [
                      if (_currentStep < 3) ...[
                        TextButton(
                          onPressed: _skipStep,
                          child: Text('Skip', style: TextStyle(color: textSecondary, fontSize: 16)),
                        ),
                        const Spacer(),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: KoraColors.purple,
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          ),
                          onPressed: _nextStep,
                          child: const Text('Next', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ] else ...[
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: KoraColors.purple,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            ),
                            onPressed: _nextStep,
                            child: const Text('Done', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStepContent(Color card, Color border, Color textPrimary, Color textSecondary) {
    switch (_currentStep) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.visibility_outlined, color: KoraColors.purple, size: 40),
            const SizedBox(height: 16),
            Text('Control who sees your Last Seen & Online', style: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Choose who can see when you were last online on Kora.', style: TextStyle(color: textSecondary, fontSize: 14)),
            const SizedBox(height: 24),
            _buildVisibilityOptions(['everyone', 'myContacts', 'nobody'], _lastSeen, (val) => setState(() => _lastSeen = val), card, border, textPrimary, textSecondary),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.account_circle_outlined, color: KoraColors.purple, size: 40),
            const SizedBox(height: 16),
            Text('Who can see your Profile Photo?', style: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Decide who can view your photo across Kora.', style: TextStyle(color: textSecondary, fontSize: 14)),
            const SizedBox(height: 24),
            _buildVisibilityOptions(['everyone', 'myContacts', 'nobody'], _profilePhoto, (val) => setState(() => _profilePhoto = val), card, border, textPrimary, textSecondary),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.done_all_rounded, color: KoraColors.purple, size: 40),
            const SizedBox(height: 16),
            Text('Read Receipts', style: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('When turned off, you won\'t send or receive read receipts in individual chats.', style: TextStyle(color: textSecondary, fontSize: 14)),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Send Read Receipts', style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                  Switch.adaptive(
                    value: _readReceipts,
                    activeTrackColor: KoraColors.purple,
                    onChanged: (val) => setState(() => _readReceipts = val),
                  ),
                ],
              ),
            ),
          ],
        );
      case 3:
      default:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: KoraColors.purple.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline, color: KoraColors.purple, size: 72),
            ),
            const SizedBox(height: 24),
            Text('You\'re all set!', style: TextStyle(color: textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('Your privacy preferences have been saved. You can always adjust these settings anytime in Privacy settings.', style: TextStyle(color: textSecondary, fontSize: 14, height: 1.4), textAlign: TextAlign.center),
          ],
        );
    }
  }

  Widget _buildVisibilityOptions(
    List<String> options,
    String currentValue,
    ValueChanged<String> onChanged,
    Color card,
    Color border,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        children: options.map((opt) {
          final isSelected = opt == currentValue;
          return ListTile(
            onTap: () => onChanged(opt),
            leading: Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? KoraColors.purple : textSecondary,
              size: 22,
            ),
            title: Text(
              _visibilityLabel(opt),
              style: TextStyle(
                color: textPrimary,
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

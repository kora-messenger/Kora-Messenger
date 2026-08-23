import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import '../../services/translation_service.dart';
import '../../models/translation_models.dart';
import 'language_picker_screen.dart';

/// Call translation configuration sheet — audio voice-to-voice mode.
///
/// Lets users pick:
/// - Their language (what they speak)
/// - Target language (what the other person hears)
///
/// No captions — translation is audio-only. The other person hears
/// your speech translated into their language via TTS.
class CallTranslationSheet extends StatefulWidget {
  final bool isInCall;

  const CallTranslationSheet({
    super.key,
    this.isInCall = false,
  });

  static void show(BuildContext context, {bool isInCall = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CallTranslationSheet(isInCall: isInCall),
    );
  }

  @override
  State<CallTranslationSheet> createState() => _CallTranslationSheetState();
}

class _CallTranslationSheetState extends State<CallTranslationSheet> {
  final _service = TranslationService.instance;
  late KoraLanguage _yourLanguage;
  late KoraLanguage _targetLanguage;

  @override
  void initState() {
    super.initState();
    _yourLanguage = _service.preferredLanguage;
    _targetLanguage = _service.preferredLanguage;
  }

  Future<KoraLanguage?> _pickLanguage(String title) async {
    return Navigator.push<KoraLanguage>(
      context,
      MaterialPageRoute(builder: (_) => LanguagePickerScreen(title: title)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final card = KoraColors.cardFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);
    final border = KoraColors.borderFor(brightness);

    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
              child: Row(
                children: [
                  Icon(Icons.translate_rounded, color: KoraColors.purple, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Call Translation',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: textMuted, size: 22),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: border),

            // Info card
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: KoraColors.purple.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: KoraColors.purple.withValues(alpha: 0.12),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.graphic_eq_rounded, size: 18, color: KoraColors.purple),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Voice-to-voice translation. You speak your language, they hear theirs. Audio only — no text on screen.',
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Language selectors
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                children: [
                  // Your language
                  _languageTile(
                    title: 'You speak',
                    subtitle: _yourLanguage.name,
                    flag: _yourLanguage.flag,
                    onTap: () async {
                      final lang = await _pickLanguage('Your Language');
                      if (lang != null && mounted) {
                        setState(() => _yourLanguage = lang);
                      }
                    },
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    textMuted: textMuted,
                    border: border,
                  ),

                  const SizedBox(height: 12),

                  // Swap icon
                  Center(
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: KoraColors.purple.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.swap_vert_rounded, color: KoraColors.purple, size: 20),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Target language
                  _languageTile(
                    title: 'They hear',
                    subtitle: _targetLanguage.name,
                    flag: _targetLanguage.flag,
                    onTap: () async {
                      final lang = await _pickLanguage('Their Language');
                      if (lang != null && mounted) {
                        setState(() => _targetLanguage = lang);
                      }
                    },
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    textMuted: textMuted,
                    border: border,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Start/Apply button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(context, (
                    sourceLanguage: _yourLanguage.code,
                    targetLanguage: _targetLanguage.code,
                  ));
                },
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: KoraColors.brandGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 6),
                        Text(
                          widget.isInCall ? 'Apply Translation' : 'Start Translation',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _languageTile({
    required String title,
    required String subtitle,
    required String flag,
    required VoidCallback onTap,
    required Color textPrimary,
    required Color textSecondary,
    required Color textMuted,
    required Color border,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: KoraColors.purple.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: 0.5),
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: textMuted),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import '../../widgets/kora_waveform.dart';

/// Voice transcription & translation bottom sheet.
///
/// Flow: Voice Note → Transcribe (auto) → Show transcript →
/// User picks a language → Translated text appears.
///
/// Since real transcription/translation APIs aren't connected yet,
/// the sheet shows a simulated processing state then displays
/// placeholder transcript and translated text. The UI is fully
/// functional — swap the simulation for real API calls later.
class VoiceTranslationSheet extends StatefulWidget {
  final String voiceDuration;

  const VoiceTranslationSheet({
    super.key,
    required this.voiceDuration,
  });

  @override
  State<VoiceTranslationSheet> createState() => _VoiceTranslationSheetState();
}

enum _Stage { transcribing, done }

class _VoiceTranslationSheetState extends State<VoiceTranslationSheet>
    with SingleTickerProviderStateMixin {
  _Stage _stage = _Stage.transcribing;
  String? _selectedLanguage;
  bool _isTranslating = false;
  bool _showTranslation = false;

  late AnimationController _spinController;

  static const _languages = [
    {'code': 'es', 'name': 'Spanish', 'flag': '🇪🇸'},
    {'code': 'fr', 'name': 'French', 'flag': '🇫🇷'},
    {'code': 'pt', 'name': 'Portuguese', 'flag': '🇵🇹'},
    {'code': 'ar', 'name': 'Arabic', 'flag': '🇸🇦'},
    {'code': 'de', 'name': 'German', 'flag': '🇩🇪'},
    {'code': 'hi', 'name': 'Hindi', 'flag': '🇮🇳'},
    {'code': 'zh', 'name': 'Chinese', 'flag': '🇨🇳'},
    {'code': 'ja', 'name': 'Japanese', 'flag': '🇯🇵'},
    {'code': 'yo', 'name': 'Yoruba', 'flag': '🇳🇬'},
    {'code': 'sw', 'name': 'Swahili', 'flag': '🇰🇪'},
  ];

  // Simulated transcript (replace with real transcription API)
  static const _mockTranscript =
      'Hey, just wanted to check in about the meeting tomorrow. '
      'Can we move it to 3 PM instead? Let me know what works for you.';

  // Simulated translations (replace with real translation API)
  static const _mockTranslations = {
    'es': 'Oye, solo quería informarte sobre la reunión de mañana. ¿Podemos cambiarla a las 3 PM en su lugar? Avísame qué te funciona.',
    'fr': 'Hé, je voulais juste vérifier pour la réunion de demain. Peut-on la déplacer à 15h à la place ? Dis-moi ce qui te convient.',
    'pt': 'Ei, só queria confirmar sobre a reunião de amanhã. Podemos mudar para as 15h? Me diga o que funciona para você.',
    'ar': 'مرحبًا، أردت فقط التحقق من اجتماع الغد. هل يمكننا نقله إلى الساعة 3 مساءً؟ دعني أعرف ما يناسبك.',
    'de': 'Hey, ich wollte nur wegen des Treffens morgen nachfragen. Können wir es stattdessen auf 15 Uhr verschieben? Sag mir Bescheid, was dir passt.',
    'hi': 'अरे, मैं बस कल की मीटिंग के बारे में जानना चाहता था। क्या हम इसे दोपहर 3 बजे कर सकते हैं? मुझे बताएं कि आपके लिए कौन सा समय उपयुक्त है।',
    'zh': '嘿，只是想确认一下明天的会议。我们能改到下午3点吗？告诉我你什么时间方便。',
    'ja': 'ねえ、明日の会議について確認したかったんです。3時に変更できますか？都合のいい時間を教えてください。',
    'yo': 'Kílọ̀, mo fẹ́ wá yẹ ìpàdé ọ̀la wò. Ṣé a lè yí ọ́ padà sí ọ̀sán mẹ́ta? Sọ fún mi irúfẹ́ tí ó wù ọ́.',
    'sw': 'Hey, nilitaka tu kuangalia kuhusu mkutano wa kesho. Tunaweza kuusogeza hadi saa 3 mchana? Niambie inakufaa nini.',
  };

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    // Simulate transcription processing
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _stage = _Stage.done);
    });
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  void _translate(String code) {
    setState(() {
      _selectedLanguage = code;
      _isTranslating = true;
      _showTranslation = false;
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _isTranslating = false;
          _showTranslation = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final surface = KoraColors.cardFor(brightness);
    final bg = KoraColors.surfaceFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);
    final border = KoraColors.borderFor(brightness);

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle ──
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
            child: Row(
              children: [
                Icon(Icons.language_rounded, color: KoraColors.purple, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Transcribe & Translate',
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
          // ── Body ──
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Voice note mini-preview
                  _buildMiniVoicePreview(bg, border, textMuted),
                  const SizedBox(height: 20),

                  if (_stage == _Stage.transcribing) ...[
                    _buildTranscribingState(textSecondary),
                  ] else ...[
                    // ── Transcript ──
                    _buildSectionLabel('Transcript', textMuted),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: border, width: 0.5),
                      ),
                      child: Text(
                        _mockTranscript,
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 14.5,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Translate ──
                    _buildSectionLabel('Translate to', textMuted),
                    const SizedBox(height: 8),

                    // Language chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _languages.map((lang) {
                        final isSelected = _selectedLanguage == lang['code'];
                        return GestureDetector(
                          onTap: () => _translate(lang['code']!),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? KoraColors.purple
                                  : bg,
                              border: Border.all(
                                color: isSelected
                                    ? KoraColors.purple
                                    : border,
                                width: 0.8,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(lang['flag']!, style: const TextStyle(fontSize: 14)),
                                const SizedBox(width: 6),
                                Text(
                                  lang['name']!,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : textSecondary,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    // Translation result
                    if (_isTranslating) ...[
                      const SizedBox(height: 16),
                      _buildTranslatingState(textSecondary),
                    ] else if (_showTranslation && _selectedLanguage != null) ...[
                      const SizedBox(height: 16),
                      _buildSectionLabel(
                        "${_languages.firstWhere((l) => l['code'] == _selectedLanguage)['name']} translation",
                        textMuted,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              KoraColors.purple.withValues(alpha: 0.08),
                              KoraColors.blue.withValues(alpha: 0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: KoraColors.purple.withValues(alpha: 0.2),
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          _mockTranslations[_selectedLanguage]!,
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 14.5,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text, Color color) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildMiniVoicePreview(Color bg, Color border, Color textMuted) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              gradient: KoraColors.brandGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 24,
              child: KoraWaveform(
                isLive: false,
                progress: 0.3,
                barCount: 30,
                height: 24,
                barWidth: 2,
                barGap: 2,
                playedColor: KoraColors.purple,
                unplayedColor: KoraColors.purple.withValues(alpha: 0.2),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            widget.voiceDuration,
            style: TextStyle(
              color: textMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscribingState(Color textSecondary) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            RotationTransition(
              turns: _spinController,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: KoraColors.purple.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.graphic_eq_rounded,
                  color: KoraColors.purple,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Transcribing...',
              style: TextStyle(
                color: textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Converting voice to text',
              style: TextStyle(
                color: textSecondary.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTranslatingState(Color textSecondary) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: KoraColors.purple,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Translating...',
              style: TextStyle(
                color: textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows the voice translation bottom sheet.
void showVoiceTranslationSheet(BuildContext context, {required String voiceDuration}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    builder: (_) => VoiceTranslationSheet(voiceDuration: voiceDuration),
  );
}

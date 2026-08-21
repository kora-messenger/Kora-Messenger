import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/kora_colors.dart';
import '../../widgets/kora_waveform.dart';
import '../../services/translation_service.dart';
import '../../models/translation_models.dart';
import '../../services/connectivity_service.dart';
import 'language_picker_screen.dart';

/// Voice transcription & translation bottom sheet.
///
/// Supports two flows:
/// 1. **Transcribe only** — Voice → Transcript (no translation)
/// 2. **Transcribe + Translate** — Voice → Transcript → Translation
///
/// Also supports one-tap "Translate Voice" which does both automatically.
///
/// Features:
/// - Mini voice preview (play button, waveform, duration)
/// - Detected language display
/// - Transcript text (copyable)
/// - Translation with language switching
/// - Loading states ("Transcribing..." / "Translating...")
/// - Offline error handling
/// - Change target language without re-transcribing
class VoiceTranslationSheet extends StatefulWidget {
  final String voiceDuration;
  final bool autoTranslate;
  final String? voiceId;
  final String? transcript;

  /// If [transcript] is provided (e.g. from on-device STT during recording),
  /// the sheet skips transcription and uses it directly.
  const VoiceTranslationSheet({
    super.key,
    required this.voiceDuration,
    this.autoTranslate = false,
    this.voiceId,
    this.transcript,
  });

  /// Opens the sheet. If [autoTranslate] is true, performs one-tap
  /// voice translation (transcribe + translate in one go).
  static void show(
    BuildContext context, {
    required String voiceDuration,
    bool autoTranslate = false,
    String? voiceId,
    String? transcript,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VoiceTranslationSheet(
        voiceDuration: voiceDuration,
        autoTranslate: autoTranslate,
        voiceId: voiceId,
        transcript: transcript,
      ),
    );
  }

  @override
  State<VoiceTranslationSheet> createState() => _VoiceTranslationSheetState();
}

enum _Stage { transcribing, transcribed, translating, translated, error }

class _VoiceTranslationSheetState extends State<VoiceTranslationSheet> {
  final _translationService = TranslationService.instance;

  _Stage _stage = _Stage.transcribing;
  String _transcript = '';
  String _detectedLangName = '';
  String _detectedLangCode = '';
  String _translatedText = '';
  KoraLanguage? _targetLanguage;
  String _errorMsg = '';

  @override
  void initState() {
    super.initState();
    _targetLanguage = _translationService.preferredLanguage;

    if (widget.autoTranslate) {
      _startFullFlow();
    } else {
      _startTranscription();
    }
  }

  Future<void> _startTranscription() async {
    setState(() => _stage = _Stage.transcribing);

    // If we already have a transcript (e.g. from on-device STT), use it directly
    if (widget.transcript != null && widget.transcript!.isNotEmpty) {
      final detectedCode = await _translationService.detectLanguage(widget.transcript!);
      final detectedLang = _translationService.languageByCode(detectedCode ?? 'en');
      if (mounted) {
        setState(() {
          _transcript = widget.transcript!;
          _detectedLangCode = detectedCode ?? 'en';
          _detectedLangName = detectedLang?.name ?? 'Unknown';
          _stage = _Stage.transcribed;
        });
      }
      return;
    }

    if (!ConnectivityService.instance.isOnline) {
      setState(() {
        _stage = _Stage.error;
        _errorMsg = 'No internet connection. Transcription requires network access.';
      });
      return;
    }

    try {
      final transcript = await _translationService.transcribeVoiceNote(
        widget.voiceId ?? 'voice_${DateTime.now().millisecondsSinceEpoch}',
      );
      final detectedCode = await _translationService.detectLanguage(transcript);
      final detectedLang = _translationService.languageByCode(detectedCode ?? 'en');

      if (mounted) {
        setState(() {
          _transcript = transcript;
          _detectedLangCode = detectedCode ?? 'en';
          _detectedLangName = detectedLang?.name ?? 'Unknown';
          _stage = _Stage.transcribed;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _stage = _Stage.error;
          _errorMsg = 'We couldn\'t transcribe this voice note. Please try again.';
        });
      }
    }
  }

  Future<void> _startFullFlow() async {
    setState(() => _stage = _Stage.transcribing);

    String transcript;

    // Use pre-existing transcript if available
    if (widget.transcript != null && widget.transcript!.isNotEmpty) {
      transcript = widget.transcript!;
    } else {
      if (!ConnectivityService.instance.isOnline) {
        setState(() {
          _stage = _Stage.error;
          _errorMsg = 'No internet connection. Voice translation requires network access.';
        });
        return;
      }
      transcript = await _translationService.transcribeVoiceNote(
        widget.voiceId ?? 'voice_${DateTime.now().millisecondsSinceEpoch}',
      );
    }

    try {
      final detectedCode = await _translationService.detectLanguage(transcript);
      final detectedLang = _translationService.languageByCode(detectedCode ?? 'en');

      if (!mounted) return;
      setState(() {
        _transcript = transcript;
        _detectedLangCode = detectedCode ?? 'en';
        _detectedLangName = detectedLang?.name ?? 'Unknown';
      });

      // Auto-translate if detected language differs from target
      if (_detectedLangCode != _targetLanguage?.code) {
        setState(() => _stage = _Stage.translating);
        final result = await _translationService.translate(
          transcript,
          _targetLanguage!.code,
          sourceCode: _detectedLangCode,
        );
        if (mounted) {
          setState(() {
            _translatedText = result.translatedText;
            _stage = _Stage.translated;
          });
        }
      } else {
        // Same language — no translation needed
        if (mounted) {
          setState(() {
            _translatedText = transcript;
            _stage = _Stage.translated;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _stage = _Stage.error;
          _errorMsg = 'We couldn\'t process this voice note. Please try again.';
        });
      }
    }
  }

  Future<void> _translate() async {
    if (!ConnectivityService.instance.isOnline) {
      setState(() {
        _stage = _Stage.error;
        _errorMsg = 'No internet connection. Translation requires network access.';
      });
      return;
    }

    setState(() => _stage = _Stage.translating);
    try {
      final result = await _translationService.translate(
        _transcript,
        _targetLanguage!.code,
        sourceCode: _detectedLangCode,
      );
      if (mounted) {
        setState(() {
          _translatedText = result.translatedText;
          _stage = _Stage.translated;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _stage = _Stage.error;
          _errorMsg = 'We couldn\'t translate this transcript. Please try again.';
        });
      }
    }
  }

  void _changeLanguage() async {
    final result = await Navigator.push<KoraLanguage>(
      context,
      MaterialPageRoute(
        builder: (_) => LanguagePickerScreen(
          selectedCode: _targetLanguage?.code,
          title: 'Translate to',
        ),
      ),
    );
    if (result != null && result.code != _targetLanguage?.code) {
      setState(() => _targetLanguage = result);
      if (_stage == _Stage.translated) {
        _translate();
      }
    }
  }

  void _copyText(String text) {
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Copied'),
        backgroundColor: KoraColors.purple,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final card = KoraColors.cardFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);
    final border = KoraColors.borderFor(brightness);

    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
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
                    widget.autoTranslate ? 'Translate Voice' : 'Transcribe & Translate',
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
                    // ── Mini voice preview ──
                    _buildMiniVoicePreview(surface, border, textMuted),
                    const SizedBox(height: 20),

                    // ── State-based content ──
                    if (_stage == _Stage.transcribing)
                      _buildProcessingRow(
                        surface,
                        textSecondary,
                        'Transcribing voice...',
                        Icons.mic_rounded,
                      )
                    else if (_stage == _Stage.translating)
                      _buildProcessingRow(
                        surface,
                        textSecondary,
                        'Translating...',
                        Icons.translate_rounded,
                      )
                    else if (_stage == _Stage.error)
                      _buildErrorCard(surface, textSecondary)
                    else ...[
                      // ── Detected language ──
                      if (_detectedLangName.isNotEmpty)
                        _buildLanguageBadge(surface, textMuted),
                      const SizedBox(height: 12),

                      // ── Transcript ──
                      _buildSectionLabel('Transcript', textMuted),
                      const SizedBox(height: 6),
                      _buildTextCard(
                        _transcript,
                        surface,
                        textPrimary,
                        onCopy: () => _copyText(_transcript),
                      ),
                      const SizedBox(height: 16),

                      // ── Translation section ──
                      if (_stage == _Stage.translated) ...[
                        _buildSectionLabel(
                          '${_targetLanguage?.name ?? ''} Translation',
                          textMuted,
                        ),
                        const SizedBox(height: 6),
                        _buildTextCard(
                          _translatedText,
                          KoraColors.purple.withValues(alpha: 0.04),
                          textPrimary,
                          isTranslation: true,
                          onCopy: () => _copyText(_translatedText),
                        ),
                        const SizedBox(height: 12),
                        // Action row
                        Row(
                          children: [
                            _buildAction(
                              Icons.language_rounded,
                              'Change language',
                              _changeLanguage,
                              textSecondary,
                            ),
                            const SizedBox(width: 16),
                            _buildAction(
                              Icons.copy_rounded,
                              'Copy translation',
                              () => _copyText(_translatedText),
                              textSecondary,
                            ),
                          ],
                        ),
                      ] else if (_stage == _Stage.transcribed) ...[
                        // Translate button
                        Row(
                          children: [
                            // Language selector
                            GestureDetector(
                              onTap: _changeLanguage,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: surface,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: border, width: 0.5),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(_targetLanguage?.flag ?? '', style: const TextStyle(fontSize: 14)),
                                    const SizedBox(width: 6),
                                    Text(
                                      _targetLanguage?.name ?? 'Select',
                                      style: TextStyle(
                                        color: textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: textMuted),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Translate button
                            GestureDetector(
                              onTap: _translate,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                                decoration: BoxDecoration(
                                  gradient: KoraColors.brandGradient,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.translate_rounded, size: 16, color: Colors.white),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Translate',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
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
            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            height: 24,
            child: KoraWaveform(
              isLive: false,
              progress: 0,
              barCount: 24,
              height: 24,
              barWidth: 2,
              barGap: 2,
              playedColor: KoraColors.purple.withValues(alpha: 0.3),
              unplayedColor: KoraColors.purple.withValues(alpha: 0.15),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            widget.voiceDuration,
            style: TextStyle(
              color: textMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageBadge(Color surface, Color textMuted) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: KoraColors.purple.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.travel_explore_rounded, size: 14, color: KoraColors.purple),
          const SizedBox(width: 4),
          Text(
            'Detected: $_detectedLangName',
            style: TextStyle(
              color: KoraColors.purple,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingRow(Color surface, Color textSecondary, String label, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: KoraColors.purple.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(width: 12),
          Icon(icon, size: 18, color: KoraColors.purple.withValues(alpha: 0.5)),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(Color surface, Color textSecondary) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline_rounded, size: 18, color: KoraColors.red),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _errorMsg,
                  style: TextStyle(color: textSecondary, fontSize: 13.5, height: 1.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () {
              if (widget.autoTranslate) {
                _startFullFlow();
              } else {
                _startTranscription();
              }
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh_rounded, size: 16, color: KoraColors.purple),
                const SizedBox(width: 4),
                Text(
                  'Try again',
                  style: TextStyle(
                    color: KoraColors.purple,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label, Color color) {
    return Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildTextCard(
    String text,
    Color bg,
    Color textColor, {
    bool isTranslation = false,
    VoidCallback? onCopy,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: isTranslation
            ? Border.all(color: KoraColors.purple.withValues(alpha: 0.15), width: 0.5)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 14.5,
              height: 1.5,
              fontWeight: isTranslation ? FontWeight.w500 : FontWeight.w400,
            ),
          ),
          if (onCopy != null) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onCopy,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.copy_rounded, size: 14, color: KoraColors.textMutedFor(Theme.of(context).brightness)),
                  const SizedBox(width: 4),
                  Text(
                    'Copy',
                    style: TextStyle(
                      color: KoraColors.textMutedFor(Theme.of(context).brightness),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAction(IconData icon, String label, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

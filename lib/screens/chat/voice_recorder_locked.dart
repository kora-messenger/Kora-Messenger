import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import '../../widgets/kora_waveform.dart';

/// The full-width bar shown once recording is locked (hands-free).
/// Trash discards, the pause/resume button toggles recording, the
/// translate button picks a target language, and the send button
/// finalises and sends — optionally translating first.
class LockedRecorderBar extends StatelessWidget {
  final int seconds;
  final bool isPaused;
  final List<double> waveformSamples;
  final VoidCallback onDiscard;
  final VoidCallback onTogglePause;
  final VoidCallback onSend;
  final VoidCallback? onTranslate;
  final String? selectedTranslateName;
  final bool isTranslating;

  const LockedRecorderBar({
    super.key,
    required this.seconds,
    required this.isPaused,
    required this.waveformSamples,
    required this.onDiscard,
    required this.onTogglePause,
    required this.onSend,
    this.onTranslate,
    this.selectedTranslateName,
    this.isTranslating = false,
  });

  String get _durationString {
    final m = (seconds ~/ 60).toString();
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final surface = KoraColors.cardFor(brightness);
    final border = KoraColors.borderFor(brightness);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border, width: 0.5),
      ),
      child: Row(
        children: [
          // ── Trash ──
          GestureDetector(
            onTap: onDiscard,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: KoraColors.red.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: KoraColors.red,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // ── Timer + Waveform ──
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selectedTranslateName != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.language_rounded,
                          size: 13,
                          color: KoraColors.purple.withValues(alpha: 0.8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Translating to $selectedTranslateName',
                          style: TextStyle(
                            color: KoraColors.purple.withValues(alpha: 0.8),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    Text(
                      _durationString,
                      style: TextStyle(
                        color: KoraColors.textSecondaryFor(brightness),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 28,
                        child: KoraWaveform(
                          isLive: !isPaused,
                          progress: 0,
                          barCount: 26,
                          height: 28,
                          barWidth: 2.5,
                          barGap: 2.5,
                          playedColor: KoraColors.purple,
                          unplayedColor:
                              KoraColors.purple.withValues(alpha: 0.2),
                          liveAmplitudes: waveformSamples,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // ── Translate button ──
          GestureDetector(
            onTap: onTranslate,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: selectedTranslateName != null
                    ? KoraColors.purple.withValues(alpha: 0.18)
                    : KoraColors.purple.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.language_rounded,
                color: selectedTranslateName != null
                    ? KoraColors.purple
                    : KoraColors.purple.withValues(alpha: 0.6),
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // ── Pause/Resume ──
          GestureDetector(
            onTap: onTogglePause,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: KoraColors.purple.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPaused ? Icons.mic_rounded : Icons.pause_rounded,
                color: KoraColors.purple,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // ── Send ──
          GestureDetector(
            onTap: isTranslating ? null : onSend,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: isTranslating ? null : KoraColors.brandGradient,
                color: isTranslating
                    ? KoraColors.purple.withValues(alpha: 0.2)
                    : null,
                shape: BoxShape.circle,
              ),
              child: isTranslating
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: KoraColors.purple,
                      ),
                    )
                  : const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import '../../widgets/kora_waveform.dart';

/// Kora's hands-free voice recording bar — replaces the composer the
/// instant the user taps the mic. No holding required.
///
/// Layout (left → right):
/// - Delete/cancel button (Kora red-tinted circle with trash icon)
/// - Center pill: live timer + animated waveform + a large, labeled
///   Pause/Resume control, all inside one Kora-styled rounded container
/// - A small translate toggle (optional, tucked beside the pill)
/// - Prominent Send button (Kora's purple-to-blue brand gradient)
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
    final surface = KoraColors.surfaceFor(brightness);
    final border = KoraColors.borderFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (selectedTranslateName != null)
          Padding(
            padding: const EdgeInsets.only(left: 58, bottom: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.language_rounded, size: 13, color: KoraColors.purple),
                const SizedBox(width: 4),
                Text(
                  'Translating to $selectedTranslateName',
                  style: const TextStyle(
                    color: KoraColors.purple,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Delete / cancel ──
            GestureDetector(
              onTap: onDiscard,
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: KoraColors.red.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: KoraColors.red,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 10),

            // ── Center pill: timer + waveform + large Pause/Resume ──
            Expanded(
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: border, width: 0.6),
                ),
                child: Row(
                  children: [
                    // Live pulse dot while recording (hidden when paused)
                    if (!isPaused) ...[
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: KoraColors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      _durationString,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 28,
                        child: KoraWaveform(
                          isLive: !isPaused,
                          progress: 0,
                          barCount: 24,
                          height: 28,
                          barWidth: 2.5,
                          barGap: 2.5,
                          playedColor: isPaused
                              ? KoraColors.purple.withValues(alpha: 0.35)
                              : KoraColors.purple,
                          unplayedColor: KoraColors.purple.withValues(alpha: 0.15),
                          liveAmplitudes: waveformSamples,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // ── Large, labeled Pause/Resume control ──
                    GestureDetector(
                      onTap: onTogglePause,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: isPaused ? KoraColors.brandGradient : null,
                          color: isPaused ? null : KoraColors.purple.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPaused ? Icons.mic_rounded : Icons.pause_rounded,
                              color: isPaused ? Colors.white : KoraColors.purple,
                              size: 17,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              isPaused ? 'Resume' : 'Pause',
                              style: TextStyle(
                                color: isPaused ? Colors.white : KoraColors.purple,
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
              ),
            ),

            // ── Translate toggle (optional) ──
            if (onTranslate != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onTranslate,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: selectedTranslateName != null
                        ? KoraColors.purple.withValues(alpha: 0.18)
                        : KoraColors.surfaceFor(brightness),
                    shape: BoxShape.circle,
                    border: selectedTranslateName != null
                        ? null
                        : Border.all(color: border, width: 0.6),
                  ),
                  child: Icon(
                    Icons.language_rounded,
                    color: selectedTranslateName != null
                        ? KoraColors.purple
                        : KoraColors.textMutedFor(brightness),
                    size: 19,
                  ),
                ),
              ),
            ],

            const SizedBox(width: 10),

            // ── Prominent Send button ──
            GestureDetector(
              onTap: isTranslating ? null : onSend,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: isTranslating ? null : KoraColors.brandGradient,
                  color: isTranslating ? KoraColors.purple.withValues(alpha: 0.2) : null,
                  shape: BoxShape.circle,
                  boxShadow: isTranslating
                      ? null
                      : [
                          BoxShadow(
                            color: KoraColors.purple.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: isTranslating
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: CircularProgressIndicator(strokeWidth: 2, color: KoraColors.purple),
                      )
                    : const Icon(Icons.send_rounded, color: Colors.white, size: 21),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

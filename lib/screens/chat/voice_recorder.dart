import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import '../../widgets/kora_waveform.dart';

/// The content shown in place of the text field while the user is
/// actively holding the mic button (recording, not yet locked).
///
/// Shows a pulsing record dot + live timer on one side and an
/// animated "◀ Slide to cancel" hint on the other. [cancelProgress]
/// (0–1, driven by how far the user has dragged left) fades and
/// shifts the hint text as they slide toward the cancel threshold.
class VoiceHoldingContent extends StatelessWidget {
  final int seconds;
  final List<double> waveformSamples;
  final double cancelProgress;
  final AnimationController pulseController;

  const VoiceHoldingContent({
    super.key,
    required this.seconds,
    required this.waveformSamples,
    required this.cancelProgress,
    required this.pulseController,
  });

  String get _durationString {
    final m = (seconds ~/ 60).toString();
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Row(
      children: [
        ScaleTransition(
          scale: Tween(begin: 0.8, end: 1.2).animate(
            CurvedAnimation(parent: pulseController, curve: Curves.easeInOut),
          ),
          child: Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(color: KoraColors.red, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _durationString,
          style: TextStyle(
            color: KoraColors.textSecondaryFor(brightness),
            fontSize: 13,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 26,
            child: KoraWaveform(
              isLive: true,
              progress: 0,
              barCount: 24,
              height: 26,
              barWidth: 2.5,
              barGap: 2.5,
              playedColor: KoraColors.purple,
              unplayedColor: KoraColors.purple.withValues(alpha: 0.2),
              liveAmplitudes: waveformSamples,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // "Slide to cancel" — shifts left and fades as the user drags.
        Opacity(
          opacity: (1 - cancelProgress).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(-cancelProgress * 40, 0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.chevron_left_rounded,
                  size: 16,
                  color: KoraColors.textMutedFor(brightness),
                ),
                Text(
                  'Slide to cancel',
                  style: TextStyle(
                    color: KoraColors.textMutedFor(brightness),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The floating "lock" pill that appears above the mic button while
/// holding, hinting the user can drag up to lock hands-free recording.
/// [progress] (0–1) is how close the drag is to the lock threshold —
/// the capsule rises and the chevron nudges up as it increases.
class VoiceLockHint extends StatelessWidget {
  final double progress;

  const VoiceLockHint({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final surface = KoraColors.cardFor(brightness);
    final border = KoraColors.borderFor(brightness);

    return Transform.translate(
      offset: Offset(0, -progress * 14),
      child: Opacity(
        opacity: (0.55 + progress * 0.45).clamp(0.0, 1.0),
        child: Container(
          width: 34,
          height: 64,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border, width: 0.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                progress >= 1 ? Icons.lock_rounded : Icons.lock_open_rounded,
                size: 16,
                color: progress >= 1 ? KoraColors.purple : KoraColors.textMutedFor(brightness),
              ),
              Icon(
                Icons.keyboard_arrow_up_rounded,
                size: 16,
                color: KoraColors.textMutedFor(brightness),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

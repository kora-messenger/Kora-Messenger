import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import '../../widgets/kora_waveform.dart';

/// WhatsApp-exact holding content — shown in place of the text field while
/// the user is actively pressing the mic button (recording, not yet locked).
///
/// Layout (left → right):
///   🔴 pulsing red dot · mm:ss timer ·~~~~~ live waveform ~~~~~· ◀ Slide to cancel
///
/// As the user drags their finger left toward cancel:
///   - The entire content slides left (WhatsApp translates it proportionally)
///   - The "Slide to cancel" text fades out
///   - A red trash icon fades in on the far right (appears as you approach the threshold)
///
/// As the user drags up toward lock:
///   - The lock capsule (handled by [VoiceLockHint]) rises above the mic
class VoiceHoldingContent extends StatelessWidget {
  final int seconds;
  final List<double> waveformSamples;
  final double cancelProgress;
  final AnimationController pulseController;
  final double dragOffsetX;

  const VoiceHoldingContent({
    super.key,
    required this.seconds,
    required this.waveformSamples,
    required this.cancelProgress,
    required this.pulseController,
    this.dragOffsetX = 0,
  });

  String get _durationString {
    final m = (seconds ~/ 60).toString();
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textSecondary = KoraColors.textSecondaryFor(brightness);

    // WhatsApp translates the entire recording content left as the user
    // drags toward cancel — proportional but eased, not 1:1.
    final slideX = (dragOffsetX * 0.35).clamp(-90.0, 0.0);

    return Transform.translate(
      offset: Offset(slideX, 0),
      child: Row(
        children: [
          // ── Red pulsing dot ──
          ScaleTransition(
            scale: Tween(begin: 0.75, end: 1.25).animate(
              CurvedAnimation(parent: pulseController, curve: Curves.easeInOut),
            ),
            child: Container(
              width: 11,
              height: 11,
              decoration: const BoxDecoration(
                color: Color(0xFFEF4444),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // ── Timer ──
          Text(
            _durationString,
            style: TextStyle(
              color: textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 10),
          // ── Live waveform (center) ──
          Expanded(
            child: SizedBox(
              height: 28,
              child: KoraWaveform(
                isLive: true,
                progress: 0,
                barCount: 30,
                height: 28,
                barWidth: 2.5,
                barGap: 2.5,
                playedColor: KoraColors.purple,
                unplayedColor: KoraColors.purple.withValues(alpha: 0.2),
                liveAmplitudes: waveformSamples,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // ── "Slide to cancel" (fades as you drag left) ──
          Opacity(
            opacity: (1 - cancelProgress * 1.5).clamp(0.0, 1.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.keyboard_arrow_left_rounded,
                  size: 18,
                  color: textSecondary,
                ),
                Text(
                  'Slide to cancel',
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// WhatsApp-exact lock capsule — a small vertical pill that floats above
/// the mic button while holding.
///
/// Structure (top → bottom inside the capsule):
///   lock icon (changes from open to locked as progress -> 1)
///   up chevron (hinting "drag up to lock")
///
/// As [progress] increases (0 -> 1):
///   - The capsule rises above the mic button
///   - Opacity increases from semi-transparent to fully visible
///   - The lock icon transitions from open to locked
class VoiceLockHint extends StatelessWidget {
  final double progress;

  const VoiceLockHint({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final surface = KoraColors.cardFor(brightness);
    final border = KoraColors.borderFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);

    // WhatsApp's capsule rises smoothly as you drag up
    final rise = (progress * 18).clamp(0.0, 18.0);

    return Transform.translate(
      offset: Offset(0, -rise - 4),
      child: Opacity(
        opacity: (0.45 + progress * 0.55).clamp(0.0, 1.0),
        child: Container(
          width: 32,
          height: 58,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border, width: 0.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Icon(
                progress >= 0.85 ? Icons.lock_rounded : Icons.lock_open_rounded,
                size: 15,
                color: progress >= 0.85 ? KoraColors.purple : textMuted,
              ),
              Icon(
                Icons.keyboard_arrow_up_rounded,
                size: 15,
                color: textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

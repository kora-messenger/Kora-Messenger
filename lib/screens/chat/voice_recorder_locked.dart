import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import '../../widgets/kora_waveform.dart';

/// The full-width bar shown once recording is locked (hands-free).
/// Trash discards, the pause/resume button toggles recording, and the
/// send button finalises and sends — no play-before-send preview,
/// matching the reference recording flow.
class LockedRecorderBar extends StatelessWidget {
  final int seconds;
  final bool isPaused;
  final List<double> waveformSamples;
  final VoidCallback onDiscard;
  final VoidCallback onTogglePause;
  final VoidCallback onSend;

  const LockedRecorderBar({
    super.key,
    required this.seconds,
    required this.isPaused,
    required this.waveformSamples,
    required this.onDiscard,
    required this.onTogglePause,
    required this.onSend,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border, width: 0.5),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onDiscard,
            child: Container(
              width: 44,
              height: 44,
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
          Expanded(
            child: Row(
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
                const SizedBox(width: 10),
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
                      unplayedColor: KoraColors.purple.withValues(alpha: 0.2),
                      liveAmplitudes: waveformSamples,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
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
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onSend,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                gradient: KoraColors.brandGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(
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

import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import '../../widgets/kora_waveform.dart';

/// Kora's hands-free voice recording bar — replaces the composer the
/// instant the user taps the mic. No holding required.
///
/// Two modes inside the center pill:
/// 1. **Recording** (not paused): red pulse dot + live timer + live
///    waveform + labeled Pause button.
/// 2. **Paused preview** (WhatsApp-style): play/pause button + tappable
///    waveform scrubber with progress fill + position/duration text +
///    speed badge (1x / 1.5x / 2x). A "Resume" button sits below.
///
/// Layout (left → right):
/// - Delete/cancel button (Kora red-tinted circle with trash icon)
/// - Center pill (recording OR paused-preview player)
/// - Play-once toggle (optional)
/// - Translate toggle (optional)
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
  final bool isPlayOnce;
  final VoidCallback? onTogglePlayOnce;

  // -- Paused-recording preview playback --
  final bool isPreviewPlaying;
  final double previewProgress;
  final int previewPositionMs;
  final int previewDurationMs;
  final double previewSpeed;
  final VoidCallback? onTogglePreviewPlay;
  final void Function(double fraction)? onSeekPreview;
  final VoidCallback? onCyclePreviewSpeed;

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
    this.isPlayOnce = false,
    this.onTogglePlayOnce,
    this.isPreviewPlaying = false,
    this.previewProgress = 0.0,
    this.previewPositionMs = 0,
    this.previewDurationMs = 0,
    this.previewSpeed = 1.0,
    this.onTogglePreviewPlay,
    this.onSeekPreview,
    this.onCyclePreviewSpeed,
  });

  String get _durationString => _fmt(seconds * 1000);

  String _fmt(int ms) {
    final totalSeconds = (ms / 1000).round();
    final m = (totalSeconds ~/ 60).toString();
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// Total duration shown while paused — prefers the live-playback
  /// engine's own duration reading once loaded, falls back to the
  /// recorder's elapsed-seconds counter (fixed while paused).
  String get _previewTotalString =>
      previewDurationMs > 0 ? _fmt(previewDurationMs) : _durationString;

  String get _previewElapsedString => _fmt(previewPositionMs);

  String get _speedLabel {
    if (previewSpeed == 1.5) return '1.5x';
    if (previewSpeed == 2.0) return '2x';
    return '1x';
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final surface = KoraColors.surfaceFor(brightness);
    final border = KoraColors.borderFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Status badges (play-once / translating) ──
        if (selectedTranslateName != null || isPlayOnce)
          Padding(
            padding: const EdgeInsets.only(left: 58, bottom: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isPlayOnce) ...[
                  Icon(Icons.lock_clock_rounded, size: 13, color: KoraColors.purple),
                  const SizedBox(width: 4),
                  Text(
                    'Play once',
                    style: const TextStyle(
                      color: KoraColors.purple,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (selectedTranslateName != null) const SizedBox(width: 12),
                ],
                if (selectedTranslateName != null) ...[
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
              ],
            ),
          ),

        // ── Main row ──
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

            // ── Center pill: recording OR paused-preview player ──
            Expanded(
              child: isPaused
                  ? _buildPausedPreviewPill(
                      surface, border, textPrimary, textMuted)
                  : _buildRecordingPill(
                      surface, border, textPrimary),
            ),

            // ── Play-once / self-destruct toggle ──
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onTogglePlayOnce,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isPlayOnce
                      ? KoraColors.purple.withValues(alpha: 0.18)
                      : KoraColors.surfaceFor(brightness),
                  shape: BoxShape.circle,
                  border: isPlayOnce
                      ? null
                      : Border.all(color: border, width: 0.6),
                ),
                child: Icon(
                  isPlayOnce ? Icons.lock_clock_rounded : Icons.timer_outlined,
                  color: isPlayOnce
                      ? KoraColors.purple
                      : textMuted,
                  size: 19,
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
                        : textMuted,
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

  // ──────────────────────────────────────────────────────────────────
  /// Recording pill — red pulse dot + timer + live waveform + Pause.
  Widget _buildRecordingPill(Color surface, Color border, Color textPrimary) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: border, width: 0.6),
      ),
      child: Row(
        children: [
          // Live pulse dot
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: KoraColors.red,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
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
                isLive: true,
                progress: 0,
                barCount: 24,
                height: 28,
                barWidth: 2.5,
                barGap: 2.5,
                playedColor: KoraColors.purple,
                unplayedColor: KoraColors.purple.withValues(alpha: 0.15),
                liveAmplitudes: waveformSamples,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // ── Labeled Pause control ──
          GestureDetector(
            onTap: onTogglePause,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: KoraColors.purple.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.pause_rounded, color: KoraColors.purple, size: 17),
                  SizedBox(width: 5),
                  Text(
                    'Pause',
                    style: TextStyle(
                      color: KoraColors.purple,
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
    );
  }

  // ──────────────────────────────────────────────────────────────────
  /// Paused-preview pill — WhatsApp-style mini player that replaces
  /// the recording waveform while paused. Layout left → right:
  ///   [play/pause] [position] [scrub waveform] [duration] [speed badge]
  /// Below the pill: a "Resume" button.
  Widget _buildPausedPreviewPill(
      Color surface, Color border, Color textPrimary, Color textMuted) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Preview player pill ──
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: border, width: 0.6),
          ),
          child: Row(
            children: [
              // ── Play / Pause preview button ──
              GestureDetector(
                onTap: onTogglePreviewPlay,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: KoraColors.brandGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: KoraColors.purple.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    isPreviewPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // ── Position text (elapsed) ──
              Text(
                _previewElapsedString,
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 8),

              // ── Scrubbable waveform ──
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final waveWidth = constraints.maxWidth.isFinite
                        ? constraints.maxWidth
                        : 100.0;
                    return GestureDetector(
                      onTapDown: onSeekPreview != null
                          ? (details) {
                              final fraction =
                                  (details.localPosition.dx / waveWidth)
                                      .clamp(0.0, 1.0);
                              onSeekPreview!(fraction);
                            }
                          : null,
                      child: SizedBox(
                        width: waveWidth,
                        height: 28,
                        child: KoraWaveform(
                          isLive: false,
                          progress: previewProgress,
                          barCount: 28,
                          height: 28,
                          barWidth: 2.5,
                          barGap: 2.5,
                          playedColor: KoraColors.purple,
                          unplayedColor:
                              KoraColors.purple.withValues(alpha: 0.2),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),

              // ── Duration text (total) ──
              Text(
                _previewTotalString,
                style: TextStyle(
                  color: textMuted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 6),

              // ── Speed badge ──
              if (onCyclePreviewSpeed != null)
                GestureDetector(
                  onTap: onCyclePreviewSpeed,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: KoraColors.purple.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _speedLabel,
                      style: const TextStyle(
                        color: KoraColors.purple,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // ── Resume button (below the pill) ──
        Center(
          child: GestureDetector(
            onTap: onTogglePause,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                gradient: KoraColors.brandGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: KoraColors.purple.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.mic_rounded, color: Colors.white, size: 17),
                  SizedBox(width: 6),
                  Text(
                    'Resume',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import '../../widgets/kora_waveform.dart';

/// WhatsApp-exact locked recording bar — shown INLINE in place of the
/// text composer once recording is locked (via swipe-up or quick tap).
///
/// Two rows:
/// **Row 1 (status):** timer + live/scrub waveform + view-once "1" badge
/// **Row 2 (actions):** delete (trash) | pause/resume pill | send (green circle)
///
/// When paused, row 1's waveform becomes scrubbable and a play/pause
/// button appears for preview.
class VoiceLockedBar extends StatelessWidget {
  final int seconds;
  final List<double> waveformSamples;
  final bool isPaused;
  final bool isPlayOnce;
  final VoidCallback onTogglePlayOnce;

  final VoidCallback onDiscard;
  final VoidCallback onTogglePause;
  final VoidCallback onSend;

  final VoidCallback? onTranslate;
  final String? selectedTranslateName;
  final bool isTranslating;

  // Paused-preview playback
  final bool isPreviewPlaying;
  final double previewProgress;
  final int previewPositionMs;
  final VoidCallback? onTogglePreviewPlay;
  final void Function(double fraction)? onSeekPreview;

  const VoiceLockedBar({
    super.key,
    required this.seconds,
    required this.waveformSamples,
    required this.isPaused,
    required this.isPlayOnce,
    required this.onTogglePlayOnce,
    required this.onDiscard,
    required this.onTogglePause,
    required this.onSend,
    this.onTranslate,
    this.selectedTranslateName,
    this.isTranslating = false,
    this.isPreviewPlaying = false,
    this.previewProgress = 0.0,
    this.previewPositionMs = 0,
    this.onTogglePreviewPlay,
    this.onSeekPreview,
  });

  String _fmt(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString();
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get _timerText =>
      isPaused ? _fmt((previewPositionMs / 1000).round()) : _fmt(seconds);

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);
    final border = KoraColors.borderFor(brightness);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Translation badge ──
        if (selectedTranslateName != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.language_rounded, size: 12, color: KoraColors.purple),
                const SizedBox(width: 4),
                Text(
                  'Translating to $selectedTranslateName',
                  style: const TextStyle(
                    color: KoraColors.purple,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

        // ── Row 1: timer + waveform + view-once badge ──
        Row(
          children: [
            // Play/pause preview button (only when paused)
            if (isPaused) ...[
              GestureDetector(
                onTap: onTogglePreviewPlay,
                child: Icon(
                  isPreviewPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: KoraColors.purple,
                  size: 22,
                ),
              ),
              const SizedBox(width: 8),
            ],
            // Timer
            Text(
              _timerText,
              style: TextStyle(
                color: textPrimary,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 10),
            // Waveform
            Expanded(
              child: SizedBox(
                height: 26,
                child: isPaused
                    ? _ScrubWaveform(
                        progress: previewProgress,
                        onSeek: onSeekPreview,
                      )
                    : KoraWaveform(
                        isLive: true,
                        progress: 0,
                        barCount: 32,
                        height: 26,
                        barWidth: 2.5,
                        barGap: 2.5,
                        playedColor: KoraColors.purple,
                        unplayedColor:
                            KoraColors.purple.withValues(alpha: 0.15),
                        liveAmplitudes: waveformSamples,
                      ),
              ),
            ),
            const SizedBox(width: 10),
            // View-once "1" badge
            GestureDetector(
              onTap: onTogglePlayOnce,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isPlayOnce ? KoraColors.purple : Colors.transparent,
                  border: Border.all(
                    color: isPlayOnce ? KoraColors.purple : border,
                    width: 1.3,
                  ),
                ),
                child: Center(
                  child: Text(
                    '1',
                    style: TextStyle(
                      color: isPlayOnce ? Colors.white : textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // ── Row 2: delete | pause/resume pill | translate | send ──
        Row(
          children: [
            // Delete
            GestureDetector(
              onTap: onDiscard,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: KoraColors.red.withValues(alpha: 0.12),
                ),
                child: Icon(
                  Icons.delete_outline_rounded,
                  color: KoraColors.red,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Pause/Resume pill
            Expanded(
              child: GestureDetector(
                onTap: onTogglePause,
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: KoraColors.purple.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isPaused
                            ? Icons.mic_rounded
                            : Icons.pause_rounded,
                        color: KoraColors.purple,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isPaused ? 'Resume' : 'Pause',
                        style: const TextStyle(
                          color: KoraColors.purple,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Translate (optional)
            if (onTranslate != null) ...[
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onTranslate,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selectedTranslateName != null
                        ? KoraColors.purple.withValues(alpha: 0.15)
                        : Colors.transparent,
                    border: selectedTranslateName == null
                        ? Border.all(color: border, width: 1)
                        : null,
                  ),
                  child: Icon(
                    Icons.language_rounded,
                    color: selectedTranslateName != null
                        ? KoraColors.purple
                        : textMuted,
                    size: 20,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 10),
            // Send — WhatsApp's green circle, using Kora's brand gradient
            GestureDetector(
              onTap: isTranslating ? null : onSend,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient:
                      isTranslating ? null : KoraColors.brandGradient,
                  color: isTranslating
                      ? KoraColors.purple.withValues(alpha: 0.4)
                      : null,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isTranslating
                      ? Icons.hourglass_top_rounded
                      : Icons.send_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Scrubbable waveform shown while the recording is paused for preview.
class _ScrubWaveform extends StatelessWidget {
  final double progress;
  final void Function(double fraction)? onSeek;

  const _ScrubWaveform({required this.progress, this.onSeek});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final waveWidth =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 150.0;
        return GestureDetector(
          onTapDown: onSeek != null
              ? (d) =>
                  onSeek!((d.localPosition.dx / waveWidth).clamp(0.0, 1.0))
              : null,
          onHorizontalDragUpdate: onSeek != null
              ? (d) => onSeek!(
                  (d.localPosition.dx / waveWidth).clamp(0.0, 1.0))
              : null,
          child: KoraWaveform(
            isLive: false,
            progress: progress,
            barCount: 32,
            height: 26,
            barWidth: 2.5,
            barGap: 2.5,
            playedColor: KoraColors.purple,
            unplayedColor: KoraColors.purple.withValues(alpha: 0.2),
          ),
        );
      },
    );
  }
}

void showPlayOnceInfoSheet(BuildContext context) {
  final brightness = Theme.of(context).brightness;
  final surface = KoraColors.surfaceFor(brightness);
  final textPrimary = KoraColors.textPrimaryFor(brightness);
  final textSecondary = KoraColors.textSecondaryFor(brightness);
  final textMuted = KoraColors.textMutedFor(brightness);

  showModalBottomSheet(
    context: context,
    backgroundColor: surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetCtx) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: GestureDetector(
                onTap: () => Navigator.pop(sheetCtx),
                child: Icon(Icons.close_rounded, color: textMuted, size: 22),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: KoraColors.brandGradient,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text(
                    '1',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'View once messages give you more privacy',
              textAlign: TextAlign.center,
              style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700, height: 1.3),
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.autorenew_rounded, color: textMuted, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "When you send a voice note, it disappears from the chat after it's opened.",
                    style: TextStyle(color: textSecondary, fontSize: 13.5, height: 1.4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline_rounded, color: textMuted, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "For added privacy, the recipient can't forward, save, or share it.",
                    style: TextStyle(color: textSecondary, fontSize: 13.5, height: 1.4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(sheetCtx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: KoraColors.purple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  elevation: 0,
                ),
                child: const Text('OK', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

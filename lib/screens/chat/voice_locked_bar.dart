import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import '../../widgets/kora_waveform.dart';

/// The locked voice-note recording bar — shown INLINE in place of the
/// text composer once recording is locked (via swipe-up or a quick tap).
///
/// Deliberately NOT a modal/bottom-sheet: it lives in the same widget
/// tree as [MessageComposer] itself, so it always reflects the composer's
/// live state (timer, waveform, pause) the instant it changes — no
/// separate route to fall out of sync with, and no screen-dimming scrim.
///
/// Mirrors WhatsApp's locked-recording bar structure:
/// - Recording: timer + live waveform + view-once badge (row 1),
///   then delete | Pause pill | translate | send (row 2).
/// - Paused (preview): play/pause + scrubbable waveform + timer +
///   view-once badge (row 1), then delete | Resume pill | translate |
///   send (row 2).
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
        // ── Status badge (translating) ──
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

        // ── Row 1: play/timer + waveform + view-once badge ──
        Row(
          children: [
            if (isPaused) ...[
              GestureDetector(
                onTap: onTogglePreviewPlay,
                child: Icon(
                  isPreviewPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: KoraColors.purple,
                  size: 22,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              _timerText,
              style: TextStyle(
                color: textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 24,
                child: isPaused
                    ? _ScrubWaveform(progress: previewProgress, onSeek: onSeekPreview)
                    : KoraWaveform(
                        isLive: true,
                        progress: 0,
                        barCount: 28,
                        height: 24,
                        barWidth: 2.5,
                        barGap: 2.5,
                        playedColor: KoraColors.purple,
                        unplayedColor: KoraColors.purple.withValues(alpha: 0.15),
                        liveAmplitudes: waveformSamples,
                      ),
              ),
            ),
            const SizedBox(width: 10),
            // ── View-once badge ──
            GestureDetector(
              onTap: onTogglePlayOnce,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isPlayOnce ? KoraColors.purple : Colors.transparent,
                  border: Border.all(
                    color: isPlayOnce ? KoraColors.purple : border,
                    width: 1.4,
                  ),
                ),
                child: Center(
                  child: Text(
                    '1',
                    style: TextStyle(
                      color: isPlayOnce ? Colors.white : textMuted,
                      fontSize: 11,
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
            _iconButton(
              icon: Icons.delete_outline_rounded,
              color: KoraColors.red,
              bgColor: KoraColors.red.withValues(alpha: 0.12),
              onTap: onDiscard,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: isPaused ? onTogglePause : onTogglePause,
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: isPaused
                        ? KoraColors.purple.withValues(alpha: 0.14)
                        : KoraColors.purple.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(19),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isPaused ? Icons.mic_rounded : Icons.pause_rounded,
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
            if (onTranslate != null) ...[
              const SizedBox(width: 10),
              _iconButton(
                icon: Icons.language_rounded,
                color: selectedTranslateName != null ? KoraColors.purple : textMuted,
                bgColor: selectedTranslateName != null
                    ? KoraColors.purple.withValues(alpha: 0.18)
                    : Colors.transparent,
                hasBorder: selectedTranslateName == null,
                borderColor: border,
                onTap: onTranslate,
              ),
            ],
            const SizedBox(width: 10),
            _iconButton(
              icon: isTranslating ? Icons.hourglass_top_rounded : Icons.send_rounded,
              color: Colors.white,
              gradient: isTranslating ? null : KoraColors.brandGradient,
              bgColor: isTranslating ? KoraColors.purple.withValues(alpha: 0.4) : null,
              size: 44,
              onTap: isTranslating ? null : onSend,
            ),
          ],
        ),
      ],
    );
  }

  Widget _iconButton({
    required IconData icon,
    required Color color,
    Color? bgColor,
    LinearGradient? gradient,
    bool hasBorder = false,
    Color? borderColor,
    double size = 38,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bgColor,
          gradient: gradient,
          shape: BoxShape.circle,
          border: hasBorder && borderColor != null ? Border.all(color: borderColor, width: 1) : null,
        ),
        child: Icon(icon, color: color, size: size >= 44 ? 20 : 18),
      ),
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
        final waveWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : 150.0;
        return GestureDetector(
          onTapDown: onSeek != null
              ? (d) => onSeek!((d.localPosition.dx / waveWidth).clamp(0.0, 1.0))
              : null,
          onHorizontalDragUpdate: onSeek != null
              ? (d) => onSeek!((d.localPosition.dx / waveWidth).clamp(0.0, 1.0))
              : null,
          child: SizedBox(
            width: waveWidth,
            height: 24,
            child: KoraWaveform(
              isLive: false,
              progress: progress,
              barCount: 28,
              height: 24,
              barWidth: 2.5,
              barGap: 2.5,
              playedColor: KoraColors.purple,
              unplayedColor: KoraColors.purple.withValues(alpha: 0.2),
            ),
          ),
        );
      },
    );
  }
}

/// Shown the first time a user enables "view once" on a voice note —
/// mirrors WhatsApp's explainer sheet (same copy/structure, Kora colors).
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

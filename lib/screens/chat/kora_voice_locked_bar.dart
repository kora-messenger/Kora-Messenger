import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import '../../widgets/kora_waveform.dart';

/// Replacement for the old VoiceLockedBar, matching the design
/// from KoraVoiceNoteRecorder.kt.
///
/// Shows: waveform + timer on top, delete / pause-resume / send on bottom.

class KoraVoiceLockedBar extends StatelessWidget {
  final int seconds;
  final List<double> waveformSamples;
  final bool isPaused;
  final bool isPlayOnce;
  final VoidCallback onTogglePlayOnce;
  final VoidCallback onDiscard;
  final VoidCallback onTogglePause;
  final VoidCallback onSend;
  final VoidCallback onTranslate;
  final String? selectedTranslateName;
  final bool isTranslating;
  final bool isPreviewPlaying;
  final double previewProgress;
  final int previewPositionMs;
  final VoidCallback onTogglePreviewPlay;
  final void Function(double) onSeekPreview;

  const KoraVoiceLockedBar({
    super.key,
    required this.seconds,
    required this.waveformSamples,
    required this.isPaused,
    required this.isPlayOnce,
    required this.onTogglePlayOnce,
    required this.onDiscard,
    required this.onTogglePause,
    required this.onSend,
    required this.onTranslate,
    required this.selectedTranslateName,
    required this.isTranslating,
    required this.isPreviewPlaying,
    required this.previewProgress,
    required this.previewPositionMs,
    required this.onTogglePreviewPlay,
    required this.onSeekPreview,
  });

  String _formatDuration(int s) {
    final m = s ~/ 60;
    final r = s % 60;
    return '$m:${r.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final surface = brightness == Brightness.light
        ? Colors.white
        : const Color(0xFF1A1A2E);
    final text = brightness == Brightness.light
        ? const Color(0xFF151515)
        : Colors.white;
    final control = brightness == Brightness.light
        ? const Color(0xFFF2F1F4)
        : const Color(0xFF2A2A3E);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top row: waveform + timer + translate
          SizedBox(
            height: 40,
            child: Row(
              children: [
                // Translate button (if selected)
                if (selectedTranslateName != null)
                  GestureDetector(
                    onTap: onTranslate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C63FF).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isTranslating)
                            const SizedBox(
                              width: 14, height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6C63FF)),
                            )
                          else
                            const Icon(Icons.language, size: 16, color: Color(0xFF6C63FF)),
                          const SizedBox(width: 4),
                          Text(
                            selectedTranslateName!,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF6C63FF)),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  IconButton(
                    onPressed: onTranslate,
                    icon: Icon(Icons.language, color: text.withValues(alpha: 0.5), size: 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                const SizedBox(width: 6),
                // Waveform — same compact, real-amplitude rendering as
                // the holding-state bar and WhatsApp's own inline waveform.
                Expanded(
                  child: KoraWaveform(
                    isLive: !isPaused,
                    liveAmplitudes: waveformSamples,
                    progress: previewProgress,
                    barCount: 42,
                    height: 26,
                    barWidth: 2.2,
                    barGap: 2.2,
                    playedColor: const Color(0xFF4A90D9),
                    unplayedColor: KoraColors.purple.withValues(alpha: isPaused ? 0.6 : 0.28),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _formatDuration(seconds),
                  style: TextStyle(
                    color: text,
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Controls row: delete / pause-resume / play-once / send
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Delete
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFE7EC),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: onDiscard,
                  icon: const Icon(Icons.delete, color: Color(0xFFE4003B), size: 28),
                ),
              ),
              const SizedBox(width: 12),
              // Pause/Resume
              Expanded(
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: control,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: TextButton.icon(
                    onPressed: onTogglePause,
                    icon: Icon(
                      isPaused ? Icons.play_arrow : Icons.pause,
                      color: text,
                      size: 28,
                    ),
                    label: Text(
                      isPaused ? 'Resume' : 'Pause',
                      style: TextStyle(color: text, fontSize: 17),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Play-once toggle
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isPlayOnce ? const Color(0xFF6C63FF).withValues(alpha: 0.15) : control,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: onTogglePlayOnce,
                  icon: Icon(
                    isPlayOnce ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: isPlayOnce ? const Color(0xFF6C63FF) : text.withValues(alpha: 0.5),
                    size: 22,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                ),
              ),
              const SizedBox(width: 12),
              // Send
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFF6C63FF),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: onSend,
                  icon: const Icon(Icons.send, color: Colors.white, size: 28),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shows a bottom sheet explaining the "view once" voice note feature.
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

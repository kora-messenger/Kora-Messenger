import 'package:flutter/material.dart';

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
  final void Function(int) onSeekPreview;

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
            height: 56,
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
                // Waveform
                Expanded(
                  child: CustomPaint(
                    painter: _LockedWaveformPainter(
                      samples: waveformSamples,
                      active: !isPaused,
                      progress: previewProgress,
                    ),
                    child: const SizedBox(height: 48),
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

class _LockedWaveformPainter extends CustomPainter {
  final List<double> samples;
  final bool active;
  final double progress;

  _LockedWaveformPainter({
    required this.samples,
    required this.active,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final barCount = samples.isNotEmpty ? samples.length : 34;
    final gap = size.width / (barCount + 1);
    final center = size.height / 2;
    final baseColor = active ? const Color(0xFF6C63FF) : const Color(0xFFD0D0D0);

    for (int i = 0; i < barCount; i++) {
      final value = samples.isNotEmpty
          ? samples[i % samples.length]
          : [0.25, 0.55, 0.35, 0.80, 0.42, 0.70, 0.32, 0.90, 0.50, 0.75, 0.38, 0.62][i % 12];
      final height = size.height * value;
      final x = gap * (i + 1);

      final played = (i / barCount) <= progress;
      final paint = Paint()
        ..color = played ? const Color(0xFF4A90D9) : baseColor
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(x, center - height / 2),
        Offset(x, center + height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_LockedWaveformPainter oldDelegate) =>
      samples != oldDelegate.samples ||
      active != oldDelegate.active ||
      progress != oldDelegate.progress;
}

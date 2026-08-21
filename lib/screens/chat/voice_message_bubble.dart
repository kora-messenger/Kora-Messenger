import 'package:flutter/material.dart';
import '../../models/message_model.dart';
import '../../theme/kora_colors.dart';
import '../../widgets/kora_waveform.dart';

/// Kora's voice message bubble — used inside MessageBubble for voice messages.
///
/// Shows: play/pause button, waveform with playback progress, duration,
/// and a Translate / Transcribe action that opens the translation sheet.
///
/// Playback is simulated (no real audio yet) — a timer advances the
/// waveform progress. The structure is ready for real audio integration.
class VoiceMessageBubble extends StatefulWidget {
  final KoraMessage message;

  /// Opens the transcription / translation bottom sheet.
  final VoidCallback? onTranslate;

  const VoiceMessageBubble({
    super.key,
    required this.message,
    this.onTranslate,
  });

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble>
    with SingleTickerProviderStateMixin {
  bool _isPlaying = false;
  double _progress = 0.0;
  @override
  void initState() {
    super.initState();
  }

  void _togglePlay() {
    setState(() => _isPlaying = !_isPlaying);
    if (_isPlaying) _simulatePlayback();
  }

  void _simulatePlayback() {
    if (_progress >= 1.0) _progress = 0.0;
    final totalSecs = _parseDuration(widget.message.voiceDuration ?? '0:05');
    const stepMs = 80;
    final step = stepMs / 1000.0 / totalSecs;

    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: stepMs));
      if (!mounted || !_isPlaying) return false;
      setState(() {
        _progress += step;
        if (_progress >= 1.0) {
          _progress = 1.0;
          _isPlaying = false;
        }
      });
      return _isPlaying;
    });
  }

  int _parseDuration(String d) {
    final parts = d.split(':');
    if (parts.length == 2) {
      return int.parse(parts[0]) * 60 + int.parse(parts[1]);
    }
    return int.tryParse(d) ?? 5;
  }

  String get _elapsedString {
    final total = _parseDuration(widget.message.voiceDuration ?? '0:05');
    final elapsed = (total * _progress).floor();
    final m = (elapsed ~/ 60).toString();
    final s = (elapsed % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get _totalDuration => widget.message.voiceDuration ?? '0:05';

  @override
  Widget build(BuildContext context) {
    final isMe = widget.message.isMe;
    final brightness = Theme.of(context).brightness;
    final textSecondary = KoraColors.textSecondaryFor(brightness);

    final iconColor = isMe ? Colors.white : KoraColors.purple;
    final playedColor = isMe ? Colors.white : KoraColors.purple;
    final unplayedColor = isMe
        ? Colors.white.withValues(alpha: 0.25)
        : KoraColors.purple.withValues(alpha: 0.2);
    final durationColor = isMe ? Colors.white.withValues(alpha: 0.7) : textSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Play / Pause ──
            GestureDetector(
              onTap: _togglePlay,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: isMe ? null : KoraColors.brandGradient,
                  color: isMe ? Colors.white.withValues(alpha: 0.15) : null,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: iconColor,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // ── Waveform ──
            Flexible(
              child: SizedBox(
                width: 140,
                height: 30,
                child: KoraWaveform(
                  isLive: false,
                  progress: _progress,
                  barCount: 30,
                  height: 30,
                  barWidth: 2.5,
                  barGap: 2.5,
                  playedColor: playedColor,
                  unplayedColor: unplayedColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // ── Duration ──
            Text(
              _isPlaying ? '$_elapsedString / $_totalDuration' : _totalDuration,
              style: TextStyle(
                color: durationColor,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // ── Translate / Transcribe action ──
        if (widget.onTranslate != null)
          GestureDetector(
            onTap: widget.onTranslate,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.language_rounded,
                  size: 13,
                  color: isMe ? Colors.white.withValues(alpha: 0.7) : KoraColors.purple,
                ),
                const SizedBox(width: 4),
                Text(
                  'Transcribe & Translate',
                  style: TextStyle(
                    color: isMe ? Colors.white.withValues(alpha: 0.7) : KoraColors.purple,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

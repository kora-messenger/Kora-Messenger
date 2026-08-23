import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import '../../widgets/kora_waveform.dart';
import '../../services/audio_playback_service.dart';

/// Voice preview bar — shown after recording, before sending.
/// Lets the user play back, discard, or send the recorded voice note.
///
/// Uses the unified [AudioPlaybackService.stateStream].
class VoicePreviewBar extends StatefulWidget {
  final String duration;
  final String? filePath;
  final VoidCallback onDiscard;
  final VoidCallback onSend;

  const VoicePreviewBar({
    super.key,
    required this.duration,
    this.filePath,
    required this.onDiscard,
    required this.onSend,
  });

  @override
  State<VoicePreviewBar> createState() => _VoicePreviewBarState();
}

class _VoicePreviewBarState extends State<VoicePreviewBar>
    with SingleTickerProviderStateMixin {
  final _playback = AudioPlaybackService.instance;
  StreamSubscription<PlaybackState>? _sub;
  late AnimationController _slideController;

  bool _isPlaying = false;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideController.forward();

    _sub = _playback.stateStream.listen((state) {
      if (!mounted) return;
      // Only update if this preview's file is the active one
      if (state.playingId == 'preview') {
        setState(() {
          _isPlaying = state.isPlaying;
          _progress = state.progress;
          if (state.isCompleted) _progress = 0.0;
        });
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _playback.stopIfActive('preview');
    _slideController.dispose();
    super.dispose();
  }

  int _parseDuration(String d) {
    final parts = d.split(':');
    if (parts.length == 2) return int.parse(parts[0]) * 60 + int.parse(parts[1]);
    return int.tryParse(d) ?? 5;
  }

  String get _elapsedString {
    final total = _parseDuration(widget.duration);
    final elapsed = (total * _progress).floor();
    final m = (elapsed ~/ 60).toString();
    final s = (elapsed % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _togglePlay() async {
    final path = widget.filePath;
    if (path == null) return;

    if (_isPlaying) {
      await _playback.pause();
    } else {
      await _playback.play(path, messageId: 'preview');
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final surface = KoraColors.cardFor(brightness);
    final border = KoraColors.borderFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(_slideController),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: border, width: 0.5),
        ),
        child: Row(
          children: [
            // Delete
            GestureDetector(
              onTap: widget.onDiscard,
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
            const SizedBox(width: 12),
            // Play/Pause
            GestureDetector(
              onTap: _togglePlay,
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  gradient: KoraColors.brandGradient,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Waveform + duration
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final waveWidth = constraints.maxWidth.isFinite
                          ? constraints.maxWidth
                          : 200.0;
                      return GestureDetector(
                        onTapDown: (details) {
                          final fraction =
                              (details.localPosition.dx / waveWidth)
                                  .clamp(0.0, 1.0);
                          _playback.seekToFraction(fraction);
                        },
                        child: SizedBox(
                          width: waveWidth,
                          height: 30,
                          child: KoraWaveform(
                            isLive: false,
                            progress: _progress,
                            barCount: 40,
                            height: 30,
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
                  const SizedBox(height: 4),
                  Text(
                    _isPlaying
                        ? '$_elapsedString / ${widget.duration}'
                        : widget.duration,
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Send
            GestureDetector(
              onTap: widget.onSend,
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
      ),
    );
  }
}

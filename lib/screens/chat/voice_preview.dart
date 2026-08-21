import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import '../../widgets/kora_waveform.dart';
import '../../services/audio_playback_service.dart';
import 'package:just_audio/just_audio.dart';

/// Kora's voice preview bar — shown after recording, before sending.
///
/// Uses [AudioPlaybackService] to play the actual recorded audio file
/// with real position/duration streams for the waveform progress.
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
    with TickerProviderStateMixin {
  final _playbackService = AudioPlaybackService.instance;

  bool _isPlaying = false;
  double _progress = 0.0;
  late AnimationController _slideController;
  StreamSubscription? _positionSub;
  StreamSubscription? _stateSub;
  Duration? _audioDuration;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideController.forward();

    // Listen to position updates for waveform progress
    _positionSub = _playbackService.positionStream.listen((pos) {
      if (_audioDuration != null && _audioDuration!.inMilliseconds > 0 && mounted) {
        setState(() {
          _progress = pos.inMilliseconds / _audioDuration!.inMilliseconds;
        });
      }
    });

    // Listen to playback state changes
    _stateSub = _playbackService.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed && mounted) {
        setState(() {
          _isPlaying = false;
          _progress = 0.0;
        });
      }
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _stateSub?.cancel();
    if (_isPlaying) _playbackService.stop();
    _slideController.dispose();
    super.dispose();
  }

  int _parseDuration(String d) {
    final parts = d.split(':');
    if (parts.length == 2) {
      return int.parse(parts[0]) * 60 + int.parse(parts[1]);
    }
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
    if (widget.filePath == null) {
      // Fallback to simulation if no file
      setState(() => _isPlaying = !_isPlaying);
      if (_isPlaying) _simulatePlayback();
      return;
    }

    if (_isPlaying) {
      await _playbackService.pause();
      setState(() => _isPlaying = false);
    } else {
      await _playbackService.play(widget.filePath!);
      _audioDuration = _playbackService.duration;
      setState(() => _isPlaying = true);
    }
  }

  void _simulatePlayback() {
    if (_progress >= 1.0) _progress = 0.0;
    final totalSecs = _parseDuration(widget.duration);
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
            // ── Delete ──
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
            // ── Play/Pause ──
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
            // ── Waveform + duration ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 30,
                    child: KoraWaveform(
                      isLive: false,
                      progress: _progress,
                      barCount: 40,
                      height: 30,
                      barWidth: 2.5,
                      barGap: 2.5,
                      playedColor: KoraColors.purple,
                      unplayedColor: KoraColors.purple.withValues(alpha: 0.2),
                    ),
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
            // ── Send ──
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

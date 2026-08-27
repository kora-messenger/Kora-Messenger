import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import '../../widgets/kora_waveform.dart';
import '../../services/audio_playback_service.dart';

/// Voice note preview — shown after recording stops, before sending.
///
/// Lets the user listen to the recording, see the waveform with playback
/// progress, check the duration, delete (discard), or send it.
///
/// Uses [AudioPlaybackService] for real audio playback via `just_audio`.
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
  bool _isPlaying = false;
  double _progress = 0.0;
  late AnimationController _slideController;
  final _playbackService = AudioPlaybackService.instance;
  StreamSubscription? _positionSub;
  StreamSubscription? _stateSub;
  Duration? _audioDuration;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();

    // Load the audio file if available
    if (widget.filePath != null) {
      _playbackService.load(widget.filePath!).then((_) {
        _audioDuration = _playbackService.duration;
      });
    }

    // Listen to position updates
    _positionSub = _playbackService.positionStream.listen((pos) {
      if (_audioDuration != null && _audioDuration!.inMilliseconds > 0) {
        setState(() {
          _progress = pos.inMilliseconds / _audioDuration!.inMilliseconds;
        });
      }
    });

    // Listen to playback state changes
    _stateSub = _playbackService.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
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
    _playbackService.stop();
    _slideController.dispose();
    super.dispose();
  }

  void _togglePlay() async {
    if (widget.filePath == null) {
      // Fallback: simulate playback if no file
      setState(() => _isPlaying = !_isPlaying);
      if (_isPlaying) {
        _simulatePlayback();
      }
      return;
    }

    if (_isPlaying) {
      await _playbackService.pause();
      setState(() => _isPlaying = false);
    } else {
      await _playbackService.play(widget.filePath!);
      setState(() => _isPlaying = true);
    }
  }

  void _simulatePlayback() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!_isPlaying || !mounted) return;
      setState(() => _progress += 0.02);
      if (_progress >= 1.0) {
        setState(() {
          _isPlaying = false;
          _progress = 0.0;
        });
      } else {
        _simulatePlayback();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.3),
        end: Offset.zero,
      ).animate(_slideController),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            // Discard button
            GestureDetector(
              onTap: widget.onDiscard,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: KoraColors.red.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.delete_outline, color: KoraColors.red, size: 22),
              ),
            ),

            const SizedBox(width: 12),

            // Play/pause button
            GestureDetector(
              onTap: _togglePlay,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: KoraColors.brandGradient,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Waveform with progress
            Expanded(
              child: KoraWaveform(
                data: List.generate(50, (i) => 0.3 + (i % 5) * 0.12),
                progress: _progress,
                isLive: false,
                barColor: KoraColors.purple,
              ),
            ),

            const SizedBox(width: 12),

            // Duration
            Text(
              widget.duration,
              style: TextStyle(
                color: textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(width: 12),

            // Send button
            GestureDetector(
              onTap: widget.onSend,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: KoraColors.brandGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

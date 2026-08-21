import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/message_model.dart';
import '../../models/chat_models.dart';
import '../../theme/kora_colors.dart';
import '../../widgets/kora_waveform.dart';
import 'voice_translation_sheet.dart';
import '../../services/audio_playback_service.dart';
import 'package:just_audio/just_audio.dart';

/// Kora's voice message bubble — used inside MessageBubble for voice messages.
///
/// Shows: play/pause button, waveform with playback progress, duration,
/// and a Translate / Transcribe action that opens the translation sheet.
///
/// When a voice note is pending offline upload ([MessageStatus.pendingOffline]),
/// the play button is replaced with a download/sync arrow icon, the waveform
/// is dimmed, and a subtle "Waiting for network" indicator is shown.
///
/// Uses [AudioPlaybackService] for real audio playback via `just_audio`.
class VoiceMessageBubble extends StatefulWidget {
  final KoraMessage message;
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
  late AnimationController _syncSpinController;

  final _playbackService = AudioPlaybackService.instance;
  StreamSubscription? _positionSub;
  StreamSubscription? _stateSub;
  Duration? _audioDuration;

  @override
  void initState() {
    super.initState();
    _syncSpinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _positionSub = _playbackService.positionStream.listen((pos) {
      if (_audioDuration != null && _audioDuration!.inMilliseconds > 0 && mounted) {
        setState(() {
          _progress = pos.inMilliseconds / _audioDuration!.inMilliseconds;
        });
      }
    });

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
    _syncSpinController.dispose();
    super.dispose();
  }

  bool get _isPendingOffline =>
      widget.message.status == MessageStatus.pendingOffline;

  void _togglePlay() async {
    if (_isPendingOffline) return;

    final path = widget.message.voiceFilePath;
    if (path == null) {
      // Fallback: simulate playback for demo/incoming messages without a file
      setState(() => _isPlaying = !_isPlaying);
      if (_isPlaying) _simulatePlayback();
      return;
    }

    if (_isPlaying) {
      await _playbackService.pause();
      setState(() => _isPlaying = false);
    } else {
      await _playbackService.play(path);
      _audioDuration = _playbackService.duration;
      setState(() => _isPlaying = true);
    }
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

    if (_isPendingOffline) {
      return _buildPendingOfflineView(isMe, brightness);
    }

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
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () {
                VoiceTranslationSheet.show(
                  context,
                  voiceDuration: widget.message.voiceDuration ?? '0:05',
                  autoTranslate: false,
                  voiceId: widget.message.id,
                  transcript: widget.message.voiceTranscript,
                );
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.mic_outlined,
                    size: 13,
                    color: isMe ? Colors.white.withValues(alpha: 0.7) : KoraColors.purple,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    'Transcribe',
                    style: TextStyle(
                      color: isMe ? Colors.white.withValues(alpha: 0.7) : KoraColors.purple,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () {
                VoiceTranslationSheet.show(
                  context,
                  voiceDuration: widget.message.voiceDuration ?? '0:05',
                  autoTranslate: true,
                  voiceId: widget.message.id,
                  transcript: widget.message.voiceTranscript,
                );
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.translate_rounded,
                    size: 13,
                    color: isMe ? Colors.white.withValues(alpha: 0.7) : KoraColors.purple,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    'Translate Voice',
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
        ),
      ],
    );
  }

  Widget _buildPendingOfflineView(bool isMe, Brightness brightness) {
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);

    final iconColor = isMe ? Colors.white.withValues(alpha: 0.8) : KoraColors.purple;
    final waveformColor = isMe
        ? Colors.white.withValues(alpha: 0.18)
        : KoraColors.purple.withValues(alpha: 0.15);
    final durationColor = isMe ? Colors.white.withValues(alpha: 0.5) : textMuted;
    final labelColor = isMe ? Colors.white.withValues(alpha: 0.55) : textSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isMe
                    ? Colors.white.withValues(alpha: 0.12)
                    : KoraColors.purple.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_downward_rounded,
                color: iconColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: SizedBox(
                width: 140,
                height: 30,
                child: KoraWaveform(
                  isLive: false,
                  progress: 0,
                  barCount: 30,
                  height: 30,
                  barWidth: 2.5,
                  barGap: 2.5,
                  playedColor: waveformColor,
                  unplayedColor: waveformColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              widget.message.voiceDuration ?? '0:05',
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
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation<Color>(iconColor),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Waiting for network…',
              style: TextStyle(
                color: labelColor,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

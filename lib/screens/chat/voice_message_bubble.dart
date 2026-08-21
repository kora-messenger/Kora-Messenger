import 'package:flutter/material.dart';
import '../../models/message_model.dart';
import '../../models/chat_models.dart';
import '../../theme/kora_colors.dart';
import '../../widgets/kora_waveform.dart';
import 'voice_translation_sheet.dart';

/// Kora's voice message bubble — used inside MessageBubble for voice messages.
///
/// Shows: play/pause button, waveform with playback progress, duration,
/// and a Translate / Transcribe action that opens the translation sheet.
///
/// When a voice note is pending offline upload ([MessageStatus.pendingOffline]),
/// the play button is replaced with a download/sync arrow icon, the waveform
/// is dimmed, and a subtle "Waiting for network" indicator is shown.
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

  /// Sync arrow rotation animation — spins while uploading.
  late AnimationController _syncSpinController;

  @override
  void initState() {
    super.initState();
    _syncSpinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void dispose() {
    _syncSpinController.dispose();
    super.dispose();
  }

  bool get _isPendingOffline =>
      widget.message.status == MessageStatus.pendingOffline;

  void _togglePlay() {
    if (_isPendingOffline) return; // No playback while pending
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

    // If the voice note is pending offline upload, show the sync state
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
        // ── Transcribe + Translate Voice actions ──
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () {
                VoiceTranslationSheet.show(
                  context,
                  voiceDuration: widget.message.voiceDuration ?? '0:05',
                  autoTranslate: false,
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

  /// Builds the pending offline view — shows a sync/download arrow
  /// instead of the play button, with a dimmed waveform and a
  /// "Waiting for network" indicator.
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
            // ── Sync / Download arrow (replaces play button) ──
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
            // ── Dimmed waveform ──
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
            // ── Duration ──
            Text(
              _totalDuration,
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
        // ── "Waiting for network" indicator ──
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 12,
              color: labelColor,
            ),
            const SizedBox(width: 4),
            Text(
              'Waiting for network',
              style: TextStyle(
                color: labelColor,
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

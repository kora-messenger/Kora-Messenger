import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import '../../widgets/kora_waveform.dart';
import '../../services/audio_recording_service.dart';

/// Kora's voice recording interface — replaces the composer while recording.
///
/// Uses [AudioRecordingService] for real microphone recording.
/// Shows: pulsing record indicator, live timer, live waveform (from
/// real amplitude data), delete (cancel) button on the left, and a
/// send button on the right.
class VoiceRecorderBar extends StatefulWidget {
  final VoidCallback onCancel;
  final void Function(String duration, String? filePath) onSend;

  const VoiceRecorderBar({
    super.key,
    required this.onCancel,
    required this.onSend,
  });

  @override
  State<VoiceRecorderBar> createState() => _VoiceRecorderBarState();
}

class _VoiceRecorderBarState extends State<VoiceRecorderBar>
    with TickerProviderStateMixin {
  final _recordingService = AudioRecordingService.instance;

  int _seconds = 0;
  Timer? _timer;
  Timer? _amplitudeTimer;
  final List<double> _waveformSamples = [];
  String? _filePath;

  late AnimationController _slideController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _slideController.forward();
    _pulseController.repeat(reverse: true);
    _startRecording();
  }

  void _startRecording() async {
    try {
      _filePath = await _recordingService.startRecording();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _seconds++);
      });

      _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 80), (_) async {
        if (!mounted || !_recordingService.isRecording) return;
        final amp = await _recordingService.getAmplitude();
        if (mounted) {
          setState(() {
            _waveformSamples.add(amp);
            if (_waveformSamples.length > 60) {
              _waveformSamples.removeAt(0);
            }
          });
        }
      });
    } catch (e) {
      if (mounted) widget.onCancel();
    }
  }

  String get _durationString {
    final m = (_seconds ~/ 60).toString();
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _cancel() async {
    _timer?.cancel();
    _amplitudeTimer?.cancel();
    await _recordingService.cancelRecording();
    _pulseController.stop();
    widget.onCancel();
  }

  void _send() async {
    _timer?.cancel();
    _amplitudeTimer?.cancel();
    _pulseController.stop();
    final path = await _recordingService.stopRecording();
    widget.onSend(_durationString, path ?? _filePath);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _amplitudeTimer?.cancel();
    _slideController.dispose();
    _pulseController.dispose();
    if (_recordingService.isRecording) {
      _recordingService.cancelRecording();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final surface = KoraColors.cardFor(brightness);
    final border = KoraColors.borderFor(brightness);

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
            GestureDetector(
              onTap: _cancel,
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ScaleTransition(
                        scale: Tween(begin: 0.8, end: 1.2).animate(
                          CurvedAnimation(
                            parent: _pulseController,
                            curve: Curves.easeInOut,
                          ),
                        ),
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: KoraColors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Recording',
                        style: TextStyle(
                          color: KoraColors.red,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _durationString,
                        style: TextStyle(
                          color: KoraColors.textSecondaryFor(brightness),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 30,
                    child: KoraWaveform(
                      isLive: true,
                      progress: 0,
                      barCount: 40,
                      height: 30,
                      barWidth: 2.5,
                      barGap: 2.5,
                      playedColor: KoraColors.purple,
                      unplayedColor: KoraColors.purple.withValues(alpha: 0.2),
                      liveAmplitudes: _waveformSamples,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _send,
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

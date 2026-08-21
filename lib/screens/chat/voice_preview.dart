import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import '../../widgets/kora_waveform.dart';

/// Voice note preview — shown after recording stops, before sending.
///
/// Lets the user listen to the recording, see the waveform with playback
/// progress, check the duration, delete (discard), or send it.
///
/// Since real audio isn't connected yet, playback is simulated with a
/// timer that advances the waveform progress bar.
class VoicePreviewBar extends StatefulWidget {
  final String duration;
  final VoidCallback onDiscard;
  final VoidCallback onSend;

  const VoicePreviewBar({
    super.key,
    required this.duration,
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
  late List<double> _waveformData;

  @override
  void initState() {
    super.initState();
    _waveformData = generateWaveformData(44);
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  void _togglePlay() {
    setState(() => _isPlaying = !_isPlaying);
    if (_isPlaying) {
      _simulatePlayback();
    }
  }

  void _simulatePlayback() {
    if (_progress >= 1.0) _progress = 0.0;
    const stepMs = 80;
    final totalSecs = _parseDuration(widget.duration);
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
    final total = _parseDuration(widget.duration);
    final elapsed = (total * _progress).floor();
    final m = (elapsed ~/ 60).toString();
    final s = (elapsed % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.3),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut)),
      child: FadeTransition(
        opacity: Tween(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOut),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: KoraColors.cardFor(brightness),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              // ── Play / Pause ──
              GestureDetector(
                onTap: _togglePlay,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: KoraColors.brandGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: KoraColors.purple.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // ── Waveform + duration ──
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    KoraWaveform(
                      isLive: false,
                      progress: _progress,
                      barCount: 44,
                      height: 28,
                      barWidth: 2.5,
                      barGap: 2.5,
                      playedColor: KoraColors.purple,
                      unplayedColor: KoraColors.purple.withValues(alpha: 0.2),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          _elapsedString,
                          style: TextStyle(
                            color: textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '· ${widget.duration}',
                          style: TextStyle(
                            color: textMuted.withValues(alpha: 0.6),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // ── Discard ──
              GestureDetector(
                onTap: widget.onDiscard,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: KoraColors.red.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: KoraColors.red,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // ── Send ──
              GestureDetector(
                onTap: widget.onSend,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    gradient: KoraColors.brandGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x558B5CF6),
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ],
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
      ),
    );
  }
}

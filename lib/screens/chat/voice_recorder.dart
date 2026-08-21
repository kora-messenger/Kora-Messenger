import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import '../../widgets/kora_waveform.dart';

/// Kora's voice recording interface — replaces the composer while recording.
///
/// Shows: pulsing record indicator, live timer, live waveform,
/// delete (cancel) button on the left, and a send button on the right.
///
/// Interaction: tap mic to start, tap delete to cancel (with animation),
/// tap send to finish recording and pass it to the preview stage.
class VoiceRecorderBar extends StatefulWidget {
  final VoidCallback onCancel;
  final void Function(String duration) onSend;

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
  int _seconds = 0;
  Timer? _timer;
  late AnimationController _slideController;
  late AnimationController _cancelController;
  late Animation<Offset> _slideIn;

  @override
  void initState() {
    super.initState();
    _startTimer();

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideIn = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    _slideController.forward();

    _cancelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  String get _durationString {
    final m = (_seconds ~/ 60).toString();
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _cancel() {
    _timer?.cancel();
    _cancelController.forward().then((_) {
      if (mounted) widget.onCancel();
    });
  }

  void _send() {
    _timer?.cancel();
    widget.onSend(_durationString);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _slideController.dispose();
    _cancelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);

    return SlideTransition(
      position: _slideIn,
      child: FadeTransition(
        opacity: Tween(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOut),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: KoraColors.cardFor(brightness),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              // ── Delete / cancel ──
              GestureDetector(
                onTap: _cancel,
                child: ScaleTransition(
                  scale: Tween(begin: 1.0, end: 0.8).animate(
                    CurvedAnimation(parent: _cancelController, curve: Curves.easeIn),
                  ),
                  child: FadeTransition(
                    opacity: Tween(begin: 1.0, end: 0.0).animate(_cancelController),
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
                ),
              ),
              const SizedBox(width: 12),
              // ── Recording indicator + timer ──
              _PulsingDot(),
              const SizedBox(width: 8),
              Text(
                _durationString,
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'Recording',
                style: TextStyle(
                  color: textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              // ── Live waveform ──
              const SizedBox(width: 12),
              Expanded(
                child: KoraWaveform(
                  isLive: true,
                  barCount: 28,
                  height: 32,
                  barWidth: 2.5,
                  barGap: 2.5,
                  playedColor: KoraColors.purple,
                ),
              ),
              const SizedBox(width: 12),
              // ── Send ──
              GestureDetector(
                onTap: _send,
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

/// Animated pulsing dot used as the recording indicator.
class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            color: KoraColors.red.withValues(alpha: 0.4 + _controller.value * 0.6),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: KoraColors.red.withValues(alpha: _controller.value * 0.3),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
        );
      },
    );
  }
}

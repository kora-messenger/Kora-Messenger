import 'dart:math';
import 'package:flutter/material.dart';

/// Kora's reusable waveform visualization.
///
/// Two modes:
/// 1. **Live** — animated random bars that simulate mic input while recording.
/// 2. **Playback** — static bars where a `progress` value (0–1) determines
///    which bars are "played" (brighter) vs "unplayed" (dimmer).
///
/// The waveform uses Kora's purple-to-blue identity for the played portion
/// and a muted translucent fill for the unplayed portion.
class KoraWaveform extends StatefulWidget {
  /// Number of bars to render.
  final int barCount;

  /// If true, bars animate to simulate live microphone input.
  final bool isLive;

  /// Playback progress 0.0 – 1.0. Only meaningful when [isLive] is false.
  final double progress;

  /// Color of the played (progress) portion. Defaults to white at 90% opacity.
  final Color? playedColor;

  /// Color of the unplayed portion.
  final Color? unplayedColor;

  /// Accent gradient colors for the played portion (Kora purple → blue).
  /// If provided, played bars use a gradient instead of a flat color.
  final List<Color>? gradientColors;

  /// Bar width in px.
  final double barWidth;

  /// Gap between bars in px.
  final double barGap;

  /// Height of the waveform. If null, fills parent.
  final double? height;

  const KoraWaveform({
    super.key,
    this.barCount = 40,
    this.isLive = false,
    this.progress = 0.0,
    this.playedColor,
    this.unplayedColor,
    this.gradientColors,
    this.barWidth = 2.5,
    this.barGap = 3.0,
    this.height,
  });

  @override
  State<KoraWaveform> createState() => _KoraWaveformState();
}

class _KoraWaveformState extends State<KoraWaveform>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late List<double> _barHeights;
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _barHeights = List.generate(widget.barCount, (_) => 0.3 + _rng.nextDouble() * 0.7);
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    if (widget.isLive) _animController.repeat();
  }

  @override
  void didUpdateWidget(KoraWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLive && !_animController.isAnimating) {
      _animController.repeat();
    } else if (!widget.isLive && _animController.isAnimating) {
      _animController.stop();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.height;
    return SizedBox(
      height: h,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _animController,
        builder: (context, _) {
          return CustomPaint(
            painter: _KoraWaveformPainter(
              barHeights: _barHeights,
              isLive: widget.isLive,
              progress: widget.progress,
              playedColor: widget.playedColor,
              unplayedColor: widget.unplayedColor,
              gradientColors: widget.gradientColors,
              barWidth: widget.barWidth,
              barGap: widget.barGap,
              animValue: _animController.value,
              rng: _rng,
            ),
          );
        },
      ),
    );
  }
}

class _KoraWaveformPainter extends CustomPainter {
  final List<double> barHeights;
  final bool isLive;
  final double progress;
  final Color? playedColor;
  final Color? unplayedColor;
  final List<Color>? gradientColors;
  final double barWidth;
  final double barGap;
  final double animValue;
  final Random rng;

  _KoraWaveformPainter({
    required this.barHeights,
    required this.isLive,
    required this.progress,
    this.playedColor,
    this.unplayedColor,
    this.gradientColors,
    required this.barWidth,
    required this.barGap,
    required this.animValue,
    required this.rng,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final totalWidth = size.width;
    final totalBars = barHeights.length;
    final actualBarWidth = (totalWidth - barGap * (totalBars - 1)) / totalBars;
    final w = actualBarWidth < barWidth ? actualBarWidth : barWidth;
    final center = size.height / 2;

    for (int i = 0; i < totalBars; i++) {
      double heightFraction;

      if (isLive) {
        // Simulate live mic input — randomize heights each frame
        heightFraction = 0.15 + rng.nextDouble() * 0.85;
      } else {
        heightFraction = barHeights[i];
      }

      final h = heightFraction * size.height * 0.85;
      final x = i * (actualBarWidth + barGap);
      final y = center - h / 2;

      final isPlayed = (i / totalBars) <= progress;

      Color color;
      if (isLive) {
        // Live recording — all bars use played color
        color = playedColor ?? const Color(0xFFFFFFFF).withValues(alpha: 0.9);
      } else if (isPlayed) {
        color = playedColor ?? const Color(0xFFFFFFFF).withValues(alpha: 0.9);
      } else {
        color = unplayedColor ??
            const Color(0xFFFFFFFF).withValues(alpha: 0.25);
      }

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, w, h),
          Radius.circular(w / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _KoraWaveformPainter oldDelegate) => true;
}

/// Generates pseudo-random bar heights for a static waveform.
/// Used to seed consistent waveform shapes for voice messages.
List<double> generateWaveformData(int count, {int? seed}) {
  final rng = Random(seed ?? DateTime.now().millisecondsSinceEpoch);
  return List.generate(count, (_) => 0.2 + rng.nextDouble() * 0.8);
}

import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import '../../widgets/kora_waveform.dart';
import '../../services/audio_recording_service.dart';

/// The popup voice-note bar for Kora Messenger.
///
/// Opens as a bottom sheet when:
/// - User taps the mic (starts recording immediately)
/// - User press-and-holds the mic then swipes up to lock (recording
///   continues seamlessly — no audio is destroyed)
///
/// Deliberately kept slim and compact — a single row, mirroring the
/// familiar WhatsApp-style recording bar — instead of a tall stacked sheet.
///
/// This widget is fully self-contained for its LIVE state: it runs its
/// own timer and listens directly to [AudioRecordingService]'s amplitude
/// stream, so the timer and waveform keep updating and the pause button
/// responds instantly — regardless of whether the parent composer widget
/// (which lives in a different route/subtree) rebuilds.
///
/// Only closes when the user taps Delete or Send.
class VoiceNotePopup extends StatefulWidget {
  final int initialSeconds;
  final List<double> initialWaveformSamples;
  final String? filePath;
  final bool isPaused;

  // Callbacks — all wired to the composer's recording state
  final VoidCallback onDiscard;
  final VoidCallback onTogglePause;
  final VoidCallback onSend;
  final VoidCallback? onTranslate;
  final String? selectedTranslateName;
  final bool isTranslating;
  final bool isPlayOnce;
  final VoidCallback? onTogglePlayOnce;

  // Paused-preview playback
  final bool isPreviewPlaying;
  final double previewProgress;
  final int previewPositionMs;
  final int previewDurationMs;
  final double previewSpeed;
  final VoidCallback? onTogglePreviewPlay;
  final void Function(double fraction)? onSeekPreview;
  final VoidCallback? onCyclePreviewSpeed;

  // Live update callbacks so the popup stays in sync with the composer
  final ValueChanged<int>? onSecondsChanged;
  final ValueChanged<List<double>>? onWaveformChanged;

  const VoiceNotePopup({
    super.key,
    required this.initialSeconds,
    required this.initialWaveformSamples,
    required this.filePath,
    required this.isPaused,
    required this.onDiscard,
    required this.onTogglePause,
    required this.onSend,
    this.onTranslate,
    this.selectedTranslateName,
    this.isTranslating = false,
    this.isPlayOnce = false,
    this.onTogglePlayOnce,
    this.isPreviewPlaying = false,
    this.previewProgress = 0.0,
    this.previewPositionMs = 0,
    this.previewDurationMs = 0,
    this.previewSpeed = 1.0,
    this.onTogglePreviewPlay,
    this.onSeekPreview,
    this.onCyclePreviewSpeed,
    this.onSecondsChanged,
    this.onWaveformChanged,
  });

  @override
  State<VoiceNotePopup> createState() => _VoiceNotePopupState();
}

class _VoiceNotePopupState extends State<VoiceNotePopup> {
  late int _seconds;
  late List<double> _waveformSamples;
  late bool _isPaused;

  Timer? _ticker;
  StreamSubscription<double>? _amplitudeSub;

  static const int _maxSamples = 40;

  @override
  void initState() {
    super.initState();
    _seconds = widget.initialSeconds;
    _waveformSamples = List.from(widget.initialWaveformSamples);
    _isPaused = widget.isPaused;

    if (!_isPaused) {
      _startTicker();
      _listenToAmplitude();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _amplitudeSub?.cancel();
    super.dispose();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _isPaused) return;
      setState(() => _seconds++);
      widget.onSecondsChanged?.call(_seconds);
    });
  }

  void _listenToAmplitude() {
    _amplitudeSub?.cancel();
    _amplitudeSub = AudioRecordingService.instance.amplitudeStream.listen((amp) {
      if (!mounted || _isPaused) return;
      setState(() {
        _waveformSamples.add(amp);
        if (_waveformSamples.length > _maxSamples) {
          _waveformSamples.removeAt(0);
        }
      });
      widget.onWaveformChanged?.call(_waveformSamples);
    });
  }

  /// Toggles pause/resume. Updates local state IMMEDIATELY for instant
  /// visual feedback, then notifies the composer to actually pause/resume
  /// the underlying audio recorder.
  void _handleTogglePause() {
    final goingToPause = !_isPaused;
    setState(() => _isPaused = goingToPause);

    if (goingToPause) {
      _ticker?.cancel();
      _amplitudeSub?.cancel();
      _amplitudeSub = null;
    } else {
      _startTicker();
      _listenToAmplitude();
    }

    widget.onTogglePause();
  }

  String get _durationString => _fmt(_seconds * 1000);

  String _fmt(int ms) {
    final totalSeconds = (ms / 1000).round();
    final m = (totalSeconds ~/ 60).toString();
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get _previewTotalString =>
      widget.previewDurationMs > 0 ? _fmt(widget.previewDurationMs) : _durationString;

  String get _previewElapsedString => _fmt(widget.previewPositionMs);

  String get _speedLabel {
    if (widget.previewSpeed == 1.5) return '1.5x';
    if (widget.previewSpeed == 2.0) return '2x';
    return '1x';
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final surface = KoraColors.surfaceFor(brightness);
    final border = KoraColors.borderFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: border, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Drag handle ──
              Container(
                width: 32,
                height: 3,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // ── Status badges (play-once / translating) ──
              if (widget.selectedTranslateName != null || widget.isPlayOnce)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.isPlayOnce) ...[
                        Icon(Icons.lock_clock_rounded, size: 13, color: KoraColors.purple),
                        const SizedBox(width: 4),
                        const Text(
                          'Play once',
                          style: TextStyle(
                            color: KoraColors.purple,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (widget.selectedTranslateName != null) const SizedBox(width: 14),
                      ],
                      if (widget.selectedTranslateName != null) ...[
                        Icon(Icons.language_rounded, size: 13, color: KoraColors.purple),
                        const SizedBox(width: 4),
                        Text(
                          'Translating to ${widget.selectedTranslateName}',
                          style: const TextStyle(
                            color: KoraColors.purple,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

              // ── Single compact row: delete | timer | waveform | pause | translate | send ──
              Row(
                children: [
                  _iconButton(
                    icon: Icons.delete_outline_rounded,
                    color: KoraColors.red,
                    bgColor: KoraColors.red.withValues(alpha: 0.12),
                    onTap: widget.onDiscard,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: KoraColors.purple.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Text(
                            widget.isPaused ? _previewElapsedString : _durationString,
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                          if (widget.isPaused)
                            Text(
                              ' / $_previewTotalString',
                              style: TextStyle(
                                color: textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SizedBox(
                              height: 26,
                              child: widget.isPaused
                                  ? _buildScrubWaveform(border, textMuted)
                                  : _buildLiveWaveform(),
                            ),
                          ),
                          if (widget.isPaused && widget.onCyclePreviewSpeed != null)
                            GestureDetector(
                              onTap: widget.onCyclePreviewSpeed,
                              child: Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: KoraColors.purple.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  _speedLabel,
                                  style: const TextStyle(
                                    color: KoraColors.purple,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    fontFeatures: [FontFeature.tabularFigures()],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // ── Pause / Resume / Preview-play ──
                  if (widget.isPaused) ...[
                    _iconButton(
                      icon: widget.isPreviewPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: KoraColors.purple,
                      bgColor: KoraColors.purple.withValues(alpha: 0.14),
                      onTap: widget.onTogglePreviewPlay,
                    ),
                    const SizedBox(width: 8),
                    _iconButton(
                      icon: Icons.mic_rounded,
                      color: Colors.white,
                      gradient: KoraColors.brandGradient,
                      onTap: _handleTogglePause,
                    ),
                  ] else
                    _iconButton(
                      icon: Icons.pause_rounded,
                      color: KoraColors.purple,
                      bgColor: KoraColors.purple.withValues(alpha: 0.14),
                      onTap: _handleTogglePause,
                    ),

                  if (widget.onTranslate != null) ...[
                    const SizedBox(width: 8),
                    _iconButton(
                      icon: Icons.language_rounded,
                      color: widget.selectedTranslateName != null ? KoraColors.purple : textMuted,
                      bgColor: widget.selectedTranslateName != null
                          ? KoraColors.purple.withValues(alpha: 0.18)
                          : surface,
                      hasBorder: widget.selectedTranslateName == null,
                      borderColor: border,
                      onTap: widget.onTranslate,
                    ),
                  ],

                  const SizedBox(width: 8),
                  _iconButton(
                    icon: widget.isTranslating ? Icons.hourglass_top_rounded : Icons.send_rounded,
                    color: Colors.white,
                    gradient: widget.isTranslating ? null : KoraColors.brandGradient,
                    bgColor: widget.isTranslating ? KoraColors.purple.withValues(alpha: 0.4) : null,
                    onTap: widget.isTranslating ? null : widget.onSend,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Live recording waveform — driven by this widget's own amplitude
  // subscription, so it keeps moving regardless of parent rebuilds. ──
  Widget _buildLiveWaveform() {
    return KoraWaveform(
      isLive: true,
      progress: 0,
      barCount: 28,
      height: 26,
      barWidth: 2.5,
      barGap: 2.5,
      playedColor: KoraColors.purple,
      unplayedColor: KoraColors.purple.withValues(alpha: 0.15),
      liveAmplitudes: _waveformSamples,
    );
  }

  // ── Scrubbable paused waveform ──
  Widget _buildScrubWaveform(Color border, Color textMuted) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final waveWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : 150.0;
        return GestureDetector(
          onTapDown: widget.onSeekPreview != null
              ? (details) {
                  final fraction = (details.localPosition.dx / waveWidth).clamp(0.0, 1.0);
                  widget.onSeekPreview!(fraction);
                }
              : null,
          onHorizontalDragUpdate: widget.onSeekPreview != null
              ? (details) {
                  final fraction = (details.localPosition.dx / waveWidth).clamp(0.0, 1.0);
                  widget.onSeekPreview!(fraction);
                }
              : null,
          child: SizedBox(
            width: waveWidth,
            height: 26,
            child: KoraWaveform(
              isLive: false,
              progress: widget.previewProgress,
              barCount: 28,
              height: 26,
              barWidth: 2.5,
              barGap: 2.5,
              playedColor: KoraColors.purple,
              unplayedColor: KoraColors.purple.withValues(alpha: 0.2),
            ),
          ),
        );
      },
    );
  }

  // ── Reusable compact icon-only control button ──
  Widget _iconButton({
    required IconData icon,
    required Color color,
    Color? bgColor,
    LinearGradient? gradient,
    bool hasBorder = false,
    Color? borderColor,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: bgColor,
          gradient: gradient,
          shape: BoxShape.circle,
          border: hasBorder && borderColor != null ? Border.all(color: borderColor, width: 0.6) : null,
        ),
        child: Icon(icon, color: color, size: 19),
      ),
    );
  }
}

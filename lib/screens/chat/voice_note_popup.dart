import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import '../../widgets/kora_waveform.dart';

/// The popup voice-note screen for Kora Messenger.
///
/// Opens as a bottom sheet when:
/// - User taps the mic (starts recording immediately)
/// - User press-and-holds the mic then swipes up to lock (recording
///   continues seamlessly — no audio is destroyed)
///
/// Layout (top to bottom):
/// - Drag handle
/// - Timer (0:00, counting up) or position/duration when paused
/// - Live waveform (recording) or scrubbable waveform (paused preview)
/// - Control row: Delete | Pause/Resume | Translate | Send
/// - When paused: play/pause preview + speed badge + resume button
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

  @override
  void initState() {
    super.initState();
    _seconds = widget.initialSeconds;
    _waveformSamples = List.from(widget.initialWaveformSamples);
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
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: border, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Drag handle ──
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // ── Status badges (play-once / translating) ──
              if (widget.selectedTranslateName != null || widget.isPlayOnce)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.isPlayOnce) ...[
                        Icon(Icons.lock_clock_rounded, size: 14, color: KoraColors.purple),
                        const SizedBox(width: 5),
                        Text(
                          'Play once',
                          style: const TextStyle(
                            color: KoraColors.purple,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (widget.selectedTranslateName != null) const SizedBox(width: 16),
                      ],
                      if (widget.selectedTranslateName != null) ...[
                        Icon(Icons.language_rounded, size: 14, color: KoraColors.purple),
                        const SizedBox(width: 5),
                        Text(
                          'Translating to ${widget.selectedTranslateName}',
                          style: const TextStyle(
                            color: KoraColors.purple,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

              // ── Timer / Position ──
              Text(
                widget.isPaused ? _previewElapsedString : _durationString,
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (widget.isPaused)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '/ $_previewTotalString',
                    style: TextStyle(
                      color: textMuted,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              // ── Waveform area ──
              SizedBox(
                height: 60,
                child: widget.isPaused
                    ? _buildScrubWaveform(border, textMuted)
                    : _buildLiveWaveform(),
              ),

              const SizedBox(height: 12),

              // ── Speed badge (when paused) ──
              if (widget.isPaused && widget.onCyclePreviewSpeed != null)
                GestureDetector(
                  onTap: widget.onCyclePreviewSpeed,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: KoraColors.purple.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _speedLabel,
                      style: const TextStyle(
                        color: KoraColors.purple,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              // ── Control row ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // ── Delete ──
                  _buildControlButton(
                    icon: Icons.delete_outline_rounded,
                    label: 'Delete',
                    color: KoraColors.red,
                    bgColor: KoraColors.red.withValues(alpha: 0.12),
                    onTap: widget.onDiscard,
                  ),

                  // ── Pause / Resume / Play preview ──
                  if (widget.isPaused) ...[
                    // Play/pause preview button
                    _buildControlButton(
                      icon: widget.isPreviewPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      label: widget.isPreviewPlaying ? 'Pause' : 'Play',
                      color: KoraColors.purple,
                      bgColor: KoraColors.purple.withValues(alpha: 0.14),
                      onTap: widget.onTogglePreviewPlay,
                    ),
                    // Resume recording
                    _buildControlButton(
                      icon: Icons.mic_rounded,
                      label: 'Resume',
                      color: Colors.white,
                      bgColor: KoraColors.purple,
                      gradient: KoraColors.brandGradient,
                      onTap: widget.onTogglePause,
                    ),
                  ] else ...[
                    // Pause recording
                    _buildControlButton(
                      icon: Icons.pause_rounded,
                      label: 'Pause',
                      color: KoraColors.purple,
                      bgColor: KoraColors.purple.withValues(alpha: 0.14),
                      onTap: widget.onTogglePause,
                    ),
                  ],

                  // ── Translate ──
                  if (widget.onTranslate != null)
                    _buildControlButton(
                      icon: Icons.language_rounded,
                      label: widget.selectedTranslateName != null
                          ? widget.selectedTranslateName!
                          : 'Translate',
                      color: widget.selectedTranslateName != null
                          ? KoraColors.purple
                          : textMuted,
                      bgColor: widget.selectedTranslateName != null
                          ? KoraColors.purple.withValues(alpha: 0.18)
                          : surface,
                      hasBorder: widget.selectedTranslateName == null,
                      borderColor: border,
                      onTap: widget.onTranslate,
                    ),

                  // ── Send ──
                  _buildControlButton(
                    icon: widget.isTranslating
                        ? Icons.hourglass_top_rounded
                        : Icons.send_rounded,
                    label: 'Send',
                    color: Colors.white,
                    bgColor: KoraColors.purple,
                    gradient: widget.isTranslating ? null : KoraColors.brandGradient,
                    onTap: widget.isTranslating ? null : widget.onSend,
                    boxShadow: widget.isTranslating
                        ? null
                        : [
                            BoxShadow(
                              color: KoraColors.purple.withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Live recording waveform ──
  Widget _buildLiveWaveform() {
    return KoraWaveform(
      isLive: true,
      progress: 0,
      barCount: 40,
      height: 60,
      barWidth: 3,
      barGap: 3,
      playedColor: KoraColors.purple,
      unplayedColor: KoraColors.purple.withValues(alpha: 0.15),
      liveAmplitudes: _waveformSamples,
    );
  }

  // ── Scrubbable paused waveform ──
  Widget _buildScrubWaveform(Color border, Color textMuted) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final waveWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 200.0;
        return GestureDetector(
          onTapDown: widget.onSeekPreview != null
              ? (details) {
                  final fraction =
                      (details.localPosition.dx / waveWidth).clamp(0.0, 1.0);
                  widget.onSeekPreview!(fraction);
                }
              : null,
          onHorizontalDragUpdate: widget.onSeekPreview != null
              ? (details) {
                  final fraction =
                      (details.localPosition.dx / waveWidth).clamp(0.0, 1.0);
                  widget.onSeekPreview!(fraction);
                }
              : null,
          child: SizedBox(
            width: waveWidth,
            height: 60,
            child: KoraWaveform(
              isLive: false,
              progress: widget.previewProgress,
              barCount: 40,
              height: 60,
              barWidth: 3,
              barGap: 3,
              playedColor: KoraColors.purple,
              unplayedColor: KoraColors.purple.withValues(alpha: 0.2),
            ),
          ),
        );
      },
    );
  }

  // ── Reusable control button ──
  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
    LinearGradient? gradient,
    bool hasBorder = false,
    Color? borderColor,
    VoidCallback? onTap,
    List<BoxShadow>? boxShadow,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: bgColor,
              gradient: gradient,
              shape: BoxShape.circle,
              border: hasBorder && borderColor != null
                  ? Border.all(color: borderColor, width: 0.6)
                  : null,
              boxShadow: boxShadow,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

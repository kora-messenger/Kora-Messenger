import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../theme/kora_colors.dart';
import '../../services/audio_recording_service.dart';
import 'attachment_sheet.dart';
import 'voice_recorder.dart';
import 'voice_recorder_locked.dart';

/// Kora's message composer — the bottom input bar.
///
/// States:
/// - **Idle** → text input + mic button (when empty) or send button (when typing)
/// - **Holding** → press-and-hold the mic to record. Shows a live timer +
///   waveform + "slide to cancel" hint, with a lock capsule floating
///   above the mic. Slide left past the threshold to cancel, slide up
///   past the threshold to lock into hands-free recording. Releasing
///   without crossing either threshold sends the note immediately.
/// - **Locked** → hands-free recording continues. Full-width bar with
///   trash (discard), waveform + timer, pause/resume, and send.
///
/// Mic button requests microphone permission with a clear explanation
/// before recording. If denied, shows a message explaining how to enable
/// it from device settings.
class MessageComposer extends StatefulWidget {
  final Function(String) onSend;
  final Function(String duration, {String? filePath}) onSendVoice;
  final VoidCallback? onAttachment;

  const MessageComposer({
    super.key,
    required this.onSend,
    required this.onSendVoice,
    this.onAttachment,
  });

  @override
  State<MessageComposer> createState() => _MessageComposerState();
}

enum _ComposerState { idle, holding, locked }

class _MessageComposerState extends State<MessageComposer>
    with TickerProviderStateMixin {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _hasText = false;
  _ComposerState _state = _ComposerState.idle;

  // ── Recording state ──
  final _recordingService = AudioRecordingService.instance;
  int _seconds = 0;
  Timer? _timer;
  Timer? _amplitudeTimer;
  final List<double> _waveformSamples = [];
  String? _filePath;
  bool _isPaused = false;

  // ── Drag tracking (holding state) ──
  double _dragDx = 0;
  double _dragDy = 0;
  static const double _kCancelThreshold = 120.0;
  static const double _kLockThreshold = 80.0;
  bool _gestureResolved = false; // true once cancelled or locked, ignore further drag updates

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final has = _controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _timer?.cancel();
    _amplitudeTimer?.cancel();
    _pulseController.dispose();
    if (_recordingService.isRecording) {
      _recordingService.cancelRecording();
    }
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
    setState(() => _hasText = false);
  }

  // ── Permission flow ──

  Future<bool> _ensureMicPermission() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) return true;

    if (status.isPermanentlyDenied) {
      if (mounted) _showSettingsPrompt();
      return false;
    }

    final shouldRequest = await _showPermissionDialog();
    if (!shouldRequest) return false;

    final result = await Permission.microphone.request();
    if (result.isGranted) return true;
    if (result.isPermanentlyDenied && mounted) _showSettingsPrompt();
    return false;
  }

  Future<bool> _showPermissionDialog() async {
    final brightness = Theme.of(context).brightness;
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KoraColors.cardFor(brightness),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.mic_rounded, color: KoraColors.purple, size: 24),
            const SizedBox(width: 8),
            Text(
              'Microphone Access',
              style: TextStyle(
                color: KoraColors.textPrimaryFor(brightness),
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Text(
          'Kora needs access to your microphone to record voice notes. '
          'Your recordings are only shared with the people you message.',
          style: TextStyle(
            color: KoraColors.textSecondaryFor(brightness),
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Not now',
              style: TextStyle(color: KoraColors.textMutedFor(brightness)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              backgroundColor: KoraColors.purple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Allow', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showSettingsPrompt() {
    final brightness = Theme.of(context).brightness;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.settings, color: KoraColors.purple, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Microphone access is blocked. Enable it in Settings to record voice notes.',
                style: TextStyle(
                  color: KoraColors.textPrimaryFor(brightness),
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: KoraColors.cardFor(brightness),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Settings',
          textColor: KoraColors.purple,
          onPressed: () => openAppSettings(),
        ),
      ),
    );
  }

  // ── Hold / slide / lock gesture ──

  Future<void> _onHoldStart(LongPressStartDetails details) async {
    final granted = await _ensureMicPermission();
    if (!granted || !mounted) return;

    _dragDx = 0;
    _dragDy = 0;
    _seconds = 0;
    _isPaused = false;
    _gestureResolved = false;
    _waveformSamples.clear();

    try {
      _filePath = await _recordingService.startRecording();
    } catch (_) {
      return; // permission or recorder error — stay idle
    }
    if (!mounted) return;

    setState(() => _state = _ComposerState.holding);
    _pulseController.repeat(reverse: true);
    _startTimers();
  }

  void _startTimers() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_isPaused) setState(() => _seconds++);
    });

    _amplitudeTimer?.cancel();
    _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 80), (_) async {
      if (!mounted || !_recordingService.isRecording || _isPaused) return;
      final amp = await _recordingService.getAmplitude();
      if (mounted) {
        setState(() {
          _waveformSamples.add(amp);
          if (_waveformSamples.length > 60) _waveformSamples.removeAt(0);
        });
      }
    });
  }

  void _onHoldMove(LongPressMoveUpdateDetails details) {
    if (_state != _ComposerState.holding || _gestureResolved) return;
    final off = details.offsetFromOrigin;
    setState(() {
      _dragDx = off.dx;
      _dragDy = off.dy;
    });

    if (_dragDx <= -_kCancelThreshold) {
      _gestureResolved = true;
      _cancelHolding();
    } else if (_dragDy <= -_kLockThreshold) {
      _gestureResolved = true;
      _lockRecording();
    }
  }

  void _onHoldEnd(LongPressEndDetails details) {
    if (_state != _ComposerState.holding || _gestureResolved) return;
    _finishAndSend();
  }

  double get _cancelProgress => (-_dragDx / _kCancelThreshold).clamp(0.0, 1.0);
  double get _lockProgress => (-_dragDy / _kLockThreshold).clamp(0.0, 1.0);

  String get _durationString {
    final m = (_seconds ~/ 60).toString();
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _cancelHolding() async {
    HapticFeedback.mediumImpact();
    _timer?.cancel();
    _amplitudeTimer?.cancel();
    _pulseController.stop();
    await _recordingService.cancelRecording();
    if (mounted) setState(() => _state = _ComposerState.idle);
  }

  void _lockRecording() {
    HapticFeedback.mediumImpact();
    _pulseController.stop();
    setState(() => _state = _ComposerState.locked);
  }

  void _finishAndSend() async {
    _timer?.cancel();
    _amplitudeTimer?.cancel();
    _pulseController.stop();

    if (_seconds < 1) {
      // Too short to be a real note — treat as an accidental tap-hold.
      await _recordingService.cancelRecording();
      if (mounted) setState(() => _state = _ComposerState.idle);
      return;
    }

    final path = await _recordingService.stopRecording();
    final duration = _durationString;
    if (mounted) setState(() => _state = _ComposerState.idle);
    widget.onSendVoice(duration, filePath: path ?? _filePath);
  }

  // ── Locked bar actions ──

  void _toggleLockedPause() async {
    if (_isPaused) {
      await _recordingService.resumeRecording();
    } else {
      await _recordingService.pauseRecording();
    }
    if (mounted) setState(() => _isPaused = !_isPaused);
  }

  void _discardLocked() async {
    _timer?.cancel();
    _amplitudeTimer?.cancel();
    await _recordingService.cancelRecording();
    if (mounted) setState(() => _state = _ComposerState.idle);
  }

  void _sendLocked() async {
    _timer?.cancel();
    _amplitudeTimer?.cancel();
    final path = await _recordingService.stopRecording();
    final duration = _durationString;
    if (mounted) setState(() => _state = _ComposerState.idle);
    widget.onSendVoice(duration, filePath: path ?? _filePath);
  }

  void _openAttachments() {
    final types = [
      KoraAttachmentType(
        icon: Icons.photo_outlined,
        label: 'Photos',
        color: const Color(0xFF8B5CF6),
        onTap: () {},
      ),
      KoraAttachmentType(
        icon: Icons.videocam_outlined,
        label: 'Videos',
        color: const Color(0xFFEC4899),
        onTap: () {},
      ),
      KoraAttachmentType(
        icon: Icons.camera_alt_outlined,
        label: 'Camera',
        color: const Color(0xFF3B82F6),
        onTap: () {},
      ),
      KoraAttachmentType(
        icon: Icons.insert_drive_file_outlined,
        label: 'Files',
        color: const Color(0xFFF59E0B),
        onTap: () {},
      ),
      KoraAttachmentType(
        icon: Icons.location_on_outlined,
        label: 'Location',
        color: const Color(0xFF22C55E),
        onTap: () {},
      ),
    ];

    if (widget.onAttachment != null) {
      widget.onAttachment!();
    } else {
      AttachmentSheet.show(context, types);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final surface = KoraColors.cardFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);
    final border = KoraColors.borderFor(brightness);

    // ── Locked state — full-width hands-free bar ──
    if (_state == _ComposerState.locked) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
          child: LockedRecorderBar(
            seconds: _seconds,
            isPaused: _isPaused,
            waveformSamples: _waveformSamples,
            onDiscard: _discardLocked,
            onTogglePause: _toggleLockedPause,
            onSend: _sendLocked,
          ),
        ),
      );
    }

    final isHolding = _state == _ComposerState.holding;

    // ── Idle / typing / holding — the mic's GestureDetector stays
    // mounted at the same spot across idle ↔ holding so an active
    // long-press gesture never gets torn down mid-drag.
    //
    // Layout matches WhatsApp: a single rounded pill containing
    // emoji + text field + camera + attach, with a separate circular
    // mic/send button floating outside on the right.
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          border: Border(top: BorderSide(color: border, width: 0.5)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: Row(
            children: [
              if (!isHolding) ...[
                // ── Single pill: emoji + text + camera + attach ──
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 120),
                    decoration: BoxDecoration(
                      color: KoraColors.surfaceFor(brightness),
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Row(
                      children: [
                        // Emoji icon
                        IconButton(
                          icon: Icon(Icons.emoji_emotions_outlined,
                              color: textMuted, size: 24),
                          onPressed: () {},
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                              minWidth: 40, minHeight: 40),
                        ),
                        // Text input
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            maxLines: null,
                            textInputAction: TextInputAction.newline,
                            style: TextStyle(color: textPrimary, fontSize: 15),
                            decoration: InputDecoration(
                              hintText: 'Message',
                              hintStyle:
                                  TextStyle(color: textMuted, fontSize: 15),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                        // Camera icon (inside pill, right side)
                        IconButton(
                          icon: Icon(Icons.camera_alt_outlined,
                              color: textMuted, size: 22),
                          onPressed: () {},
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                              minWidth: 36, minHeight: 36),
                        ),
                        // Attach icon (inside pill, far right)
                        IconButton(
                          icon: Icon(Icons.attach_file,
                              color: textMuted, size: 22),
                          onPressed: _openAttachments,
                          padding: const EdgeInsets.only(right: 4),
                          constraints: const BoxConstraints(
                              minWidth: 36, minHeight: 36),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                // Holding — replaces the pill with the live
                // timer + waveform + slide-to-cancel hint.
                Expanded(
                  child: VoiceHoldingContent(
                    seconds: _seconds,
                    waveformSamples: _waveformSamples,
                    cancelProgress: _cancelProgress,
                    pulseController: _pulseController,
                  ),
                ),
              ],
              const SizedBox(width: 6),
              // ── Send / Mic circular button (outside the pill) ──
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  if (isHolding)
                    Positioned(
                      bottom: 50,
                      child: VoiceLockHint(progress: _lockProgress),
                    ),
                  GestureDetector(
                    onTap: _hasText ? _send : null,
                    onLongPressStart:
                        (!_hasText && !isHolding) ? _onHoldStart : null,
                    onLongPressMoveUpdate: isHolding ? _onHoldMove : null,
                    onLongPressEnd: isHolding ? _onHoldEnd : null,
                    child: Transform.translate(
                      offset: isHolding
                          ? Offset(
                              (_dragDx * 0.25).clamp(-24.0, 0.0),
                              (_dragDy * 0.25).clamp(-24.0, 0.0),
                            )
                          : Offset.zero,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        width: isHolding ? 50 : 46,
                        height: isHolding ? 50 : 46,
                        decoration: BoxDecoration(
                          gradient: _hasText ? KoraColors.brandGradient : null,
                          color: _hasText
                              ? null
                              : (isHolding
                                  ? KoraColors.red.withValues(alpha: 0.15)
                                  : null),
                          shape: BoxShape.circle,
                          border: (_hasText || isHolding)
                              ? null
                              : Border.all(
                                  color: textMuted.withValues(alpha: 0.3),
                                  width: 1),
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            _hasText ? Icons.send : Icons.mic_rounded,
                            key: ValueKey('$_hasText-$isHolding'),
                            color: _hasText
                                ? Colors.white
                                : (isHolding ? KoraColors.red : textMuted),
                            size: isHolding ? 24 : 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../theme/kora_colors.dart';
import '../../services/audio_recording_service.dart';
import '../../services/audio_playback_service.dart';
import '../../services/voice_note_stt_service.dart';
import '../../services/voice_translation_pipeline.dart';
import '../../services/translation_service.dart';
import '../../models/translation_models.dart';
import 'ai_writing_sheet.dart';
import 'voice_recorder.dart';
import 'voice_locked_bar.dart';
import 'emoji_sticker_panel.dart';
import 'kora_camera_screen.dart';
import 'media_editor_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'language_picker_screen.dart';

/// Kora's message composer — the bottom input bar.
///
/// Uses WhatsApp's raw-pointer-event approach for gesture tracking
/// (Flutter Listener ≈ Android onInterceptTouchEvent/onTouchEvent):
/// - **Idle** → text input + mic button (when empty) or send button (when typing)
/// - **Holding** → press-and-hold the mic to record. Recording starts on
///   pointer DOWN (not after a hold threshold — same as WhatsApp). Shows
///   a live timer + waveform + "slide to cancel" hint, with a lock capsule
///   floating above the mic. Slide left to cancel, slide up to lock
///   hands-free. Releasing without crossing either threshold sends
///   immediately. A quick tap (short press, minimal drag) opens the popup.
/// - **Popup** → hands-free recording bar (tap or lock). Trash, timer,
///   waveform, pause/resume, translate and send. Only closes on delete/send.
///
/// Waveform data comes from [AudioRecordingService.amplitudeStream] —
/// real microphone amplitude, not a placeholder.
///
/// **Why Listener, not GestureDetector:** A GestureDetector's PanRecognizer
/// can be destroyed and recreated when the widget tree rebuilds (e.g. when
/// switching from idle → holding), orphaning an in-progress pointer. The
/// Listener widget's pointer callback is just a function — it survives
/// any rebuild because the Listener itself never changes identity.
class MessageComposer extends StatefulWidget {
  final Function(String) onSend;
  final Function(
    String duration, {
    String? filePath,
    String? transcript,
    String? translatedLanguageCode,
    String? translatedLanguageName,
    bool isPlayOnce,
  }) onSendVoice;
  final VoidCallback? onAttachment;
  final Function(String)? onAiWriting;
  final VoidCallback? onMicTap; // notify parent to pause any playing voice note
  final Function(String path, bool isVideo, String? caption, bool isViewOnce, bool isHD, double? width, double? height)? onSendMedia;

  const MessageComposer({
    super.key,
    required this.onSend,
    required this.onSendVoice,
    this.onAttachment,
    this.onAiWriting,
    this.onMicTap,
    this.onSendMedia,
  });

  @override
  State<MessageComposer> createState() => _MessageComposerState();
}

enum _ComposerState { idle, holding, popup }

class _MessageComposerState extends State<MessageComposer>
    with TickerProviderStateMixin {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _hasText = false;
  bool _showEmojiPanel = false;
  _ComposerState _state = _ComposerState.idle;

  // ── Recording state ──
  final _recordingService = AudioRecordingService.instance;
  int _seconds = 0;
  Timer? _timer;
  StreamSubscription<double>? _amplitudeSub;
  final List<double> _waveformSamples = [];
  String? _filePath;
  bool _isPaused = false;
  bool _isPlayOnce = false;

  // -- Paused-recording preview playback (WhatsApp-style) --
  static const String _previewId = '__kora_recording_preview__';
  final _previewPlayback = AudioPlaybackService.instance;
  StreamSubscription<PlaybackState>? _previewSub;
  bool _previewPlaying = false;
  double _previewProgress = 0.0;
  int _previewPositionMs = 0;
  int _previewDurationMs = 0;
  double _previewSpeed = 1.0;

  // ── Pointer tracking (WhatsApp onInterceptTouchEvent pattern) ──
  // Instead of GestureDetector's pan recognizers (which compete in the
  // gesture arena and can be destroyed when the widget tree rebuilds),
  // we use raw pointer events via Listener — exactly like WhatsApp's
  // onInterceptTouchEvent / onTouchEvent at the container level.
  //
  // The pointer tracker lives on a Listener that never changes identity,
  // so the tracking is never interrupted by setState rebuilds.
  Offset? _pointerDownPos;
  DateTime? _pointerDownTime;
  double _dragDx = 0;
  double _dragDy = 0;
  static const double _kCancelThreshold = 120.0;
  static const double _kLockThreshold = 80.0;
  static const double _kTapMaxDuration = Duration.millisecondsPerSecond * 0; // unused, kept for clarity
  static const double _kTapMaxDrag = 18.0; // max movement to still count as a tap
  bool _gestureResolved = false;

  // ── Translation state ──
  String? _selectedTranslateCode;
  String? _selectedTranslateName;
  bool _isTranslating = false;

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

    _previewSub = _previewPlayback.stateStream.listen((state) {
      if (!mounted || state.playingId != _previewId) return;
      setState(() {
        _previewPlaying = state.isPlaying;
        _previewProgress = state.progress;
        _previewPositionMs = state.positionMs;
        _previewDurationMs = state.durationMs;
        _previewSpeed = state.speed;
        if (state.isCompleted) {
          _previewPlaying = false;
          _previewProgress = 0.0;
        }
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _timer?.cancel();
    _amplitudeSub?.cancel();
    _previewSub?.cancel();
    _previewPlayback.stopIfActive(_previewId);
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

  // ── Permission ──

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

  // ── Recording ──

  // ── WhatsApp-style pointer tracking (onInterceptTouchEvent equivalent) ──
  //
  // The mic button is wrapped in a Listener (raw pointer events), NOT a
  // GestureDetector. This means:
  //   - No gesture arena competition — the pointer events come straight
  //     from the framework, so no recognizer can lose the gesture.
  //   - The Listener widget never changes identity across rebuilds, so
  //     tracking is never interrupted by setState (the bug that plagues
  //     GestureDetector-based approaches when the widget tree changes).
  //   - We classify tap-vs-hold manually from duration + drag distance,
  //     exactly like WhatsApp's onInterceptTouchEvent does on Android.

  /// Pointer went down on the mic button. Start recording immediately
  /// (WhatsApp starts audio capture on ACTION_DOWN, not after a hold
  /// threshold — the recording starts the instant you touch the mic).
  void _onPointerDown(PointerDownEvent event) {
    if (_hasText || _state != _ComposerState.idle) return;

    _pointerDownPos = event.position;
    _pointerDownTime = DateTime.now();
    _dragDx = 0;
    _dragDy = 0;
    _gestureResolved = false;

    // Start recording immediately on pointer down
    _startRecording(isHold: true);
  }

  /// Pointer moved while on the mic button. Track drag for cancel/lock.
  void _onPointerMove(PointerMoveEvent event) {
    if (_state != _ComposerState.holding || _gestureResolved) return;
    if (_pointerDownPos == null) return;

    setState(() {
      _dragDx = event.position.dx - _pointerDownPos!.dx;
      _dragDy = event.position.dy - _pointerDownPos!.dy;
    });

    if (_dragDx <= -_kCancelThreshold) {
      _gestureResolved = true;
      _cancelHolding();
    } else if (_dragDy <= -_kLockThreshold) {
      _gestureResolved = true;
      _lockRecording();
    }
  }

  /// Pointer lifted off the mic button. Classify as tap or hold-release.
  void _onPointerUp(PointerUpEvent event) {
    if (_state != _ComposerState.idle && _state != _ComposerState.holding) return;
    if (_pointerDownPos == null || _pointerDownTime == null) return;

    // If already in popup (e.g. from a previous tap), ignore
    if (_state == _ComposerState.popup) return;

    final elapsed = DateTime.now().difference(_pointerDownTime!);
    final dragDistance = (event.position - _pointerDownPos!).distance;

    // ── Tap detection ──
    // Short press with minimal movement → treat as tap → open popup.
    // WhatsApp uses a ~200ms threshold; we use 250ms to be safe with
    // Flutter's pointer pipeline latency.
    if (elapsed.inMilliseconds < 250 && dragDistance < _kTapMaxDrag) {
      _handleTapRecord();
      _pointerDownPos = null;
      _pointerDownTime = null;
      return;
    }

    // ── Hold release ──
    // If we're in holding state and the gesture wasn't resolved
    // (cancel/lock), releasing sends the voice note immediately.
    if (_state == _ComposerState.holding && !_gestureResolved) {
      _finishAndSend();
    }

    _pointerDownPos = null;
    _pointerDownTime = null;
  }

  /// Called when the pointer classification determines this was a quick
  /// tap (not a hold). Switches from holding → popup (hands-free recording).
  void _handleTapRecord() {
    if (_state == _ComposerState.holding) {
      // Recording already started on pointer down — just switch to popup
      _pulseController.stop();
      setState(() => _state = _ComposerState.popup);
    } else if (_state == _ComposerState.idle) {
      // Fallback: start fresh recording in popup mode
      _startRecording(isHold: false);
    }
  }

  /// Core recording start — shared by both tap and hold paths.
  Future<void> _startRecording({required bool isHold}) async {
    if (_hasText) return;

    widget.onMicTap?.call();

    final granted = await _ensureMicPermission();
    if (!granted || !mounted) return;

    _seconds = 0;
    _isPaused = false;
    _gestureResolved = false;
    _waveformSamples.clear();

    try {
      _filePath = await _recordingService.startRecording();
    } catch (_) {
      return;
    }
    if (!mounted) return;

    // Listen to real amplitude data for the live waveform
    _amplitudeSub?.cancel();
    _amplitudeSub = _recordingService.amplitudeStream.listen((amp) {
      if (!mounted || !_recordingService.isRecording || _isPaused) return;
      setState(() {
        _waveformSamples.add(amp);
        if (_waveformSamples.length > 60) _waveformSamples.removeAt(0);
      });
    });

    // Start on-device STT capture alongside audio recording
    VoiceNoteSttService.instance.start();

    if (isHold) {
      HapticFeedback.heavyImpact();
      setState(() => _state = _ComposerState.holding);
      _pulseController.repeat(reverse: true);
    } else {
      setState(() => _state = _ComposerState.popup);
    }
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_isPaused) setState(() => _seconds++);
    });
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
    _amplitudeSub?.cancel();
    _pulseController.stop();
    await VoiceNoteSttService.instance.stop();
    await _recordingService.cancelRecording();
    _isPlayOnce = false;
    if (mounted) setState(() => _state = _ComposerState.idle);
  }

  /// Swipe up to lock — opens the popup voice-note screen.
  /// Recording continues seamlessly, no audio is destroyed.
  void _lockRecording() {
    HapticFeedback.heavyImpact();
    _pulseController.stop();
    setState(() => _state = _ComposerState.popup);
  }

  /// Release hold without swiping — auto-sends the voice note.
  void _finishAndSend() async {
    HapticFeedback.lightImpact();
    _timer?.cancel();
    _amplitudeSub?.cancel();
    _pulseController.stop();

    if (_seconds < 1) {
      await _recordingService.cancelRecording();
      if (mounted) setState(() => _state = _ComposerState.idle);
      return;
    }

    final path = await _recordingService.stopRecording();
    final duration = _durationString;
    if (mounted) setState(() => _state = _ComposerState.idle);

    // If translation is selected, run the pipeline before sending
    if (_selectedTranslateCode != null) {
      final result = await _translateVoiceNote(path ?? _filePath ?? '');
      if (result != null) {
        widget.onSendVoice(
          duration,
          filePath: result.audioPath,
          transcript: result.transcript,
          translatedLanguageCode: result.langCode,
          translatedLanguageName: result.langName,
          isPlayOnce: _isPlayOnce,
        );
        _clearTranslation();
        _isPlayOnce = false;
        return;
      }
      return;
    }

    unawaited(VoiceNoteSttService.instance.stop());
    widget.onSendVoice(duration, filePath: path ?? _filePath, isPlayOnce: _isPlayOnce);
    _isPlayOnce = false;
  }

  // ── Popup actions ──

  void _handleTogglePlayOnce() {
    final turningOn = !_isPlayOnce;
    setState(() => _isPlayOnce = turningOn);
    if (turningOn) showPlayOnceInfoSheet(context);
  }

  void _toggleLockedPause() async {
    if (_isPaused) {
      await _stopPreview();
      await _recordingService.resumeRecording();
    } else {
      await _recordingService.pauseRecording();
    }
    if (mounted) setState(() => _isPaused = !_isPaused);
  }

  Future<void> _togglePreviewPlay() async {
    if (!_isPaused || _filePath == null) return;
    await _previewPlayback.toggle(_filePath!, messageId: _previewId);
  }

  Future<void> _seekPreview(double fraction) async {
    if (!_isPaused || _filePath == null) return;
    if (_previewPlayback.currentSource != _filePath) {
      await _previewPlayback.play(_filePath!, messageId: _previewId);
      await _previewPlayback.pause();
    }
    await _previewPlayback.seekToFraction(fraction);
  }

  void _cyclePreviewSpeed() async {
    final next = _previewSpeed >= 2.0
        ? 1.0
        : _previewSpeed >= 1.5
            ? 2.0
            : 1.5;
    await _previewPlayback.setSpeed(next);
  }

  Future<void> _stopPreview() async {
    _previewPlayback.stopIfActive(_previewId);
    if (mounted) {
      setState(() {
        _previewPlaying = false;
        _previewProgress = 0.0;
      });
    }
  }

  void _discardLocked() async {
    final wasPaused = _isPaused;
    if (!wasPaused) await _recordingService.pauseRecording();

    if (_seconds > 2) {
      final confirmed = await _confirmDiscard();
      if (!confirmed) {
        if (!wasPaused && mounted) await _recordingService.resumeRecording();
        return;
      }
    }

    _timer?.cancel();
    _amplitudeSub?.cancel();
    await _stopPreview();
    await VoiceNoteSttService.instance.stop();
    await _recordingService.cancelRecording();
    _clearTranslation();
    _isPlayOnce = false;
    if (mounted) setState(() => _state = _ComposerState.idle);
  }

  Future<bool> _confirmDiscard() async {
    if (!mounted) return false;
    final brightness = Theme.of(context).brightness;
    final surface = KoraColors.cardFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Delete this recording?',
                style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text(
                'Your voice note will be discarded and won\'t be sent.',
                textAlign: TextAlign.center,
                style: TextStyle(color: textSecondary, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Cancel', style: TextStyle(color: KoraColors.purple, fontWeight: FontWeight.w700)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return confirmed == true;
  }

  void _sendLocked() async {
    _timer?.cancel();
    _amplitudeSub?.cancel();
    await _stopPreview();
    final path = await _recordingService.stopRecording();
    final duration = _durationString;

    if (mounted) setState(() => _state = _ComposerState.idle);

    if (_selectedTranslateCode != null) {
      final result = await _translateVoiceNote(path ?? _filePath ?? '');
      if (result != null) {
        widget.onSendVoice(
          duration,
          filePath: result.audioPath,
          transcript: result.transcript,
          translatedLanguageCode: result.langCode,
          translatedLanguageName: result.langName,
          isPlayOnce: _isPlayOnce,
        );
        _clearTranslation();
        _isPlayOnce = false;
        return;
      }
      return;
    }

    unawaited(VoiceNoteSttService.instance.stop());
    widget.onSendVoice(duration, filePath: path ?? _filePath, isPlayOnce: _isPlayOnce);
    _isPlayOnce = false;
  }

  // ── Voice note translation ──

  void _openTranslatePicker() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LanguagePickerScreen(
          selectedCode: _selectedTranslateCode,
          title: 'Translate voice note to',
        ),
      ),
    ).then((result) {
      if (result != null && result is KoraLanguage) {
        setState(() {
          _selectedTranslateCode = result.code;
          _selectedTranslateName = result.name;
        });
      }
    });
  }

  void _clearTranslation() {
    setState(() {
      _selectedTranslateCode = null;
      _selectedTranslateName = null;
    });
  }

  Future<({String audioPath, String transcript, String langCode, String langName})?>
  _translateVoiceNote(String originalFilePath) async {
    if (_selectedTranslateCode == null) return null;

    setState(() => _isTranslating = true);

    try {
      final stt = VoiceNoteSttService.instance;
      final transcript = await stt.stop();

      if (transcript.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('No speech detected. Please try again and speak clearly.'),
              backgroundColor: KoraColors.cardFor(Theme.of(context).brightness),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return null;
      }

      final result = await TranslationService.instance.translate(
        transcript,
        _selectedTranslateCode!,
      );

      final translatedText = result.translatedText;
      if (translatedText.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Translation failed. Please try again.'),
              backgroundColor: KoraColors.cardFor(Theme.of(context).brightness),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return null;
      }

      final tts = VoiceTranslationPipeline.instance;
      final outcome = await tts.translateAndSynthesize(
        transcript: transcript,
        targetLanguageCode: _selectedTranslateCode!,
      );

      if (!outcome.success || outcome.audioFilePath == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(outcome.errorMessage ?? 'Could not generate translated audio. Please try again.'),
              backgroundColor: KoraColors.cardFor(Theme.of(context).brightness),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return null;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Translation successful → $_selectedTranslateName',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: KoraColors.cardFor(Theme.of(context).brightness),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      return (
        audioPath: outcome.audioFilePath!,
        transcript: translatedText,
        langCode: _selectedTranslateCode!,
        langName: _selectedTranslateName ?? _selectedTranslateCode!,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Translation failed. Please try again.'),
            backgroundColor: KoraColors.cardFor(Theme.of(context).brightness),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return null;
    } finally {
      if (mounted) setState(() => _isTranslating = false);
    }
  }

  void _openAttachments() {
    showModalBottomSheet(
      context: context,
      backgroundColor: KoraColors.cardFor(Theme.of(context).brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _buildAttachmentSheet(),
    );
  }

  Widget _buildAttachmentSheet() {
    final brightness = Theme.of(context).brightness;
    final card = KoraColors.cardFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 10),
        Container(
          width: 40, height: 4,
          decoration: BoxDecoration(
            color: textMuted.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),

        // Attachment icons row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _attachIcon(Icons.document_scanner_outlined, 'Document', KoraColors.purple, () => _pickFromGallery(false)),
              _attachIcon(Icons.photo_library_outlined, 'Gallery', KoraColors.purple, () => _pickFromGallery(true)),
              _attachIcon(Icons.camera_alt_outlined, 'Camera', KoraColors.purple, _openCamera),
              _attachIcon(Icons.insert_drive_file_outlined, 'File', KoraColors.purple, () => Navigator.pop(context)),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _attachIcon(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: () { Navigator.pop(context); onTap(); },
      child: Column(
        children: [
          Container(
            width: 54, height: 54,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _openCamera() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const KoraCameraScreen()),
    );
    if (result == null || !mounted) return;
    _openEditor(result['path'] as String, result['isVideo'] as bool);
  }

  void _pickFromGallery(bool isImage) async {
    final picker = ImagePicker();
    if (isImage) {
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 100);
      if (picked == null || !mounted) return;
      _openEditor(picked.path, false);
    } else {
      final picked = await picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(minutes: 3));
      if (picked == null || !mounted) return;
      _openEditor(picked.path, true);
    }
  }

  void _openEditor(String path, bool isVideo) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MediaEditorScreen(mediaPath: path, isVideo: isVideo)),
    );
    if (result == null || !mounted) return;
    widget.onSendMedia?.call(
      result['path'] as String,
      result['isVideo'] as bool,
      result['caption'] as String?,
      result['isViewOnce'] as bool,
      result['isHD'] as bool,
      result['width'] as double?,
      result['height'] as double?,
    );
  }

  void _openAiWriting() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AiWritingSheet(currentText: _controller.text, onApply: (result) { _controller.text = result; _controller.selection = TextSelection.fromPosition(TextPosition(offset: result.length)); setState(() => _hasText = true); _focusNode.requestFocus(); }),
    ).then((result) {
      if (result != null && result is String && result.isNotEmpty) {
        _controller.text = result;
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: result.length),
        );
        setState(() => _hasText = true);
        _focusNode.requestFocus();
      }
    });
  }

  /// Opens the popup voice-note bottom sheet.
  /// Uses isDismissible: false so it only closes on delete/send.
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textSecondaryFor(brightness);
    final bg = KoraColors.cardFor(brightness);

    // ── Locked recording state — its own bar. Gestures have already
    // ended (lock or auto-lock already resolved the pan) by the time we
    // get here, so there's no in-progress pointer to preserve. ──
    if (_state == _ComposerState.popup) {
      return SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          color: bg,
          child: VoiceLockedBar(
            seconds: _seconds,
            waveformSamples: _waveformSamples,
            isPaused: _isPaused,
            isPlayOnce: _isPlayOnce,
            onTogglePlayOnce: _handleTogglePlayOnce,
            onDiscard: _discardLocked,
            onTogglePause: _toggleLockedPause,
            onSend: _sendLocked,
            onTranslate: _openTranslatePicker,
            selectedTranslateName: _selectedTranslateName,
            isTranslating: _isTranslating,
            isPreviewPlaying: _previewPlaying,
            previewProgress: _previewProgress,
            previewPositionMs: _previewPositionMs,
            onTogglePreviewPlay: _togglePreviewPlay,
            onSeekPreview: _seekPreview,
          ),
        ),
      );
    }

    // ── Idle & Holding share ONE persistent structure. ──
    //
    // This matters: press-and-hold starts a pan gesture on the mic
    // button, then _onHoldStart's setState() rebuilds while that pointer
    // is still down. If the button at that moment were swapped for a
    // *different* widget (as it previously was — a plain GestureDetector
    // in idle vs. a GestureDetector nested inside a Stack while holding),
    // Flutter unmounts the old recognizer and mounts a fresh one that
    // never saw the pointer's initial down event — so drag-to-lock,
    // drag-to-cancel, and release-to-send would all silently stop
    // responding the instant the hold began.
    //
    // Keeping the SAME GestureDetector (same key, same position, same
    // type) for both states — and only changing its visual decoration —
    // means the recognizer survives the whole press→drag→release
    // lifecycle without interruption.
    final isHolding = _state == _ComposerState.holding;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            color: bg,
            child: Row(
              children: [
                Expanded(
              child: isHolding
                  ? VoiceHoldingContent(
                      seconds: _seconds,
                      waveformSamples: _waveformSamples,
                      cancelProgress: _cancelProgress,
                      pulseController: _pulseController,
                      dragOffsetX: _dragDx,
                    )
                  : Container(
                      constraints: const BoxConstraints(minHeight: 44),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: KoraColors.inputFillFor(brightness),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              _focusNode.unfocus();
                              setState(() => _showEmojiPanel = !_showEmojiPanel);
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Icon(
                                _showEmojiPanel
                                    ? Icons.keyboard_outlined
                                    : Icons.emoji_emotions_outlined,
                                color: KoraColors.purple, size: 22),
                            ),
                          ),
                          GestureDetector(
                            onTap: _openAiWriting,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Icon(Icons.auto_awesome_outlined,
                                  color: KoraColors.purple, size: 22),
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              focusNode: _focusNode,
                              maxLines: null,
                              textInputAction: TextInputAction.newline,
                              style: TextStyle(color: textPrimary, fontSize: 15),
                              decoration: InputDecoration(
                                hintText: 'Message',
                                hintStyle: TextStyle(color: textMuted, fontSize: 15),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.camera_alt_outlined,
                                color: textMuted, size: 22),
                            onPressed: () {},
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                                minWidth: 36, minHeight: 36),
                          ),
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
            const SizedBox(width: 6),
            // ── WhatsApp-exact mic button with recording background ──
            // Same persistent Stack > Listener structure (never changes
            // identity across rebuilds — critical for gesture survival).
            Stack(
              key: const ValueKey('kora-mic-send-button'),
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                // Lock hint — always in the tree, opacity toggles
                Positioned(
                  bottom: 52,
                  child: IgnorePointer(
                    ignoring: !isHolding,
                    child: Opacity(
                      opacity: isHolding ? 1.0 : 0.0,
                      child: VoiceLockHint(progress: _lockProgress),
                    ),
                  ),
                ),
                // WhatsApp's large semi-transparent recording background
                // circle that grows behind the mic while holding
                Positioned(
                  bottom: -8,
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: isHolding ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 150),
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: KoraColors.purple.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
                // Red trash zone — appears as user drags left toward cancel
                // WhatsApp shows a red circle with trash icon behind the mic
                Positioned(
                  bottom: 0,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: isHolding && _cancelProgress > 0.15
                          ? _cancelProgress.clamp(0.0, 1.0)
                          : 0.0,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.delete_outline_rounded,
                          color: const Color(0xFFEF4444),
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
                // The mic/send button itself with raw pointer tracking
                Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: _hasText ? null : _onPointerDown,
                  onPointerMove: _hasText ? null : _onPointerMove,
                  onPointerUp: _hasText ? null : _onPointerUp,
                  child: Transform.translate(
                    offset: isHolding
                        ? Offset(
                            (_dragDx * 0.25).clamp(-24.0, 0.0),
                            (_dragDy * 0.25).clamp(-24.0, 0.0),
                          )
                        : Offset.zero,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      width: isHolding ? 54 : 44,
                      height: isHolding ? 54 : 44,
                      decoration: BoxDecoration(
                        color: isHolding
                            ? KoraColors.purple
                            : null,
                        gradient: isHolding ? null : KoraColors.brandGradient,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _hasText ? Icons.send_rounded : Icons.mic_rounded,
                        color: Colors.white,
                        size: isHolding ? 26 : 22,
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
        // WhatsApp-style emoji & sticker panel — inline below the input bar
        if (_showEmojiPanel)
          KoraEmojiPanel(
            onEmojiSelected: (emoji) {
              final text = _controller.text;
              final sel = _controller.selection;
              final start = sel.start ?? 0;
              _controller.value = TextEditingValue(
                text: text.substring(0, start) + emoji + text.substring(sel.end ?? text.length),
                selection: TextSelection.collapsed(offset: start + emoji.length),
              );
              setState(() {});
            },
            onStickerSelected: (sticker) {
              widget.onSend(sticker);
              setState(() => _showEmojiPanel = false);
            },
            onGifSelected: (gif) {
              widget.onSend(gif);
              setState(() => _showEmojiPanel = false);
            },
          ),
      ],
    );
  }
}

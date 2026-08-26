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
import 'attachment_sheet.dart';
import 'ai_writing_sheet.dart';
import 'voice_recorder.dart';
import 'voice_note_popup.dart';
import 'language_picker_screen.dart';

/// Kora's message composer — the bottom input bar.
///
/// States:
/// - **Idle** → text input + mic button (when empty) or send button (when typing)
/// - **Holding** → press-and-hold the mic to record. Shows a live timer +
///   waveform + "slide to cancel" hint, with a lock capsule floating
///   above the mic. Slide left to cancel, slide up to lock hands-free.
///   Releasing without crossing either threshold sends immediately.
/// - **Popup** → hands-free recording popup (tap or lock). Trash, timer,
///   waveform, pause/resume, translate and send. Only closes on delete/send.
///
/// Waveform data comes from [AudioRecordingService.amplitudeStream] —
/// real microphone amplitude, not a placeholder.
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

  const MessageComposer({
    super.key,
    required this.onSend,
    required this.onSendVoice,
    this.onAttachment,
    this.onAiWriting,
    this.onMicTap,
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

  // ── Drag tracking ──
  double _dragDx = 0;
  double _dragDy = 0;
  static const double _kCancelThreshold = 120.0;
  static const double _kLockThreshold = 80.0;
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

  /// A quick tap on the mic button (no hold) starts recording and opens
  /// the popup voice-note screen immediately — trash, timer, waveform,
  /// pause, translate and send. Only closes on delete/send.
  Future<void> _onTapRecord() async {
    if (_hasText || _state != _ComposerState.idle) return;

    // Pause any currently playing voice note
    widget.onMicTap?.call();

    final granted = await _ensureMicPermission();
    if (!granted || !mounted) return;

    _seconds = 0;
    _isPaused = false;
    _waveformSamples.clear();

    try {
      _filePath = await _recordingService.startRecording();
    } catch (_) {
      return;
    }
    if (!mounted) return;

    // Start on-device STT capture alongside audio recording
    VoiceNoteSttService.instance.start();

    _amplitudeSub?.cancel();
    _amplitudeSub = _recordingService.amplitudeStream.listen((amp) {
      if (!mounted || !_recordingService.isRecording || _isPaused) return;
      _waveformSamples.add(amp);
      if (_waveformSamples.length > 60) _waveformSamples.removeAt(0);
    });

    setState(() => _state = _ComposerState.popup);
    _startTimer();
    _openPopup();
  }

  /// Press-and-hold the mic to start recording inline. Shows live timer,
  /// waveform, "slide to cancel" hint, and a lock capsule above the mic.
  /// Slide left to cancel, slide up to lock (opens popup), release to send.
  Future<void> _onHoldStart(DragStartDetails details) async {
    if (_hasText || _state != _ComposerState.idle) return;

    HapticFeedback.heavyImpact();

    // Pause any currently playing voice note
    widget.onMicTap?.call();

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

    setState(() => _state = _ComposerState.holding);
    _pulseController.repeat(reverse: true);
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_isPaused) setState(() => _seconds++);
    });
  }

  void _onHoldMove(DragUpdateDetails details) {
    if (_state != _ComposerState.holding || _gestureResolved) return;
    setState(() {
      _dragDx += details.delta.dx;
      _dragDy += details.delta.dy;
    });

    if (_dragDx <= -_kCancelThreshold) {
      _gestureResolved = true;
      _cancelHolding();
    } else if (_dragDy <= -_kLockThreshold) {
      _gestureResolved = true;
      _lockRecording();
    }
  }

  void _onHoldEnd(DragEndDetails details) {
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
    _openPopup();
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
    // Close popup
    if (mounted) Navigator.of(context).pop();
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

    // Close popup first
    if (mounted) Navigator.of(context).pop();

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
    if (widget.onAttachment != null) {
      widget.onAttachment!();
    } else {
      showModalBottomSheet(
        context: context,
        backgroundColor: KoraColors.cardFor(Theme.of(context).brightness),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => const AttachmentSheet(),
      );
    }
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
  void _openPopup() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.transparent,
        builder: (sheetCtx) => VoiceNotePopup(
          initialSeconds: _seconds,
          initialWaveformSamples: _waveformSamples,
          filePath: _filePath,
          isPaused: _isPaused,
          onDiscard: _discardLocked,
          onTogglePause: _toggleLockedPause,
          onSend: _sendLocked,
          onTranslate: _openTranslatePicker,
          selectedTranslateName: _selectedTranslateName,
          isTranslating: _isTranslating,
          isPlayOnce: _isPlayOnce,
          onTogglePlayOnce: () => setState(() => _isPlayOnce = !_isPlayOnce),
          isPreviewPlaying: _previewPlaying,
          previewProgress: _previewProgress,
          previewPositionMs: _previewPositionMs,
          previewDurationMs: _previewDurationMs,
          previewSpeed: _previewSpeed,
          onTogglePreviewPlay: _togglePreviewPlay,
          onSeekPreview: _seekPreview,
          onCyclePreviewSpeed: _cyclePreviewSpeed,
        ),
      ).then((_) {
        // If the popup was closed (delete/send already handle state),
        // make sure we reset to idle if still in popup state
        if (mounted && _state == _ComposerState.popup) {
          // This can happen if the sheet was dismissed by the system
          // In normal flow, _discardLocked and _sendLocked already pop + reset
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textSecondaryFor(brightness);
    final bg = KoraColors.cardFor(brightness);

    // ── Holding state — inline recording with gestures ──
    if (_state == _ComposerState.holding) {
      return SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          color: bg,
          child: Row(
            children: [
              Expanded(
                child: VoiceHoldingContent(
                  seconds: _seconds,
                  waveformSamples: _waveformSamples,
                  cancelProgress: _cancelProgress,
                  pulseController: _pulseController,
                ),
              ),
              const SizedBox(width: 6),
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  // Lock hint floating above the mic
                  Positioned(
                    bottom: 48,
                    child: VoiceLockHint(progress: _lockProgress),
                  ),
                  GestureDetector(
                    onPanUpdate: _onHoldMove,
                    onPanEnd: _onHoldEnd,
                    child: Transform.translate(
                      offset: Offset(
                        (_dragDx * 0.25).clamp(-24.0, 0.0),
                        (_dragDy * 0.25).clamp(-24.0, 0.0),
                      ),
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: const BoxDecoration(
                          color: KoraColors.waGreen,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.mic_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // ── Idle / Typing state ──
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        color: bg,
        child: Row(
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: KoraColors.inputFillFor(brightness),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
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
            // Mic button (when empty) / Send button (when text exists)
            GestureDetector(
              onTap: _hasText ? _send : _onTapRecord,
              onPanStart: _hasText ? null : _onHoldStart,
              onPanUpdate: _hasText ? null : _onHoldMove,
              onPanEnd: _hasText ? null : _onHoldEnd,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: KoraColors.brandGradient,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _hasText ? Icons.send_rounded : Icons.mic_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

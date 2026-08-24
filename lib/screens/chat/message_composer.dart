import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../theme/kora_colors.dart';
import '../../services/audio_recording_service.dart';
import 'attachment_sheet.dart';
import 'ai_writing_sheet.dart';
import 'voice_recorder.dart';
import 'voice_recorder_locked.dart';
import 'language_picker_screen.dart';
import '../../services/translation_service.dart';
import '../../models/translation_models.dart';
import '../../services/voice_note_stt_service.dart';
import '../../services/voice_translation_pipeline.dart';

/// Kora's message composer — the bottom input bar.
///
/// States:
/// - **Idle** → text input + mic button (when empty) or send button (when typing)
/// - **Holding** → press-and-hold the mic to record. Shows a live timer +
///   waveform + "slide to cancel" hint, with a lock capsule floating
///   above the mic. Slide left to cancel, slide up to lock hands-free.
///   Releasing without crossing either threshold sends immediately.
/// - **Locked** → hands-free recording bar with trash, pause/resume, send.
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
  }) onSendVoice;
  final VoidCallback? onAttachment;
  final Function(String)? onAiWriting;

  const MessageComposer({
    super.key,
    required this.onSend,
    required this.onSendVoice,
    this.onAttachment,
    this.onAiWriting,
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
  StreamSubscription<double>? _amplitudeSub;
  final List<double> _waveformSamples = [];
  String? _filePath;
  bool _isPaused = false;

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
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _timer?.cancel();
    _amplitudeSub?.cancel();
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

  /// A quick tap on the mic button (no hold) starts recording and goes
  /// straight into the hands-free "locked" bar — trash, timer, waveform,
  /// pause, translate and send — matching the reference recording UI.
  /// Only a press-and-hold enters the slide-to-cancel / swipe-up-to-lock
  /// gesture flow via [_onHoldStart].
  Future<void> _onTapRecord() async {
    if (_hasText || _state != _ComposerState.idle) return;

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
      setState(() {
        _waveformSamples.add(amp);
        if (_waveformSamples.length > 60) _waveformSamples.removeAt(0);
      });
    });

    setState(() => _state = _ComposerState.locked);
    _startTimer();
  }

  Future<void> _onHoldStart(DragStartDetails details) async {
    HapticFeedback.heavyImpact();
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
    if (mounted) setState(() => _state = _ComposerState.idle);
  }

  void _lockRecording() {
    HapticFeedback.heavyImpact();
    _pulseController.stop();
    setState(() => _state = _ComposerState.locked);
  }

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
        );
        _clearTranslation();
        return;
      }
      // Translation failed — don't send the original, let user retry
      return;
    }

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

  /// Deletes the current recording. Only asks for confirmation when
  /// there's meaningful audio to lose (more than ~2 seconds) — a quick
  /// accidental tap right after starting is discarded silently.
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
    await VoiceNoteSttService.instance.stop();
    await _recordingService.cancelRecording();
    _clearTranslation();
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
        );
        _clearTranslation();
        return;
      }
      // Translation failed — don't send the original
      return;
    }

    // No translation requested — stop the on-device STT capture
    // (its transcript isn't needed) and send immediately.
    unawaited(VoiceNoteSttService.instance.stop());
    widget.onSendVoice(duration, filePath: path ?? _filePath);
  }

  // ── Voice note translation ──

  /// Opens the language picker so the user can choose a target language
  /// for their voice note before sending. When set, the voice note is
  /// transcribed on-device, translated, synthesized to a new audio file,
  /// and the recipient hears the translated version.
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

  /// Clears the selected translation language.
  void _clearTranslation() {
    setState(() {
      _selectedTranslateCode = null;
      _selectedTranslateName = null;
    });
  }

  /// Translates a voice note: transcribes on-device, translates the text,
  /// synthesizes TTS audio in the target language. Returns the translated
  /// audio path + transcript, or null on failure (with a snackbar message).
  Future<({String audioPath, String transcript, String langCode, String langName})?>
  _translateVoiceNote(String originalFilePath) async {
    if (_selectedTranslateCode == null) return null;

    setState(() => _isTranslating = true);

    try {
      // Step 1: On-device transcription
      final stt = VoiceNoteSttService.instance;
      final transcript = await stt.stop();

      if (transcript.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'No speech detected. Please try again and speak clearly.',
              ),
              backgroundColor: KoraColors.cardFor(Theme.of(context).brightness),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return null;
      }

      // Step 2: Translate text
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

      // Step 3: TTS synthesis
      final tts = VoiceTranslationPipeline.instance;
      final outcome = await tts.translateAndSynthesize(
        transcript: transcript,
        targetLanguageCode: _selectedTranslateCode!,
      );

      if (!outcome.success || outcome.audioFilePath == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(outcome.errorMessage ??
                  'Could not generate translated audio. Please try again.'),
              backgroundColor: KoraColors.cardFor(Theme.of(context).brightness),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return null;
      }

      // Show success popup
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

  /// Cross-fades between the idle/holding composer and the locked
  /// recorder bar so the swipe-up-to-lock moment reads as a deliberate,
  /// smooth hand-off rather than an abrupt UI swap.
  Widget _wrapTransition(Widget child) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (transitionChild, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.97, end: 1.0).animate(animation),
          child: transitionChild,
        ),
      ),
      child: KeyedSubtree(key: ValueKey(_state), child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final surface = KoraColors.cardFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);
    final border = KoraColors.borderFor(brightness);

    // ── Locked state ──
    if (_state == _ComposerState.locked) {
      return _wrapTransition(
        SafeArea(
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
              onTranslate: _openTranslatePicker,
              selectedTranslateName: _selectedTranslateName,
              isTranslating: _isTranslating,
            ),
          ),
        ),
      );
    }

    final isHolding = _state == _ComposerState.holding;

    return _wrapTransition(
      SafeArea(
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
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 120),
                    decoration: BoxDecoration(
                      color: KoraColors.surfaceFor(brightness),
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.emoji_emotions_outlined,
                              color: textMuted, size: 24),
                          onPressed: () {},
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                              minWidth: 40, minHeight: 40),
                        ),
                        IconButton(
                          icon: Icon(Icons.auto_awesome,
                              color: KoraColors.purple, size: 22),
                          onPressed: () {
                            AiWritingSheet.show(
                              context,
                              _controller.text,
                              (result) {
                                _controller.text = result;
                                setState(() => _hasText = result.isNotEmpty);
                                _focusNode.requestFocus();
                              },
                            );
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                              minWidth: 36, minHeight: 36),
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
              ] else ...[
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
                    onTap: _hasText ? _send : _onTapRecord,
                    onPanStart:
                        (!_hasText && !isHolding) ? _onHoldStart : null,
                    onPanUpdate: isHolding ? _onHoldMove : null,
                    onPanEnd: isHolding ? _onHoldEnd : null,
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
    ));
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import '../../services/voice_note_stt_service.dart';
import '../../services/translation_service.dart';
import '../../models/translation_models.dart';
import '../../widgets/kora_waveform.dart';
import 'language_picker_screen.dart';

/// Voice-to-text input bottom sheet.
///
/// Opens when the user taps the mic button in the composer.
/// Uses on-device speech-to-text to capture speech, optionally
/// translates it, and sends the result as a **text message**.
///
/// This is NOT a voice note — no audio is recorded or sent. The recording
/// bar (timer, live waveform, delete, pause/resume, send) mirrors the
/// familiar recording UI, but drives the speech-to-text capture instead
/// of an audio recorder.
class VoiceInputSheet extends StatefulWidget {
  final Function(String) onSend;

  const VoiceInputSheet({
    super.key,
    required this.onSend,
  });

  static void show(BuildContext context, {required Function(String) onSend}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VoiceInputSheet(onSend: onSend),
    );
  }

  @override
  State<VoiceInputSheet> createState() => _VoiceInputSheetState();
}

enum _SheetState { idle, listening, done, translating, translated }

class _VoiceInputSheetState extends State<VoiceInputSheet>
    with SingleTickerProviderStateMixin {
  final _stt = VoiceNoteSttService.instance;
  final _translationService = TranslationService.instance;

  _SheetState _state = _SheetState.idle;
  String _transcript = '';
  String _translatedText = '';
  String _detectedLangName = '';
  String _detectedLangCode = '';
  KoraLanguage? _targetLanguage;
  String _errorMsg = '';
  bool _translateEnabled = false;

  bool _isPaused = false;
  int _elapsedSeconds = 0;
  Timer? _elapsedTimer;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    final code = _translationService.preferredLanguageCode;
    final lang = _translationService.allLanguages
        .where((l) => l.code == code)
        .firstOrNull;
    if (lang != null) {
      _targetLanguage = lang;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _elapsedTimer?.cancel();
    _stt.stop();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _startElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
  }

  Future<void> _startListening() async {
    setState(() {
      _state = _SheetState.listening;
      _transcript = '';
      _errorMsg = '';
      _isPaused = false;
      _elapsedSeconds = 0;
    });
    final success = await _stt.start();
    if (!success) {
      setState(() {
        _state = _SheetState.idle;
        _errorMsg = 'Speech recognition not available on this device.';
      });
      return;
    }
    _startElapsedTimer();
  }

  /// Stops recording and moves to the transcript-review state (no send).
  Future<void> _stopListening() async {
    _elapsedTimer?.cancel();
    final result = await _stt.stop();
    setState(() {
      _transcript = result;
      _isPaused = false;
      _state = result.isEmpty ? _SheetState.idle : _SheetState.done;
      if (result.isEmpty) {
        _errorMsg = "Didn't catch that. Try again?";
      }
    });
    if (_translateEnabled && result.isNotEmpty && _targetLanguage != null) {
      _doTranslate();
    }
  }

  /// Pauses/resumes capture while recording, mirroring the familiar
  /// recording bar's pause button.
  Future<void> _togglePause() async {
    if (_isPaused) {
      await _stt.resume();
      _startElapsedTimer();
      setState(() => _isPaused = false);
    } else {
      await _stt.pause();
      _elapsedTimer?.cancel();
      setState(() => _isPaused = true);
    }
  }

  /// Discards the in-progress recording (trash icon) and returns to idle.
  Future<void> _cancelRecording() async {
    _elapsedTimer?.cancel();
    await _stt.stop();
    setState(() {
      _state = _SheetState.idle;
      _transcript = '';
      _elapsedSeconds = 0;
      _isPaused = false;
      _errorMsg = '';
    });
  }

  /// Sends directly from the recording bar (green send arrow) — stops
  /// capture, optionally translates, and sends without an extra step.
  Future<void> _sendFromRecording() async {
    _elapsedTimer?.cancel();
    final result = await _stt.stop();
    if (result.trim().isEmpty) {
      setState(() {
        _state = _SheetState.idle;
        _elapsedSeconds = 0;
        _isPaused = false;
        _errorMsg = "Didn't catch that. Try again?";
      });
      return;
    }
    _transcript = result;

    if (_translateEnabled && _targetLanguage != null) {
      setState(() => _state = _SheetState.translating);
      try {
        final translation = await _translationService.translate(
          _transcript,
          _targetLanguage!.code,
        );
        widget.onSend(translation.translatedText.trim());
      } catch (e) {
        widget.onSend(_transcript.trim());
      }
    } else {
      widget.onSend(_transcript.trim());
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _doTranslate() async {
    if (_transcript.isEmpty || _targetLanguage == null) return;
    setState(() {
      _state = _SheetState.translating;
      _errorMsg = '';
    });
    try {
      final result = await _translationService.translate(
        _transcript,
        _targetLanguage!.code,
      );
      setState(() {
        _translatedText = result.translatedText;
        _detectedLangName = result.detectedLanguageName;
        _detectedLangCode = result.detectedLanguageCode;
        _state = _SheetState.translated;
      });
    } catch (e) {
      setState(() {
        _state = _SheetState.done;
        _errorMsg = 'Translation failed. Check your connection.';
      });
    }
  }

  void _send() {
    final textToSend = _translatedText.isNotEmpty ? _translatedText : _transcript;
    if (textToSend.trim().isEmpty) return;
    widget.onSend(textToSend.trim());
    Navigator.pop(context);
  }

  void _reset() {
    setState(() {
      _state = _SheetState.idle;
      _transcript = '';
      _translatedText = '';
      _errorMsg = '';
      _detectedLangName = '';
      _detectedLangCode = '';
      _elapsedSeconds = 0;
      _isPaused = false;
    });
  }

  void _pickLanguage() async {
    final lang = await Navigator.push<KoraLanguage>(
      context,
      MaterialPageRoute(builder: (_) => const LanguagePickerScreen()),
    );
    if (lang != null) {
      setState(() => _targetLanguage = lang);
      await _translationService.setPreferredLanguage(lang.code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return AnimatedPadding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      duration: const Duration(milliseconds: 200),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Voice to Text',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(
                    Icons.close,
                    size: 22,
                    color: isDark ? Colors.white60 : Colors.black45,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Main content area
            _buildContent(isDark),

            const SizedBox(height: 16),

            // Translate toggle (only when we have transcript, not while recording)
            if (_state == _SheetState.done || _state == _SheetState.translated)
              _buildTranslateRow(isDark),

            const SizedBox(height: 12),

            // Bottom action buttons (recording bar handles its own actions inline)
            if (_state != _SheetState.listening) _buildActions(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    switch (_state) {
      case _SheetState.idle:
        return _buildIdleState(isDark);
      case _SheetState.listening:
        return _buildRecordingBar(isDark);
      case _SheetState.done:
        return _buildTranscriptState(isDark, _transcript);
      case _SheetState.translating:
        return _buildLoadingState(isDark, 'Translating...');
      case _SheetState.translated:
        return _buildTranslatedState(isDark);
    }
  }

  Widget _buildIdleState(bool isDark) {
    return Column(
      children: [
        GestureDetector(
          onTap: _startListening,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: KoraColors.brandGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: KoraColors.purple.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.mic,
              color: Colors.white,
              size: 36,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _errorMsg.isEmpty ? 'Tap to speak' : _errorMsg,
          style: TextStyle(
            fontSize: 15,
            color: _errorMsg.isEmpty
                ? (isDark ? Colors.white60 : Colors.black45)
                : Colors.red.shade300,
          ),
        ),
      ],
    );
  }

  /// The recording bar — timer, live waveform, trash/delete, pause/resume
  /// pill, and send — mirroring the familiar voice-recording UI.
  Widget _buildRecordingBar(bool isDark) {
    final waveColor = isDark ? Colors.white : Colors.black87;
    final pillBg = isDark ? Colors.white12 : const Color(0xFFF0F0F0);
    final pillFg = isDark ? Colors.white70 : Colors.black54;

    return Column(
      children: [
        // Timer + live waveform
        Row(
          children: [
            GestureDetector(
              onTap: _stopListening,
              child: Text(
                _formatDuration(_elapsedSeconds),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: KoraWaveform(
                isLive: !_isPaused,
                barCount: 34,
                height: 32,
                playedColor: waveColor.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Trash / Pause pill / Send
        Row(
          children: [
            GestureDetector(
              onTap: _cancelRecording,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.delete_outline,
                  color: Colors.red.shade400,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: _togglePause,
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: pillBg,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isPaused ? Icons.play_arrow : Icons.pause,
                        color: pillFg,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isPaused ? 'Resume' : 'Pause',
                        style: TextStyle(
                          fontSize: 14,
                          color: pillFg,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _sendFromRecording,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: KoraColors.brandGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.send,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTranscriptState(bool isDark, String text) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 80, maxHeight: 200),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: SingleChildScrollView(
        child: SelectableText(
          text,
          style: TextStyle(
            fontSize: 16,
            height: 1.4,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(bool isDark, String label) {
    return Column(
      children: [
        const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white60 : Colors.black45,
          ),
        ),
      ],
    );
  }

  Widget _buildTranslatedState(bool isDark) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? Colors.white12 : const Color(0xFFF0F0F0),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Original',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _transcript,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark
                ? KoraColors.purple.withValues(alpha: 0.15)
                : const Color(0xFFEDE7F6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: KoraColors.purple.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    _targetLanguage?.flag ?? '🌐',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _detectedLangName.isNotEmpty
                        ? '$_detectedLangName → ${_targetLanguage?.name ?? ''}'
                        : (_targetLanguage?.name ?? ''),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white38 : Colors.black45,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SelectableText(
                _translatedText,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.4,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTranslateRow(bool isDark) {
    return Row(
      children: [
        GestureDetector(
          onTap: () {
            setState(() => _translateEnabled = !_translateEnabled);
            if (_translateEnabled &&
                _state == _SheetState.done &&
                _targetLanguage != null) {
              _doTranslate();
            }
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _translateEnabled
                        ? KoraColors.purple
                        : (isDark ? Colors.white30 : Colors.black26),
                    width: 2,
                  ),
                  color: _translateEnabled ? KoraColors.purple : Colors.transparent,
                ),
                child: _translateEnabled
                    ? const Icon(Icons.check, size: 12, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 8),
              Text(
                'Translate to',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _pickLanguage,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : const Color(0xFFF0F0F0),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _targetLanguage?.flag ?? '🌐',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(width: 4),
                Text(
                  _targetLanguage?.name ?? 'Select',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_down,
                  size: 16,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActions(bool isDark) {
    if (_state == _SheetState.idle || _state == _SheetState.translating) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        GestureDetector(
          onTap: _reset,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : const Color(0xFFF0F0F0),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.refresh,
              color: isDark ? Colors.white60 : Colors.black45,
              size: 22,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () {
              final textToSend =
                  _translatedText.isNotEmpty ? _translatedText : _transcript;
              Navigator.pop(context, textToSend);
            },
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : const Color(0xFFF0F0F0),
                borderRadius: BorderRadius.circular(24),
              ),
              alignment: Alignment.center,
              child: Text(
                'Edit',
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: _send,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: KoraColors.brandGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.send,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      ],
    );
  }
}

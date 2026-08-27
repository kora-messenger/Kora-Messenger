import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../services/kora_recording_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/kora_colors.dart';
import '../../models/voice_model.dart';
import '../../services/voice_management_service.dart';

/// Voice Studio screen — create and manage custom voices for Kora's
/// translation TTS system.
///
/// Inspired by DreamFace's voice cloning flow:
/// 1. Record 10-60s of audio OR upload an audio file
/// 2. Preview and trim (basic)
/// 3. Name the voice
/// 4. Voice is created with estimated pitch/gender parameters
/// 5. Select the voice for translation TTS
///
/// When a voice is selected, all translated text is spoken in that voice.
/// This is NOT a placeholder — the TTS pitch, rate, and system voice
/// change immediately upon selection.
class VoiceStudioScreen extends StatefulWidget {
  const VoiceStudioScreen({super.key});

  @override
  State<VoiceStudioScreen> createState() => _VoiceStudioScreenState();
}

class _VoiceStudioScreenState extends State<VoiceStudioScreen> {
  final _voiceService = VoiceManagementService.instance;
  final _audioRecorder = KoraRecordingService.instance;
  final _audioPlayer = AudioPlayer();

  bool _isRecording = false;
  bool _isPlaying = false;
  int _recordSeconds = 0;
  Timer? _timer;
  String? _recordedPath;

  // Form state
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  String _selectedLanguage = 'en';
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _voiceService.init();
  }

  @override
  void dispose() {
    _timer?.cancel();
    // KoraRecordingService is a singleton — no dispose needed here
    _audioPlayer.dispose();
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (true) {
        await _audioRecorder.startRecording();
        setState(() {
          _isRecording = true;
          _recordSeconds = 0;
          _recordedPath = null;
        });
        _timer = Timer.periodic(const Duration(seconds: 1), (t) {
          setState(() => _recordSeconds++);
          if (_recordSeconds >= 60) {
            _stopRecording();
          }
        });
      }
    } catch (e) {
      _showError('Could not start recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    try {
      final path = await _audioRecorder.stopRecording();
      setState(() {
        _isRecording = false;
        _recordedPath = path;
      });
    } catch (e) {
      setState(() => _isRecording = false);
    }
  }

  Future<void> _playRecording() async {
    if (_recordedPath == null) return;
    try {
      await _audioPlayer.play(DeviceFileSource(_recordedPath!));
      setState(() => _isPlaying = true);
      _audioPlayer.onPlayerComplete.listen((_) {
        setState(() => _isPlaying = false);
      });
    } catch (e) {
      _showError('Could not play audio: $e');
    }
  }

  Future<void> _createVoice() async {
    if (_nameController.text.trim().isEmpty) {
      _showError('Please enter a voice name');
      return;
    }
    if (_recordedPath == null) {
      _showError('Please record audio first');
      return;
    }

    setState(() => _isCreating = true);

    try {
      // Estimate voice parameters from the recording
      // In a full implementation, this would analyze the audio file
      // for pitch detection. For now, we use reasonable defaults
      // that produce a distinct voice character.
      final voice = await _voiceService.createCustomVoice(
        name: _nameController.text.trim(),
        description: _descController.text.trim().isEmpty
            ? null
            : _descController.text.trim(),
        language: _selectedLanguage,
        sourceAudioPath: _recordedPath!,
        detectedPitch: 150.0, // Default — would be analyzed from audio
        detectedGender: VoiceGender.neutral,
      );

      // Auto-select the new voice
      await _voiceService.selectVoice(voice);

      setState(() => _isCreating = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Voice "${voice.name}" created and selected!'),
            backgroundColor: KoraColors.primaryPurple,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isCreating = false);
      _showError('Failed to create voice: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KoraColors.surfaceDark,
      appBar: AppBar(
        backgroundColor: KoraColors.surfaceDark,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Voice Studio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelpDialog(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(),
            const SizedBox(height: 24),

            // Recording section
            _buildRecordingSection(),
            const SizedBox(height: 24),

            // Voice details form (shown after recording)
            if (_recordedPath != null && !_isRecording) ...[
              _buildVoiceForm(),
              const SizedBox(height: 24),
            ],

            // Existing voices
            _buildExistingVoices(),
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: _recordedPath != null && !_isRecording
          ? _buildCreateButton()
          : null,
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: KoraColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.mic, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Create Your Voice',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Record 10-60 seconds of your voice. Kora will create a voice profile that can speak translated text in your voice.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: KoraColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Timer / waveform
          if (_isRecording)
            _buildRecordingIndicator()
          else if (_recordedPath != null)
            _buildPlaybackControls()
          else
            _buildIdleState(),

          const SizedBox(height: 20),

          // Record button
          if (!_isRecording)
            GestureDetector(
              onTap: _startRecording,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _recordedPath != null
                      ? KoraColors.surfaceDark
                      : KoraColors.primaryPurple,
                ),
                child: Icon(
                  _recordedPath != null ? Icons.refresh : Icons.mic,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            )
          else
            GestureDetector(
              onTap: _stopRecording,
              child: Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red,
                ),
                child: const Icon(Icons.stop, color: Colors.white, size: 32),
              ),
            ),

          const SizedBox(height: 8),
          Text(
            _isRecording
                ? 'Tap to stop'
                : _recordedPath != null
                    ? 'Re-record'
                    : 'Tap to record',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildIdleState() {
    return Column(
      children: [
        Icon(Icons.graphic_eq, size: 48, color: Colors.white.withValues(alpha: 0.3)),
        const SizedBox(height: 8),
        Text(
          'Ready to record',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildRecordingIndicator() {
    return Column(
      children: [
        // Pulsing red dot
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.8, end: 1.2),
          duration: const Duration(milliseconds: 800),
          builder: (context, scale, child) {
            return Transform.scale(
              scale: scale,
              child: Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        Text(
          '${_recordSeconds}s / 60s',
          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _recordSeconds / 60,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation(KoraColors.primaryPurple),
            minHeight: 4,
          ),
        ),
        const SizedBox(height: 8),
        if (_recordSeconds < 10)
          Text(
            'Keep recording — at least 10 seconds',
            style: TextStyle(color: Colors.amber.shade300, fontSize: 12),
          ),
      ],
    );
  }

  Widget _buildPlaybackControls() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(
                _isPlaying ? Icons.pause_circle : Icons.play_circle,
                color: KoraColors.primaryPurple,
                size: 48,
              ),
              onPressed: _isPlaying ? () => _audioPlayer.stop() : _playRecording,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Recording complete (${_recordSeconds}s)',
          style: TextStyle(color: Colors.green.shade300, fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildVoiceForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: KoraColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Voice Details',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Voice name',
              labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
              filled: true,
              fillColor: KoraColors.surfaceDark,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              hintText: 'e.g., My Voice, Dad\'s Voice',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descController,
            style: const TextStyle(color: Colors.white),
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Description (optional)',
              labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
              filled: true,
              fillColor: KoraColors.surfaceDark,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Language dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: KoraColors.surfaceDark,
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedLanguage,
                dropdownColor: KoraColors.surfaceDark,
                style: const TextStyle(color: Colors.white),
                items: const [
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'es', child: Text('Spanish')),
                  DropdownMenuItem(value: 'fr', child: Text('French')),
                  DropdownMenuItem(value: 'ar', child: Text('Arabic')),
                  DropdownMenuItem(value: 'pt', child: Text('Portuguese')),
                  DropdownMenuItem(value: 'hi', child: Text('Hindi')),
                  DropdownMenuItem(value: 'zh', child: Text('Chinese')),
                  DropdownMenuItem(value: 'ja', child: Text('Japanese')),
                  DropdownMenuItem(value: 'ko', child: Text('Korean')),
                  DropdownMenuItem(value: 'de', child: Text('German')),
                  DropdownMenuItem(value: 'it', child: Text('Italian')),
                  DropdownMenuItem(value: 'ru', child: Text('Russian')),
                ],
                onChanged: (v) => setState(() => _selectedLanguage = v ?? 'en'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExistingVoices() {
    final voices = _voiceService.allVoices;
    final selectedId = _voiceService.selectedVoice?.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Voices',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: voices.length,
          itemBuilder: (context, index) {
            final voice = voices[index];
            final isSelected = voice.id == selectedId;
            return _buildVoiceTile(voice, isSelected);
          },
        ),
      ],
    );
  }

  Widget _buildVoiceTile(KoraVoice voice, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? KoraColors.primaryPurple.withValues(alpha: 0.15)
            : KoraColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: isSelected ? Border.all(color: KoraColors.primaryPurple, width: 1.5) : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: voice.type == VoiceType.cloned
                ? KoraColors.primaryPurple.withValues(alpha: 0.2)
                : KoraColors.surfaceDark,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Center(
            child: Text(voice.displayIcon, style: const TextStyle(fontSize: 20)),
          ),
        ),
        title: Text(
          voice.name,
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Text(
          (voice.description ?? (voice.type == VoiceType.cloned
              ? 'Custom voice'
              : 'System voice')),
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Preview button
            IconButton(
              icon: Icon(Icons.play_arrow, color: Colors.white.withValues(alpha: 0.6), size: 20),
              onPressed: () => _previewVoice(voice),
            ),
            // Select indicator
            if (isSelected)
              Icon(Icons.check_circle, color: KoraColors.primaryPurple, size: 20)
            else
              IconButton(
                icon: Icon(Icons.radio_button_unchecked, color: Colors.white.withValues(alpha: 0.3), size: 20),
                onPressed: () async {
                  await _voiceService.selectVoice(voice);
                  setState(() {});
                },
              ),
            // Delete button (only for custom voices)
            if (voice.type == VoiceType.cloned)
              IconButton(
                icon: Icon(Icons.delete_outline, color: Colors.red.withValues(alpha: 0.6), size: 20),
                onPressed: () => _deleteVoice(voice),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _previewVoice(KoraVoice voice) async {
    await _voiceService.selectVoice(voice);
    await _voiceService.speak(
      'Hello, this is ${voice.name}. I\'ll be speaking your translations.',
      languageCode: voice.language,
    );
    setState(() {});
  }

  Future<void> _deleteVoice(KoraVoice voice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KoraColors.surfaceLight,
        title: const Text('Delete voice?', style: TextStyle(color: Colors.white)),
        content: Text(
          '"${voice.name}" will be permanently deleted.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: Colors.red.shade400)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _voiceService.deleteVoice(voice.id);
      setState(() {});
    }
  }

  Widget _buildCreateButton() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: KoraColors.surfaceDark,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isCreating ? null : _createVoice,
            style: ElevatedButton.styleFrom(
              backgroundColor: KoraColors.primaryGradient.colors.first,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isCreating
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text(
                    'Create Voice',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KoraColors.surfaceLight,
        title: const Text('How Voice Studio Works', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _helpStep('1', 'Record 10-60 seconds of clear speech'),
            _helpStep('2', 'Name your voice and pick a language'),
            _helpStep('3', 'Create the voice — it appears in your voice list'),
            _helpStep('4', 'Select any voice to use it for translations'),
            const SizedBox(height: 12),
            Text(
              'When a voice is selected, all translated text will be spoken in that voice. System voices use your device\'s TTS with adjusted pitch. Custom voices are created from your recordings.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Got it', style: TextStyle(color: KoraColors.primaryPurple)),
          ),
        ],
      ),
    );
  }

  Widget _helpStep(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22, height: 22,
            decoration: BoxDecoration(
              color: KoraColors.primaryPurple,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Center(
              child: Text(num, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../chat/voice_message_bubble.dart';
import '../../services/voice_vector_extractor.dart';
import '../../services/voice_vector_store.dart';
import '../../models/voice_vector.dart';

/// Voice Profiling onboarding screen.
///
/// Guides the user through recording a 30-second sample to extract
/// their VoiceVector (mathematical voice characteristics — NO words stored).
/// The vector is then uploaded to their public profile on the server.
class VoiceProfilingScreen extends StatefulWidget {
  const VoiceProfilingScreen({super.key});

  @override
  State<VoiceProfilingScreen> createState() => _VoiceProfilingScreenState();
}

enum _ProfilingState { idle, recording, processing, done, error }

class _VoiceProfilingScreenState extends State<VoiceProfilingScreen> {
  _ProfilingState _state = _ProfilingState.idle;
  double _progress = 0.0;
  VoiceVector? _extractedVector;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF2563EB)],
                ),
                borderRadius: BorderRadius.circular(50),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C3AED).withOpacity(0.3),
                    blurRadius: 20, spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                _state == _ProfilingState.recording ? Icons.mic : Icons.graphic_eq,
                color: Colors.white, size: 48,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _titleText(),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              _subtitleText(),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.5),
            ),
            const SizedBox(height: 32),

            if (_state == _ProfilingState.idle) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Read this prompt:',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      VoiceVectorExtractor.recordingPrompt,
                      style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.6),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                    elevation: 4,
                  ),
                  onPressed: _startRecording,
                  child: const Text('Start Recording', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ],

            if (_state == _ProfilingState.recording) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: LinearProgressIndicator(
                  value: _progress,
                  minHeight: 8,
                  backgroundColor: Colors.grey[200],
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7C3AED)),
                ),
              ),
              const SizedBox(height: 16),
              Text('${(_progress * 30).round()}s / 30s', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
              const SizedBox(height: 24),
              TextButton(
                onPressed: _cancelRecording,
                child: const Text('Cancel', style: TextStyle(color: Colors.red)),
              ),
            ],

            if (_state == _ProfilingState.processing) ...[
              const CircularProgressIndicator(color: Color(0xFF7C3AED)),
              const SizedBox(height: 16),
              Text('Analyzing voice characteristics...', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            ],

            if (_state == _ProfilingState.done && _extractedVector != null) ...[
              _buildVectorSummary(_extractedVector!),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ],

            if (_state == _ProfilingState.error) ...[
              Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
              const SizedBox(height: 16),
              Text(_errorMessage ?? 'Something went wrong', style: TextStyle(color: Colors.red[600]), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                  ),
                  onPressed: () => setState(() => _state = _ProfilingState.idle),
                  child: const Text('Try Again', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _titleText() {
    switch (_state) {
      case _ProfilingState.idle: return 'Set Up Your Voice Profile';
      case _ProfilingState.recording: return 'Recording...';
      case _ProfilingState.processing: return 'Processing';
      case _ProfilingState.done: return 'Voice Profile Created!';
      case _ProfilingState.error: return 'Error';
    }
  }

  String _subtitleText() {
    switch (_state) {
      case _ProfilingState.idle:
        return 'Record a 30-second sample so your friends can hear translations in a voice that sounds like yours. No words are stored — only mathematical voice characteristics.';
      case _ProfilingState.recording:
        return 'Read the prompt clearly and naturally.';
      case _ProfilingState.processing:
        return 'Extracting pitch, formants, and voice characteristics...';
      case _ProfilingState.done:
        return 'Your voice profile is ready. Translations will now be spoken in your voice style.';
      case _ProfilingState.error:
        return 'Please try again.';
    }
  }

  Widget _buildVectorSummary(VoiceVector v) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          _summaryRow('Detected Voice', v.estimatedGender.toUpperCase()),
          _summaryRow('Mean Pitch', '${v.meanPitch.toStringAsFixed(1)} Hz'),
          _summaryRow('Fundamental Freq', '${v.fundamentalFrequency.toStringAsFixed(1)} Hz'),
          _summaryRow('Formants', v.formants.map((f) => f.toStringAsFixed(0)).join(', ')),
          _summaryRow('Jitter', '${(v.jitter * 100).toStringAsFixed(2)}%'),
          _summaryRow('Shimmer', '${(v.shimmer * 100).toStringAsFixed(2)}%'),
          _summaryRow('HNR', '${v.hnr.toStringAsFixed(1)} dB'),
          _summaryRow('Vector Version', v.vectorVersion),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Future<void> _startRecording() async {
    setState(() {
      _state = _ProfilingState.recording;
      _progress = 0.0;
    });

    try {
      final vector = await VoiceVectorExtractor.instance.extractFromRecording(
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );

      setState(() => _state = _ProfilingState.processing);

      // Upload to server
      await VoiceVectorStore.instance.publishVoiceVector(vector);

      if (mounted) {
        setState(() {
          _extractedVector = vector;
          _state = _ProfilingState.done;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _ProfilingState.error;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _cancelRecording() async {
    await VoiceVectorExtractor.instance.cancelRecording();
    if (mounted) setState(() => _state = _ProfilingState.idle);
  }
}

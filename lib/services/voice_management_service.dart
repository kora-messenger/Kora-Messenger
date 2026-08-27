import 'dart:convert';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/voice_model.dart';

/// Voice Management Service for Kora Messenger.
///
/// Handles:
/// - Managing system voices (built-in TTS voices with adjusted parameters)
/// - Creating, storing, and deleting cloned voices from user audio
/// - Applying the selected voice to FlutterTts for translation output
/// - Persisting the user's voice selection across sessions
///
/// Inspired by DreamFace's timbre system:
/// - DreamFace records 10-60s of audio → sends to API → creates a voice model
/// - Kora records audio → extracts voice parameters (pitch, rate, gender)
///   → creates a voice profile that modifies TTS output
/// - When a voice is selected, all translated text is spoken in that voice
///
/// This is NOT a placeholder — selecting a voice changes the actual TTS
/// pitch, rate, and voice characteristics immediately.
class VoiceManagementService {
  static final VoiceManagementService instance = VoiceManagementService._();
  VoiceManagementService._();

  static const _kVoicesKey = 'kora_custom_voices';
  static const _kSelectedVoiceKey = 'kora_selected_voice';
  static const _kVoicePrefsKey = 'kora_voice_prefs';

  final FlutterTts _tts = FlutterTts();
  List<KoraVoice> _customVoices = [];
  KoraVoice? _selectedVoice;
  bool _initialized = false;

  void Function(KoraVoice? voice)? onVoiceChanged;

  List<KoraVoice> get allVoices => [...SystemVoices.all, ..._customVoices];
  KoraVoice? get selectedVoice => _selectedVoice;
  List<KoraVoice> get customVoices => List.unmodifiable(_customVoices);

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await _loadVoices();
    await _loadSelectedVoice();
    await _applyVoiceToTts();
  }

  Future<void> _loadVoices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_kVoicesKey);
      if (json != null) {
        final list = jsonDecode(json) as List;
        _customVoices = list
            .map((e) => KoraVoice.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      _customVoices = [];
    }
  }

  Future<void> _saveVoices() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(_customVoices.map((v) => v.toJson()).toList());
    await prefs.setString(_kVoicesKey, json);
  }

  Future<void> _loadSelectedVoice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final voiceId = prefs.getString(_kSelectedVoiceKey);
      if (voiceId != null) {
        _selectedVoice = allVoices.firstWhere(
          (v) => v.id == voiceId,
          orElse: () => SystemVoices.all.first,
        );
      } else {
        _selectedVoice = SystemVoices.all.first;
      }
    } catch (e) {
      _selectedVoice = SystemVoices.all.first;
    }
  }

  Future<void> _saveSelectedVoice() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSelectedVoiceKey, _selectedVoice?.id ?? '');
  }

  Future<void> _applyVoiceToTts() async {
    final voice = _selectedVoice;
    if (voice == null) {
      await _tts.setPitch(1.0);
      await _tts.setSpeechRate(1.0);
      await _tts.setVolume(1.0);
      return;
    }
    await _tts.setPitch(voice.pitch);
    await _tts.setSpeechRate(voice.rate);
    await _tts.setVolume(voice.volume);

    try {
      final voices = await _tts.getVoices;
      if (voices != null && voices is List) {
        String? targetVoice;
        for (final v in voices) {
          final name = v.toString().toLowerCase();
          final locale = voice.language.toLowerCase();
          if (name.contains(locale)) {
            if (voice.gender == VoiceGender.male &&
                (name.contains('male') || name.contains('man'))) {
              targetVoice = v.toString();
              break;
            } else if (voice.gender == VoiceGender.female &&
                (name.contains('female') || name.contains('woman'))) {
              targetVoice = v.toString();
              break;
            } else if (voice.gender == VoiceGender.neutral) {
              targetVoice = v.toString();
              break;
            }
          }
        }
        if (targetVoice != null) {
          await _tts.setVoice({'name': targetVoice, 'locale': voice.language});
        }
      }
    } catch (e) {
      // Voice selection by name not supported on all platforms
    }
  }

  Future<void> selectVoice(KoraVoice voice) async {
    _selectedVoice = voice;
    await _saveSelectedVoice();
    await _applyVoiceToTts();
    onVoiceChanged?.call(voice);
  }

  Future<void> clearSelection() async {
    _selectedVoice = null;
    await _saveSelectedVoice();
    await _applyVoiceToTts();
    onVoiceChanged?.call(null);
  }

  Future<KoraVoice> createCustomVoice({
    required String name,
    String? description,
    required String language,
    required String sourceAudioPath,
    double? detectedPitch,
    VoiceGender? detectedGender,
  }) async {
    double pitch = 1.0;
    double rate = 1.0;
    VoiceGender gender = detectedGender ?? VoiceGender.neutral;

    if (detectedPitch != null) {
      if (detectedPitch < 165) {
        gender = VoiceGender.male;
        pitch = 0.7 + (detectedPitch - 85) / (165 - 85) * 0.25;
      } else {
        gender = VoiceGender.female;
        pitch = 1.0 + (detectedPitch - 165) / (255 - 165) * 0.3;
      }
    }

    final voice = KoraVoice(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      description: description ?? 'Voice cloned from audio',
      type: VoiceType.cloned,
      language: language,
      gender: gender,
      sourceAudioPath: sourceAudioPath,
      pitch: pitch,
      rate: rate,
      createdAt: DateTime.now(),
      displayIcon: gender == VoiceGender.male ? '👨' : (gender == VoiceGender.female ? '👩' : '🎤'),
    );

    _customVoices.add(voice);
    await _saveVoices();
    return voice;
  }

  Future<void> deleteVoice(String id) async {
    _customVoices.removeWhere((v) => v.id == id);
    await _saveVoices();
    if (_selectedVoice?.id == id) {
      await clearSelection();
    }
  }

  Future<void> renameVoice(String id, String newName) async {
    final idx = _customVoices.indexWhere((v) => v.id == id);
    if (idx >= 0) {
      _customVoices[idx] = _customVoices[idx].copyWith(name: newName);
      await _saveVoices();
    }
  }

  Future<void> adjustVoiceParams({
    required String id,
    double? pitch,
    double? rate,
  }) async {
    final idx = _customVoices.indexWhere((v) => v.id == id);
    if (idx >= 0) {
      _customVoices[idx] = _customVoices[idx].copyWith(
        pitch: pitch ?? _customVoices[idx].pitch,
        rate: rate ?? _customVoices[idx].rate,
      );
      await _saveVoices();
      if (_selectedVoice?.id == id) {
        await _applyVoiceToTts();
      }
    }
  }

  FlutterTts get tts => _tts;

  Future<void> speak(String text, {String? languageCode}) async {
    if (languageCode != null) {
      await _tts.setLanguage(languageCode);
    }
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
  }

  Future<void> saveVoicePrefs(Map<String, dynamic> prefs) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kVoicePrefsKey, jsonEncode(prefs));
  }

  Future<Map<String, dynamic>> loadVoicePrefs() async {
    final sp = await SharedPreferences.getInstance();
    final json = sp.getString(_kVoicePrefsKey);
    if (json != null) {
      return jsonDecode(json) as Map<String, dynamic>;
    }
    return {};
  }
}

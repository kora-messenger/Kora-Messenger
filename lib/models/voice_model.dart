/// Voice model for Kora Messenger — represents a user-created or
/// system-provided voice that can be used for TTS in translations.
///
/// Inspired by DreamFace's timbre system:
/// - System voices: built-in TTS voices (male/female per language)
/// - Cloned voices: created from user-recorded or uploaded audio
/// - Each voice has a pitch, speed, and timbre profile
///
/// When wired to the translation system, selecting a voice changes
/// the TTS output — no placeholder behavior.

class KoraVoice {
  final String id;
  final String name;
  final String? description;
  final VoiceType type;
  final String language;
  final VoiceGender gender;

  /// For cloned voices: the audio file path used to create this voice
  final String? sourceAudioPath;

  /// Voice parameters that affect TTS output
  final double pitch;
  final double rate;
  final double volume;

  /// For cloned voices: timestamp of creation
  final DateTime? createdAt;

  /// Whether this voice is currently selected for translation TTS
  final bool isSelected;

  /// Avatar/emoji to display in the voice picker
  final String displayIcon;

  const KoraVoice({
    required this.id,
    required this.name,
    this.description,
    required this.type,
    required this.language,
    required this.gender,
    this.sourceAudioPath,
    this.pitch = 1.0,
    this.rate = 1.0,
    this.volume = 1.0,
    this.createdAt,
    this.isSelected = false,
    this.displayIcon = '🎤',
  });

  KoraVoice copyWith({
    String? id,
    String? name,
    String? description,
    VoiceType? type,
    String? language,
    VoiceGender? gender,
    String? sourceAudioPath,
    double? pitch,
    double? rate,
    double? volume,
    DateTime? createdAt,
    bool? isSelected,
    String? displayIcon,
  }) {
    return KoraVoice(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      language: language ?? this.language,
      gender: gender ?? this.gender,
      sourceAudioPath: sourceAudioPath ?? this.sourceAudioPath,
      pitch: pitch ?? this.pitch,
      rate: rate ?? this.rate,
      volume: volume ?? this.volume,
      createdAt: createdAt ?? this.createdAt,
      isSelected: isSelected ?? this.isSelected,
      displayIcon: displayIcon ?? this.displayIcon,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'type': type.name,
    'language': language,
    'gender': gender.name,
    'sourceAudioPath': sourceAudioPath,
    'pitch': pitch,
    'rate': rate,
    'volume': volume,
    'createdAt': createdAt?.toIso8601String(),
    'displayIcon': displayIcon,
  };

  factory KoraVoice.fromJson(Map<String, dynamic> json) => KoraVoice(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String?,
    type: VoiceType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => VoiceType.system,
    ),
    language: json['language'] as String? ?? 'en',
    gender: VoiceGender.values.firstWhere(
      (e) => e.name == json['gender'],
      orElse: () => VoiceGender.neutral,
    ),
    sourceAudioPath: json['sourceAudioPath'] as String?,
    pitch: (json['pitch'] as num?)?.toDouble() ?? 1.0,
    rate: (json['rate'] as num?)?.toDouble() ?? 1.0,
    volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
    createdAt: json['createdAt'] != null
        ? DateTime.parse(json['createdAt'] as String)
        : null,
    displayIcon: json['displayIcon'] as String? ?? '🎤',
  );
}

enum VoiceType { system, cloned }

enum VoiceGender { male, female, neutral }

/// Built-in system voices available to all Kora users.
class SystemVoices {
  static List<KoraVoice> get all => [
    const KoraVoice(
      id: 'system_default',
      name: 'Default',
      description: 'Your device\'s default voice',
      type: VoiceType.system,
      language: 'en',
      gender: VoiceGender.neutral,
      displayIcon: '🗣️',
    ),
    const KoraVoice(
      id: 'system_male_en',
      name: 'Kora Male',
      description: 'Deep, clear male voice',
      type: VoiceType.system,
      language: 'en',
      gender: VoiceGender.male,
      pitch: 0.85,
      rate: 0.95,
      displayIcon: '👨',
    ),
    const KoraVoice(
      id: 'system_female_en',
      name: 'Kora Female',
      description: 'Warm, expressive female voice',
      type: VoiceType.system,
      language: 'en',
      gender: VoiceGender.female,
      pitch: 1.15,
      rate: 1.0,
      displayIcon: '👩',
    ),
    const KoraVoice(
      id: 'system_male_deep',
      name: 'Deep Bass',
      description: 'Deep, resonant voice',
      type: VoiceType.system,
      language: 'en',
      gender: VoiceGender.male,
      pitch: 0.7,
      rate: 0.9,
      displayIcon: '🎙️',
    ),
    const KoraVoice(
      id: 'system_female_soft',
      name: 'Soft Voice',
      description: 'Gentle, soft-spoken voice',
      type: VoiceType.system,
      language: 'en',
      gender: VoiceGender.female,
      pitch: 1.1,
      rate: 0.85,
      displayIcon: '✨',
    ),
    const KoraVoice(
      id: 'system_male_fast',
      name: 'Quick Talk',
      description: 'Fast-paced energetic voice',
      type: VoiceType.system,
      language: 'en',
      gender: VoiceGender.male,
      pitch: 1.0,
      rate: 1.25,
      displayIcon: '⚡',
    ),
  ];
}

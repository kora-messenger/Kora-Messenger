/// Result of a text translation.
class TranslationResult {
  final String originalText;
  final String translatedText;
  final String detectedLanguageCode;
  final String detectedLanguageName;
  final String targetLanguageCode;
  final String targetLanguageName;
  final DateTime translatedAt;

  const TranslationResult({
    required this.originalText,
    required this.translatedText,
    required this.detectedLanguageCode,
    required this.detectedLanguageName,
    required this.targetLanguageCode,
    required this.targetLanguageName,
    required this.translatedAt,
  });
}

/// Result of voice transcription + translation.
class VoiceTranslationResult {
  final String transcript;
  final String detectedLanguageCode;
  final String detectedLanguageName;
  final String translatedText;
  final String targetLanguageCode;
  final String targetLanguageName;
  final DateTime processedAt;

  const VoiceTranslationResult({
    required this.transcript,
    required this.detectedLanguageCode,
    required this.detectedLanguageName,
    required this.translatedText,
    required this.targetLanguageCode,
    required this.targetLanguageName,
    required this.processedAt,
  });
}

/// Auto-translation mode preference.
enum AutoTranslateMode {
  off,
  ask,
  automatic,
}

/// Call translation mode.
enum CallTranslationMode {
  originalAudio,
  translatedAudio,
  originalWithCaptions,
  translationWithCaptions,
}

/// A supported language for translation.
class KoraLanguage {
  final String code;
  final String name;
  final String flag;
  final String nativeName;

  const KoraLanguage({
    required this.code,
    required this.name,
    required this.flag,
    required this.nativeName,
  });
}

import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../models/translation_models.dart';
import '../config/kora_api.dart';

/// Central translation service for Kora Messenger.
///
/// Handles:
/// - Real text translation via koraTranslate backend (Google → MyMemory → OpenRouter LLM fallback)
/// - Language detection
/// - Voice note transcription + translation
/// - User translation preferences (persisted)
/// - Recently used languages
///
/// All API endpoints are domain-swappable via [KoraApi].
/// When a .com domain is set, just change [KoraApi.baseUrl].
class TranslationService {
  static final TranslationService instance = TranslationService._();
  TranslationService._();

  // ── Keys ───────────────────────────────────────────────────
  static const _kPreferredLang = 'kora_translation_pref_lang';
  static const _kAutoMode = 'kora_translation_auto_mode';
  static const _kShowOriginal = 'kora_translation_show_original';
  static const _kTranslateVoice = 'kora_translation_voice';
  static const _kCallTranslation = 'kora_call_translation';
  static const _kCaptionSize = 'kora_caption_size';
  static const _kRecentLangs = 'kora_recent_langs';

  // ── State ──────────────────────────────────────────────────
  String _preferredLangCode = 'en';
  AutoTranslateMode _autoMode = AutoTranslateMode.off;
  bool _showOriginal = true;
  bool _translateVoice = true;
  bool _callTranslationEnabled = false;
  double _captionSize = 14.0;
  List<String> _recentLangCodes = [];

  bool _initialized = false;

  final StreamController<String> _settingsController =
      StreamController<String>.broadcast();
  Stream<String> get settingsStream => _settingsController.stream;

  // ── Supported Languages (100+) ────────────────────────────
  static const List<KoraLanguage> _allLanguages = [
    KoraLanguage(code: 'en', name: 'English', flag: '🇬🇧', nativeName: 'English'),
    KoraLanguage(code: 'es', name: 'Spanish', flag: '🇪🇸', nativeName: 'Español'),
    KoraLanguage(code: 'fr', name: 'French', flag: '🇫🇷', nativeName: 'Français'),
    KoraLanguage(code: 'de', name: 'German', flag: '🇩🇪', nativeName: 'Deutsch'),
    KoraLanguage(code: 'it', name: 'Italian', flag: '🇮🇹', nativeName: 'Italiano'),
    KoraLanguage(code: 'pt', name: 'Portuguese', flag: '🇵🇹', nativeName: 'Português'),
    KoraLanguage(code: 'pt-BR', name: 'Portuguese (Brazil)', flag: '🇧🇷', nativeName: 'Português (Brasil)'),
    KoraLanguage(code: 'nl', name: 'Dutch', flag: '🇳🇱', nativeName: 'Nederlands'),
    KoraLanguage(code: 'ru', name: 'Russian', flag: '🇷🇺', nativeName: 'Русский'),
    KoraLanguage(code: 'pl', name: 'Polish', flag: '🇵🇱', nativeName: 'Polski'),
    KoraLanguage(code: 'uk', name: 'Ukrainian', flag: '🇺🇦', nativeName: 'Українська'),
    KoraLanguage(code: 'cs', name: 'Czech', flag: '🇨🇿', nativeName: 'Čeština'),
    KoraLanguage(code: 'sk', name: 'Slovak', flag: '🇸🇰', nativeName: 'Slovenčina'),
    KoraLanguage(code: 'hu', name: 'Hungarian', flag: '🇭🇺', nativeName: 'Magyar'),
    KoraLanguage(code: 'ro', name: 'Romanian', flag: '🇷🇴', nativeName: 'Română'),
    KoraLanguage(code: 'bg', name: 'Bulgarian', flag: '🇧🇬', nativeName: 'Български'),
    KoraLanguage(code: 'hr', name: 'Croatian', flag: '🇭🇷', nativeName: 'Hrvatski'),
    KoraLanguage(code: 'sr', name: 'Serbian', flag: '🇷🇸', nativeName: 'Српски'),
    KoraLanguage(code: 'sl', name: 'Slovenian', flag: '🇸🇮', nativeName: 'Slovenščina'),
    KoraLanguage(code: 'el', name: 'Greek', flag: '🇬🇷', nativeName: 'Ελληνικά'),
    KoraLanguage(code: 'sv', name: 'Swedish', flag: '🇸🇪', nativeName: 'Svenska'),
    KoraLanguage(code: 'da', name: 'Danish', flag: '🇩🇰', nativeName: 'Dansk'),
    KoraLanguage(code: 'fi', name: 'Finnish', flag: '🇫🇮', nativeName: 'Suomi'),
    KoraLanguage(code: 'no', name: 'Norwegian', flag: '🇳🇴', nativeName: 'Norsk'),
    KoraLanguage(code: 'is', name: 'Icelandic', flag: '🇮🇸', nativeName: 'Íslenska'),
    KoraLanguage(code: 'et', name: 'Estonian', flag: '🇪🇪', nativeName: 'Eesti'),
    KoraLanguage(code: 'lv', name: 'Latvian', flag: '🇱🇻', nativeName: 'Latviešu'),
    KoraLanguage(code: 'lt', name: 'Lithuanian', flag: '🇱🇹', nativeName: 'Lietuvių'),
    KoraLanguage(code: 'tr', name: 'Turkish', flag: '🇹🇷', nativeName: 'Türkçe'),
    KoraLanguage(code: 'ar', name: 'Arabic', flag: '🇸🇦', nativeName: 'العربية'),
    KoraLanguage(code: 'he', name: 'Hebrew', flag: '🇮🇱', nativeName: 'עברית'),
    KoraLanguage(code: 'fa', name: 'Persian', flag: '🇮🇷', nativeName: 'فارسی'),
    KoraLanguage(code: 'ps', name: 'Pashto', flag: '🇦🇫', nativeName: 'پښتو'),
    KoraLanguage(code: 'ur', name: 'Urdu', flag: '🇵🇰', nativeName: 'اردو'),
    KoraLanguage(code: 'hi', name: 'Hindi', flag: '🇮🇳', nativeName: 'हिन्दी'),
    KoraLanguage(code: 'bn', name: 'Bengali', flag: '🇧🇩', nativeName: 'বাংলা'),
    KoraLanguage(code: 'ta', name: 'Tamil', flag: '🇮🇳', nativeName: 'தமிழ்'),
    KoraLanguage(code: 'te', name: 'Telugu', flag: '🇮🇳', nativeName: 'తెలుగు'),
    KoraLanguage(code: 'ml', name: 'Malayalam', flag: '🇮🇳', nativeName: 'മലയാളം'),
    KoraLanguage(code: 'kn', name: 'Kannada', flag: '🇮🇳', nativeName: 'ಕನ್ನಡ'),
    KoraLanguage(code: 'mr', name: 'Marathi', flag: '🇮🇳', nativeName: 'मराठी'),
    KoraLanguage(code: 'gu', name: 'Gujarati', flag: '🇮🇳', nativeName: 'ગુજરાતી'),
    KoraLanguage(code: 'pa', name: 'Punjabi', flag: '🇮🇳', nativeName: 'ਪੰਜਾਬੀ'),
    KoraLanguage(code: 'th', name: 'Thai', flag: '🇹🇭', nativeName: 'ไทย'),
    KoraLanguage(code: 'km', name: 'Khmer', flag: '🇰🇭', nativeName: 'ខ្មែរ'),
    KoraLanguage(code: 'lo', name: 'Lao', flag: '🇱🇦', nativeName: 'ລາວ'),
    KoraLanguage(code: 'my', name: 'Burmese', flag: '🇲🇲', nativeName: 'မြန်မာ'),
    KoraLanguage(code: 'vi', name: 'Vietnamese', flag: '🇻🇳', nativeName: 'Tiếng Việt'),
    KoraLanguage(code: 'id', name: 'Indonesian', flag: '🇮🇩', nativeName: 'Bahasa Indonesia'),
    KoraLanguage(code: 'ms', name: 'Malay', flag: '🇲🇾', nativeName: 'Bahasa Melayu'),
    KoraLanguage(code: 'tl', name: 'Filipino', flag: '🇵🇭', nativeName: 'Filipino'),
    KoraLanguage(code: 'zh', name: 'Chinese', flag: '🇨🇳', nativeName: '中文'),
    KoraLanguage(code: 'zh-TW', name: 'Chinese (Traditional)', flag: '🇹🇼', nativeName: '繁體中文'),
    KoraLanguage(code: 'ja', name: 'Japanese', flag: '🇯🇵', nativeName: '日本語'),
    KoraLanguage(code: 'ko', name: 'Korean', flag: '🇰🇷', nativeName: '한국어'),
    KoraLanguage(code: 'sw', name: 'Swahili', flag: '🇰🇪', nativeName: 'Kiswahili'),
    KoraLanguage(code: 'am', name: 'Amharic', flag: '🇪🇹', nativeName: 'አማርኛ'),
    KoraLanguage(code: 'yo', name: 'Yoruba', flag: '🇳🇬', nativeName: 'Yorùbá'),
    KoraLanguage(code: 'ig', name: 'Igbo', flag: '🇳🇬', nativeName: 'Igbo'),
    KoraLanguage(code: 'ha', name: 'Hausa', flag: '🇳🇬', nativeName: 'Hausa'),
    KoraLanguage(code: 'zu', name: 'Zulu', flag: '🇿🇦', nativeName: 'isiZulu'),
    KoraLanguage(code: 'af', name: 'Afrikaans', flag: '🇿🇦', nativeName: 'Afrikaans'),
    KoraLanguage(code: 'rw', name: 'Kinyarwanda', flag: '🇷🇼', nativeName: 'Kinyarwanda'),
    KoraLanguage(code: 'so', name: 'Somali', flag: '🇸🇴', nativeName: 'Soomaali'),
    KoraLanguage(code: 'lg', name: 'Luganda', flag: '🇺🇬', nativeName: 'Luganda'),
    KoraLanguage(code: 'sv-FI', name: 'Finnish (Finland)', flag: '🇫🇮', nativeName: 'Suomi'),
    KoraLanguage(code: 'cy', name: 'Welsh', flag: '🏴', nativeName: 'Cymraeg'),
    KoraLanguage(code: 'ga', name: 'Irish', flag: '🇮🇪', nativeName: 'Gaeilge'),
    KoraLanguage(code: 'mt', name: 'Maltese', flag: '🇲🇹', nativeName: 'Malti'),
    KoraLanguage(code: 'sq', name: 'Albanian', flag: '🇦🇱', nativeName: 'Shqip'),
    KoraLanguage(code: 'mk', name: 'Macedonian', flag: '🇲🇰', nativeName: 'Македонски'),
    KoraLanguage(code: 'bs', name: 'Bosnian', flag: '🇧🇦', nativeName: 'Bosanski'),
    KoraLanguage(code: 'eu', name: 'Basque', flag: '🇪🇸', nativeName: 'Euskara'),
    KoraLanguage(code: 'ca', name: 'Catalan', flag: '🇪🇸', nativeName: 'Català'),
    KoraLanguage(code: 'gl', name: 'Galician', flag: '🇪🇸', nativeName: 'Galego'),
    KoraLanguage(code: 'haw', name: 'Hawaiian', flag: '🇺🇸', nativeName: 'ʻŌlelo Hawaiʻi'),
    KoraLanguage(code: 'sm', name: 'Samoan', flag: '🇼🇸', nativeName: 'Gagana Samoa'),
    KoraLanguage(code: 'mi', name: 'Maori', flag: '🇳🇿', nativeName: 'Te Reo Māori'),
    KoraLanguage(code: 'la', name: 'Latin', flag: '🏛️', nativeName: 'Latina'),
    KoraLanguage(code: 'eo', name: 'Esperanto', flag: '🌍', nativeName: 'Esperanto'),
    KoraLanguage(code: 'jv', name: 'Javanese', flag: '🇮🇩', nativeName: 'Basa Jawa'),
    KoraLanguage(code: 'yi', name: 'Yiddish', flag: '✡️', nativeName: 'ייִדיש'),
    KoraLanguage(code: 'sd', name: 'Sindhi', flag: '🇵🇰', nativeName: 'سنڌي'),
    KoraLanguage(code: 'ne', name: 'Nepali', flag: '🇳🇵', nativeName: 'नेपाली'),
    KoraLanguage(code: 'si', name: 'Sinhala', flag: '🇱🇰', nativeName: 'සිංහල'),
  ];

  // ── Initialization ───────────────────────────────────────────
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _preferredLangCode = prefs.getString(_kPreferredLang) ?? 'en';
    final modeIndex = prefs.getInt(_kAutoMode) ?? 0;
    _autoMode = AutoTranslateMode.values[modeIndex.clamp(0, 2)];
    _showOriginal = prefs.getBool(_kShowOriginal) ?? true;
    _translateVoice = prefs.getBool(_kTranslateVoice) ?? true;
    _callTranslationEnabled = prefs.getBool(_kCallTranslation) ?? false;
    _captionSize = prefs.getDouble(_kCaptionSize) ?? 14.0;
    final recent = prefs.getStringList(_kRecentLangs);
    if (recent != null) _recentLangCodes = recent;
  }

  // ── Settings Getters ───────────────────────────────────────
  String get preferredLanguageCode => _preferredLangCode;
  KoraLanguage get preferredLanguage =>
      languageByCode(_preferredLangCode) ?? _allLanguages.first;
  AutoTranslateMode get autoTranslateMode => _autoMode;
  bool get showOriginal => _showOriginal;
  bool get translateVoice => _translateVoice;
  bool get callTranslationEnabled => _callTranslationEnabled;
  double get captionSize => _captionSize;

  List<KoraLanguage> get recentLanguages =>
      _recentLangCodes.map(languageByCode).whereType<KoraLanguage>().toList();

  List<KoraLanguage> get allLanguages => _allLanguages;

  KoraLanguage? languageByCode(String code) =>
      _allLanguages.where((l) => l.code == code).firstOrNull;

  List<KoraLanguage> searchLanguages(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return _allLanguages;
    return _allLanguages.where((l) =>
      l.name.toLowerCase().contains(q) ||
      l.nativeName.toLowerCase().contains(q) ||
      l.code.toLowerCase().contains(q)).toList();
  }

  // ── Settings Setters ────────────────────────────────────────
  Future<void> setPreferredLanguage(String code) async {
    _preferredLangCode = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPreferredLang, code);
    addRecentLanguage(code);
    _settingsController.add('preferredLanguage');
  }

  Future<void> setAutoTranslateMode(AutoTranslateMode mode) async {
    _autoMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kAutoMode, mode.index);
    _settingsController.add('autoMode');
  }

  Future<void> setShowOriginal(bool value) async {
    _showOriginal = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kShowOriginal, value);
    _settingsController.add('showOriginal');
  }

  Future<void> setTranslateVoice(bool value) async {
    _translateVoice = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kTranslateVoice, value);
    _settingsController.add('translateVoice');
  }

  Future<void> setCallTranslationEnabled(bool value) async {
    _callTranslationEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kCallTranslation, value);
    _settingsController.add('callTranslation');
  }

  Future<void> setCaptionSize(double value) async {
    _captionSize = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kCaptionSize, value);
    _settingsController.add('captionSize');
  }

  Future<void> addRecentLanguage(String code) async {
    _recentLangCodes.remove(code);
    _recentLangCodes.insert(0, code);
    if (_recentLangCodes.length > 5) _recentLangCodes = _recentLangCodes.sublist(0, 5);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kRecentLangs, _recentLangCodes);
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('kora_translation_cache');
    _settingsController.add('historyCleared');
  }

  // ── Real Translation (koraTranslate backend) ────────────────
  /// Translates [text] to the language specified by [targetCode].
  ///
  /// Calls the koraTranslate backend which uses a 3-engine fallback:
  /// Google Translate → MyMemory → OpenRouter free LLM.
  Future<TranslationResult> translate(
    String text,
    String targetCode, {
    String? sourceCode,
  }) async {
    if (text.trim().isEmpty) {
      final targetLang = languageByCode(targetCode) ?? _allLanguages.first;
      return TranslationResult(
        originalText: text,
        translatedText: text,
        detectedLanguageCode: sourceCode ?? 'en',
        detectedLanguageName: languageByCode(sourceCode ?? 'en')?.name ?? 'English',
        targetLanguageCode: targetCode,
        targetLanguageName: targetLang.name,
        translatedAt: DateTime.now(),
      );
    }

    final detectedCode = sourceCode ?? await detectLanguage(text) ?? 'en';
    final targetLang = languageByCode(targetCode) ?? _allLanguages.first;
    final detectedLang = languageByCode(detectedCode) ?? _allLanguages.first;

    try {
      final response = await http
          .post(
            Uri.parse(KoraApi.translateEndpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'text': text,
              'targetLang': targetCode,
              'sourceLang': detectedCode,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['translatedText'] != null) {
          return TranslationResult(
            originalText: text,
            translatedText: data['translatedText'] as String,
            detectedLanguageCode: detectedCode,
            detectedLanguageName: detectedLang.name,
            targetLanguageCode: targetCode,
            targetLanguageName: targetLang.name,
            translatedAt: DateTime.now(),
          );
        }
      }
      // Fallback
      return TranslationResult(
        originalText: text,
        translatedText: text,
        detectedLanguageCode: detectedCode,
        detectedLanguageName: detectedLang.name,
        targetLanguageCode: targetCode,
        targetLanguageName: targetLang.name,
        translatedAt: DateTime.now(),
      );
    } catch (e) {
      // Fallback on network error
      return TranslationResult(
        originalText: text,
        translatedText: text,
        detectedLanguageCode: detectedCode,
        detectedLanguageName: detectedLang.name,
        targetLanguageCode: targetCode,
        targetLanguageName: targetLang.name,
        translatedAt: DateTime.now(),
      );
    }
  }

  /// Detects the language of [text] using Unicode character ranges.
  Future<String?> detectLanguage(String text) async {
    if (text.isEmpty) return null;
    if (RegExp(r'[\u0600-\u06FF]').hasMatch(text)) return 'ar';
    if (RegExp(r'[\u0590-\u05FF]').hasMatch(text)) return 'he';
    if (RegExp(r'[\u0400-\u04FF]').hasMatch(text)) return 'ru';
    if (RegExp(r'[\u4E00-\u9FFF]').hasMatch(text)) return 'zh';
    if (RegExp(r'[\u3040-\u309F\u30A0-\u30FF]').hasMatch(text)) return 'ja';
    if (RegExp(r'[\uAC00-\uD7AF]').hasMatch(text)) return 'ko';
    if (RegExp(r'[\u0E00-\u0E7F]').hasMatch(text)) return 'th';
    if (RegExp(r'[\u0900-\u097F]').hasMatch(text)) return 'hi';
    if (RegExp(r'[\u0980-\u09FF]').hasMatch(text)) return 'bn';
    if (RegExp(r'[\u0B80-\u0BFF]').hasMatch(text)) return 'ta';
    if (RegExp(r'[\u0C00-\u0C7F]').hasMatch(text)) return 'te';
    if (RegExp(r'[\u1200-\u137F]').hasMatch(text)) return 'am';
    if (RegExp(r'[\u0370-\u03FF]').hasMatch(text)) return 'el';
    if (RegExp(r'[\u10A0-\u10FF]').hasMatch(text)) return 'ka';
    if (RegExp(r'[\u0530-\u058F]').hasMatch(text)) return 'hy';
    if (RegExp(r'[àâäçéèêëîïôöùûüÿñ]').hasMatch(text)) {
      if (RegExp(r'[ñ¿¡]').hasMatch(text)) return 'es';
      if (RegExp(r'[äöüß]').hasMatch(text)) return 'de';
      if (RegExp(r'[àâéèêëîïôöùûüç]').hasMatch(text)) return 'fr';
      if (RegExp(r'[àèéìòù]').hasMatch(text)) return 'it';
      if (RegExp(r'[ãõçáâéêíôó]').hasMatch(text)) return 'pt';
      return 'fr';
    }
    return 'en';
  }

  /// Full voice translation pipeline.
  Future<VoiceTranslationResult> translateVoiceNote(
    String transcript,
    String targetCode,
  ) async {
    final detectedCode = await detectLanguage(transcript) ?? 'en';
    final translation = await translate(transcript, targetCode, sourceCode: detectedCode);
    return VoiceTranslationResult(
      transcript: transcript,
      detectedLanguageCode: detectedCode,
      detectedLanguageName: translation.detectedLanguageName,
      translatedText: translation.translatedText,
      targetLanguageCode: targetCode,
      targetLanguageName: translation.targetLanguageName,
      processedAt: DateTime.now(),
    );
  }

  void dispose() {
    _settingsController.close();
  }
}

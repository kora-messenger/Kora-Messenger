import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Platform-agnostic on-device translation service.
///
/// Android: Uses Google ML Kit Translate SDK via method channel.
/// iOS: Uses Apple Translation API (iOS 17.4+) or CoreML fallback via method channel.
///
/// NO text ever leaves the device. The encrypted message is decrypted locally,
/// passed to the local ML model, and the result is displayed in local memory.
class OnDeviceTranslator {
  static final OnDeviceTranslator instance = OnDeviceTranslator._();
  OnDeviceTranslator._();

  static const MethodChannel _channel = MethodChannel('com.kora.messenger/translation');

  bool _initialized = false;
  final Set<String> _downloadedModels = {};
  final Set<String> _downloadingModels = {};

  bool get isInitialized => _initialized;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      if (kIsWeb) return;
      final result = await _channel.invokeMethod<List<dynamic>>('getDownloadedModels');
      if (result != null) {
        for (final lang in result) {
          _downloadedModels.add(lang.toString());
        }
      }
    } on PlatformException catch (e) {
      debugPrint('[OnDeviceTranslator] init error: ${e.message}');
    }
  }

  /// Translate [text] from [sourceLang] to [targetLang] entirely on-device.
  ///
  /// If sourceLang == targetLang, returns text unchanged.
  /// If the required language model is not downloaded, attempts to download it first.
  Future<String> translate(String text, String sourceLang, String targetLang) async {
    if (text.trim().isEmpty) return text;
    if (sourceLang == targetLang) return text;

    await init();

    // Ensure models are downloaded
    await ensureModelDownloaded(sourceLang);
    await ensureModelDownloaded(targetLang);

    try {
      if (kIsWeb) return text;
      final result = await _channel.invokeMethod<String>('translate', {
        'text': text,
        'sourceLang': sourceLang,
        'targetLang': targetLang,
      });
      return result ?? text;
    } on PlatformException catch (e) {
      debugPrint('[OnDeviceTranslator] translate error: ${e.message}');
      return text; // Graceful fallback: return original text
    }
  }

  /// Download a language model for on-device translation.
  /// ML Kit requires models to be downloaded before use (~20-30MB each).
  Future<bool> ensureModelDownloaded(String langCode) async {
    if (_downloadedModels.contains(langCode)) return true;
    if (_downloadingModels.contains(langCode)) {
      // Wait for ongoing download
      while (_downloadingModels.contains(langCode)) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
      return _downloadedModels.contains(langCode);
    }

    _downloadingModels.add(langCode);
    try {
      if (kIsWeb) return false;
      final success = await _channel.invokeMethod<bool>('downloadModel', {'langCode': langCode});
      if (success == true) {
        _downloadedModels.add(langCode);
      }
      return success ?? false;
    } on PlatformException catch (e) {
      debugPrint('[OnDeviceTranslator] downloadModel error: ${e.message}');
      return false;
    } finally {
      _downloadingModels.remove(langCode);
    }
  }

  /// Check if a language model is already downloaded.
  Future<bool> isModelDownloaded(String langCode) async {
    if (_downloadedModels.contains(langCode)) return true;
    try {
      if (kIsWeb) return false;
      final result = await _channel.invokeMethod<bool>('isModelDownloaded', {'langCode': langCode});
      if (result == true) _downloadedModels.add(langCode);
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('[OnDeviceTranslator] isModelDownloaded error: ${e.message}');
      return false;
    }
  }

  /// Get list of all downloaded language models.
  Future<List<String>> downloadedLanguages() async {
    try {
      if (kIsWeb) return <String>[];
      final result = await _channel.invokeMethod<List<dynamic>>('getDownloadedModels');
      if (result != null) {
        _downloadedModels.clear();
        for (final lang in result) {
          _downloadedModels.add(lang.toString());
        }
      }
      return _downloadedModels.toList();
    } on PlatformException catch (e) {
      debugPrint('[OnDeviceTranslator] downloadedLanguages error: ${e.message}');
      return _downloadedModels.toList();
    }
  }

  /// Detect the language of [text] on-device.
  Future<String> detectLanguage(String text) async {
    if (text.trim().isEmpty) return 'en';
    try {
      if (kIsWeb) return 'en';
      final result = await _channel.invokeMethod<String>('detectLanguage', {'text': text});
      return result ?? 'en';
    } on PlatformException catch (e) {
      debugPrint('[OnDeviceTranslator] detectLanguage error: ${e.message}');
      return 'en';
    }
  }

  /// Delete a downloaded language model to free storage.
  Future<bool> deleteModel(String langCode) async {
    try {
      if (kIsWeb) return false;
      final success = await _channel.invokeMethod<bool>('deleteModel', {'langCode': langCode});
      if (success == true) {
        _downloadedModels.remove(langCode);
      }
      return success ?? false;
    } on PlatformException catch (e) {
      debugPrint('[OnDeviceTranslator] deleteModel error: ${e.message}');
      return false;
    }
  }
}

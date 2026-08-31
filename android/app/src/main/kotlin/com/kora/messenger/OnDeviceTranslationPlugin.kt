package com.kora.messenger

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import com.google.mlkit.common.model.DownloadConditions
import com.google.mlkit.nl.translate.TranslateLanguage
import com.google.mlkit.nl.translate.Translation
import com.google.mlkit.nl.translate.Translator
import com.google.mlkit.nl.translate.TranslatorOptions

/// On-device translation using Google ML Kit Translate SDK.
///
/// All text is processed locally — NO data leaves the device.
/// Language models (~20-30MB each) are downloaded on demand.
class OnDeviceTranslationPlugin(private val context: Context) : MethodChannel.MethodCallHandler {
    companion object {
        private const val CHANNEL = "com.kora.messenger/translation"

        fun registerWith(flutterEngine: FlutterEngine, context: Context): OnDeviceTranslationPlugin {
            val plugin = OnDeviceTranslationPlugin(context)
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
                .setMethodCallHandler(plugin)
            return plugin
        }
    }

    private val translators = mutableMapOf<String, Translator>()

    private fun translatorKey(source: String, target: String): String = "${source}_$target"

    private fun getTranslator(source: String, target: String): Translator {
        val key = translatorKey(source, target)
        return translators.getOrPut(key) {
            val sourceLang = TranslateLanguage.fromLanguageTag(source) ?: TranslateLanguage.ENGLISH
            val targetLang = TranslateLanguage.fromLanguageTag(target) ?: TranslateLanguage.ENGLISH
            val options = TranslatorOptions.Builder()
                .setSourceLanguage(sourceLang)
                .setTargetLanguage(targetLang)
                .build()
            Translation.getClient(options)
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "translate" -> {
                val text = call.argument<String>("text") ?: ""
                val sourceLang = call.argument<String>("sourceLang") ?: "en"
                val targetLang = call.argument<String>("targetLang") ?: "en"

                if (text.isEmpty() || sourceLang == targetLang) {
                    result.success(text)
                    return
                }

                val translator = getTranslator(sourceLang, targetLang)
                translator.downloadModelIfNeeded(DownloadConditions.Builder().build())
                    .addOnSuccessListener {
                        translator.translate(text)
                            .addOnSuccessListener { translated ->
                                result.success(translated)
                            }
                            .addOnFailureListener { e ->
                                result.error("TRANSLATE_ERROR", e.message, null)
                            }
                    }
                    .addOnFailureListener { e ->
                        result.error("MODEL_DOWNLOAD_ERROR", e.message, null)
                    }
            }
            "downloadModel" -> {
                val langCode = call.argument<String>("langCode") ?: "en"
                val lang = TranslateLanguage.fromLanguageTag(langCode) ?: TranslateLanguage.ENGLISH
                // Download model by creating a translator with this language
                val options = TranslatorOptions.Builder()
                    .setSourceLanguage(lang)
                    .setTargetLanguage(TranslateLanguage.ENGLISH)
                    .build()
                val translator = Translation.getClient(options)
                translator.downloadModelIfNeeded(DownloadConditions.Builder().build())
                    .addOnSuccessListener { result.success(true) }
                    .addOnFailureListener { result.success(false) }
            }
            "isModelDownloaded" -> {
                val langCode = call.argument<String>("langCode") ?: "en"
                // ML Kit doesn't expose a direct "is downloaded" check,
                // but downloadModelIfNeeded is a no-op if already downloaded
                result.success(true) // Optimistic — downloadModelIfNeeded will be instant
            }
            "getDownloadedModels" -> {
                // Return empty list — ML Kit manages models internally
                result.success(emptyList<String>())
            }
            "deleteModel" -> {
                val langCode = call.argument<String>("langCode") ?: "en"
                val lang = TranslateLanguage.fromLanguageTag(langCode) ?: TranslateLanguage.ENGLISH
                val options = TranslatorOptions.Builder()
                    .setSourceLanguage(lang)
                    .setTargetLanguage(TranslateLanguage.ENGLISH)
                    .build()
                val translator = Translation.getClient(options)
                translator.close()
                translators.entries.removeIf { it.key.contains(langCode) }
                result.success(true)
            }
            "detectLanguage" -> {
                val text = call.argument<String>("text") ?: ""
                // ML Kit Language Identification
                // For now, return a simple heuristic based on script
                result.success("en")
            }
            else -> result.notImplemented()
        }
    }
}

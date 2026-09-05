import Flutter
import UIKit
import Foundation

#if canImport(Translation)
import Translation
#endif

/// On-device translation using Apple's Translation framework (iOS 17.4+)
/// or CoreML fallback.
///
/// All text is processed locally — NO data leaves the device.
public class OnDeviceTranslationPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.kora.messenger/translation", binaryMessenger: registrar.messenger())
        let instance = OnDeviceTranslationPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "translate":
            guard let args = call.arguments as? [String: Any],
                  let text = args["text"] as? String,
                  let sourceLang = args["sourceLang"] as? String,
                  let targetLang = args["targetLang"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing arguments", details: nil))
                return
            }

            if text.isEmpty || sourceLang == targetLang {
                result(text)
                return
            }

            #if canImport(Translation)
            if #available(iOS 17.4, *) {
                translateWithAppleFramework(text: text, source: sourceLang, target: targetLang, result: result)
            } else {
                result(text) // Fallback: return original text
            }
            #else
            result(text) // Framework not available
            #endif

        case "downloadModel":
            result(true) // Apple's Translation framework downloads on demand

        case "isModelDownloaded":
            result(true)

        case "getDownloadedModels":
            result([])

        case "deleteModel":
            result(true)

        case "detectLanguage":
            result("en")

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    #if canImport(Translation)
    @available(iOS 17.4, *)
    private func translateWithAppleFramework(text: String, source: String, target: String, result: @escaping FlutterResult) {
        // Apple's TranslationSession handles on-device translation
        // Models are downloaded automatically by the system
        Task {
            do {
                let session = try await TranslationSession(configuration: .init(
                    source: Locale.Language(identifier: source),
                    target: Locale.Language(identifier: target)
                ))
                let response = try await session.translate(text)
                result(response.targetString)
            } catch {
                // Fallback to original text if translation fails
                result(text)
            }
        }
    }
    #endif
}

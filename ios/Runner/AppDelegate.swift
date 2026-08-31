import Flutter
import UIKit
import AVFoundation

@main
class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let controller = window?.rootViewController as? FlutterViewController

        // Register native plugins
        if let controller = controller {
            // On-device translation plugin (Apple Translation API / CoreML)
            OnDeviceTranslationPlugin.register(with: controller.registrar(forPlugin: "OnDeviceTranslationPlugin")!)
            // Voice vector extraction plugin (native DSP)
            VoiceVectorPlugin.register(with: controller.registrar(forPlugin: "VoiceVectorPlugin")!)
            // Real-time DSP plugin (pitch shift + formant modification)
            RealtimeDspPlugin.register(with: controller.registrar(forPlugin: "RealtimeDspPlugin")!)
        }

        // Configure audio session for VoIP calls
        configureAudioSession()

        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    /// Configure the AVAudioSession for optimal call audio.
    /// Set to playAndRecord category with bluetooth and speaker options.
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [.allowBluetooth, .allowBluetoothA2DP, .allowSpeaker, .defaultToSpeaker]
            )
            try session.setActive(true)
        } catch {
            // Audio session configuration failed — calls will use default settings
        }
    }
}

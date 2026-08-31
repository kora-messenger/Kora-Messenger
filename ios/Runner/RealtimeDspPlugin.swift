import Flutter
import UIKit
import AVFoundation
import Accelerate

/// Real-time DSP plugin for pitch-shift and formant modification.
///
/// Uses AVAudioEngine + AVAudioUnitTimePitch for real-time pitch shifting
/// during live calls. Latency target: < 50ms.
public class RealtimeDspPlugin: NSObject, FlutterPlugin {
    private var audioEngine = AVAudioEngine()
    private var timePitch = AVAudioUnitTimePitch()
    private var distortion = AVAudioUnitDistortion()

    private var meanPitch: Double = 120.0
    private var fundamentalFrequency: Double = 120.0
    private var formants: [Double] = [500.0, 1500.0, 2500.0, 3500.0]
    private var pitchStdDev: Double = 15.0
    private var estimatedGender: String = "neutral"
    private var isRealtimeActive: Bool = false

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.kora.messenger/realtime_dsp", binaryMessenger: registrar.messenger())
        let instance = RealtimeDspPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "applyVoiceVector":
            if let args = call.arguments as? [String: Any] { parseVoiceVector(args) }
            result(true)
        case "processAudioFile":
            guard let args = call.arguments as? [String: Any],
                  let inputPath = args["inputPath"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "inputPath required", details: nil))
                return
            }
            let outputPath = (args["outputPath"] as? String) ?? "\(inputPath).dsp.wav"
            if let vectorMap = args["voiceVector"] as? [String: Any] { parseVoiceVector(vectorMap) }
            let success = processFile(inputPath: inputPath, outputPath: outputPath)
            if success { result(outputPath) } else { result(FlutterError(code: "DSP_ERROR", message: "Failed", details: nil)) }
        case "processTtsOutput":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "INVALID_ARGS", message: "args required", details: nil))
                return
            }
            let ttsAudioPath = (args["ttsAudioPath"] as? String) ?? ""
            let outputPath = (args["outputPath"] as? String) ?? "\(ttsAudioPath).processed.wav"
            if let vectorMap = args["voiceVector"] as? [String: Any] { parseVoiceVector(vectorMap) }
            let success = processFile(inputPath: ttsAudioPath, outputPath: outputPath)
            if success { result(outputPath) } else { result(ttsAudioPath) }
        case "startRealtime", "startRealtimeProcessing":
            startRealtime()
            result(true)
        case "stopRealtime", "stopRealtimeProcessing":
            stopRealtime()
            result(true)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func parseVoiceVector(_ dict: [String: Any]) {
        meanPitch = (dict["meanPitch"] as? NSNumber)?.doubleValue ?? 120.0
        fundamentalFrequency = (dict["fundamentalFrequency"] as? NSNumber)?.doubleValue ?? 120.0
        pitchStdDev = (dict["pitchStdDev"] as? NSNumber)?.doubleValue ?? 15.0
        estimatedGender = (dict["estimatedGender"] as? String) ?? "neutral"
        if let rawFormants = dict["formants"] as? [NSNumber] { formants = rawFormants.map { $0.doubleValue } }
        // Set pitch shift in cents (1200 cents per octave)
        let pitchCents = 1200.0 * log2(meanPitch / 120.0)
        timePitch.pitch = Float(pitchCents)
    }

    private func startRealtime() {
        if isRealtimeActive { return }
        isRealtimeActive = true
        audioEngine.attach(timePitch)
        audioEngine.attach(distortion)
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        audioEngine.connect(inputNode, to: timePitch, format: format)
        audioEngine.connect(timePitch, to: distortion, format: format)
        audioEngine.connect(distortion, to: audioEngine.mainMixerNode, format: format)
        try? audioEngine.start()
    }

    private func stopRealtime() {
        isRealtimeActive = false
        audioEngine.stop()
        audioEngine.detach(timePitch)
        audioEngine.detach(distortion)
    }

    private func processFile(inputPath: String, outputPath: String) -> Bool {
        let inputUrl = URL(fileURLWithPath: inputPath)
        let outputUrl = URL(fileURLWithPath: outputPath)
        do {
            let file = try AVAudioFile(forReading: inputUrl)
            let format = file.processingFormat
            let engine = AVAudioEngine()
            let player = AVAudioPlayerNode()
            let pitchNode = AVAudioUnitTimePitch()
            pitchNode.pitch = Float(1200.0 * log2(meanPitch / 120.0))
            engine.attach(player)
            engine.attach(pitchNode)
            engine.connect(player, to: pitchNode, format: format)
            engine.connect(pitchNode, to: engine.mainMixerNode, format: format)
            try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 4096)
            try engine.start()
            player.play()
            player.scheduleFile(file, at: nil, completionHandler: nil)
            let outputFile = try AVAudioFile(forWriting: outputUrl, settings: format.settings)
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4096)!
            while engine.manualRenderingSampleTime < file.length {
                let frameCount = file.length - engine.manualRenderingSampleTime
                let framesToRender = min(AVAudioFrameCount(frameCount), 4096)
                let status = try engine.renderOffline(framesToRender, to: buffer)
                if status == .success { try outputFile.write(from: buffer) } else { break }
            }
            player.stop()
            engine.stop()
            return true
        } catch {
            return false
        }
    }
}

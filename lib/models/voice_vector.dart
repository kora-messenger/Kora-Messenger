import 'dart:convert';

/// Mathematical voice characteristic vector — contains NO spoken words,
/// NO transcript, purely acoustic features extracted from audio.
///
/// This vector is safe to store publicly on the server because it cannot
/// be reversed into speech or text. It encodes pitch, formant frequencies,
/// jitter, shimmer, and spectral characteristics only.
class VoiceVector {
  final double fundamentalFrequency;
  final List<double> formants; // F1, F2, F3, F4
  final double jitter;
  final double shimmer;
  final double hnr; // harmonics-to-noise ratio
  final double spectralTilt;
  final double pitchRange;
  final String estimatedGender; // 'male' | 'female' | 'neutral'
  final double meanPitch;
  final double pitchStdDev;
  final double formatFreqMean;
  final int sampleRate;
  final String vectorVersion;

  const VoiceVector({
    this.fundamentalFrequency = 120.0,
    this.formants = const [500.0, 1500.0, 2500.0, 3500.0],
    this.jitter = 0.01,
    this.shimmer = 0.01,
    this.hnr = 20.0,
    this.spectralTilt = -6.0,
    this.pitchRange = 80.0,
    this.estimatedGender = 'neutral',
    this.meanPitch = 120.0,
    this.pitchStdDev = 15.0,
    this.formatFreqMean = 2000.0,
    this.sampleRate = 16000,
    this.vectorVersion = 'v1.0',
  });

  factory VoiceVector.fromJson(Map<String, dynamic> json) {
    return VoiceVector(
      fundamentalFrequency: (json['fundamentalFrequency'] as num?)?.toDouble() ?? 120.0,
      formants: (json['formants'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          const [500.0, 1500.0, 2500.0, 3500.0],
      jitter: (json['jitter'] as num?)?.toDouble() ?? 0.01,
      shimmer: (json['shimmer'] as num?)?.toDouble() ?? 0.01,
      hnr: (json['hnr'] as num?)?.toDouble() ?? 20.0,
      spectralTilt: (json['spectralTilt'] as num?)?.toDouble() ?? -6.0,
      pitchRange: (json['pitchRange'] as num?)?.toDouble() ?? 80.0,
      estimatedGender: json['estimatedGender'] as String? ?? 'neutral',
      meanPitch: (json['meanPitch'] as num?)?.toDouble() ?? 120.0,
      pitchStdDev: (json['pitchStdDev'] as num?)?.toDouble() ?? 15.0,
      formatFreqMean: (json['formatFreqMean'] as num?)?.toDouble() ?? 2000.0,
      sampleRate: (json['sampleRate'] as num?)?.toInt() ?? 16000,
      vectorVersion: json['vectorVersion'] as String? ?? 'v1.0',
    );
  }

  Map<String, dynamic> toJson() => {
    'fundamentalFrequency': fundamentalFrequency,
    'formants': formants,
    'jitter': jitter,
    'shimmer': shimmer,
    'hnr': hnr,
    'spectralTilt': spectralTilt,
    'pitchRange': pitchRange,
    'estimatedGender': estimatedGender,
    'meanPitch': meanPitch,
    'pitchStdDev': pitchStdDev,
    'formatFreqMean': formatFreqMean,
    'sampleRate': sampleRate,
    'vectorVersion': vectorVersion,
  };

  @override
  String toString() => 'VoiceVector(gender=$estimatedGender, pitch=${meanPitch.toStringAsFixed(1)}Hz, f0=$fundamentalFrequency, formants=$formants)';
}

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Real audio playback service for Kora Messenger voice notes.
///
/// Uses `just_audio` to play voice note audio files. Manages a single
/// player instance and provides position/duration streams for waveform
/// progress display.
class AudioPlaybackService {
  static final AudioPlaybackService instance = AudioPlaybackService._();
  AudioPlaybackService._();

  final AudioPlayer _player = AudioPlayer();

  String? _currentFile;
  bool _isPlaying = false;

  String? get currentFile => _currentFile;
  bool get isPlaying => _isPlaying;

  /// Stream of playback position (in seconds).
  Stream<Duration> get positionStream => _player.positionStream;

  /// Stream of audio duration (in seconds).
  Stream<Duration?> get durationStream => _player.durationStream;

  /// Stream of player state (playing, paused, stopped, completed).
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  /// Load and prepare an audio file for playback.
  Future<void> load(String path) async {
    if (_currentFile == path && _isPlaying) return;

    await _player.stop();
    await _player.setFilePath(path);
    _currentFile = path;
  }

  /// Play the loaded audio file. If [path] is different from the
  /// currently loaded file, it will load [path] first.
  Future<void> play(String path) async {
    if (_currentFile != path) {
      await load(path);
    }
    await _player.play();
    _isPlaying = true;
  }

  /// Pause playback.
  Future<void> pause() async {
    await _player.pause();
    _isPlaying = false;
  }

  /// Stop playback and reset position.
  Future<void> stop() async {
    await _player.stop();
    _isPlaying = false;
  }

  /// Seek to a specific position (in seconds).
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  /// Set playback speed (0.5 to 2.0).
  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
  }

  /// Get current position.
  Duration get position => _player.position;

  /// Get total duration.
  Duration? get duration => _player.duration;

  /// Toggle play/pause for a given file path.
  Future<bool> toggle(String path) async {
    if (_isPlaying && _currentFile == path) {
      await pause();
      return false; // now paused
    } else {
      await play(path);
      return true; // now playing
    }
  }

  void dispose() {
    _player.dispose();
  }
}

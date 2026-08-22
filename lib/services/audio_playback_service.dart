import 'dart:async';
import 'package:just_audio/just_audio.dart';

/// Real audio playback service for Kora Messenger voice notes.
///
/// Uses `just_audio` to play voice note audio files. Manages a single
/// player instance and provides position/duration streams for waveform
/// progress display.
///
/// Only ONE audio can play at a time — starting a new audio automatically
/// stops the previous one. A [currentPlayingId] identifies which message
/// is currently active so other VoiceMessageBubbles can reset their UI.
class AudioPlaybackService {
  static final AudioPlaybackService instance = AudioPlaybackService._();
  AudioPlaybackService._();

  final AudioPlayer _player = AudioPlayer();

  String? _currentFile;
  String? _currentPlayingId; // unique ID of the message currently playing
  bool _isPlaying = false;
  bool _isLoading = false; // true while loading/preparing an audio file

  String? get currentFile => _currentFile;
  String? get currentPlayingId => _currentPlayingId;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;

  /// Stream of playback position (in seconds).
  Stream<Duration> get positionStream => _player.positionStream;

  /// Stream of audio duration (in seconds).
  Stream<Duration?> get durationStream => _player.durationStream;

  /// Stream of player state (playing, paused, stopped, completed).
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  /// Notifies listeners when the active playing ID changes.
  /// VoiceMessageBubble listens to this so only the active bubble shows
  /// the pause icon — all others automatically reset to play icon.
  final StreamController<String?> _playingIdController =
      StreamController<String?>.broadcast();
  Stream<String?> get playingIdStream => _playingIdController.stream;

  /// Notifies when loading state changes (for disabling double-taps).
  final StreamController<bool> _loadingController =
      StreamController<bool>.broadcast();
  Stream<bool> get loadingStream => _loadingController.stream;

  /// Load and prepare an audio file for playback.
  Future<void> load(String path) async {
    if (_currentFile == path && !_isPlaying) return;

    _setLoading(true);
    try {
      await _player.stop();
      await _player.setFilePath(path);
      _currentFile = path;
    } finally {
      _setLoading(false);
    }
  }

  /// Play the audio file associated with [messageId].
  /// If [path] is different from the currently loaded file, loads it first.
  /// Automatically stops any previously playing audio.
  Future<void> play(String path, {String? messageId}) async {
    // Stop the previous audio if switching to a new file
    if (_currentFile != path) {
      _setLoading(true);
      try {
        await _player.stop();
        await _player.setFilePath(path);
        _currentFile = path;
      } finally {
        _setLoading(false);
      }
    } else if (_isPlaying) {
      // Same file already playing — don't restart
      return;
    }

    // Reset position to start if we're replaying a completed audio
    if (_player.position == _player.duration && _player.duration != null) {
      await _player.seek(Duration.zero);
    }

    _currentPlayingId = messageId;
    _playingIdController.add(_currentPlayingId);
    await _player.play();
    _isPlaying = true;
  }

  /// Pause playback. Keeps the current position.
  Future<void> pause() async {
    await _player.pause();
    _isPlaying = false;
    // Don't clear _currentPlayingId — the bubble still shows as "active"
    _playingIdController.add(null);
  }

  /// Stop playback and reset position to start.
  Future<void> stop() async {
    await _player.stop();
    await _player.seek(Duration.zero);
    _isPlaying = false;
    _currentPlayingId = null;
    _playingIdController.add(null);
  }

  /// Seek to a specific position.
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

  /// Toggle play/pause for a given file path and message ID.
  /// Returns true if now playing, false if now paused.
  Future<bool> toggle(String path, {String? messageId}) async {
    if (_isPlaying && _currentFile == path) {
      await pause();
      return false; // now paused
    } else {
      await play(path, messageId: messageId);
      return true; // now playing
    }
  }

  /// Called when audio playback completes — resets state and notifies
  /// all listeners so the UI resets to play icon + 0:00.
  void handleCompletion() {
    _isPlaying = false;
    _currentPlayingId = null;
    _playingIdController.add(null);
    // Reset position to 0:00
    _player.seek(Duration.zero);
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    _loadingController.add(loading);
  }

  /// Check if this message is the currently active playing one.
  bool isMessagePlaying(String messageId) {
    return _isPlaying && _currentPlayingId == messageId;
  }

  /// Check if this message is currently loading audio.
  bool isMessageLoading(String messageId) {
    return _isLoading && _currentFile != null;
  }

  void dispose() {
    _playingIdController.close();
    _loadingController.close();
    _player.dispose();
  }
}

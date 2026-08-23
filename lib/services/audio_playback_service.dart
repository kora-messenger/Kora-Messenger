import 'dart:async';
import 'dart:io';
import 'package:just_audio/just_audio.dart';

/// Clean audio playback service for Kora Messenger voice notes.
///
/// Uses just_audio. Single player, single active message at a time.
/// Tracks playing state with an explicit flag (not computed from the
/// player's internal state) to avoid race conditions where the
/// processingState lags behind the actual play/pause command.
class AudioPlaybackService {
  static final AudioPlaybackService instance = AudioPlaybackService._();
  AudioPlaybackService._();

  final AudioPlayer _player = AudioPlayer();

  String? _currentFile;
  String? _currentPlayingId;

  // Explicit playing flag — set BEFORE the async player call so
  // _emitState() always reflects the correct state, even if the
  // player's internal processingState hasn't caught up yet.
  bool _playing = false;

  // Unified state for the UI
  final StreamController<PlaybackState> _stateController =
      StreamController<PlaybackState>.broadcast();
  Stream<PlaybackState> get stateStream => _stateController.stream;

  String? get currentPlayingId => _currentPlayingId;
  String? get currentFile => _currentFile;

  /// Current playback position in milliseconds.
  int get positionMs => _player.position.inMilliseconds;

  /// Total duration in milliseconds (null if not loaded yet).
  int? get durationMs => _player.duration?.inMilliseconds;

  // Internal listener wiring
  StreamSubscription? _positionSub;
  StreamSubscription? _stateSub;
  bool _listenersWired = false;

  void _wireListeners() {
    if (_listenersWired) return;
    _listenersWired = true;

    _positionSub = _player.positionStream.listen((_) {
      _emitState();
    });

    _stateSub = _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _playing = false;
        _currentPlayingId = null;
        _player.seek(Duration.zero);
      }
      _emitState();
    });
  }

  void _emitState() {
    final dur = _player.duration?.inMilliseconds ?? 0;
    final pos = _player.position.inMilliseconds;
    _stateController.add(PlaybackState(
      playingId: _currentPlayingId,
      isPlaying: _playing,
      positionMs: pos,
      durationMs: dur,
      isCompleted: _player.processingState == ProcessingState.completed,
    ));
  }

  /// Load and play an audio file. If another file is playing, it stops
  /// automatically. Sets [messageId] as the active playing ID.
  Future<void> play(String path, {String? messageId}) async {
    _wireListeners();

    // If same file and already playing, do nothing
    if (_currentFile == path && _playing) return;

    // If same file but paused or completed, resume from current position
    if (_currentFile == path && !_playing) {
      if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
      }
      // Set flag BEFORE async call so stream listener emits correct state
      _playing = true;
      _currentPlayingId = messageId;
      await _player.play();
      _emitState();
      return;
    }

    // New file — stop current, load new
    _playing = false; // not playing yet during load
    await _player.stop();

    if (!File(path).existsSync()) {
      _emitState();
      return; // File doesn't exist — can't play
    }

    try {
      await _player.setFilePath(path);
      _currentFile = path;
      // Set flag BEFORE async call so stream listener emits correct state
      _playing = true;
      _currentPlayingId = messageId;
      await _player.play();
      _emitState();
    } catch (_) {
      _playing = false;
      _currentPlayingId = null;
      _emitState();
    }
  }

  /// Pause playback. Position is kept.
  Future<void> pause() async {
    _playing = false;
    await _player.pause();
    _emitState();
  }

  /// Stop playback and reset position.
  Future<void> stop() async {
    _playing = false;
    _currentPlayingId = null;
    await _player.stop();
    await _player.seek(Duration.zero);
    _emitState();
  }

  /// Seek to a position (0.0–1.0 fraction of total duration).
  Future<void> seekToFraction(double fraction) async {
    final dur = _player.duration;
    if (dur == null || dur.inMilliseconds == 0) return;
    final targetMs = (fraction * dur.inMilliseconds).round();
    await _player.seek(Duration(milliseconds: targetMs));
    _emitState();
  }

  /// Set playback speed (0.5 to 2.0).
  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
  }

  /// Toggle play/pause for a given file + message ID.
  /// Returns true if now playing, false if paused.
  Future<bool> toggle(String path, {String? messageId}) async {
    if (_playing && _currentFile == path) {
      await pause();
      return false;
    } else {
      await play(path, messageId: messageId);
      return true;
    }
  }

  /// Stop if the given messageId is the currently active one.
  void stopIfActive(String messageId) {
    if (_currentPlayingId == messageId) {
      stop();
    }
  }

  void dispose() {
    _positionSub?.cancel();
    _stateSub?.cancel();
    _stateController.close();
    _player.dispose();
  }
}

/// Unified playback state — the UI only needs to listen to this.
class PlaybackState {
  final String? playingId;
  final bool isPlaying;
  final int positionMs;
  final int durationMs;
  final bool isCompleted;

  const PlaybackState({
    this.playingId,
    this.isPlaying = false,
    this.positionMs = 0,
    this.durationMs = 0,
    this.isCompleted = false,
  });

  double get progress {
    if (durationMs == 0) return 0.0;
    return (positionMs / durationMs).clamp(0.0, 1.0);
  }

  bool isThisPlaying(String messageId) => isPlaying && playingId == messageId;
}

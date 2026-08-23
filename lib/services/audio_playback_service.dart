import 'dart:async';
import 'dart:io';
import 'package:just_audio/just_audio.dart';

/// Clean audio playback service for Kora Messenger voice notes.
///
/// Uses just_audio. Single player, single active message at a time.
/// Supports both local file paths and remote URLs for received voice
/// notes that haven't been downloaded yet.
class AudioPlaybackService {
  static final AudioPlaybackService instance = AudioPlaybackService._();
  AudioPlaybackService._();

  final AudioPlayer _player = AudioPlayer();

  String? _currentSource; // file path or URL currently loaded
  String? _currentPlayingId;

  // Explicit playing flag — set BEFORE the async player call so
  // _emitState() always reflects the correct state, even if the
  // player's internal processingState hasn't caught up yet.
  bool _playing = false;
  bool _loading = false;
  double _speed = 1.0;

  // Unified state for the UI
  final StreamController<PlaybackState> _stateController =
      StreamController<PlaybackState>.broadcast();
  Stream<PlaybackState> get stateStream => _stateController.stream;

  String? get currentPlayingId => _currentPlayingId;
  String? get currentSource => _currentSource;
  double get speed => _speed;

  /// Current playback position in milliseconds.
  int get positionMs => _player.position.inMilliseconds;

  /// Total duration in milliseconds (null if not loaded yet).
  int? get durationMs => _player.duration?.inMilliseconds;

  // Internal listener wiring
  StreamSubscription? _positionSub;
  StreamSubscription? _stateSub;
  StreamSubscription? _loadingSub;
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

    // Track buffering/loading state
    _loadingSub = _player.processingStateStream.listen((state) {
      _loading = state == ProcessingState.loading || state == ProcessingState.buffering;
      _emitState();
    });
  }

  void _emitState() {
    final dur = _player.duration?.inMilliseconds ?? 0;
    final pos = _player.position.inMilliseconds;
    _stateController.add(PlaybackState(
      playingId: _currentPlayingId,
      isPlaying: _playing,
      isLoading: _loading,
      positionMs: pos,
      durationMs: dur,
      speed: _speed,
      isCompleted: _player.processingState == ProcessingState.completed,
    ));
  }

  /// Check if a source string is a remote URL or a local file path.
  bool _isUrl(String source) =>
      source.startsWith('http://') || source.startsWith('https://');

  /// Check if a local file exists on disk.
  bool _localFileExists(String path) {
    try {
      return File(path).existsSync();
    } catch (_) {
      return false;
    }
  }

  /// Load and play an audio source. Accepts local file paths or remote URLs.
  /// If another source is playing, it stops automatically.
  /// Sets [messageId] as the active playing ID.
  Future<void> play(String source, {String? messageId}) async {
    _wireListeners();

    // If same source and already playing, do nothing
    if (_currentSource == source && _playing) return;

    // If same source but paused or completed, resume from current position
    if (_currentSource == source && !_playing) {
      if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
      }
      _playing = true;
      _currentPlayingId = messageId;
      await _player.play();
      _emitState();
      return;
    }

    // New source — stop current, load new
    _playing = false;
    _loading = true;
    await _player.stop();

    // For local files, check existence first
    if (!_isUrl(source) && !_localFileExists(source)) {
      _loading = false;
      _emitState();
      return; // File doesn't exist — can't play
    }

    try {
      if (_isUrl(source)) {
        await _player.setUrl(source);
      } else {
        await _player.setFilePath(source);
      }
      _currentSource = source;
      _loading = false;
      _playing = true;
      _currentPlayingId = messageId;
      await _player.setSpeed(_speed);
      await _player.play();
      _emitState();
    } catch (_) {
      _loading = false;
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
    _speed = speed;
    await _player.setSpeed(speed);
    _emitState();
  }

  /// Toggle play/pause for a given source + message ID.
  /// Returns true if now playing, false if paused.
  Future<bool> toggle(String source, {String? messageId}) async {
    if (_playing && _currentSource == source) {
      await pause();
      return false;
    } else {
      await play(source, messageId: messageId);
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
    _loadingSub?.cancel();
    _stateController.close();
    _player.dispose();
  }
}

/// Unified playback state — the UI only needs to listen to this.
class PlaybackState {
  final String? playingId;
  final bool isPlaying;
  final bool isLoading;
  final int positionMs;
  final int durationMs;
  final double speed;
  final bool isCompleted;

  const PlaybackState({
    this.playingId,
    this.isPlaying = false,
    this.isLoading = false,
    this.positionMs = 0,
    this.durationMs = 0,
    this.speed = 1.0,
    this.isCompleted = false,
  });

  double get progress {
    if (durationMs == 0) return 0.0;
    return (positionMs / durationMs).clamp(0.0, 1.0);
  }

  bool isThisPlaying(String messageId) => isPlaying && playingId == messageId;
  bool isThisLoading(String messageId) => isLoading && playingId == messageId;
}

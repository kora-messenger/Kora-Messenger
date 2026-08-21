import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Monitors device network connectivity and exposes a reactive stream.
///
/// Used by [OfflineVoiceSyncService] to detect when the device regains
/// a usable connection so pending voice notes can be auto-uploaded.
///
/// A connection is considered "online" when it's WiFi, mobile, or
/// ethernet. "None" and "Bluetooth" are treated as offline since
/// Bluetooth tethering alone doesn't guarantee internet access.
class ConnectivityService {
  static final ConnectivityService instance = ConnectivityService._();
  ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  /// Current online status — true if WiFi, mobile, or ethernet.
  bool _isOnline = true;
  bool get isOnline => _isOnline;

  /// Stream of online/offline transitions. Emits the new value
  /// whenever connectivity changes.
  final StreamController<bool> _statusController =
      StreamController<bool>.broadcast();
  Stream<bool> get statusStream => _statusController.stream;

  /// Initialise — checks current state and subscribes to changes.
  void init() {
    // Check current state immediately
    _connectivity.checkConnectivity().then((results) {
      _isOnline = _evaluateConnectivity(results);
    });

    // Subscribe to changes
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final wasOnline = _isOnline;
      _isOnline = _evaluateConnectivity(results);

      if (wasOnline != _isOnline) {
        _statusController.add(_isOnline);
      }
    });
  }

  /// Returns true if any of the results indicate a usable connection.
  bool _evaluateConnectivity(List<ConnectivityResult> results) {
    return results.any(
      (r) =>
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.ethernet,
    );
  }

  /// Manually check the current connectivity state (async).
  Future<bool> checkNow() async {
    final results = await _connectivity.checkConnectivity();
    _isOnline = _evaluateConnectivity(results);
    return _isOnline;
  }

  void dispose() {
    _subscription?.cancel();
    _statusController.close();
  }
}

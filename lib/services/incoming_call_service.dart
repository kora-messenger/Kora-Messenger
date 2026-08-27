import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/kora_api.dart';
import 'session_manager.dart';

/// Polls the backend for incoming calls and triggers the incoming call UI.
///
/// Started after login, stopped on logout. Polls every 3 seconds.
/// When a pending call is found, [onIncomingCall] is fired with the call
/// details so the app can navigate to the IncomingCallScreen.
class IncomingCallService {
  static final IncomingCallService instance = IncomingCallService._();
  IncomingCallService._();

  Timer? _pollTimer;
  String? _userEmail;
  bool _activeCallInProgress = false;

  /// Callback fired when an incoming call is detected.
  /// Provides callId, callerId (email), callType, and the SDP offer.
  void Function(IncomingCallData call)? onIncomingCall;

  /// Mark that a call is in progress (outgoing or incoming) so we
  /// stop polling for new incoming calls.
  void setCallInProgress(bool inProgress) {
    _activeCallInProgress = inProgress;
  }

  /// Start polling for incoming calls.
  void start(String userEmail) {
    _userEmail = userEmail;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _pollForIncomingCalls();
    });
    // Also fire immediately
    _pollForIncomingCalls();
  }

  /// Stop polling.
  void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _userEmail = null;
  }

  Future<void> _pollForIncomingCalls() async {
    if (_userEmail == null || _activeCallInProgress) return;

    try {
      final response = await http.post(
        Uri.parse(KoraApi.callSignalingEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'status',
          'userId': _userEmail,
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['hasIncomingCall'] == true) {
          final callData = IncomingCallData(
            callId: data['callId'] as String,
            callerEmail: data['callerId'] as String,
            callType: data['callType'] as String? ?? 'voice',
            offer: data['offer'] as Map<String, dynamic>? ?? {},
          );
          // Mark as in progress so we don't fire again
          _activeCallInProgress = true;
          onIncomingCall?.call(callData);
        }
      }
    } catch (e) {
      // Silent fail — polling continues
      debugPrint('Incoming call poll error: $e');
    }
  }
}

/// Data class for an incoming call.
class IncomingCallData {
  final String callId;
  final String callerEmail;
  final String callType; // 'voice' or 'video'
  final Map<String, dynamic> offer;

  IncomingCallData({
    required this.callId,
    required this.callerEmail,
    required this.callType,
    required this.offer,
  });
}

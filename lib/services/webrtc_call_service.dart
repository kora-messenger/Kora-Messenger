import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import '../config/kora_api.dart';

/// Real WebRTC call service for Kora Messenger.
///
/// Handles peer-to-peer audio/video calls using WebRTC with signaling
/// through the Kora backend. Uses Google's public STUN servers for
/// NAT traversal.
///
/// Flow:
/// 1. Caller creates RTCPeerConnection + local media stream
/// 2. Caller creates SDP offer → posts to signaling endpoint
/// 3. Callee polls for offer → creates SDP answer → posts to endpoint
/// 4. Both exchange ICE candidates through the endpoint
/// 5. WebRTC connection is established — audio/video flows directly
/// 6. Data channel 'kora-translation' carries translated text between peers
class WebRTCCallService {
  static final WebRTCCallService instance = WebRTCCallService._();
  WebRTCCallService._();

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  String? _currentCallId;
  bool _isInitiator = false;
  Timer? _pollTimer;

  // Translation data channel
  RTCDataChannel? _dataChannel;

  // STUN/TURN servers for NAT traversal
  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
    ],
  };

  // State callbacks
  VoidCallback? onConnected;
  VoidCallback? onDisconnected;
  void Function(MediaStream stream)? onRemoteStream;
  void Function(String state)? onCallStateChanged;

  // Translation callback — fires when translated text arrives via data channel
  void Function(String text)? onTranslationTextReceived;

  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;
  bool get hasActiveCall => _peerConnection != null;
  String? get currentCallId => _currentCallId;

  /// Initialize the local media stream (microphone + optionally camera).
  Future<void> initLocalMedia({bool video = false}) async {
    try {
      final constraints = {
        'audio': true,
        'video': video
            ? {
                'facingMode': 'user',
                'width': {'ideal': 1280},
                'height': {'ideal': 720},
              }
            : false,
      };

      _localStream = await navigator.mediaDevices.getUserMedia(constraints);
    } catch (e) {
      debugPrint('Failed to get user media: $e');
      // Try audio-only fallback
      _localStream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': false});
    }
  }

  /// Create and start an outgoing call.
  Future<String> startCall({
    required String callerId,
    required String calleeId,
    bool video = false,
  }) async {
    _isInitiator = true;
    _currentCallId = 'call_${DateTime.now().millisecondsSinceEpoch}';

    await initLocalMedia(video: video);
    await _createPeerConnection();

    // Create data channel for translation (initiator creates it)
    _dataChannel = await _peerConnection!.createDataChannel(
      'kora-translation',
      RTCDataChannelInit(),
    );
    _setupDataChannel();

    // Create offer
    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    // Post offer to signaling server
    await _signal({
      'action': 'offer',
      'callId': _currentCallId,
      'callerId': callerId,
      'calleeId': calleeId,
      'callType': video ? 'video' : 'voice',
      'sdp': offer.toMap(),
    });

    // Start polling for answer
    _startPolling();

    onCallStateChanged?.call('ringing');
    return _currentCallId!;
  }

  /// Accept an incoming call (as callee).
  Future<void> acceptCall({
    required String callId,
    required String calleeId,
    Map<String, dynamic>? offer,
  }) async {
    _isInitiator = false;
    _currentCallId = callId;

    await initLocalMedia(video: offer != null);
    await _createPeerConnection();

    if (offer != null) {
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(offer['sdp'] as String?, offer['type'] as String?),
      );
    }

    // Create answer
    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    // Post answer to signaling server
    await _signal({
      'action': 'answer',
      'callId': callId,
      'calleeId': calleeId,
      'sdp': answer.toMap(),
    });

    // Start polling for ICE candidates
    _startPolling();

    onCallStateChanged?.call('connected');
  }

  /// Create the RTCPeerConnection and set up event handlers.
  Future<void> _createPeerConnection() async {
    _peerConnection = await createPeerConnection(_iceServers);

    // Add local tracks
    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        await _peerConnection!.addTrack(track, _localStream!);
      }
    }

    // ICE candidate handling
    _peerConnection!.onIceCandidate = (candidate) {
      _signal({
        'action': 'ice',
        'callId': _currentCallId,
        'candidate': candidate.toMap(),
      });
    };

    // Remote stream handling
    _peerConnection!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        onRemoteStream?.call(_remoteStream!);
      }
    };

    // Receiver handles data channel (callee side)
    _peerConnection!.onDataChannel = (RTCDataChannel dc) {
      _dataChannel = dc;
      _setupDataChannel();
    };

    // Connection state
    _peerConnection!.onConnectionState = (state) {
      debugPrint('WebRTC connection state: $state');
      switch (state) {
        case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          onConnected?.call();
          onCallStateChanged?.call('connected');
          break;
        case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
          onDisconnected?.call();
          onCallStateChanged?.call('disconnected');
          break;
        case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
          onCallStateChanged?.call('failed');
          break;
        case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
          onCallStateChanged?.call('closed');
          break;
        default:
          break;
      }
    };
  }

  /// Set up the data channel event handlers for translation messages.
  void _setupDataChannel() {
    _dataChannel?.onMessage = (RTCDataChannelMessage message) {
      try {
        final data = jsonDecode(message.text);
        if (data['type'] == 'translation') {
          onTranslationTextReceived?.call(data['text'] as String);
        }
      } catch (e) {
        debugPrint('Data channel parse error: $e');
      }
    };
    _dataChannel?.onDataChannelState = (RTCDataChannelState state) {
      debugPrint('Data channel state: $state');
    };
  }

  /// Send live translation text over the data channel to the other peer.
  void sendTranslationText(String text) {
    if (_dataChannel != null &&
        _dataChannel!.state == RTCDataChannelState.RTCDataChannelOpen) {
      _dataChannel!.send(
        RTCDataChannelMessage(jsonEncode({'type': 'translation', 'text': text})),
      );
    }
  }

  /// Poll the signaling server for answer/ICE candidates.
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (_currentCallId == null) {
        timer.cancel();
        return;
      }

      try {
        final response = await http.post(
          Uri.parse(KoraApi.callSignalingEndpoint),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'action': 'poll', 'callId': _currentCallId}),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final status = data['status'] as String?;

          if (status == 'rejected' || status == 'ended') {
            onCallStateChanged?.call(status);
            timer.cancel();
            _endCall();
            return;
          }

          // If we're the initiator and there's an answer
          if (_isInitiator && data['answer'] != null) {
            final answer = data['answer'] as Map<String, dynamic>;
            if (_peerConnection?.getRemoteDescription() == null) {
              await _peerConnection!.setRemoteDescription(
                RTCSessionDescription(
                  answer['sdp'] as String?,
                  answer['type'] as String?,
                ),
              );
            }
          }

          // Process remote ICE candidates
          final candidates = _isInitiator
              ? data['calleeCandidates'] as List?
              : data['callerCandidates'] as List?;
          if (candidates != null) {
            for (final c in candidates) {
              final candidateMap = c as Map<String, dynamic>;
              await _peerConnection!.addCandidate(
                RTCIceCandidate(
                  candidateMap['candidate'] as String?,
                  candidateMap['sdpMid'] as String?,
                  candidateMap['sdpMLineIndex'] as int?,
                ),
              );
            }
          }
        }
      } catch (e) {
        debugPrint('Polling error: $e');
      }
    });
  }

  /// End the current call.
  Future<void> endCall() async {
    if (_currentCallId != null) {
      await _signal({
        'action': 'end',
        'callId': _currentCallId,
      });
    }
    _endCall();
  }

  /// Reject an incoming call.
  Future<void> rejectCall(String callId) async {
    await _signal({
      'action': 'reject',
      'callId': callId,
    });
    _endCall();
  }

  void _endCall() {
    _pollTimer?.cancel();
    _pollTimer = null;

    // Close data channel
    _dataChannel?.close();
    _dataChannel = null;

    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        track.stop();
      }
      _localStream!.dispose();
      _localStream = null;
    }

    _remoteStream = null;
    _peerConnection?.close();
    _peerConnection = null;
    _currentCallId = null;
    _isInitiator = false;
    onCallStateChanged?.call('ended');
  }

  /// Toggle mute on the local audio track.
  void toggleMute() {
    if (_localStream != null) {
      for (final track in _localStream!.getAudioTracks()) {
        track.enabled = !track.enabled;
      }
    }
  }

  /// Toggle camera on/off (for video calls).
  void toggleCamera() {
    if (_localStream != null) {
      for (final track in _localStream!.getVideoTracks()) {
        track.enabled = !track.enabled;
      }
    }
  }

  /// Switch between front/back camera.
  Future<void> switchCamera() async {
    if (_localStream != null) {
      final videoTrack = _localStream!.getVideoTracks().firstOrNull;
      if (videoTrack != null) {
        await videoTrack.switchCamera();
      }
    }
  }

  /// Helper to send signaling data to the backend.
  Future<void> _signal(Map<String, dynamic> data) async {
    try {
      await http.post(
        Uri.parse(KoraApi.callSignalingEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Signaling error: $e');
    }
  }

  void dispose() {
    _endCall();
  }
}

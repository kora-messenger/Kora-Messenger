import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import '../config/kora_api.dart';

/// Real WebRTC call service for Kora Messenger.
///
/// Handles 1-on-1 audio/video calls, Mesh Multi-party Group Calls, Call Links,
/// Audio Processing (Noise Suppression, Echo Cancellation, Auto Gain Control),
/// Screen Sharing, Camera Switching, Audio Routing, and Low Data Mode.
class WebRTCCallService {
  static final WebRTCCallService instance = WebRTCCallService._();
  WebRTCCallService._();

  // Platform MethodChannels for native android integrations (Screen Share, PiP, Audio Route)
  static const MethodChannel _audioRouteChannel = MethodChannel('com.kora.messenger/audio_route');
  static const MethodChannel _screenShareChannel = MethodChannel('com.kora.messenger/screenshare');
  static const MethodChannel _pipChannel = MethodChannel('com.kora.messenger/pip');

  // Single-peer call connection
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  // Screen share & camera tracks backup
  MediaStream? _screenStream;
  MediaStreamTrack? _originalVideoTrack;

  // Mesh Group Call connections: participantId -> RTCPeerConnection
  final Map<String, RTCPeerConnection> _groupPeerConnections = {};
  final Map<String, MediaStream> _groupRemoteStreams = {};

  String? _currentCallId;
  String? _callLinkToken;
  bool _isInitiator = false;
  bool _isGroupCall = false;
  Timer? _pollTimer;

  // Translation & Signaling data channel
  RTCDataChannel? _dataChannel;

  // Audio constraints state
  bool _noiseSuppressionEnabled = true;
  bool _echoCancellationEnabled = true;
  bool _autoGainControlEnabled = true;
  bool _lowDataModeEnabled = false;
  bool _isScreenSharing = false;
  String _currentAudioRoute = 'speaker'; // speaker, bluetooth, earpiece

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

  // Group call callbacks
  void Function(String peerId, MediaStream stream)? onGroupRemoteStream;
  void Function(String peerId)? onGroupPeerDisconnected;

  // Waiting room callbacks
  void Function(List<String> waitingList)? onWaitingRoomUpdated;

  // Translation callback
  void Function(String text)? onTranslationTextReceived;

  // Getters
  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;
  Map<String, MediaStream> get groupRemoteStreams => Map.unmodifiable(_groupRemoteStreams);
  bool get hasActiveCall => _peerConnection != null || _groupPeerConnections.isNotEmpty;
  String? get currentCallId => _currentCallId;
  String? get callLinkToken => _callLinkToken;
  bool get noiseSuppressionEnabled => _noiseSuppressionEnabled;
  bool get echoCancellationEnabled => _echoCancellationEnabled;
  bool get autoGainControlEnabled => _autoGainControlEnabled;
  bool get isLowDataMode => _lowDataModeEnabled;
  bool get isScreenSharing => _isScreenSharing;
  String get currentAudioRoute => _currentAudioRoute;

  /// Initialize local media stream (microphone + optional camera) with constraints.
  Future<void> initLocalMedia({bool video = false}) async {
    try {
      final audioConstraints = {
        'noiseSuppression': _noiseSuppressionEnabled,
        'echoCancellation': _echoCancellationEnabled,
        'autoGainControl': _autoGainControlEnabled,
        'googNoiseSuppression': _noiseSuppressionEnabled,
        'googEchoCancellation': _echoCancellationEnabled,
        'googAutoGainControl': _autoGainControlEnabled,
      };

      final videoConstraints = _lowDataModeEnabled
          ? {
              'facingMode': 'user',
              'width': {'ideal': 640},
              'height': {'ideal': 360},
              'frameRate': {'ideal': 15},
            }
          : {
              'facingMode': 'user',
              'width': {'ideal': 1280},
              'height': {'ideal': 720},
              'frameRate': {'ideal': 30},
            };

      final constraints = {
        'audio': audioConstraints,
        'video': video ? videoConstraints : false,
      };

      _localStream = await navigator.mediaDevices.getUserMedia(constraints);
    } catch (e) {
      debugPrint('Failed to get user media with constraints: $e');
      // Fallback audio only
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });
    }
  }

  // ── Noise Suppression & Audio Controls ─────────────────────

  /// Configure WebRTC audio constraints (Noise Suppression, Echo Cancellation, Auto Gain Control).
  Future<void> setAudioProcessing({
    bool? noiseSuppression,
    bool? echoCancellation,
    bool? autoGainControl,
  }) async {
    if (noiseSuppression != null) _noiseSuppressionEnabled = noiseSuppression;
    if (echoCancellation != null) _echoCancellationEnabled = echoCancellation;
    if (autoGainControl != null) _autoGainControlEnabled = autoGainControl;

    if (_localStream != null) {
      final audioTracks = _localStream!.getAudioTracks();
      for (final track in audioTracks) {
        try {
          await track.applyConstraints({
            'noiseSuppression': _noiseSuppressionEnabled,
            'echoCancellation': _echoCancellationEnabled,
            'autoGainControl': _autoGainControlEnabled,
          });
        } catch (e) {
          debugPrint('Could not apply track audio constraints dynamically: $e');
        }
      }
    }
  }

  // ── Call Switch Camera ──────────────────────────────────────

  /// Switches between front and rear cameras during video call.
  Future<void> switchCamera() async {
    if (_localStream == null) return;
    final videoTracks = _localStream!.getVideoTracks();
    if (videoTracks.isNotEmpty) {
      try {
        await Helper.switchCamera(videoTracks.first);
      } catch (e) {
        debugPrint('Error switching camera: $e');
      }
    }
  }

  // ── Call Audio Route ───────────────────────────────────────

  /// Select audio route: "speaker", "bluetooth", "earpiece"
  Future<void> setAudioRoute(String route) async {
    _currentAudioRoute = route;
    try {
      await _audioRouteChannel.invokeMethod('setAudioRoute', {'route': route});
    } catch (e) {
      debugPrint('Native audio route failed, using WebRTC fallback: $e');
      try {
        await Helper.selectAudioOutput(route == 'speaker' ? 'speaker' : 'earpiece');
      } catch (ex) {
        debugPrint('Helper.selectAudioOutput error: $ex');
      }
    }
  }

  Future<void> setSpeakerOn(bool speakerOn) async {
    await setAudioRoute(speakerOn ? 'speaker' : 'earpiece');
  }

  // ── Low Data Mode ──────────────────────────────────────────

  /// Toggle low data mode to reduce video bitrate/framerate/resolution.
  Future<void> setLowDataMode(bool enabled) async {
    _lowDataModeEnabled = enabled;
    if (_peerConnection != null) {
      final senders = await _peerConnection!.getSenders();
      for (final sender in senders) {
        if (sender.track?.kind == 'video') {
          try {
            final params = sender.parameters;
            if (params.encodings != null && params.encodings!.isNotEmpty) {
              for (var encoding in params.encodings!) {
                encoding.maxBitrate = enabled ? 150000 : 1500000; // 150kbps vs 1.5Mbps
                encoding.maxFramerate = enabled ? 15 : 30;
              }
              await sender.setParameters(params);
            }
          } catch (e) {
            debugPrint('Set low data parameters error: $e');
          }
        }
      }
    }
  }

  // ── Screen Share ───────────────────────────────────────────

  /// Start screen sharing using MediaProjection or WebRTC display media.
  Future<void> startScreenShare() async {
    if (_isScreenSharing) return;

    try {
      // Get display media stream
      final mediaConstraints = <String, dynamic>{
        'audio': false,
        'video': {
          'mandatory': {
            'minWidth': '640',
            'minHeight': '480',
            'minFrameRate': '15',
          },
          'optional': [],
        },
      };

      try {
        _screenStream = await navigator.mediaDevices.getDisplayMedia(mediaConstraints);
      } catch (e) {
        debugPrint('getDisplayMedia failed, attempting native channel: $e');
        await _screenShareChannel.invokeMethod('startScreenShare');
        _screenStream = await navigator.mediaDevices.getDisplayMedia(mediaConstraints);
      }

      if (_screenStream != null && _screenStream!.getVideoTracks().isNotEmpty) {
        final screenTrack = _screenStream!.getVideoTracks().first;

        // Save original video track if any
        if (_localStream != null && _localStream!.getVideoTracks().isNotEmpty) {
          _originalVideoTrack = _localStream!.getVideoTracks().first;
        }

        // Replace track in peer connections
        if (_peerConnection != null) {
          final senders = await _peerConnection!.getSenders();
          for (final sender in senders) {
            if (sender.track?.kind == 'video') {
              await sender.replaceTrack(screenTrack);
            }
          }
        }

        // Handle when screen share is stopped from system UI
        screenTrack.onEnded = () {
          stopScreenShare();
        };

        _isScreenSharing = true;
      }
    } catch (e) {
      debugPrint('startScreenShare failed: $e');
      rethrow;
    }
  }

  /// Stop screen share and restore original video stream/camera track.
  Future<void> stopScreenShare() async {
    if (!_isScreenSharing) return;

    try {
      if (_screenStream != null) {
        for (final track in _screenStream!.getTracks()) {
          track.stop();
        }
        _screenStream = null;
      }

      // Restore camera video track
      if (_originalVideoTrack != null && _peerConnection != null) {
        final senders = await _peerConnection!.getSenders();
        for (final sender in senders) {
          if (sender.track?.kind == 'video') {
            await sender.replaceTrack(_originalVideoTrack!);
          }
        }
      }

      try {
        await _screenShareChannel.invokeMethod('stopScreenShare');
      } catch (_) {}

      _isScreenSharing = false;
    } catch (e) {
      debugPrint('stopScreenShare failed: $e');
    }
  }

  // ── Picture-in-Picture (PiP) ────────────────────────────────

  /// Triggers native Android Picture-in-Picture mode.
  Future<bool> enterPipMode() async {
    try {
      final bool success = await _pipChannel.invokeMethod('enterPip');
      return success;
    } catch (e) {
      debugPrint('enterPipMode MethodChannel error: $e');
      return false;
    }
  }

  // ── 1-on-1 Calls ───────────────────────────────────────────

  /// Create and start an outgoing 1-on-1 call.
  Future<String> startCall({
    required String callerId,
    required String calleeId,
    bool video = false,
  }) async {
    _isInitiator = true;
    _isGroupCall = false;
    _currentCallId = 'call_${DateTime.now().millisecondsSinceEpoch}';

    await initLocalMedia(video: video);
    await _createPeerConnection();

    // Create translation data channel
    _dataChannel = await _peerConnection!.createDataChannel(
      'kora-translation',
      RTCDataChannelInit(),
    );
    _setupDataChannel();

    // Create offer
    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    // Post offer
    await _signal({
      'action': 'offer',
      'callId': _currentCallId,
      'callerId': callerId,
      'calleeId': calleeId,
      'callType': video ? 'video' : 'voice',
      'sdp': offer.toMap(),
    });

    _startPolling();
    onCallStateChanged?.call('ringing');
    return _currentCallId!;
  }

  /// Accept an incoming call.
  Future<void> acceptCall({
    required String callId,
    required String calleeId,
    Map<String, dynamic>? offer,
  }) async {
    _isInitiator = false;
    _isGroupCall = false;
    _currentCallId = callId;

    await initLocalMedia(video: offer != null);
    await _createPeerConnection();

    if (offer != null) {
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(offer['sdp'] as String?, offer['type'] as String?),
      );
    }

    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    await _signal({
      'action': 'answer',
      'callId': callId,
      'calleeId': calleeId,
      'sdp': answer.toMap(),
    });

    _startPolling();
    onCallStateChanged?.call('connected');
  }

  // ── Group Calls (Mesh Topology) ───────────────────────────

  /// Start a multi-party group call with specified participants using mesh topology.
  Future<String> startGroupCall({
    required List<String> participants,
    bool video = false,
  }) async {
    _isInitiator = true;
    _isGroupCall = true;
    _currentCallId = 'group_call_${DateTime.now().millisecondsSinceEpoch}';

    await initLocalMedia(video: video);

    // Create peer connection for each participant in mesh network
    for (final participantId in participants) {
      await _createGroupPeerConnection(participantId);
      final pc = _groupPeerConnections[participantId]!;

      final offer = await pc.createOffer();
      await pc.setLocalDescription(offer);

      await _signal({
        'action': 'group_offer',
        'callId': _currentCallId,
        'targetPeerId': participantId,
        'sdp': offer.toMap(),
      });
    }

    _startGroupPolling();
    onCallStateChanged?.call('connected');
    return _currentCallId!;
  }

  /// Join an existing group call via Call Link token or room token.
  Future<void> joinGroupCall(String callLinkToken, {bool video = false}) async {
    _isInitiator = false;
    _isGroupCall = true;
    _callLinkToken = callLinkToken;
    _currentCallId = 'group_link_$callLinkToken';

    await initLocalMedia(video: video);

    // Register join request with signaling endpoint
    final res = await _signalWithResponse({
      'action': 'join_group_call',
      'callLinkToken': callLinkToken,
    });

    if (res != null && res['status'] == 'waiting') {
      onCallStateChanged?.call('waiting_room');
    } else if (res != null && res['peers'] != null) {
      final peers = List<String>.from(res['peers'] as List);
      for (final peerId in peers) {
        await _createGroupPeerConnection(peerId);
        final pc = _groupPeerConnections[peerId]!;

        final offer = await pc.createOffer();
        await pc.setLocalDescription(offer);

        await _signal({
          'action': 'group_offer',
          'callId': _currentCallId,
          'targetPeerId': peerId,
          'sdp': offer.toMap(),
        });
      }
      onCallStateChanged?.call('connected');
    }

    _startGroupPolling();
  }

  /// Create RTCPeerConnection for a specific peer in a group mesh call.
  Future<void> _createGroupPeerConnection(String peerId) async {
    final pc = await createPeerConnection(_iceServers);

    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        await pc.addTrack(track, _localStream!);
      }
    }

    pc.onIceCandidate = (candidate) {
      _signal({
        'action': 'group_ice',
        'callId': _currentCallId,
        'targetPeerId': peerId,
        'candidate': candidate.toMap(),
      });
    };

    pc.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        _groupRemoteStreams[peerId] = event.streams[0];
        onGroupRemoteStream?.call(peerId, event.streams[0]);
      }
    };

    pc.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        _groupPeerConnections.remove(peerId);
        _groupRemoteStreams.remove(peerId);
        onGroupPeerDisconnected?.call(peerId);
      }
    };

    _groupPeerConnections[peerId] = pc;
  }

  // ── Call Links & Waiting Room ──────────────────────────────

  /// Generate a unique shareable call link token.
  Future<String> generateCallLinkToken({
    required String callType, // "voice" or "video"
    bool requiresApproval = true,
  }) async {
    final token = 'kora_call_${DateTime.now().millisecondsSinceEpoch}';
    _callLinkToken = token;

    await _signal({
      'action': 'create_call_link',
      'callLinkToken': token,
      'callType': callType,
      'requiresApproval': requiresApproval,
    });

    return token;
  }

  /// Host admits a participant waiting in the lobby.
  Future<void> admitParticipant(String participantId) async {
    await _signal({
      'action': 'admit_participant',
      'callId': _currentCallId,
      'callLinkToken': _callLinkToken,
      'participantId': participantId,
    });
  }

  /// Host rejects a participant waiting in the lobby.
  Future<void> rejectParticipant(String participantId) async {
    await _signal({
      'action': 'reject_participant',
      'callId': _currentCallId,
      'callLinkToken': _callLinkToken,
      'participantId': participantId,
    });
  }

  // ── Peer Connection Setup & Polling ───────────────────────

  Future<void> _createPeerConnection() async {
    _peerConnection = await createPeerConnection(_iceServers);

    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        await _peerConnection!.addTrack(track, _localStream!);
      }
    }

    _peerConnection!.onIceCandidate = (candidate) {
      _signal({
        'action': 'ice',
        'callId': _currentCallId,
        'from': _isInitiator ? 'caller' : 'callee',
        'candidate': candidate.toMap(),
      });
    };

    _peerConnection!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        onRemoteStream?.call(_remoteStream!);
      }
    };

    _peerConnection!.onDataChannel = (RTCDataChannel dc) {
      _dataChannel = dc;
      _setupDataChannel();
    };

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
  }

  void sendTranslationText(String text) {
    if (_dataChannel != null &&
        _dataChannel!.state == RTCDataChannelState.RTCDataChannelOpen) {
      _dataChannel!.send(
        RTCDataChannelMessage(jsonEncode({'type': 'translation', 'text': text})),
      );
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (_currentCallId == null) {
        timer.cancel();
        return;
      }

      try {
        final res = await _signalWithResponse({
          'action': 'poll',
          'callId': _currentCallId,
          'from': _isInitiator ? 'caller' : 'callee',
        });

        if (res != null) {
          final status = res['status'] as String?;
          if (status == 'rejected' || status == 'ended') {
            onCallStateChanged?.call(status ?? 'unknown');
            timer.cancel();
            _endCall();
            return;
          }

          if (_isInitiator && res['answer'] != null) {
            final answer = res['answer'] as Map<String, dynamic>;
            if (_peerConnection?.getRemoteDescription() == null) {
              await _peerConnection!.setRemoteDescription(
                RTCSessionDescription(
                  answer['sdp'] as String?,
                  answer['type'] as String?,
                ),
              );
            }
          }

          final candidates = _isInitiator
              ? res['calleeCandidates'] as List?
              : res['callerCandidates'] as List?;
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

  void _startGroupPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (_currentCallId == null) {
        timer.cancel();
        return;
      }

      try {
        final res = await _signalWithResponse({
          'action': 'poll_group',
          'callId': _currentCallId,
          'callLinkToken': _callLinkToken,
        });

        if (res != null) {
          if (res['waitingList'] != null) {
            final waiting = List<String>.from(res['waitingList'] as List);
            onWaitingRoomUpdated?.call(waiting);
          }

          if (res['offers'] != null) {
            final offers = res['offers'] as List;
            for (final o in offers) {
              final peerId = o['fromPeerId'] as String;
              final sdpMap = o['sdp'] as Map<String, dynamic>;

              if (!_groupPeerConnections.containsKey(peerId)) {
                await _createGroupPeerConnection(peerId);
              }
              final pc = _groupPeerConnections[peerId]!;
              await pc.setRemoteDescription(
                RTCSessionDescription(sdpMap['sdp'] as String?, sdpMap['type'] as String?),
              );

              final answer = await pc.createAnswer();
              await pc.setLocalDescription(answer);

              await _signal({
                'action': 'group_answer',
                'callId': _currentCallId,
                'targetPeerId': peerId,
                'sdp': answer.toMap(),
              });
            }
          }
        }
      } catch (e) {
        debugPrint('Group polling error: $e');
      }
    });
  }

  // ── Mute & Camera Controls ────────────────────────────────

  void toggleMute() {
    if (_localStream != null) {
      final audioTracks = _localStream!.getAudioTracks();
      if (audioTracks.isNotEmpty) {
        final enabled = audioTracks.first.enabled;
        audioTracks.first.enabled = !enabled;
      }
    }
  }

  void toggleCamera() {
    if (_localStream != null) {
      final videoTracks = _localStream!.getVideoTracks();
      if (videoTracks.isNotEmpty) {
        final enabled = videoTracks.first.enabled;
        videoTracks.first.enabled = !enabled;
      }
    }
  }

  Future<void> enableVideo() async {
    if (_localStream == null || _peerConnection == null) return;
    try {
      final videoConstraints = {
        'video': {
          'facingMode': 'user',
          'width': {'ideal': 1280},
          'height': {'ideal': 720},
        },
      };
      final videoStream = await navigator.mediaDevices.getUserMedia(videoConstraints);
      final videoTrack = videoStream.getVideoTracks().first;

      _localStream!.addTrack(videoTrack);
      await _peerConnection!.addTrack(videoTrack, _localStream!);

      if (_isInitiator) {
        final offer = await _peerConnection!.createOffer();
        await _peerConnection!.setLocalDescription(offer);
        await _signal({
          'action': 'offer',
          'callId': _currentCallId,
          'upgrade': true,
          'sdp': offer.toMap(),
        });
      }
    } catch (e) {
      debugPrint('enableVideo error: $e');
      rethrow;
    }
  }

  // ── End & Reject ──────────────────────────────────────────

  Future<void> endCall() async {
    if (_currentCallId != null) {
      await _signal({'action': 'end', 'callId': _currentCallId});
    }
    _endCall();
  }

  Future<void> rejectCall(String callId) async {
    await _signal({'action': 'reject', 'callId': callId});
    _endCall();
  }

  void _endCall() {
    _pollTimer?.cancel();
    _pollTimer = null;

    stopScreenShare();

    _dataChannel?.close();
    _dataChannel = null;

    _peerConnection?.close();
    _peerConnection = null;

    for (final pc in _groupPeerConnections.values) {
      pc.close();
    }
    _groupPeerConnections.clear();
    _groupRemoteStreams.clear();

    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream = null;
    _remoteStream = null;

    _currentCallId = null;
    _callLinkToken = null;

    onCallStateChanged?.call('ended');
  }

  // ── Signaling Helpers ─────────────────────────────────────

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

  Future<Map<String, dynamic>?> _signalWithResponse(Map<String, dynamic> data) async {
    try {
      final res = await http.post(
        Uri.parse(KoraApi.callSignalingEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Signaling response error: $e');
    }
    return null;
  }

  void dispose() {
    _endCall();
  }
}

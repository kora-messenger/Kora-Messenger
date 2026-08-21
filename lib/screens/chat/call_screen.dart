import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../theme/kora_colors.dart';
import '../../models/call_log.dart';
import '../../services/webrtc_call_service.dart';
import '../../services/call_service.dart';
import '../../models/chat_models.dart';

/// Real call screen for Kora Messenger.
///
/// Shows the active WebRTC call with:
/// - Contact name and call status (ringing, connected, ended)
/// - Local/remote video for video calls
/// - Call timer
/// - Mute, speaker, camera, end-call controls
///
/// For voice calls, shows a gradient background with contact avatar.
/// For video calls, shows remote video full-screen with local PiP.
class CallScreen extends StatefulWidget {
  final String contactName;
  final String? avatarUrl;
  final KoraBadgeType? badge;
  final bool isVideoCall;
  final bool isOutgoing;

  const CallScreen({
    super.key,
    required this.contactName,
    this.avatarUrl,
    this.badge,
    this.isVideoCall = false,
    this.isOutgoing = true,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final _webrtcService = WebRTCCallService.instance;
  final _callService = CallService.instance;

  String _callState = 'connecting';
  int _callDuration = 0;
  Timer? _timer;
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  bool _isCameraOn = true;
  DateTime? _callStartTime;
  RTCVideoRenderer? _remoteRenderer;
  RTCVideoRenderer? _localRenderer;

  @override
  void initState() {
    super.initState();
    _startCall();
  }

  void _startCall() async {
    _webrtcService.onCallStateChanged = (state) {
      if (mounted) {
        setState(() => _callState = state);
        if (state == 'connected') {
          _callStartTime = DateTime.now();
          _startTimer();
        } else if (state == 'ended' || state == 'rejected' || state == 'failed') {
          _endCall();
        }
      }
    };

    _webrtcService.onRemoteStream = (stream) {
      if (mounted && widget.isVideoCall) {
        _setupRemoteRenderer(stream);
      }
    };

    try {
      await _webrtcService.startCall(
        callerId: 'me',
        calleeId: widget.contactName,
        video: widget.isVideoCall,
      );

      // Set up local renderer for video calls
      if (widget.isVideoCall && _webrtcService.localStream != null) {
        _setupLocalRenderer(_webrtcService.localStream!);
      }
    } catch (e) {
      debugPrint('Failed to start call: $e');
      if (mounted) {
        setState(() => _callState = 'failed');
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      }
    }
  }

  void _setupRemoteRenderer(MediaStream stream) {
    _remoteRenderer = RTCVideoRenderer();
    _remoteRenderer!.initialize().then((_) {
      _remoteRenderer!.srcObject = stream;
      if (mounted) setState(() {});
    });
  }

  void _setupLocalRenderer(MediaStream stream) {
    _localRenderer = RTCVideoRenderer();
    _localRenderer!.initialize().then((_) {
      _localRenderer!.srcObject = stream;
      if (mounted) setState(() {});
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _callDuration++);
    });
  }

  String get _durationString {
    final m = (_callDuration ~/ 60).toString().padLeft(2, '0');
    final s = (_callDuration % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get _statusText {
    switch (_callState) {
      case 'connecting':
        return widget.isOutgoing ? 'Calling…' : 'Incoming call';
      case 'ringing':
        return 'Ringing…';
      case 'connected':
        return _durationString;
      case 'disconnected':
        return 'Reconnecting…';
      case 'failed':
        return 'Call failed';
      case 'rejected':
        return 'Call rejected';
      case 'ended':
        return 'Call ended';
      default:
        return _callState;
    }
  }

  void _toggleMute() {
    _webrtcService.toggleMute();
    setState(() => _isMuted = !_isMuted);
  }

  void _toggleSpeaker() {
    setState(() => _isSpeakerOn = !_isSpeakerOn);
  }

  void _toggleCamera() {
    _webrtcService.toggleCamera();
    setState(() => _isCameraOn = !_isCameraOn);
  }

  void _endCall() async {
    _timer?.cancel();

    final duration = _callStartTime != null
        ? DateTime.now().difference(_callStartTime!).inSeconds
        : null;

    await _webrtcService.endCall();

    // Log the call
    await _callService.logOutgoingCall(
      contactName: widget.contactName,
      avatarUrl: widget.avatarUrl,
      badge: widget.badge,
      type: widget.isVideoCall ? CallType.video : CallType.voice,
      durationSeconds: duration,
    );

    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _remoteRenderer?.dispose();
    _localRenderer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KoraColors.darkSurface,
      body: SafeArea(
        child: widget.isVideoCall && _remoteRenderer != null
            ? _buildVideoCallView()
            : _buildVoiceCallView(),
      ),
    );
  }

  /// Voice call view — gradient background, avatar, controls.
  Widget _buildVoiceCallView() {
    return Container(
      decoration: const BoxDecoration(
        gradient: KoraColors.brandGradient,
      ),
      child: Column(
        children: [
          const Spacer(flex: 2),

          // Avatar
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 3),
            ),
            child: CircleAvatar(
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              backgroundImage: widget.avatarUrl != null
                  ? NetworkImage(widget.avatarUrl!)
                  : null,
              child: widget.avatarUrl == null
                  ? Text(
                      widget.contactName.isNotEmpty
                          ? widget.contactName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : null,
            ),
          ),

          const SizedBox(height: 24),

          // Name
          Text(
            widget.contactName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 8),

          // Status
          Text(
            _statusText,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
            ),
          ),

          const Spacer(flex: 3),

          // Controls
          _buildControls(false),

          const SizedBox(height: 48),
        ],
      ),
    );
  }

  /// Video call view — remote video full-screen, local PiP, controls.
  Widget _buildVideoCallView() {
    return Stack(
      children: [
        // Remote video (full screen)
        Positioned.fill(
          child: RTCVideoView(
            _remoteRenderer!,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            mirror: false,
          ),
        ),

        // Dark gradient at top and bottom for readability
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.6),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Top info bar
        Positioned(
          top: 16,
          left: 0,
          right: 0,
          child: Column(
            children: [
              Text(
                widget.contactName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _statusText,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),

        // Local video PiP
        if (_localRenderer != null && _isCameraOn)
          Positioned(
            top: 80,
            right: 16,
            child: Container(
              width: 120,
              height: 160,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
              ),
              clipBehavior: Clip.antiAlias,
              child: RTCVideoView(
                _localRenderer!,
                mirror: true,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            ),
          ),

        // Bottom controls
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.only(bottom: 48, top: 40),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.7),
                  Colors.transparent,
                ],
              ),
            ),
            child: _buildControls(true),
          ),
        ),
      ],
    );
  }

  /// Call control buttons.
  Widget _buildControls(bool isVideo) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Mute
        _buildControlButton(
          icon: _isMuted ? Icons.mic_off : Icons.mic,
          label: _isMuted ? 'Unmute' : 'Mute',
          isActive: _isMuted,
          onTap: _toggleMute,
        ),

        // Speaker (voice) / Camera (video)
        if (isVideo)
          _buildControlButton(
            icon: _isCameraOn ? Icons.videocam : Icons.videocam_off,
            label: _isCameraOn ? 'Camera' : 'Off',
            isActive: !_isCameraOn,
            onTap: _toggleCamera,
          )
        else
          _buildControlButton(
            icon: Icons.volume_up,
            label: 'Speaker',
            isActive: _isSpeakerOn,
            onTap: _toggleSpeaker,
          ),

        // Switch camera (video only)
        if (isVideo)
          _buildControlButton(
            icon: Icons.flip_camera_ios,
            label: 'Flip',
            isActive: false,
            onTap: () => _webrtcService.switchCamera(),
          ),

        // End call
        GestureDetector(
          onTap: _endCall,
          child: Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: KoraColors.red,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.call_end,
              color: Colors.white,
              size: 30,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.white.withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

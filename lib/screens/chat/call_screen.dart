import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../theme/kora_colors.dart';
import '../../services/webrtc_call_service.dart';
import '../../services/call_service.dart';
import '../../services/live_translation_service.dart';
import '../../models/chat_models.dart';
import '../../models/call_log.dart';
import 'call_translation_sheet.dart';

/// WhatsApp-style call screen for Kora Messenger.
///
/// Voice call: full-screen gradient with large avatar, name, status,
///   and a floating pill control bar at the bottom.
/// Video call: full-screen remote video, draggable local PiP,
///   semi-transparent top info bar, floating pill controls.
///
/// The control bar is a horizontal pill (not a 2x2 grid) matching
/// WhatsApp's current design: [Mute] [Speaker] [Video] [End] [More]
/// Each button is 48dp circular inside a rounded pill container.
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
  final _liveTranslation = LiveTranslationService.instance;

  String _callState = 'connecting';
  int _callDuration = 0;
  Timer? _timer;
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  bool _isCameraOn = true;
  DateTime? _callStartTime;
  RTCVideoRenderer? _remoteRenderer;
  RTCVideoRenderer? _localRenderer;

  // Translation state
  bool _translationActive = false;
  String _lastRecognized = '';
  String _lastReceived = '';

  // Draggable PiP position
  Offset _pipOffset = Offset.zero;
  bool _pipInitialized = false;

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

    _webrtcService.onTranslationTextReceived = (text) {
      _liveTranslation.onTranslatedTextReceived(text);
    };

    try {
      await _webrtcService.startCall(
        callerId: 'me',
        calleeId: widget.contactName,
        video: widget.isVideoCall,
      );
      await _webrtcService.setSpeakerOn(_isSpeakerOn);

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
      if (!mounted) return;
      _remoteRenderer?.srcObject = stream;
      setState(() {});
    });
  }

  void _setupLocalRenderer(MediaStream stream) {
    _localRenderer = RTCVideoRenderer();
    _localRenderer!.initialize().then((_) {
      if (!mounted) return;
      _localRenderer?.srcObject = stream;
      setState(() {});
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
      case 'connecting': return widget.isOutgoing ? 'Calling…' : 'Incoming call';
      case 'ringing': return 'Ringing…';
      case 'connected': return _durationString;
      case 'disconnected': return 'Reconnecting…';
      case 'failed': return 'Call failed';
      case 'rejected': return 'Call rejected';
      case 'ended': return 'Call ended';
      default: return _callState;
    }
  }

  void _toggleMute() {
    _webrtcService.toggleMute();
    setState(() => _isMuted = !_isMuted);
  }

  void _toggleSpeaker() async {
    final newState = !_isSpeakerOn;
    await _webrtcService.setSpeakerOn(newState);
    setState(() => _isSpeakerOn = newState);
  }

  void _toggleCamera() {
    _webrtcService.toggleCamera();
    setState(() => _isCameraOn = !_isCameraOn);
  }

  void _upgradeToVideoCall() async {
    try {
      await _webrtcService.enableVideo();
      _localRenderer = RTCVideoRenderer();
      await _localRenderer!.initialize();
      _localRenderer!.srcObject = _webrtcService.localStream;
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => CallScreen(
              contactName: widget.contactName,
              avatarUrl: widget.avatarUrl,
              badge: widget.badge,
              isVideoCall: true,
              isOutgoing: false,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Failed to upgrade to video: $e');
    }
  }

  /// WhatsApp's "More" popup — bottom sheet with options.
  void _showMorePopup() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: KoraColors.deepNavy,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10),
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              _moreItem(
                icon: Icons.translate_rounded,
                label: 'Live Translation',
                isActive: _translationActive,
                onTap: () { Navigator.pop(ctx); _openTranslationSheet(); },
              ),
              _moreItem(
                icon: Icons.flip_camera_ios,
                label: 'Flip Camera',
                onTap: () { Navigator.pop(ctx); _webrtcService.switchCamera(); },
              ),
              _moreItem(
                icon: Icons.person_add_outlined,
                label: 'Add Person',
                onTap: () => Navigator.pop(ctx),
              ),
              _moreItem(
                icon: Icons.volume_up_outlined,
                label: 'Audio & Video',
                onTap: () => Navigator.pop(ctx),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _moreItem({
    required IconData icon, required String label,
    bool isActive = false, required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: isActive
              ? KoraColors.purple.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon,
            color: isActive ? KoraColors.purple : Colors.white.withValues(alpha: 0.9),
            size: 20),
      ),
      title: Text(label, style: TextStyle(
        color: Colors.white.withValues(alpha: 0.9),
        fontSize: 15, fontWeight: FontWeight.w500,
      )),
      trailing: isActive
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                gradient: KoraColors.brandGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('ON',
                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
            )
          : Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.4)),
      onTap: onTap,
    );
  }

  void _openTranslationSheet() async {
    if (_translationActive) {
      await _liveTranslation.stop();
      setState(() => _translationActive = false);
      return;
    }

    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CallTranslationSheet(isInCall: _callState == 'connected'),
    );

    if (result != null && mounted) {
      final sourceLang = result['sourceLanguage'] as String;
      final targetLang = result['targetLanguage'] as String;

      _liveTranslation.onSpeechRecognized = (text) {
        if (mounted) setState(() => _lastRecognized = text);
      };
      _liveTranslation.onTranslationReceived = (text) {
        if (mounted) setState(() => _lastReceived = text);
      };
      _liveTranslation.onSendTranslatedText = (translatedText) {
        _webrtcService.sendTranslationText(translatedText);
      };
      _liveTranslation.onError = (error) {
        debugPrint('Translation error: $error');
      };

      await _liveTranslation.start(sourceLanguage: sourceLang, targetLanguage: targetLang);
      setState(() => _translationActive = true);
    }
  }

  void _endCall() async {
    _timer?.cancel();
    if (_translationActive) await _liveTranslation.stop();

    final duration = _callStartTime != null
        ? DateTime.now().difference(_callStartTime!).inSeconds
        : null;

    await _webrtcService.endCall();

    if (mounted) setState(() => _callState = 'ended');

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
    if (_translationActive) _liveTranslation.stop();
    _remoteRenderer?.dispose();
    _localRenderer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KoraColors.deepNavy,
      body: SafeArea(
        child: widget.isVideoCall && _remoteRenderer != null
            ? _buildVideoCallView()
            : _buildVoiceCallView(),
      ),
    );
  }

  // ── Voice Call View ──
  // WhatsApp: full-screen gradient, large centered avatar with pulse,
  // contact name, status/timer, floating pill control bar at bottom.
  Widget _buildVoiceCallView() {
    return Container(
      decoration: const BoxDecoration(gradient: KoraColors.brandGradient),
      child: Stack(
        children: [
          Column(
            children: [
              const Spacer(flex: 3),

              // Avatar with subtle pulse ring
              _buildPulsingAvatar(),

              const SizedBox(height: 24),

              // Name
              Text(widget.contactName,
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w600)),

              const SizedBox(height: 8),

              // Status + translation indicator
              _buildStatusRow(),

              // Translation subtitle
              if (_translationActive && (_lastRecognized.isNotEmpty || _lastReceived.isNotEmpty))
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 4),
                  child: Text(
                    _lastReceived.isNotEmpty ? '🔊 $_lastReceived' : '🗣️ $_lastRecognized',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ),

              const Spacer(flex: 4),
            ],
          ),

          // Floating pill control bar at bottom
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: _buildControlPill(false),
          ),
        ],
      ),
    );
  }

  // ── Video Call View ──
  // WhatsApp: full-screen remote video, draggable local PiP,
  // semi-transparent top info bar, floating pill controls.
  Widget _buildVideoCallView() {
    return Stack(
      children: [
        // Remote video (full screen)
        Positioned.fill(
          child: RTCVideoView(_remoteRenderer!,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            mirror: false),
        ),

        // Dark gradient at top
        Positioned(
          top: 0, left: 0, right: 0,
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.black.withValues(alpha: 0.6), Colors.transparent],
              ),
            ),
          ),
        ),

        // Top info bar
        Positioned(
          top: 16, left: 0, right: 0,
          child: Column(children: [
            Text(widget.contactName,
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            _buildStatusRow(),
          ]),
        ),

        // Draggable local PiP (WhatsApp: 90x160dp, top-right default, draggable)
        if (_localRenderer != null && _isCameraOn)
          Positioned(
            left: _pipInitialized ? _pipOffset.dx : null,
            top: _pipInitialized ? _pipOffset.dy : 80,
            right: _pipInitialized ? null : 16,
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  _pipInitialized = true;
                  _pipOffset += details.delta;
                  // Clamp within screen bounds
                  final size = MediaQuery.of(context).size;
                  _pipOffset = Offset(
                    _pipOffset.dx.clamp(8.0, size.width - 128),
                    _pipOffset.dy.clamp(8.0, size.height - 200),
                  );
                });
              },
              child: Container(
                width: 90, height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                ),
                clipBehavior: Clip.antiAlias,
                child: RTCVideoView(_localRenderer!,
                  mirror: true,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
              ),
            ),
          ),

        // Floating pill controls at bottom
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: _buildControlPill(true),
        ),
      ],
    );
  }

  // ── Pulsing Avatar (voice call) ──
  Widget _buildPulsingAvatar() {
    return Container(
      width: 120, height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 3),
      ),
      child: CircleAvatar(
        backgroundColor: Colors.white.withValues(alpha: 0.15),
        backgroundImage: widget.avatarUrl != null ? NetworkImage(widget.avatarUrl!) : null,
        child: widget.avatarUrl == null
            ? Text(
                widget.contactName.isNotEmpty ? widget.contactName[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w600))
            : null,
      ),
    );
  }

  // ── Status Row ──
  Widget _buildStatusRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_translationActive) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.translate_rounded, color: Colors.white, size: 12),
              const SizedBox(width: 4),
              Text('Translation ON',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 11, fontWeight: FontWeight.w600)),
            ]),
          ),
          const SizedBox(width: 8),
        ],
        Text(_statusText,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 16)),
      ],
    );
  }

  // ── Floating Pill Control Bar ──
  // WhatsApp's current design: a horizontal pill with circular buttons.
  // [Mute] [Speaker/Camera] [Video/Flip] [End] [More]
  // Each button: 48dp circular, semi-transparent white background.
  // End call: 56dp, red.
  Widget _buildControlPill(bool isVideo) {
    return Container(
      padding: const EdgeInsets.only(bottom: 48, top: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter, end: Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.7),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pill bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mute
                  _pillButton(
                    icon: _isMuted ? Icons.mic_off : Icons.mic,
                    label: _isMuted ? 'Unmute' : 'Mute',
                    isActive: _isMuted,
                    onTap: _toggleMute,
                  ),
                  // Speaker (voice) or Camera (video)
                  _pillButton(
                    icon: isVideo
                        ? (_isCameraOn ? Icons.videocam : Icons.videocam_off)
                        : Icons.volume_up,
                    label: isVideo ? 'Camera' : 'Speaker',
                    isActive: isVideo ? !_isCameraOn : _isSpeakerOn,
                    onTap: isVideo ? _toggleCamera : _toggleSpeaker,
                  ),
                  // Video (voice) or Flip (video)
                  _pillButton(
                    icon: isVideo ? Icons.flip_camera_ios : Icons.videocam_outlined,
                    label: isVideo ? 'Flip' : 'Video',
                    isActive: false,
                    onTap: isVideo ? () => _webrtcService.switchCamera() : _upgradeToVideoCall,
                  ),
                  // End call (red, larger)
                  _endCallButton(),
                  // More
                  _pillButton(
                    icon: Icons.more_horiz,
                    label: 'More',
                    isActive: _translationActive,
                    onTap: _showMorePopup,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pillButton({
    required IconData icon, required String label,
    required bool isActive, required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.white.withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 6),
          Text(label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 10)),
        ],
      ),
    );
  }

  Widget _endCallButton() {
    return GestureDetector(
      onTap: _endCall,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56, height: 56,
            decoration: const BoxDecoration(
              color: KoraColors.red, shape: BoxShape.circle),
            child: const Icon(Icons.call_end, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 6),
          Text('End', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 10)),
        ],
      ),
    );
  }
}

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

/// WhatsApp-style call screen for Kora Messenger (2025 redesign).
///
/// Matches WhatsApp's latest calling UI:
/// - Top-left: Minimize button (not back) — call continues in background
/// - Top-right: 3-dot overflow menu (Add person, Audio & Video, etc.)
/// - Center: Large profile picture (voice) or full-screen video (video)
/// - Floating island bottom bar with circular outlined buttons
/// - Two-row layout: Row 1 = controls, Row 2 = End call (red)
/// - Each button has its own circular outline with label
/// - Translation feature accessed via overflow menu
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

class _CallScreenState extends State<CallScreen>
    with SingleTickerProviderStateMixin {
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

  // UI state
  bool _controlsVisible = true;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
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
      setState(() => _isCameraOn = true);
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

  void _minimizeCall() {
    Navigator.pop(context);
  }

  void _showOverflowMenu() {
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
              _overflowItem(
                icon: Icons.translate_rounded,
                label: 'Translation',
                isActive: _translationActive,
                onTap: () {
                  Navigator.pop(ctx);
                  _openTranslationSheet();
                },
              ),
              _overflowItem(
                icon: Icons.flip_camera_ios,
                label: 'Flip Camera',
                onTap: () {
                  Navigator.pop(ctx);
                  _webrtcService.switchCamera();
                },
              ),
              _overflowItem(
                icon: Icons.person_add_outlined,
                label: 'Add Person',
                onTap: () => Navigator.pop(ctx),
              ),
              _overflowItem(
                icon: Icons.volume_up_outlined,
                label: 'Audio & Video',
                onTap: () => Navigator.pop(ctx),
              ),
              _overflowItem(
                icon: Icons.wallpaper_outlined,
                label: 'Wallpaper',
                onTap: () => Navigator.pop(ctx),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _overflowItem({
    required IconData icon,
    required String label,
    bool isActive = false,
    required VoidCallback onTap,
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
      title: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.9),
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
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

      _liveTranslation.onRecognizedText = (recognizedText) {
        if (mounted) setState(() => _lastRecognized = recognizedText);
      };

      _liveTranslation.onTranslatedText = (translatedText) {
        if (mounted) setState(() => _lastReceived = translatedText);
        _webrtcService.sendTranslationText(translatedText);
      };

      _liveTranslation.onError = (error) {
        debugPrint('Translation error: $error');
      };

      await _liveTranslation.start(
        sourceLanguage: sourceLang,
        targetLanguage: targetLang,
      );

      setState(() => _translationActive = true);
    }
  }

  void _endCall() async {
    _timer?.cancel();
    if (_translationActive) {
      await _liveTranslation.stop();
    }

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
    _pulseController.dispose();
    if (_translationActive) {
      _liveTranslation.stop();
    }
    _remoteRenderer?.dispose();
    _localRenderer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KoraColors.deepNavy,
      body: widget.isVideoCall && _remoteRenderer != null
          ? _buildVideoCallView()
          : _buildVoiceCallView(),
    );
  }

  // ── Voice call view ──────────────────────────────────────────

  Widget _buildVoiceCallView() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0A0A14), Color(0xFF13131F), Color(0xFF0A0A14)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──
            _buildTopBar(),
            // ── Center: Avatar + info ──
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Pulsing avatar ring
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Container(
                        width: 140 * _pulseAnimation.value,
                        height: 140 * _pulseAnimation.value,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [KoraColors.purple, KoraColors.blue],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: KoraColors.purple.withValues(alpha: 0.3),
                              blurRadius: 40,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: CircleAvatar(
                            backgroundColor: Colors.white.withValues(alpha: 0.1),
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
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  // Name
                  Text(
                    widget.contactName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Status + translation indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_translationActive) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: KoraColors.purple.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.translate_rounded, color: Colors.white, size: 12),
                              const SizedBox(width: 4),
                              Text('Translation ON',
                                  style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.9),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        _statusText,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  // Translation subtitle
                  if (_translationActive && (_lastRecognized.isNotEmpty || _lastReceived.isNotEmpty))
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _lastReceived.isNotEmpty ? '🔊 $_lastReceived' : '🗣️ $_lastRecognized',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            // ── Floating island bottom bar ──
            _buildFloatingIslandBar(false),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  // ── Video call view ──────────────────────────────────────────

  Widget _buildVideoCallView() {
    return Stack(
      children: [
        // Remote video full screen
        Positioned.fill(
          child: GestureDetector(
            onTap: () => setState(() => _controlsVisible = !_controlsVisible),
            child: RTCVideoView(
              _remoteRenderer!,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              mirror: false,
            ),
          ),
        ),
        // Dark gradient at top
        if (_controlsVisible)
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withValues(alpha: 0.6), Colors.transparent],
                ),
              ),
            ),
          ),
        // Top bar
        if (_controlsVisible)
          Positioned(
            top: 0, left: 0, right: 0,
            child: _buildTopBar(transparent: true),
          ),
        // Local video PiP (WhatsApp-style: top-right)
        if (_localRenderer != null && _isCameraOn)
          Positioned(
            top: 80, right: 16,
            child: Container(
              width: 120, height: 180,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: RTCVideoView(
                _localRenderer!,
                mirror: true,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            ),
          ),
        // Dark gradient at bottom
        if (_controlsVisible)
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
                ),
              ),
            ),
          ),
        // Floating island bar
        if (_controlsVisible)
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 28),
              child: _buildFloatingIslandBar(true),
            ),
          ),
      ],
    );
  }

  // ── Top bar (Minimize + 3-dot menu) ──────────────────────────

  Widget _buildTopBar({bool transparent = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          // Minimize button (WhatsApp replaces Back with Minimize)
          _topBarButton(
            icon: Icons.keyboard_arrow_down_rounded,
            onTap: _minimizeCall,
          ),
          const Spacer(),
          // Add person
          _topBarButton(
            icon: Icons.person_add_outlined,
            onTap: () {},
          ),
          const SizedBox(width: 4),
          // 3-dot overflow menu
          _topBarButton(
            icon: Icons.more_vert,
            onTap: _showOverflowMenu,
          ),
        ],
      ),
    );
  }

  Widget _topBarButton({required IconData icon, required VoidCallback onTap}) {
    return IconButton(
      icon: Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 24),
      onPressed: onTap,
    );
  }

  // ── Floating island bottom bar ───────────────────────────────

  /// WhatsApp's latest design: a floating pill-shaped bar containing
  /// circular outlined buttons in a row. The End Call button sits
  /// separately below the island.
  Widget _buildFloatingIslandBar(bool isVideo) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Floating island with control buttons
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Mute
              _islandButton(
                icon: _isMuted ? Icons.mic_off : Icons.mic,
                label: _isMuted ? 'Unmute' : 'Mute',
                isActive: _isMuted,
                onTap: _toggleMute,
              ),
              // Speaker
              _islandButton(
                icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                label: 'Speaker',
                isActive: _isSpeakerOn,
                onTap: _toggleSpeaker,
              ),
              // Video (voice call: upgrade; video call: toggle camera)
              if (!isVideo)
                _islandButton(
                  icon: Icons.videocam_outlined,
                  label: 'Video',
                  isActive: false,
                  onTap: _upgradeToVideoCall,
                )
              else
                _islandButton(
                  icon: _isCameraOn ? Icons.videocam : Icons.videocam_off,
                  label: 'Camera',
                  isActive: _isCameraOn,
                  onTap: _toggleCamera,
                ),
              // Flip camera (video only)
              if (isVideo)
                _islandButton(
                  icon: Icons.flip_camera_ios,
                  label: 'Flip',
                  isActive: false,
                  onTap: () => _webrtcService.switchCamera(),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // End call button — separate, red, centered
        GestureDetector(
          onTap: _endCall,
          child: Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Icons.call_end, color: Colors.white, size: 28),
          ),
        ),
      ],
    );
  }

  /// Circular outlined button inside the floating island.
  Widget _islandButton({
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
            width: 54, height: 54,
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.white.withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: isActive ? 0.4 : 0.15),
                width: 1.5,
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

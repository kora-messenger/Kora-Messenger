import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../theme/kora_colors.dart';
import '../../models/call_log.dart';
import '../../services/webrtc_call_service.dart';
import '../../services/call_service.dart';
import '../../services/call_stt_service.dart';
import '../../models/chat_models.dart';
import '../../services/translation_service.dart';
import 'call_translation_sheet.dart';

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
  // Call translation feature — behaves as an overlay/bottom sheet over
  // this call screen. Opening/closing it never touches WebRTC state,
  // navigator stack position, or any of the call controls above —
  // the CallScreen route stays mounted underneath the modal sheet route
  // the whole time, so the call itself is never affected.
  bool _translationOn = false;
  bool _captionsOn = true;
  bool _translationSheetOpen = false;
  DateTime? _callStartTime;

  // Call translation: STT + data channel caption streams
  final _sttService = CallSttService.instance;
  StreamController<(String, bool)>? _remoteCaptionStream;
  StreamController<(String, bool)>? _localCaptionStream;
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

  /// Toggles the in-call translation feature.
  ///
  /// This ONLY opens/closes a [showModalBottomSheet] overlay on top of
  /// the current call route — it never navigates away from, pops, or
  /// rebuilds this [CallScreen]. The call (WebRTC connection, mute state,
  /// camera state, speaker routing, timer) is completely untouched by
  /// opening or closing the translation sheet.
  void _toggleTranslation() {
    setState(() => _translationOn = !_translationOn);
    if (_translationOn) {
      _startCallTranslation();
      _translationSheetOpen = true;
      CallTranslationSheet.show(context, isInCall: true).then((_) {
        _translationSheetOpen = false;
      });
    } else {
      _stopCallTranslation();
    }
  }

  /// Starts real-time call translation:
  /// 1. Set up stream controllers for caption overlays
  /// 2. Wire the WebRTC data channel to receive remote captions
  /// 3. Start on-device STT to transcribe local speech
  /// 4. Send local transcripts via the data channel to the remote peer
  void _startCallTranslation() {
    // Create caption stream controllers
    _remoteCaptionStream = StreamController<(String, bool)>.broadcast();
    _localCaptionStream = StreamController<(String, bool)>.broadcast();

    // Wire incoming remote captions from the data channel
    _webrtcService.onRemoteCaption = (text, isFinal) {
      _remoteCaptionStream?.add((text, isFinal));
    };

    // Configure STT locale based on the user's preferred language
    final langCode = TranslationService.instance.preferredLanguageCode;
    _sttService.setLocale(_localeFromCode(langCode));

    // Wire local STT transcripts:
    // a) Feed to local caption stream (user sees their own speech)
    // b) Send to remote peer via the data channel
    _sttService.onTranscript = (text, isFinal) {
      _localCaptionStream?.add((text, isFinal));
      _webrtcService.sendCaption(text, isFinal);
    };

    _sttService.onError = (error) {
      debugPrint('[CallTranslation] STT error: $error');
    };

    // Start listening — this runs in parallel with the WebRTC
    // audio stream and does not interfere with the call audio.
    _sttService.start();
  }

  /// Stops call translation: cancels STT, closes stream controllers,
  /// and disconnects the data channel callback.
  void _stopCallTranslation() {
    _sttService.stop();
    _sttService.onTranscript = null;
    _sttService.onError = null;
    _webrtcService.onRemoteCaption = null;
    _remoteCaptionStream?.close();
    _remoteCaptionStream = null;
    _localCaptionStream?.close();
    _localCaptionStream = null;
  }

  /// Maps a Kora translation language code to a speech_to_text locale ID.
  /// Falls back to en-US if no exact match is found.
  String _localeFromCode(String code) {
    final mapping = <String, String>{
      'en': 'en-US',
      'es': 'es-ES',
      'fr': 'fr-FR',
      'de': 'de-DE',
      'it': 'it-IT',
      'pt': 'pt-PT',
      'pt-BR': 'pt-BR',
      'ru': 'ru-RU',
      'pl': 'pl-PL',
      'tr': 'tr-TR',
      'ar': 'ar-SA',
      'hi': 'hi-IN',
      'ja': 'ja-JP',
      'ko': 'ko-KR',
      'zh': 'zh-CN',
      'zh-TW': 'zh-TW',
      'nl': 'nl-NL',
      'sv': 'sv-SE',
      'da': 'da-DK',
      'fi': 'fi-FI',
      'no': 'nb-NO',
      'el': 'el-GR',
      'cs': 'cs-CZ',
      'uk': 'uk-UA',
      'th': 'th-TH',
      'vi': 'vi-VN',
      'id': 'id-ID',
      'ms': 'ms-MY',
      'sw': 'sw-KE',
      'he': 'he-IL',
      'ro': 'ro-RO',
      'hu': 'hu-HU',
    };
    return mapping[code] ?? 'en-US';
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

    // Stop call translation (STT + data channel) before ending
    _stopCallTranslation();

    if (mounted) {
      if (_translationSheetOpen && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _stopCallTranslation();
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
        // The base call view (voice or video) is always the bottom layer
        // of this Stack and is NEVER rebuilt, replaced, or unmounted when
        // translation opens/closes — only the overlay on top changes.
        // StackFit.expand keeps it filling the screen exactly like before
        // (needed for the Spacer widgets inside _buildVoiceCallView).
        child: Stack(
          fit: StackFit.expand,
          children: [
            widget.isVideoCall && _remoteRenderer != null
                ? _buildVideoCallView()
                : _buildVoiceCallView(),
            if (_translationOn) _buildTranslationOverlay(),
          ],
        ),
      ),
    );
  }

  /// Floating translation indicator + live captions, rendered above the
  /// call view but below the control row. Purely additive — sits on top
  /// of the existing call UI as an overlay, never replacing it.
  Widget _buildTranslationOverlay() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: widget.isVideoCall ? 150 : 170,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Kora Translate indicator pill
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: KoraColors.purple.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: KoraColors.purple.withValues(alpha: 0.4),
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.language_rounded, size: 14, color: KoraColors.purple),
                  const SizedBox(width: 6),
                  const Text(
                    'Kora Translate • ON',
                    style: TextStyle(
                      color: KoraColors.purple,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() => _captionsOn = !_captionsOn),
                    child: Icon(
                      _captionsOn ? Icons.closed_caption_rounded : Icons.closed_caption_outlined,
                      size: 16,
                      color: KoraColors.purple.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_captionsOn) ...[
            const SizedBox(height: 8),
            LiveCaptionsOverlay(
              speakerName: widget.contactName,
              fontSize: TranslationService.instance.captionSize,
              captionStream: _remoteCaptionStream?.stream,
              localCaptionStream: _localCaptionStream?.stream,
            ),
          ],
        ],
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

        // Translate — opens/closes a bottom-sheet overlay above this
        // same call screen. Never navigates away, never ends the call.
        _buildControlButton(
          icon: Icons.translate_rounded,
          label: 'Translate',
          isActive: _translationOn,
          onTap: _toggleTranslation,
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

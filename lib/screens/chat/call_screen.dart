import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/kora_colors.dart';
import '../../services/webrtc_call_service.dart';
import '../../services/call_service.dart';
import '../../services/live_translation_service.dart';
import '../../models/chat_models.dart';
import '../../models/call_log.dart';
import 'call_translation_sheet.dart';
import 'group_call_participants.dart';
import 'call_wallpaper_picker.dart';
import 'call_effects_sheet.dart';
import 'call_link_screen.dart';
import '../../widgets/kora_badge.dart';
import '../../widgets/kora_avatar.dart';

/// WhatsApp-style call screen for Kora Messenger (2026 redesign).
///
/// Supports:
/// 1. Group Calls (up to 32 participants) with video tile grid, active speaker purple border,
///    speaker view toggle, participant count badge, send messages during call, call links.
/// 2. Call Wallpaper (Preset gradients & custom gallery photo saved in SharedPreferences).
/// 3. Call Effects & Filters (10 color filters, virtual backgrounds, face AR effects, SharedPreferences).
class CallScreen extends StatefulWidget {
  final String contactName;
  final String? avatarUrl;
  final KoraBadgeType? badge;
  final bool isVideoCall;
  final bool isOutgoing;
  final List<CallParticipant>? initialParticipants;

  const CallScreen({
    super.key,
    required this.contactName,
    this.avatarUrl,
    this.badge,
    this.isVideoCall = false,
    this.isOutgoing = true,
    this.initialParticipants,
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
  bool _isScreenSharing = false;
  DateTime? _callStartTime;

  /// True once _endCall() has run for this call — makes it idempotent

  /// against double-taps and the service's 'ended' callback racing the

  /// user tapping the end button (the re-entrant pair that used to

  /// recurse until stack overflow).

  bool _endCallHandled = false;
  RTCVideoRenderer? _remoteRenderer;
  RTCVideoRenderer? _localRenderer;

  // Translation state
  bool _translationActive = false;
  String _lastRecognized = '';
  String _lastReceived = '';

  // Call settings
  bool _noiseSuppression = false;
  bool _lowDataMode = false;

  // UI state
  bool _controlsVisible = true;
  Timer? _autoHideTimer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Draggable self-view PiP state (1-on-1 video call)
  Offset _pipPosition = Offset.zero;
  Offset _pipDragOffset = Offset.zero;
  bool _pipExpanded = false;
  bool _pipHidden = false;
  Size? _screenSize;
  static const double _pipSmallW = 110;
  static const double _pipSmallH = 160;
  static const double _pipLargeW = 180;
  static const double _pipLargeH = 260;

  // Feature 1: Group Calls State
  late List<CallParticipant> _participants;
  String _activeSpeakerId = 'me';
  bool _isSpeakerView = false;
  Timer? _speakerCycleTimer;

  // Feature 2: Call Wallpaper State
  CallWallpaper _activeWallpaper = CallWallpaperPresets.koraPurple;

  // Feature 3: Effects & Filters State
  String _activeFilterId = 'none';
  String _activeBgId = 'none';
  String _activeEffectId = 'none';

  @override
  void initState() {
    super.initState();

    // Initialize group call participants
    if (widget.initialParticipants != null && widget.initialParticipants!.isNotEmpty) {
      _participants = List.from(widget.initialParticipants!);
    } else {
      _participants = [
        CallParticipant(
          id: 'me',
          name: 'You',
          isHost: true,
          isSelf: true,
          isVideoOn: widget.isVideoCall,
        ),
        CallParticipant(
          id: widget.contactName,
          name: widget.contactName,
          avatarUrl: widget.avatarUrl,
          isHost: false,
          isSelf: false,
          isVideoOn: widget.isVideoCall,
        ),
      ];
    }

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startCall();
    _loadSavedWallpaper();
    _loadSavedEffects();
    _startSpeakerSimulation();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final size = MediaQuery.of(context).size;
      _screenSize = size;
      _pipPosition = Offset(
        size.width - _pipSmallW - 16,
        MediaQuery.of(context).padding.top + 190,
      );
      setState(() {});
    });
    _resetAutoHideTimer();
  }

  Future<void> _loadSavedWallpaper() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString('call_wallpaper_preset_id') ?? 'kora_purple';
    final customPath = prefs.getString('call_wallpaper_custom_path');
    if (mounted) {
      setState(() {
        _activeWallpaper = CallWallpaperPresets.getById(savedId, customPath: customPath);
      });
    }
  }

  Future<void> _loadSavedEffects() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _activeFilterId = prefs.getString(CallEffectsData.keyFilter) ?? 'none';
        _activeBgId = prefs.getString(CallEffectsData.keyBackground) ?? 'none';
        _activeEffectId = prefs.getString(CallEffectsData.keyEffect) ?? 'none';
      });
    }
  }

  void _startSpeakerSimulation() {
    // Periodically shift active speaker if multiple participants exist
    _speakerCycleTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (mounted && _participants.length > 2 && _callState == 'connected') {
        final nonSelf = _participants.where((p) => !p.isSelf).toList();
        if (nonSelf.isNotEmpty) {
          final nextIndex = (nonSelf.indexWhere((p) => p.id == _activeSpeakerId) + 1) % nonSelf.length;
          setState(() {
            _activeSpeakerId = nonSelf[nextIndex].id;
            for (var p in _participants) {
              p.isSpeaking = (p.id == _activeSpeakerId);
            }
          });
        }
      }
    });
  }

  void _resetAutoHideTimer() {
    if (!widget.isVideoCall) return;
    _autoHideTimer?.cancel();
    _autoHideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _callState == 'connected') {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) {
      _resetAutoHideTimer();
    }
  }

  void _startCall() async {
    _webrtcService.onCallStateChanged = (state) {
      if (mounted) {
        setState(() => _callState = state);
        if (state == 'connected') {
          _callStartTime = DateTime.now();
          _startTimer();
          _resetAutoHideTimer();
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

  /// True while the call hasn't been answered yet — the ringing phase.
  bool get _isPreConnect =>
      _callState == 'connecting' || _callState == 'ringing';

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
        return 'Declined';
      case 'ended':
        return 'Call ended';
      default:
        return _callState;
    }
  }

  void _toggleMute() {
    _webrtcService.toggleMute();
    setState(() {
      _isMuted = !_isMuted;
      final me = _participants.firstWhere((p) => p.isSelf, orElse: () => _participants.first);
      me.isMuted = _isMuted;
    });
    _resetAutoHideTimer();
  }

  void _toggleSpeaker() async {
    final newState = !_isSpeakerOn;
    await _webrtcService.setSpeakerOn(newState);
    setState(() => _isSpeakerOn = newState);
    _resetAutoHideTimer();
  }

  void _toggleCamera() {
    _webrtcService.toggleCamera();
    setState(() {
      _isCameraOn = !_isCameraOn;
      final me = _participants.firstWhere((p) => p.isSelf, orElse: () => _participants.first);
      me.isVideoOn = _isCameraOn;
    });
    _resetAutoHideTimer();
  }

  void _toggleScreenShare() async {
    if (_isScreenSharing) {
      await _webrtcService.stopScreenShare();
    } else {
      await _webrtcService.startScreenShare();
    }
    setState(() => _isScreenSharing = !_isScreenSharing);
    _resetAutoHideTimer();
  }

  /// Confirms with the user before switching an ongoing voice call to
  /// video — matches the reference recording: a white rounded dialog
  /// with "Switch to video call?" and Cancel / Switch actions. Only
  /// calls [_upgradeToVideoCall] if the user taps Switch.
  void _confirmSwitchToVideo() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        title: const Text(
          'Switch to video call?',
          style: TextStyle(color: Color(0xFF1C1C1E), fontSize: 17, fontWeight: FontWeight.w600),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF8E8E93), fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _upgradeToVideoCall();
            },
            child: Text('Switch', style: TextStyle(color: KoraColors.purple, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
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
              initialParticipants: _participants,
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

  // ── Open Feature Sheets ──

  void _openParticipantsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GroupCallParticipantsSheet(
        participants: _participants,
        maxParticipants: 32,
        onAddParticipant: (newP) {
          setState(() {
            _participants.add(newP);
          });
        },
        onRemoveParticipant: (id) {
          setState(() {
            _participants.removeWhere((p) => p.id == id);
          });
        },
        onToggleMute: (id, isMuted) {
          setState(() {
            final p = _participants.firstWhere((item) => item.id == id);
            p.isMuted = isMuted;
          });
        },
        onToggleVideo: (id, isVideoOn) {
          setState(() {
            final p = _participants.firstWhere((item) => item.id == id);
            p.isVideoOn = isVideoOn;
          });
        },
      ),
    );
  }

  void _openAddPersonSheet() {
    _openParticipantsSheet();
  }

  void _openWallpaperPicker() async {
    final selected = await showModalBottomSheet<CallWallpaper>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CallWallpaperPicker(),
    );

    if (selected != null && mounted) {
      setState(() {
        _activeWallpaper = selected;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Wallpaper updated to ${selected.name}'),
          backgroundColor: KoraColors.purple,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _openEffectsSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CallEffectsSheet(),
    );

    // Refresh active effects from SharedPreferences
    await _loadSavedEffects();
  }

  void _openInCallChatSheet() {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        decoration: const BoxDecoration(
          color: KoraColors.deepNavy,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                const Row(
                  children: [
                    Icon(Icons.chat_bubble_outline, color: KoraColors.purple),
                    SizedBox(width: 8),
                    Text(
                      'In-Call Messages',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: KoraColors.darkCard,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const SingleChildScrollView(
                    child: Text(
                      '💬 Call created. Messages sent here are visible to all call participants.',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Type a message…',
                          hintStyle: const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: KoraColors.darkCard,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send_rounded, color: KoraColors.purple),
                      onPressed: () {
                        if (controller.text.trim().isNotEmpty) {
                          final text = controller.text.trim();
                          controller.clear();
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Message sent to call: $text'),
                              backgroundColor: KoraColors.purple,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openCallLinkScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CallLinkScreen()),
    );
  }

  // ── Overflow Menu ──

  void _showOverflowMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: KoraColors.deepNavy,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              _overflowItem(
                icon: Icons.person_add_outlined,
                label: 'Add people',
                onTap: () {
                  Navigator.pop(ctx);
                  _openAddPersonSheet();
                },
              ),
              _overflowItem(
                icon: Icons.wallpaper_outlined,
                label: 'Call Wallpaper',
                onTap: () {
                  Navigator.pop(ctx);
                  _openWallpaperPicker();
                },
              ),
              _overflowItem(
                icon: Icons.auto_awesome_outlined,
                label: 'Effects & Filters',
                onTap: () {
                  Navigator.pop(ctx);
                  _openEffectsSheet();
                },
              ),
              _overflowItem(
                icon: Icons.chat_outlined,
                label: 'Send Message in Call',
                onTap: () {
                  Navigator.pop(ctx);
                  _openInCallChatSheet();
                },
              ),
              _overflowItem(
                icon: Icons.link_rounded,
                label: 'Call link',
                onTap: () {
                  Navigator.pop(ctx);
                  _openCallLinkScreen();
                },
              ),
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
                icon: _noiseSuppression ? Icons.noise_control_off : Icons.graphic_eq_outlined,
                label: 'Noise cancellation',
                isActive: _noiseSuppression,
                onTap: () {
                  Navigator.pop(ctx);
                  _toggleNoiseSuppression();
                },
              ),
              _overflowItem(
                icon: Icons.data_saver_off_outlined,
                label: 'Low Data Mode',
                isActive: _lowDataMode,
                onTap: () {
                  Navigator.pop(ctx);
                  _toggleLowData();
                },
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
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isActive
              ? KoraColors.purple.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: isActive ? KoraColors.purple : Colors.white.withValues(alpha: 0.9),
          size: 20,
        ),
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
      // CallTranslationSheet pops a Dart record
      // ({sourceLanguage, targetLanguage}) — not a Map. Reading it with
      // result['sourceLanguage'] threw a NoSuchMethodError (crash
      // 2026-09-03 17:13). Accept both shapes defensively.
      final sourceLang = result is Map
          ? result['sourceLanguage'] as String
          : (result as dynamic).sourceLanguage as String;
      final targetLang = result is Map
          ? result['targetLanguage'] as String
          : (result as dynamic).targetLanguage as String;

      _liveTranslation.onSpeechRecognized = (recognizedText) {
        if (mounted) setState(() => _lastRecognized = recognizedText);
      };

      _liveTranslation.onSendTranslatedText = (translatedText) {
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

  void _toggleNoiseSuppression() async {
    setState(() => _noiseSuppression = !_noiseSuppression);
    await _webrtcService.setAudioProcessing(noiseSuppression: _noiseSuppression);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_noiseSuppression ? 'Noise cancellation turned on' : 'Noise cancellation turned off'),
          backgroundColor: KoraColors.purple,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _toggleLowData() {
    setState(() => _lowDataMode = !_lowDataMode);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_lowDataMode
            ? 'Low data mode on — video quality reduced'
            : 'Low data mode off — full quality'),
        backgroundColor: KoraColors.purple,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _endCall() async {
    // Idempotency guard — only run the teardown once per call.
    if (_endCallHandled) return;
    _endCallHandled = true;

    _timer?.cancel();
    _autoHideTimer?.cancel();
    _speakerCycleTimer?.cancel();
    if (_translationActive) {
      await _liveTranslation.stop();
    }

    final duration = _callStartTime != null
        ? DateTime.now().difference(_callStartTime!).inSeconds
        : null;

    await _webrtcService.endCall();

    if (mounted) setState(() => _callState = 'ended');

    // Log with the real direction — outgoing for placed calls,
    // incoming for received-and-answered calls (the reference app
    // logs all three: outgoing, incoming, missed).
    if (widget.isOutgoing) {
      await _callService.logOutgoingCall(
        contactName: widget.contactName,
        avatarUrl: widget.avatarUrl,
        badge: widget.badge,
        type: widget.isVideoCall ? CallType.video : CallType.voice,
        durationSeconds: duration,
      );
    } else {
      await _callService.logIncomingCall(
        contactName: widget.contactName,
        avatarUrl: widget.avatarUrl,
        badge: widget.badge,
        type: widget.isVideoCall ? CallType.video : CallType.voice,
        durationSeconds: duration,
      );
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _autoHideTimer?.cancel();
    _speakerCycleTimer?.cancel();
    _pulseController.dispose();
    if (_translationActive) {
      _liveTranslation.stop();
    }
    _remoteRenderer?.dispose();
    _localRenderer?.dispose();
    super.dispose();
  }

  // ── Video Filter Helper ──

  Widget _applyVideoFilter(Widget child) {
    final option = CallEffectsData.filters.firstWhere(
      (f) => f.id == _activeFilterId,
      orElse: () => CallEffectsData.filters.first,
    );
    if (option.colorFilter != null) {
      return ColorFiltered(colorFilter: option.colorFilter!, child: child);
    }
    return child;
  }

  @override
  Widget build(BuildContext context) {
    final isGroupCall = _participants.length > 2;

    return Scaffold(
      backgroundColor: KoraColors.deepNavy,
      body: widget.isVideoCall
          ? (isGroupCall
              ? _buildGroupVideoCallView()
              : (_isPreConnect ? _buildVideoRingingView() : _buildVideoCallView()))
          : (isGroupCall ? _buildGroupVoiceCallView() : _buildVoiceCallView()),
    );
  }

  // ── 1-on-1 Voice call view ──

  /// 1-on-1 voice call screen — matches the reference recording: shared
  /// top bar (minimize / name+badge+status / add-person), a large flat
  /// avatar centered in the remaining space (no pulse animation, no
  /// text underneath — the name+status already live in the top bar),
  /// and the labeled 2x3 control grid card at the bottom.
  Widget _buildVoiceCallView() {
    return Container(
      decoration: _activeWallpaper.decoration,
      child: SafeArea(
        child: Column(
          children: [
            _buildCallTopBar(),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    KoraAvatar(
                      name: widget.contactName,
                      imageUrl: widget.avatarUrl,
                      size: 168,
                    ),
                    if (_translationActive) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: KoraColors.purple.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.translate_rounded, color: Colors.white, size: 13),
                            const SizedBox(width: 5),
                            Text('Translation ON',
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      if (_lastRecognized.isNotEmpty || _lastReceived.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _lastReceived.isNotEmpty ? '🔊 $_lastReceived' : '🗣️ $_lastRecognized',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                left: 20, right: 20,
                bottom: MediaQuery.of(context).padding.bottom + 20,
              ),
              child: _buildVoiceControlGrid(),
            ),
          ],
        ),
      ),
    );
  }

  /// The rounded-rectangle 2x3 labeled control grid used by the voice
  /// call screen: Speaker / Video / Mute on top, More / Share / End
  /// below — matching the reference recording exactly.
  Widget _buildVoiceControlGrid() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _gridButton(
                icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                label: 'Speaker',
                isOn: _isSpeakerOn,
                onTap: _toggleSpeaker,
              ),
              _gridButton(
                icon: Icons.videocam,
                label: 'Video',
                isOn: false,
                onTap: _confirmSwitchToVideo,
              ),
              _gridButton(
                icon: _isMuted ? Icons.mic : Icons.mic_off,
                label: _isMuted ? 'Unmute' : 'Mute',
                isOn: _isMuted,
                onTap: _toggleMute,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _gridButton(
                icon: Icons.more_horiz,
                label: 'More',
                isOn: false,
                onTap: _showOverflowMenu,
              ),
              _gridButton(
                icon: _isScreenSharing ? Icons.stop_screen_share : Icons.ios_share,
                label: 'Share',
                isOn: _isScreenSharing,
                onTap: _toggleScreenShare,
              ),
              _gridButton(
                icon: Icons.call_end,
                label: 'End',
                isOn: false,
                isDestructive: true,
                onTap: _endCall,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// A single icon-over-label button inside the voice call control
  /// grid. Fills solid white with a dark glyph when the toggle it
  /// represents is active; otherwise a subtle translucent dark circle
  /// with a white glyph. The End button is always solid red.
  Widget _gridButton({
    required IconData icon,
    required String label,
    required bool isOn,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final Color circleColor = isDestructive
        ? const Color(0xFFEF4444)
        : (isOn ? Colors.white : Colors.white.withValues(alpha: 0.16));
    final Color iconColor = isDestructive
        ? Colors.white
        : (isOn ? const Color(0xFF1C1C1E) : Colors.white);

    return SizedBox(
      width: 78,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 56,
              height: 56,
              decoration: BoxDecoration(shape: BoxShape.circle, color: circleColor),
              child: Icon(icon, color: iconColor, size: 24),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── Group Voice Call View ──

  Widget _buildGroupVoiceCallView() {
    return Container(
      decoration: _activeWallpaper.decoration,
      child: SafeArea(
        child: Column(
          children: [
            _buildGroupTopBar(false),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _participants.length <= 4 ? 2 : 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: _participants.length,
                  itemBuilder: (context, index) {
                    final p = _participants[index];
                    final isSpeaker = p.id == _activeSpeakerId || p.isSpeaking;

                    return Container(
                      decoration: BoxDecoration(
                        color: KoraColors.darkCard.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSpeaker ? KoraColors.purple : Colors.white12,
                          width: isSpeaker ? 3 : 1,
                        ),
                        boxShadow: isSpeaker
                            ? [
                                BoxShadow(
                                  color: KoraColors.purple.withValues(alpha: 0.5),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundColor: KoraColors.purple.withValues(alpha: 0.3),
                                backgroundImage: p.avatarUrl != null && p.avatarUrl!.isNotEmpty
                                    ? (p.avatarUrl!.startsWith('data:')
                                        ? MemoryImage(base64Decode(p.avatarUrl!.substring(p.avatarUrl!.indexOf(',') + 1))) as ImageProvider
                                        : NetworkImage(p.avatarUrl!) as ImageProvider)
                                    : null,
                                child: p.avatarUrl == null || p.avatarUrl!.isEmpty
                                    ? Text(
                                        p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  p.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Icon(
                              p.isMuted ? Icons.mic_off : Icons.mic,
                              color: p.isMuted ? Colors.redAccent : Colors.white70,
                              size: 16,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            _buildFloatingIslandBar(false),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  // ── 1-on-1 Video call view ──

  // ── 1-on-1 Video call RINGING view (pre-connect) ──
  // Layout per reference video: full-screen self camera preview,
  // name + end-to-end lock badge top-left, vertical 4-button rail on the
  // right, and a full-width bottom pill with the red end-call inline.

  Widget _buildVideoRingingView() {
    final topPad = MediaQuery.of(context).padding.top;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Full-screen local camera preview while waiting for the answer.
        if (_localRenderer != null && _isCameraOn)
          Positioned.fill(
            child: _applyVideoFilter(
              RTCVideoView(
                _localRenderer!,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                mirror: true,
              ),
            ),
          )
        else
          Positioned.fill(
            child: Container(
              decoration: _activeWallpaper.decoration,
              child: Center(
                child: CircleAvatar(
                  radius: 64,
                  backgroundColor: KoraColors.purple.withValues(alpha: 0.3),
                  backgroundImage: widget.avatarUrl != null
                      ? (widget.avatarUrl!.startsWith('data:')
                          ? MemoryImage(base64Decode(
                              widget.avatarUrl!.substring(widget.avatarUrl!.indexOf(',') + 1))) as ImageProvider
                          : NetworkImage(widget.avatarUrl!) as ImageProvider)
                      : null,
                  child: widget.avatarUrl == null
                      ? Text(
                          widget.contactName.isNotEmpty
                              ? widget.contactName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 44,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ),

        // Subtle scrim so the chrome reads over bright previews
        Positioned.fill(
          child: Container(color: Colors.black.withValues(alpha: 0.18)),
        ),

        // Top gradient
        Positioned(
          top: 0, left: 0, right: 0,
          child: Container(
            height: 150,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withValues(alpha: 0.55), Colors.transparent],
              ),
            ),
          ),
        ),

        // Top-left info: name + end-to-end encrypted badge + status
        Positioned(
          top: topPad + 14,
          left: 16,
          right: 100,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KoraNameWithBadge(
                name: widget.contactName,
                badge: widget.badge ?? KoraBadgeType.none,
                badgeSize: 16,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_rounded,
                        color: Colors.white.withValues(alpha: 0.85), size: 12),
                    const SizedBox(width: 4),
                    Text(
                      'End-to-end encrypted',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
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

        // Right-side vertical rail: minimize, effects, flip camera, add person
        Positioned(
          top: topPad + 14,
          right: 18,
          child: Column(
            children: [
              _ringRailButton(Icons.keyboard_arrow_down_rounded, _minimizeCall),
              const SizedBox(height: 20),
              _ringRailButton(Icons.auto_awesome, _openEffectsSheet),
              const SizedBox(height: 20),
              _ringRailButton(
                  Icons.flip_camera_ios, () => _webrtcService.switchCamera()),
              const SizedBox(height: 20),
              _ringRailButton(Icons.person_add_outlined, _openAddPersonSheet),
            ],
          ),
        ),

        // Bottom gradient
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            height: 170,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black.withValues(alpha: 0.65), Colors.transparent],
              ),
            ),
          ),
        ),

        // Bottom pill: more, camera, speaker, mute + inline red end-call
        Positioned(
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).padding.bottom + 18,
          child: Container(
            height: 68,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(34),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _ringPillButton(Icons.more_vert, _showOverflowMenu),
                _ringPillButton(
                  _isCameraOn ? Icons.videocam : Icons.videocam_off,
                  _toggleCamera,
                ),
                _ringPillButton(
                  _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                  _toggleSpeaker,
                ),
                _ringPillButton(
                  _isMuted ? Icons.mic_off : Icons.mic,
                  _toggleMute,
                ),
                // Inline red end-call button at the right end of the pill
                GestureDetector(
                  onTap: _endCall,
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.call_end, color: Colors.white, size: 26),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Round translucent button for the ringing-screen right rail.
  Widget _ringRailButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Icon(icon, color: Colors.white.withValues(alpha: 0.92), size: 24),
      ),
    );
  }

  /// Connected-call control pill: more (plain), camera/speaker/mute
  /// toggles that fill solid white when actively "on" (matches the
  /// reference — camera streaming & speaker on show a white circle,
  /// muted mic shows a dark circle), and the red end-call inline at
  /// the right end of the pill.
  Widget _buildConnectedControlPill({required bool isVideo}) {
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _pillPlainButton(Icons.more_vert, _showOverflowMenu),
          if (isVideo)
            _pillToggleButton(
              icon: _isCameraOn ? Icons.videocam : Icons.videocam_off,
              isOn: _isCameraOn,
              onTap: _toggleCamera,
            )
          else
            _pillToggleButton(
              icon: Icons.videocam_outlined,
              isOn: false,
              onTap: _confirmSwitchToVideo,
            ),
          _pillToggleButton(
            icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
            isOn: _isSpeakerOn,
            onTap: _toggleSpeaker,
          ),
          _pillToggleButton(
            icon: _isMuted ? Icons.mic_off : Icons.mic,
            isOn: !_isMuted,
            onTap: _toggleMute,
          ),
          GestureDetector(
            onTap: _endCall,
            child: Container(
              width: 54,
              height: 54,
              decoration: const BoxDecoration(
                color: Color(0xFFEF4444),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.call_end, color: Colors.white, size: 26),
            ),
          ),
        ],
      ),
    );
  }

  /// Plain (non-toggle) icon button inside the connected-call pill.
  Widget _pillPlainButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 40,
        height: 52,
        child: Icon(icon, color: Colors.white.withValues(alpha: 0.92), size: 24),
      ),
    );
  }

  /// Toggle icon button inside the connected-call pill. "On" fills solid
  /// white with a dark glyph; "off" stays a subtle translucent dark
  /// circle with a white glyph.
  Widget _pillToggleButton({
    required IconData icon,
    required bool isOn,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isOn ? Colors.white : Colors.white.withValues(alpha: 0.16),
        ),
        child: Icon(
          icon,
          color: isOn ? const Color(0xFF1C1C1E) : Colors.white,
          size: 22,
        ),
      ),
    );
  }

  /// Plain icon button inside the ringing-screen bottom pill.
  Widget _ringPillButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 46,
        height: 52,
        child: Icon(icon, color: Colors.white.withValues(alpha: 0.92), size: 26),
      ),
    );
  }

  /// Whether the remote party in this 1-on-1 call currently has their
  /// camera on. When false, the reference recording shows their avatar
  /// centered on the wallpaper instead of a black/empty video surface.
  bool get _remoteHasVideo {
    final remote = _participants.firstWhere(
      (p) => !p.isSelf,
      orElse: () => _participants.first,
    );
    return _remoteRenderer != null && remote.isVideoOn;
  }

  Widget _buildVideoCallView() {
    return Stack(
      children: [
        // Background wallpaper, or remote video when their camera is on
        Positioned.fill(
          child: GestureDetector(
            onTap: _toggleControls,
            child: _remoteHasVideo
                ? _applyVideoFilter(
                    RTCVideoView(
                      _remoteRenderer!,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      mirror: false,
                    ),
                  )
                : Container(decoration: _activeWallpaper.decoration),
          ),
        ),

        // Remote's avatar, centered — shown while their camera is off
        // (matches the reference: the contact's circular photo stays
        // visible in the middle of the screen until they enable video).
        if (!_remoteHasVideo)
          Positioned.fill(
            child: Center(
              child: KoraAvatar(
                name: widget.contactName,
                imageUrl: widget.avatarUrl,
                size: 168,
              ),
            ),
          ),

        // Dark gradient at top
        if (_controlsVisible)
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              height: 140,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
                ),
              ),
            ),
          ),

        // Top bar: minimize, name + verified badge + duration, add-person
        if (_controlsVisible)
          Positioned(
            top: 0, left: 0, right: 0,
            child: _buildCallTopBar(),
          ),

        // Right-side rail: flip camera, then effects — sits below the top
        // bar, matching the reference layout. The self-view PiP defaults
        // to the space just underneath this rail.
        if (_controlsVisible)
          Positioned(
            top: MediaQuery.of(context).padding.top + 68,
            right: 18,
            child: Column(
              children: [
                _ringRailButton(
                    Icons.flip_camera_ios, () => _webrtcService.switchCamera()),
                const SizedBox(height: 14),
                _ringRailButton(Icons.auto_awesome, _openEffectsSheet),
              ],
            ),
          ),

        // Draggable self-view PiP
        if (_localRenderer != null && _isCameraOn && !_pipHidden)
          Positioned(
            left: _pipPosition.dx,
            top: _pipPosition.dy,
            child: GestureDetector(
              onPanStart: (details) {
                _pipDragOffset = details.globalPosition - _pipPosition;
              },
              onPanUpdate: (details) {
                if (_screenSize == null) return;
                setState(() {
                  _pipPosition = details.globalPosition - _pipDragOffset;
                  _pipPosition = Offset(
                    _pipPosition.dx.clamp(4.0, _screenSize!.width - _pipW - 4),
                    _pipPosition.dy.clamp(
                      MediaQuery.of(context).padding.top + 190,
                      _screenSize!.height - _pipH - 100,
                    ),
                  );
                });
              },
              onPanEnd: (_) {
                _snapPipToCorner();
                _checkPipHidden();
              },
              onTap: () {
                setState(() => _pipExpanded = !_pipExpanded);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: _pipW,
                height: _pipH,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: _applyVideoFilter(
                  RTCVideoView(
                    _localRenderer!,
                    mirror: true,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
              ),
            ),
          ),

        // Hidden PiP restore button
        if (_localRenderer != null && _isCameraOn && _pipHidden)
          Positioned(
            top: MediaQuery.of(context).padding.top + 190,
            right: 16,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _pipHidden = false;
                  _pipExpanded = false;
                  if (_screenSize != null) {
                    _pipPosition = Offset(
                      _screenSize!.width - _pipSmallW - 16,
                      MediaQuery.of(context).padding.top + 190,
                    );
                  }
                });
              },
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.5),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                ),
                child: const Icon(Icons.picture_in_picture_alt, color: Colors.white, size: 20),
              ),
            ),
          ),

        // Dark gradient at bottom
        if (_controlsVisible)
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              height: 220,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
                ),
              ),
            ),
          ),

        // Connected call control pill (more, camera, speaker, mute,
        // inline red end-call) — matches the reference call screen.
        if (_controlsVisible)
          Positioned(
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).padding.bottom + 18,
            child: _buildConnectedControlPill(isVideo: true),
          ),
      ],
    );
  }

  // ── Group Video Call View ──

  Widget _buildGroupVideoCallView() {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(decoration: _activeWallpaper.decoration),
        ),

        // Grid or Speaker view
        Positioned.fill(
          child: Column(
            children: [
              SizedBox(height: MediaQuery.of(context).padding.top + 60),
              Expanded(
                child: _isSpeakerView ? _buildSpeakerView() : _buildVideoGrid(),
              ),
              const SizedBox(height: 120),
            ],
          ),
        ),

        // Top bar
        if (_controlsVisible)
          Positioned(
            top: 0, left: 0, right: 0,
            child: _buildGroupTopBar(true),
          ),

        // Bottom floating island bar
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

  Widget _buildVideoGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _participants.length <= 4 ? 2 : (_participants.length <= 9 ? 3 : 4),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.85,
        ),
        itemCount: _participants.length,
        itemBuilder: (context, index) {
          final p = _participants[index];
          final isSpeaker = p.id == _activeSpeakerId || p.isSpeaking;

          return Container(
            decoration: BoxDecoration(
              color: KoraColors.darkCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSpeaker ? KoraColors.purple : Colors.white24,
                width: isSpeaker ? 3.0 : 1.0,
              ),
              boxShadow: isSpeaker
                  ? [
                      BoxShadow(
                        color: KoraColors.purple.withValues(alpha: 0.6),
                        blurRadius: 10,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // Video stream or Avatar
                Positioned.fill(
                  child: p.isSelf && _localRenderer != null && _isCameraOn
                      ? _applyVideoFilter(
                          RTCVideoView(
                            _localRenderer!,
                            mirror: true,
                            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                          ),
                        )
                      : (p.id == widget.contactName && _remoteRenderer != null && p.isVideoOn
                          ? _applyVideoFilter(
                              RTCVideoView(
                                _remoteRenderer!,
                                mirror: false,
                                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                              ),
                            )
                          : Container(
                              color: KoraColors.darkSurface,
                              child: Center(
                                child: CircleAvatar(
                                  radius: 28,
                                  backgroundColor: KoraColors.purple.withValues(alpha: 0.3),
                                  backgroundImage: p.avatarUrl != null && p.avatarUrl!.isNotEmpty
                                      ? NetworkImage(p.avatarUrl!) as ImageProvider
                                      : null,
                                  child: p.avatarUrl == null || p.avatarUrl!.isEmpty
                                      ? Text(
                                          p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                            )),
                ),

                // Name tag
                Positioned(
                  left: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      p.isSelf ? '${p.name} (You)' : p.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),

                // Mute status icon
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      p.isMuted ? Icons.mic_off : Icons.mic,
                      color: p.isMuted ? Colors.redAccent : Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSpeakerView() {
    final activeSpeaker = _participants.firstWhere(
      (p) => p.id == _activeSpeakerId,
      orElse: () => _participants.first,
    );

    return Column(
      children: [
        // Main Active Speaker View
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: KoraColors.darkCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: KoraColors.purple, width: 3),
              boxShadow: [
                BoxShadow(
                  color: KoraColors.purple.withValues(alpha: 0.5),
                  blurRadius: 16,
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Positioned.fill(
                  child: activeSpeaker.isSelf && _localRenderer != null && _isCameraOn
                      ? _applyVideoFilter(
                          RTCVideoView(
                            _localRenderer!,
                            mirror: true,
                            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                          ),
                        )
                      : (activeSpeaker.id == widget.contactName && _remoteRenderer != null
                          ? _applyVideoFilter(
                              RTCVideoView(
                                _remoteRenderer!,
                                mirror: false,
                                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                              ),
                            )
                          : Container(
                              color: KoraColors.darkSurface,
                              child: Center(
                                child: CircleAvatar(
                                  radius: 48,
                                  backgroundColor: KoraColors.purple.withValues(alpha: 0.3),
                                  child: Text(
                                    activeSpeaker.name.isNotEmpty
                                        ? activeSpeaker.name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            )),
                ),

                Positioned(
                  left: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.graphic_eq, color: KoraColors.purple, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          'Active Speaker: ${activeSpeaker.name}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Horizontal thumbnail strip for other participants
        SizedBox(
          height: 90,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _participants.length,
            itemBuilder: (context, index) {
              final p = _participants[index];
              return GestureDetector(
                onTap: () => setState(() => _activeSpeakerId = p.id),
                child: Container(
                  width: 80,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: KoraColors.darkCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: p.id == _activeSpeakerId ? KoraColors.purple : Colors.white24,
                      width: 2,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: KoraColors.purple.withValues(alpha: 0.3),
                        child: Text(
                          p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Positioned(
                        bottom: 4,
                        child: Text(
                          p.name,
                          style: const TextStyle(color: Colors.white, fontSize: 10),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Top Bar Helpers ──

  Widget _buildGroupTopBar(bool isVideo) {
    return Padding(
      padding: EdgeInsets.only(
        left: 8, right: 8,
        top: MediaQuery.of(context).padding.top + 4,
        bottom: 8,
      ),
      child: Row(
        children: [
          _topBarButton(
            icon: Icons.keyboard_arrow_down_rounded,
            onTap: _minimizeCall,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'Group Call (${_participants.length})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Participant count badge
                    GestureDetector(
                      onTap: _openParticipantsSheet,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: KoraColors.purple.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: KoraColors.purple, width: 1),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.people, color: Colors.white, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              '${_participants.length}/32',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _statusText,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          // Speaker View / Grid View toggle
          if (isVideo)
            _topBarButton(
              icon: _isSpeakerView ? Icons.grid_view : Icons.picture_in_picture,
              onTap: () => setState(() => _isSpeakerView = !_isSpeakerView),
            ),

          // Add Person
          _topBarButton(
            icon: Icons.person_add_outlined,
            onTap: _openAddPersonSheet,
          ),

          const SizedBox(width: 4),
          _topBarButton(
            icon: Icons.more_vert,
            onTap: _showOverflowMenu,
          ),
        ],
      ),
    );
  }

  /// Shared 1-on-1 call top bar (voice + video): minimize (top-left),
  /// contact name + verified/premium badge + live status/duration
  /// (centered), and add-person (top-right) — matches the reference
  /// call screen layout.
  Widget _buildCallTopBar() {
    return Padding(
      padding: EdgeInsets.only(
        left: 4, right: 4,
        top: MediaQuery.of(context).padding.top + 4,
        bottom: 8,
      ),
      child: Row(
        children: [
          _topBarButton(
            icon: Icons.close_fullscreen_rounded,
            onTap: _minimizeCall,
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                KoraNameWithBadge(
                  name: widget.contactName,
                  badge: widget.badge ?? KoraBadgeType.none,
                  badgeSize: 15,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _statusText,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          _topBarButton(
            icon: Icons.person_add_outlined,
            onTap: _openAddPersonSheet,
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar({bool transparent = false}) {
    return _buildCallTopBar();
  }

  Widget _topBarButton({required IconData icon, required VoidCallback onTap}) {
    return IconButton(
      icon: Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 24),
      onPressed: onTap,
    );
  }

  // ── Floating island bottom bar ──

  Widget _buildFloatingIslandBar(bool isVideo) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _islandButton(
                icon: _isMuted ? Icons.mic_off : Icons.mic,
                label: _isMuted ? 'Unmute' : 'Mute',
                isActive: _isMuted,
                onTap: _toggleMute,
              ),
              if (!isVideo)
                _islandButton(
                  icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                  label: 'Speaker',
                  isActive: _isSpeakerOn,
                  onTap: _toggleSpeaker,
                )
              else
                _islandButton(
                  icon: _isCameraOn ? Icons.videocam : Icons.videocam_off,
                  label: 'Camera',
                  isActive: _isCameraOn,
                  onTap: _toggleCamera,
                ),
              if (!isVideo)
                _islandButton(
                  icon: Icons.videocam_outlined,
                  label: 'Video',
                  isActive: false,
                  onTap: _confirmSwitchToVideo,
                )
              else
                _islandButton(
                  icon: Icons.flip_camera_ios,
                  label: 'Flip',
                  isActive: false,
                  onTap: () => _webrtcService.switchCamera(),
                ),
              if (isVideo)
                _islandButton(
                  icon: _isScreenSharing ? Icons.stop_screen_share : Icons.screen_share,
                  label: 'Share',
                  isActive: _isScreenSharing,
                  onTap: _toggleScreenShare,
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
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

  double get _pipW => _pipExpanded ? _pipLargeW : _pipSmallW;
  double get _pipH => _pipExpanded ? _pipLargeH : _pipSmallH;

  void _snapPipToCorner() {
    if (_screenSize == null) return;
    final w = _pipW;
    final h = _pipH;
    const margin = 16.0;
    final topSafe = MediaQuery.of(context).padding.top + 190;

    final centerX = _pipPosition.dx + w / 2;
    final centerY = _pipPosition.dy + h / 2;
    final screenW = _screenSize!.width;
    final screenH = _screenSize!.height;

    final leftHalf = centerX < screenW / 2;
    final topHalf = centerY < screenH / 2;

    Offset target;
    if (leftHalf && topHalf) {
      target = Offset(margin, topSafe);
    } else if (!leftHalf && topHalf) {
      target = Offset(screenW - w - margin, topSafe);
    } else if (leftHalf && !topHalf) {
      target = Offset(margin, screenH - h - margin - 100);
    } else {
      target = Offset(screenW - w - margin, screenH - h - margin - 100);
    }

    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        setState(() {
          _pipPosition = target;
        });
      }
    });
  }

  void _checkPipHidden() {
    if (_screenSize == null) return;
    if (_pipPosition.dx < -_pipW * 0.7 ||
        _pipPosition.dx > _screenSize!.width - _pipW * 0.3 ||
        _pipPosition.dy < -_pipH * 0.7 ||
        _pipPosition.dy > _screenSize!.height - _pipH * 0.3) {
      setState(() => _pipHidden = true);
    }
  }
}

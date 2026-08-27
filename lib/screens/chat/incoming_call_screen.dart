import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import '../../models/chat_models.dart';
import '../../services/webrtc_call_service.dart';
import '../../services/call_service.dart';
import '../../services/incoming_call_service.dart';
import '../../services/session_manager.dart';
import '../../models/call_log.dart';
import 'call_screen.dart';

/// Incoming call screen — shown when another user is calling.
///
/// WhatsApp 2025 design:
/// - Full-screen dark gradient background
/// - Pulsing avatar with gradient ring
/// - Caller name + call type (voice/video)
/// - Pill-shaped Accept (green) and Decline (red) buttons
/// - Accept uses tap (not swipe) — consistent with WhatsApp's latest
class IncomingCallScreen extends StatefulWidget {
  final IncomingCallData callData;
  final String callerName;
  final String? avatarUrl;
  final KoraBadgeType? badge;

  const IncomingCallScreen({
    super.key,
    required this.callData,
    required this.callerName,
    this.avatarUrl,
    this.badge,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with SingleTickerProviderStateMixin {
  final _webrtcService = WebRTCCallService.instance;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isAccepting = false;
  bool _didRespond = false;
  bool _navigatedToCallScreen = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _acceptCall() async {
    if (_didRespond) return;
    _didRespond = true;
    setState(() => _isAccepting = true);

    try {
      final session = await SessionManager.instance.loadSession();
      final myEmail = session?['email'] ?? '';

      _webrtcService.onCallStateChanged = (state) {
        if (mounted && !_navigatedToCallScreen) {
          if (state == 'connected') {
            _navigateToCallScreen();
          } else if (state == 'ended' || state == 'failed' || state == 'rejected') {
            IncomingCallService.instance.setCallInProgress(false);
            if (mounted) Navigator.pop(context);
          }
        }
      };

      _webrtcService.onRemoteStream = (_) {};

      await _webrtcService.acceptCall(
        callId: widget.callData.callId,
        calleeId: myEmail,
        offer: widget.callData.offer,
      );

      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted && !_navigatedToCallScreen) {
        _navigateToCallScreen();
      }
    } catch (e) {
      debugPrint('Failed to accept call: $e');
      IncomingCallService.instance.setCallInProgress(false);
      if (mounted) Navigator.pop(context);
    }
  }

  void _navigateToCallScreen() {
    if (_navigatedToCallScreen) return;
    _navigatedToCallScreen = true;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          contactName: widget.callerName,
          avatarUrl: widget.avatarUrl,
          badge: widget.badge,
          isVideoCall: widget.callData.callType == 'video',
          isOutgoing: false,
        ),
      ),
    );
  }

  void _rejectCall() async {
    if (_didRespond) return;
    _didRespond = true;

    try {
      await _webrtcService.rejectCall(widget.callData.callId);
    } catch (_) {}

    await CallService.instance.logMissedCall(
      contactName: widget.callerName,
      type: widget.callData.callType == 'video' ? CallType.video : CallType.voice,
      avatarUrl: widget.avatarUrl,
      badge: widget.badge,
    );

    IncomingCallService.instance.setCallInProgress(false);

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.callData.callType == 'video';

    return Scaffold(
      body: Container(
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
              const Spacer(flex: 2),
              // Pulsing avatar with gradient ring
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
                        backgroundImage: widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty
                            ? NetworkImage(widget.avatarUrl!)
                            : null,
                        child: (widget.avatarUrl == null || widget.avatarUrl!.isEmpty)
                            ? _initialsAvatar()
                            : null,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
              // Caller name
              Text(
                widget.callerName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              // Call type
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isVideo ? Icons.videocam : Icons.phone,
                    color: KoraColors.purple,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isVideo ? 'Incoming video call' : 'Incoming voice call',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const Spacer(flex: 3),
              if (_isAccepting) ...[
                const SizedBox(
                  width: 48, height: 48,
                  child: CircularProgressIndicator(
                    color: KoraColors.purple,
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Connecting…',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 16,
                  ),
                ),
              ] else ...[
                // Pill-shaped buttons (WhatsApp 2025 style)
                _pillButton(
                  icon: Icons.call_end,
                  label: 'Decline',
                  color: const Color(0xFFEF4444),
                  onTap: _rejectCall,
                ),
                const SizedBox(height: 16),
                _pillButton(
                  icon: isVideo ? Icons.videocam : Icons.phone,
                  label: 'Accept',
                  color: const Color(0xFF25D366),
                  onTap: _acceptCall,
                ),
              ],
              const Spacer(flex: 1),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _initialsAvatar() {
    final initials = widget.callerName.isNotEmpty
        ? widget.callerName.split(' ').take(2).map((e) => e[0].toUpperCase()).join()
        : '?';
    return Text(
      initials,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 48,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  /// WhatsApp 2025 pill-shaped call button with tap-to-act (not swipe).
  Widget _pillButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 180,
        height: 56,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 26),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

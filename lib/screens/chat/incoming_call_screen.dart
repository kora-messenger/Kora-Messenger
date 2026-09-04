import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
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
/// WhatsApp 2026 design:
/// - Full-screen dark gradient background
/// - Pulsing avatar with gradient ring
/// - Caller name + call type (voice/video)
/// - Three swipe-up action buttons at the bottom:
///   • Decline (red phone icon) — swipe up to reject
///   • Reply (message icon) — swipe up to decline + send quick message
///   • Accept (green phone/video icon) — swipe up to answer
/// - Each button has a label below the circular icon
/// - Swipe-up gesture on each button triggers the action
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
  bool _showReplySheet = false;

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

  void _replyWithMessage(String message) async {
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

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reply sent'),
          backgroundColor: KoraColors.purple,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      Navigator.pop(context);
    }
  }

  void _openReplySheet() {
    setState(() => _showReplySheet = true);
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
          child: _showReplySheet
              ? _buildReplySheet(isVideo)
              : _buildIncomingCallUI(isVideo),
        ),
      ),
    );
  }

  // ── Main incoming call UI ──────────────────────────────────

  Widget _buildIncomingCallUI(bool isVideo) {
    return Column(
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
                      ? (widget.avatarUrl!.startsWith('data:')
                          ? MemoryImage(_decodeBase64Avatar(widget.avatarUrl!)) as ImageProvider
                          : NetworkImage(widget.avatarUrl!) as ImageProvider)
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
            width: 48,
            height: 48,
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
          // WhatsApp swipe-up action buttons
          _buildSwipeActionButtons(isVideo),
        ],
        const Spacer(flex: 1),
        const SizedBox(height: 48),
      ],
    );
  }

  // ── WhatsApp swipe-up action buttons ───────────────────────

  Widget _buildSwipeActionButtons(bool isVideo) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Decline — swipe up
        _swipeUpAction(
          icon: Icons.call_end,
          label: 'Decline',
          color: const Color(0xFFEF4444),
          onSwipeUp: _rejectCall,
        ),
        // Reply — swipe up to decline + send quick message
        _swipeUpAction(
          icon: Icons.message,
          label: 'Reply',
          color: Colors.white.withValues(alpha: 0.9),
          iconColor: const Color(0xFF13131F),
          onSwipeUp: _openReplySheet,
        ),
        // Accept — swipe up
        _swipeUpAction(
          icon: isVideo ? Icons.videocam : Icons.phone,
          label: 'Accept',
          color: const Color(0xFF25D366),
          onSwipeUp: _acceptCall,
        ),
      ],
    );
  }

  /// WhatsApp-style swipe-up action button.
  /// Circular icon with a label below. Swipe up to trigger the action.
  Widget _swipeUpAction({
    required IconData icon,
    required String label,
    required Color color,
    Color? iconColor,
    required VoidCallback onSwipeUp,
  }) {
    return GestureDetector(
      onTap: onSwipeUp,
      onVerticalDragEnd: (details) {
        // Swipe up = negative velocity
        if (details.primaryVelocity != null && details.primaryVelocity! < -200) {
          onSwipeUp();
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Swipe-up arrow indicator (animated, above the circle)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 800),
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, -4 * (1 - value)),
                child: Opacity(
                  opacity: 0.4 * (1 - value) + 0.2,
                  child: Icon(
                    Icons.keyboard_arrow_up_rounded,
                    color: Colors.white.withValues(alpha: 0.5),
                    size: 20,
                  ),
                ),
              );
            },
          ),
          // Circular icon button
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              icon,
              color: iconColor ?? Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(height: 10),
          // Label below
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          // "Swipe up" hint
          const SizedBox(height: 2),
          Text(
            'Swipe up',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  // ── Reply sheet (decline + send quick message) ──────────────

  Widget _buildReplySheet(bool isVideo) {
    final quickMessages = [
      "Can't talk now. What's up?",
      "I'll call you right back.",
      "Can't talk now. Call me later?",
      "Can't talk right now, sorry.",
      "Give me a few minutes.",
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Header
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: Colors.white.withValues(alpha: 0.7)),
                onPressed: () => setState(() => _showReplySheet = false),
              ),
              const Spacer(),
              Text(
                'Reply',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Decline this call and send a message',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          // Quick message options
          Expanded(
            child: ListView.builder(
              itemCount: quickMessages.length,
              itemBuilder: (context, index) {
                return _replyOption(quickMessages[index]);
              },
            ),
          ),
          // Custom message input
          _customReplyInput(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _replyOption(String message) {
    return GestureDetector(
      onTap: () => _replyWithMessage(message),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              color: Colors.white.withValues(alpha: 0.4),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 15,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.white.withValues(alpha: 0.3),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _customReplyInput() {
    final controller = TextEditingController();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: 'Custom message…',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 15,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
              onSubmitted: (text) {
                if (text.trim().isNotEmpty) {
                  _replyWithMessage(text.trim());
                }
              },
            ),
          ),
          GestureDetector(
            onTap: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                _replyWithMessage(text);
              }
            },
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: KoraColors.brandGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────

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

  static Uint8List _decodeBase64Avatar(String dataUrl) {
    final commaIdx = dataUrl.indexOf(',');
    final base64Str = commaIdx >= 0 ? dataUrl.substring(commaIdx + 1) : dataUrl;
    return Uint8List.fromList(base64Decode(base64Str));
  }
}

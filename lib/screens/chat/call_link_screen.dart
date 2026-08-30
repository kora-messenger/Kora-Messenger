import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/kora_colors.dart';
import '../../services/webrtc_call_service.dart';
import '../../config/kora_api.dart';

/// Call Link screen — create or join a call via a shareable link.
/// Mirrors WhatsApp's "Call Link" feature.
///
/// Two modes:
/// - Create: generates a link, shows it with copy/share buttons
/// - Join: shows a waiting room before joining the call
class CallLinkScreen extends StatefulWidget {
  const CallLinkScreen({super.key});

  @override
  State<CallLinkScreen> createState() => _CallLinkScreenState();
}

class _CallLinkScreenState extends State<CallLinkScreen> {
  String? _callLink;
  bool _isVideo = true;
  bool _generating = false;

  Future<void> _generateLink() async {
    setState(() => _generating = true);
    try {
      final link = await WebRTCCallService.instance.generateCallLinkToken(
          callType: _isVideo ? 'video' : 'voice',
      );
      setState(() {
        _callLink = '${KoraApi.callLinkBaseUrl}/call/$link';
        _generating = false;
      });
    } catch (_) {
      setState(() => _generating = false);
    }
  }

  void _copyLink() {
    if (_callLink == null) return;
    Clipboard.setData(ClipboardData(text: _callLink!));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Call link copied'),
        backgroundColor: KoraColors.purple,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _startCall() {
    if (_callLink == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CallWaitingRoomScreen(
          callLink: _callLink!,
          isVideo: _isVideo,
          isHost: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text('Call Link',
            style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Center(
              child: Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [KoraColors.purple, KoraColors.blue]),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.link, color: Colors.white, size: 32),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text('Create a Call Link',
                  style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text('Share a link to invite anyone to a call',
                  style: TextStyle(color: textMuted, fontSize: 13)),
            ),

            const SizedBox(height: 32),

            // Video / Voice toggle
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isVideo = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _isVideo ? KoraColors.purple.withValues(alpha: 0.15) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.videocam,
                                size: 18,
                                color: _isVideo ? KoraColors.purple : textMuted),
                            const SizedBox(width: 8),
                            Text('Video',
                                style: TextStyle(
                                    color: _isVideo ? KoraColors.purple : textMuted,
                                    fontSize: 14, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isVideo = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: !_isVideo ? KoraColors.purple.withValues(alpha: 0.15) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.call,
                                size: 18,
                                color: !_isVideo ? KoraColors.purple : textMuted),
                            const SizedBox(width: 8),
                            Text('Voice',
                                style: TextStyle(
                                    color: !_isVideo ? KoraColors.purple : textMuted,
                                    fontSize: 14, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            if (_callLink != null) ...[
              // Generated link
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: KoraColors.purple.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(_callLink!,
                          style: TextStyle(color: KoraColors.purple, fontSize: 14),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    IconButton(
                      icon: Icon(Icons.copy, color: KoraColors.purple, size: 20),
                      onPressed: _copyLink,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _startCall,
                  icon: Icon(_isVideo ? Icons.videocam : Icons.call, size: 20),
                  label: Text('Start Call', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: KoraColors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _generating ? null : _generateLink,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: KoraColors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _generating
                      ? SizedBox(height: 20, width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('Create Link', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Waiting room — shown before joining a call link.
/// Shows "Waiting for host..." or "People are in the call" before entering.
class CallWaitingRoomScreen extends StatefulWidget {
  final String callLink;
  final bool isVideo;
  final bool isHost;

  const CallWaitingRoomScreen({
    super.key,
    required this.callLink,
    required this.isVideo,
    this.isHost = false,
  });

  @override
  State<CallWaitingRoomScreen> createState() => _CallWaitingRoomScreenState();
}

class _CallWaitingRoomScreenState extends State<CallWaitingRoomScreen> {
  @override
  void initState() {
    super.initState();
    // Auto-join after a brief delay
    Future.delayed(const Duration(seconds: 2), _joinCall);
  }

  void _joinCall() {
    if (!mounted) return;
    // Extract token from link
    final token = widget.callLink.split('/call/').last;
    WebRTCCallService.instance.joinGroupCall(token, video: widget.isVideo);
    // Navigate to call screen
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => _WaitingRoomToCall(
          callLink: widget.callLink,
          isVideo: widget.isVideo,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Pulsing call icon
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [KoraColors.purple, KoraColors.blue]),
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.isVideo ? Icons.videocam : Icons.call,
                color: Colors.white, size: 36,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              widget.isHost ? 'Starting call…' : 'Joining call…',
              style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              widget.isHost ? 'Setting up your call link' : 'Connecting you to the call',
              style: TextStyle(color: textMuted, fontSize: 14),
            ),
            const SizedBox(height: 32),
            CircularProgressIndicator(color: KoraColors.purple, strokeWidth: 2),
          ],
        ),
      ),
    );
  }
}

/// Simple wrapper to transition from waiting room to actual call screen.
/// In production, this would use the full CallScreen.
class _WaitingRoomToCall extends StatelessWidget {
  final String callLink;
  final bool isVideo;

  const _WaitingRoomToCall({
    required this.callLink,
    required this.isVideo,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Scaffold(
      backgroundColor: KoraColors.backgroundFor(brightness),
      appBar: AppBar(
        backgroundColor: KoraColors.backgroundFor(brightness),
        title: Text('Group Call',
            style: TextStyle(color: KoraColors.textPrimaryFor(brightness))),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: KoraColors.textPrimaryFor(brightness)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isVideo ? Icons.videocam : Icons.call,
                size: 64, color: KoraColors.purple),
            const SizedBox(height: 16),
            Text('You are in the call',
                style: TextStyle(
                    color: KoraColors.textPrimaryFor(brightness),
                    fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Call link: $callLink',
                style: TextStyle(
                    color: KoraColors.textMutedFor(brightness), fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

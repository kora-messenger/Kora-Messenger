import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../theme/kora_colors.dart';
import 'attachment_sheet.dart';
import 'voice_recorder.dart';
import 'voice_preview.dart';

/// Kora's message composer — the bottom input bar.
///
/// States:
/// - **Idle** → text input + mic button (when empty) or send button (when typing)
/// - **Recording** → live waveform, timer, delete, send
/// - **Preview** → play/pause, waveform, duration, delete, send
///
/// Mic button requests microphone permission with a clear explanation
/// before recording. If denied, shows a message explaining how to enable
/// it from device settings.
class MessageComposer extends StatefulWidget {
  final Function(String) onSend;
  final Function(String duration, {String? filePath}) onSendVoice;
  final VoidCallback? onAttachment;

  const MessageComposer({
    super.key,
    required this.onSend,
    required this.onSendVoice,
    this.onAttachment,
  });

  @override
  State<MessageComposer> createState() => _MessageComposerState();
}

enum _ComposerState { idle, recording, preview }

class _MessageComposerState extends State<MessageComposer> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _hasText = false;
  _ComposerState _state = _ComposerState.idle;
  String _recordedDuration = '0:00';
  String? _recordedPath;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final has = _controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
    setState(() => _hasText = false);
  }

  // ── Recording flow ──

  Future<void> _onMicTap() async {
    // Check mic permission
    final status = await Permission.microphone.status;

    if (status.isGranted) {
      _startRecording();
    } else if (status.isDenied || status.isRestricted) {
      // Show explanation dialog, then request
      final shouldRequest = await _showPermissionDialog();
      if (shouldRequest) {
        final result = await Permission.microphone.request();
        if (result.isGranted) {
          _startRecording();
        } else if (result.isPermanentlyDenied) {
          if (mounted) _showSettingsPrompt();
        }
      }
    } else if (status.isPermanentlyDenied) {
      if (mounted) _showSettingsPrompt();
    }
  }

  Future<bool> _showPermissionDialog() async {
    final brightness = Theme.of(context).brightness;
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KoraColors.cardFor(brightness),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.mic_rounded, color: KoraColors.purple, size: 24),
            const SizedBox(width: 8),
            Text(
              'Microphone Access',
              style: TextStyle(
                color: KoraColors.textPrimaryFor(brightness),
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Text(
          'Kora needs access to your microphone to record voice notes. '
          'Your recordings are only shared with the people you message.',
          style: TextStyle(
            color: KoraColors.textSecondaryFor(brightness),
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Not now',
              style: TextStyle(color: KoraColors.textMutedFor(brightness)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              backgroundColor: KoraColors.purple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Allow', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showSettingsPrompt() {
    final brightness = Theme.of(context).brightness;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.settings, color: KoraColors.purple, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Microphone access is blocked. Enable it in Settings to record voice notes.',
                style: TextStyle(
                  color: KoraColors.textPrimaryFor(brightness),
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: KoraColors.cardFor(brightness),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Settings',
          textColor: KoraColors.purple,
          onPressed: () => openAppSettings(),
        ),
      ),
    );
  }

  void _startRecording() {
    setState(() => _state = _ComposerState.recording);
  }

  void _cancelRecording() {
    setState(() => _state = _ComposerState.idle);
  }

  void _stopRecording(String duration, String? filePath) {
    setState(() {
      _recordedDuration = duration;
      _recordedPath = filePath;
      _state = _ComposerState.preview;
    });
  }

  void _discardPreview() {
    setState(() => _state = _ComposerState.idle);
  }

  void _sendVoice() {
    setState(() => _state = _ComposerState.idle);
    widget.onSendVoice(_recordedDuration, filePath: _recordedPath);
    _recordedPath = null;
  }

  void _openAttachments() {
    final types = [
      KoraAttachmentType(
        icon: Icons.photo_outlined,
        label: 'Photos',
        color: const Color(0xFF8B5CF6),
        onTap: () {},
      ),
      KoraAttachmentType(
        icon: Icons.videocam_outlined,
        label: 'Videos',
        color: const Color(0xFFEC4899),
        onTap: () {},
      ),
      KoraAttachmentType(
        icon: Icons.camera_alt_outlined,
        label: 'Camera',
        color: const Color(0xFF3B82F6),
        onTap: () {},
      ),
      KoraAttachmentType(
        icon: Icons.insert_drive_file_outlined,
        label: 'Files',
        color: const Color(0xFFF59E0B),
        onTap: () {},
      ),
      KoraAttachmentType(
        icon: Icons.location_on_outlined,
        label: 'Location',
        color: const Color(0xFF22C55E),
        onTap: () {},
      ),
    ];

    if (widget.onAttachment != null) {
      widget.onAttachment!();
    } else {
      AttachmentSheet.show(context, types);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final surface = KoraColors.cardFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);
    final border = KoraColors.borderFor(brightness);

    // ── Recording state ──
    if (_state == _ComposerState.recording) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
          child: VoiceRecorderBar(
            onCancel: _cancelRecording,
            onSend: _stopRecording,
          ),
        ),
      );
    }

    // ── Preview state ──
    if (_state == _ComposerState.preview) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
          child: VoicePreviewBar(
            duration: _recordedDuration,
            filePath: _recordedPath,
            onDiscard: _discardPreview,
            onSend: _sendVoice,
          ),
        ),
      );
    }

    // ── Idle / typing state ──
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          border: Border(
            top: BorderSide(color: border, width: 0.5),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: Row(
            children: [
              // Emoji button
              IconButton(
                icon: Icon(Icons.emoji_emotions_outlined, color: textMuted, size: 26),
                onPressed: () {},
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
              // Text input
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 120),
                  decoration: BoxDecoration(
                    color: KoraColors.surfaceFor(brightness),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          maxLines: null,
                          textInputAction: TextInputAction.newline,
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 15,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Message',
                            hintStyle: TextStyle(color: textMuted, fontSize: 15),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                      // Attachment button (inside input pill)
                      IconButton(
                        icon: Icon(Icons.attach_file, color: textMuted, size: 22),
                        onPressed: _openAttachments,
                        padding: const EdgeInsets.only(right: 8),
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // Send or Mic button
              GestureDetector(
                onTap: _hasText ? _send : _onMicTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: _hasText ? KoraColors.brandGradient : null,
                    color: _hasText ? null : KoraColors.surfaceFor(brightness),
                    shape: BoxShape.circle,
                    border: _hasText
                        ? null
                        : Border.all(color: textMuted.withValues(alpha: 0.3), width: 1),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      _hasText ? Icons.send : Icons.mic_rounded,
                      key: ValueKey(_hasText),
                      color: _hasText ? Colors.white : textMuted,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

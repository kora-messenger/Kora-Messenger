import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import 'attachment_sheet.dart';
import 'voice_recorder.dart';

/// Kora's message composer — the bottom input bar.
/// Has: text input, emoji button, attachment button, voice/send toggle.
/// When empty: shows mic icon. When text present: shows send icon.
/// When recording: replaced by VoiceRecorderBar.
class MessageComposer extends StatefulWidget {
  final Function(String) onSend;
  final Function(String) onSendVoice;
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

class _MessageComposerState extends State<MessageComposer> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _hasText = false;
  bool _isRecording = false;

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

  void _startRecording() {
    setState(() => _isRecording = true);
  }

  void _cancelRecording() {
    setState(() => _isRecording = false);
  }

  void _sendVoice(String duration) {
    setState(() => _isRecording = false);
    widget.onSendVoice(duration);
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

    if (_isRecording) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
          child: VoiceRecorderBar(
            onCancel: _cancelRecording,
            onSend: () => _sendVoice('0:05'),
          ),
        ),
      );
    }

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
                onTap: _hasText ? _send : _startRecording,
                onLongPress: _hasText ? null : _startRecording,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
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
                  child: Icon(
                    _hasText ? Icons.send : Icons.mic,
                    color: _hasText ? Colors.white : textMuted,
                    size: 22,
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

import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';

/// Kora's Voice & Media settings — upload your own audio/video for
/// supported Kora voice features.
///
/// Flow: Settings → Voice & Media → Upload Your Own Voice →
/// Select Audio/Video → Consent Warning → Agree → Upload → Process
///
/// The consent warning is mandatory before any upload or processing.
/// The "I Agree" button stays disabled until the user checks the
/// agreement checkbox.
class VoiceMediaSettingsScreen extends StatefulWidget {
  const VoiceMediaSettingsScreen({super.key});

  @override
  State<VoiceMediaSettingsScreen> createState() =>
      _VoiceMediaSettingsScreenState();
}

class _VoiceMediaSettingsScreenState extends State<VoiceMediaSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final card = KoraColors.cardFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);
    final border = KoraColors.borderFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: card,
        elevation: 0,
        title: Text(
          'Voice & Media',
          style: TextStyle(
            color: textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ── Info card ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: KoraColors.purple.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: KoraColors.purple.withValues(alpha: 0.12),
                  width: 0.5,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.graphic_eq_rounded, size: 22, color: KoraColors.purple),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Manage voice, audio, and video features. Upload your own audio or video to use through supported Kora features.',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 13.5,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Upload Your Own Voice ──
          _sectionLabel('UPLOAD', textMuted),
          _card(
            card: card,
            border: border,
            children: [
              InkWell(
                onTap: () => _showUploadFlow(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: KoraColors.purple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.upload_file_rounded, color: KoraColors.purple, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Upload Your Own Voice',
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Select an audio or video file from your device',
                              style: TextStyle(color: textSecondary, fontSize: 12.5),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: textMuted),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Consent info ──
          _sectionLabel('CONSENT', textMuted),
          _card(
            card: card,
            border: border,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: KoraColors.purple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.privacy_tip_outlined, color: KoraColors.purple, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Consent Protection',
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'You must confirm consent before uploading any media',
                            style: TextStyle(color: textSecondary, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showUploadFlow(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _UploadFlowSheet(brightness: brightness),
    );
  }

  Widget _sectionLabel(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _card({
    required Color card,
    required Color border,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: 0.3),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

// ── Upload Flow Bottom Sheet ──────────────────────────────────

class _UploadFlowSheet extends StatefulWidget {
  final Brightness brightness;

  const _UploadFlowSheet({required this.brightness});

  @override
  State<_UploadFlowSheet> createState() => _UploadFlowSheetState();
}

class _UploadFlowSheetState extends State<_UploadFlowSheet> {
  bool _agreed = false;
  bool _uploading = false;
  bool _uploaded = false;

  @override
  Widget build(BuildContext context) {
    final card = KoraColors.cardFor(widget.brightness);
    final surface = KoraColors.surfaceFor(widget.brightness);
    final textPrimary = KoraColors.textPrimaryFor(widget.brightness);
    final textSecondary = KoraColors.textSecondaryFor(widget.brightness);
    final textMuted = KoraColors.textMutedFor(widget.brightness);
    final border = KoraColors.borderFor(widget.brightness);

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
              child: Row(
                children: [
                  Icon(Icons.upload_file_rounded, color: KoraColors.purple, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Upload Your Own Voice',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: textMuted, size: 22),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: border),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: _uploaded
                    ? _buildSuccessView(surface, textPrimary, textSecondary)
                    : _buildUploadView(surface, textPrimary, textSecondary, textMuted, border),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadView(
    Color surface,
    Color textPrimary,
    Color textSecondary,
    Color textMuted,
    Color border,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── File type selection ──
        Text(
          'CHOOSE FILE TYPE',
          style: TextStyle(
            color: textMuted,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _fileTypeCard(
                Icons.audio_file_rounded,
                'Audio File',
                surface,
                textPrimary,
                textSecondary,
                border,
                () => _selectFile('audio'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _fileTypeCard(
                Icons.video_file_rounded,
                'Video File',
                surface,
                textPrimary,
                textSecondary,
                border,
                () => _selectFile('video'),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // ── Consent warning ──
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: KoraColors.red.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: KoraColors.red.withValues(alpha: 0.15),
              width: 0.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 20, color: KoraColors.red),
                  const SizedBox(width: 8),
                  Text(
                    'Before You Upload',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Don\'t upload any person\'s voice, audio, or video without their consent.',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 13.5,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Only upload media if this is your own audio/video or you have asked the owner for permission before uploading it.',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── Agreement checkbox ──
        GestureDetector(
          onTap: () => setState(() => _agreed = !_agreed),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: _agreed ? KoraColors.purple : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _agreed ? KoraColors.purple : border,
                    width: 1.5,
                  ),
                ),
                child: _agreed
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'I agree that this is my video/audio or I agree I have asked the owner of the video/audio before uploading it.',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 13.5,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ── Buttons ──
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: border, width: 0.5),
                  ),
                  child: Center(
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: _agreed && !_uploading ? _doUpload : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: _agreed ? KoraColors.brandGradient : null,
                    color: _agreed ? null : surface,
                    borderRadius: BorderRadius.circular(12),
                    border: _agreed ? null : Border.all(color: border, width: 0.5),
                  ),
                  child: Center(
                    child: _uploading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'I Agree',
                            style: TextStyle(
                              color: _agreed ? Colors.white : textMuted,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _fileTypeCard(
    IconData icon,
    String label,
    Color surface,
    Color textPrimary,
    Color textSecondary,
    Color border,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: 0.5),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: KoraColors.purple),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectFile(String type) {
    // Would use image_picker or file_picker here in production
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(type == 'audio' ? 'Select an audio file...' : 'Select a video file...'),
        backgroundColor: KoraColors.purple,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _doUpload() {
    setState(() => _uploading = true);
    // Simulate upload + processing
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _uploading = false;
          _uploaded = true;
        });
      }
    });
  }

  Widget _buildSuccessView(Color surface, Color textPrimary, Color textSecondary) {
    return Column(
      children: [
        const SizedBox(height: 20),
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: KoraColors.purple.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check_circle_rounded, size: 40, color: KoraColors.purple),
        ),
        const SizedBox(height: 16),
        Text(
          'Upload Complete',
          style: TextStyle(
            color: textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Your media has been processed and is ready to use in supported Kora features.',
          style: TextStyle(
            color: textSecondary,
            fontSize: 13.5,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              gradient: KoraColors.brandGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                'Done',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

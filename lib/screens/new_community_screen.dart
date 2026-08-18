import 'package:flutter/material.dart';
import '../theme/kora_colors.dart';
import 'community_preview_screen.dart';

/// New Community screen — setup community profile, name, and description.
/// Continue arrow at the bottom takes user to the community preview.
class NewCommunityScreen extends StatefulWidget {
  const NewCommunityScreen({super.key});

  @override
  State<NewCommunityScreen> createState() => _NewCommunityScreenState();
}

class _NewCommunityScreenState extends State<NewCommunityScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  bool get _canContinue => _nameController.text.trim().isNotEmpty;

  void _goToPreview() {
    final name = _nameController.text.trim();
    final desc = _descController.text.trim();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CommunityPreviewScreen(
          communityName: name,
          communityDescription: desc,
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
    final border = KoraColors.borderFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header with back arrow
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.arrow_back, color: textPrimary, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'New Community',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            // Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 32),
                    // Circle community profile image
                    GestureDetector(
                      onTap: () {
                        // TODO: Pick image
                      },
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: border, width: 1.5),
                        ),
                        child: Icon(
                          Icons.camera_alt_outlined,
                          color: textMuted,
                          size: 36,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Tap to add photo',
                      style: TextStyle(color: textMuted, fontSize: 13),
                    ),
                    const SizedBox(height: 36),
                    // Community name field
                    Container(
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: border, width: 0.5),
                      ),
                      child: TextField(
                        controller: _nameController,
                        maxLength: 100,
                        style: TextStyle(color: textPrimary, fontSize: 16),
                        decoration: InputDecoration(
                          hintText: 'Community name',
                          hintStyle: TextStyle(color: textMuted, fontSize: 16),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          counterStyle: TextStyle(color: textMuted, fontSize: 11),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Community description field (optional)
                    Container(
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: border, width: 0.5),
                      ),
                      child: TextField(
                        controller: _descController,
                        maxLength: 3000,
                        maxLines: 4,
                        style: TextStyle(color: textPrimary, fontSize: 16),
                        decoration: InputDecoration(
                          hintText: 'Description (optional)',
                          hintStyle: TextStyle(color: textMuted, fontSize: 16),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          counterStyle: TextStyle(color: textMuted, fontSize: 11),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Provide a description to help people understand your community.',
                        style: TextStyle(color: textMuted, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Continue arrow at bottom
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: _canContinue ? _goToPreview : null,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: _canContinue ? KoraColors.brandGradient : null,
                        color: _canContinue ? null : KoraColors.purple.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                        boxShadow: _canContinue
                            ? [
                                BoxShadow(
                                  color: KoraColors.purple.withValues(alpha: 0.35),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        Icons.arrow_forward,
                        color: _canContinue ? Colors.white : textMuted,
                        size: 26,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

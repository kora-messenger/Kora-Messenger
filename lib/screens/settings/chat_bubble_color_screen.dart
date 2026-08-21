import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import '../../theme/chat_theme_provider.dart';
import 'chat_theme_preview_screen.dart';
import 'premium_subscribe_sheet.dart';

/// Color picker for chat bubble colors.
class ChatBubbleColorScreen extends StatefulWidget {
  const ChatBubbleColorScreen({super.key});

  @override
  State<ChatBubbleColorScreen> createState() => _ChatBubbleColorScreenState();
}

class _ChatBubbleColorScreenState extends State<ChatBubbleColorScreen> {
  final _provider = ChatThemeProvider.instance;
  late Color _selected;
  bool _isLoadingPremium = false;

  @override
  void initState() {
    super.initState();
    _selected = _provider.customSentBubble ?? _provider.activeTheme.sentBubble;
    _provider.addListener(_onChanged);
  }

  @override
  void dispose() {
    _provider.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) {
      setState(() {
        _selected = _provider.customSentBubble ?? _provider.activeTheme.sentBubble;
      });
    }
  }

  Future<void> _showPremiumSheet() async {
    if (_isLoadingPremium) return;
    setState(() => _isLoadingPremium = true);
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    setState(() => _isLoadingPremium = false);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const PremiumSubscribeSheet(),
    );
  }

  void _openPreview(Color color) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatThemePreviewScreen(
          backgrounds: [currentPreviewBackground(_provider)],
          initialBubbleColor: color,
          allowSwipe: false,
          hintText: null,
          descriptionText: 'This is how your sent messages will look.',
          onApply: (bg, bubbleColor, dimLevel) {
            _provider.setCustomSentBubble(bubbleColor);
            _provider.setWallpaperDimLevel(dimLevel);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final card = KoraColors.cardFor(brightness);
    final border = KoraColors.borderFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          'Chat bubble',
          style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Preview
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border, width: 0.5),
              ),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _provider.customReceivedBubble ?? _provider.activeTheme.receivedBubble,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(14),
                          topRight: Radius.circular(14),
                          bottomRight: Radius.circular(14),
                          bottomLeft: Radius.circular(4),
                        ),
                      ),
                      child: Text(
                        'This is a received message',
                        style: TextStyle(
                          color: _provider.activeTheme.receivedTextColor,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _selected,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(14),
                          topRight: Radius.circular(14),
                          bottomLeft: Radius.circular(14),
                          bottomRight: Radius.circular(4),
                        ),
                      ),
                      child: const Text(
                        'This is a sent message',
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (!_provider.isPremium) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: KoraColors.purple.withValues(alpha: 0.25), width: 1.5),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.workspace_premium, color: KoraColors.purple, size: 28),
                      const SizedBox(height: 8),
                      const Text(
                        'Custom chat bubbles are a Kora Premium feature',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: KoraColors.purple, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Upgrade to unlock 20 unique bubble colors.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: textSecondary, fontSize: 12.5),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: KoraColors.purple,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: _isLoadingPremium
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.workspace_premium, size: 18),
                          label: Text(_isLoadingPremium ? 'Loading...' : 'Get Kora Premium'),
                          onPressed: _isLoadingPremium ? null : _showPremiumSheet,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ] else ...[
            // Color grid (premium only)
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  childAspectRatio: 1,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: kChatBubbleColors.length,
                itemBuilder: (context, index) {
                  final color = kChatBubbleColors[index];
                  final isSelected = _selected.toARGB32() == color.toARGB32();
                  return GestureDetector(
                    onTap: () => _openPreview(color),
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 22)
                          : null,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import '../../theme/chat_theme_provider.dart';
import 'chat_theme_preview_screen.dart';

/// Color picker for chat bubble colors.
class ChatBubbleColorScreen extends StatefulWidget {
  const ChatBubbleColorScreen({super.key});

  @override
  State<ChatBubbleColorScreen> createState() => _ChatBubbleColorScreenState();
}

class _ChatBubbleColorScreenState extends State<ChatBubbleColorScreen> {
  final _provider = ChatThemeProvider.instance;
  late Color _selected;

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
            // Color grid
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

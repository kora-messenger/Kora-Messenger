import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';

/// An inline search bar that appears at the top of the chat screen.
/// Searches messages within the current chat and highlights matching text.
/// Pressing the back arrow or close button hides the search bar.
class ChatSearchBar extends StatefulWidget {
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClose;
  final int resultCount;

  const ChatSearchBar({
    super.key,
    required this.onQueryChanged,
    required this.onClose,
    this.resultCount = 0,
  });

  @override
  State<ChatSearchBar> createState() => _ChatSearchBarState();
}

class _ChatSearchBarState extends State<ChatSearchBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);

    return Material(
      color: bg,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Search bar row
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 12, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: textPrimary),
                    onPressed: widget.onClose,
                  ),
                  Expanded(
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search, color: textMuted, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              focusNode: _focusNode,
                              onChanged: widget.onQueryChanged,
                              style: TextStyle(color: textPrimary, fontSize: 15),
                              decoration: InputDecoration(
                                hintText: 'Search in this chat…',
                                hintStyle: TextStyle(color: textMuted, fontSize: 14),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                          if (_controller.text.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _controller.clear();
                                widget.onQueryChanged('');
                                setState(() {});
                              },
                              child: Icon(Icons.close, color: textMuted, size: 18),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Result count
            if (_controller.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${widget.resultCount} ${widget.resultCount == 1 ? "result" : "results"}',
                  style: TextStyle(color: textMuted, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Highlights all occurrences of [query] within [text] using Kora purple.
class HighlightedText extends StatelessWidget {
  final String text;
  final String query;

  const HighlightedText({
    super.key,
    required this.text,
    required this.query,
  });

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) {
      return Text(text);
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final spans = <TextSpan>[];
    var start = 0;

    while (start < text.length) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }
      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: TextStyle(
          color: KoraColors.purple,
          fontWeight: FontWeight.w700,
          backgroundColor: KoraColors.purple.withValues(alpha: 0.15),
        ),
      ));
      start = index + query.length;
    }

    return RichText(
      text: TextSpan(
        style: DefaultTextStyle.of(context).style,
        children: spans,
      ),
    );
  }
}

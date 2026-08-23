import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import '../../services/ai_features_service.dart';

class AiReplySuggestions extends StatefulWidget {
  final String receivedMessage;
  final List<Map<String, dynamic>>? contextMessages;
  final Function(String) onSuggestionTap;
  final VoidCallback onDismiss;

  const AiReplySuggestions({
    super.key,
    required this.receivedMessage,
    this.contextMessages,
    required this.onSuggestionTap,
    required this.onDismiss,
  });

  @override
  State<AiReplySuggestions> createState() => _AiReplySuggestionsState();
}

class _AiReplySuggestionsState extends State<AiReplySuggestions> {
  List<String> _suggestions = [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  @override
  void didUpdateWidget(covariant AiReplySuggestions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.receivedMessage != widget.receivedMessage) {
      _loadSuggestions();
    }
  }

  Future<void> _loadSuggestions() async {
    if (widget.receivedMessage.trim().isEmpty) return;
    setState(() => _isLoading = true);
    final suggestions = await AiFeaturesService.instance.getReplySuggestions(
      widget.receivedMessage,
      contextMessages: widget.contextMessages,
    );
    if (mounted) {
      setState(() {
        _suggestions = suggestions;
        _isLoading = false;
        _hasLoaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasLoaded && _suggestions.isEmpty && !_isLoading) {
      return const SizedBox.shrink();
    }

    final brightness = Theme.of(context).brightness;
    final surface = KoraColors.surfaceFor(brightness);
    final cardColor = KoraColors.cardFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final border = KoraColors.borderFor(brightness);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: KoraColors.purple.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header / Collapsed Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: KoraColors.purple.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: KoraColors.purple,
                    size: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'AI Suggestions',
                  style: TextStyle(
                    color: KoraColors.purple,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_isLoading) ...[
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        KoraColors.purple,
                      ),
                    ),
                  ),
                ] else if (_suggestions.isNotEmpty && !_isExpanded) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: KoraColors.purple.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_suggestions.length}',
                      style: const TextStyle(
                        color: KoraColors.purple,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _isExpanded = !_isExpanded),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Icon(
                      _isExpanded
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_up,
                      color: textSecondary,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: widget.onDismiss,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Icon(
                      Icons.close,
                      color: textSecondary,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Expanded view with suggestion chips
          if (_isExpanded) ...[
            Divider(height: 1, color: border.withValues(alpha: 0.5)),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: _isLoading
                  ? Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'Generating reply suggestions...',
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _suggestions.take(3).map((suggestion) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InkWell(
                              onTap: () => widget.onSuggestionTap(suggestion),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: KoraColors.purple.withValues(alpha: 0.4),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      suggestion,
                                      style: TextStyle(
                                        color: textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(
                                      Icons.arrow_upward_rounded,
                                      color: KoraColors.purple,
                                      size: 14,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

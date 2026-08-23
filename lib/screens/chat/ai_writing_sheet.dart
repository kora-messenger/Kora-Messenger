import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import '../../services/ai_features_service.dart';

/// AI Writing Assistant bottom sheet.
///
/// Lets the user improve, rewrite, fix grammar, change tone,
/// translate, or adjust length of their message before sending.
/// The result is never sent automatically — the user reviews and decides.
class AiWritingSheet extends StatefulWidget {
  final String currentText;
  final Function(String) onApply;

  const AiWritingSheet({
    super.key,
    required this.currentText,
    required this.onApply,
  });

  static void show(
    BuildContext context,
    String currentText,
    Function(String) onApply,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          AiWritingSheet(currentText: currentText, onApply: onApply),
    );
  }

  @override
  State<AiWritingSheet> createState() => _AiWritingSheetState();
}

class _AiWritingSheetState extends State<AiWritingSheet> {
  late TextEditingController _textController;
  bool _isLoading = false;
  String? _result;
  AiWritingMode? _selectedMode;
  String? _error;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.currentText);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _process(AiWritingMode mode) async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _isLoading = true;
      _selectedMode = mode;
      _result = null;
      _error = null;
    });

    String? targetLanguage;
    if (mode == AiWritingMode.translate) {
      // Use the user's preferred language or default to French
      targetLanguage = 'fr';
    }

    final result =
        await AiFeaturesService.instance.rewriteText(text, mode,
            targetLanguage: targetLanguage);

    if (mounted) {
      if (result != null && result.isNotEmpty) {
        setState(() {
          _result = result;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Could not process. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  void _applyResult() {
    if (_result != null && _result!.isNotEmpty) {
      widget.onApply(_result!);
      Navigator.pop(context);
    }
  }

  void _useAsBase() {
    if (_result != null) {
      setState(() {
        _textController.text = _result!;
        _result = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Container(
      height: screenHeight * 0.85,
      decoration: BoxDecoration(
        color: KoraColors.trueBlack,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(
            color: KoraColors.purple.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTextField(),
                  const SizedBox(height: 16),
                  _buildModeGrid(),
                  if (_isLoading) _buildLoadingState(),
                  if (_result != null) ...[
                    const SizedBox(height: 16),
                    _buildResultCard(),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    _buildErrorState(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [KoraColors.purple, KoraColors.blue],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'AI Writing Assistant',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField() {
    return Container(
      decoration: BoxDecoration(
        color: KoraColors.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KoraColors.borderFor(Brightness.dark)),
      ),
      child: TextField(
        controller: _textController,
        maxLines: 4,
        minLines: 2,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          hintText: 'Type or edit your message...',
          hintStyle: TextStyle(color: KoraColors.hintFor(Brightness.dark)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(14),
        ),
      ),
    );
  }

  Widget _buildModeGrid() {
    final modes = AiWritingMode.values;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: modes.map((mode) {
        final isSelected = _selectedMode == mode && _isLoading;
        return GestureDetector(
          onTap: _isLoading ? null : () => _process(mode),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(
                      colors: [KoraColors.purple, KoraColors.blue],
                    )
                  : null,
              color: isSelected ? null : KoraColors.darkCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? Colors.transparent
                    : KoraColors.borderFor(Brightness.dark),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(mode.emoji, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(
                  mode.label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : KoraColors.purple,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Center(
        child: Column(
          children: [
            const CircularProgressIndicator(color: KoraColors.purple, strokeWidth: 2),
            const SizedBox(height: 12),
            Text(
              '${_selectedMode?.emoji ?? ''} ${_selectedMode?.label ?? 'Processing'}...',
              style: TextStyle(
                color: KoraColors.textSecondaryFor(Brightness.dark),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: KoraColors.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: KoraColors.purple.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: KoraColors.purple, size: 16),
              const SizedBox(width: 6),
              Text(
                'AI Result',
                style: TextStyle(
                  color: KoraColors.purple,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _result!,
            style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _useAsBase,
                  style: TextButton.styleFrom(
                    foregroundColor: KoraColors.purple,
                  ),
                  child: const Text('Use as base'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: _applyResult,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [KoraColors.purple, KoraColors.blue],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'Send',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: KoraColors.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 24),
          const SizedBox(height: 8),
          Text(
            _error!,
            style: TextStyle(
              color: KoraColors.textSecondaryFor(Brightness.dark),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              if (_selectedMode != null) _process(_selectedMode!);
            },
            child: const Text('Retry', style: TextStyle(color: KoraColors.purple)),
          ),
        ],
      ),
    );
  }
}

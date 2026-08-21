import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/kora_colors.dart';
import '../../services/translation_service.dart';
import '../../models/translation_models.dart';
import '../../services/connectivity_service.dart';
import 'language_picker_screen.dart';

/// Kora's text translation bottom sheet.
///
/// Shows original message + translated text. Supports:
/// - Language switching (retranslates to new language)
/// - Show/hide original toggle
/// - Copy translated text
/// - Loading states ("Translating...")
/// - Offline error handling
/// - Auto-detected source language display
///
/// Designed to feel native to Kora — uses Kora colors, typography,
/// icons, and rounded surfaces throughout.
class TranslateSheet extends StatefulWidget {
  final String originalText;

  const TranslateSheet({
    super.key,
    required this.originalText,
  });

  static void show(BuildContext context, String text) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TranslateSheet(originalText: text),
    );
  }

  @override
  State<TranslateSheet> createState() => _TranslateSheetState();
}

class _TranslateSheetState extends State<TranslateSheet>
    with SingleTickerProviderStateMixin {
  final _translationService = TranslationService.instance;

  KoraLanguage? _targetLanguage;
  TranslationResult? _result;
  bool _isTranslating = true;
  bool _showOriginal = true;
  bool _hasError = false;
  String _errorMsg = '';
  late AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _targetLanguage = _translationService.preferredLanguage;
    _showOriginal = _translationService.showOriginal;

    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _doTranslate();
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  Future<void> _doTranslate() async {
    setState(() {
      _isTranslating = true;
      _hasError = false;
      _errorMsg = '';
    });

    // Check connectivity
    final isOnline = ConnectivityService.instance.isOnline;
    if (!isOnline) {
      setState(() {
        _isTranslating = false;
        _hasError = true;
        _errorMsg = 'No internet connection. Translation requires network access.';
      });
      return;
    }

    if (_spinController.isAnimating) {
      _spinController.repeat();
    } else {
      _spinController.repeat();
    }

    try {
      final result = await _translationService.translate(
        widget.originalText,
        _targetLanguage!.code,
      );
      if (mounted) {
        setState(() {
          _result = result;
          _isTranslating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTranslating = false;
          _hasError = true;
          _errorMsg = 'We couldn\'t translate this message right now. Please try again.';
        });
      }
    } finally {
      _spinController.stop();
    }
  }

  void _changeLanguage() async {
    final result = await Navigator.push<KoraLanguage>(
      context,
      MaterialPageRoute(
        builder: (_) => LanguagePickerScreen(
          selectedCode: _targetLanguage?.code,
          title: 'Translate to',
        ),
      ),
    );
    if (result != null && result.code != _targetLanguage?.code) {
      setState(() => _targetLanguage = result);
      _doTranslate();
    }
  }

  void _copyTranslation() {
    final text = _result?.translatedText ?? '';
    if (text.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: text));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Translation copied'),
          backgroundColor: KoraColors.purple,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final card = KoraColors.cardFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);
    final border = KoraColors.borderFor(brightness);

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.72,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Handle ──
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
              child: Row(
                children: [
                  Icon(Icons.translate_rounded, color: KoraColors.purple, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Translate',
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

            // ── Language selector row ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  // Detected language badge
                  if (_result != null && !_isTranslating) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: KoraColors.purple.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.travel_explore_rounded, size: 14, color: KoraColors.purple),
                          const SizedBox(width: 4),
                          Text(
                            _result!.detectedLanguageName,
                            style: TextStyle(
                              color: KoraColors.purple,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 16, color: textMuted),
                    const SizedBox(width: 8),
                  ],
                  // Target language selector
                  GestureDetector(
                    onTap: _changeLanguage,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: border, width: 0.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_targetLanguage?.flag ?? '', style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                          Text(
                            _targetLanguage?.name ?? 'Select',
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: textMuted),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Show original toggle
                  GestureDetector(
                    onTap: () {
                      setState(() => _showOriginal = !_showOriginal);
                      _translationService.setShowOriginal(_showOriginal);
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _showOriginal ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                          size: 16,
                          color: textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _showOriginal ? 'Original' : 'Hide',
                          style: TextStyle(
                            color: textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Content ──
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Original text
                    if (_showOriginal) ...[
                      _buildLabel('Original', textMuted),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.originalText,
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 15,
                            height: 1.45,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Translated text or loading or error
                    _buildLabel(
                      _isTranslating
                          ? 'Translating...'
                          : _hasError
                              ? 'Error'
                              : '${_targetLanguage?.name ?? ''} Translation',
                      textMuted,
                    ),
                    const SizedBox(height: 6),
                    if (_isTranslating)
                      _buildLoadingCard(surface, textSecondary)
                    else if (_hasError)
                      _buildErrorCard(surface, textSecondary)
                    else ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: KoraColors.purple.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: KoraColors.purple.withValues(alpha: 0.15),
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          _result?.translatedText ?? '',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 15,
                            height: 1.45,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      // Action row
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildAction(
                            Icons.copy_rounded,
                            'Copy',
                            _copyTranslation,
                            textSecondary,
                          ),
                          const SizedBox(width: 16),
                          _buildAction(
                            Icons.language_rounded,
                            'Change language',
                            _changeLanguage,
                            textSecondary,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String label, Color color) {
    return Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildLoadingCard(Color surface, Color textSecondary) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: KoraColors.purple.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Translating...',
            style: TextStyle(
              color: textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(Color surface, Color textSecondary) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline_rounded, size: 18, color: KoraColors.red),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _errorMsg,
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _doTranslate,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh_rounded, size: 16, color: KoraColors.purple),
                const SizedBox(width: 4),
                Text(
                  'Try again',
                  style: TextStyle(
                    color: KoraColors.purple,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAction(IconData icon, String label, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

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
/// - Free choice of BOTH source and target language (not just auto-detect)
/// - Swap button — instantly flips source ⇄ target (and their text)
/// - Refresh — re-runs translation against the backend
/// - Show/hide original toggle
/// - Copy translated text
/// - Loading states ("Translating...")
/// - Offline error handling
/// - Auto-detected source language shown by default until changed
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

  // The text currently shown as "original" — mutable so swap can flip it
  // with the translated text, just like a real two-way translator.
  late String _displayOriginalText;

  KoraLanguage? _sourceLanguage; // null until auto-detected or user-picked
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
    _displayOriginalText = widget.originalText;
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

    _spinController.repeat();

    try {
      final result = await _translationService.translate(
        _displayOriginalText,
        _targetLanguage!.code,
        // Once the source language is known (auto-detected or user-picked),
        // always pass it explicitly so the user's own choice of source is
        // respected instead of re-detecting every time.
        sourceLanguageCode: _sourceLanguage?.code,
      );
      if (mounted) {
        setState(() {
          _result = result;
          _isTranslating = false;
          // Populate the source chip from detection the first time.
          _sourceLanguage ??= _translationService.languageByCode(
            result.detectedLanguageCode,
          );
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

  /// Manual refresh — re-runs translation with the current language pair.
  void _refreshTranslate() {
    HapticFeedback.selectionClick();
    _doTranslate();
  }

  void _changeSourceLanguage() async {
    final result = await Navigator.push<KoraLanguage>(
      context,
      MaterialPageRoute(
        builder: (_) => LanguagePickerScreen(
          selectedCode: _sourceLanguage?.code,
          title: 'Translate from',
        ),
      ),
    );
    if (result != null && result.code != _sourceLanguage?.code) {
      setState(() => _sourceLanguage = result);
      _doTranslate();
    }
  }

  void _changeTargetLanguage() async {
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

  /// Swaps the source and target sides — e.g. "English > German" becomes
  /// "German > English" — flipping both the selected languages AND which
  /// text block is shown as "original" vs "translation", exactly like a
  /// standard two-way translator swap button.
  void _swapLanguages() {
    if (_sourceLanguage == null || _isTranslating) return;

    HapticFeedback.mediumImpact();

    final oldSource = _sourceLanguage!;
    final oldTarget = _targetLanguage!;
    final oldOriginalText = _displayOriginalText;
    final oldTranslatedText = _result?.translatedText ?? '';

    setState(() {
      _sourceLanguage = oldTarget;
      _targetLanguage = oldSource;
      _displayOriginalText = oldTranslatedText.isNotEmpty ? oldTranslatedText : oldOriginalText;

      if (_result != null) {
        _result = TranslationResult(
          originalText: _displayOriginalText,
          translatedText: oldOriginalText,
          detectedLanguageCode: oldTarget.code,
          detectedLanguageName: oldTarget.name,
          targetLanguageCode: oldSource.code,
          targetLanguageName: oldSource.name,
          translatedAt: DateTime.now(),
        );
      }
    });

    _translationService.addRecentLanguage(oldSource.code);
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
          maxHeight: MediaQuery.of(context).size.height * 0.76,
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
                  // Refresh — re-runs the translation
                  IconButton(
                    icon: RotationTransition(
                      turns: _spinController,
                      child: Icon(Icons.refresh_rounded, color: textMuted, size: 20),
                    ),
                    onPressed: _isTranslating ? null : _refreshTranslate,
                    tooltip: 'Refresh translation',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
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

            // ── Language selector row: Source ⇄ Target ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(
                children: [
                  // Source language chip — freely selectable, not locked to
                  // auto-detection.
                  Expanded(
                    child: _buildLangChip(
                      language: _sourceLanguage,
                      placeholder: 'Detecting...',
                      onTap: _changeSourceLanguage,
                      surface: surface,
                      textPrimary: textPrimary,
                      textMuted: textMuted,
                      border: border,
                      isAutoDetected: _sourceLanguage != null &&
                          _result != null &&
                          _sourceLanguage!.code == _result!.detectedLanguageCode,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Swap button — flips source ⇄ target
                  GestureDetector(
                    onTap: _swapLanguages,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: KoraColors.purple.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.swap_horiz_rounded,
                        size: 18,
                        color: KoraColors.purple,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Target language chip
                  Expanded(
                    child: _buildLangChip(
                      language: _targetLanguage,
                      placeholder: 'Select',
                      onTap: _changeTargetLanguage,
                      surface: surface,
                      textPrimary: textPrimary,
                      textMuted: textMuted,
                      border: border,
                      isAutoDetected: false,
                    ),
                  ),
                ],
              ),
            ),

            // ── Show original toggle ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
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
                          _displayOriginalText,
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
                            Icons.refresh_rounded,
                            'Refresh',
                            _refreshTranslate,
                            textSecondary,
                          ),
                          const SizedBox(width: 16),
                          _buildAction(
                            Icons.swap_horiz_rounded,
                            'Swap',
                            _swapLanguages,
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

  Widget _buildLangChip({
    required KoraLanguage? language,
    required String placeholder,
    required VoidCallback onTap,
    required Color surface,
    required Color textPrimary,
    required Color textMuted,
    required Color border,
    required bool isAutoDetected,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(language?.flag ?? '🌐', style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    language?.name ?? placeholder,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (isAutoDetected)
                    Text(
                      'Detected',
                      style: TextStyle(
                        color: KoraColors.purple.withValues(alpha: 0.8),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: textMuted),
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

import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';

/// Kora's translation panel — slides up when a user taps "Translate"
/// on a message. Shows the original text and a translated version.
/// Designed to feel native to Kora, not a third-party translate popup.
class TranslateSheet extends StatefulWidget {
  final String originalText;
  final String detectedLanguage;

  const TranslateSheet({
    super.key,
    required this.originalText,
    this.detectedLanguage = 'Auto',
  });

  static void show(BuildContext context, String text, {String language = 'Auto'}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TranslateSheet(originalText: text, detectedLanguage: language),
    );
  }

  @override
  State<TranslateSheet> createState() => _TranslateSheetState();
}

class _TranslateSheetState extends State<TranslateSheet> {
  String _targetLang = 'French';
  bool _isTranslating = true;
  String? _translated;

  // Mock translations — replace with real API later.
  static const _mockTranslations = {
    'French': 'Bienvenue sur Kora Messenger ! 👋',
    'Spanish': '¡Bienvenido a Kora Messenger! 👋',
    'German': 'Willkommen bei Kora Messenger! 👋',
    'Portuguese': 'Bem-vindo ao Kora Messenger! 👋',
    'Arabic': 'مرحبًا بك في كورا ماسنجر! 👋',
    'Hausa': 'Barka da zuwa Kora Messenger! 👋',
    'Swahili': 'Karibu kwenye Kora Messenger! 👋',
  };

  @override
  void initState() {
    super.initState();
    _doTranslate();
  }

  void _doTranslate() {
    setState(() => _isTranslating = true);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _translated = _mockTranslations[_targetLang] ?? 'Translation unavailable';
          _isTranslating = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final card = KoraColors.cardFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);

    final languages = _mockTranslations.keys.toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.8,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: textMuted.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    Icon(Icons.translate, color: KoraColors.purple, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Translate',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Icon(Icons.close, color: textSecondary, size: 22),
                    ),
                  ],
                ),
              ),
              // Language selector
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: languages.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final lang = languages[index];
                      final isSelected = lang == _targetLang;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _targetLang = lang);
                          _doTranslate();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? KoraColors.purple.withValues(alpha: 0.12)
                                : KoraColors.surfaceFor(brightness),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? KoraColors.purple : Colors.transparent,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            lang,
                            style: TextStyle(
                              color: isSelected ? KoraColors.purple : textSecondary,
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Original text
              _section(context, 'Original', widget.originalText, textPrimary, textMuted),
              const SizedBox(height: 12),
              // Translated text
              _section(
                context,
                '$_targetLang Translation',
                _isTranslating ? 'Translating…' : (_translated ?? ''),
                _isTranslating ? textMuted : KoraColors.purple,
                textMuted,
                isLoading: _isTranslating,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _section(
    BuildContext context,
    String label,
    String text,
    Color textColor,
    Color labelColor, {
    bool isLoading = false,
  }) {
    final brightness = Theme.of(context).brightness;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: labelColor,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: KoraColors.surfaceFor(brightness),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                if (isLoading) ...[
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: KoraColors.purple,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

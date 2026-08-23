import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import '../../services/translation_service.dart';
import '../../models/translation_models.dart';

/// Kora's language picker — full-screen searchable language selection.
///
/// Features:
/// - Search bar (by name, code, or native name)
/// - Recently used languages row
/// - Currently selected language highlighted
/// - Full alphabetical language list
/// - Clean Kora design language
class LanguagePickerScreen extends StatefulWidget {
  final String? selectedCode;
  final String title;

  const LanguagePickerScreen({
    super.key,
    this.selectedCode,
    this.title = 'Select Language',
  });

  @override
  State<LanguagePickerScreen> createState() => _LanguagePickerScreenState();
}

class _LanguagePickerScreenState extends State<LanguagePickerScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  List<KoraLanguage> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = TranslationService.instance.allLanguages;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    setState(() {
      _query = query;
      _filtered = TranslationService.instance.searchLanguages(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final card = KoraColors.cardFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);
    final border = KoraColors.borderFor(brightness);

    final recent = TranslationService.instance.recentLanguages;
    final preferred = TranslationService.instance.preferredLanguage;

    // Languages already shown under Preferred / Recently Used should not
    // also appear again in the All Languages / Results list below.
    final excludedCodes = <String>{
      preferred.code,
      ...recent.map((l) => l.code),
    };
    // Only hide duplicates from the default "All Languages" view — while
    // actively searching, show every match so users can still find and
    // re-select a language that's already Preferred/Recent.
    final visibleLanguages = _query.isEmpty
        ? _filtered.where((l) => !excludedCodes.contains(l.code)).toList()
        : _filtered;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: card,
        elevation: 0,
        title: Text(
          widget.title,
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearch,
              autofocus: false,
              decoration: InputDecoration(
                hintText: 'Search languages...',
                hintStyle: TextStyle(color: textMuted, fontSize: 14),
                prefixIcon: Icon(Icons.search_rounded, color: textMuted, size: 20),
                filled: true,
                fillColor: KoraColors.surfaceFor(brightness),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              style: TextStyle(color: textPrimary, fontSize: 14),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ── Preferred language ──
          if (_query.isEmpty) ...[
            _buildSectionHeader('PREFERRED', textMuted),
            _buildLanguageTile(
              context,
              preferred,
              isPreferred: true,
              card: card,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              textMuted: textMuted,
              border: border,
            ),
          ],

          // ── Recent ──
          if (_query.isEmpty && recent.isNotEmpty) ...[
            _buildSectionHeader('RECENTLY USED', textMuted),
            ...recent.map((lang) => _buildLanguageTile(
                  context,
                  lang,
                  card: card,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  textMuted: textMuted,
                  border: border,
                )),
          ],

          // ── All languages (excludes anything already listed above) ──
          if (visibleLanguages.isNotEmpty) ...[
            _buildSectionHeader(
              _query.isEmpty ? 'ALL LANGUAGES' : 'RESULTS (${visibleLanguages.length})',
              textMuted,
            ),
            ...visibleLanguages.map((lang) => _buildLanguageTile(
                  context,
                  lang,
                  card: card,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  textMuted: textMuted,
                  border: border,
                )),
          ],

          if (_filtered.isEmpty && _query.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(Icons.language_rounded, size: 48, color: textMuted),
                  const SizedBox(height: 12),
                  Text(
                    'No languages found',
                    style: TextStyle(color: textSecondary, fontSize: 14),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String label, Color color) {
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

  Widget _buildLanguageTile(
    BuildContext context,
    KoraLanguage lang, {
    bool isPreferred = false,
    required Color card,
    required Color textPrimary,
    required Color textSecondary,
    required Color textMuted,
    required Color border,
  }) {
    final isSelected = lang.code == widget.selectedCode;

    return InkWell(
      onTap: () {
        TranslationService.instance.addRecentLanguage(lang.code);
        Navigator.pop(context, lang);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? KoraColors.purple.withValues(alpha: 0.06) : Colors.transparent,
          border: Border(
            bottom: BorderSide(color: border, width: 0.3),
          ),
        ),
        child: Row(
          children: [
            // Flag
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: KoraColors.surfaceFor(Theme.of(context).brightness),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(lang.flag, style: const TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(width: 14),
            // Name + native name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        lang.name,
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (isPreferred) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: KoraColors.purple.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Default',
                            style: TextStyle(
                              color: KoraColors.purple,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (lang.nativeName != lang.name)
                    Text(
                      lang.nativeName,
                      style: TextStyle(color: textMuted, fontSize: 12.5),
                    ),
                ],
              ),
            ),
            // Checkmark if selected
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: KoraColors.purple, size: 22),
          ],
        ),
      ),
    );
  }
}

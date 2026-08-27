import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import '../../services/translation_service.dart';
import '../../models/translation_models.dart';
import '../chat/language_picker_screen.dart';
import 'premium_subscribe_sheet.dart';
import 'voice_studio_screen.dart';
import '../../theme/chat_theme_provider.dart';

/// Kora's Translation settings — accessible from Settings > Translation.
///
/// Options:
/// - Preferred Translation Language
/// - Automatic Translation (Off / Ask / Automatically translate)
/// - Translate Voice Notes (on/off)
/// - Show Original Text (on/off)
/// - Live Call Translation (on/off)
/// - Call Translation Mode
/// - Caption Size
/// - Translation History (clear)
class TranslationSettingsScreen extends StatefulWidget {
  const TranslationSettingsScreen({super.key});

  @override
  State<TranslationSettingsScreen> createState() =>
      _TranslationSettingsScreenState();
}

class _TranslationSettingsScreenState extends State<TranslationSettingsScreen> {
  final _service = TranslationService.instance;
  bool _isLoadingPremium = false;
  late AutoTranslateMode _autoMode;
  late bool _translateVoice;
  late bool _showOriginal;
  late bool _callTranslation;
  late double _captionSize;

  @override
  void initState() {
    super.initState();
    _autoMode = _service.autoTranslateMode;
    _translateVoice = _service.translateVoice;
    _showOriginal = _service.showOriginal;
    _callTranslation = _service.callTranslationEnabled;
    _captionSize = _service.captionSize;

    _service.settingsStream.listen((_) {
      if (mounted) setState(() {});
    });
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

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final card = KoraColors.cardFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);
    final border = KoraColors.borderFor(brightness);

    final preferred = _service.preferredLanguage;
    final isPremium = ChatThemeProvider.instance.isPremium;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: card,
        elevation: 0,
        title: Text(
          'Translation',
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
      ),
      body: isPremium
          ? ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ── PREFERRED LANGUAGE ──
          _sectionLabel('PREFERRED LANGUAGE', textMuted),
          _navTile(
            card: card,
            border: border,
            icon: Icons.language_rounded,
            iconBg: KoraColors.purple.withValues(alpha: 0.1),
            title: 'Translation Language',
            subtitle: '${preferred.flag} ${preferred.name}',
            trailing: Icon(Icons.chevron_right, color: textMuted),
            onTap: () async {
              final result = await Navigator.push<KoraLanguage>(
                context,
                MaterialPageRoute(
                  builder: (_) => LanguagePickerScreen(
                    selectedCode: _service.preferredLanguageCode,
                    title: 'Preferred Translation Language',
                    // Keep this screen's original full list — a language
                    // already shown under Preferred/Recently Used still
                    // also appears in All Languages here (unlike the
                    // Translate to/from pickers, which de-duplicate).
                    hideDuplicatesInAllLanguages: false,
                  ),
                ),
              );
              if (result != null) {
                _service.setPreferredLanguage(result.code);
                setState(() {});
              }
            },
          ),

          const SizedBox(height: 20),

          // ── AUTOMATIC TRANSLATION ──
          _sectionLabel('AUTOMATIC TRANSLATION', textMuted),
          _cardGroup(
            card: card,
            border: border,
            children: [
              _autoModeTile(
                'Off',
                'Messages are not translated automatically',
                _autoMode == AutoTranslateMode.off,
                () => _setAutoMode(AutoTranslateMode.off),
              ),
              _divider(border),
              _autoModeTile(
                'Ask before translating',
                'Kora detects a different language and asks if you want to translate',
                _autoMode == AutoTranslateMode.ask,
                () => _setAutoMode(AutoTranslateMode.ask),
              ),
              _divider(border),
              _autoModeTile(
                'Automatically translate',
                'Messages are translated automatically when a different language is detected',
                _autoMode == AutoTranslateMode.automatic,
                () => _setAutoMode(AutoTranslateMode.automatic),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── VOICE ──
          _sectionLabel('VOICE', textMuted),
          _cardGroup(
            card: card,
            border: border,
            children: [
              _switchTile(
                card: card,
                icon: Icons.mic_rounded,
                iconBg: KoraColors.purple.withValues(alpha: 0.1),
                title: 'Translate Voice Notes',
                subtitle: 'Allow transcription and translation of voice messages',
                value: _translateVoice,
                onChanged: (v) {
                  _service.setTranslateVoice(v);
                  setState(() => _translateVoice = v);
                },
              ),
              _navTile(
                card: card,
                icon: Icons.graphic_eq_rounded,
                iconBg: KoraColors.purple.withValues(alpha: 0.1),
                title: 'Voice Studio',
                subtitle: 'Create and manage custom voices for translation',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const VoiceStudioScreen()),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── DISPLAY ──
          _sectionLabel('DISPLAY', textMuted),
          _cardGroup(
            card: card,
            border: border,
            children: [
              _switchTile(
                card: card,
                icon: Icons.visibility_rounded,
                iconBg: KoraColors.purple.withValues(alpha: 0.1),
                title: 'Show Original Text',
                subtitle: 'Keep the original message visible when translated',
                value: _showOriginal,
                onChanged: (v) {
                  _service.setShowOriginal(v);
                  setState(() => _showOriginal = v);
                },
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── CALL TRANSLATION ──
          _sectionLabel('LIVE CALL TRANSLATION', textMuted),
          _cardGroup(
            card: card,
            border: border,
            children: [
              _switchTile(
                card: card,
                icon: Icons.phone_in_talk_rounded,
                iconBg: KoraColors.purple.withValues(alpha: 0.1),
                title: 'Live Call Translation',
                subtitle: 'Enable real-time translation during calls',
                value: _callTranslation,
                onChanged: (v) {
                  _service.setCallTranslationEnabled(v);
                  setState(() => _callTranslation = v);
                },
              ),
              if (_callTranslation) ...[
                _divider(border),
                _sliderTile(
                  icon: Icons.text_fields_rounded,
                  title: 'Caption Size',
                  value: _captionSize,
                  onChanged: (v) {
                    _service.setCaptionSize(v);
                    setState(() => _captionSize = v);
                  },
                ),
              ],
            ],
          ),

          const SizedBox(height: 20),

          // ── PRIVACY ──
          _sectionLabel('PRIVACY', textMuted),
          _cardGroup(
            card: card,
            border: border,
            children: [
              _navTile(
                card: card,
                border: null,
                icon: Icons.delete_outline_rounded,
                iconBg: KoraColors.red.withValues(alpha: 0.1),
                title: 'Clear Translation History',
                subtitle: 'Remove all stored translation data',
                trailing: Icon(Icons.chevron_right, color: textMuted),
                onTap: () => _showClearDialog(context),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Info note ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: KoraColors.purple.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: KoraColors.purple.withValues(alpha: 0.12),
                  width: 0.5,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, size: 18, color: KoraColors.purple),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Kora translates messages using AI. Original messages are never modified — '
                      'translations are generated on demand and stored only for your viewing. '
                      'Voice notes are transcribed and translated without altering the original audio.',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 12.5,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      )
          : _buildPremiumLock(card, border, textPrimary, textSecondary),
    );
  }

  Widget _buildPremiumLock(Color card, Color border, Color textPrimary, Color textSecondary) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.translate_rounded, color: KoraColors.purple, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Real-Time Translation is a Kora Premium feature',
              textAlign: TextAlign.center,
              style: TextStyle(color: KoraColors.purple, fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Translate messages, voice notes, and live calls in real-time. Upgrade to unlock all translation features.',
              textAlign: TextAlign.center,
              style: TextStyle(color: textSecondary, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: KoraColors.purple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: _isLoadingPremium
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.workspace_premium, size: 20),
                label: Text(_isLoadingPremium ? 'Loading...' : 'Get Kora Premium'),
                onPressed: _isLoadingPremium ? null : _showPremiumSheet,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _setAutoMode(AutoTranslateMode mode) {
    _service.setAutoTranslateMode(mode);
    setState(() => _autoMode = mode);
  }

  void _showClearDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KoraColors.cardFor(Theme.of(context).brightness),
        title: Text(
          'Clear Translation History',
          style: TextStyle(
            color: KoraColors.textPrimaryFor(Theme.of(context).brightness),
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'This will remove all stored translations. Original messages are not affected.',
          style: TextStyle(
            color: KoraColors.textSecondaryFor(Theme.of(context).brightness),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: KoraColors.purple)),
          ),
          TextButton(
            onPressed: () {
              _service.clearHistory();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Translation history cleared'),
                  backgroundColor: KoraColors.purple,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Clear', style: TextStyle(color: KoraColors.red)),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──

  Widget _sectionLabel(String label, Color color) {
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

  Widget _cardGroup({
    required Color card,
    required Color border,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: 0.3),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  Widget _divider(Color border) {
    return Padding(
      padding: const EdgeInsets.only(left: 64),
      child: Divider(height: 0.5, color: border, thickness: 0.5),
    );
  }

  Widget _navTile({
    required Color card,
    required Color? border,
    required IconData icon,
    required Color iconBg,
    required String title,
    required String subtitle,
    required Widget trailing,
    required VoidCallback onTap,
  }) {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: KoraColors.purple, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: TextStyle(color: textSecondary, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );
  }

  Widget _autoModeTile(String title, String subtitle, bool isSelected, VoidCallback onTap) {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: 20,
              color: isSelected ? KoraColors.purple : Colors.grey.shade600,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 14.5,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _switchTile({
    required Color card,
    required IconData icon,
    required Color iconBg,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: KoraColors.purple, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: TextStyle(color: textSecondary, fontSize: 12.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: KoraColors.purple,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  Widget _sliderTile({
    required IconData icon,
    required String title,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: KoraColors.purple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: KoraColors.purple, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Slider(
                  value: value,
                  min: 10,
                  max: 24,
                  divisions: 14,
                  thumbColor: KoraColors.purple,
                  onChanged: onChanged,
                  label: '${value.round()}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/kora_colors.dart';

/// App language settings — mirrors WhatsApp's Settings > App language.
/// Shows a list of available languages. Selection is persisted to
/// SharedPreferences and reflected immediately.
class AppLanguageScreen extends StatefulWidget {
  const AppLanguageScreen({super.key});

  @override
  State<AppLanguageScreen> createState() => _AppLanguageScreenState();
}

class _AppLanguageScreenState extends State<AppLanguageScreen> {
  String _selected = 'en';
  bool _loading = true;

  static const _languages = [
    ('en', 'English', 'English'),
    ('es', 'Español', 'Spanish'),
    ('fr', 'Français', 'French'),
    ('pt', 'Português', 'Portuguese'),
    ('de', 'Deutsch', 'German'),
    ('it', 'Italiano', 'Italian'),
    ('hi', 'हिन्दी', 'Hindi'),
    ('sw', 'Kiswahili', 'Swahili'),
    ('ha', 'Hausa', 'Hausa'),
    ('yo', 'Yorùbá', 'Yoruba'),
    ('ig', 'Igbo', 'Igbo'),
    ('ar', 'العربية', 'Arabic'),
    ('zh', '中文', 'Chinese'),
    ('ja', '日本語', 'Japanese'),
  ];

  @override
  void initState() {
    super.initState();
    _loadPref();
  }

  Future<void> _loadPref() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _selected = prefs.getString('app_language') ?? 'en';
        _loading = false;
      });
    }
  }

  Future<void> _select(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', code);
    if (mounted) setState(() => _selected = code);
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

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text('App language',
            style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: KoraColors.purple))
          : SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Text(
                      'Select your preferred language for Kora Messenger. '
                      'This will affect the app interface language.',
                      style: TextStyle(color: textSecondary, fontSize: 13),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _languages.length,
                      itemBuilder: (ctx, i) {
                        final (code, nativeName, englishName) = _languages[i];
                        final isSelected = code == _selected;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: card,
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected
                                ? Border.all(color: KoraColors.purple, width: 1.5)
                                : null,
                          ),
                          child: ListTile(
                            title: Text(nativeName,
                                style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w500)),
                            subtitle: englishName != nativeName
                                ? Text(englishName, style: TextStyle(color: textMuted, fontSize: 12))
                                : null,
                            trailing: isSelected
                                ? Icon(Icons.check_circle, color: KoraColors.purple, size: 22)
                                : Icon(Icons.radio_button_unchecked, color: textMuted, size: 22),
                            onTap: () => _select(code),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: KoraColors.purple.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: KoraColors.purple, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Full app language localization is coming soon. '
                            'Your selection is saved and will apply automatically when available.',
                            style: TextStyle(color: textSecondary, fontSize: 12.5, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }
}

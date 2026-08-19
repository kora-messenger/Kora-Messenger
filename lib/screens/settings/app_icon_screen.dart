import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import '../../theme/chat_theme_provider.dart';
import 'premium_subscribe_sheet.dart';
import 'billing_screen.dart';
import '../../services/app_icon_switcher.dart';

/// A single Kora app icon option — either a gradient swatch or a real
/// asset image. Public so other screens (e.g. Appearance) can render
/// a matching preview thumbnail of the currently-selected icon.
class KoraIconDef {
  final String name;
  final List<Color>? gradient;
  final String? assetPath;
  const KoraIconDef({
    required this.name,
    this.gradient,
    this.assetPath,
  });
}

/// 12 Kora app icon definitions.
/// Icons 0-9 use gradient previews; icons 10-11 use real asset images.
const List<KoraIconDef> kKoraIconDefs = [
  KoraIconDef(name: 'Classic',   gradient: [Color(0xFF8B5CF6), Color(0xFF3B82F6)]),
  KoraIconDef(name: 'Sunset',     gradient: [Color(0xFFEF4444), Color(0xFFF59E0B)]),
  KoraIconDef(name: 'Emerald',    gradient: [Color(0xFF10B981), Color(0xFF06B6D4)]),
  KoraIconDef(name: 'Midnight',   gradient: [Color(0xFF1E1B4B), Color(0xFF4338CA)]),
  KoraIconDef(name: 'Rose Gold',  gradient: [Color(0xFFF472B6), Color(0xFFFB923C)]),
  KoraIconDef(name: 'Ocean',      gradient: [Color(0xFF0EA5E9), Color(0xFF6366F1)]),
  KoraIconDef(name: 'Forest',     gradient: [Color(0xFF059669), Color(0xFF0D9488)]),
  KoraIconDef(name: 'Crimson',    gradient: [Color(0xFFDC2626), Color(0xFF7C3AED)]),
  KoraIconDef(name: 'Aurora',     gradient: [Color(0xFFA855F7), Color(0xFF2DD4BF)]),
  KoraIconDef(name: 'Carbon',     gradient: [Color(0xFF374151), Color(0xFF111827)]),
  KoraIconDef(name: 'Nebula',     assetPath: 'assets/icons/icon_nebula.png'),
  KoraIconDef(name: 'Galaxy',     assetPath: 'assets/icons/icon_galaxy.png'),
];

/// App Icon picker — 12 Kora app icons. Premium only.
///
/// Non-premium users can see all icons but the grid is
/// read-only. A "Get Kora Premium" button appears at the
/// bottom instead of the Apply button.
class AppIconScreen extends StatefulWidget {
  const AppIconScreen({super.key});

  @override
  State<AppIconScreen> createState() => _AppIconScreenState();
}

class _AppIconScreenState extends State<AppIconScreen> {
  final _provider = ChatThemeProvider.instance;
  int _selectedIcon = 0;
  bool _isApplying = false;

  @override
  void initState() {
    super.initState();
    _selectedIcon = _provider.appIconIndex;
    _provider.addListener(_onChanged);
  }

  @override
  void dispose() {
    _provider.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  // 12 Kora app icon definitions live in the top-level `kKoraIconDefs`
  // list below so the Appearance screen can render a matching preview.
  static const List<KoraIconDef> _icons = kKoraIconDefs;

  void _selectIcon(int index) {
    if (!_provider.isPremium) return;
    setState(() => _selectedIcon = index);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_icons[index].name} icon selected'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: KoraColors.darkCard,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _applyIcon() async {
    if (_isApplying) return;
    setState(() => _isApplying = true);

    // Persist selection
    await _provider.setAppIcon(_selectedIcon);

    // Attempt to change the actual app icon
    final success = await AppIconSwitcher.setIcon(_selectedIcon);

    if (mounted) {
      setState(() => _isApplying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? '${_icons[_selectedIcon].name} icon set! The app icon will update shortly.'
                : '${_icons[_selectedIcon].name} icon saved. Restart the app to see the change.',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: KoraColors.darkCard,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showPremiumSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (context) => const PremiumSubscribeSheet(),
    ).then((result) {
      if (result == true && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BillingScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final border = KoraColors.borderFor(brightness);
    final card = KoraColors.cardFor(brightness);
    final isPremium = _provider.isPremium;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          'App Icon',
          style: TextStyle(
            color: textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Icon grid ──
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.82,
                ),
                itemCount: _icons.length,
                itemBuilder: (context, index) {
                  final icon = _icons[index];
                  final isSelected = index == _selectedIcon;
                  return GestureDetector(
                    onTap: () => _selectIcon(index),
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                border: isSelected
                                    ? Border.all(color: KoraColors.purple, width: 3)
                                    : Border.all(color: border, width: 0.5),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: KoraColors.purple.withValues(alpha: 0.25),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Stack(
                                  children: [
                                    // ── Icon preview ──
                                    if (icon.assetPath != null)
                                      SizedBox(
                                        width: 76,
                                        height: 76,
                                        child: Image.asset(
                                          icon.assetPath!,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    else
                                      Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: icon.gradient!,
                                          ),
                                        ),
                                      ),
                                    // ── K letter for gradient icons ──
                                    if (icon.assetPath == null)
                                      Center(
                                        child: Text(
                                          'K',
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.9),
                                            fontSize: 32,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: -1,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            if (isSelected && isPremium)
                              Positioned(
                                top: -2,
                                right: -2,
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: KoraColors.purple,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: bg, width: 2),
                                  ),
                                  child: const Icon(Icons.check, color: Colors.white, size: 14),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          icon.name,
                          style: TextStyle(
                            color: isSelected ? textPrimary : textSecondary,
                            fontSize: 12.5,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // ── Bottom section ──
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
              decoration: BoxDecoration(
                color: card,
                border: Border(
                  top: BorderSide(color: border, width: 0.5),
                ),
              ),
              child: isPremium
                  ? Column(
                      children: [
                        if (_selectedIcon != _provider.appIconIndex)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              'Tap to apply ${_icons[_selectedIcon].name} icon',
                              style: TextStyle(color: KoraColors.purple, fontSize: 13),
                            ),
                          ),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: GestureDetector(
                            onTap: _isApplying ? null : _applyIcon,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: KoraColors.brandGradient,
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: _isApplying ? null : [
                                  BoxShadow(
                                    color: KoraColors.purple.withValues(alpha: 0.35),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: _isApplying
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : Text(
                                        _selectedIcon == _provider.appIconIndex
                                            ? 'Set App Icon'
                                            : 'Apply ${_icons[_selectedIcon].name} Icon',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.workspace_premium, color: KoraColors.purple, size: 22),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Choose your app icon with Kora Premium.',
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: GestureDetector(
                            onTap: _showPremiumSheet,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: KoraColors.brandGradient,
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: [
                                  BoxShadow(
                                    color: KoraColors.purple.withValues(alpha: 0.35),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Text(
                                  'Get Kora Premium',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}



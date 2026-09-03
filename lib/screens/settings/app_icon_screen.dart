import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import '../../theme/chat_theme_provider.dart';
import 'premium_subscribe_sheet.dart';
import 'billing_screen.dart';
import '../../config/subscription_pricing.dart';
import '../../services/app_icon_switcher.dart';
import '../../services/session_manager.dart';

/// A single Kora app icon option. Every icon is a real asset image now —
/// no gradient/letter placeholders. `isPremiumIcon` gates selection;
/// `isCircle` controls whether the picker renders it as a circle (only
/// the free Default icon) or a rounded-square "box" (Premium icons).
class KoraIconDef {
  final String name;
  final String assetPath;
  final bool isPremiumIcon;
  final bool isCircle;
  const KoraIconDef({
    required this.name,
    required this.assetPath,
    this.isPremiumIcon = true,
    this.isCircle = false,
  });
}

/// Kora app icon definitions.
/// Index 0 — Default — is free for everyone and rendered as a circle.
/// Indices 1+ are Premium-only and rendered as rounded-square boxes.
const List<KoraIconDef> kKoraIconDefs = [
  KoraIconDef(
    name: 'Default',
    assetPath: 'assets/icons/icon_default_circle.webp',
    isPremiumIcon: false,
    isCircle: true,
  ),
  KoraIconDef(
    name: 'Aurora Circle',
    assetPath: 'assets/icons/icon_aurora_circle.webp',
  ),
  KoraIconDef(
    name: 'Gold Elite',
    assetPath: 'assets/icons/icon_gold_elite.webp',
  ),
];

/// App Icon picker. Default (index 0) is free for everyone; the other
/// icons require Kora Premium to select and apply. A 3-dot menu at the
/// top lets the user reset back to the Default icon at any time.
class AppIconScreen extends StatefulWidget {
  const AppIconScreen({super.key});

  @override
  State<AppIconScreen> createState() => _AppIconScreenState();
}

class _AppIconScreenState extends State<AppIconScreen> {
  String? _userEmail;

  final _provider = ChatThemeProvider.instance;
  int _selectedIcon = 0;
  bool _isApplying = false;
  bool _isLoadingPremiumSheet = false;

  @override
  void initState() {
    super.initState();
    _loadEmail();
    _selectedIcon = _provider.appIconIndex;
    _provider.addListener(_onChanged);
  }

  
  Future<void> _loadEmail() async {
    final session = await SessionManager.instance.loadSession();
    if (session != null && mounted) {
      setState(() {
        _userEmail = session['email']?.toString() ?? '';
      });
    }
  }

@override
  void dispose() {
    _provider.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  // Icon definitions live in the top-level `kKoraIconDefs` list below so
  // the Appearance screen can render a matching preview thumbnail.
  static const List<KoraIconDef> _icons = kKoraIconDefs;

  void _selectIcon(int index) {
    final icon = _icons[index];
    if (icon.isPremiumIcon && !_provider.isPremium) {
      // Premium-locked icon — offer Premium instead of selecting it.
      _showPremiumSheet();
      return;
    }
    setState(() => _selectedIcon = index);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${icon.name} icon selected'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: KoraColors.darkCard,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _applyIcon() async {
    if (_isApplying) return;
    final icon = _icons[_selectedIcon];
    if (icon.isPremiumIcon && !_provider.isPremium) return;

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
                ? '${icon.name} icon set! The app icon will update shortly.'
                : '${icon.name} icon saved. Restart the app to see the change.',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: KoraColors.darkCard,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// Resets the app icon back to the free Default icon — always allowed.
  Future<void> _resetToDefault() async {
    setState(() {
      _selectedIcon = 0;
      _isApplying = true;
    });

    await _provider.resetAppIcon();
    final success = await AppIconSwitcher.setIcon(0);

    if (mounted) {
      setState(() => _isApplying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'App icon reset to Default.'
                : 'Default icon saved. Restart the app to see the change.',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: KoraColors.darkCard,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _showPremiumSheet() async {
    if (_isLoadingPremiumSheet) return;
    setState(() => _isLoadingPremiumSheet = true);

    // Brief loading state for tactile feedback before the sheet opens.
    await Future.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    setState(() => _isLoadingPremiumSheet = false);

    final result = await showModalBottomSheet<SubscriptionPlan>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (context) => const PremiumSubscribeSheet(),
    );

    if (result != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => BillingScreen(selectedPlan: result, userEmail: _userEmail ?? '')),
      );
    }
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
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: textPrimary),
            color: card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: border, width: 0.5),
            ),
            onSelected: (value) {
              if (value == 'reset') _resetToDefault();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'reset',
                child: Row(
                  children: [
                    const Text('🔁', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 10),
                    Text(
                      'Reset app icon',
                      style: TextStyle(color: textPrimary, fontSize: 14.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (!isPremium)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Only the Default icon is free. Unlock the rest with Kora Premium.',
                    style: TextStyle(color: textSecondary, fontSize: 13, height: 1.4),
                  ),
                ),
              ),
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
                  final isLocked = icon.isPremiumIcon && !isPremium;
                  final radius = icon.isCircle
                      ? BorderRadius.circular(38)
                      : BorderRadius.circular(18);
                  final innerRadius = icon.isCircle
                      ? BorderRadius.circular(36)
                      : BorderRadius.circular(16);

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
                                borderRadius: radius,
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
                                borderRadius: innerRadius,
                                child: Stack(
                                  children: [
                                    SizedBox(
                                      width: 76,
                                      height: 76,
                                      child: Image.asset(
                                        icon.assetPath,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          decoration: const BoxDecoration(
                                            gradient: KoraColors.brandGradient,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (isLocked)
                                      Positioned(
                                        bottom: 0,
                                        left: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 4),
                                          color: Colors.black.withValues(alpha: 0.55),
                                          child: const Icon(
                                            Icons.workspace_premium,
                                            color: Colors.white,
                                            size: 14,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            if (isSelected)
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
              child: Column(
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
                  if (!isPremium) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: GestureDetector(
                        onTap: _isLoadingPremiumSheet ? null : _showPremiumSheet,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: KoraColors.purple, width: 1.5),
                            borderRadius: BorderRadius.circular(26),
                          ),
                          child: Center(
                            child: _isLoadingPremiumSheet
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: KoraColors.purple,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Text(
                                    'Get Kora Premium',
                                    style: TextStyle(
                                      color: KoraColors.purple,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

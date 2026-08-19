import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import '../../theme/chat_theme_provider.dart';
import 'premium_subscribe_sheet.dart';
import 'billing_screen.dart';

/// App theme picker — 20 colors. Premium only.
/// Normal users see "This feature isn't available to you" dialog.
/// 3-dot menu → Reset app theme (also premium only).
class AppThemeScreen extends StatefulWidget {
  const AppThemeScreen({super.key});

  @override
  State<AppThemeScreen> createState() => _AppThemeScreenState();
}

class _AppThemeScreenState extends State<AppThemeScreen> {
  final _provider = ChatThemeProvider.instance;

  @override
  void initState() {
    super.initState();
    _provider.addListener(_onChanged);
  }

  @override
  void dispose() {
    _provider.removeListener(_onChanged);
    super.dispose();
  }

  bool _isLoadingPremium = false;

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _showPremiumSheet() async {
    if (_isLoadingPremium) return;
    setState(() => _isLoadingPremium = true);
    await Future.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    setState(() => _isLoadingPremium = false);

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (context) => const PremiumSubscribeSheet(),
    );

    if (result == true && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BillingScreen()),
      );
    }
  }

  void _showNotAvailable() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: KoraColors.cardFor(Theme.of(context).brightness),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'This feature isn\'t available to you',
          style: TextStyle(
            color: KoraColors.textPrimaryFor(Theme.of(context).brightness),
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(color: KoraColors.purple, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showResetDialog() {
    final brightness = Theme.of(context).brightness;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: KoraColors.cardFor(brightness),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Reset app theme?',
          style: TextStyle(
            color: KoraColors.textPrimaryFor(brightness),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Any changes you have made will reset back to the default Kora app theme',
          style: TextStyle(
            color: KoraColors.textSecondaryFor(brightness),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: KoraColors.purple, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () {
              _provider.resetAppTheme();
              Navigator.pop(context);
            },
            child: const Text(
              'Reset',
              style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final isPremium = _provider.isPremium;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          'App theme',
          style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: textPrimary),
            color: KoraColors.cardFor(brightness),
            onSelected: (value) {
              if (value == 'reset') {
                if (isPremium) {
                  _showResetDialog();
                } else {
                  _showNotAvailable();
                }
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'reset',
                child: Row(
                  children: [
                    Icon(Icons.refresh, size: 20, color: textSecondary),
                    const SizedBox(width: 10),
                    Text(
                      '↺ Reset app theme',
                      style: TextStyle(color: textPrimary, fontSize: 14),
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
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: KoraColors.purple.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: KoraColors.purple.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.workspace_premium, color: KoraColors.purple, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'App theme is a Kora Premium feature. Upgrade to unlock 20 exclusive colors.',
                        style: TextStyle(color: textSecondary, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  childAspectRatio: 1,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: kAppThemeColors.length,
                itemBuilder: (context, index) {
                  final color = kAppThemeColors[index];
                  final isSelected = _provider.appThemeColor.toARGB32() == color.toARGB32();
                  return GestureDetector(
                    onTap: () {
                      if (!isPremium) {
                        _showNotAvailable();
                        return;
                      }
                      _provider.setAppThemeColor(color);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 26)
                          : null,
                    ),
                  );
                },
              ),
            ),

            // ── Bottom button ──
            // Premium: "Set App Theme" button (confirms the current selection)
            // Non-premium: "Get Kora Premium" button
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
              decoration: BoxDecoration(
                color: KoraColors.cardFor(brightness),
                border: Border(
                  top: BorderSide(color: KoraColors.borderFor(brightness), width: 0.5),
                ),
              ),
              child: isPremium
                  ? SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('App theme color applied'),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: KoraColors.cardFor(brightness),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                          Navigator.pop(context);
                        },
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
                              'Set App Theme',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  : SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: GestureDetector(
                        onTap: _isLoadingPremium ? null : _showPremiumSheet,
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
                          child: Center(
                            child: _isLoadingPremium
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Text(
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
            ),
          ],
        ),
      ),
    );
  }
}

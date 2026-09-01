import 'package:flutter/material.dart';
import '../theme/kora_colors.dart';
import '../services/accounts_manager.dart';
import 'kora_avatar.dart';

/// Telegram-style account switcher — long-press the Profile tab to see
/// every account added on this device, with "Add Account" pinned at the
/// top. Tapping an account switches to it instantly (no re-login). The
/// active account is ringed in Kora purple, matching Telegram's blue ring.
///
/// Free devices can add up to [AccountsManager.freeAccountLimit] accounts;
/// if any added account has Premium, the device-wide ceiling rises to
/// [AccountsManager.premiumAccountLimit].
class AccountSwitcherPopup {
  /// Shows the popup anchored above the bottom nav bar, near [anchorRight]
  /// from the right edge and [bottomOffset] above the screen bottom.
  ///
  /// [onAddAccount] is called when the user taps "Add Account" and there's
  /// room for another one.
  /// [onLimitReached] is called instead when the device-wide account cap
  /// has already been hit — the caller should show the Premium upsell.
  /// [onSwitched] is called with the newly active account's email after a
  /// successful switch, so the caller can rebuild/navigate.
  static void show(
    BuildContext context, {
    required double bottomOffset,
    required VoidCallback onAddAccount,
    required VoidCallback onLimitReached,
    required void Function(String email) onSwitched,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => _AccountSwitcherOverlay(
        bottomOffset: bottomOffset,
        onDismiss: () => entry.remove(),
        onAddAccount: onAddAccount,
        onLimitReached: onLimitReached,
        onSwitched: onSwitched,
      ),
    );

    overlay.insert(entry);
  }
}

class _AccountSwitcherOverlay extends StatefulWidget {
  final double bottomOffset;
  final VoidCallback onDismiss;
  final VoidCallback onAddAccount;
  final VoidCallback onLimitReached;
  final void Function(String email) onSwitched;

  const _AccountSwitcherOverlay({
    required this.bottomOffset,
    required this.onDismiss,
    required this.onAddAccount,
    required this.onLimitReached,
    required this.onSwitched,
  });

  @override
  State<_AccountSwitcherOverlay> createState() => _AccountSwitcherOverlayState();
}

class _AccountSwitcherOverlayState extends State<_AccountSwitcherOverlay> {
  List<Map<String, dynamic>> _accounts = [];
  String? _activeEmail;
  bool _loading = true;
  String? _switchingEmail;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final accounts = await AccountsManager.instance.getAccounts();
    final active = await AccountsManager.instance.getActiveEmail();
    if (!mounted) return;
    setState(() {
      _accounts = accounts;
      _activeEmail = active;
      _loading = false;
    });
  }

  Future<void> _handleAddAccount() async {
    final canAdd = await AccountsManager.instance.canAddMore();
    widget.onDismiss();
    if (canAdd) {
      widget.onAddAccount();
    } else {
      widget.onLimitReached();
    }
  }

  Future<void> _handleTapAccount(String email) async {
    if (email == _activeEmail || _switchingEmail != null) return;
    setState(() => _switchingEmail = email);
    await AccountsManager.instance.switchAccount(email);
    if (!mounted) return;
    widget.onDismiss();
    widget.onSwitched(email);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final card = KoraColors.cardFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onDismiss,
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.black.withValues(alpha: 0.25)),
          ),
        ),
        Positioned(
          right: 16,
          bottom: widget.bottomOffset,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 240,
              constraints: const BoxConstraints(maxHeight: 360),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: KoraColors.purple),
                        ),
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ── Add Account ──
                        InkWell(
                          onTap: _handleAddAccount,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: KoraColors.purple, width: 1.6),
                                  ),
                                  child: Icon(Icons.add, size: 16, color: KoraColors.purple),
                                ),
                                const SizedBox(width: 14),
                                Text(
                                  'Add Account',
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_accounts.isNotEmpty)
                          Divider(height: 1, color: textSecondary.withValues(alpha: 0.12)),
                        // ── Account list ──
                        Flexible(
                          child: ListView.builder(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: _accounts.length,
                            itemBuilder: (context, index) {
                              final acc = _accounts[index];
                              final email = (acc['email'] as String?) ?? '';
                              final name = (acc['fullName'] as String?)?.trim().isNotEmpty == true
                                  ? acc['fullName'] as String
                                  : (acc['username'] as String?) ?? email;
                              final avatarUrl = acc['avatarUrl'] as String?;
                              final isActive = email == _activeEmail;
                              final isSwitching = email == _switchingEmail;

                              return InkWell(
                                onTap: () => _handleTapAccount(email),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: isActive
                                              ? Border.all(color: KoraColors.purple, width: 2)
                                              : null,
                                        ),
                                        child: KoraAvatar(name: name, imageUrl: avatarUrl, size: 34),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: textPrimary,
                                            fontSize: 14.5,
                                            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      if (isSwitching)
                                        const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: KoraColors.purple),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

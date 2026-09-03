import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../models/chat_models.dart';
import '../services/chat_service.dart';
import '../services/chat_vault_service.dart';
import '../services/conversation_directory.dart';
import '../theme/kora_colors.dart';
import '../widgets/chat_list_item.dart';
import '../widgets/kora_empty_state.dart';
import '../widgets/kora_menu_sheet.dart';
import 'chat/kora_chat_screen.dart';

/// Locked Chats screen — shows chats the user has locked.
/// Hidden from BOTH the main Home list and Archived Chats; only reachable
/// behind biometric authentication or secret code.
class LockedChatsScreen extends StatefulWidget {
  final bool skipInitialAuth;

  const LockedChatsScreen({
    super.key,
    this.skipInitialAuth = false,
  });

  @override
  State<LockedChatsScreen> createState() => _LockedChatsScreenState();
}

class _LockedChatsScreenState extends State<LockedChatsScreen> {
  List<ChatPreview> _chats = [];
  bool _loading = true;
  bool _authenticated = false;
  final Set<String> _selectedIds = {};
  bool get _isSelecting => _selectedIds.isNotEmpty;

  int _autoLockTimer = 0; // minutes: 0 = immediate, 1, 5, 30, -1 = never

  @override
  void initState() {
    super.initState();
    if (widget.skipInitialAuth) {
      _authenticated = true;
      _load();
    } else {
      _verifyAndLoad();
    }
  }

  Future<void> _verifyAndLoad() async {
    final authed = await _authenticate('Open Locked Chats');
    if (!authed) {
      if (mounted) Navigator.pop(context);
      return;
    }
    await ChatVaultService.instance.recordUnlocked();
    setState(() => _authenticated = true);
    await _load();
  }

  Future<bool> _authenticate(String reason) async {
    try {
      final localAuth = LocalAuthentication();
      final available = await localAuth.canCheckBiometrics ||
          await localAuth.isDeviceSupported();

      if (available) {
        final authed = await localAuth.authenticate(
          localizedReason: '$reason requires biometric authentication',
          biometricOnly: false,
        );
        if (authed) return true;
      }

      // Fallback: Secret code
      final hasCode = await ChatVaultService.instance.hasSecretCode();
      if (hasCode) {
        return await _showSecretCodeAuthDialog();
      }
      return false;
    } catch (_) {
      final hasCode = await ChatVaultService.instance.hasSecretCode();
      if (hasCode) {
        return await _showSecretCodeAuthDialog();
      }
      return false;
    }
  }

  Future<bool> _showSecretCodeAuthDialog() async {
    final controller = TextEditingController();
    bool obscure = true;
    String? error;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final brightness = Theme.of(context).brightness;
          final card = KoraColors.cardFor(brightness);
          final textPrimary = KoraColors.textPrimaryFor(brightness);
          final textSecondary = KoraColors.textSecondaryFor(brightness);

          return AlertDialog(
            backgroundColor: card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'Enter Secret Code',
              style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Enter your secret code to view locked chats.',
                  style: TextStyle(color: textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  obscureText: obscure,
                  autofocus: true,
                  maxLength: 8,
                  style: TextStyle(color: textPrimary, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'Secret code',
                    hintStyle: TextStyle(color: textSecondary),
                    errorText: error,
                    counterText: '',
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: KoraColors.borderFor(brightness)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: KoraColors.purple, width: 2),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, color: textSecondary),
                      onPressed: () => setDialogState(() => obscure = !obscure),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: Text('Cancel', style: TextStyle(color: textSecondary)),
              ),
              TextButton(
                onPressed: () async {
                  final text = controller.text.trim();
                  final ok = await ChatVaultService.instance.verifySecretCode(text);
                  if (ok) {
                    Navigator.pop(dialogCtx, true);
                  } else {
                    setDialogState(() {
                      error = 'Incorrect secret code';
                    });
                  }
                },
                child: const Text('Unlock', style: TextStyle(color: KoraColors.purple, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
    controller.dispose();
    return result ?? false;
  }

  Future<void> _load() async {
    final chats = await ChatService.instance.getLockedChats();
    final timer = await ChatVaultService.instance.getAutoLockTimer();
    if (!mounted) return;
    setState(() {
      _chats = chats;
      _autoLockTimer = timer;
      _loading = false;
    });
  }

  void _openChat(ChatPreview chat) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => KoraChatScreen(
          isGroupChat: false,
          chatId: chat.id,
          name: chat.name,
          avatarAsset: chat.avatarAsset,
          avatarUrl: chat.avatarUrl,
          badge: chat.badge,
          isOnline: chat.isOnline,
          lastSeen: chat.isOnline ? null : 'last seen recently',
        ),
      ),
    );
  }

  void _onChatTap(ChatPreview chat) {
    if (_isSelecting) {
      setState(() {
        if (_selectedIds.contains(chat.id)) {
          _selectedIds.remove(chat.id);
        } else {
          _selectedIds.add(chat.id);
        }
      });
    } else {
      _openChat(chat);
    }
  }

  void _onChatLongPress(ChatPreview chat) {
    setState(() {
      if (_selectedIds.contains(chat.id)) {
        _selectedIds.remove(chat.id);
      } else {
        _selectedIds.add(chat.id);
      }
    });
  }

  void _clearSelection() => setState(() => _selectedIds.clear());

  Future<void> _unlockSelected() async {
    final ids = List<String>.from(_selectedIds);
    if (ids.isEmpty) return;
    for (final id in ids) {
      await ConversationDirectoryService.instance.setLocked(id, false);
    }
    final count = ids.length;
    _clearSelection();
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(count == 1 ? 'Chat unlocked' : '$count chats unlocked'),
          backgroundColor: KoraColors.purple,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _showSetSecretCodeDialog() async {
    final hasCode = await ChatVaultService.instance.hasSecretCode();
    final controller = TextEditingController();
    bool obscure = true;
    String? errorMessage;

    final code = await showDialog<String>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final brightness = Theme.of(context).brightness;
            final card = KoraColors.cardFor(brightness);
            final textPrimary = KoraColors.textPrimaryFor(brightness);
            final textSecondary = KoraColors.textSecondaryFor(brightness);

            return AlertDialog(
              backgroundColor: card,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                hasCode ? 'Change Secret Code' : 'Set Secret Code',
                style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Secret code must be 4 to 8 characters.',
                    style: TextStyle(color: textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    obscureText: obscure,
                    autofocus: true,
                    maxLength: 8,
                    style: TextStyle(color: textPrimary, fontSize: 16),
                    decoration: InputDecoration(
                      labelText: 'Secret code',
                      labelStyle: TextStyle(color: textSecondary),
                      errorText: errorMessage,
                      counterText: '',
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: KoraColors.borderFor(brightness)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: KoraColors.purple, width: 2),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, color: textSecondary),
                        onPressed: () => setDialogState(() => obscure = !obscure),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text('Cancel', style: TextStyle(color: textSecondary)),
                ),
                TextButton(
                  onPressed: () {
                    final text = controller.text.trim();
                    if (text.length < 4 || text.length > 8) {
                      setDialogState(() {
                        errorMessage = 'Code must be 4 to 8 characters';
                      });
                      return;
                    }
                    Navigator.pop(dialogCtx, text);
                  },
                  child: const Text('Save', style: TextStyle(color: KoraColors.purple, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
    if (code != null && code.isNotEmpty) {
      await ChatVaultService.instance.setSecretCode(code);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Secret code updated'),
            backgroundColor: KoraColors.purple,
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

  Future<void> _showAutoLockDialog() async {
    final current = await ChatVaultService.instance.getAutoLockTimer();
    int selected = current;

    final result = await showDialog<int>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final brightness = Theme.of(context).brightness;
          final card = KoraColors.cardFor(brightness);
          final textPrimary = KoraColors.textPrimaryFor(brightness);

          Widget optionTile(int val, String label) {
            return RadioListTile<int>(
              title: Text(label, style: TextStyle(color: textPrimary, fontSize: 15)),
              value: val,
              groupValue: selected,
              activeColor: KoraColors.purple,
              onChanged: (v) {
                if (v != null) setDialogState(() => selected = v);
              },
            );
          }

          return AlertDialog(
            backgroundColor: card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'Auto-lock timer',
              style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                optionTile(0, 'Immediately'),
                optionTile(1, 'After 1 minute'),
                optionTile(5, 'After 5 minutes'),
                optionTile(30, 'After 30 minutes'),
                optionTile(-1, 'Never'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, selected),
                child: const Text('Save', style: TextStyle(color: KoraColors.purple, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );

    if (result != null) {
      await ChatVaultService.instance.setAutoLockTimer(result);
      setState(() => _autoLockTimer = result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Auto-lock timer updated'),
            backgroundColor: KoraColors.purple,
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

  void _openOverflowMenu() {
    KoraMenuSheet.show(context, [
      KoraMenuOption(
        icon: Icons.password_outlined,
        label: 'Secret code settings',
        onTap: _showSetSecretCodeDialog,
      ),
      KoraMenuOption(
        icon: Icons.timer_outlined,
        label: 'Auto-lock timer',
        onTap: _showAutoLockDialog,
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (!_authenticated) {
      return Scaffold(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF0B0B0F)
            : Colors.white,
        body: const Center(child: CircularProgressIndicator(color: KoraColors.purple)),
      );
    }

    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);

    // WhatsApp behavior: back while chats are selected cancels the
    // selection instead of leaving the screen.
    return PopScope(
      canPop: !_isSelecting,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_isSelecting) {
          setState(() => _selectedIds.clear());
        }
      },
      child: Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: surface,
        elevation: 0,
        title: _isSelecting
            ? Text(
                '${_selectedIds.length} selected',
                style: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
              )
            : Text(
                'Locked Chats',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
          onPressed: _isSelecting ? _clearSelection : () => Navigator.pop(context),
        ),
        actions: _isSelecting
            ? [
                IconButton(
                  tooltip: 'Unlock',
                  icon: Icon(Icons.lock_open_outlined, color: textPrimary),
                  onPressed: _unlockSelected,
                ),
              ]
            : [
                IconButton(
                  tooltip: 'Vault Settings',
                  icon: Icon(Icons.more_vert, color: textPrimary),
                  onPressed: _openOverflowMenu,
                ),
              ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: KoraColors.purple))
          : _chats.isEmpty
              ? const KoraEmptyState(
                  icon: Icons.lock_outline,
                  title: 'No locked chats',
                  message: 'Long-press a chat on the Home screen and select "Lock chat" to hide it here, behind biometric authentication.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(top: 4),
                  itemCount: _chats.length,
                  separatorBuilder: (_, __) => Padding(
                    padding: const EdgeInsets.only(left: 84),
                    child: Divider(
                      height: 1,
                      color: textSecondary.withValues(alpha: 0.08),
                    ),
                  ),
                  itemBuilder: (context, index) {
                    final chat = _chats[index];
                    return ChatListItem(
                      chat: chat,
                      showLockIcon: true,
                      isSelected: _selectedIds.contains(chat.id),
                      onTap: () => _onChatTap(chat),
                      onLongPress: (_) => _onChatLongPress(chat),
                    );
                  },
                ),
    ),
    );
  }
}

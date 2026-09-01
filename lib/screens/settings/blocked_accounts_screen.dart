import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/kora_colors.dart';

/// Blocked Accounts screen — manages blocked contacts stored in
/// SharedPreferences as a JSON array of {name, koraId, blockedAt}.
class BlockedAccountsScreen extends StatefulWidget {
  const BlockedAccountsScreen({super.key});

  @override
  State<BlockedAccountsScreen> createState() => _BlockedAccountsScreenState();
}

class _BlockedAccountsScreenState extends State<BlockedAccountsScreen> {
  static const _prefsKey = 'kora_blocked_accounts_json';
  List<Map<String, dynamic>> _blockedList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBlockedAccounts();
  }

  Future<void> _loadBlockedAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      try {
        final List<dynamic> parsed = jsonDecode(raw);
        setState(() {
          _blockedList = parsed.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
        return;
      } catch (_) {}
    }
    // No blocked accounts found - show empty state
    setState(() {
      _blockedList = [];
      _isLoading = false;
    });
  }

  Future<void> _saveBlockedAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_blockedList));
  }

  void _unblockUser(int index) {
    final user = _blockedList[index];
    final name = user['name'] ?? 'User';
    setState(() {
      _blockedList.removeAt(index);
    });
    _saveBlockedAccounts();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Unblocked $name')),
    );
  }

  void _showAddBlockDialog() {
    final nameController = TextEditingController();
    final koraIdController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        final brightness = Theme.of(context).brightness;
        final textPrimary = KoraColors.textPrimaryFor(brightness);
        final textSecondary = KoraColors.textSecondaryFor(brightness);
        final card = KoraColors.cardFor(brightness);

        return AlertDialog(
          backgroundColor: card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Block User', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: TextStyle(color: textPrimary),
                decoration: InputDecoration(
                  labelText: 'Name or Phone',
                  labelStyle: TextStyle(color: textSecondary),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: KoraColors.borderFor(brightness))),
                  focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: KoraColors.purple)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: koraIdController,
                style: TextStyle(color: textPrimary),
                decoration: InputDecoration(
                  labelText: 'Kora ID (Optional)',
                  labelStyle: TextStyle(color: textSecondary),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: KoraColors.borderFor(brightness))),
                  focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: KoraColors.purple)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: KoraColors.red),
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  setState(() {
                    _blockedList.add({
                      'name': name,
                      'koraId': koraIdController.text.trim().isEmpty ? 'kora_user' : koraIdController.text.trim(),
                      'blockedAt': DateTime.now().toIso8601String(),
                    });
                  });
                  _saveBlockedAccounts();
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Block', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final card = KoraColors.cardFor(brightness);
    final border = KoraColors.borderFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          'Blocked accounts',
          style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_outlined, color: KoraColors.purple),
            onPressed: _showAddBlockDialog,
            tooltip: 'Add block',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: KoraColors.purple))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Text(
                    'Blocked contacts will no longer be able to call you or send you messages.',
                    style: TextStyle(color: textSecondary, fontSize: 13, height: 1.4),
                  ),
                ),
                Expanded(
                  child: _blockedList.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.block, size: 64, color: textSecondary.withValues(alpha: 0.5)),
                              const SizedBox(height: 16),
                              Text(
                                'No blocked accounts',
                                style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Tap + to block a contact or Kora ID.',
                                style: TextStyle(color: textSecondary, fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _blockedList.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final item = _blockedList[index];
                            final name = item['name'] as String? ?? 'Blocked Contact';
                            final koraId = item['koraId'] as String? ?? '';
                            return Container(
                              decoration: BoxDecoration(
                                color: card,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: border),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: KoraColors.red.withValues(alpha: 0.2),
                                  child: Icon(Icons.block, color: KoraColors.red, size: 20),
                                ),
                                title: Text(
                                  name,
                                  style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
                                ),
                                subtitle: koraId.isNotEmpty
                                    ? Text(
                                        '@$koraId',
                                        style: TextStyle(color: textSecondary, fontSize: 13),
                                      )
                                    : null,
                                trailing: TextButton(
                                  onPressed: () => _unblockUser(index),
                                  child: const Text('Unblock', style: TextStyle(color: KoraColors.purple, fontWeight: FontWeight.w600)),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

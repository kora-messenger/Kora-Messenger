import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/kora_colors.dart';

/// Kora Contacts screen — shows saved Kora contacts with add & remove options,
/// persisting to SharedPreferences.
class KoraContactsScreen extends StatefulWidget {
  const KoraContactsScreen({super.key});

  @override
  State<KoraContactsScreen> createState() => _KoraContactsScreenState();
}

class _KoraContactsScreenState extends State<KoraContactsScreen> {
  static const _prefsKey = 'kora_saved_contacts_list';
  List<Map<String, dynamic>> _contacts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      try {
        final List<dynamic> parsed = jsonDecode(raw);
        setState(() {
          _contacts = parsed.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
        return;
      } catch (_) {}
    }

    // Default sample contacts if empty
    setState(() {
      _contacts = [
        {'name': 'Alice Johnson', 'phone': '+1 555 0192', 'koraId': 'alice_j', 'status': 'Hey there! Using Kora.'},
        {'name': 'Bob Smith', 'phone': '+1 555 0143', 'koraId': 'bob_smith', 'status': 'Available'},
        {'name': 'Carol Williams', 'phone': '+1 555 0188', 'koraId': 'carol_w', 'status': 'At work'},
      ];
      _isLoading = false;
    });
  }

  Future<void> _saveContacts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_contacts));
  }

  void _addContact() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final koraIdController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        final brightness = Theme.of(context).brightness;
        final textPrimary = KoraColors.textPrimaryFor(brightness);
        final card = KoraColors.cardFor(brightness);

        return AlertDialog(
          backgroundColor: card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Add Kora Contact', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  style: TextStyle(color: textPrimary),
                  decoration: const InputDecoration(labelText: 'Full Name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(color: textPrimary),
                  decoration: const InputDecoration(labelText: 'Phone Number'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: koraIdController,
                  style: TextStyle(color: textPrimary),
                  decoration: const InputDecoration(labelText: 'Kora ID / Username'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: KoraColors.purple),
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  setState(() {
                    _contacts.add({
                      'name': name,
                      'phone': phoneController.text.trim(),
                      'koraId': koraIdController.text.trim(),
                      'status': 'Hey there! Using Kora.',
                    });
                  });
                  _saveContacts();
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Add Contact', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _removeContact(int index) {
    final removed = _contacts[index]['name'];
    setState(() {
      _contacts.removeAt(index);
    });
    _saveContacts();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Removed $removed from contacts')),
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
          'Kora contacts',
          style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addContact,
        backgroundColor: KoraColors.purple,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('New Contact', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: KoraColors.purple))
          : _contacts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.contacts_outlined, size: 64, color: textSecondary.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      Text('No saved Kora contacts', style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text('Tap + New Contact to add someone.', style: TextStyle(color: textSecondary, fontSize: 13)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                  itemCount: _contacts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final contact = _contacts[index];
                    final name = contact['name'] as String? ?? 'Contact';
                    final phone = contact['phone'] as String? ?? '';
                    final koraId = contact['koraId'] as String? ?? '';
                    final status = contact['status'] as String? ?? '';

                    return Container(
                      decoration: BoxDecoration(
                        color: card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: border),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: KoraColors.purple.withValues(alpha: 0.2),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'C',
                            style: const TextStyle(color: KoraColors.purple, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(name, style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (phone.isNotEmpty || koraId.isNotEmpty)
                              Text(
                                [if (phone.isNotEmpty) phone, if (koraId.isNotEmpty) '@$koraId'].join(' • '),
                                style: TextStyle(color: textSecondary, fontSize: 12),
                              ),
                            if (status.isNotEmpty)
                              Text(
                                status,
                                style: TextStyle(color: textSecondary.withValues(alpha: 0.8), fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: KoraColors.red, size: 22),
                          onPressed: () => _removeContact(index),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

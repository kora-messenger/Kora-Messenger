import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/kora_colors.dart';

/// WhatsApp-style Live Location screen — displays map placeholder and
/// list of contacts you are currently sharing your live location with.
class LiveLocationScreen extends StatefulWidget {
  const LiveLocationScreen({super.key});

  @override
  State<LiveLocationScreen> createState() => _LiveLocationScreenState();
}

class _LiveLocationScreenState extends State<LiveLocationScreen> {
  static const _prefsKey = 'kora_live_location_contacts';
  List<Map<String, dynamic>> _sharingContacts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSharingContacts();
  }

  Future<void> _loadSharingContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final rawJson = prefs.getString(_prefsKey);
    if (rawJson != null) {
      try {
        final List<dynamic> list = jsonDecode(rawJson);
        setState(() {
          _sharingContacts = list.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
        return;
      } catch (_) {}
    }
    // Default mock initial data if empty
    setState(() {
      _sharingContacts = [];
      _isLoading = false;
    });
  }

  Future<void> _saveSharingContacts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_sharingContacts));
  }

  void _stopSharing(int index) {
    final removed = _sharingContacts[index]['name'];
    setState(() {
      _sharingContacts.removeAt(index);
    });
    _saveSharingContacts();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Stopped sharing location with $removed')),
    );
  }

  void _stopSharingAll() {
    setState(() {
      _sharingContacts.clear();
    });
    _saveSharingContacts();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Stopped sharing live location in all chats')),
    );
  }

  void _showAddSharingDialog() {
    final controller = TextEditingController();
    String duration = '8 hours';
    unawaited(showDialog(
      context: context,
      builder: (ctx) {
        final brightness = Theme.of(context).brightness;
        final textPrimary = KoraColors.textPrimaryFor(brightness);
        final card = KoraColors.cardFor(brightness);

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: card,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Share Live Location', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    style: TextStyle(color: textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Contact Name',
                      labelStyle: TextStyle(color: KoraColors.textSecondaryFor(brightness)),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: KoraColors.borderFor(brightness))),
                      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: KoraColors.purple)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: duration,
                    dropdownColor: card,
                    style: TextStyle(color: textPrimary),
                    decoration: const InputDecoration(labelText: 'Duration'),
                    items: const [
                      DropdownMenuItem(value: '15 minutes', child: Text('15 minutes')),
                      DropdownMenuItem(value: '1 hour', child: Text('1 hour')),
                      DropdownMenuItem(value: '8 hours', child: Text('8 hours')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => duration = val);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: KoraColors.purple),
                  onPressed: () {
                    final name = controller.text.trim();
                    if (name.isNotEmpty) {
                      setState(() {
                        _sharingContacts.add({
                          'name': name,
                          'duration': duration,
                          'sharedAt': DateTime.now().toIso8601String(),
                        });
                      });
                      _saveSharingContacts();
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text('Share', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() { controller.dispose(); }));
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
          'Live location',
          style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: KoraColors.purple))
          : Column(
              children: [
                // Map Placeholder Container
                Container(
                  height: 220,
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: KoraColors.darkSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: border),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Grid lines effect
                      Opacity(
                        opacity: 0.15,
                        child: Icon(Icons.map_outlined, size: 180, color: KoraColors.purple),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: KoraColors.purple.withValues(alpha: 0.2),
                              border: Border.all(color: KoraColors.purple, width: 2),
                            ),
                            child: const Icon(Icons.my_location, color: KoraColors.purple, size: 36),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _sharingContacts.isEmpty
                                      ? 'Not sharing location'
                                      : 'Sharing live location (${_sharingContacts.length} active)',
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'CHATS SHARING LIVE LOCATION',
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, color: KoraColors.purple),
                        onPressed: _showAddSharingDialog,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _sharingContacts.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.location_off_outlined, size: 64, color: textSecondary.withValues(alpha: 0.5)),
                                const SizedBox(height: 16),
                                Text(
                                  'You are not sharing your live location in any chats',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: textSecondary, fontSize: 15),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _sharingContacts.length,
                          separatorBuilder: (_, __) => Divider(color: border, height: 1),
                          itemBuilder: (context, index) {
                            final contact = _sharingContacts[index];
                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                color: card,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: KoraColors.purple.withValues(alpha: 0.2),
                                  child: Text(
                                    (contact['name'] as String? ?? 'C')[0].toUpperCase(),
                                    style: const TextStyle(color: KoraColors.purple, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                title: Text(
                                  contact['name'] as String? ?? 'Contact',
                                  style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  'Sharing for ${contact['duration'] ?? '8 hours'}',
                                  style: TextStyle(color: textSecondary, fontSize: 13),
                                ),
                                trailing: TextButton(
                                  onPressed: () => _stopSharing(index),
                                  child: const Text('Stop', style: TextStyle(color: KoraColors.red, fontWeight: FontWeight.w600)),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                if (_sharingContacts.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: KoraColors.red,
                          side: const BorderSide(color: KoraColors.red),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _stopSharingAll,
                        child: const Text('Stop Sharing with All Contacts', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

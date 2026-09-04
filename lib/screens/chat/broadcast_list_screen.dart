import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import '../../services/chat_service.dart';
import '../../services/message_service.dart';
import '../../models/chat_models.dart';
import '../../widgets/kora_avatar.dart';
import '../chat/kora_chat_screen.dart';
import '../../utils/kora_page_routes.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Broadcast List screen — create and manage broadcast lists.
/// A broadcast list lets you send the same message to multiple
/// contacts at once. Recipients receive it as a normal message
/// (they don't see it's a broadcast).
///
/// Mirrors WhatsApp's Broadcast Lists feature.
class BroadcastListScreen extends StatefulWidget {
  const BroadcastListScreen({super.key});

  @override
  State<BroadcastListScreen> createState() => _BroadcastListScreenState();
}

class _BroadcastListScreenState extends State<BroadcastListScreen> {
  List<BroadcastList> _lists = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLists();
  }

  Future<void> _loadLists() async {
    final lists = await BroadcastManager.instance.loadLists();
    setState(() {
      _lists = lists;
      _loading = false;
    });
  }

  void _createNewList() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreateBroadcastScreen()),
    ).then((_) => _loadLists());
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text('Broadcast lists',
            style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewList,
        backgroundColor: KoraColors.purple,
        child: Icon(Icons.add, color: KoraColors.textPrimaryFor(Brightness.light)),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: KoraColors.purple))
          : _lists.isEmpty
              ? _emptyState(context)
              : ListView.builder(
                  itemCount: _lists.length,
                  itemBuilder: (context, index) => _buildListTile(_lists[index]),
                ),
    );
  }

  Widget _emptyState(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broadcast_on_personal, size: 56,
              color: KoraColors.textMutedFor(brightness)),
          const SizedBox(height: 16),
          Text('No broadcast lists yet',
              style: TextStyle(
                  color: KoraColors.textPrimaryFor(brightness),
                  fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Create a list to send messages to\nmultiple contacts at once',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: KoraColors.textMutedFor(brightness), fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildListTile(BroadcastList list) {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: KoraColors.purple.withValues(alpha: 0.15),
        child: Icon(Icons.campaign,
            color: KoraColors.purple, size: 24),
      ),
      title: Text(list.name,
          style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
      subtitle: Text('${list.recipientIds.length} recipients',
          style: TextStyle(color: textMuted, fontSize: 13)),
      onTap: () => _sendBroadcast(list),
    );
  }

  void _sendBroadcast(BroadcastList list) {
    // Navigate to a compose screen that sends to all recipients
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BroadcastComposeScreen(broadcastList: list),
      ),
    );
  }
}

/// Create a new broadcast list — select contacts to include.
class CreateBroadcastScreen extends StatefulWidget {
  const CreateBroadcastScreen({super.key});

  @override
  State<CreateBroadcastScreen> createState() => _CreateBroadcastScreenState();
}

class _CreateBroadcastScreenState extends State<CreateBroadcastScreen> {
  final _nameController = TextEditingController();
  final Set<String> _selected = {};
  List<ChatPreview> _contacts = [];

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final chats = await ChatService.instance.getChats();
    setState(() => _contacts = chats);
  }

  void _save() async {
    if (_nameController.text.isEmpty || _selected.isEmpty) return;
    final list = BroadcastList(
      id: 'broadcast_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text,
      recipientIds: _selected.toList(),
      createdAt: DateTime.now(),
    );
    await BroadcastManager.instance.addList(list);
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

@override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: Text('New Broadcast List',
            style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text('Create', style: TextStyle(color: KoraColors.purple, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _nameController,
              style: TextStyle(color: textPrimary),
              decoration: InputDecoration(
                hintText: 'List name',
                hintStyle: TextStyle(color: KoraColors.textMutedFor(brightness)),
                filled: true,
                fillColor: KoraColors.surfaceFor(brightness),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _contacts.length,
              itemBuilder: (context, index) {
                final chat = _contacts[index];
                final isSelected = _selected.contains(chat.id);
                return ListTile(
                  leading: KoraAvatar(
                    name: chat.name,
                    assetPath: chat.avatarAsset,
                    imageUrl: chat.avatarUrl,
                    size: 44,
                  ),
                  title: Text(chat.name,
                      style: TextStyle(color: textPrimary, fontSize: 15)),
                  trailing: isSelected
                      ? Icon(Icons.check_circle, color: KoraColors.purple)
                      : Icon(Icons.radio_button_off,
                          color: KoraColors.textMutedFor(brightness)),
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selected.remove(chat.id);
                      } else {
                        _selected.add(chat.id);
                      }
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Compose a broadcast message — sends to all recipients in the list.
class BroadcastComposeScreen extends StatefulWidget {
  final BroadcastList broadcastList;

  const BroadcastComposeScreen({super.key, required this.broadcastList});

  @override
  State<BroadcastComposeScreen> createState() => _BroadcastComposeScreenState();
}

class _BroadcastComposeScreenState extends State<BroadcastComposeScreen> {
  final _textController = TextEditingController();

  void _send() async {
    if (_textController.text.trim().isEmpty) return;
    for (final recipientId in widget.broadcastList.recipientIds) {
      await MessageService.instance.sendMessage(
        recipientId,
        _textController.text,
      );
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sent to ${widget.broadcastList.recipientIds.length} recipients'),
          backgroundColor: KoraColors.purple,
        ),
      );
      Navigator.pop(context);
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

@override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: Text(widget.broadcastList.name,
            style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Message will be sent to ${widget.broadcastList.recipientIds.length} recipients',
              style: TextStyle(color: KoraColors.textMutedFor(brightness), fontSize: 13),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _textController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: TextStyle(color: textPrimary, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Type a broadcast message…',
                  hintStyle: TextStyle(color: KoraColors.textMutedFor(brightness)),
                  filled: true,
                  fillColor: surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _send,
                style: ElevatedButton.styleFrom(
                  backgroundColor: KoraColors.purple,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Send Broadcast',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Broadcast list data model.
class BroadcastList {
  final String id;
  final String name;
  final List<String> recipientIds;
  final DateTime createdAt;

  BroadcastList({
    required this.id,
    required this.name,
    required this.recipientIds,
    required this.createdAt,
  });
}

/// Manages broadcast lists in SharedPreferences.

class BroadcastManager {
  static final BroadcastManager instance = BroadcastManager._();
  BroadcastManager._();

  static const _kKey = 'kora_broadcast_lists';

  Future<List<BroadcastList>> loadLists() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) {
        final m = e as Map<String, dynamic>;
        return BroadcastList(
          id: m['id'] as String,
          name: m['name'] as String,
          recipientIds: (m['recipientIds'] as List).cast<String>(),
          createdAt: DateTime.parse(m['createdAt'] as String),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> addList(BroadcastList list) async {
    final lists = await loadLists();
    lists.add(list);
    await _saveLists(lists);
  }

  Future<void> removeList(String id) async {
    final lists = await loadLists();
    lists.removeWhere((l) => l.id == id);
    await _saveLists(lists);
  }

  Future<void> _saveLists(List<BroadcastList> lists) async {
    final prefs = await SharedPreferences.getInstance();
    final json = lists.map((l) => {
      'id': l.id,
      'name': l.name,
      'recipientIds': l.recipientIds,
      'createdAt': l.createdAt.toIso8601String(),
    }).toList();
    await prefs.setString(_kKey, jsonEncode(json));
  }
}

import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import '../../models/message_model.dart';

/// Forward a message to one or more chats (max 5, like WhatsApp).
/// Shows a searchable list of recent conversations; user taps to
/// select/deselect, then hits the send button to forward.
class ForwardMessageScreen extends StatefulWidget {
  final KoraMessage message;

  const ForwardMessageScreen({super.key, required this.message});

  @override
  State<ForwardMessageScreen> createState() => _ForwardMessageScreenState();
}

class _ForwardMessageScreenState extends State<ForwardMessageScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Set<int> _selectedIndices = {};
  List<_ForwardContact> _allContacts = [];
  List<_ForwardContact> _filtered = [];

  @override
  void initState() {
    super.initState();
    _allContacts = _buildMockContacts();
    _filtered = _allContacts;
    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _allContacts
          : _allContacts.where((c) => c.name.toLowerCase().contains(q)).toList();
    });
  }

  List<_ForwardContact> _buildMockContacts() {
    return [
      _ForwardContact(name: 'Amara Okafor', lastMessage: 'Hey! Are we still on for tomorrow?', isGroup: false),
      _ForwardContact(name: 'Tunde Bello', lastMessage: 'Sent the files', isGroup: false),
      _ForwardContact(name: 'Zainab Yusuf', lastMessage: 'Thank you so much', isGroup: false),
      _ForwardContact(name: 'Family Group', lastMessage: 'Dad: See you all at dinner', isGroup: true),
      _ForwardContact(name: 'Work Team', lastMessage: 'Chioma: Meeting moved to 3pm', isGroup: true),
      _ForwardContact(name: 'Chidi Eze', lastMessage: 'Got it, thanks!', isGroup: false),
      _ForwardContact(name: 'Sunday Crew', lastMessage: 'You: Haha that was wild', isGroup: true),
      _ForwardContact(name: 'Fatima Ibrahim', lastMessage: 'Can you call me back?', isGroup: false),
      _ForwardContact(name: 'Project Alpha', lastMessage: 'Mike: PR is merged!', isGroup: true),
      _ForwardContact(name: 'Grace Adeyemi', lastMessage: 'Voice message (0:14)', isGroup: false),
    ];
  }

  void _toggleSelect(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else if (_selectedIndices.length < 5) {
        _selectedIndices.add(index);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You can forward to up to 5 chats at a time'),
            backgroundColor: KoraColors.purple,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  void _doForward() {
    if (_selectedIndices.isEmpty) return;
    final count = _selectedIndices.length;
    Navigator.pop(context, count);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.surfaceFor(brightness);
    final card = KoraColors.cardFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: card,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Forward to',
              style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
            if (_selectedIndices.isNotEmpty)
              Text('${_selectedIndices.length} selected',
                style: TextStyle(color: textSecondary, fontSize: 12)),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search',
                hintStyle: TextStyle(color: textSecondary, fontSize: 14),
                prefixIcon: Icon(Icons.search, color: textSecondary, size: 20),
                filled: true,
                fillColor: bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
        ),
      ),
      body: _filtered.isEmpty
          ? Center(child: Text('No chats found', style: TextStyle(color: textSecondary)))
          : ListView.builder(
              itemCount: _filtered.length,
              itemBuilder: (ctx, i) {
                final contact = _filtered[i];
                final realIndex = _allContacts.indexOf(contact);
                final selected = _selectedIndices.contains(realIndex);
                return _buildContactTile(contact, selected, realIndex, textPrimary, textSecondary);
              },
            ),
      floatingActionButton: _selectedIndices.isEmpty
          ? null
          : FloatingActionButton(
              backgroundColor: KoraColors.purple,
              onPressed: _doForward,
              child: const Icon(Icons.send, color: Colors.white),
            ),
    );
  }

  Widget _buildContactTile(
    _ForwardContact contact,
    bool selected,
    int index,
    Color textPrimary,
    Color textSecondary,
  ) {
    return InkWell(
      onTap: () => _toggleSelect(index),
      child: Container(
        color: selected ? KoraColors.purple.withValues(alpha: 0.06) : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: contact.isGroup ? KoraColors.brandGradient : null,
                color: contact.isGroup ? null : KoraColors.purple.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: contact.isGroup
                    ? const Icon(Icons.group, color: Colors.white, size: 22)
                    : Text(
                        contact.name[0].toUpperCase(),
                        style: const TextStyle(color: KoraColors.purple, fontWeight: FontWeight.w700, fontSize: 18),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(contact.name,
                    style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(contact.lastMessage,
                    style: TextStyle(color: textSecondary, fontSize: 13),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? KoraColors.purple : Colors.transparent,
                border: Border.all(
                  color: selected ? KoraColors.purple : textSecondary.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _ForwardContact {
  final String name;
  final String lastMessage;
  final bool isGroup;
  _ForwardContact({required this.name, required this.lastMessage, required this.isGroup});
}

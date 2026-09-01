import 'dart:convert';
import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import '../../services/contacts_service.dart';

/// Participant model for group calls (up to 32 participants).
class CallParticipant {
  final String id;
  final String name;
  final String? avatarUrl;
  final bool isHost;
  final bool isSelf;
  bool isMuted;
  bool isVideoOn;
  bool isSpeaking;

  CallParticipant({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.isHost = false,
    this.isSelf = false,
    this.isMuted = false,
    this.isVideoOn = true,
    this.isSpeaking = false,
  });

  CallParticipant copyWith({
    String? id,
    String? name,
    String? avatarUrl,
    bool? isHost,
    bool? isSelf,
    bool? isMuted,
    bool? isVideoOn,
    bool? isSpeaking,
  }) {
    return CallParticipant(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isHost: isHost ?? this.isHost,
      isSelf: isSelf ?? this.isSelf,
      isMuted: isMuted ?? this.isMuted,
      isVideoOn: isVideoOn ?? this.isVideoOn,
      isSpeaking: isSpeaking ?? this.isSpeaking,
    );
  }
}

/// Bottom sheet listing all call participants with mute/video status
/// and an 'Add' button to invite contacts (up to 32 participants max).
class GroupCallParticipantsSheet extends StatefulWidget {
  final List<CallParticipant> participants;
  final Function(CallParticipant participant)? onAddParticipant;
  final Function(String participantId)? onRemoveParticipant;
  final Function(String participantId, bool isMuted)? onToggleMute;
  final Function(String participantId, bool isVideoOn)? onToggleVideo;
  final int maxParticipants;

  const GroupCallParticipantsSheet({
    super.key,
    required this.participants,
    this.onAddParticipant,
    this.onRemoveParticipant,
    this.onToggleMute,
    this.onToggleVideo,
    this.maxParticipants = 32,
  });

  @override
  State<GroupCallParticipantsSheet> createState() => _GroupCallParticipantsSheetState();
}

class _GroupCallParticipantsSheetState extends State<GroupCallParticipantsSheet> {
  late List<CallParticipant> _participantsList;
  bool _isAddingContact = false;
  List<Map<String, Object?>> _availableContacts = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _participantsList = List.from(widget.participants);
    _loadAvailableContacts();
  }

  Future<void> _loadAvailableContacts() async {
    try {
      final contacts = await ContactsService.instance.getContacts();
      if (mounted) {
        setState(() {
          _availableContacts = contacts;
        });
      }
    } catch (e) {
      debugPrint('Error loading contacts for group call: $e');
    }
  }

  void _showAddContactSheet() {
    if (_participantsList.length >= widget.maxParticipants) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Maximum limit of ${widget.maxParticipants} participants reached.'),
          backgroundColor: KoraColors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isAddingContact = true;
      _searchQuery = '';
    });
  }

  void _addContactToCall(Map<String, Object?> contact) {
    if (_participantsList.length >= widget.maxParticipants) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Maximum limit of ${widget.maxParticipants} participants reached.'),
          backgroundColor: KoraColors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final name = (contact['name'] as String? ?? 'Contact').trim();
    final avatarUrl = contact['avatarUrl'] as String?;
    final koraId = (contact['koraId'] as String? ?? '').isNotEmpty
        ? (contact['koraId'] as String)
        : (contact['email'] as String? ?? name);

    // Check if already in call
    if (_participantsList.any((p) => p.name.toLowerCase() == name.toLowerCase() || p.id == koraId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$name is already in the call.'),
          backgroundColor: KoraColors.purple,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final newParticipant = CallParticipant(
      id: koraId,
      name: name,
      avatarUrl: avatarUrl,
      isHost: false,
      isSelf: false,
      isMuted: false,
      isVideoOn: true,
      isSpeaking: false,
    );

    setState(() {
      _participantsList.add(newParticipant);
      _isAddingContact = false;
    });

    if (widget.onAddParticipant != null) {
      widget.onAddParticipant!(newParticipant);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added $name to call (${_participantsList.length}/${widget.maxParticipants})'),
        backgroundColor: KoraColors.purple,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: KoraColors.deepNavy,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  if (_isAddingContact) ...[
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => setState(() => _isAddingContact = false),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    _isAddingContact
                        ? 'Add People (${_participantsList.length}/${widget.maxParticipants})'
                        : 'Participants (${_participantsList.length}/${widget.maxParticipants})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (!_isAddingContact) ...[
                    TextButton.icon(
                      onPressed: _participantsList.length < widget.maxParticipants
                          ? _showAddContactSheet
                          : null,
                      icon: Icon(
                        Icons.person_add_rounded,
                        size: 18,
                        color: _participantsList.length < widget.maxParticipants
                            ? KoraColors.purple
                            : Colors.white38,
                      ),
                      label: Text(
                        'Add',
                        style: TextStyle(
                          color: _participantsList.length < widget.maxParticipants
                              ? KoraColors.purple
                              : Colors.white38,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const Divider(color: Colors.white10, height: 1),

            // Body: Contact picker view OR Participants list
            Expanded(
              child: _isAddingContact
                  ? _buildAddContactView()
                  : _buildParticipantsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantsList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _participantsList.length,
      separatorBuilder: (_, __) => const Divider(color: Colors.white12, indent: 68),
      itemBuilder: (context, index) {
        final p = _participantsList[index];
        return ListTile(
          leading: Stack(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: p.isSpeaking
                    ? KoraColors.purple
                    : Colors.white.withValues(alpha: 0.12),
                backgroundImage: p.avatarUrl != null && p.avatarUrl!.isNotEmpty
                    ? (p.avatarUrl!.startsWith('data:')
                        ? MemoryImage(base64Decode(p.avatarUrl!.substring(p.avatarUrl!.indexOf(',') + 1))) as ImageProvider
                        : NetworkImage(p.avatarUrl!) as ImageProvider)
                    : null,
                child: p.avatarUrl == null || p.avatarUrl!.isEmpty
                    ? Text(
                        p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                        ),
                      )
                    : null,
              ),
              if (p.isSpeaking)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: KoraColors.purple,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.graphic_eq, color: Colors.white, size: 10),
                  ),
                ),
            ],
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  p.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (p.isSelf) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: KoraColors.purple.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'You',
                    style: TextStyle(
                      color: KoraColors.purple,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              if (p.isHost) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: KoraColors.brandGradient,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Host',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          subtitle: Text(
            p.isSpeaking
                ? 'Speaking…'
                : p.isMuted
                    ? 'Muted'
                    : 'Active',
            style: TextStyle(
              color: p.isSpeaking
                  ? KoraColors.purple
                  : p.isMuted
                      ? Colors.redAccent
                      : Colors.white.withValues(alpha: 0.5),
              fontSize: 13,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Mute status toggle button
              IconButton(
                icon: Icon(
                  p.isMuted ? Icons.mic_off : Icons.mic,
                  color: p.isMuted ? Colors.redAccent : Colors.white70,
                  size: 20,
                ),
                onPressed: () {
                  setState(() => p.isMuted = !p.isMuted);
                  if (widget.onToggleMute != null) {
                    widget.onToggleMute!(p.id, p.isMuted);
                  }
                },
              ),
              // Video status toggle button
              IconButton(
                icon: Icon(
                  p.isVideoOn ? Icons.videocam : Icons.videocam_off,
                  color: p.isVideoOn ? KoraColors.blue : Colors.white38,
                  size: 20,
                ),
                onPressed: () {
                  setState(() => p.isVideoOn = !p.isVideoOn);
                  if (widget.onToggleVideo != null) {
                    widget.onToggleVideo!(p.id, p.isVideoOn);
                  }
                },
              ),
              // Remove button (if not self and not host or current user is host)
              if (!p.isSelf)
                IconButton(
                  icon: Icon(
                    Icons.person_remove_outlined,
                    color: Colors.white.withValues(alpha: 0.4),
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _participantsList.removeWhere((item) => item.id == p.id);
                    });
                    if (widget.onRemoveParticipant != null) {
                      widget.onRemoveParticipant!(p.id);
                    }
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAddContactView() {
    // Use only real contacts loaded from ContactsService
    final sourceContacts = _availableContacts;

    // Filter contacts not currently in call
    final currentNames = _participantsList.map((p) => p.name.toLowerCase()).toSet();
    final filterable = sourceContacts.where((c) {
      final name = (c['name'] as String? ?? '').toLowerCase();
      if (currentNames.contains(name)) return false;
      if (_searchQuery.isNotEmpty) {
        return name.contains(_searchQuery.toLowerCase()) ||
            ((c['username'] as String? ?? '').toLowerCase().contains(_searchQuery.toLowerCase()));
      }
      return true;
    }).toList();

    if (sourceContacts.isEmpty && _searchQuery.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.contacts, size: 48, color: KoraColors.purple.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text('No contacts available to add', style: TextStyle(color: KoraColors.textMutedFor(Theme.of(context).brightness), fontSize: 14)),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Search field
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search contacts…',
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
              prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 20),
              filled: true,
              fillColor: KoraColors.darkCard,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        Expanded(
          child: filterable.isEmpty
              ? const Center(
                  child: Text(
                    'No contacts available to add',
                    style: TextStyle(color: Colors.white38, fontSize: 14),
                  ),
                )
              : ListView.builder(
                  itemCount: filterable.length,
                  itemBuilder: (context, index) {
                    final c = filterable[index];
                    final name = (c['name'] as String? ?? 'Contact').trim();
                    final username = c['username'] as String? ?? '';
                    final avatarUrl = c['avatarUrl'] as String?;

                    return ListTile(
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundColor: KoraColors.purple.withValues(alpha: 0.3),
                        backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                            ? NetworkImage(avatarUrl) as ImageProvider
                            : null,
                        child: avatarUrl == null || avatarUrl.isEmpty
                            ? Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                      subtitle: username.isNotEmpty
                          ? Text(username, style: const TextStyle(color: Colors.white54, fontSize: 12))
                          : null,
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: KoraColors.brandGradient,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Add',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      onTap: () => _addContactToCall(c),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/kora_colors.dart';

/// Group Permissions screen — mirrors WhatsApp's group settings.
///
/// WhatsApp sections:
/// 1. Send messages (All participants / Admins only)
/// 2. Group settings
///    - Edit group info
///    - Add members
///    - Add group description
/// 3. Admin permissions
///    - Approve new participants
///    - Send polls
class GroupPermissionsScreen extends StatefulWidget {
  final String? groupId;
  const GroupPermissionsScreen({super.key, this.groupId});
  @override
  State<GroupPermissionsScreen> createState() => _GroupPermissionsScreenState();
}

class _GroupPermissionsScreenState extends State<GroupPermissionsScreen> {
  int _sendMessages = 0; // 0 = all, 1 = admins only
  bool _editGroupInfo = true;
  bool _addMembers = true;
  bool _editDescription = true;
  bool _approveNewParticipants = false;
  bool _sendPolls = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final p = widget.groupId != null ? 'group_${widget.groupId}_' : 'group_default_';
    if (mounted) setState(() {
      _sendMessages = prefs.getInt('${p}send_messages') ?? 0;
      _editGroupInfo = prefs.getBool('${p}edit_info') ?? true;
      _addMembers = prefs.getBool('${p}add_members') ?? true;
      _editDescription = prefs.getBool('${p}edit_desc') ?? true;
      _approveNewParticipants = prefs.getBool('${p}approve_new') ?? false;
      _sendPolls = prefs.getBool('${p}send_polls') ?? true;
    });
  }

  Future<void> _save(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    final p = widget.groupId != null ? 'group_${widget.groupId}_' : 'group_default_';
    if (value is int) await prefs.setInt('$p$key', value);
    else await prefs.setBool('$p$key', value);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);
    final border = KoraColors.borderFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: Text('Group permissions', style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
        leading: IconButton(icon: Icon(Icons.arrow_back, color: textPrimary), onPressed: () => Navigator.pop(context)),
      ),
      body: ListView(
        children: [
          // Send messages
          _sectionLabel('Send messages', textMuted),
          Container(
            color: surface,
            child: Column(
              children: [
                RadioListTile<int>(
                  value: 0,
                  groupValue: _sendMessages,
                  activeColor: KoraColors.purple,
                  title: Text('All participants', style: TextStyle(color: textPrimary)),
                  onChanged: (v) { setState(() => _sendMessages = v!); _save('send_messages', v!); },
                ),
                RadioListTile<int>(
                  value: 1,
                  groupValue: _sendMessages,
                  activeColor: KoraColors.purple,
                  title: Text('Admins only', style: TextStyle(color: textPrimary)),
                  onChanged: (v) { setState(() => _sendMessages = v!); _save('send_messages', v!); },
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Group settings
          _sectionLabel('Group settings', textMuted),
          Container(
            color: surface,
            child: Column(
              children: [
                SwitchListTile(
                  value: _editGroupInfo,
                  activeColor: KoraColors.purple,
                  activeTrackColor: KoraColors.purple.withValues(alpha: 0.3),
                  title: Text('Edit group info', style: TextStyle(color: textPrimary, fontSize: 15)),
                  subtitle: Text('Allow all participants to edit', style: TextStyle(color: textMuted, fontSize: 13)),
                  onChanged: (v) { setState(() => _editGroupInfo = v); _save('edit_info', v); },
                ),
                _divider(border),
                SwitchListTile(
                  value: _addMembers,
                  activeColor: KoraColors.purple,
                  activeTrackColor: KoraColors.purple.withValues(alpha: 0.3),
                  title: Text('Add members', style: TextStyle(color: textPrimary, fontSize: 15)),
                  subtitle: Text('Allow all participants to add', style: TextStyle(color: textMuted, fontSize: 13)),
                  onChanged: (v) { setState(() => _addMembers = v); _save('add_members', v); },
                ),
                _divider(border),
                SwitchListTile(
                  value: _editDescription,
                  activeColor: KoraColors.purple,
                  activeTrackColor: KoraColors.purple.withValues(alpha: 0.3),
                  title: Text('Add group description', style: TextStyle(color: textPrimary, fontSize: 15)),
                  subtitle: Text('Allow all participants to edit description', style: TextStyle(color: textMuted, fontSize: 13)),
                  onChanged: (v) { setState(() => _editDescription = v); _save('edit_desc', v); },
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Admin permissions
          _sectionLabel('Admin permissions', textMuted),
          Container(
            color: surface,
            child: Column(
              children: [
                SwitchListTile(
                  value: _approveNewParticipants,
                  activeColor: KoraColors.purple,
                  activeTrackColor: KoraColors.purple.withValues(alpha: 0.3),
                  title: Text('Approve new participants', style: TextStyle(color: textPrimary, fontSize: 15)),
                  subtitle: Text('Require admin approval to join', style: TextStyle(color: textMuted, fontSize: 13)),
                  onChanged: (v) { setState(() => _approveNewParticipants = v); _save('approve_new', v); },
                ),
                _divider(border),
                SwitchListTile(
                  value: _sendPolls,
                  activeColor: KoraColors.purple,
                  activeTrackColor: KoraColors.purple.withValues(alpha: 0.3),
                  title: Text('Send polls', style: TextStyle(color: textPrimary, fontSize: 15)),
                  subtitle: Text('Allow all participants to create polls', style: TextStyle(color: textMuted, fontSize: 13)),
                  onChanged: (v) { setState(() => _sendPolls = v); _save('send_polls', v); },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(text, style: TextStyle(color: KoraColors.purple, fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }

  Widget _divider(Color border) => Padding(padding: const EdgeInsets.only(left: 16), child: Divider(height: 1, color: border.withValues(alpha: 0.3)));
}

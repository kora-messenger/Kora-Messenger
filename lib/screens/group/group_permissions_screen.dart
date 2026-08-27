import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/kora_colors.dart';

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

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = widget.groupId != null ? 'group_${widget.groupId}_' : 'group_default_';
    setState(() {
      _sendMessages = prefs.getInt('${prefix}send_messages') ?? 0;
      _editGroupInfo = prefs.getBool('${prefix}edit_info') ?? true;
      _addMembers = prefs.getBool('${prefix}add_members') ?? true;
    });
  }

  Future<void> _save(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = widget.groupId != null ? 'group_${widget.groupId}_' : 'group_default_';
    if (value is int) {
      await prefs.setInt('$prefix$key', value);
    } else {
      await prefs.setBool('$prefix$key', value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KoraColors.surface,
      appBar: AppBar(
        backgroundColor: KoraColors.surface,
        title: const Text('Group permissions', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        children: [
          _sectionHeader('Send messages'),
          RadioListTile<int>(
            value: 0,
            groupValue: _sendMessages,
            activeColor: KoraColors.purple,
            title: const Text('All participants', style: TextStyle(color: Colors.white)),
            onChanged: (v) { setState(() => _sendMessages = v!); _save('send_messages', v!); },
          ),
          RadioListTile<int>(
            value: 1,
            groupValue: _sendMessages,
            activeColor: KoraColors.purple,
            title: const Text('Admins only', style: TextStyle(color: Colors.white)),
            onChanged: (v) { setState(() => _sendMessages = v!); _save('send_messages', v!); },
          ),
          const Divider(color: Colors.white24),
          _sectionHeader('Group settings'),
          SwitchListTile(
            value: _editGroupInfo,
            activeColor: KoraColors.purple,
            title: const Text('Edit group info', style: TextStyle(color: Colors.white)),
            subtitle: Text('Allow all participants to edit', style: TextStyle(color: KoraColors.textMuted, fontSize: 12)),
            onChanged: (v) { setState(() => _editGroupInfo = v); _save('edit_info', v); },
          ),
          SwitchListTile(
            value: _addMembers,
            activeColor: KoraColors.purple,
            title: const Text('Add members', style: TextStyle(color: Colors.white)),
            subtitle: Text('Allow all participants to add', style: TextStyle(color: KoraColors.textMuted, fontSize: 12)),
            onChanged: (v) { setState(() => _addMembers = v); _save('add_members', v); },
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title, style: TextStyle(color: KoraColors.purple, fontSize: 14, fontWeight: FontWeight.w600)),
    );
  }
}

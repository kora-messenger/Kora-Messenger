import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../theme/kora_colors.dart';

/// Business Tools screen — WhatsApp Business-style business tools hub.
///
/// Entry point for all business features:
/// - Business Profile (name, category, address, description, website, email)
/// - Catalog (product/service listings)
/// - Quick Replies (shortcut templates)
/// - Away Message (auto-reply with schedule)
/// - Greeting Message (auto-welcome new customers)
/// - Labels (color-coded chat organization)
/// - Business Hours (operating schedule)
/// - Order Status (track customer orders)
class BusinessToolsScreen extends StatefulWidget {
  const BusinessToolsScreen({super.key});

  @override
  State<BusinessToolsScreen> createState() => _BusinessToolsScreenState();
}

class _BusinessToolsScreenState extends State<BusinessToolsScreen> {
  bool _isBusinessAccount = false;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _isBusinessAccount = prefs.getBool('kora_business_account') ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);
    final border = KoraColors.borderFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: Text('Business Tools',
            style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // Profile section
          _sectionLabel('PROFILE', textMuted),
          _navTile(
            context, surface, textPrimary, textMuted, border,
            icon: Icons.store, color: KoraColors.purple,
            title: 'Business Profile',
            subtitle: 'Name, category, address, description',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BusinessProfileEditScreen())),
          ),

          // Catalog
          _sectionLabel('CATALOG', textMuted),
          _navTile(
            context, surface, textPrimary, textMuted, border,
            icon: Icons.inventory_2_outlined, color: KoraColors.purple,
            title: 'Catalog',
            subtitle: 'Showcase your products and services',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CatalogScreen())),
          ),

          // Messaging
          _sectionLabel('MESSAGING', textMuted),
          _navTile(
            context, surface, textPrimary, textMuted, border,
            icon: Icons.quickreply_outlined, color: KoraColors.purple,
            title: 'Quick Replies',
            subtitle: 'Create shortcuts for frequent messages',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QuickRepliesScreen())),
          ),
          _navTile(
            context, surface, textPrimary, textMuted, border,
            icon: Icons.near_me_outlined, color: KoraColors.purple,
            title: 'Away Message',
            subtitle: 'Auto-reply when you're unavailable',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AwayMessageScreen())),
          ),
          _navTile(
            context, surface, textPrimary, textMuted, border,
            icon: Icons.waving_hand_outlined, color: KoraColors.purple,
            title: 'Greeting Message',
            subtitle: 'Welcome new customers automatically',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GreetingMessageScreen())),
          ),

          // Organization
          _sectionLabel('ORGANIZATION', textMuted),
          _navTile(
            context, surface, textPrimary, textMuted, border,
            icon: Icons.label_outline, color: KoraColors.purple,
            title: 'Labels',
            subtitle: 'Organize chats with color labels',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LabelsScreen())),
          ),
          _navTile(
            context, surface, textPrimary, textMuted, border,
            icon: Icons.schedule_outlined, color: KoraColors.purple,
            title: 'Business Hours',
            subtitle: 'Set your operating schedule',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BusinessHoursScreen())),
          ),

          // Orders
          _sectionLabel('ORDERS', textMuted),
          _navTile(
            context, surface, textPrimary, textMuted, border,
            icon: Icons.receipt_long_outlined, color: KoraColors.purple,
            title: 'Order Status',
            subtitle: 'Track and update customer orders',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrderStatusScreen())),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(label, style: TextStyle(color: KoraColors.purple, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
    );
  }

  Widget _navTile(
    BuildContext context, Color surface, Color textPrimary, Color textMuted, Color border, {
    required IconData icon, required Color color,
    required String title, required String subtitle, required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: surface, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border, width: 0.5),
      ),
      child: ListTile(
        leading: Icon(icon, color: color, size: 26),
        title: Text(title, style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle, style: TextStyle(color: textMuted, fontSize: 13)),
        trailing: Icon(Icons.chevron_right, color: textMuted, size: 20),
        onTap: onTap,
      ),
    );
  }
}

// ── Business Profile Edit ─────────────────────────────────────────

class BusinessProfileEditScreen extends StatefulWidget {
  const BusinessProfileEditScreen({super.key});
  @override
  State<BusinessProfileEditScreen> createState() => _BusinessProfileEditScreenState();
}

class _BusinessProfileEditScreenState extends State<BusinessProfileEditScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  String _category = 'Retail';

  static const _categories = ['Retail', 'Food & Beverage', 'Services', 'Health & Beauty', 'Technology', 'Fashion', 'Education', 'Other'];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameCtrl.text = prefs.getString('kora_biz_name') ?? '';
      _descCtrl.text = prefs.getString('kora_biz_desc') ?? '';
      _addressCtrl.text = prefs.getString('kora_biz_address') ?? '';
      _emailCtrl.text = prefs.getString('kora_biz_email') ?? '';
      _websiteCtrl.text = prefs.getString('kora_biz_website') ?? '';
      _category = prefs.getString('kora_biz_category') ?? 'Retail';
    });
  }

  Future<void> _saveProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('kora_biz_name', _nameCtrl.text);
    await prefs.setString('kora_biz_desc', _descCtrl.text);
    await prefs.setString('kora_biz_address', _addressCtrl.text);
    await prefs.setString('kora_biz_email', _emailCtrl.text);
    await prefs.setString('kora_biz_website', _websiteCtrl.text);
    await prefs.setString('kora_biz_category', _category);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Business profile saved'), backgroundColor: KoraColors.purple, behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: Text('Business Profile', style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
        leading: IconButton(icon: Icon(Icons.arrow_back, color: textPrimary), onPressed: () => Navigator.pop(context)),
        actions: [TextButton(onPressed: _saveProfile, child: Text('Save', style: TextStyle(color: KoraColors.purple, fontWeight: FontWeight.w600)))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Avatar
          Center(
            child: Container(
              width: 80, height: 80,
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [KoraColors.purple, KoraColors.blue]), shape: BoxShape.circle),
              child: const Icon(Icons.store, color: Colors.white, size: 36),
            ),
          ),
          const SizedBox(height: 24),

          _field('Business name', _nameCtrl, surface, textPrimary, textMuted, 'e.g. Kora Store'),
          const SizedBox(height: 12),
          _dropdown('Category', surface, textPrimary, textMuted),
          const SizedBox(height: 12),
          _field('Description', _descCtrl, surface, textPrimary, textMuted, 'Tell customers about your business', maxLines: 3),
          const SizedBox(height: 12),
          _field('Address', _addressCtrl, surface, textPrimary, textMuted, 'Street, City, State'),
          const SizedBox(height: 12),
          _field('Email', _emailCtrl, surface, textPrimary, textMuted, 'business@example.com'),
          const SizedBox(height: 12),
          _field('Website', _websiteCtrl, surface, textPrimary, textMuted, 'https://example.com'),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, Color surface, Color textPrimary, Color textMuted, String hint, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: KoraColors.purple, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl, maxLines: maxLines,
          style: TextStyle(color: textPrimary, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint, hintStyle: TextStyle(color: textMuted, fontSize: 14),
            filled: true, fillColor: surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _dropdown(String label, Color surface, Color textPrimary, Color textMuted) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: KoraColors.purple, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(12)),
          child: DropdownButton<String>(
            value: _category, underline: const SizedBox(), isExpanded: true,
            items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: TextStyle(color: textPrimary, fontSize: 15)))).toList(),
            onChanged: (v) { if (v != null) setState(() => _category = v); },
          ),
        ),
      ],
    );
  }
}

// ── Catalog ──────────────────────────────────────────────────────

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});
  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString('kora_catalog_items') ?? '[]';
    setState(() => _items = List<Map<String, dynamic>>.from(jsonDecode(str)));
  }

  Future<void> _saveItems() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('kora_catalog_items', jsonEncode(_items));
  }

  void _addItem() {
    _showEditDialog(isEdit: false);
  }

  void _editItem(int index) {
    _showEditDialog(isEdit: true, index: index);
  }

  void _showEditDialog({required bool isEdit, int? index}) {
    final nameCtrl = TextEditingController(text: isEdit ? _items[index!]['name'] : '');
    final priceCtrl = TextEditingController(text: isEdit ? _items[index!]['price'] : '');
    final descCtrl = TextEditingController(text: isEdit ? _items[index!]['description'] : '');
    final type = isEdit ? _items[index!]['type'] ?? 'Product' : 'Product';

    showDialog(
      context: context,
      builder: (ctx) {
        String currentType = type;
        return StatefulBuilder(
          builder: (ctx, setDialog) {
            final brightness = Theme.of(context).brightness;
            final surface = KoraColors.surfaceFor(brightness);
            final textPrimary = KoraColors.textPrimaryFor(brightness);
            final textMuted = KoraColors.textMutedFor(brightness);
            return AlertDialog(
              backgroundColor: KoraColors.cardFor(brightness),
              title: Text(isEdit ? 'Edit Item' : 'Add Item', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Type toggle
                    Row(
                      children: [
                        ChoiceChip(label: const Text('Product'), selected: currentType == 'Product', onSelected: (v) => setDialog(() => currentType = 'Product')),
                        const SizedBox(width: 8),
                        ChoiceChip(label: const Text('Service'), selected: currentType == 'Service', onSelected: (v) => setDialog(() => currentType = 'Service')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: nameCtrl, style: TextStyle(color: textPrimary),
                      decoration: InputDecoration(hintText: 'Item name', hintStyle: TextStyle(color: textMuted),
                        filled: true, fillColor: surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none))),
                    const SizedBox(height: 8),
                    TextField(controller: priceCtrl, style: TextStyle(color: textPrimary), keyboardType: TextInputType.number,
                      decoration: InputDecoration(hintText: 'Price (₦)', hintStyle: TextStyle(color: textMuted),
                        filled: true, fillColor: surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none))),
                    const SizedBox(height: 8),
                    TextField(controller: descCtrl, style: TextStyle(color: textPrimary), maxLines: 2,
                      decoration: InputDecoration(hintText: 'Description', hintStyle: TextStyle(color: textMuted),
                        filled: true, fillColor: surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none))),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: textMuted))),
                ElevatedButton(
                  onPressed: () {
                    final item = {'name': nameCtrl.text, 'price': priceCtrl.text, 'description': descCtrl.text, 'type': currentType, 'id': DateTime.now().millisecondsSinceEpoch};
                    setState(() {
                      if (isEdit) { _items[index!] = item; } else { _items.add(item); }
                    });
                    _saveItems();
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: KoraColors.purple, foregroundColor: Colors.white),
                  child: Text(isEdit ? 'Update' : 'Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteItem(int index) {
    setState(() => _items.removeAt(index));
    _saveItems();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: Text('Catalog', style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
        leading: IconButton(icon: Icon(Icons.arrow_back, color: textPrimary), onPressed: () => Navigator.pop(context)),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addItem,
        backgroundColor: KoraColors.purple,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 56, color: KoraColors.purple.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text('No items yet', style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Add products or services to your catalog', style: TextStyle(color: textMuted, fontSize: 14)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              itemBuilder: (context, i) {
                final item = _items[i];
                return Dismissible(
                  key: Key('${item['id']}'),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) => _deleteItem(i),
                  background: Container(
                    alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20),
                    color: Colors.red, child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  child: GestureDetector(
                    onTap: () => _editItem(i),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(
                              color: item['type'] == 'Service' ? KoraColors.blue.withValues(alpha: 0.15) : KoraColors.purple.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(item['type'] == 'Service' ? Icons.handshake_outlined : Icons.inventory,
                                color: item['type'] == 'Service' ? KoraColors.blue : KoraColors.purple, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item['name'] ?? '', style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                                if (item['description'] != null && item['description'].isNotEmpty)
                                  Text(item['description'], style: TextStyle(color: textMuted, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('₦${item['price'] ?? '0'}', style: TextStyle(color: KoraColors.purple, fontSize: 15, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ── Quick Replies ─────────────────────────────────────────────────

class QuickRepliesScreen extends StatefulWidget {
  const QuickRepliesScreen({super.key});
  @override
  State<QuickRepliesScreen> createState() => _QuickRepliesScreenState();
}

class _QuickRepliesScreenState extends State<QuickRepliesScreen> {
  List<Map<String, String>> _replies = [];

  @override
  void initState() {
    super.initState();
    _loadReplies();
  }

  Future<void> _loadReplies() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString('kora_quick_replies') ?? '[]';
    setState(() => _replies = List<Map<String, String>>.from(jsonDecode(str).map((x) => Map<String, String>.from(x))));
  }

  Future<void> _saveReplies() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('kora_quick_replies', jsonEncode(_replies));
  }

  void _addOrEdit({int? index}) {
    final shortcutCtrl = TextEditingController(text: index != null ? _replies[index!]['shortcut'] : '');
    final messageCtrl = TextEditingController(text: index != null ? _replies[index!]['message'] : '');

    showDialog(
      context: context,
      builder: (ctx) {
        final brightness = Theme.of(context).brightness;
        final surface = KoraColors.surfaceFor(brightness);
        final textPrimary = KoraColors.textPrimaryFor(brightness);
        final textMuted = KoraColors.textMutedFor(brightness);
        return AlertDialog(
          backgroundColor: KoraColors.cardFor(brightness),
          title: Text(index != null ? 'Edit Quick Reply' : 'New Quick Reply', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: shortcutCtrl, style: TextStyle(color: textPrimary),
                decoration: InputDecoration(hintText: '/shortcut', hintStyle: TextStyle(color: textMuted),
                  filled: true, fillColor: surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)),
              ),
              const SizedBox(height: 8),
              TextField(controller: messageCtrl, style: TextStyle(color: textPrimary), maxLines: 3,
                decoration: InputDecoration(hintText: 'Message text', hintStyle: TextStyle(color: textMuted),
                  filled: true, fillColor: surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: textMuted))),
            ElevatedButton(
              onPressed: () {
                final s = shortcutCtrl.text.trim();
                final m = messageCtrl.text.trim();
                if (s.isEmpty || m.isEmpty) return;
                setState(() {
                  if (index != null) { _replies[index!] = {'shortcut': s, 'message': m}; }
                  else { _replies.add({'shortcut': s, 'message': m}); }
                });
                _saveReplies();
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: KoraColors.purple, foregroundColor: Colors.white),
              child: Text(index != null ? 'Update' : 'Add'),
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
    final surface = KoraColors.surfaceFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: Text('Quick Replies', style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
        leading: IconButton(icon: Icon(Icons.arrow_back, color: textPrimary), onPressed: () => Navigator.pop(context)),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEdit(), backgroundColor: KoraColors.purple, child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _replies.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.quickreply_outlined, size: 56, color: KoraColors.purple.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text('No quick replies', style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Create shortcuts like /greeting to send messages faster', style: TextStyle(color: textMuted, fontSize: 14), textAlign: TextAlign.center),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _replies.length,
              itemBuilder: (context, i) => GestureDetector(
                onTap: () => _addOrEdit(index: i),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(10)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_replies[i]['shortcut']!, style: TextStyle(color: KoraColors.purple, fontSize: 14, fontWeight: FontWeight.w700)),
                      Text(_replies[i]['message']!, style: TextStyle(color: textMuted, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

// ── Away Message ──────────────────────────────────────────────────

class AwayMessageScreen extends StatefulWidget {
  const AwayMessageScreen({super.key});
  @override
  State<AwayMessageScreen> createState() => _AwayMessageScreenState();
}

class _AwayMessageScreenState extends State<AwayMessageScreen> {
  bool _enabled = false;
  final _msgCtrl = TextEditingController();
  String _schedule = 'always'; // always, custom
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);
  List<bool> _days = [true, true, true, true, true, false, false]; // Mon-Sun

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _enabled = prefs.getBool('kora_away_enabled') ?? false;
      _msgCtrl.text = prefs.getString('kora_away_msg') ?? 'Hi, I'm currently unavailable. I'll get back to you soon.';
      _schedule = prefs.getString('kora_away_schedule') ?? 'always';
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('kora_away_enabled', _enabled);
    await prefs.setString('kora_away_msg', _msgCtrl.text);
    await prefs.setString('kora_away_schedule', _schedule);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: Text('Away Message', style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
        leading: IconButton(icon: Icon(Icons.arrow_back, color: textPrimary), onPressed: () { _save(); Navigator.pop(context); }),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: Text('Send away message', style: TextStyle(color: textPrimary, fontSize: 15)),
            subtitle: Text('Auto-reply when you can't respond', style: TextStyle(color: textMuted, fontSize: 13)),
            value: _enabled, onChanged: (v) { setState(() => _enabled = v); _save(); }, activeColor: KoraColors.purple,
          ),
          const Divider(height: 32),
          Text('MESSAGE', style: TextStyle(color: KoraColors.purple, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          TextField(
            controller: _msgCtrl, maxLines: 4, enabled: _enabled,
            style: TextStyle(color: textPrimary, fontSize: 15),
            decoration: InputDecoration(
              filled: true, fillColor: surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 24),
          Text('SCHEDULE', style: TextStyle(color: KoraColors.purple, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          RadioListTile<String>(
            title: Text('Always send', style: TextStyle(color: textPrimary)), value: 'always', groupValue: _schedule,
            onChanged: _enabled ? (v) { setState(() => _schedule = v!); _save(); } : null, activeColor: KoraColors.purple,
          ),
          RadioListTile<String>(
            title: Text('Custom schedule', style: TextStyle(color: textPrimary)), value: 'custom', groupValue: _schedule,
            onChanged: _enabled ? (v) { setState(() => _schedule = v!); _save(); } : null, activeColor: KoraColors.purple,
          ),
          if (_enabled && _schedule == 'custom') ...[
            const SizedBox(height: 8),
            Text('ACTIVE DAYS', style: TextStyle(color: KoraColors.purple, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            ...['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].asMap().entries.map((e) =>
              SwitchListTile(
                title: Text(e.value, style: TextStyle(color: textPrimary, fontSize: 14)),
                value: _days[e.key], onChanged: (v) => setState(() => _days[e.key] = v), activeColor: KoraColors.purple,
              ),
            ),
            ListTile(
              title: Text('Start time', style: TextStyle(color: textPrimary)),
              trailing: Text('${_startTime.format(context)}', style: TextStyle(color: KoraColors.purple, fontWeight: FontWeight.w600)),
              onTap: () async {
                final t = await showTimePicker(context: context, initialTime: _startTime);
                if (t != null) setState(() => _startTime = t);
              },
            ),
            ListTile(
              title: Text('End time', style: TextStyle(color: textPrimary)),
              trailing: Text('${_endTime.format(context)}', style: TextStyle(color: KoraColors.purple, fontWeight: FontWeight.w600)),
              onTap: () async {
                final t = await showTimePicker(context: context, initialTime: _endTime);
                if (t != null) setState(() => _endTime = t);
              },
            ),
          ],
        ],
      ),
    );
  }
}

// ── Greeting Message ──────────────────────────────────────────────

class GreetingMessageScreen extends StatefulWidget {
  const GreetingMessageScreen({super.key});
  @override
  State<GreetingMessageScreen> createState() => _GreetingMessageScreenState();
}

class _GreetingMessageScreenState extends State<GreetingMessageScreen> {
  bool _enabled = false;
  final _msgCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _enabled = prefs.getBool('kora_greeting_enabled') ?? false;
      _msgCtrl.text = prefs.getString('kora_greeting_msg') ?? 'Hello! Thanks for reaching out. How can I help you today?';
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('kora_greeting_enabled', _enabled);
    await prefs.setString('kora_greeting_msg', _msgCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: Text('Greeting Message', style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
        leading: IconButton(icon: Icon(Icons.arrow_back, color: textPrimary), onPressed: () { _save(); Navigator.pop(context); }),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: Text('Send greeting message', style: TextStyle(color: textPrimary, fontSize: 15)),
            subtitle: Text('Auto-welcome new customers', style: TextStyle(color: textMuted, fontSize: 13)),
            value: _enabled, onChanged: (v) { setState(() => _enabled = v); _save(); }, activeColor: KoraColors.purple,
          ),
          const Divider(height: 32),
          Text('MESSAGE', style: TextStyle(color: KoraColors.purple, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          TextField(
            controller: _msgCtrl, maxLines: 4, enabled: _enabled,
            style: TextStyle(color: textPrimary, fontSize: 15),
            decoration: InputDecoration(
              filled: true, fillColor: surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: KoraColors.purple.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: KoraColors.purple),
                const SizedBox(width: 8),
                Expanded(child: Text('Greeting is sent once per new customer who messages you.', style: TextStyle(color: KoraColors.purple, fontSize: 12))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Labels ─────────────────────────────────────────────────────────

class LabelsScreen extends StatefulWidget {
  const LabelsScreen({super.key});
  @override
  State<LabelsScreen> createState() => _LabelsScreenState();
}

class _LabelsScreenState extends State<LabelsScreen> {
  List<Map<String, dynamic>> _labels = [];

  static const _colors = [
    {'name': 'Red', 'color': Colors.red},
    {'name': 'Orange', 'color': Colors.orange},
    {'name': 'Yellow', 'color': Colors.amber},
    {'name': 'Green', 'color': Colors.green},
    {'name': 'Blue', 'color': Colors.blue},
    {'name': 'Purple', 'color': KoraColors.purple},
  ];

  @override
  void initState() {
    super.initState();
    _loadLabels();
  }

  Future<void> _loadLabels() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString('kora_labels') ?? '[]';
    setState(() => _labels = List<Map<String, dynamic>>.from(jsonDecode(str)));
  }

  Future<void> _saveLabels() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('kora_labels', jsonEncode(_labels));
  }

  void _addLabel() {
    final nameCtrl = TextEditingController();
    int selectedColor = 0;

    showDialog(
      context: context,
      builder: (ctx) {
        final brightness = Theme.of(context).brightness;
        final surface = KoraColors.surfaceFor(brightness);
        final textPrimary = KoraColors.textPrimaryFor(brightness);
        final textMuted = KoraColors.textMutedFor(brightness);
        return StatefulBuilder(
          builder: (ctx, setDialog) => AlertDialog(
            backgroundColor: KoraColors.cardFor(brightness),
            title: Text('New Label', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, style: TextStyle(color: textPrimary),
                  decoration: InputDecoration(hintText: 'Label name', hintStyle: TextStyle(color: textMuted),
                    filled: true, fillColor: surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none))),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: _colors.asMap().entries.map((e) {
                    return GestureDetector(
                      onTap: () => setDialog(() => selectedColor = e.key),
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: e.value['color'] as Color,
                          shape: BoxShape.circle,
                          border: selectedColor == e.key ? Border.all(color: textPrimary, width: 3) : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: textMuted))),
              ElevatedButton(
                onPressed: () {
                  if (nameCtrl.text.trim().isEmpty) return;
                  setState(() => _labels.add({'name': nameCtrl.text.trim(), 'colorIndex': selectedColor, 'id': DateTime.now().millisecondsSinceEpoch}));
                  _saveLabels();
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(backgroundColor: KoraColors.purple, foregroundColor: Colors.white),
                child: const Text('Add'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: Text('Labels', style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
        leading: IconButton(icon: Icon(Icons.arrow_back, color: textPrimary), onPressed: () => Navigator.pop(context)),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addLabel, backgroundColor: KoraColors.purple, child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _labels.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.label_outline, size: 56, color: KoraColors.purple.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text('No labels yet', style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Organize your chats with color-coded labels', style: TextStyle(color: textMuted, fontSize: 14), textAlign: TextAlign.center),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _labels.length,
              itemBuilder: (context, i) {
                final label = _labels[i];
                final color = _colors[label['colorIndex'] ?? 0]['color'] as Color;
                return Dismissible(
                  key: Key('${label['id']}'),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) { setState(() => _labels.removeAt(i)); _saveLabels(); },
                  background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), color: Colors.red, child: const Icon(Icons.delete, color: Colors.white)),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      children: [
                        Icon(Icons.label, color: color, size: 22),
                        const SizedBox(width: 12),
                        Text(label['name'], style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                          child: Text('0 chats', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ── Business Hours ────────────────────────────────────────────────

class BusinessHoursScreen extends StatefulWidget {
  const BusinessHoursScreen({super.key});
  @override
  State<BusinessHoursScreen> createState() => _BusinessHoursScreenState();
}

class _BusinessHoursScreenState extends State<BusinessHoursScreen> {
  List<bool> _open = [];
  List<TimeOfDay> _start = [];
  List<TimeOfDay> _end = [];
  static const _dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  @override
  void initState() {
    super.initState();
    _loadHours();
  }

  Future<void> _loadHours() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString('kora_business_hours') ?? '';
    if (str.isNotEmpty) {
      final data = jsonDecode(str);
      setState(() {
        _open = List<bool>.from(data['open']);
        _start = (data['start'] as List).map((t) => TimeOfDay(hour: t['h'], minute: t['m'])).toList();
        _end = (data['end'] as List).map((t) => TimeOfDay(hour: t['h'], minute: t['m'])).toList();
      });
    } else {
      setState(() {
        _open = [true, true, true, true, true, false, false];
        _start = List.filled(7, const TimeOfDay(hour: 9, minute: 0));
        _end = List.filled(7, const TimeOfDay(hour: 17, minute: 0));
      });
    }
  }

  Future<void> _saveHours() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('kora_business_hours', jsonEncode({
      'open': _open,
      'start': _start.map((t) => {'h': t.hour, 'm': t.minute}).toList(),
      'end': _end.map((t) => {'h': t.hour, 'm': t.minute}).toList(),
    }));
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: Text('Business Hours', style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
        leading: IconButton(icon: Icon(Icons.arrow_back, color: textPrimary), onPressed: () { _saveHours(); Navigator.pop(context); }),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 7,
        itemBuilder: (context, i) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(10)),
          child: Column(
            children: [
              SwitchListTile(
                title: Text(_dayNames[i], style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
                value: _open[i], onChanged: (v) { setState(() => _open[i] = v); _saveHours(); }, activeColor: KoraColors.purple,
                contentPadding: EdgeInsets.zero,
              ),
              if (_open[i])
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final t = await showTimePicker(context: context, initialTime: _start[i]);
                          if (t != null) { setState(() => _start[i] = t); _saveHours(); }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(color: KoraColors.purple.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                          child: Text('${_start[i].format(context)}', style: TextStyle(color: KoraColors.purple, fontSize: 14, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('to', style: TextStyle(color: textMuted))),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final t = await showTimePicker(context: context, initialTime: _end[i]);
                          if (t != null) { setState(() => _end[i] = t); _saveHours(); }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(color: KoraColors.purple.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                          child: Text('${_end[i].format(context)}', style: TextStyle(color: KoraColors.purple, fontSize: 14, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Order Status ──────────────────────────────────────────────────

class OrderStatusScreen extends StatefulWidget {
  const OrderStatusScreen({super.key});
  @override
  State<OrderStatusScreen> createState() => _OrderStatusScreenState();
}

class _OrderStatusScreenState extends State<OrderStatusScreen> {
  List<Map<String, dynamic>> _orders = [];

  static const _statuses = ['Pending', 'Processing', 'Shipped', 'Delivered', 'Cancelled'];
  static const _statusColors = [Colors.orange, Colors.blue, Colors.purple, Colors.green, Colors.red];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString('kora_orders') ?? '[]';
    setState(() => _orders = List<Map<String, dynamic>>.from(jsonDecode(str)));
  }

  Future<void> _saveOrders() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('kora_orders', jsonEncode(_orders));
  }

  void _addOrder() {
    final customerCtrl = TextEditingController();
    final itemCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    int statusIndex = 0;

    showDialog(
      context: context,
      builder: (ctx) {
        final brightness = Theme.of(context).brightness;
        final surface = KoraColors.surfaceFor(brightness);
        final textPrimary = KoraColors.textPrimaryFor(brightness);
        final textMuted = KoraColors.textMutedFor(brightness);
        return StatefulBuilder(
          builder: (ctx, setDialog) => AlertDialog(
            backgroundColor: KoraColors.cardFor(brightness),
            title: Text('New Order', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: customerCtrl, style: TextStyle(color: textPrimary),
                    decoration: InputDecoration(hintText: 'Customer name', hintStyle: TextStyle(color: textMuted),
                      filled: true, fillColor: surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none))),
                  const SizedBox(height: 8),
                  TextField(controller: itemCtrl, style: TextStyle(color: textPrimary),
                    decoration: InputDecoration(hintText: 'Item(s)', hintStyle: TextStyle(color: textMuted),
                      filled: true, fillColor: surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none))),
                  const SizedBox(height: 8),
                  TextField(controller: priceCtrl, style: TextStyle(color: textPrimary), keyboardType: TextInputType.number,
                    decoration: InputDecoration(hintText: 'Total (₦)', hintStyle: TextStyle(color: textMuted),
                      filled: true, fillColor: surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none))),
                  const SizedBox(height: 12),
                  Text('Status', style: TextStyle(color: KoraColors.purple, fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: _statuses.asMap().entries.map((e) => ChoiceChip(
                      label: Text(e.value, style: TextStyle(fontSize: 12)),
                      selected: statusIndex == e.key,
                      selectedColor: _statusColors[e.key].withValues(alpha: 0.3),
                      onSelected: (_) => setDialog(() => statusIndex = e.key),
                    )).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: textMuted))),
              ElevatedButton(
                onPressed: () {
                  if (customerCtrl.text.trim().isEmpty) return;
                  setState(() => _orders.add({
                    'customer': customerCtrl.text.trim(), 'item': itemCtrl.text.trim(),
                    'price': priceCtrl.text.trim(), 'status': statusIndex,
                    'id': DateTime.now().millisecondsSinceEpoch,
                  }));
                  _saveOrders();
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(backgroundColor: KoraColors.purple, foregroundColor: Colors.white),
                child: const Text('Add'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _cycleStatus(int index) {
    setState(() {
      _orders[index]['status'] = ((_orders[index]['status'] ?? 0) + 1) % _statuses.length;
    });
    _saveOrders();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: Text('Order Status', style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
        leading: IconButton(icon: Icon(Icons.arrow_back, color: textPrimary), onPressed: () => Navigator.pop(context)),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addOrder, backgroundColor: KoraColors.purple, child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _orders.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 56, color: KoraColors.purple.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text('No orders yet', style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Track and manage customer orders', style: TextStyle(color: textMuted, fontSize: 14)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _orders.length,
              itemBuilder: (context, i) {
                final order = _orders[i];
                final statusIdx = order['status'] ?? 0;
                final color = _statusColors[statusIdx];
                return Dismissible(
                  key: Key('${order['id']}'),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) { setState(() => _orders.removeAt(i)); _saveOrders(); },
                  background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), color: Colors.red, child: const Icon(Icons.delete, color: Colors.white)),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(order['customer'] ?? '', style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                              Text(order['item'] ?? '', style: TextStyle(color: textMuted, fontSize: 13)),
                              if (order['price'] != null && order['price'].isNotEmpty)
                                Text('₦${order['price']}', style: TextStyle(color: KoraColors.purple, fontSize: 13, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _cycleStatus(i),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                            child: Text(_statuses[statusIdx], style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

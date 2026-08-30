import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../theme/kora_colors.dart';
import '../../models/business_models.dart';

class BusinessCatalogScreen extends StatefulWidget {
  const BusinessCatalogScreen({super.key});
  @override
  State<BusinessCatalogScreen> createState() => _BusinessCatalogScreenState();
}

class _BusinessCatalogScreenState extends State<BusinessCatalogScreen> {
  List<CatalogItem> _items = [];

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('kora_business_catalog');
    if (raw != null) {
      _items = (jsonDecode(raw) as List).map((e) => CatalogItem.fromJson(e as Map<String, dynamic>)).toList();
      setState(() {});
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('kora_business_catalog', jsonEncode(_items.map((e) => e.toJson()).toList()));
  }

  void _addItem() {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: KoraColors.backgroundFor(Theme.of(ctx).brightness),
      title: Text('Add product', style: TextStyle(color: KoraColors.textPrimaryFor(Theme.of(ctx).brightness))),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, decoration: const InputDecoration(hintText: 'Product name'),),
        TextField(controller: priceCtrl, decoration: const InputDecoration(hintText: 'Price'), keyboardType: TextInputType.number),
        TextField(controller: descCtrl, decoration: const InputDecoration(hintText: 'Description'), maxLines: 2),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: KoraColors.textMutedFor(Theme.of(ctx).brightness)))),
        TextButton(onPressed: () {
          _items.add(CatalogItem(id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: nameCtrl.text, price: priceCtrl.text, description: descCtrl.text));
          _save(); setState(() {}); Navigator.pop(ctx);
        }, child: Text('Add', style: TextStyle(color: KoraColors.purple))),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Scaffold(
      backgroundColor: KoraColors.backgroundFor(brightness),
      appBar: AppBar(
        backgroundColor: KoraColors.backgroundFor(brightness),
        title: Text('Catalog', style: TextStyle(color: KoraColors.textPrimaryFor(brightness))),
        iconTheme: IconThemeData(color: KoraColors.textPrimaryFor(brightness)),
      ),
      floatingActionButton: FloatingActionButton(onPressed: _addItem,
        backgroundColor: KoraColors.purple, child: const Icon(Icons.add, color: Colors.white)),
      body: _items.isEmpty ? _empty(brightness) : GridView.builder(
        padding: const EdgeInsets.all(12), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.75),
        itemCount: _items.length,
        itemBuilder: (ctx, i) => _productCard(_items[i], brightness, i),
      ),
    );
  }

  Widget _empty(Brightness b) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(Icons.storefront_outlined, size: 64, color: KoraColors.textMutedFor(b)),
    const SizedBox(height: 16),
    Text('No products yet', style: TextStyle(fontSize: 16, color: KoraColors.textMutedFor(b))),
    const SizedBox(height: 8),
    Text('Tap + to add your first product', style: TextStyle(fontSize: 14, color: KoraColors.textMutedFor(b))),
  ]));

  Widget _productCard(CatalogItem item, Brightness b, int index) {
    return Card(color: KoraColors.cardFor(b), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 3, child: Container(
          decoration: BoxDecoration(borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            color: KoraColors.purple.withValues(alpha: 0.1)),
          child: Center(child: Icon(Icons.image_outlined, size: 40, color: KoraColors.textMutedFor(b))))),
        Expanded(flex: 2, child: Padding(padding: const EdgeInsets.all(8), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: KoraColors.textPrimaryFor(b)),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            if (item.description.isNotEmpty) Text(item.description, style: TextStyle(fontSize: 12, color: KoraColors.textMutedFor(b)),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            const Spacer(),
            Text(item.price, style: TextStyle(fontWeight: FontWeight.bold, color: KoraColors.purple, fontSize: 14)),
          ]))),
      ]));
  }
}

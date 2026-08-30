import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';

class AiStickerGenScreen extends StatefulWidget {
  final ValueChanged<String>? onStickerCreated;
  const AiStickerGenScreen({super.key, this.onStickerCreated});
  @override
  State<AiStickerGenScreen> createState() => _AiStickerGenScreenState();
}

class _AiStickerGenScreenState extends State<AiStickerGenScreen> {
  final _promptCtrl = TextEditingController();
  String _style = 'Kawaii 3D';
  final _styles = ['Kawaii 3D', 'Vector Flat', 'Neon Glow', 'Emoji Style'];
  final _quickPrompts = ['Happy cat', 'Cool sunglasses', 'Heart eyes', 'Thumbs up', 'Party hat'];
  bool _generating = false;
  final List<String> _stickers = [];

  void _generate() async {
    if (_promptCtrl.text.isEmpty) return;
    setState(() => _generating = true);
    await Future.delayed(const Duration(seconds: 2));
    setState(() { _generating = false; _stickers.insert(0, _promptCtrl.text); });
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Scaffold(
      backgroundColor: KoraColors.backgroundFor(b),
      appBar: AppBar(backgroundColor: KoraColors.backgroundFor(b),
        title: Text('AI Sticker', style: TextStyle(color: KoraColors.textPrimaryFor(b))),
        iconTheme: IconThemeData(color: KoraColors.textPrimaryFor(b))),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: TextField(
          controller: _promptCtrl, maxLines: 2,
          decoration: InputDecoration(hintText: 'Describe a sticker...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: KoraColors.purple)),
            suffixIcon: IconButton(icon: Icon(Icons.auto_awesome, color: KoraColors.purple), onPressed: _generate)),
          style: TextStyle(color: KoraColors.textPrimaryFor(b)),)),
        SizedBox(height: 40, child: ListView.separated(
          scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _styles.length, separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (ctx, i) => ChoiceChip(label: Text(_styles[i]), selected: _style == _styles[i],
            selectedColor: KoraColors.purple, onSelected: (v) => setState(() => _style = _styles[i])),)),
        if (_generating)
          Padding(padding: const EdgeInsets.all(20), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: KoraColors.purple)),
            SizedBox(width: 12),
            Text('Creating sticker...', style: TextStyle(color: KoraColors.purple)),
          ])),
        Expanded(child: _stickers.isEmpty ? _quickPromptsList(b) : GridView.builder(
          padding: const EdgeInsets.all(12), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, crossAxisSpacing: 12, mainAxisSpacing: 12),
          itemCount: _stickers.length,
          itemBuilder: (ctx, i) => _stickerCard(_stickers[i], b),)),
      ]),
    );
  }

  Widget _quickPromptsList(Brightness b) {
    return Column(children: [
      Padding(padding: const EdgeInsets.all(16), child: Text('Quick prompts',
        style: TextStyle(color: KoraColors.textMutedFor(b), fontSize: 14))),
      Wrap(spacing: 8, children: _quickPrompts.map((s) => ActionChip(label: Text(s),
        onPressed: () => setState(() => _promptCtrl.text = s))).toList()),
    ]);
  }

  Widget _stickerCard(String prompt, Brightness b) {
    return Card(color: KoraColors.cardFor(b), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Expanded(child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
          color: KoraColors.purple.withValues(alpha: 0.15)),
          child: Center(child: Icon(Icons.emoji_emotions, size: 40, color: KoraColors.purple)))),
        Padding(padding: const EdgeInsets.all(6), child: Text(prompt, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11, color: KoraColors.textPrimaryFor(b)))),
      ]));
  }
}

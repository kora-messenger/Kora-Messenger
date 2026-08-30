import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';

class AiImageGenScreen extends StatefulWidget {
  final ValueChanged<String>? onImageGenerated;
  const AiImageGenScreen({super.key, this.onImageGenerated});
  @override
  State<AiImageGenScreen> createState() => _AiImageGenScreenState();
}

class _AiImageGenScreenState extends State<AiImageGenScreen> {
  final _promptCtrl = TextEditingController();
  String _selectedStyle = 'Photorealistic';
  final _styles = ['Photorealistic', 'Anime', 'Cyberpunk', '3D Render', 'Watercolor', 'Pixel Art'];
  final _samples = ['A sunset over mountains', 'A futuristic city', 'A cute cat in space', 'Abstract geometric art'];
  bool _generating = false;
  final List<String> _generated = [];

  void _generate() async {
    if (_promptCtrl.text.isEmpty) return;
    setState(() => _generating = true);
    await Future.delayed(const Duration(seconds: 3));
    setState(() { _generating = false; _generated.insert(0, _promptCtrl.text); });
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Scaffold(
      backgroundColor: KoraColors.backgroundFor(b),
      appBar: AppBar(backgroundColor: KoraColors.backgroundFor(b),
        title: Text('AI Image', style: TextStyle(color: KoraColors.textPrimaryFor(b))),
        iconTheme: IconThemeData(color: KoraColors.textPrimaryFor(b))),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: TextField(
          controller: _promptCtrl, maxLines: 2,
          decoration: InputDecoration(hintText: 'Describe the image you want to create...',
            hintStyle: TextStyle(color: KoraColors.textMutedFor(b)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: KoraColors.purple)),
            suffixIcon: IconButton(icon: Icon(Icons.auto_awesome, color: KoraColors.purple), onPressed: _generate)),
          style: TextStyle(color: KoraColors.textPrimaryFor(b)),)),
        SizedBox(height: 40, child: ListView.separated(
          scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _styles.length, separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (ctx, i) => ChoiceChip(label: Text(_styles[i]), selected: _selectedStyle == _styles[i],
            selectedColor: KoraColors.purple, labelStyle: TextStyle(color: _selectedStyle == _styles[i] ? Colors.white : KoraColors.textPrimaryFor(b)),
            onSelected: (v) => setState(() => _selectedStyle = _styles[i])),)),
        if (_generating)
          Container(margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [KoraColors.purple, KoraColors.blue]),
              borderRadius: BorderRadius.circular(16)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white)),
              SizedBox(width: 12),
              Text('Generating...', style: TextStyle(color: Colors.white, fontSize: 16)),
            ])),
        Expanded(child: _generated.isEmpty ? _samplesList(b) : GridView.builder(
          padding: const EdgeInsets.all(12), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12),
          itemCount: _generated.length,
          itemBuilder: (ctx, i) => _imageCard(_generated[i], b),)),
      ]),
    );
  }

  Widget _samplesList(Brightness b) {
    return Column(children: [
      Padding(padding: const EdgeInsets.all(16), child: Text('Try these prompts',
        style: TextStyle(color: KoraColors.textMutedFor(b), fontSize: 14))),
      Wrap(spacing: 8, children: _samples.map((s) => ActionChip(label: Text(s),
        onPressed: () => setState(() => _promptCtrl.text = s))).toList()),
    ]);
  }

  Widget _imageCard(String prompt, Brightness b) {
    return Card(color: KoraColors.cardFor(b), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Expanded(flex: 3, child: Container(decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          gradient: LinearGradient(colors: [KoraColors.purple.withValues(alpha: 0.3), KoraColors.blue.withValues(alpha: 0.3)])),
          child: Center(child: Icon(Icons.image, size: 40, color: KoraColors.purple.withValues(alpha: 0.5))))),
        Expanded(flex: 1, child: Padding(padding: const EdgeInsets.all(8), child: Text(prompt,
          maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: KoraColors.textPrimaryFor(b))))),
      ]));
  }
}

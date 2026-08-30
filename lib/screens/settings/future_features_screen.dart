import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/kora_colors.dart';

// ════════════════════════════════════════════════════════════════
// FUTURE FEATURES SCREEN — AI Image Gen, AI Stickers, On-Device AI,
// Wear OS, Android Auto, Cross-Platform Interop, Managed Accounts,
// Channel Creation
// ════════════════════════════════════════════════════════════════

/// Hub screen for all Future features.
/// Mirrors WhatsApp's approach to emerging/experimental features.
class FutureFeaturesScreen extends StatefulWidget {
  const FutureFeaturesScreen({super.key});

  @override
  State<FutureFeaturesScreen> createState() => _FutureFeaturesScreenState();
}

class _FutureFeaturesScreenState extends State<FutureFeaturesScreen> {
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
        title: Text('Future Features', style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
        leading: IconButton(icon: Icon(Icons.arrow_back, color: textPrimary), onPressed: () => Navigator.pop(context)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _sectionLabel('AI FEATURES', textMuted),
          _navTile(context, Icons.auto_awesome, 'AI Image Generation', 'Create images with AI in chat', AiImageGenScreen()),
          _navTile(context, Icons.emoji_emotions, 'AI Stickers', 'Generate custom stickers with AI', AiStickersScreen()),
          _navTile(context, Icons.memory, 'On-Device AI', 'Private, offline AI processing', OnDeviceAiScreen()),
          const SizedBox(height: 20),
          _sectionLabel('PLATFORM', textMuted),
          _navTile(context, Icons.watch, 'Wear OS', 'Kora on your smartwatch', WearOsScreen()),
          _navTile(context, Icons.directions_car, 'Android Auto', 'Kora in your car', AndroidAutoScreen()),
          const SizedBox(height: 20),
          _sectionLabel('CONNECTIVITY', textMuted),
          _navTile(context, Icons.swap_horiz, 'Cross-Platform Interop', 'Message across apps', InteropScreen()),
          _navTile(context, Icons.manage_accounts, 'Managed Accounts', 'Business account management', ManagedAccountsScreen()),
          _navTile(context, Icons.campaign, 'Channel Creation', 'Create a broadcast channel', ChannelCreationScreen()),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
    );
  }

  Widget _navTile(BuildContext context, IconData icon, String title, String subtitle, Widget screen) {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);
    return ListTile(
      leading: Icon(icon, color: KoraColors.purple),
      title: Text(title, style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: TextStyle(color: textMuted, fontSize: 13)),
      trailing: Icon(Icons.chevron_right, color: textMuted, size: 20),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// 1. AI IMAGE GENERATION
// ════════════════════════════════════════════════════════════════

/// AI Image Generation — generate images from text prompts in chat.
/// Mirrors WhatsApp/Meta AI image generation.
class AiImageGenScreen extends StatefulWidget {
  const AiImageGenScreen({super.key});
  @override
  State<AiImageGenScreen> createState() => _AiImageGenScreenState();
}

class _AiImageGenScreenState extends State<AiImageGenScreen> {
  final _promptController = TextEditingController();
  final List<_GeneratedImage> _history = [];
  bool _isGenerating = false;
  String _selectedStyle = 'Realistic';
  final _styles = ['Realistic', 'Anime', '3D', 'Watercolor', 'Pixel Art', 'Cyberpunk'];

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  void _generate() {
    if (_promptController.text.trim().isEmpty) return;
    setState(() => _isGenerating = true);
    // Simulate generation (production: call AI image API)
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _history.insert(0, _GeneratedImage(
            prompt: _promptController.text.trim(),
            style: _selectedStyle,
            timestamp: DateTime.now(),
          ));
          _promptController.clear();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: Text('AI Image Gen', style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
        leading: IconButton(icon: Icon(Icons.arrow_back, color: textPrimary), onPressed: () => Navigator.pop(context)),
      ),
      body: Column(
        children: [
          // Info banner
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [KoraColors.purple.withValues(alpha: 0.1), KoraColors.blue.withValues(alpha: 0.1)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              Icon(Icons.auto_awesome, color: KoraColors.purple, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('Describe an image and Kora AI will create it for you.', style: TextStyle(color: textMuted, fontSize: 13))),
            ]),
          ),
          // Style selector
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: _styles.map((style) {
                final isSelected = _selectedStyle == style;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(style, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : textPrimary)),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedStyle = style),
                    backgroundColor: surface,
                    selectedColor: KoraColors.purple,
                    showCheckmark: false,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          // Prompt input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _promptController,
                  style: TextStyle(color: textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Describe an image…',
                    hintStyle: TextStyle(color: textMuted),
                    filled: true,
                    fillColor: surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onSubmitted: (_) => _generate(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _isGenerating ? null : _generate,
                icon: _isGenerating
                  ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: KoraColors.purple))
                  : Icon(Icons.send, color: KoraColors.purple),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          // History grid
          Expanded(
            child: _history.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.image_outlined, size: 48, color: textMuted.withValues(alpha: 0.3)),
                  const SizedBox(height: 8),
                  Text('No images yet', style: TextStyle(color: textMuted, fontSize: 14)),
                ]))
              : GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 8, mainAxisSpacing: 8),
                  itemCount: _history.length,
                  itemBuilder: (ctx, i) {
                    final img = _history[i];
                    return Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [KoraColors.purple.withValues(alpha: 0.15), KoraColors.blue.withValues(alpha: 0.15)]),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: KoraColors.borderFor(brightness), width: 0.5),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.auto_awesome, size: 32, color: KoraColors.purple.withValues(alpha: 0.5)),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(img.prompt, style: TextStyle(color: textMuted, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                          ),
                          Text(img.style, style: TextStyle(color: KoraColors.purple, fontSize: 10, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}

class _GeneratedImage {
  final String prompt;
  final String style;
  final DateTime timestamp;
  _GeneratedImage({required this.prompt, required this.style, required this.timestamp});
}

// ════════════════════════════════════════════════════════════════
// 2. AI STICKERS
// ════════════════════════════════════════════════════════════════

/// AI Stickers — generate custom stickers from text prompts.
/// Mirrors WhatsApp/Meta AI sticker generation.
class AiStickersScreen extends StatefulWidget {
  const AiStickersScreen({super.key});
  @override
  State<AiStickersScreen> createState() => _AiStickersScreenState();
}

class _AiStickersScreenState extends State<AiStickersScreen> {
  final _promptController = TextEditingController();
  final List<String> _generated = [];
  bool _isGenerating = false;

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  void _generate() {
    if (_promptController.text.trim().isEmpty) return;
    setState(() => _isGenerating = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _generated.insert(0, _promptController.text.trim());
          _promptController.clear();
        });
      }
    });
  }

  Future<void> _saveToMyStickers(String prompt) async {
    final prefs = await SharedPreferences.getInstance();
    final myStickers = prefs.getStringList('kora_my_stickers') ?? [];
    myStickers.insert(0, jsonEncode({'aiGenerated': true, 'prompt': prompt, 'created': DateTime.now().millisecondsSinceEpoch}));
    if (myStickers.length > 30) myStickers.removeLast();
    await prefs.setStringList('kora_my_stickers', myStickers);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Sticker saved to My Stickers pack'), backgroundColor: KoraColors.purple, behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: Text('AI Stickers', style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
        leading: IconButton(icon: Icon(Icons.arrow_back, color: textPrimary), onPressed: () => Navigator.pop(context)),
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [KoraColors.purple.withValues(alpha: 0.1), KoraColors.blue.withValues(alpha: 0.1)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              Icon(Icons.emoji_emotions, color: KoraColors.purple, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('Describe a sticker and AI will generate it. Saved to My Stickers pack.', style: TextStyle(color: textMuted, fontSize: 13))),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _promptController,
                  style: TextStyle(color: textPrimary),
                  decoration: InputDecoration(
                    hintText: 'e.g. "happy cat waving"',
                    hintStyle: TextStyle(color: textMuted),
                    filled: true,
                    fillColor: surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onSubmitted: (_) => _generate(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _isGenerating ? null : _generate,
                icon: _isGenerating
                  ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: KoraColors.purple))
                  : Icon(Icons.auto_awesome, color: KoraColors.purple),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _generated.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.emoji_emotions_outlined, size: 48, color: textMuted.withValues(alpha: 0.3)),
                  const SizedBox(height: 8),
                  Text('No AI stickers yet', style: TextStyle(color: textMuted, fontSize: 14)),
                ]))
              : GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
                  itemCount: _generated.length,
                  itemBuilder: (ctx, i) {
                    return GestureDetector(
                      onLongPress: () => _saveToMyStickers(_generated[i]),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [KoraColors.purple.withValues(alpha: 0.15), KoraColors.blue.withValues(alpha: 0.15)]),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: KoraColors.borderFor(brightness), width: 0.5),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.auto_awesome, size: 28, color: KoraColors.purple.withValues(alpha: 0.5)),
                            const SizedBox(height: 4),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(_generated[i], style: TextStyle(color: textMuted, fontSize: 10), maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('Long-press to save to My Stickers', style: TextStyle(color: textMuted, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// 3. ON-DEVICE AI
// ════════════════════════════════════════════════════════════════

/// On-Device AI — private, offline AI processing.
/// Mirrors WhatsApp's on-device AI features for privacy.
class OnDeviceAiScreen extends StatefulWidget {
  const OnDeviceAiScreen({super.key});
  @override
  State<OnDeviceAiScreen> createState() => _OnDeviceAiScreenState();
}

class _OnDeviceAiScreenState extends State<OnDeviceAiScreen> {
  bool _smartReplies = true;
  bool _spamDetection = true;
  bool _languageDetection = true;
  bool _sentimentAnalysis = false;
  bool _textClassification = true;
  String _modelSize = 'Small (45 MB)';
  bool _isDownloading = false;
  double _downloadProgress = 0;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: Text('On-Device AI', style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
        leading: IconButton(icon: Icon(Icons.arrow_back, color: textPrimary), onPressed: () => Navigator.pop(context)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [KoraColors.purple.withValues(alpha: 0.1), KoraColors.blue.withValues(alpha: 0.1)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              Icon(Icons.shield, color: KoraColors.purple, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('On-device AI runs locally on your phone. Your data never leaves your device.', style: TextStyle(color: textMuted, fontSize: 13))),
            ]),
          ),
          _sectionLabel('AVAILABLE FEATURES', textMuted),
          _toggleTile('Smart Replies', 'Suggest quick replies based on context', _smartReplies, (v) => setState(() => _smartReplies = v)),
          _toggleTile('Spam Detection', 'Flag suspicious messages locally', _spamDetection, (v) => setState(() => _spamDetection = v)),
          _toggleTile('Language Detection', 'Auto-detect message language', _languageDetection, (v) => setState(() => _languageDetection = v)),
          _toggleTile('Sentiment Analysis', 'Analyze message tone (positive/negative)', _sentimentAnalysis, (v) => setState(() => _sentimentAnalysis = v)),
          _toggleTile('Text Classification', 'Categorize messages by type', _textClassification, (v) => setState(() => _textClassification = v)),
          const SizedBox(height: 20),
          _sectionLabel('MODEL', textMuted),
          ListTile(
            leading: Icon(Icons.memory, color: KoraColors.purple),
            title: Text('AI Model', style: TextStyle(color: textPrimary, fontSize: 15)),
            subtitle: Text(_modelSize, style: TextStyle(color: textMuted, fontSize: 13)),
            trailing: DropdownButton<String>(
              value: _modelSize,
              underline: const SizedBox(),
              items: ['Small (45 MB)', 'Medium (120 MB)', 'Large (280 MB)'].map((s) => DropdownMenuItem(value: s, child: Text(s, style: TextStyle(fontSize: 13)))).toList(),
              onChanged: (v) => setState(() => _modelSize = v ?? _modelSize),
            ),
          ),
          if (_isDownloading) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LinearProgressIndicator(value: _downloadProgress, backgroundColor: surface, color: KoraColors.purple),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text('${(_downloadProgress * 100).round()}%', style: TextStyle(color: textMuted, fontSize: 12)),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() { _isDownloading = true; _downloadProgress = 0; });
                  // Simulate download
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (mounted) setState(() => _downloadProgress = 0.3);
                  });
                  Future.delayed(const Duration(seconds: 1), () {
                    if (mounted) setState(() => _downloadProgress = 0.7);
                  });
                  Future.delayed(const Duration(seconds: 2), () {
                    if (mounted) setState(() { _downloadProgress = 1; _isDownloading = false; });
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Model downloaded'), backgroundColor: KoraColors.purple));
                  });
                },
                icon: Icon(Icons.download, color: Colors.white, size: 18),
                label: const Text('Download Model', style: TextStyle(color: Colors.white, fontSize: 14)),
                style: ElevatedButton.styleFrom(backgroundColor: KoraColors.purple, minimumSize: const Size(double.infinity, 44), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('On-device AI features work offline and never send your messages to servers.', style: TextStyle(color: textMuted, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
    );
  }

  Widget _toggleTile(String title, String subtitle, bool value, Function(bool) onChanged) {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);
    return SwitchListTile(
      secondary: Icon(Icons.check_circle_outline, color: value ? KoraColors.purple : textMuted),
      title: Text(title, style: TextStyle(color: textPrimary, fontSize: 15)),
      subtitle: Text(subtitle, style: TextStyle(color: textMuted, fontSize: 13)),
      value: value,
      onChanged: onChanged,
      activeTrackColor: KoraColors.purple.withValues(alpha: 0.3),
      activeColor: KoraColors.purple,
    );
  }
}

// ════════════════════════════════════════════════════════════════
// 4. WEAR OS
// ════════════════════════════════════════════════════════════════

/// Wear OS — Kora on smartwatches.
/// Mirrors WhatsApp's Wear OS companion app.
class WearOsScreen extends StatefulWidget {
  const WearOsScreen({super.key});
  @override
  State<WearOsScreen> createState() => _WearOsScreenState();
}

class _WearOsScreenState extends State<WearOsScreen> {
  bool _wearEnabled = false;
  bool _voiceReply = true;
  bool _quickReplies = true;
  bool _notificationsOnly = false;
  String _connectedWatch = 'No watch connected';

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: Text('Wear OS', style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
        leading: IconButton(icon: Icon(Icons.arrow_back, color: textPrimary), onPressed: () => Navigator.pop(context)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // Watch status card
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: KoraColors.borderFor(brightness), width: 0.5),
            ),
            child: Column(
              children: [
                Icon(Icons.watch, size: 48, color: _wearEnabled ? KoraColors.purple : textMuted),
                const SizedBox(height: 8),
                Text(_connectedWatch, style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _wearEnabled = !_wearEnabled;
                      _connectedWatch = _wearEnabled ? 'Galaxy Watch 6' : 'No watch connected';
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _wearEnabled ? surface : KoraColors.purple,
                    foregroundColor: _wearEnabled ? textPrimary : Colors.white,
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: _wearEnabled ? BorderSide(color: KoraColors.borderFor(brightness)) : null,
                  ),
                  child: Text(_wearEnabled ? 'Disconnect' : 'Pair Watch'),
                ),
              ],
            ),
          ),
          if (_wearEnabled) ...[
            _sectionLabel('COMPANION SETTINGS', textMuted),
            SwitchListTile(
              secondary: Icon(Icons.mic, color: KoraColors.purple),
              title: Text('Voice Reply', style: TextStyle(color: textPrimary, fontSize: 15)),
              subtitle: Text('Dicticate replies from your watch', style: TextStyle(color: textMuted, fontSize: 13)),
              value: _voiceReply,
              onChanged: (v) => setState(() => _voiceReply = v),
              activeTrackColor: KoraColors.purple.withValues(alpha: 0.3),
              activeColor: KoraColors.purple,
            ),
            SwitchListTile(
              secondary: Icon(Icons.quickreply, color: KoraColors.purple),
              title: Text('Quick Replies', style: TextStyle(color: textPrimary, fontSize: 15)),
              subtitle: Text('Show canned reply suggestions', style: TextStyle(color: textMuted, fontSize: 13)),
              value: _quickReplies,
              onChanged: (v) => setState(() => _quickReplies = v),
              activeTrackColor: KoraColors.purple.withValues(alpha: 0.3),
              activeColor: KoraColors.purple,
            ),
            SwitchListTile(
              secondary: Icon(Icons.notifications, color: KoraColors.purple),
              title: Text('Notifications Only', style: TextStyle(color: textPrimary, fontSize: 15)),
              subtitle: Text('Only show notifications, no replies', style: TextStyle(color: textMuted, fontSize: 13)),
              value: _notificationsOnly,
              onChanged: (v) => setState(() => _notificationsOnly = v),
              activeTrackColor: KoraColors.purple.withValues(alpha: 0.3),
              activeColor: KoraColors.purple,
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('Kora for Wear OS supports viewing messages, voice replies, and quick replies. Full chat composition requires your phone.', style: TextStyle(color: textMuted, fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// 5. ANDROID AUTO
// ════════════════════════════════════════════════════════════════

/// Android Auto — Kora in your car.
/// Mirrors WhatsApp's Android Auto support.
class AndroidAutoScreen extends StatefulWidget {
  const AndroidAutoScreen({super.key});
  @override
  State<AndroidAutoScreen> createState() => _AndroidAutoScreenState();
}

class _AndroidAutoScreenState extends State<AndroidAutoScreen> {
  bool _autoEnabled = true;
  bool _voiceOnly = true;
  bool _readAloud = true;
  bool _autoReply = false;
  String _autoReplyText = "I'm driving right now. I'll get back to you soon.";

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: Text('Android Auto', style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
        leading: IconButton(icon: Icon(Icons.arrow_back, color: textPrimary), onPressed: () => Navigator.pop(context)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [KoraColors.purple.withValues(alpha: 0.1), KoraColors.blue.withValues(alpha: 0.1)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              Icon(Icons.directions_car, color: KoraColors.purple, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('Kora works with Android Auto for safe messaging while driving.', style: TextStyle(color: textMuted, fontSize: 13))),
            ]),
          ),
          SwitchListTile(
            secondary: Icon(Icons.directions_car, color: KoraColors.purple),
            title: Text('Enable Android Auto', style: TextStyle(color: textPrimary, fontSize: 15)),
            subtitle: Text('Show Kora in Android Auto', style: TextStyle(color: textMuted, fontSize: 13)),
            value: _autoEnabled,
            onChanged: (v) => setState(() => _autoEnabled = v),
            activeTrackColor: KoraColors.purple.withValues(alpha: 0.3),
            activeColor: KoraColors.purple,
          ),
          if (_autoEnabled) ...[
            _sectionLabel('DRIVING SAFETY', textMuted),
            SwitchListTile(
              secondary: Icon(Icons.mic, color: KoraColors.purple),
              title: Text('Voice Only Mode', style: TextStyle(color: textPrimary, fontSize: 15)),
              subtitle: Text('Only use voice commands while driving', style: TextStyle(color: textMuted, fontSize: 13)),
              value: _voiceOnly,
              onChanged: (v) => setState(() => _voiceOnly = v),
              activeTrackColor: KoraColors.purple.withValues(alpha: 0.3),
              activeColor: KoraColors.purple,
            ),
            SwitchListTile(
              secondary: Icon(Icons.record_voice_over, color: KoraColors.purple),
              title: Text('Read Messages Aloud', style: TextStyle(color: textPrimary, fontSize: 15)),
              subtitle: Text('Read incoming messages via TTS', style: TextStyle(color: textMuted, fontSize: 13)),
              value: _readAloud,
              onChanged: (v) => setState(() => _readAloud = v),
              activeTrackColor: KoraColors.purple.withValues(alpha: 0.3),
              activeColor: KoraColors.purple,
            ),
            SwitchListTile(
              secondary: Icon(Icons.reply, color: KoraColors.purple),
              title: Text('Auto-Reply While Driving', style: TextStyle(color: textPrimary, fontSize: 15)),
              subtitle: Text('Send automatic reply when driving', style: TextStyle(color: textMuted, fontSize: 13)),
              value: _autoReply,
              onChanged: (v) => setState(() => _autoReply = v),
              activeTrackColor: KoraColors.purple.withValues(alpha: 0.3),
              activeColor: KoraColors.purple,
            ),
            if (_autoReply)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: TextEditingController(text: _autoReplyText),
                  style: TextStyle(color: textPrimary),
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Auto-reply message',
                    labelStyle: TextStyle(color: textMuted),
                    filled: true,
                    fillColor: surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  onChanged: (v) => _autoReplyText = v,
                ),
              ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('Android Auto lets you hear and reply to messages hands-free. Stay safe on the road.', style: TextStyle(color: textMuted, fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// 6. CROSS-PLATFORM INTEROP
// ════════════════════════════════════════════════════════════════

/// Cross-Platform Interop — message across different apps.
/// Mirrors WhatsApp's EU DMA interoperability requirement.
class InteropScreen extends StatefulWidget {
  const InteropScreen({super.key});
  @override
  State<InteropScreen> createState() => _InteropScreenState();
}

class _InteropScreenState extends State<InteropScreen> {
  bool _interopEnabled = false;
  final List<_InteropApp> _apps = [
    _InteropApp(name: 'Telegram', icon: Icons.send, connected: false),
    _InteropApp(name: 'Signal', icon: Icons.signal_cellular_alt, connected: false),
    _InteropApp(name: 'iMessage', icon: Icons.chat_bubble, connected: false),
    _InteropApp(name: 'Google Messages', icon: Icons.message, connected: false),
  ];

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: Text('Cross-Platform Interop', style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
        leading: IconButton(icon: Icon(Icons.arrow_back, color: textPrimary), onPressed: () => Navigator.pop(context)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [KoraColors.purple.withValues(alpha: 0.1), KoraColors.blue.withValues(alpha: 0.1)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              Icon(Icons.swap_horiz, color: KoraColors.purple, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('Send and receive messages across supported apps. End-to-end encrypted.', style: TextStyle(color: textMuted, fontSize: 13))),
            ]),
          ),
          SwitchListTile(
            secondary: Icon(Icons.swap_horiz, color: KoraColors.purple),
            title: Text('Enable Interoperability', style: TextStyle(color: textPrimary, fontSize: 15)),
            subtitle: Text('Allow messages from other apps', style: TextStyle(color: textMuted, fontSize: 13)),
            value: _interopEnabled,
            onChanged: (v) => setState(() => _interopEnabled = v),
            activeTrackColor: KoraColors.purple.withValues(alpha: 0.3),
            activeColor: KoraColors.purple,
          ),
          if (_interopEnabled) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text('SUPPORTED APPS', style: TextStyle(color: textMuted, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
            ),
            ..._apps.map((app) => ListTile(
              leading: Icon(app.icon, color: app.connected ? KoraColors.purple : textMuted),
              title: Text(app.name, style: TextStyle(color: textPrimary, fontSize: 15)),
              subtitle: Text(app.connected ? 'Connected' : 'Not connected', style: TextStyle(color: app.connected ? KoraColors.purple : textMuted, fontSize: 13)),
              trailing: app.connected
                ? Icon(Icons.check_circle, color: KoraColors.purple, size: 24)
                : TextButton(
                    onPressed: () => setState(() => app.connected = true),
                    child: Text('Connect', style: TextStyle(color: KoraColors.purple, fontWeight: FontWeight.w600)),
                  ),
            )),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('Interop uses end-to-end encryption protocols compatible with other messaging apps. Your messages remain private.', style: TextStyle(color: textMuted, fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }
}

class _InteropApp {
  final String name;
  final IconData icon;
  bool connected;
  _InteropApp({required this.name, required this.icon, required this.connected});
}

// ════════════════════════════════════════════════════════════════
// 7. MANAGED ACCOUNTS
// ════════════════════════════════════════════════════════════════

/// Managed Accounts — business account management.
/// Mirrors WhatsApp Business managed accounts feature.
class ManagedAccountsScreen extends StatefulWidget {
  const ManagedAccountsScreen({super.key});
  @override
  State<ManagedAccountsScreen> createState() => _ManagedAccountsScreenState();
}

class _ManagedAccountsScreenState extends State<ManagedAccountsScreen> {
  final List<_ManagedUser> _users = [
    _ManagedUser(name: 'Ijezie Goodluck', email: 'ijezie@goodluck.com', role: 'Owner', status: 'Active'),
    _ManagedUser(name: 'Demo User', email: 'demo@kora.com', role: 'Admin', status: 'Active'),
  ];

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: Text('Managed Accounts', style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
        leading: IconButton(icon: Icon(Icons.arrow_back, color: textPrimary), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(icon: Icon(Icons.person_add, color: KoraColors.purple), onPressed: () => _addUser()),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [KoraColors.purple.withValues(alpha: 0.1), KoraColors.blue.withValues(alpha: 0.1)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              Icon(Icons.manage_accounts, color: KoraColors.purple, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('Manage team members and their access levels.', style: TextStyle(color: textMuted, fontSize: 13))),
            ]),
          ),
          ..._users.map((user) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: KoraColors.borderFor(brightness), width: 0.5),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: KoraColors.purple.withValues(alpha: 0.15),
                  child: Text(user.name[0], style: TextStyle(color: KoraColors.purple, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.name, style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
                      Text(user.email, style: TextStyle(color: textMuted, fontSize: 13)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: user.role == 'Owner' ? KoraColors.purple : KoraColors.purple.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(user.role, style: TextStyle(color: user.role == 'Owner' ? Colors.white : KoraColors.purple, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 4),
                    Text(user.status, style: TextStyle(color: KoraColors.purple, fontSize: 11)),
                  ],
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  void _addUser() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KoraColors.surfaceFor(Theme.of(context).brightness),
        title: Text('Add Team Member', style: TextStyle(color: KoraColors.textPrimaryFor(Theme.of(context).brightness), fontSize: 17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: InputDecoration(labelText: 'Name', labelStyle: TextStyle(color: KoraColors.textMutedFor(Theme.of(context).brightness)), border: const OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: emailController, decoration: InputDecoration(labelText: 'Email', labelStyle: TextStyle(color: KoraColors.textMutedFor(Theme.of(context).brightness)), border: const OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (nameController.text.isNotEmpty && emailController.text.isNotEmpty) {
                setState(() {
                  _users.add(_ManagedUser(name: nameController.text, email: emailController.text, role: 'Admin', status: 'Pending'));
                });
                Navigator.pop(ctx);
              }
            },
            child: Text('Add', style: TextStyle(color: KoraColors.purple)),
          ),
        ],
      ),
    );
  }
}

class _ManagedUser {
  final String name;
  final String email;
  final String role;
  final String status;
  _ManagedUser({required this.name, required this.email, required this.role, required this.status});
}

// ════════════════════════════════════════════════════════════════
// 8. CHANNEL CREATION
// ════════════════════════════════════════════════════════════════

/// Channel Creation — create a broadcast channel.
/// Mirrors WhatsApp Channels creation flow.
class ChannelCreationScreen extends StatefulWidget {
  const ChannelCreationScreen({super.key});
  @override
  State<ChannelCreationScreen> createState() => _ChannelCreationScreenState();
}

class _ChannelCreationScreenState extends State<ChannelCreationScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  String _selectedCategory = 'General';
  bool _requireApproval = true;
  final _categories = ['General', 'News', 'Entertainment', 'Sports', 'Tech', 'Business', 'Education', 'Lifestyle'];

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: Text('Create Channel', style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
        leading: IconButton(icon: Icon(Icons.arrow_back, color: textPrimary), onPressed: () => Navigator.pop(context)),
        actions: [
          TextButton(
            onPressed: _createChannel,
            child: Text('Create', style: TextStyle(color: KoraColors.purple, fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Channel icon
          Center(
            child: GestureDetector(
              child: Container(
                width: 96, height: 96,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [KoraColors.purple, KoraColors.blue]),
                  shape: BoxShape.circle,
                ),
                child: const Center(child: Icon(Icons.camera_alt, color: Colors.white, size: 32)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Channel name
          TextField(
            controller: _nameController,
            style: TextStyle(color: textPrimary),
            maxLength: 100,
            decoration: InputDecoration(
              labelText: 'Channel Name',
              labelStyle: TextStyle(color: textMuted),
              hintText: 'Enter channel name',
              hintStyle: TextStyle(color: textMuted),
              filled: true,
              fillColor: surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          // Channel description
          TextField(
            controller: _descController,
            style: TextStyle(color: textPrimary),
            maxLines: 3,
            maxLength: 500,
            decoration: InputDecoration(
              labelText: 'Description (optional)',
              labelStyle: TextStyle(color: textMuted),
              hintText: 'What is your channel about?',
              hintStyle: TextStyle(color: textMuted),
              filled: true,
              fillColor: surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          // Category
          DropdownButtonFormField<String>(
            value: _selectedCategory,
            decoration: InputDecoration(
              labelText: 'Category',
              labelStyle: TextStyle(color: textMuted),
              filled: true,
              fillColor: surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: TextStyle(fontSize: 14)))).toList(),
            onChanged: (v) => setState(() => _selectedCategory = v ?? 'General'),
          ),
          const SizedBox(height: 16),
          // Follower approval
          SwitchListTile(
            secondary: Icon(Icons.verified_user, color: KoraColors.purple),
            title: Text('Require Approval', style: TextStyle(color: textPrimary, fontSize: 15)),
            subtitle: Text('Approve new followers before they can see posts', style: TextStyle(color: textMuted, fontSize: 13)),
            value: _requireApproval,
            onChanged: (v) => setState(() => _requireApproval = v),
            activeTrackColor: KoraColors.purple.withValues(alpha: 0.3),
            activeColor: KoraColors.purple,
          ),
          const SizedBox(height: 24),
          // Info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              Icon(Icons.info_outline, color: textMuted, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('Channels are one-way broadcasts. Only admins can post. Followers can react to posts.', style: TextStyle(color: textMuted, fontSize: 12))),
            ]),
          ),
        ],
      ),
    );
  }

  void _createChannel() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Enter a channel name'), backgroundColor: KoraColors.purple),
      );
      return;
    }
    Navigator.pop(context, {
      'name': _nameController.text.trim(),
      'description': _descController.text.trim(),
      'category': _selectedCategory,
      'requireApproval': _requireApproval,
    });
  }
}

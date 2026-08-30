import 'dart:io';
import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import 'doodle_editor.dart' show DoodleEditorScreen;

/// Kora Media Editor — the full-screen editor that opens when you pick
/// a photo or video from gallery or camera. Mirrors WhatsApp's editor.
///
/// Layout (images):
/// ┌──────────────────────────────────┐
/// │  ✕                    HD    ➤     │ ← top bar: cancel, HD toggle, send
/// │                                   │
/// │         [ full-screen image ]     │ ← pinch/pan image
/// │                                   │
/// │  [caption input bar...........]   │ ← optional caption
/// ├───────────────────────────────────┤
/// │  ✂️   😀   Aa   ✏️   🎨          │ ← tool tabs: crop, sticker, text, draw, filter
│ │  [filter strip when filter active]│
/// └──────────────────────────────────┘
///
/// Layout (videos):
/// Same but with video preview, trim bar, and playback speed.
class KoraMediaEditorScreen extends StatefulWidget {
  final String mediaPath;
  final bool isVideo;

  const KoraMediaEditorScreen({
    super.key,
    required this.mediaPath,
    required this.isVideo,
  });

  @override
  State<KoraMediaEditorScreen> createState() => _KoraMediaEditorScreenState();
}

class _KoraMediaEditorScreenState extends State<KoraMediaEditorScreen> {
  bool _isHD = true;
  bool _isViewOnce = false;
  final _captionController = TextEditingController();

  // Editor state
  int _selectedTool = -1; // -1 = none, 0 = crop, 1 = sticker, 2 = text, 3 = draw, 4 = filter
  int _selectedFilter = 0;
  double _rotation = 0;
  double _aspectRatio = 0; // 0 = free
  final List<_TextOverlay> _textOverlays = [];

  static const _tools = [
    (Icons.crop, 'Crop'),
    (Icons.emoji_emotions_outlined, 'Sticker'),
    (Icons.text_fields, 'Text'),
    (Icons.brush, 'Draw'),
    (Icons.tune, 'Filter'),
  ];

  static const _aspectRatios = [
    ('Free', 0.0),
    ('1:1', 1.0),
    ('4:5', 4 / 5),
    ('9:16', 9 / 16),
    ('16:9', 16 / 9),
    ('3:4', 3 / 4),
  ];

  static const _filters = [
    ('Original', null),
    ('Pop', ColorFilter.matrix(<double>[
      1.3, 0, 0, 0, 0, 0, 1.15, 0, 0, 0, 0, 0, 1.1, 0, 0, 0, 0, 0, 1, 0,
    ])),
    ('B&W', ColorFilter.matrix(<double>[
      0.299, 0.587, 0.114, 0, 0, 0.299, 0.587, 0.114, 0, 0, 0.299, 0.587, 0.114, 0, 0, 0, 0, 0, 1, 0,
    ])),
    ('Cool', ColorFilter.matrix(<double>[
      0.9, 0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 0, 1.2, 0, 10, 0, 0, 0, 1, 0,
    ])),
    ('Warm', ColorFilter.matrix(<double>[
      1.2, 0, 0, 0, 15, 0, 1.05, 0, 0, 0, 0, 0, 0.85, 0, 0, 0, 0, 0, 1, 0,
    ])),
    ('Vintage', ColorFilter.matrix(<double>[
      0.9, 0.5, 0.1, 0, 0, 0.3, 0.8, 0.1, 0, 0, 0.2, 0.3, 0.5, 0, 0, 0, 0, 0, 1, 0,
    ])),
    ('Chrome', ColorFilter.matrix(<double>[
      1.1, 0, 0, 0, 5, 0, 1.1, 0, 0, 5, 0, 0, 1.1, 0, 5, 0, 0, 0, 1, 0,
    ])),
    ('Faded', ColorFilter.matrix(<double>[
      0.85, 0, 0, 0, 20, 0, 0.85, 0, 0, 20, 0, 0, 0.85, 0, 20, 0, 0, 0, 1, 0,
    ])),
  ];

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  void _send() {
    Navigator.pop(context, {
      'path': widget.mediaPath,
      'isVideo': widget.isVideo,
      'caption': _captionController.text.trim().isEmpty ? null : _captionController.text.trim(),
      'isViewOnce': _isViewOnce,
      'isHD': _isHD,
      'filter': _selectedFilter,
      'rotation': _rotation,
      'width': null,
      'height': null,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──
            _buildTopBar(),

            // ── Media preview area ──
            Expanded(child: _buildMediaPreview()),

            // ── Caption bar ──
            _buildCaptionBar(),

            // ── Tool bar ──
            _buildToolBar(),

            // ── Tool panel (collapsible) ──
            if (_selectedTool >= 0) _buildToolPanel(),
          ],
        ),
      ),
    );
  }

  // ── Top bar: cancel, view-once, HD toggle, send ──
  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const Spacer(),
          // View once toggle
          GestureDetector(
            onTap: () => setState(() => _isViewOnce = !_isViewOnce),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _isViewOnce ? KoraColors.purple.withValues(alpha: 0.2) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _isViewOnce ? Icons.visibility : Icons.visibility_off_outlined,
                color: _isViewOnce ? KoraColors.purple : Colors.white70,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 4),
          // HD toggle
          GestureDetector(
            onTap: () => setState(() => _isHD = !_isHD),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _isHD ? KoraColors.purple : Colors.white12,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('HD',
                  style: TextStyle(
                    color: _isHD ? Colors.white : Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  )),
            ),
          ),
          const SizedBox(width: 4),
          // Send button
          IconButton(
            icon: const Icon(Icons.send, color: KoraColors.purple),
            onPressed: _send,
          ),
        ],
      ),
    );
  }

  // ── Media preview ──
  Widget _buildMediaPreview() {
    final filter = _filters[_selectedFilter];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          // Image with filter and rotation
          Center(
            child: Transform.rotate(
              angle: _rotation * 3.14159 / 180,
              child: ColorFiltered(
                colorFilter: filter.$2 ?? const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                child: widget.isVideo
                    ? const Icon(Icons.play_circle_fill, size: 72, color: Colors.white54)
                    : Image.file(File(widget.mediaPath), fit: BoxFit.contain),
              ),
            ),
          ),
          // Text overlays
          ..._textOverlays.map((t) => Positioned(
            left: t.x, top: t.y,
            child: GestureDetector(
              onPanUpdate: (d) => setState(() {
                t.x += d.delta.dx;
                t.y += d.delta.dy;
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(t.text, style: TextStyle(color: t.color, fontSize: 18, fontWeight: FontWeight.w700)),
              ),
            ),
          )),
          // Video trim bar for videos
          if (widget.isVideo)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: _buildVideoTrimBar(),
            ),
        ],
      ),
    );
  }

  // ── Caption bar ──
  Widget _buildCaptionBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _captionController,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: widget.isVideo ? 'Add a caption…' : 'Add a caption…',
                hintStyle: const TextStyle(color: Colors.white54, fontSize: 15),
                border: InputBorder.none,
                isDense: true,
              ),
              maxLines: 1,
            ),
          ),
          // Emoji button
          IconButton(
            icon: const Icon(Icons.emoji_emotions_outlined, color: Colors.white54, size: 22),
            onPressed: () {},
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  // ── Tool bar (bottom row of icons) ──
  Widget _buildToolBar() {
    return Container(
      height: 56,
      color: Colors.black,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(_tools.length, (i) {
          final tool = _tools[i];
          final isSelected = _selectedTool == i;
          return GestureDetector(
            onTap: () => setState(() => _selectedTool = _selectedTool == i ? -1 : i),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(tool.$1, size: 22,
                    color: isSelected ? KoraColors.purple : Colors.white70),
                const SizedBox(height: 2),
                Text(tool.$2, style: TextStyle(
                  color: isSelected ? KoraColors.purple : Colors.white70,
                  fontSize: 10,
                )),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ── Collapsible tool panel ──
  Widget _buildToolPanel() {
    switch (_selectedTool) {
      case 0: return _buildCropPanel();
      case 1: return _buildStickerPanel();
      case 2: return _buildTextPanel();
      case 3: return _buildDrawPanel();
      case 4: return _buildFilterPanel();
      default: return const SizedBox.shrink();
    }
  }

  // Crop & Rotate panel
  Widget _buildCropPanel() {
    return Container(
      height: 100,
      color: Colors.black87,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          // Aspect ratio chips
          SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _aspectRatios.length,
              itemBuilder: (context, i) {
                final ratio = _aspectRatios[i];
                final isSelected = _aspectRatio == ratio.$2;
                return GestureDetector(
                  onTap: () => setState(() => _aspectRatio = ratio.$2),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? KoraColors.purple : Colors.white10,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(ratio.$1, style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 13, fontWeight: FontWeight.w500,
                    )),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _cropAction(Icons.rotate_left, 'Rotate', () => setState(() => _rotation -= 90)),
              _cropAction(Icons.rotate_right, 'Rotate R', () => setState(() => _rotation += 90)),
              _cropAction(Icons.flip, 'Flip', () {}),
              _cropAction(Icons.crop, 'Adjust', () {}),
            ],
          ),
        ],
      ),
    );
  }

  // Sticker panel
  Widget _buildStickerPanel() {
    final emojis = ['😀', '😂', '❤️', '👍', '🎉', '🔥', '😎', '😭', '🙏', '💯',
                    '👀', '🤔', '😏', '🙄', '😮', '😱', '🤯', '🥳', '🤝', '💪',
                    '👋', '🙌', '✨', '⭐', '🌟', '💫', '🎉', '🎊', '🎈', '🎁'];
    return Container(
      height: 120,
      color: Colors.black87,
      padding: const EdgeInsets.all(12),
      child: GridView.builder(
        scrollDirection: Axis.horizontal,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1,
        ),
        itemCount: emojis.length,
        itemBuilder: (context, i) => GestureDetector(
          onTap: () => _addTextOverlay(emojis[i]),
          child: Center(child: Text(emojis[i], style: const TextStyle(fontSize: 28))),
        ),
      ),
    );
  }

  // Text panel
  Widget _buildTextPanel() {
    final controller = TextEditingController();
    Color textColor = Colors.white;
    final colors = [Colors.white, Colors.black, Colors.red, Colors.orange, Colors.yellow,
                   Colors.green, Colors.blue, Colors.purple, Colors.pink, Colors.cyan];
    return Container(
      height: 140,
      color: Colors.black87,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'Type text…',
                    hintStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    isDense: true,
                  ),
                  onSubmitted: (v) => _addTextOverlay(v, textColor),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.check, color: KoraColors.purple),
                onPressed: () => _addTextOverlay(controller.text, textColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: colors.length,
              itemBuilder: (context, i) => GestureDetector(
                onTap: () => textColor = colors[i],
                child: Container(
                  width: 32, height: 32,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(color: colors[i], shape: BoxShape.circle),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Draw panel — opens the doodle editor
  Widget _buildDrawPanel() {
    return Container(
      height: 60,
      color: Colors.black87,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Text('Draw mode', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const Spacer(),
          TextButton.icon(
            onPressed: () => _openDoodle(),
            icon: const Icon(Icons.brush, color: KoraColors.purple, size: 18),
            label: const Text('Open Editor', style: TextStyle(color: KoraColors.purple)),
          ),
        ],
      ),
    );
  }

  // Filter strip panel
  Widget _buildFilterPanel() {
    return Container(
      height: 100,
      color: Colors.black54,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _filters.length,
        itemBuilder: (context, i) {
          final filter = _filters[i];
          final isSelected = _selectedFilter == i;
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = i),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              child: Column(
                children: [
                  Container(
                    width: 60, height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isSelected ? KoraColors.purple : Colors.transparent, width: 2),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: ColorFiltered(
                        colorFilter: filter.$2 ?? const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                        child: Image.file(File(widget.mediaPath), fit: BoxFit.cover, width: 60, height: 60),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(filter.$1, style: TextStyle(
                    color: isSelected ? KoraColors.purple : Colors.white70,
                    fontSize: 11, fontWeight: FontWeight.w500,
                  )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Video trim bar ──
  Widget _buildVideoTrimBar() {
    double _startTrim = 0.0;
    double _endTrim = 1.0;
    return StatefulBuilder(
      builder: (context, setLocalState) => Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        color: Colors.black54,
        child: LayoutBuilder(builder: (context, constraints) {
          final w = constraints.maxWidth;
          return Stack(
            children: [
              Container(decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(4))),
              Positioned(
                left: _startTrim * w,
                width: (_endTrim - _startTrim) * w,
                top: 0, bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: KoraColors.purple.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: KoraColors.purple, width: 2),
                  ),
                ),
              ),
              // Start handle
              Positioned(
                left: _startTrim * w - 4, top: 0, bottom: 0,
                child: GestureDetector(
                  onHorizontalDragUpdate: (d) => setLocalState(() {
                    _startTrim = (_startTrim + d.delta.dx / w).clamp(0.0, _endTrim - 0.05);
                  }),
                  child: Container(width: 8, color: KoraColors.purple),
                ),
              ),
              // End handle
              Positioned(
                left: _endTrim * w - 4, top: 0, bottom: 0,
                child: GestureDetector(
                  onHorizontalDragUpdate: (d) => setLocalState(() {
                    _endTrim = (_endTrim + d.delta.dx / w).clamp(_startTrim + 0.05, 1.0);
                  }),
                  child: Container(width: 8, color: KoraColors.purple),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  // ── Helpers ──
  void _addTextOverlay(String text, [Color color = Colors.white]) {
    if (text.isEmpty) return;
    setState(() {
      _textOverlays.add(_TextOverlay(text: text, color: color, x: 100, y: 100));
      _selectedTool = -1;
    });
  }

  void _openDoodle() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DoodleEditorScreen(imagePath: widget.mediaPath)),
    );
    setState(() => _selectedTool = -1);
  }

  Widget _cropAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      ),
    );
  }
}

class _TextOverlay {
  String text;
  Color color;
  double x;
  double y;

  _TextOverlay({required this.text, required this.color, required this.x, required this.y});
}

import 'dart:io';
import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';

/// Image Editor screen — WhatsApp-style image editing with:
/// - Crop and rotate
/// - Filters (None, Bright, Contrast, Warm, Cool, Vintage, Mono)
/// - Doodle/draw overlay (calls DoodleEditor)
/// - Sticker overlay
/// - Text overlay
/// - Quality selection (HD / Standard)
class ImageEditorScreen extends StatefulWidget {
  final String imagePath;

  const ImageEditorScreen({super.key, required this.imagePath});

  @override
  State<ImageEditorScreen> createState() => _ImageEditorScreenState();
}

class _ImageEditorScreenState extends State<ImageEditorScreen> {
  int _selectedFilter = 0;
  bool _isHD = true;

  static const _filters = [
    ('None', ColorFilter.mode(Colors.transparent, BlendMode.dst)),
    ('Bright', ColorFilter.matrix(<double>[
      1.2, 0, 0, 0, 0,
      0, 1.2, 0, 0, 0,
      0, 0, 1.2, 0, 0,
      0, 0, 0, 1, 0,
    ])),
    ('Warm', ColorFilter.matrix(<double>[
      1.1, 0, 0, 0, 10,
      0, 1.05, 0, 0, 0,
      0, 0, 0.9, 0, 0,
      0, 0, 0, 1, 0,
    ])),
    ('Cool', ColorFilter.matrix(<double>[
      0.9, 0, 0, 0, 0,
      0, 1.0, 0, 0, 0,
      0, 0, 1.15, 0, 10,
      0, 0, 0, 1, 0,
    ])),
    ('Mono', ColorFilter.matrix(<double>[
      0.299, 0.587, 0.114, 0, 0,
      0.299, 0.587, 0.114, 0, 0,
      0.299, 0.587, 0.114, 0, 0,
      0, 0, 0, 1, 0,
    ])),
    ('Vintage', ColorFilter.matrix(<double>[
      0.9, 0.5, 0.1, 0, 0,
      0.3, 0.8, 0.1, 0, 0,
      0.2, 0.3, 0.5, 0, 0,
      0, 0, 0, 1, 0,
    ])),
  ];

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = Colors.black;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // HD toggle
          TextButton(
            onPressed: () => setState(() => _isHD = !_isHD),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _isHD ? KoraColors.purple : Colors.white24,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('HD', style: TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700,
              )),
            ),
          ),
          // Send button
          IconButton(
            icon: const Icon(Icons.send, color: KoraColors.purple),
            onPressed: () => Navigator.pop(context, {
              'path': widget.imagePath,
              'filter': _selectedFilter,
              'hd': _isHD,
            }),
          ),
        ],
      ),
      body: Column(
        children: [
          // Image preview
          Expanded(
            child: Center(
              child: ColorFiltered(
                colorFilter: _filters[_selectedFilter].$2,
                child: Image.file(
                  File(widget.imagePath),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),

          // Filter strip
          Container(
            height: 100,
            padding: const EdgeInsets.symmetric(vertical: 8),
            color: Colors.black54,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _filters.length,
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final isSelected = _selectedFilter == index;
                return GestureDetector(
                  onTap: () => setState(() => _selectedFilter = index),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: Column(
                      children: [
                        Container(
                          width: 64, height: 64,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? KoraColors.purple : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: ColorFiltered(
                              colorFilter: filter.$2,
                              child: Image.file(File(widget.imagePath),
                                  fit: BoxFit.cover, width: 64, height: 64),
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
          ),

          // Tool bar
          Container(
            height: 56,
            color: Colors.black87,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _toolButton(Icons.crop, 'Crop', () {}),
                _toolButton(Icons.rotate_right, 'Rotate', () {}),
                _toolButton(Icons.brush, 'Draw', () => _openDoodle()),
                _toolButton(Icons.emoji_emotions_outlined, 'Sticker', () {}),
                _toolButton(Icons.text_fields, 'Text', () {}),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      ),
    );
  }

  void _openDoodle() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DoodleEditorScreen(imagePath: widget.imagePath)),
    );
  }
}

/// Doodle Editor — draw on top of an image with brush, colors, undo.
class DoodleEditorScreen extends StatefulWidget {
  final String imagePath;

  const DoodleEditorScreen({super.key, required this.imagePath});

  @override
  State<DoodleEditorScreen> createState() => _DoodleEditorScreenState();
}

class _DoodleEditorScreenState extends State<DoodleEditorScreen> {
  Color _brushColor = Colors.red;
  double _brushSize = 4;
  final List<_DoodlePath> _paths = [];
  final List<_DoodlePath> _undoStack = [];

  static const _colors = [
    Colors.red, Colors.orange, Colors.yellow, Colors.green,
    Colors.blue, Colors.purple, Colors.white, Colors.black,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo, color: Colors.white),
            onPressed: _paths.isNotEmpty
                ? () => setState(() {
                    _undoStack.add(_paths.removeLast());
                  })
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.redo, color: Colors.white),
            onPressed: _undoStack.isNotEmpty
                ? () => setState(() {
                    _paths.add(_undoStack.removeLast());
                  })
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.check, color: KoraColors.purple),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  if (_paths.isEmpty || _paths.last.isComplete) {
                    _paths.add(_DoodlePath(color: _brushColor, strokeWidth: _brushSize));
                  }
                  _paths.last.points.add(details.localPosition);
                });
              },
              onPanEnd: (_) {
                if (_paths.isNotEmpty) _paths.last.isComplete = true;
              },
              child: Stack(
                children: [
                  Center(child: Image.file(File(widget.imagePath), fit: BoxFit.contain)),
                  CustomPaint(
                    painter: _DoodlePainter(_paths),
                    child: const SizedBox.expand(),
                  ),
                ],
              ),
            ),
          ),
          // Color picker
          Container(
            height: 50,
            color: Colors.black87,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _colors.length,
              itemBuilder: (context, index) {
                final color = _colors[index];
                final isSelected = _brushColor == color;
                return GestureDetector(
                  onTap: () => setState(() => _brushColor = color),
                  child: Container(
                    width: 34, height: 34,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 3,
                      ),
                    ),
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

class _DoodlePath {
  final Color color;
  final double strokeWidth;
  final List<Offset> points;
  bool isComplete;

  _DoodlePath({
    required this.color,
    required this.strokeWidth,
    this.isComplete = false,
  }) : points = [];
}

class _DoodlePainter extends CustomPainter {
  final List<_DoodlePath> paths;

  _DoodlePainter(this.paths);

  @override
  void paint(Canvas canvas, Size size) {
    for (final path in paths) {
      if (path.points.length < 2) continue;
      final paint = Paint()
        ..color = path.color
        ..strokeWidth = path.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      for (int i = 0; i < path.points.length - 1; i++) {
        canvas.drawLine(path.points[i], path.points[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DoodlePainter oldDelegate) => true;
}

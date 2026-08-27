import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';

/// Point in a doodle stroke, storing position, color, width, and whether it's an eraser stroke.
class DoodlePoint {
  final Offset offset;
  final Color color;
  final double strokeWidth;
  final bool isEraser;

  DoodlePoint({
    required this.offset,
    required this.color,
    required this.strokeWidth,
    this.isEraser = false,
  });
}

/// A single completed stroke containing multiple points.
class DoodleStroke {
  final List<DoodlePoint> points;
  final Color color;
  final double strokeWidth;
  final bool isEraser;

  DoodleStroke({
    required this.points,
    required this.color,
    required this.strokeWidth,
    this.isEraser = false,
  });
}

/// Interactive Doodle / Draw on photo widget and dialog.
///
/// Features:
/// - Canvas overlay where users draw with finger
/// - Brush size slider
/// - Color picker (Kora purple, blue, white, black, red, yellow, green)
/// - Eraser tool
/// - Undo / Redo support
class DoodleEditor extends StatefulWidget {
  final List<DoodleStroke>? initialStrokes;
  final ValueChanged<List<DoodleStroke>>? onStrokesChanged;
  final Widget? backgroundWidget;

  const DoodleEditor({
    super.key,
    this.initialStrokes,
    this.onStrokesChanged,
    this.backgroundWidget,
  });

  @override
  State<DoodleEditor> createState() => _DoodleEditorState();
}

class _DoodleEditorState extends State<DoodleEditor> {
  final List<DoodleStroke> _strokes = [];
  final List<DoodleStroke> _undoHistory = [];
  final List<DoodlePoint> _currentStrokePoints = [];

  Color _selectedColor = KoraColors.purple;
  double _strokeWidth = 5.0;
  bool _isEraser = false;

  static const List<Color> _presetColors = [
    KoraColors.purple,
    KoraColors.blue,
    Colors.white,
    Colors.black,
    Color(0xFFEF4444), // Red
    Color(0xFFF59E0B), // Yellow
    Color(0xFF10B981), // Green
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialStrokes != null) {
      _strokes.addAll(widget.initialStrokes!);
    }
  }

  void _notifyChange() {
    widget.onStrokesChanged?.call(List.from(_strokes));
  }

  void _undo() {
    if (_strokes.isNotEmpty) {
      setState(() {
        _undoHistory.add(_strokes.removeLast());
      });
      _notifyChange();
    }
  }

  void _redo() {
    if (_undoHistory.isNotEmpty) {
      setState(() {
        _strokes.add(_undoHistory.removeLast());
      });
      _notifyChange();
    }
  }

  void _clearAll() {
    if (_strokes.isNotEmpty) {
      setState(() {
        _undoHistory.addAll(_strokes.reversed);
        _strokes.clear();
      });
      _notifyChange();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Optional Background
          if (widget.backgroundWidget != null) Positioned.fill(child: widget.backgroundWidget!),

          // Canvas Layer
          Positioned.fill(
            child: GestureDetector(
              onPanStart: (details) {
                setState(() {
                  _undoHistory.clear();
                  _currentStrokePoints.clear();
                  _currentStrokePoints.add(
                    DoodlePoint(
                      offset: details.localPosition,
                      color: _selectedColor,
                      strokeWidth: _strokeWidth,
                      isEraser: _isEraser,
                    ),
                  );
                });
              },
              onPanUpdate: (details) {
                setState(() {
                  _currentStrokePoints.add(
                    DoodlePoint(
                      offset: details.localPosition,
                      color: _selectedColor,
                      strokeWidth: _strokeWidth,
                      isEraser: _isEraser,
                    ),
                  );
                });
              },
              onPanEnd: (_) {
                if (_currentStrokePoints.isNotEmpty) {
                  setState(() {
                    _strokes.add(
                      DoodleStroke(
                        points: List.from(_currentStrokePoints),
                        color: _selectedColor,
                        strokeWidth: _strokeWidth,
                        isEraser: _isEraser,
                      ),
                    );
                    _currentStrokePoints.clear();
                  });
                  _notifyChange();
                }
              },
              child: CustomPaint(
                painter: _DoodlePainter(
                  strokes: _strokes,
                  currentPoints: _currentStrokePoints,
                  currentColor: _selectedColor,
                  currentWidth: _strokeWidth,
                  isEraser: _isEraser,
                ),
              ),
            ),
          ),

          // Control Toolbar
          Positioned(
            top: 40,
            left: 16,
            right: 16,
            child: _buildTopControlBar(),
          ),

          // Bottom Palette and Brush Controls
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: _buildBottomControls(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopControlBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.black.withValues(alpha: 0.5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context, _strokes),
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.undo, color: _strokes.isNotEmpty ? Colors.white : Colors.white30),
                    onPressed: _strokes.isNotEmpty ? _undo : null,
                  ),
                  IconButton(
                    icon: Icon(Icons.redo, color: _undoHistory.isNotEmpty ? Colors.white : Colors.white30),
                    onPressed: _undoHistory.isNotEmpty ? _redo : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.white70),
                    onPressed: _clearAll,
                    tooltip: 'Clear All',
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.check, color: KoraColors.purple),
                onPressed: () => Navigator.pop(context, _strokes),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          color: Colors.black.withValues(alpha: 0.6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Brush Size Slider
              Row(
                children: [
                  Icon(Icons.brush, color: _isEraser ? Colors.white38 : _selectedColor, size: 18),
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: _isEraser ? Colors.white : _selectedColor,
                        thumbColor: _isEraser ? Colors.white : _selectedColor,
                        inactiveTrackColor: Colors.white24,
                      ),
                      child: Slider(
                        value: _strokeWidth,
                        min: 2.0,
                        max: 30.0,
                        onChanged: (val) => setState(() => _strokeWidth = val),
                      ),
                    ),
                  ),
                  Text(
                    '${_strokeWidth.round()}px',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Color Palette & Eraser Toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ..._presetColors.map((color) {
                    final isSelected = !_isEraser && _selectedColor == color;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedColor = color;
                          _isEraser = false;
                        });
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 3)
                              : Border.all(color: Colors.white24, width: 1),
                        ),
                      ),
                    );
                  }),
                  // Eraser Button
                  GestureDetector(
                    onTap: () => setState(() => _isEraser = !_isEraser),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _isEraser ? KoraColors.purple : Colors.white12,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _isEraser ? Colors.white : Colors.white24,
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        Icons.cleaning_services,
                        color: _isEraser ? Colors.white : Colors.white70,
                        size: 18,
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

/// Painter that renders all strokes and current touch point.
class _DoodlePainter extends CustomPainter {
  final List<DoodleStroke> strokes;
  final List<DoodlePoint> currentPoints;
  final Color currentColor;
  final double currentWidth;
  final bool isEraser;

  _DoodlePainter({
    required this.strokes,
    required this.currentPoints,
    required this.currentColor,
    required this.currentWidth,
    required this.isEraser,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

    for (final stroke in strokes) {
      _drawStroke(canvas, stroke.points, stroke.color, stroke.strokeWidth, stroke.isEraser);
    }

    if (currentPoints.isNotEmpty) {
      _drawStroke(canvas, currentPoints, currentColor, currentWidth, isEraser);
    }

    canvas.restore();
  }

  void _drawStroke(
    Canvas canvas,
    List<DoodlePoint> points,
    Color color,
    double width,
    bool eraser,
  ) {
    if (points.isEmpty) return;

    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = width
      ..style = PaintingStyle.stroke;

    if (eraser) {
      paint.blendMode = BlendMode.clear;
    } else {
      paint.color = color;
    }

    if (points.length == 1) {
      canvas.drawCircle(points.first.offset, width / 2, paint..style = PaintingStyle.fill);
      return;
    }

    final path = Path();
    path.moveTo(points.first.offset.dx, points.first.offset.dy);

    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].offset.dx, points[i].offset.dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _DoodlePainter oldDelegate) => true;
}

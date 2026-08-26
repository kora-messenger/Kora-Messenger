import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/kora_colors.dart';

/// WhatsApp-style media editor/preview screen.
///
/// Opens after capturing or selecting media. Lets the user:
/// - Add a caption
/// - Toggle HD quality
/// - Toggle view-once
/// - Crop, add text overlay, draw, add stickers (future: basic versions now)
/// - Send the media with the caption
///
/// Returns a Map with: path, isVideo, caption, isViewOnce, isHD
class MediaEditorScreen extends StatefulWidget {
  final String mediaPath;
  final bool isVideo;
  final List<({String path, bool isVideo})>? multiMedia;

  const MediaEditorScreen({
    super.key,
    required this.mediaPath,
    required this.isVideo,
    this.multiMedia,
  });

  @override
  State<MediaEditorScreen> createState() => _MediaEditorScreenState();
}

enum _EditorTool { none, crop, text, draw, sticker }

class _MediaEditorScreenState extends State<MediaEditorScreen> {
  final _captionController = TextEditingController();
  bool _isViewOnce = false;
  bool _isHD = false;
  _EditorTool _activeTool = _EditorTool.none;

  // Text overlay state
  String _textOverlay = '';
  Color _textColor = Colors.white;
  Offset _textPosition = const Offset(0.5, 0.3);

  // Drawing state
  final List<List<Offset>> _strokes = [];
  List<Offset> _currentStroke = [];
  Color _drawColor = KoraColors.purple;
  double _strokeWidth = 4.0;

  // Media dimensions
  double? _mediaWidth;
  double? _mediaHeight;

  @override
  void initState() {
    super.initState();
    _loadMediaInfo();
  }

  void _loadMediaInfo() async {
    try {
      if (widget.isVideo) {
        // For videos, we use the thumbnail/first frame
        // Video dimensions would come from video_player metadata
        // For now, use standard 9:16 or 16:9
        setState(() {
          _mediaWidth = 1080;
          _mediaHeight = 1920;
        });
      } else {
        // Decode image to get dimensions
        final bytes = await File(widget.mediaPath).readAsBytes();
        final codec = await instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        setState(() {
          _mediaWidth = frame.image.width.toDouble();
          _mediaHeight = frame.image.height.toDouble();
        });
        frame.image.dispose();
        codec.dispose();
      }
    } catch (e) {
      debugPrint('Media info error: $e');
    }
  }

  void _send() {
    Navigator.pop(context, {
      'path': widget.mediaPath,
      'isVideo': widget.isVideo,
      'caption': _captionController.text.trim(),
      'isViewOnce': _isViewOnce,
      'isHD': _isHD,
      'width': _mediaWidth,
      'height': _mediaHeight,
    });
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KoraColors.deepNavy,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(child: _buildMediaPreview()),
            _buildToolsBar(),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  // ── Top Bar ──
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.close, color: Colors.white, size: 26),
            ),
          ),
          const Spacer(),
          // HD toggle
          if (!_isViewOnce) ...[
            GestureDetector(
              onTap: () => setState(() => _isHD = !_isHD),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _isHD
                      ? KoraColors.purple.withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: _isHD
                      ? Border.all(color: KoraColors.purple, width: 1)
                      : null,
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.hd_outlined,
                      color: _isHD ? KoraColors.purple : Colors.white70,
                      size: 18),
                  const SizedBox(width: 4),
                  Text(
                    _isHD ? 'HD' : 'Standard',
                    style: TextStyle(
                      color: _isHD ? KoraColors.purple : Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(width: 8),
          ],
          // Crop icon
          _toolButton(Icons.crop, _EditorTool.crop),
        ],
      ),
    );
  }

  // ── Media Preview ──
  Widget _buildMediaPreview() {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_activeTool != _EditorTool.none) {
            setState(() => _activeTool = _EditorTool.none);
          }
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.black,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Media
              widget.isVideo
                  ? _buildVideoThumbnail()
                  : Image.file(File(widget.mediaPath), fit: BoxFit.contain),

              // Drawing layer
              if (_strokes.isNotEmpty || _currentStroke.isNotEmpty)
                CustomPaint(
                  painter: _DrawingPainter(_strokes, _currentStroke, _drawColor, _strokeWidth),
                ),

              // Text overlay
              if (_textOverlay.isNotEmpty)
                Positioned(
                  left: 0, right: 0,
                  top: 0, bottom: 0,
                  child: Center(
                    child: GestureDetector(
                      onPanUpdate: (d) {
                        setState(() {
                          _textPosition = Offset(
                            (_textPosition.dx + d.delta.dx).clamp(0.0, 1.0),
                            (_textPosition.dy + d.delta.dy).clamp(0.0, 1.0),
                          );
                        });
                      },
                      child: FractionalTranslation(
                        translation: Offset(
                          _textPosition.dx - 0.5,
                          _textPosition.dy - 0.5,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          color: Colors.black54,
                          child: Text(
                            _textOverlay,
                            style: TextStyle(
                              color: _textColor,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // Video play indicator
              if (widget.isVideo)
                const Center(
                  child: Icon(Icons.play_circle_fill,
                      color: Colors.white70, size: 64),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoThumbnail() {
    // For now, show a dark placeholder. In production, generate a
    // thumbnail from the first frame using video_player or ffmpeg.
    final file = File(widget.mediaPath);
    if (!file.existsSync()) {
      return Container(color: Colors.black26);
    }
    return Container(
      color: Colors.black87,
      child: const Center(
        child: Icon(Icons.videocam, color: Colors.white24, size: 80),
      ),
    );
  }

  // ── Tools Bar (crop, text, draw, sticker) ──
  Widget _buildToolsBar() {
    if (_isViewOnce) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _toolButton2(Icons.text_fields, 'Text', _EditorTool.text),
          _toolButton2(Icons.emoji_emotions_outlined, 'Sticker', _EditorTool.sticker),
          _toolButton2(Icons.draw, 'Draw', _EditorTool.draw),
        ],
      ),
    );
  }

  Widget _toolButton(IconData icon, _EditorTool tool) {
    final isActive = _activeTool == tool;
    return GestureDetector(
      onTap: () => setState(() => _activeTool = isActive ? _EditorTool.none : tool),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon,
            color: isActive ? KoraColors.purple : Colors.white70, size: 24),
      ),
    );
  }

  Widget _toolButton2(IconData icon, String label, _EditorTool tool) {
    final isActive = _activeTool == tool;
    return GestureDetector(
      onTap: () => _handleToolTap(tool),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              color: isActive ? KoraColors.purple : Colors.white70, size: 24),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                color: isActive ? KoraColors.purple : Colors.white54,
                fontSize: 11,
              )),
        ],
      ),
    );
  }

  void _handleToolTap(_EditorTool tool) {
    if (tool == _EditorTool.text) {
      _showTextInput();
    } else if (tool == _EditorTool.draw) {
      setState(() => _activeTool = _EditorTool.draw);
    } else if (tool == _EditorTool.sticker) {
      _showStickerPicker();
    }
  }

  void _showTextInput() {
    final controller = TextEditingController(text: _textOverlay);
    showModalBottomSheet(
      context: context,
      backgroundColor: KoraColors.deepNavy,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            // Color picker row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                _colorSwatch(Colors.white),
                _colorSwatch(Colors.black),
                _colorSwatch(KoraColors.purple),
                _colorSwatch(Colors.blue),
                _colorSwatch(Colors.green),
                _colorSwatch(Colors.yellow),
                _colorSwatch(Colors.red),
                _colorSwatch(Colors.orange),
              ]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 18),
              decoration: InputDecoration(
                hintText: 'Type text...',
                hintStyle: TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _textOverlay = controller.text;
                      _activeTool = _EditorTool.none;
                    });
                    Navigator.pop(ctx);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: KoraColors.purple,
                  ),
                  child: const Text('Done'),
                ),
                const SizedBox(width: 16),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _colorSwatch(Color color) {
    final isSelected = _textColor == color;
    return GestureDetector(
      onTap: () => setState(() => _textColor = color),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(color: KoraColors.purple, width: 3)
              : Border.all(color: Colors.white24, width: 1),
        ),
      ),
    );
  }

  void _showStickerPicker() {
    // For now, a simple emoji picker
    final emojis = ['😀', '😂', '❤️', '👍', '🔥', '🎉', '⭐', '👏', '😍', '🙏', '💯', '😎'];
    showModalBottomSheet(
      context: context,
      backgroundColor: KoraColors.deepNavy,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Add Sticker', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                childAspectRatio: 1,
              ),
              itemCount: emojis.length,
              itemBuilder: (_, i) => GestureDetector(
                onTap: () {
                  // Add as text overlay for now
                  setState(() {
                    _textOverlay = emojis[i];
                    _activeTool = _EditorTool.none;
                  });
                  Navigator.pop(ctx);
                },
                child: Center(
                  child: Text(emojis[i], style: const TextStyle(fontSize: 32)),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ── Bottom Bar (caption, view-once, send) ──
  Widget _buildBottomBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            // View-once toggle
            GestureDetector(
              onTap: () => setState(() => _isViewOnce = !_isViewOnce),
              child: Container(
                width: 44, height: 44,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: _isViewOnce
                      ? KoraColors.purple.withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isViewOnce ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: _isViewOnce ? KoraColors.purple : Colors.white70,
                  size: 22,
                ),
              ),
            ),

            // Caption field
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _captionController,
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                        maxLines: null,
                        decoration: InputDecoration(
                          hintText: _isViewOnce ? 'Add caption…' : 'Add a caption…',
                          hintStyle: TextStyle(color: Colors.white38, fontSize: 15),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Send button
            GestureDetector(
              onTap: _send,
              child: Container(
                width: 44, height: 44,
                decoration: const BoxDecoration(
                  gradient: KoraColors.brandGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for drawing strokes on media.
class _DrawingPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Offset> currentStroke;
  final Color color;
  final double strokeWidth;

  _DrawingPainter(this.strokes, this.currentStroke, this.color, this.strokeWidth);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      canvas.drawPoints(PointMode.polygon, stroke, paint);
    }
    if (currentStroke.length >= 2) {
      canvas.drawPoints(PointMode.polygon, currentStroke, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DrawingPainter old) => true;
}

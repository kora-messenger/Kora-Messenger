import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';

/// Video Trimmer screen — trim video before sending.
/// Shows a timeline with draggable trim handles.
/// Also supports playback speed selection.
class VideoTrimmerScreen extends StatefulWidget {
  final String videoPath;
  final Duration totalDuration;

  const VideoTrimmerScreen({
    super.key,
    required this.videoPath,
    this.totalDuration = const Duration(seconds: 30),
  });

  @override
  State<VideoTrimmerScreen> createState() => _VideoTrimmerScreenState();
}

class _VideoTrimmerScreenState extends State<VideoTrimmerScreen> {
  double _startTrim = 0.0;
  double _endTrim = 1.0;
  double _playbackSpeed = 1.0;

  static const _speeds = [0.5, 1.0, 1.5, 2.0];

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
            icon: const Icon(Icons.send, color: KoraColors.purple),
            onPressed: () => Navigator.pop(context, {
              'path': widget.videoPath,
              'startTrim': _startTrim,
              'endTrim': _endTrim,
              'speed': _playbackSpeed,
            }),
          ),
        ],
      ),
      body: Column(
        children: [
          // Video preview placeholder
          Expanded(
            child: Center(
              child: Container(
                width: 200, height: 200,
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.play_circle_fill,
                    color: Colors.white54, size: 64),
              ),
            ),
          ),

          // Playback speed
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _speeds.map((speed) {
                final isSelected = _playbackSpeed == speed;
                return GestureDetector(
                  onTap: () => setState(() => _playbackSpeed = speed),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? KoraColors.purple : Colors.white12,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text('${speed}x', style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 13, fontWeight: FontWeight.w600,
                    )),
                  ),
                );
              }).toList(),
            ),
          ),

          // Trim bar
          Container(
            height: 80,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.black87,
            child: Column(
              children: [
                // Timeline
                Expanded(
                  child: LayoutBuilder(builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    return Stack(
                      children: [
                        // Full bar
                        Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        // Selected region
                        Positioned(
                          left: _startTrim * width,
                          width: (_endTrim - _startTrim) * width,
                          top: 0,
                          bottom: 0,
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: KoraColors.purple.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: KoraColors.purple, width: 2),
                            ),
                          ),
                        ),
                        // Start handle
                        Positioned(
                          left: _startTrim * width - 8,
                          top: 0, bottom: 0,
                          child: GestureDetector(
                            onHorizontalDragUpdate: (details) {
                              setState(() {
                                _startTrim = (_startTrim + details.delta.dx / width)
                                    .clamp(0.0, _endTrim - 0.05);
                              });
                            },
                            child: Container(
                              width: 16, height: 48,
                              decoration: BoxDecoration(
                                color: KoraColors.purple,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Icon(Icons.drag_handle,
                                  color: Colors.white, size: 14),
                            ),
                          ),
                        ),
                        // End handle
                        Positioned(
                          left: _endTrim * width - 8,
                          top: 0, bottom: 0,
                          child: GestureDetector(
                            onHorizontalDragUpdate: (details) {
                              setState(() {
                                _endTrim = (_endTrim + details.delta.dx / width)
                                    .clamp(_startTrim + 0.05, 1.0);
                              });
                            },
                            child: Container(
                              width: 16, height: 48,
                              decoration: BoxDecoration(
                                color: KoraColors.purple,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Icon(Icons.drag_handle,
                                  color: Colors.white, size: 14),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(_startTrim * widget.totalDuration.inSeconds).round()}s - '
                  '${(_endTrim * widget.totalDuration.inSeconds).round()}s',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// GIF Search Sheet — search and select GIFs for sending.
/// Uses a grid of trending/search GIFs.
class GifSearchSheet extends StatefulWidget {
  const GifSearchSheet({super.key});

  @override
  State<GifSearchSheet> createState() => _GifSearchSheetState();
}

class _GifSearchSheetState extends State<GifSearchSheet> {
  final _searchController = TextEditingController();
  final List<String> _trendingTags = [
    '😂', '❤️', '👍', '🎉', '🔥', '😎', '😭', '🤔',
    '👋', '🙏', '💯', '👀', '🙌', '🥳', '😅', '🤝',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search, color: textMuted, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            style: TextStyle(color: textPrimary, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Search GIFs…',
                              hintStyle: TextStyle(color: textMuted, fontSize: 14),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // GIF grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _trendingTags.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () => Navigator.pop(context, _trendingTags[index]),
                  child: Container(
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        _trendingTags[index],
                        style: const TextStyle(fontSize: 32),
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

/// Document Viewer screen — preview documents (PDF, DOCX, etc.)
/// before sending or after receiving.
class DocumentViewerScreen extends StatelessWidget {
  final String filePath;
  final String fileName;
  final int fileSizeBytes;

  const DocumentViewerScreen({
    super.key,
    required this.filePath,
    required this.fileName,
    this.fileSizeBytes = 0,
  });

  String get _sizeText {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) return '${(fileSizeBytes / 1024).round()} KB';
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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
        title: Text(fileName, style: TextStyle(
            color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 100,
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: KoraColors.purple.withValues(alpha: 0.3)),
              ),
              child: Icon(Icons.description, size: 40,
                  color: KoraColors.purple),
            ),
            const SizedBox(height: 16),
            Text(fileName, style: TextStyle(
                color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(_sizeText, style: TextStyle(color: textMuted, fontSize: 13)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Save to device'),
              style: ElevatedButton.styleFrom(
                backgroundColor: KoraColors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

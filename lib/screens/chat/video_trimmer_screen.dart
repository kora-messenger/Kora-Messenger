import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';

/// Video Trimmer screen — trim video clips before sending.
/// Mirrors WhatsApp's video trimming interface.
///
/// Shows a filmstrip with draggable start/end handles, duration display,
/// and a preview. Result is the trimmed video path with start/end timestamps.
class VideoTrimmerScreen extends StatefulWidget {
  final String videoPath;

  const VideoTrimmerScreen({super.key, required this.videoPath});

  @override
  State<VideoTrimmerScreen> createState() => _VideoTrimmerScreenState();
}

class _VideoTrimmerScreenState extends State<VideoTrimmerScreen> {
  double _startPos = 0.0;
  double _endPos = 1.0;
  double _videoDuration = 30.0; // seconds — would come from video metadata

  String get _trimmedDuration {
    final start = (_startPos * _videoDuration).round();
    final end = (_endPos * _videoDuration).round();
    final duration = end - start;
    final m = (duration / 60).floor();
    final s = duration % 60;
    return '${m}m ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Trim Video', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, {
              'path': widget.videoPath,
              'start': _startPos,
              'end': _endPos,
            }),
            child: Text('Send', style: TextStyle(color: KoraColors.purple, fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Video preview area
          Expanded(
            child: Center(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(Icons.play_circle_fill, size: 64, color: Colors.white54),
                ),
              ),
            ),
          ),
          // Duration display
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${(_startPos * _videoDuration).round()}s',
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
                Text(_trimmedDuration,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                Text('${(_endPos * _videoDuration).round()}s',
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
          // Trim slider
          Container(
            height: 80,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.black87,
            child: Stack(
              children: [
                // Filmstrip background
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: List.generate(20, (i) => Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 0.5),
                        color: Colors.white12,
                      ),
                    )),
                  ),
                ),
                // Selected region overlay
                Positioned(
                  left: _startPos * (MediaQuery.of(context).size.width - 32),
                  right: (1 - _endPos) * (MediaQuery.of(context).size.width - 32),
                  top: 0, bottom: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: KoraColors.purple, width: 2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                // Start handle
                Positioned(
                  left: _startPos * (MediaQuery.of(context).size.width - 32) - 8,
                  top: 0, bottom: 0,
                  child: GestureDetector(
                    onHorizontalDragUpdate: (d) {
                      setState(() {
                        _startPos = (_startPos + d.delta.dx / (MediaQuery.of(context).size.width - 32))
                            .clamp(0.0, _endPos - 0.05);
                      });
                    },
                    child: Container(
                      width: 16,
                      decoration: BoxDecoration(
                        color: KoraColors.purple,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Center(child: Icon(Icons.chevron_right, color: Colors.white, size: 16)),
                    ),
                  ),
                ),
                // End handle
                Positioned(
                  right: (1 - _endPos) * (MediaQuery.of(context).size.width - 32) - 8,
                  top: 0, bottom: 0,
                  child: GestureDetector(
                    onHorizontalDragUpdate: (d) {
                      setState(() {
                        _endPos = (_endPos - d.delta.dx / (MediaQuery.of(context).size.width - 32))
                            .clamp(_startPos + 0.05, 1.0);
                      });
                    },
                    child: Container(
                      width: 16,
                      decoration: BoxDecoration(
                        color: KoraColors.purple,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Center(child: Icon(Icons.chevron_left, color: Colors.white, size: 16)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

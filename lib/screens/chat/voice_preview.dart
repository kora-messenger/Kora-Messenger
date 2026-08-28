import 'package:flutter/material.dart';

class VoicePreview extends StatefulWidget {
  final String? voiceFilePath;
  final int? duration;

  const VoicePreview({super.key, this.voiceFilePath, this.duration});

  @override
  State<VoicePreview> createState() => _VoicePreviewState();
}

class _VoicePreviewState extends State<VoicePreview> {
  bool _isPlaying = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
            onPressed: () => setState(() => _isPlaying = !_isPlaying),
          ),
          if (widget.duration != null)
            Text('${widget.duration! ~/ 60}:${(widget.duration! % 60).toString().padLeft(2, '0')}'),
        ],
      ),
    );
  }
}

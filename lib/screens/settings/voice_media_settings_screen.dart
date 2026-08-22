import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme/chat_theme_provider.dart';
import '../../theme/kora_colors.dart';
import 'premium_subscribe_sheet.dart';

/// Kora's Voice & Media settings — upload your own audio/video for
/// supported Kora voice features.
///
/// Flow: Settings → Voice & Media → Upload Your Own Voice →
/// Select Audio/Video → Consent Warning → Agree → Upload → Process
///
/// Premium Feature: Premium check is enforced before upload flow opens.
class VoiceMediaSettingsScreen extends StatefulWidget {
  const VoiceMediaSettingsScreen({super.key});

  @override
  State<VoiceMediaSettingsScreen> createState() =>
      _VoiceMediaSettingsScreenState();
}

class _VoiceMediaSettingsScreenState extends State<VoiceMediaSettingsScreen> {
  static const String _kUploadsKey = 'kora_voice_uploads';
  List<Map<String, dynamic>> _uploadedFiles = [];
  bool _loadingUploads = true;

  @override
  void initState() {
    super.initState();
    _loadUploadedFiles();
  }

  Future<void> _loadUploadedFiles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kUploadsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List;
        if (mounted) {
          setState(() {
            _uploadedFiles = list.cast<Map<String, dynamic>>();
            _loadingUploads = false;
          });
        }
        return;
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _uploadedFiles = [];
        _loadingUploads = false;
      });
    }
  }

  Future<void> _deleteUploadedFile(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kUploadsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        final index = list.indexWhere((item) => item['id'] == id);
        if (index != -1) {
          final item = list[index];
          final path = item['path'] as String?;
          if (path != null && path.isNotEmpty) {
            try {
              final file = File(path);
              if (await file.exists()) {
                await file.delete();
              }
            } catch (_) {}
          }
          list.removeAt(index);
          await prefs.setString(_kUploadsKey, jsonEncode(list));
        }
      } catch (_) {}
    }
    await _loadUploadedFiles();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Upload deleted'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showUploadFlow(BuildContext context) {
    if (!ChatThemeProvider.instance.isPremium) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => const PremiumSubscribeSheet(),
      );
      return;
    }

    final brightness = Theme.of(context).brightness;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _UploadFlowSheet(
        brightness: brightness,
        onUploadChanged: _loadUploadedFiles,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final card = KoraColors.cardFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);
    final border = KoraColors.borderFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: card,
        elevation: 0,
        title: Text(
          'Voice & Media',
          style: TextStyle(
            color: textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ── Info card ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: KoraColors.purple.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: KoraColors.purple.withValues(alpha: 0.12),
                  width: 0.5,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.graphic_eq_rounded, size: 22, color: KoraColors.purple),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Manage voice, audio, and video features. Upload your own audio or video to use through supported Kora features.',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 13.5,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Upload Your Own Voice ──
          _sectionLabel('UPLOAD', textMuted),
          _card(
            card: card,
            border: border,
            children: [
              InkWell(
                onTap: () => _showUploadFlow(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: KoraColors.purple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.upload_file_rounded, color: KoraColors.purple, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Upload Your Own Voice',
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Select an audio or video file from your device',
                              style: TextStyle(color: textSecondary, fontSize: 12.5),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: textMuted),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Previously Uploaded Files ──
          _sectionLabel('PREVIOUSLY UPLOADED FILES', textMuted),
          _card(
            card: card,
            border: border,
            children: _buildUploadedFilesList(card, textPrimary, textSecondary, textMuted, border),
          ),

          const SizedBox(height: 20),

          // ── Consent info ──
          _sectionLabel('CONSENT', textMuted),
          _card(
            card: card,
            border: border,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: KoraColors.purple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.privacy_tip_outlined, color: KoraColors.purple, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Consent Protection',
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'You must confirm consent before uploading any media',
                            style: TextStyle(color: textSecondary, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  List<Widget> _buildUploadedFilesList(
    Color card,
    Color textPrimary,
    Color textSecondary,
    Color textMuted,
    Color border,
  ) {
    if (_loadingUploads) {
      return [
        const Padding(
          padding: EdgeInsets.all(20),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: KoraColors.purple,
              ),
            ),
          ),
        ),
      ];
    }

    if (_uploadedFiles.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.folder_open_rounded, color: textMuted, size: 22),
              const SizedBox(width: 12),
              Text(
                'No uploaded files yet',
                style: TextStyle(color: textSecondary, fontSize: 13.5),
              ),
            ],
          ),
        ),
      ];
    }

    final widgets = <Widget>[];
    for (int i = 0; i < _uploadedFiles.length; i++) {
      final fileData = _uploadedFiles[i];
      final id = fileData['id']?.toString() ?? '';
      final name = fileData['name']?.toString() ?? 'Unnamed File';
      final type = fileData['type']?.toString() ?? 'audio';
      final isVideo = type == 'video';

      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: KoraColors.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isVideo ? Icons.movie_rounded : Icons.audiotrack_rounded,
                  color: KoraColors.purple,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      type.toUpperCase(),
                      style: TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: KoraColors.red, size: 20),
                onPressed: () => _deleteUploadedFile(id),
                tooltip: 'Delete Upload',
              ),
            ],
          ),
        ),
      );

      if (i < _uploadedFiles.length - 1) {
        widgets.add(Divider(height: 1, color: border, indent: 14, endIndent: 14));
      }
    }

    return widgets;
  }

  Widget _sectionLabel(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _card({
    required Color card,
    required Color border,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: 0.3),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

// ── Upload Flow Bottom Sheet ──────────────────────────────────

class _UploadFlowSheet extends StatefulWidget {
  final Brightness brightness;
  final VoidCallback? onUploadChanged;

  const _UploadFlowSheet({
    required this.brightness,
    this.onUploadChanged,
  });

  @override
  State<_UploadFlowSheet> createState() => _UploadFlowSheetState();
}

class _UploadFlowSheetState extends State<_UploadFlowSheet> {
  String? _selectedFilePath;
  String? _selectedFileName;
  String? _selectedFileType;
  String? _uploadedFileId;

  bool _agreed = false;
  bool _uploading = false;
  bool _uploaded = false;

  Future<void> _selectFile(String type) async {
    final extensions = type == 'audio'
        ? ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac']
        : ['mp4', 'mov', 'avi', 'mkv'];

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: extensions,
      );

      if (result != null && result.files.isNotEmpty && result.files.first.path != null) {
        final file = result.files.first;
        setState(() {
          _selectedFilePath = file.path;
          _selectedFileName = file.name;
          _selectedFileType = type;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting file: $e'),
            backgroundColor: KoraColors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _doUpload() async {
    if (_selectedFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an audio or video file first.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _uploading = true);

    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final uploadsDir = Directory('${docsDir.path}/kora_voice_uploads');
      if (!await uploadsDir.exists()) {
        await uploadsDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileId = timestamp.toString();
      final fileName = _selectedFileName ?? 'file_$fileId';
      final savedPath = '${uploadsDir.path}/${timestamp}_$fileName';

      final sourceFile = File(_selectedFilePath!);
      await sourceFile.copy(savedPath);

      final metadata = {
        'id': fileId,
        'path': savedPath,
        'name': fileName,
        'type': _selectedFileType ?? 'audio',
        'uploadDate': DateTime.now().toIso8601String(),
      };

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('kora_voice_uploads');
      List list = [];
      if (raw != null && raw.isNotEmpty) {
        try {
          list = jsonDecode(raw) as List;
        } catch (_) {}
      }
      list.insert(0, metadata);
      await prefs.setString('kora_voice_uploads', jsonEncode(list));

      if (widget.onUploadChanged != null) {
        widget.onUploadChanged!();
      }

      if (mounted) {
        setState(() {
          _uploading = false;
          _uploaded = true;
          _uploadedFileId = fileId;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: KoraColors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deleteCurrentUpload() async {
    if (_uploadedFileId == null) return;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('kora_voice_uploads');
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        final index = list.indexWhere((item) => item['id'] == _uploadedFileId);
        if (index != -1) {
          final item = list[index];
          final path = item['path'] as String?;
          if (path != null && path.isNotEmpty) {
            try {
              final file = File(path);
              if (await file.exists()) {
                await file.delete();
              }
            } catch (_) {}
          }
          list.removeAt(index);
          await prefs.setString('kora_voice_uploads', jsonEncode(list));
        }
      } catch (_) {}
    }

    if (widget.onUploadChanged != null) {
      widget.onUploadChanged!();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Upload deleted'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = KoraColors.cardFor(widget.brightness);
    final surface = KoraColors.surfaceFor(widget.brightness);
    final textPrimary = KoraColors.textPrimaryFor(widget.brightness);
    final textSecondary = KoraColors.textSecondaryFor(widget.brightness);
    final textMuted = KoraColors.textMutedFor(widget.brightness);
    final border = KoraColors.borderFor(widget.brightness);

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
              child: Row(
                children: [
                  const Icon(Icons.upload_file_rounded, color: KoraColors.purple, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'Upload Voice / Media',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: textMuted, size: 22),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: border),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: _uploaded
                    ? _buildSuccessView(surface, textPrimary, textSecondary, border)
                    : _buildUploadView(surface, textPrimary, textSecondary, textMuted, border),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadView(
    Color surface,
    Color textPrimary,
    Color textSecondary,
    Color textMuted,
    Color border,
  ) {
    final bool canSubmit = _agreed && _selectedFilePath != null && !_uploading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── File type selection ──
        Text(
          'CHOOSE FILE TYPE',
          style: TextStyle(
            color: textMuted,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _fileTypeCard(
                Icons.audio_file_rounded,
                'Audio File',
                _selectedFileType == 'audio',
                surface,
                textPrimary,
                textSecondary,
                border,
                () => _selectFile('audio'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _fileTypeCard(
                Icons.video_file_rounded,
                'Video File',
                _selectedFileType == 'video',
                surface,
                textPrimary,
                textSecondary,
                border,
                () => _selectFile('video'),
              ),
            ),
          ],
        ),

        if (_selectedFileName != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: KoraColors.purple.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: KoraColors.purple.withValues(alpha: 0.25),
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _selectedFileType == 'video'
                      ? Icons.movie_rounded
                      : Icons.audiotrack_rounded,
                  color: KoraColors.purple,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selected File',
                        style: TextStyle(
                          color: textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _selectedFileName!,
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, size: 18, color: textMuted),
                  onPressed: () {
                    setState(() {
                      _selectedFilePath = null;
                      _selectedFileName = null;
                      _selectedFileType = null;
                    });
                  },
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 24),

        // ── Consent warning ──
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: KoraColors.red.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: KoraColors.red.withValues(alpha: 0.15),
              width: 0.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 20, color: KoraColors.red),
                  const SizedBox(width: 8),
                  Text(
                    'Before You Upload',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Don\'t upload any person\'s voice, audio, or video without their consent.',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 13.5,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Only upload media if this is your own audio/video or you have asked the owner for permission before uploading it.',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── Agreement checkbox ──
        GestureDetector(
          onTap: () => setState(() => _agreed = !_agreed),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: _agreed ? KoraColors.purple : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _agreed ? KoraColors.purple : border,
                    width: 1.5,
                  ),
                ),
                child: _agreed
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'I agree that this is my video/audio or I agree I have asked the owner of the video/audio before uploading it.',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 13.5,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ── Buttons ──
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: border, width: 0.5),
                  ),
                  child: Center(
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: canSubmit ? _doUpload : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: canSubmit ? KoraColors.brandGradient : null,
                    color: canSubmit ? null : surface,
                    borderRadius: BorderRadius.circular(12),
                    border: canSubmit ? null : Border.all(color: border, width: 0.5),
                  ),
                  child: Center(
                    child: _uploading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'I Agree',
                            style: TextStyle(
                              color: canSubmit ? Colors.white : textMuted,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _fileTypeCard(
    IconData icon,
    String label,
    bool isSelected,
    Color surface,
    Color textPrimary,
    Color textSecondary,
    Color border,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? KoraColors.purple.withValues(alpha: 0.08) : surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? KoraColors.purple : border,
            width: isSelected ? 1.5 : 0.5,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: isSelected ? KoraColors.purple : KoraColors.purple.withValues(alpha: 0.7)),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? KoraColors.purple : textPrimary,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessView(
    Color surface,
    Color textPrimary,
    Color textSecondary,
    Color border,
  ) {
    return Column(
      children: [
        const SizedBox(height: 20),
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: KoraColors.purple.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_rounded, size: 40, color: KoraColors.purple),
        ),
        const SizedBox(height: 16),
        Text(
          'Upload Complete',
          style: TextStyle(
            color: textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        if (_selectedFileName != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: border, width: 0.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _selectedFileType == 'video'
                      ? Icons.movie_rounded
                      : Icons.audiotrack_rounded,
                  size: 18,
                  color: KoraColors.purple,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _selectedFileName!,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        Text(
          'Your media has been processed and saved to Kora Voice & Media.',
          style: TextStyle(
            color: textSecondary,
            fontSize: 13.5,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _deleteCurrentUpload,
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: KoraColors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: KoraColors.red.withValues(alpha: 0.25),
                      width: 0.5,
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      'Delete Upload',
                      style: TextStyle(
                        color: KoraColors.red,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: KoraColors.brandGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text(
                      'Done',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

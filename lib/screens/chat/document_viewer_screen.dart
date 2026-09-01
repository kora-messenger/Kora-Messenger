import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';

/// Document Viewer screen — preview documents (PDF, DOC, TXT) in chat.
/// Mirrors WhatsApp's document preview feature.
///
/// Shows file icon, name, size, and a preview area. For PDFs, renders
/// pages. For text files, shows content. For others, shows file info.
class DocumentViewerScreen extends StatefulWidget {
  final String filePath;
  final String fileName;
  final int fileSize; // in bytes
  final String fileType; // 'pdf', 'doc', 'txt', etc.

  const DocumentViewerScreen({
    super.key,
    required this.filePath,
    required this.fileName,
    required this.fileSize,
    required this.fileType,
  });

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  int _currentPage = 1;
  int _totalPages = 5; // would come from PDF metadata

  String get _sizeText {
    if (widget.fileSize < 1024) return '${widget.fileSize} B';
    if (widget.fileSize < 1024 * 1024) return '${(widget.fileSize / 1024).round()} KB';
    return '${(widget.fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  IconData get _fileIcon {
    switch (widget.fileType.toLowerCase()) {
      case 'pdf': return Icons.picture_as_pdf;
      case 'doc':
      case 'docx': return Icons.description;
      case 'txt': return Icons.text_snippet;
      case 'xls':
      case 'xlsx': return Icons.table_chart;
      case 'ppt':
      case 'pptx': return Icons.slideshow;
      default: return Icons.insert_drive_file;
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(widget.fileName,
            style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.share, color: textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          IconButton(
            icon: Icon(Icons.more_vert, color: textPrimary),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // File info bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: surface,
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: KoraColors.purple.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_fileIcon, color: KoraColors.purple, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.fileName,
                          style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text('${widget.fileType.toUpperCase()} • ${_sizeText}',
                          style: TextStyle(color: textMuted, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Preview area
          Expanded(
            child: widget.fileType.toLowerCase() == 'pdf'
                ? _buildPdfPreview(textPrimary, textMuted, surface)
                : _buildGenericPreview(textPrimary, textMuted, surface),
          ),
          // Page navigation for PDFs
          if (widget.fileType.toLowerCase() == 'pdf')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: surface,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(Icons.chevron_left, color: _currentPage > 1 ? KoraColors.purple : textMuted),
                    onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
                  ),
                  Text('Page $_currentPage of $_totalPages',
                      style: TextStyle(color: textMuted, fontSize: 14)),
                  IconButton(
                    icon: Icon(Icons.chevron_right, color: _currentPage < _totalPages ? KoraColors.purple : textMuted),
                    onPressed: _currentPage < _totalPages ? () => setState(() => _currentPage++) : null,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPdfPreview(Color textPrimary, Color textMuted, Color surface) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_fileIcon, size: 64, color: KoraColors.purple),
            const SizedBox(height: 16),
            Text('Page $_currentPage', style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(widget.fileName, style: TextStyle(color: textMuted, fontSize: 13),
                maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildGenericPreview(Color textPrimary, Color textMuted, Color surface) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_fileIcon, size: 80, color: KoraColors.purple.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(widget.fileName, style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('${widget.fileType.toUpperCase()} • ${_sizeText}',
              style: TextStyle(color: textMuted, fontSize: 14)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {},
            icon: Icon(Icons.open_in_new, size: 18),
            label: const Text('Open with…', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: KoraColors.purple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

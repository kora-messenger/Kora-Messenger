import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../theme/kora_colors.dart';
import '../../models/status_model.dart';
import '../../services/status_service.dart';

/// WhatsApp 2026-style Layout/Collage screen for Status.
///
/// Users can select 2-6 photos and arrange them into a collage:
/// - 2 photos: side by side
/// - 3 photos: top + bottom split
/// - 4 photos: 2x2 grid
/// - 5-6 photos: various grid layouts
/// Each layout can be previewed before publishing as a status.
class StatusLayoutScreen extends StatefulWidget {
  const StatusLayoutScreen({super.key});

  @override
  State<StatusLayoutScreen> createState() => _StatusLayoutScreenState();
}

class _StatusLayoutScreenState extends State<StatusLayoutScreen> {
  final List<String> _selectedPhotos = [];
  int _layoutIndex = 0;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);
    final border = KoraColors.borderFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Layout',
            style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
        actions: [
          if (_selectedPhotos.isNotEmpty)
            TextButton(
              onPressed: _publish,
              child: Text('Done',
                  style: TextStyle(color: KoraColors.purple, fontSize: 16, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: Column(
        children: [
          // Preview area
          Expanded(
            child: _selectedPhotos.isEmpty
                ? _buildEmptyState(textPrimary, textSecondary, textMuted)
                : _buildPreview(textPrimary, textSecondary, textMuted, border),
          ),
          // Bottom controls
          if (_selectedPhotos.isNotEmpty) ...[
            // Layout switcher
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: surface,
                border: Border(top: BorderSide(color: border, width: 0.5)),
              ),
              child: Column(
                children: [
                  Text('Choose layout',
                      style: TextStyle(color: textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: _buildLayoutOptions(textPrimary, textMuted),
                  ),
                ],
              ),
            ),
            // Add / remove photos
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_selectedPhotos.length < 6)
                    GestureDetector(
                      onTap: _addPhoto,
                      child: Container(
                        width: 56, height: 56,
                        decoration: BoxDecoration(
                          color: KoraColors.purple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: KoraColors.purple.withValues(alpha: 0.3), width: 1),
                        ),
                        child: Icon(Icons.add_photo_alternate, color: KoraColors.purple, size: 26),
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _selectedPhotos.length,
                        itemBuilder: (context, index) {
                          return GestureDetector(
                            onTap: () => setState(() {
                              _selectedPhotos.removeAt(index);
                              if (_selectedPhotos.isEmpty) _layoutIndex = 0;
                            }),
                            child: Container(
                              width: 56, height: 56,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: border, width: 1),
                                image: DecorationImage(
                                  image: FileImage(File(_selectedPhotos[index])),
                                  fit: BoxFit.cover,
                                ),
                              ),
                              child: Align(
                                alignment: Alignment.topRight,
                                child: Container(
                                  margin: const EdgeInsets.all(2),
                                  width: 18, height: 18,
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close, color: Colors.white, size: 12),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _addPhoto,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: KoraColors.purple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text('Select Photos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(Color textPrimary, Color textSecondary, Color textMuted) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: KoraColors.purple.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.grid_view_rounded, color: KoraColors.purple, size: 40),
          ),
          const SizedBox(height: 20),
          Text('Create a Layout Status',
              style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Select 2-6 photos to combine into a collage',
              style: TextStyle(color: textSecondary, fontSize: 14)),
          const SizedBox(height: 4),
          Text('Choose from different grid layouts',
              style: TextStyle(color: textMuted, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildPreview(Color textPrimary, Color textSecondary, Color textMuted, Color border) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: AspectRatio(
          aspectRatio: 9 / 16,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border, width: 1),
              color: Colors.black12,
            ),
            clipBehavior: Clip.antiAlias,
            child: _buildGridLayout(),
          ),
        ),
      ),
    );
  }

  Widget _buildGridLayout() {
    final count = _selectedPhotos.length;
    if (count == 0) return const SizedBox();

    // Layout patterns based on count and layoutIndex
    switch (count) {
      case 2:
        return _layoutIndex == 0
            ? Row(children: _buildCells(2, axis: Axis.vertical))
            : Column(children: _buildCells(2, axis: Axis.horizontal));
      case 3:
        if (_layoutIndex == 0) {
          return Column(
            children: [
              Expanded(child: Image.file(File(_selectedPhotos[0]), fit: BoxFit.cover)),
              Expanded(
                child: Row(
                  children: [
                    Expanded(child: Image.file(File(_selectedPhotos[1]), fit: BoxFit.cover)),
                    Expanded(child: Image.file(File(_selectedPhotos[2]), fit: BoxFit.cover)),
                  ],
                ),
              ),
            ],
          );
        } else {
          return Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(child: Image.file(File(_selectedPhotos[0]), fit: BoxFit.cover)),
                    Expanded(child: Image.file(File(_selectedPhotos[1]), fit: BoxFit.cover)),
                  ],
                ),
              ),
              Expanded(child: Image.file(File(_selectedPhotos[2]), fit: BoxFit.cover)),
            ],
          );
        }
      case 4:
        return Column(
          children: [
            Expanded(child: Row(children: _buildCells(2, axis: Axis.horizontal))),
            Expanded(child: Row(children: _buildCells(2, axis: Axis.horizontal, offset: 2))),
          ],
        );
      case 5:
        return Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(flex: 2, child: Image.file(File(_selectedPhotos[0]), fit: BoxFit.cover)),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(child: Image.file(File(_selectedPhotos[1]), fit: BoxFit.cover)),
                        Expanded(child: Image.file(File(_selectedPhotos[2]), fit: BoxFit.cover)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: Image.file(File(_selectedPhotos[3]), fit: BoxFit.cover)),
                  Expanded(child: Image.file(File(_selectedPhotos[4]), fit: BoxFit.cover)),
                ],
              ),
            ),
          ],
        );
      case 6:
        return Column(
          children: [
            Expanded(child: Row(children: _buildCells(3, axis: Axis.horizontal))),
            Expanded(child: Row(children: _buildCells(3, axis: Axis.horizontal, offset: 3))),
          ],
        );
      default:
        return Row(children: _buildCells(count, axis: Axis.vertical));
    }
  }

  List<Widget> _buildCells(int count, {required Axis axis, int offset = 0}) {
    return List.generate(count, (i) {
      final idx = i + offset;
      if (idx >= _selectedPhotos.length) return const SizedBox();
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(1),
          child: Image.file(File(_selectedPhotos[idx]), fit: BoxFit.cover),
        ),
      );
    });
  }

  List<Widget> _buildLayoutOptions(Color textPrimary, Color textMuted) {
    final count = _selectedPhotos.length;
    if (count < 2) return [];

    final layouts = <_LayoutOption>[];

    if (count == 2) {
      layouts.addAll([
        _LayoutOption(Icons.view_column_outlined, 'Vertical'),
        _LayoutOption(Icons.view_agenda_outlined, 'Horizontal'),
      ]);
    } else if (count == 3) {
      layouts.addAll([
        _LayoutOption(Icons.grid_view_outlined, 'Top + 2'),
        _LayoutOption(Icons.view_agenda_outlined, '2 + Bottom'),
      ]);
    } else if (count == 4) {
      layouts.add(_LayoutOption(Icons.grid_view_rounded, '2x2'));
    } else if (count == 5) {
      layouts.add(_LayoutOption(Icons.grid_view_outlined, 'Layout 5'));
    } else if (count == 6) {
      layouts.add(_LayoutOption(Icons.grid_view_rounded, '2x3'));
    }

    return layouts.asMap().entries.map((entry) {
      final i = entry.key;
      final layout = entry.value;
      final isActive = i == _layoutIndex;
      return GestureDetector(
        onTap: () => setState(() => _layoutIndex = i),
        child: Container(
          width: 60, height: 60,
          decoration: BoxDecoration(
            color: isActive ? KoraColors.purple.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isActive
                ? Border.all(color: KoraColors.purple, width: 1.5)
                : Border.all(color: textMuted.withValues(alpha: 0.2), width: 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(layout.icon, color: isActive ? KoraColors.purple : textPrimary, size: 24),
              const SizedBox(height: 2),
              Text(layout.label, style: TextStyle(
                color: isActive ? KoraColors.purple : textMuted, fontSize: 9)),
            ],
          ),
        ),
      );
    }).toList();
  }

  void _addPhoto() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    final picker = ImagePicker();
    final photos = await picker.pickMultiImage(imageQuality: 100, limit: 6 - _selectedPhotos.length);

    if (photos.isNotEmpty && mounted) {
      setState(() {
        _selectedPhotos.addAll(photos.map((p) => p.path));
        _layoutIndex = 0;
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _publish() async {
    if (_selectedPhotos.isEmpty) return;

    // For collage status, store the first photo as main with a reference
    // In production, this would composite the images server-side
    final item = StatusItem(
      id: 'status_${DateTime.now().millisecondsSinceEpoch}',
      type: StatusType.photo,
      mediaPath: _selectedPhotos.first,
      text: 'Layout (${_selectedPhotos.length} photos)',
      createdAt: DateTime.now(),
    );
    await StatusService.instance.addStatusItem(item);

    if (mounted) {
      Navigator.of(context).popUntil((r) => r.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Layout status posted'),
          backgroundColor: KoraColors.purple,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _LayoutOption {
  final IconData icon;
  final String label;
  _LayoutOption(this.icon, this.label);
}

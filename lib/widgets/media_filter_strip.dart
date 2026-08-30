import 'package:flutter/material.dart';

/// Media Filter strip — horizontal scrollable filter picker for images.
/// Mirrors WhatsApp's filter strip in the camera/editor.
///
/// Filters: None, Pop, B&W, Cool, Warm, Vintage, Chrome, Faded
class MediaFilterStrip extends StatefulWidget {
  final ValueChanged<int> onFilterSelected;

  const MediaFilterStrip({super.key, required this.onFilterSelected});

  @override
  State<MediaFilterStrip> createState() => _MediaFilterStripState();
}

class _MediaFilterStripState extends State<MediaFilterStrip> {
  int _selected = 0;

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

  ColorFilter? get currentFilter => _filters[_selected].$2;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: Colors.black54,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _filters.length,
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = _selected == index;
          return GestureDetector(
            onTap: () {
              setState(() => _selected = index);
              widget.onFilterSelected(index);
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              child: Column(
                children: [
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isSelected ? const Color(0xFF6C63FF) : Colors.transparent, width: 2),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        color: Colors.grey.shade800,
                        child: filter.$2 != null
                          ? ColorFiltered(colorFilter: filter.$2!, child: const Icon(Icons.image, size: 28, color: Colors.white24))
                          : const Icon(Icons.image, size: 28, color: Colors.white24),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(filter.$1, style: TextStyle(
                    color: isSelected ? const Color(0xFF6C63FF) : Colors.white70,
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
}

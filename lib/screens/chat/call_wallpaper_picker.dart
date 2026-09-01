import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/kora_colors.dart';

/// Wallpaper model for Call Screen background customization.
class CallWallpaper {
  final String id;
  final String name;
  final List<Color>? gradientColors;
  final String? imagePath;
  final bool isCustom;

  const CallWallpaper({
    required this.id,
    required this.name,
    this.gradientColors,
    this.imagePath,
    this.isCustom = false,
  });

  Decoration get decoration {
    if (isCustom && imagePath != null && File(imagePath!).existsSync()) {
      return BoxDecoration(
        image: DecorationImage(
          image: FileImage(File(imagePath!)),
          fit: BoxFit.cover,
        ),
      );
    } else if (gradientColors != null && gradientColors!.isNotEmpty) {
      return BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors!,
        ),
      );
    }
    return const BoxDecoration(
      gradient: KoraColors.brandGradient,
    );
  }
}

/// Predefined list of gradient wallpapers for Kora calls.
class CallWallpaperPresets {
  static const CallWallpaper koraPurple = CallWallpaper(
    id: 'kora_purple',
    name: 'Kora Purple',
    gradientColors: [KoraColors.purple, KoraColors.blue],
  );

  static const CallWallpaper deepNavy = CallWallpaper(
    id: 'deep_navy',
    name: 'Deep Navy',
    gradientColors: [KoraColors.deepNavy, Color(0xFF181832)],
  );

  static const CallWallpaper sunset = CallWallpaper(
    id: 'sunset',
    name: 'Sunset Glow',
    gradientColors: [Color(0xFFFF512F), Color(0xFFDD2476)],
  );

  static const CallWallpaper ocean = CallWallpaper(
    id: 'ocean',
    name: 'Ocean Breeze',
    gradientColors: [Color(0xFF2193B0), Color(0xFF6DD5ED)],
  );

  static const CallWallpaper forest = CallWallpaper(
    id: 'forest',
    name: 'Forest Emerald',
    gradientColors: [Color(0xFF11998E), Color(0xFF38EF7D)],
  );

  static const CallWallpaper midnight = CallWallpaper(
    id: 'midnight',
    name: 'Midnight Mystery',
    gradientColors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
  );

  static const CallWallpaper darkNeon = CallWallpaper(
    id: 'dark_neon',
    name: 'Dark Neon',
    gradientColors: [Color(0xFF121212), Color(0xFF4A0072)],
  );

  static const CallWallpaper roseGold = CallWallpaper(
    id: 'rose_gold',
    name: 'Rose Crimson',
    gradientColors: [Color(0xFFB92B27), Color(0xFF1565C0)],
  );

  static const List<CallWallpaper> allPresets = [
    koraPurple,
    deepNavy,
    sunset,
    ocean,
    forest,
    midnight,
    darkNeon,
    roseGold,
  ];

  static CallWallpaper getById(String id, {String? customPath}) {
    if (id == 'custom' && customPath != null && customPath.isNotEmpty) {
      return CallWallpaper(
        id: 'custom',
        name: 'Custom Photo',
        imagePath: customPath,
        isCustom: true,
      );
    }
    return allPresets.firstWhere(
      (w) => w.id == id,
      orElse: () => koraPurple,
    );
  }
}

/// Call Wallpaper Picker screen/sheet — allows selecting gradient preset
/// or custom photo from gallery, persisting choice to SharedPreferences.
class CallWallpaperPicker extends StatefulWidget {
  const CallWallpaperPicker({super.key});

  @override
  State<CallWallpaperPicker> createState() => _CallWallpaperPickerState();
}

class _CallWallpaperPickerState extends State<CallWallpaperPicker> {
  static const String _kWallpaperPresetKey = 'call_wallpaper_preset_id';
  static const String _kWallpaperCustomKey = 'call_wallpaper_custom_path';

  String _selectedId = 'kora_purple';
  String? _customPath;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedWallpaper();
  }

  Future<void> _loadSavedWallpaper() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString(_kWallpaperPresetKey) ?? 'kora_purple';
    final customPath = prefs.getString(_kWallpaperCustomKey);

    if (mounted) {
      setState(() {
        _selectedId = savedId;
        _customPath = customPath;
        _loading = false;
      });
    }
  }

  Future<void> _saveWallpaper(CallWallpaper wallpaper) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kWallpaperPresetKey, wallpaper.id);
    if (wallpaper.isCustom && wallpaper.imagePath != null) {
      await prefs.setString(_kWallpaperCustomKey, wallpaper.imagePath!);
    }
    if (mounted) {
      Navigator.pop(context, wallpaper);
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      if (image != null) {
        setState(() {
          _customPath = image.path;
          _selectedId = 'custom';
        });

        final customWallpaper = CallWallpaper(
          id: 'custom',
          name: 'Custom Photo',
          imagePath: image.path,
          isCustom: true,
        );

        await _saveWallpaper(customWallpaper);
      }
    } catch (e) {
      debugPrint('Error picking wallpaper from gallery: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open gallery.'),
            backgroundColor: KoraColors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentWallpaper = CallWallpaperPresets.getById(
      _selectedId,
      customPath: _customPath,
    );

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: KoraColors.deepNavy,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: KoraColors.purple))
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 8),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      children: [
                        const Text(
                          'Call Wallpaper',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),

                  const Divider(color: Colors.white12, height: 1),

                  // Live Preview Banner
                  Container(
                    margin: const EdgeInsets.all(16),
                    height: 120,
                    width: double.infinity,
                    decoration: currentWallpaper.decoration.copyWith(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white24, width: 1),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.white24,
                              child: Icon(Icons.person, color: Colors.white, size: 28),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Preview: ${currentWallpaper.name}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                              ),
                            ),
                          ],
                        ),
                        Positioned(
                          right: 12,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.call, color: Colors.white, size: 12),
                                SizedBox(width: 4),
                                Text(
                                  'In Call',
                                  style: TextStyle(color: Colors.white, fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Custom Gallery Pick Button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: InkWell(
                      onTap: _pickFromGallery,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: KoraColors.darkCard,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _selectedId == 'custom'
                                ? KoraColors.purple
                                : Colors.white10,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: KoraColors.purple.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.photo_library_outlined,
                                  color: KoraColors.purple, size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Choose from Gallery',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Select custom image background',
                                  style: TextStyle(color: Colors.white54, fontSize: 11),
                                ),
                              ],
                            ),
                            const Spacer(),
                            if (_selectedId == 'custom')
                              const Icon(Icons.check_circle, color: KoraColors.purple, size: 20)
                            else
                              const Icon(Icons.chevron_right, color: Colors.white38),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Preset Gradients',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  // Grid of Presets
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.8,
                      ),
                      itemCount: CallWallpaperPresets.allPresets.length,
                      itemBuilder: (context, index) {
                        final wallpaper = CallWallpaperPresets.allPresets[index];
                        final isSelected = _selectedId == wallpaper.id;

                        return GestureDetector(
                          onTap: () {
                            setState(() => _selectedId = wallpaper.id);
                            _saveWallpaper(wallpaper);
                          },
                          child: Column(
                            children: [
                              Expanded(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  decoration: wallpaper.decoration.copyWith(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected ? KoraColors.purple : Colors.white24,
                                      width: isSelected ? 3 : 1,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: KoraColors.purple.withValues(alpha: 0.5),
                                              blurRadius: 8,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: isSelected
                                      ? const Center(
                                          child: Icon(
                                            Icons.check_circle_rounded,
                                            color: Colors.white,
                                            size: 24,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                wallpaper.name,
                                style: TextStyle(
                                  color: isSelected ? KoraColors.purple : Colors.white70,
                                  fontSize: 11,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

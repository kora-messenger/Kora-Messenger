import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/kora_colors.dart';

/// Filter, Background, and AR Effect definitions for Video Calls.
class CallFilterOption {
  final String id;
  final String name;
  final IconData icon;
  final ColorFilter? colorFilter;

  const CallFilterOption({
    required this.id,
    required this.name,
    required this.icon,
    this.colorFilter,
  });
}

class CallBackgroundOption {
  final String id;
  final String name;
  final IconData icon;
  final double blurSigma;
  final List<Color>? gradientColors;

  const CallBackgroundOption({
    required this.id,
    required this.name,
    required this.icon,
    this.blurSigma = 0.0,
    this.gradientColors,
  });
}

class CallEffectOption {
  final String id;
  final String name;
  final IconData icon;
  final String description;

  const CallEffectOption({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
  });
}

/// Helper class containing all preset filters, backgrounds, and face effects.
class CallEffectsData {
  static const String keyFilter = 'call_video_filter_id';
  static const String keyBackground = 'call_video_bg_id';
  static const String keyEffect = 'call_video_effect_id';

  // 10 WhatsApp-style Filters
  static final List<CallFilterOption> filters = [
    const CallFilterOption(
      id: 'none',
      name: 'Normal',
      icon: Icons.filter_none,
      colorFilter: null,
    ),
    CallFilterOption(
      id: 'warm',
      name: 'Warm',
      icon: Icons.wb_sunny,
      colorFilter: ColorFilter.mode(
        const Color(0xFFFFA726).withValues(alpha: 0.22),
        BlendMode.colorBurn,
      ),
    ),
    CallFilterOption(
      id: 'cool',
      name: 'Cool',
      icon: Icons.ac_unit,
      colorFilter: ColorFilter.mode(
        const Color(0xFF29B6F6).withValues(alpha: 0.22),
        BlendMode.colorBurn,
      ),
    ),
    const CallFilterOption(
      id: 'bw',
      name: 'B & W',
      icon: Icons.style,
      colorFilter: ColorFilter.matrix(<double>[
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0,      0,      0,      1, 0,
      ]),
    ),
    CallFilterOption(
      id: 'lightLeak',
      name: 'Light Leak',
      icon: Icons.wb_twilight,
      colorFilter: ColorFilter.mode(
        const Color(0xFFFF7043).withValues(alpha: 0.28),
        BlendMode.softLight,
      ),
    ),
    CallFilterOption(
      id: 'dreamy',
      name: 'Dreamy',
      icon: Icons.auto_awesome,
      colorFilter: ColorFilter.mode(
        const Color(0xFFEC4899).withValues(alpha: 0.2),
        BlendMode.softLight,
      ),
    ),
    CallFilterOption(
      id: 'prism',
      name: 'Prism Light',
      icon: Icons.looks,
      colorFilter: ColorFilter.mode(
        const Color(0xFF8B5CF6).withValues(alpha: 0.25),
        BlendMode.overlay,
      ),
    ),
    CallFilterOption(
      id: 'fisheye',
      name: 'Fisheye',
      icon: Icons.remove_red_eye_outlined,
      colorFilter: ColorFilter.mode(
        const Color(0xFF000000).withValues(alpha: 0.15),
        BlendMode.darken,
      ),
    ),
    const CallFilterOption(
      id: 'vintageTv',
      name: 'Vintage TV',
      icon: Icons.tv,
      colorFilter: ColorFilter.matrix(<double>[
        0.393, 0.769, 0.189, 0, 0,
        0.349, 0.686, 0.168, 0, 0,
        0.272, 0.534, 0.131, 0, 0,
        0,     0,     0,     1, 0,
      ]),
    ),
    CallFilterOption(
      id: 'frostedGlass',
      name: 'Frosted',
      icon: Icons.blur_on,
      colorFilter: ColorFilter.mode(
        Colors.white.withValues(alpha: 0.2),
        BlendMode.lighten,
      ),
    ),
    CallFilterOption(
      id: 'duoTone',
      name: 'Duo Tone',
      icon: Icons.invert_colors,
      colorFilter: ColorFilter.mode(
        KoraColors.purple.withValues(alpha: 0.35),
        BlendMode.color,
      ),
    ),
  ];

  // Background Options
  static final List<CallBackgroundOption> backgrounds = [
    const CallBackgroundOption(
      id: 'none',
      name: 'None',
      icon: Icons.block,
    ),
    const CallBackgroundOption(
      id: 'blur_low',
      name: 'Slight Blur',
      icon: Icons.blur_linear,
      blurSigma: 5.0,
    ),
    const CallBackgroundOption(
      id: 'blur_high',
      name: 'Strong Blur',
      icon: Icons.blur_circular,
      blurSigma: 15.0,
    ),
    const CallBackgroundOption(
      id: 'office',
      name: 'Modern Office',
      icon: Icons.business,
      gradientColors: [Color(0xFF1E293B), Color(0xFF334155)],
    ),
    const CallBackgroundOption(
      id: 'beach',
      name: 'Beach Sunset',
      icon: Icons.beach_access,
      gradientColors: [Color(0xFFF97316), Color(0xFF0284C7)],
    ),
    const CallBackgroundOption(
      id: 'studio',
      name: 'Studio Light',
      icon: Icons.highlight,
      gradientColors: [Color(0xFF312E81), Color(0xFF581C87)],
    ),
    const CallBackgroundOption(
      id: 'cyberpunk',
      name: 'Cyberpunk',
      icon: Icons.bolt,
      gradientColors: [Color(0xFFC026D3), Color(0xFF1E1B4B)],
    ),
    const CallBackgroundOption(
      id: 'cosmic',
      name: 'Cosmic Void',
      icon: Icons.auto_awesome,
      gradientColors: [Color(0xFF030712), Color(0xFF1E1B4B)],
    ),
    const CallBackgroundOption(
      id: 'ai_gen',
      name: 'AI Generator',
      icon: Icons.psychology,
      gradientColors: [KoraColors.purple, KoraColors.blue],
    ),
  ];

  // Effects Options
  static final List<CallEffectOption> effects = [
    const CallEffectOption(
      id: 'none',
      name: 'None',
      icon: Icons.block,
      description: 'No active face effect',
    ),
    const CallEffectOption(
      id: 'sparkles',
      name: 'Sparkles',
      icon: Icons.auto_awesome,
      description: 'Magical shimmering particles around head',
    ),
    const CallEffectOption(
      id: 'studioGlow',
      name: 'Studio Light',
      icon: Icons.wb_sunny_outlined,
      description: 'Soft halo studio ring light overlay',
    ),
    const CallEffectOption(
      id: 'softBeauty',
      name: 'Soft Glow',
      icon: Icons.face,
      description: 'Subtle skin smoothing & eye boost',
    ),
    const CallEffectOption(
      id: 'cyberVisor',
      name: 'Cyber HUD',
      icon: Icons.visibility,
      description: 'Futuristic visor glow effect',
    ),
    const CallEffectOption(
      id: 'neonFrame',
      name: 'Neon Frame',
      icon: Icons.crop_free,
      description: 'Pulsing purple-blue neon border',
    ),
    const CallEffectOption(
      id: 'goldenHour',
      name: 'Golden Hour',
      icon: Icons.wb_twilight,
      description: 'Warm sunset light leak flare',
    ),
  ];
}

/// Call Effects & Filters Sheet — 3-tab modal for video call customization.
class CallEffectsSheet extends StatefulWidget {
  const CallEffectsSheet({super.key});

  @override
  State<CallEffectsSheet> createState() => _CallEffectsSheetState();
}

class _CallEffectsSheetState extends State<CallEffectsSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String _selectedFilterId = 'none';
  String _selectedBgId = 'none';
  String _selectedEffectId = 'none';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSavedSelections();
  }

  Future<void> _loadSavedSelections() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _selectedFilterId = prefs.getString(CallEffectsData.keyFilter) ?? 'none';
        _selectedBgId = prefs.getString(CallEffectsData.keyBackground) ?? 'none';
        _selectedEffectId = prefs.getString(CallEffectsData.keyEffect) ?? 'none';
        _loading = false;
      });
    }
  }

  Future<void> _selectFilter(String filterId) async {
    setState(() => _selectedFilterId = filterId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(CallEffectsData.keyFilter, filterId);
  }

  Future<void> _selectBg(String bgId) async {
    if (bgId == 'ai_gen') {
      _showAiPromptDialog();
      return;
    }
    setState(() => _selectedBgId = bgId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(CallEffectsData.keyBackground, bgId);
  }

  Future<void> _selectEffect(String effectId) async {
    setState(() => _selectedEffectId = effectId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(CallEffectsData.keyEffect, effectId);
  }

  void _showAiPromptDialog() {
    final controller = TextEditingController(text: 'Futuristic glass greenhouse on Mars');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KoraColors.darkCard,
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: KoraColors.purple),
            SizedBox(width: 8),
            Text('AI Background', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Describe the background you want Kora AI to generate:',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: KoraColors.deepNavy,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: KoraColors.purple,
            ),
            child: const Text('Generate', style: TextStyle(color: Colors.white)),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _selectedBgId = 'ai_gen');
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(CallEffectsData.keyBackground, 'ai_gen');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Generated AI Background: ${controller.text}'),
                    backgroundColor: KoraColors.purple,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentFilter = CallEffectsData.filters.firstWhere(
      (f) => f.id == _selectedFilterId,
      orElse: () => CallEffectsData.filters.first,
    );

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: KoraColors.deepNavy,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: KoraColors.purple))
            : Column(
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

                  // Header with Close
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Row(
                      children: [
                        const Text(
                          'Call Effects & Filters',
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

                  // Mini Camera Preview Box
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    height: 100,
                    width: double.infinity,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: KoraColors.darkCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: KoraColors.purple.withValues(alpha: 0.5), width: 1.5),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Background preview
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: CallEffectsData.backgrounds
                                      .firstWhere((b) => b.id == _selectedBgId)
                                      .gradientColors != null
                                  ? LinearGradient(
                                      colors: CallEffectsData.backgrounds
                                          .firstWhere((b) => b.id == _selectedBgId)
                                          .gradientColors!,
                                    )
                                  : null,
                            ),
                          ),
                        ),

                        // Filter preview on face icon
                        ColorFiltered(
                          colorFilter: currentFilter.colorFilter ??
                              const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                          child: const Icon(Icons.face_retouching_natural,
                              size: 54, color: Colors.white70),
                        ),

                        // Active Effect Badge
                        if (_selectedEffectId != 'none')
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: KoraColors.purple,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.auto_awesome, color: Colors.white, size: 10),
                                  const SizedBox(width: 4),
                                  Text(
                                    _selectedEffectId,
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // TabBar
                  TabBar(
                    controller: _tabController,
                    indicatorColor: KoraColors.purple,
                    indicatorWeight: 3,
                    labelColor: KoraColors.purple,
                    unselectedLabelColor: Colors.white54,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    tabs: const [
                      Tab(text: 'Filters'),
                      Tab(text: 'Backgrounds'),
                      Tab(text: 'Effects'),
                    ],
                  ),

                  const Divider(color: Colors.white12, height: 1),

                  // TabBarView Content
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildFiltersTab(),
                        _buildBackgroundsTab(),
                        _buildEffectsTab(),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildFiltersTab() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: CallEffectsData.filters.length,
      itemBuilder: (context, index) {
        final f = CallEffectsData.filters[index];
        final isSelected = _selectedFilterId == f.id;

        return GestureDetector(
          onTap: () => _selectFilter(f.id),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? KoraColors.purple.withValues(alpha: 0.3)
                        : KoraColors.darkCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? KoraColors.purple : Colors.white12,
                      width: isSelected ? 2.5 : 1,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      f.icon,
                      color: isSelected ? KoraColors.purple : Colors.white70,
                      size: 26,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                f.name,
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
    );
  }

  Widget _buildBackgroundsTab() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.0,
      ),
      itemCount: CallEffectsData.backgrounds.length,
      itemBuilder: (context, index) {
        final bg = CallEffectsData.backgrounds[index];
        final isSelected = _selectedBgId == bg.id;

        return GestureDetector(
          onTap: () => _selectBg(bg.id),
          child: Container(
            decoration: BoxDecoration(
              gradient: bg.gradientColors != null ? LinearGradient(colors: bg.gradientColors!) : null,
              color: bg.gradientColors == null ? KoraColors.darkCard : null,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? KoraColors.purple : Colors.white12,
                width: isSelected ? 3 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  bg.icon,
                  color: isSelected ? Colors.white : Colors.white70,
                  size: 28,
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    bg.name,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEffectsTab() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: CallEffectsData.effects.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final eff = CallEffectsData.effects[index];
        final isSelected = _selectedEffectId == eff.id;

        return InkWell(
          onTap: () => _selectEffect(eff.id),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: isSelected
                  ? KoraColors.purple.withValues(alpha: 0.2)
                  : KoraColors.darkCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? KoraColors.purple : Colors.white12,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? KoraColors.purple
                        : Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    eff.icon,
                    color: isSelected ? Colors.white : KoraColors.purple,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        eff.name,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        eff.description,
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle, color: KoraColors.purple, size: 22),
              ],
            ),
          ),
        );
      },
    );
  }
}

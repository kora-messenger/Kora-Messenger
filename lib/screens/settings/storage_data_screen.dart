import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/kora_colors.dart';
import 'manage_storage_screen.dart';
import 'network_usage_screen.dart';

/// Storage and data settings — mirrors WhatsApp's Settings > Storage and data.
///
/// Sections:
/// 1. Storage — "Manage storage" (shows storage breakdown), media usage
/// 2. Network — Network usage, Media auto-download (when using Wi-Fi / cellular / roaming)
class StorageDataScreen extends StatefulWidget {
  const StorageDataScreen({super.key});

  @override
  State<StorageDataScreen> createState() => _StorageDataScreenState();
}

class _StorageDataScreenState extends State<StorageDataScreen> {
  // Media auto-download prefs
  String _photosWifi = 'On';
  String _photosCellular = 'Off';
  String _videosWifi = 'Off';
  String _videosCellular = 'Off';
  String _docsWifi = 'Off';
  String _docsCellular = 'Off';
  String _audioWifi = 'On';
  String _audioCellular = 'Off';

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _photosWifi = prefs.getString('auto_dl_photos_wifi') ?? 'On';
        _photosCellular = prefs.getString('auto_dl_photos_cellular') ?? 'Off';
        _videosWifi = prefs.getString('auto_dl_videos_wifi') ?? 'Off';
        _videosCellular = prefs.getString('auto_dl_videos_cellular') ?? 'Off';
        _docsWifi = prefs.getString('auto_dl_docs_wifi') ?? 'Off';
        _docsCellular = prefs.getString('auto_dl_docs_cellular') ?? 'Off';
        _audioWifi = prefs.getString('auto_dl_audio_wifi') ?? 'On';
        _audioCellular = prefs.getString('auto_dl_audio_cellular') ?? 'Off';
        _loading = false;
      });
    }
  }

  Future<void> _setPref(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
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
        backgroundColor: bg,
        elevation: 0,
        title: Text('Storage and data',
            style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: KoraColors.purple))
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  // ── STORAGE section ──
                  _sectionLabel('STORAGE', textMuted),
                  Container(
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(Icons.storage_outlined, color: KoraColors.purple, size: 24),
                          title: Text('Manage storage', style: TextStyle(color: textPrimary, fontSize: 16)),
                          subtitle: Text('Review and delete media to free up space',
                              style: TextStyle(color: textSecondary, fontSize: 13)),
                          trailing: Icon(Icons.chevron_right, color: textMuted),
                          onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const ManageStorageScreen())),
                        ),
                        Divider(height: 1, indent: 56, color: border),
                        ListTile(
                          leading: Icon(Icons.network_check_outlined, color: KoraColors.purple, size: 24),
                          title: Text('Network usage', style: TextStyle(color: textPrimary, fontSize: 16)),
                          subtitle: Text('See how much data Kora uses',
                              style: TextStyle(color: textSecondary, fontSize: 13)),
                          trailing: Icon(Icons.chevron_right, color: textMuted),
                          onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const NetworkUsageScreen())),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── MEDIA AUTO-DOWNLOAD section ──
                  _sectionLabel('MEDIA AUTO-DOWNLOAD', textMuted),
                  Text(
                    'Automatically download media to your phone when using:',
                    style: TextStyle(color: textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 12),

                  // Photos
                  _autoDownloadCard(
                    card, textPrimary, textSecondary, textMuted, border,
                    'Photos',
                    _photosWifi, _photosCellular,
                    (v) { setState(() => _photosWifi = v); _setPref('auto_dl_photos_wifi', v); },
                    (v) { setState(() => _photosCellular = v); _setPref('auto_dl_photos_cellular', v); },
                  ),
                  const SizedBox(height: 10),

                  // Videos
                  _autoDownloadCard(
                    card, textPrimary, textSecondary, textMuted, border,
                    'Videos',
                    _videosWifi, _videosCellular,
                    (v) { setState(() => _videosWifi = v); _setPref('auto_dl_videos_wifi', v); },
                    (v) { setState(() => _videosCellular = v); _setPref('auto_dl_videos_cellular', v); },
                  ),
                  const SizedBox(height: 10),

                  // Audio
                  _autoDownloadCard(
                    card, textPrimary, textSecondary, textMuted, border,
                    'Audio',
                    _audioWifi, _audioCellular,
                    (v) { setState(() => _audioWifi = v); _setPref('auto_dl_audio_wifi', v); },
                    (v) { setState(() => _audioCellular = v); _setPref('auto_dl_audio_cellular', v); },
                  ),
                  const SizedBox(height: 10),

                  // Documents
                  _autoDownloadCard(
                    card, textPrimary, textSecondary, textMuted, border,
                    'Documents',
                    _docsWifi, _docsCellular,
                    (v) { setState(() => _docsWifi = v); _setPref('auto_dl_docs_wifi', v); },
                    (v) { setState(() => _docsCellular = v); _setPref('auto_dl_docs_cellular', v); },
                  ),

                  const SizedBox(height: 20),

                  // ── Data usage tip ──
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: KoraColors.purple.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: KoraColors.purple.withValues(alpha: 0.15), width: 0.5),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lightbulb_outline, color: KoraColors.purple, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Auto-downloading media on cellular may use significant data. '
                            'Keep cellular off to save data.',
                            style: TextStyle(color: textSecondary, fontSize: 12.5, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _sectionLabel(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5),
      ),
    );
  }

  Widget _autoDownloadCard(
    Color card, Color textPrimary, Color textSecondary, Color textMuted, Color border,
    String label,
    String wifiValue, String cellularValue,
    ValueChanged<String> onWifiChanged,
    ValueChanged<String> onCellularChanged,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              label == 'Photos' ? Icons.photo_outlined :
              label == 'Videos' ? Icons.videocam_outlined :
              label == 'Audio' ? Icons.graphic_eq_outlined :
              Icons.description_outlined,
              color: KoraColors.purple,
              size: 24,
            ),
            title: Text(label, style: TextStyle(color: textPrimary, fontSize: 16)),
            subtitle: Text('Wi-Fi: $wifiValue  ·  Cellular: $cellularValue',
                style: TextStyle(color: textSecondary, fontSize: 13)),
          ),
          Divider(height: 1, indent: 16, color: border),
          // Wi-Fi toggle row
          _downloadToggleRow('When using Wi-Fi', wifiValue, onWifiChanged, textPrimary, textSecondary),
          Divider(height: 1, indent: 16, color: border),
          // Cellular toggle row
          _downloadToggleRow('When using cellular', cellularValue, onCellularChanged, textPrimary, textSecondary),
        ],
      ),
    );
  }

  Widget _downloadToggleRow(
    String label, String value, ValueChanged<String> onChanged, Color textPrimary, Color textSecondary,
  ) {
    return ListTile(
      title: Text(label, style: TextStyle(color: textPrimary, fontSize: 14)),
      trailing: SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'Off', label: Text('Off', style: TextStyle(fontSize: 12))),
          ButtonSegment(value: 'On', label: Text('On', style: TextStyle(fontSize: 12))),
        ],
        selected: {value},
        onSelectionChanged: (set) => onChanged(set.first),
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return KoraColors.purple;
            return null;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return Colors.white;
            return null;
          }),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}

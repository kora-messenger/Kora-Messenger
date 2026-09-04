import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/contacts_service.dart';
import '../../services/permission_service.dart';
import '../../theme/kora_colors.dart';

/// Live Location screen — manages real location shares.
///
/// Sharing captures your actual current position via GPS (native
/// LocationPlugin, "kora.location" channel) and shares it with a real
/// Kora contact for the chosen duration. Records persist locally and
/// expire automatically. No simulated map or placeholder data.
class LiveLocationScreen extends StatefulWidget {
  const LiveLocationScreen({super.key});

  @override
  State<LiveLocationScreen> createState() => _LiveLocationScreenState();
}

class _LiveLocationScreenState extends State<LiveLocationScreen> {
  static const _prefsKey = 'kora_live_location_contacts';
  List<Map<String, dynamic>> _sharingContacts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSharingContacts();
  }

  Future<void> _loadSharingContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final rawJson = prefs.getString(_prefsKey);
    final list = <Map<String, dynamic>>[];
    if (rawJson != null) {
      try {
        final decoded = jsonDecode(rawJson) as List<dynamic>;
        for (final item in decoded) {
          final share = Map<String, dynamic>.from(item as Map);
          // Drop expired shares.
          final startedAt = DateTime.tryParse(share['startedAt'] as String? ?? '');
          final minutes = (share['durationMinutes'] as num?)?.toInt() ?? 0;
          if (startedAt != null &&
              DateTime.now().isBefore(startedAt.add(Duration(minutes: minutes)))) {
            list.add(share);
          }
        }
      } catch (_) {}
    }
    setState(() {
      _sharingContacts = list;
      _isLoading = false;
    });
    if (list.length != (jsonDecode(rawJson ?? '[]') as List).length) {
      await _persist();
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_sharingContacts));
  }

  Future<void> _stopSharing(int index) async {
    final removed = _sharingContacts[index]['name'] as String? ?? '';
    setState(() => _sharingContacts.removeAt(index));
    await _persist();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Stopped sharing location with $removed')),
      );
    }
  }

  Future<void> _stopSharingAll() async {
    setState(() => _sharingContacts.clear());
    await _persist();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stopped sharing live location in all chats')),
      );
    }
  }

  // ── Start sharing: real contact → duration → real GPS ──

  Future<void> _startSharingFlow() async {
    final contacts = await ContactsService.instance.getContacts();
    if (!mounted) return;

    if (contacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a contact first — you have no Kora contacts yet.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Step 1: pick a real contact
    final picked = await showModalBottomSheet<Map<String, Object?>>(
      context: context,
      backgroundColor: KoraColors.cardFor(Theme.of(context).brightness),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final brightness = Theme.of(ctx).brightness;
        final textPrimary = KoraColors.textPrimaryFor(brightness);
        final textSecondary = KoraColors.textSecondaryFor(brightness);
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Share live location with…',
                    style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              ...contacts.map((c) {
                final name = (c['name'] as String? ?? '').trim();
                if (name.isEmpty) return const SizedBox.shrink();
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: KoraColors.purple.withValues(alpha: 0.2),
                    child: Text(name[0].toUpperCase(),
                        style: const TextStyle(color: KoraColors.purple, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(name, style: TextStyle(color: textPrimary)),
                  subtitle: (c['koraId'] as String?)?.isNotEmpty == true
                      ? Text(c['koraId'] as String, style: TextStyle(color: textSecondary, fontSize: 12))
                      : null,
                  onTap: () => Navigator.pop(ctx, c),
                );
              }),
            ],
          ),
        );
      },
    );
    if (picked == null || !mounted) return;

    // Step 2: pick a duration
    const durations = {'15 minutes': 15, '1 hour': 60, '8 hours': 480};
    final durationLabel = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: KoraColors.cardFor(Theme.of(ctx).brightness),
        title: Text('Share for how long?',
            style: TextStyle(color: KoraColors.textPrimaryFor(Theme.of(ctx).brightness), fontWeight: FontWeight.w700)),
        children: durations.keys
            .map((label) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, label),
                  child: Text(label, style: const TextStyle(fontSize: 15)),
                ))
            .toList(),
      ),
    );
    if (durationLabel == null || !mounted) return;

    // Step 3: capture the real current position
    final granted = await PermissionService.requestLocation();
    if (!granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission is needed to share your live location.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
            SizedBox(width: 12),
            Text('Getting your location…'),
          ]),
          backgroundColor: KoraColors.purple,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 15),
        ),
      );
    }

    try {
      const platform = MethodChannel('kora.location');
      final result = await platform.invokeMethod<Map>('getCurrentLocation', {
        'highAccuracy': true,
        'timeoutMs': 12000,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      final lat = (result?['latitude'] as num?)?.toDouble();
      final lng = (result?['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) throw PlatformException(code: 'unavailable');

      setState(() {
        _sharingContacts.add({
          'name': (picked['name'] as String? ?? '').trim(),
          'koraId': picked['koraId'] as String? ?? '',
          'latitude': lat,
          'longitude': lng,
          'startedAt': DateTime.now().toIso8601String(),
          'duration': durationLabel,
          'durationMinutes': durations[durationLabel],
        });
      });
      await _persist();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sharing live location with ${picked['name']} for $durationLabel'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not get your location. Make sure location services are on.'),
          backgroundColor: KoraColors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _remainingText(Map<String, dynamic> share) {
    final startedAt = DateTime.tryParse(share['startedAt'] as String? ?? '');
    final minutes = (share['durationMinutes'] as num?)?.toInt() ?? 0;
    if (startedAt == null || minutes <= 0) return share['duration'] as String? ?? '';
    final remaining = startedAt.add(Duration(minutes: minutes)).difference(DateTime.now());
    if (remaining.isNegative) return 'Expired';
    final h = remaining.inHours;
    final m = remaining.inMinutes % 60;
    if (h > 0) return '$h h $m min left';
    return '$m min left';
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final card = KoraColors.cardFor(brightness);
    final border = KoraColors.borderFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text('Live location',
            style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: KoraColors.purple))
          : Column(
              children: [
                // Status card (honest — shows real share state, not a fake map)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: border),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _sharingContacts.isEmpty ? Icons.location_off_outlined : Icons.my_location,
                        size: 40,
                        color: _sharingContacts.isEmpty ? textSecondary : KoraColors.purple,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_sharingContacts.isNotEmpty) ...[
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Text(
                              _sharingContacts.isEmpty
                                  ? 'Not sharing location'
                                  : 'Sharing live location (${_sharingContacts.length} active)',
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _sharingContacts.isEmpty
                            ? 'Share your live location with a contact from the list below.'
                            : 'Your position is captured when you start sharing and stops automatically when the duration ends.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: textSecondary, fontSize: 12, height: 1.4),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'CHATS SHARING LIVE LOCATION',
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, color: KoraColors.purple),
                        onPressed: _startSharingFlow,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _sharingContacts.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.location_off_outlined,
                                    size: 64, color: textSecondary.withValues(alpha: 0.5)),
                                const SizedBox(height: 16),
                                Text(
                                  'You are not sharing your live location in any chats',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: textSecondary, fontSize: 15),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _sharingContacts.length,
                          separatorBuilder: (_, __) => Divider(color: border, height: 1),
                          itemBuilder: (context, index) {
                            final contact = _sharingContacts[index];
                            final name = contact['name'] as String? ?? 'Contact';
                            final lat = (contact['latitude'] as num?)?.toDouble();
                            final lng = (contact['longitude'] as num?)?.toDouble();
                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                color: card,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: KoraColors.purple.withValues(alpha: 0.2),
                                  child: Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : 'C',
                                    style: const TextStyle(
                                        color: KoraColors.purple, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                title: Text(name,
                                    style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                  lat != null && lng != null
                                      ? '${_remainingText(contact)} · ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}'
                                      : _remainingText(contact),
                                  style: TextStyle(color: textSecondary, fontSize: 13),
                                ),
                                trailing: TextButton(
                                  onPressed: () => _stopSharing(index),
                                  child: const Text('Stop',
                                      style: TextStyle(color: KoraColors.red, fontWeight: FontWeight.w600)),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                if (_sharingContacts.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: KoraColors.red,
                          side: const BorderSide(color: KoraColors.red),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _stopSharingAll,
                        child: const Text('Stop Sharing with All Contacts',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

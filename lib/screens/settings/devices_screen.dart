import 'package:flutter/material.dart';
import 'link_device_screen.dart';
import 'pairing_qr_screen.dart';
import '../../config/kora_api.dart';
import '../../services/session_manager.dart';
import '../../services/device_manager.dart';
import '../../theme/kora_colors.dart';

/// Telegram-style Devices screen.
///
/// Shows every device currently logged in to the user's Kora account.
/// The current device is pinned at the top with no terminate option.
/// Other devices can be individually terminated, or all at once via
/// "Terminate all other sessions".
class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _KoraDevice {
  final String id;
  final String deviceId;
  final String deviceName;
  final String platform;
  final String? firstLoginDate;
  final String? lastLoginDate;
  final bool isTrusted;

  _KoraDevice({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    this.firstLoginDate,
    this.lastLoginDate,
    required this.isTrusted,
  });

  factory _KoraDevice.fromJson(Map<String, dynamic> json) {
    return _KoraDevice(
      id: json['id']?.toString() ?? '',
      deviceId: json['deviceId']?.toString() ?? '',
      deviceName: json['deviceName']?.toString() ?? 'Unknown Device',
      platform: json['platform']?.toString() ?? 'unknown',
      firstLoginDate: json['firstLoginDate']?.toString(),
      lastLoginDate: json['lastLoginDate']?.toString(),
      isTrusted: json['isTrusted'] == true,
    );
  }
}

class _DevicesScreenState extends State<DevicesScreen> {
  bool _loading = true;
  String? _error;
  List<_KoraDevice> _devices = [];
  String? _currentDeviceId;
  final Set<String> _terminating = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _currentDeviceId = await DeviceManager.getDeviceId();
      final email = SessionManager.instance.currentEmail;
      final result = await KoraApi.post({
        'action': 'listDevices',
        'email': email,
      });
      if (result['success'] == true) {
        final list = (result['devices'] as List? ?? [])
            .map((e) => _KoraDevice.fromJson(e as Map<String, dynamic>))
            .toList();
        setState(() {
          _devices = list;
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Could not load devices';
          _loading = false;
        });
      }
    } catch (_) {
      setState(() {
        _error = 'Could not load devices';
        _loading = false;
      });
    }
  }

  Future<void> _terminate(_KoraDevice device) async {
    final confirmed = await _confirmTerminate(device.deviceName);
    if (confirmed != true) return;

    setState(() => _terminating.add(device.id));
    try {
      final email = SessionManager.instance.currentEmail;
      final result = await KoraApi.post({
        'action': 'logoutDevice',
        'email': email,
        'deviceRecordId': device.id,
      });
      if (result['success'] == true) {
        setState(() {
          _devices.removeWhere((d) => d.id == device.id);
          _terminating.remove(device.id);
        });
      } else {
        setState(() => _terminating.remove(device.id));
        _showSnack('Could not terminate that session');
      }
    } catch (_) {
      setState(() => _terminating.remove(device.id));
      _showSnack('Could not terminate that session');
    }
  }

  Future<void> _terminateAllOthers() async {
    final others = _devices.where((d) => d.deviceId != _currentDeviceId).toList();
    if (others.isEmpty) return;

    final confirmed = await _confirmTerminate(
      'all other devices (${others.length})',
      isAll: true,
    );
    if (confirmed != true) return;

    final email = SessionManager.instance.currentEmail;
    setState(() => _terminating.addAll(others.map((d) => d.id)));
    for (final d in others) {
      try {
        await KoraApi.post({
          'action': 'logoutDevice',
          'email': email,
          'deviceRecordId': d.id,
        });
      } catch (_) {}
    }
    setState(() {
      _devices.removeWhere((d) => d.deviceId != _currentDeviceId);
      _terminating.clear();
    });
  }

  Future<bool?> _confirmTerminate(String label, {bool isAll = false}) {
    final brightness = Theme.of(context).brightness;
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final card = KoraColors.cardFor(brightness);

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isAll ? 'Terminate all other sessions?' : 'Terminate this session?',
          style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: Text(
          isAll
              ? 'This will log out Kora on $label. Those devices will need to verify again to log back in.'
              : 'This will log out Kora on $label. It will need to verify again to log back in.',
          style: TextStyle(color: textSecondary, fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Terminate', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: KoraColors.purple,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _relativeTime(String? iso) {
    if (iso == null || iso.isEmpty) return 'Unknown';
    try {
      final dt = DateTime.parse(iso);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
      if (diff.inHours < 24) return '${diff.inHours} h ago';
      if (diff.inDays < 7) return '${diff.inDays} d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return 'Unknown';
    }
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
    } catch (_) {
      return '';
    }
  }

  IconData _platformIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'android':
        return Icons.phone_android_rounded;
      case 'ios':
        return Icons.phone_iphone_rounded;
      default:
        return Icons.devices_other_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);
    final card = KoraColors.cardFor(brightness);
    final border = KoraColors.borderFor(brightness);

    final currentDevice = _devices.where((d) => d.deviceId == _currentDeviceId).toList();
    final otherDevices = _devices.where((d) => d.deviceId != _currentDeviceId).toList();

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          'Devices',
          style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: KoraColors.purple))
            : _error != null
                ? _buildError(textPrimary, textSecondary)
                : RefreshIndicator(
                    onRefresh: _load,
                    color: KoraColors.purple,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                      children: [
                        // Info banner
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: KoraColors.purple.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: KoraColors.purple.withValues(alpha: 0.2), width: 0.5),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline, color: KoraColors.purple, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Review the list of devices where you are logged in to your Kora account.',
                                  style: TextStyle(color: textSecondary, fontSize: 12.5, height: 1.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Link a device button
                        _buildLinkDeviceButton(card, border, textPrimary, textSecondary),
                        const SizedBox(height: 8),

                        // Show pairing code button
                        _buildPairingCodeButton(card, border, textPrimary, textSecondary),
                        const SizedBox(height: 24),

                        // This device section
                        if (currentDevice.isNotEmpty) ...[
                          _buildSectionHeader('THIS DEVICE', textMuted),
                          ...currentDevice.map((d) => _buildCurrentDeviceCard(d, card, border, textPrimary, textSecondary, textMuted)),
                          const SizedBox(height: 24),
                        ],

                        // Other devices section
                        if (otherDevices.isNotEmpty) ...[
                          _buildSectionHeader('ACTIVE SESSIONS', textMuted),
                          ...otherDevices.map((d) => _buildOtherDeviceCard(d, card, border, textPrimary, textSecondary, textMuted)),
                          const SizedBox(height: 16),

                          // Terminate all button
                          SizedBox(
                            width: double.infinity,
                            child: TextButton.icon(
                              onPressed: _terminateAllOthers,
                              icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                              label: const Text(
                                'Terminate all other sessions',
                                style: TextStyle(color: Colors.redAccent, fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ] else if (currentDevice.isNotEmpty) ...[
                          // Only one device — show a hint
                          const SizedBox(height: 32),
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                              child: Column(
                                children: [
                                  Icon(Icons.devices_other_rounded, color: textMuted, size: 40),
                                  const SizedBox(height: 12),
                                  Text(
                                    'This is the only device linked to your account',
                                    style: TextStyle(color: textMuted, fontSize: 13.5),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildError(Color textPrimary, Color textSecondary) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, color: textSecondary, size: 40),
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: textPrimary, fontSize: 14)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _load,
            style: ElevatedButton.styleFrom(
              backgroundColor: KoraColors.purple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(
        title,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildLinkDeviceButton(Color card, Color border, Color textPrimary, Color textSecondary) {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LinkDeviceScreen()),
        );
        if (result == true) _load();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: KoraColors.purple.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.qr_code_scanner_rounded, color: KoraColors.purple, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Link a device', style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                  Text('Scan QR code from another device', style: TextStyle(color: textSecondary, fontSize: 12.5)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: textSecondary, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildPairingCodeButton(Color card, Color border, Color textPrimary, Color textSecondary) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const PairingQrScreen()));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: KoraColors.purple.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.qr_code_2_rounded, color: KoraColors.purple, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Show pairing code', style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                  Text('Display QR code for another device to scan', style: TextStyle(color: textSecondary, fontSize: 12.5)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: textSecondary, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentDeviceCard(
    _KoraDevice device, Color card, Color border, Color textPrimary, Color textSecondary, Color textMuted) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: KoraColors.purple.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_platformIcon(device.platform), color: KoraColors.purple, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.deviceName,
                  style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Text('Online', style: TextStyle(color: Colors.green.shade300, fontSize: 11, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (device.isTrusted)
                      Text('Trusted device', style: TextStyle(color: textMuted, fontSize: 11.5)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtherDeviceCard(
    _KoraDevice device, Color card, Color border, Color textPrimary, Color textSecondary, Color textMuted) {
    final isTerminating = _terminating.contains(device.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: KoraColors.purple.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_platformIcon(device.platform), color: textSecondary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.deviceName,
                  style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Last active ${_relativeTime(device.lastLoginDate)}',
                  style: TextStyle(color: textMuted, fontSize: 12.5),
                ),
                if (device.firstLoginDate != null && device.firstLoginDate!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Linked ${_formatDate(device.firstLoginDate)}',
                      style: TextStyle(color: textMuted.withValues(alpha: 0.7), fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          isTerminating
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: KoraColors.purple))
              : GestureDetector(
                  onTap: () => _terminate(device),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 20),
                  ),
                ),
        ],
      ),
    );
  }
}

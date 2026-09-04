import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../theme/kora_colors.dart';
import '../../models/business_models.dart';

class BusinessHoursScreen extends StatefulWidget {
  const BusinessHoursScreen({super.key});
  @override
  State<BusinessHoursScreen> createState() => _BusinessHoursScreenState();
}

class _BusinessHoursScreenState extends State<BusinessHoursScreen> {
  BusinessHoursSettings _settings = BusinessHoursSettings(
    mode: 'selected',
    days: List.generate(7, (i) => DaySchedule(isOpen: i < 5, openTime: '09:00', closeTime: '17:00')),
  );
  final _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('kora_business_hours');
    if (raw != null) { _settings = BusinessHoursSettings.fromJson(jsonDecode(raw)); setState(() {}); }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('kora_business_hours', jsonEncode(_settings.toJson()));
  }

  bool get _isOpenNow {
    if (_settings.mode == 'always_open') return true;
    if (_settings.mode == 'appointment') return false;
    final now = DateTime.now();
    int dayIdx = (now.weekday - 1) % 7;
    final day = _settings.days[dayIdx];
    if (!day.isOpen || day.openTime == null || day.closeTime == null) return false;
    // Compare the actual clock time against open/close, not just the toggle.
    int _mins(String s) {
      final parts = s.split(':');
      return (int.tryParse(parts.first) ?? 0) * 60 + (int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0);
    }
    final nowMins = now.hour * 60 + now.minute;
    return nowMins >= _mins(day.openTime!) && nowMins < _mins(day.closeTime!);
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Scaffold(
      backgroundColor: KoraColors.backgroundFor(b),
      appBar: AppBar(backgroundColor: KoraColors.backgroundFor(b),
        title: Text('Business hours', style: TextStyle(color: KoraColors.textPrimaryFor(b))),
        iconTheme: IconThemeData(color: KoraColors.textPrimaryFor(b))),
      body: ListView(children: [
        Container(margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: KoraColors.cardFor(b), borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _isOpenNow ? Colors.green : Colors.orange, width: 2)),
          child: Row(children: [
            Icon(_isOpenNow ? Icons.check_circle : Icons.access_time, color: _isOpenNow ? Colors.green : Colors.orange),
            const SizedBox(width: 12),
            Text(_settings.mode == 'always_open'
                ? 'Open 24 hours'
                : _isOpenNow ? 'Open now' : 'Closed',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
              color: _isOpenNow ? Colors.green : Colors.orange)),
          ])),
        _modeRadio('Selected hours', 'selected', b),
        _modeRadio('Always open', 'always_open', b),
        _modeRadio('Appointment only', 'appointment', b),
        if (_settings.mode == 'selected') ...[
          const SizedBox(height: 8),
          Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('Weekly schedule', style: TextStyle(fontSize: 13, color: KoraColors.textMutedFor(b), fontWeight: FontWeight.w600))),
          ..._dayNames.asMap().entries.map((e) {
            final day = _settings.days[e.key];
            return SwitchListTile(
              value: day.isOpen,
              onChanged: (v) { setState(() { _settings.days[e.key] = day.copyWith(isOpen: v); }); _save(); },
              title: Text(e.value, style: TextStyle(color: KoraColors.textPrimaryFor(b))),
              subtitle: Text(day.isOpen ? '${day.openTime} - ${day.closeTime}' : 'Closed',
                style: TextStyle(color: KoraColors.textMutedFor(b))),
              activeThumbColor: KoraColors.purple);
          }),
        ],
      ]),
    );
  }

  Widget _modeRadio(String label, String value, Brightness b) {
    return RadioListTile<String>(value: value, groupValue: _settings.mode,
      title: Text(label, style: TextStyle(color: KoraColors.textPrimaryFor(b))),
      onChanged: (v) { setState(() => _settings = _settings.copyWith(mode: v)); _save(); }, activeColor: KoraColors.purple);
  }
}

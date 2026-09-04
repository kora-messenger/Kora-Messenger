import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:battery_plus/battery_plus.dart';

import '../models/status_model.dart';
import 'status_service.dart';

/// Enum representing trigger types for automated status updates.
enum StatusTriggerType { TIME, LOCATION, BATTERY, MANUAL }

/// Represents an automated status update trigger rule.
class StatusTrigger {
  final String id;
  final StatusTriggerType type;
  final String label;
  final String emoji;
  final String statusText;
  final Map<String, dynamic> conditionData;
  final bool isEnabled;
  final int priority;

  StatusTrigger({
    required this.id,
    required this.type,
    required this.label,
    required this.emoji,
    required this.statusText,
    Map<String, dynamic>? conditionData,
    this.isEnabled = true,
    this.priority = 1,
  }) : conditionData = conditionData ?? {};

  StatusTrigger copyWith({
    String? id,
    StatusTriggerType? type,
    String? label,
    String? emoji,
    String? statusText,
    Map<String, dynamic>? conditionData,
    bool? isEnabled,
    int? priority,
  }) {
    return StatusTrigger(
      id: id ?? this.id,
      type: type ?? this.type,
      label: label ?? this.label,
      emoji: emoji ?? this.emoji,
      statusText: statusText ?? this.statusText,
      conditionData: conditionData ?? Map<String, dynamic>.from(this.conditionData),
      isEnabled: isEnabled ?? this.isEnabled,
      priority: priority ?? this.priority,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'label': label,
      'emoji': emoji,
      'statusText': statusText,
      'conditionData': conditionData,
      'isEnabled': isEnabled,
      'priority': priority,
    };
  }

  factory StatusTrigger.fromJson(Map<String, dynamic> json) {
    final typeName = json['type'] as String? ?? 'TIME';
    final type = StatusTriggerType.values.firstWhere(
      (t) => t.name.toUpperCase() == typeName.toUpperCase(),
      orElse: () => StatusTriggerType.TIME,
    );

    return StatusTrigger(
      id: json['id'] as String,
      type: type,
      label: json['label'] as String? ?? '',
      emoji: json['emoji'] as String? ?? '💬',
      statusText: json['statusText'] as String? ?? '',
      conditionData: json['conditionData'] != null
          ? Map<String, dynamic>.from(json['conditionData'] as Map)
          : {},
      isEnabled: json['isEnabled'] as bool? ?? true,
      priority: json['priority'] as int? ?? 1,
    );
  }

  /// Summary description of the condition for UI display.
  String get conditionSummary {
    switch (type) {
      case StatusTriggerType.TIME:
        final rawDays = (conditionData['days'] as List?)?.map((e) => (e as num).toInt()).toList() ?? [1, 2, 3, 4, 5, 6, 7];
        final startH = (conditionData['startHour'] as num? ?? 9).toInt().toString().padLeft(2, '0');
        final startM = (conditionData['startMinute'] as num? ?? 0).toInt().toString().padLeft(2, '0');
        final endH = (conditionData['endHour'] as num? ?? 17).toInt().toString().padLeft(2, '0');
        final endM = (conditionData['endMinute'] as num? ?? 0).toInt().toString().padLeft(2, '0');

        final sortedDays = List<int>.from(rawDays)..sort();
        String daysText;
        if (sortedDays.length == 7) {
          daysText = 'Daily';
        } else if (listEquals(sortedDays, [1, 2, 3, 4, 5])) {
          daysText = 'Mon-Fri';
        } else if (listEquals(sortedDays, [6, 7])) {
          daysText = 'Weekends';
        } else {
          const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
          daysText = sortedDays.map((d) => (d >= 1 && d <= 7) ? dayNames[d - 1] : '').where((s) => s.isNotEmpty).join(', ');
        }
        return '$daysText, $startH:$startM - $endH:$endM';

      case StatusTriggerType.LOCATION:
        final name = conditionData['locationName'] as String? ?? 'Saved Location';
        final radius = (conditionData['radiusMeters'] as num? ?? 100).toInt();
        final isMoving = conditionData['isMoving'] as bool? ?? false;
        return isMoving ? 'When moving / traveling' : '$name (${radius}m radius)';

      case StatusTriggerType.BATTERY:
        final threshold = (conditionData['threshold'] as num? ?? 15).toInt();
        return 'Battery below $threshold%';

      case StatusTriggerType.MANUAL:
        return 'One-tap trigger';
    }
  }
}

/// Service that manages automated status update triggers.
class StatusTriggerService extends ChangeNotifier {
  StatusTriggerService._();
  static final StatusTriggerService instance = StatusTriggerService._();

  static const String _kStorageKey = 'kora_status_triggers';
  Timer? _timer;
  List<StatusTrigger> _triggers = [];
  StatusTrigger? _activeTrigger;
  bool _initialized = false;

  /// Unmodifiable list of triggers.
  List<StatusTrigger> get triggers => List.unmodifiable(_triggers);

  /// Currently active winning trigger.
  StatusTrigger? get activeTrigger => _activeTrigger;

  /// Returns all stored triggers.
  List<StatusTrigger> getTriggers() => List.unmodifiable(_triggers);

  /// Returns the current active winning trigger.
  StatusTrigger? getActiveTrigger() => _activeTrigger;

  /// Initialize service, load persisted triggers, start periodic timer.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    await _loadTriggers();
    unawaited(_checkTriggersInternal());

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) {
      unawaited(checkTriggers());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Add a new trigger.
  Future<void> addTrigger(StatusTrigger trigger) async {
    _triggers.removeWhere((t) => t.id == trigger.id);
    _triggers.add(trigger);
    await _persistTriggers();
    unawaited(checkTriggers());
  }

  /// Remove a trigger by ID.
  Future<void> removeTrigger(String id) async {
    _triggers.removeWhere((t) => t.id == id);
    if (_activeTrigger?.id == id) {
      _activeTrigger = null;
    }
    await _persistTriggers();
    unawaited(checkTriggers());
  }

  /// Toggle trigger enabled state.
  Future<void> toggleTrigger(String id, [bool? enabled]) async {
    final idx = _triggers.indexWhere((t) => t.id == id);
    if (idx >= 0) {
      final current = _triggers[idx];
      final newStatus = enabled ?? !current.isEnabled;
      _triggers[idx] = current.copyWith(isEnabled: newStatus);
      await _persistTriggers();
      unawaited(checkTriggers());
    }
  }

  /// Check conditions for all enabled triggers and return highest priority active trigger.
  Future<StatusTrigger?> checkTriggers() async {
    final winning = await _checkTriggersInternal();
    notifyListeners();
    return winning;
  }

  Future<StatusTrigger?> _checkTriggersInternal() async {
    final now = DateTime.now();
    final enabledTriggers = _triggers.where((t) => t.isEnabled).toList();
    final activeCandidates = <StatusTrigger>[];

    for (final trigger in enabledTriggers) {
      if (await _evaluateCondition(trigger, now)) {
        activeCandidates.add(trigger);
      }
    }

    StatusTrigger? winner;
    if (activeCandidates.isNotEmpty) {
      // Highest priority wins
      activeCandidates.sort((a, b) => b.priority.compareTo(a.priority));
      winner = activeCandidates.first;
    }

    final prevActiveId = _activeTrigger?.id;
    _activeTrigger = winner;

    // If active trigger changed or fired new state, update StatusService
    if (winner != null && winner.id != prevActiveId) {
      _fireTriggerStatus(winner);
    }

    return winner;
  }

  Future<bool> _evaluateCondition(StatusTrigger trigger, DateTime now) async {
    switch (trigger.type) {
      case StatusTriggerType.TIME:
        final days = (trigger.conditionData['days'] as List?)?.map((e) => (e as num).toInt()).toList() ?? [1, 2, 3, 4, 5, 6, 7];
        final weekday = now.weekday; // 1 = Mon, 7 = Sun
        if (!days.contains(weekday)) {
          return false;
        }

        final startH = (trigger.conditionData['startHour'] as num? ?? 9).toInt();
        final startM = (trigger.conditionData['startMinute'] as num? ?? 0).toInt();
        final endH = (trigger.conditionData['endHour'] as num? ?? 17).toInt();
        final endM = (trigger.conditionData['endMinute'] as num? ?? 0).toInt();

        final currentMins = now.hour * 60 + now.minute;
        final startMins = startH * 60 + startM;
        final endMins = endH * 60 + endM;

        if (startMins <= endMins) {
          return currentMins >= startMins && currentMins < endMins;
        } else {
          // Overnight range, e.g. 23:00 to 07:00
          return currentMins >= startMins || currentMins < endMins;
        }

      case StatusTriggerType.LOCATION:
        final isActive = trigger.conditionData['isActive'] as bool? ?? true;
        return isActive;

      case StatusTriggerType.BATTERY:
        final threshold = (trigger.conditionData['threshold'] as num? ?? 15).toInt();
        final isActive = trigger.conditionData['isActive'] as bool? ?? true;
        if (!isActive) return false;
        // Real device battery level — never simulated.
        try {
          final level = await Battery().batteryLevel;
          return level <= threshold;
        } catch (_) {
          return false;
        }

      case StatusTriggerType.MANUAL:
        final isActive = trigger.conditionData['isActive'] as bool? ?? true;
        return isActive;
    }
  }

  Future<void> _fireTriggerStatus(StatusTrigger trigger) async {
    try {
      final statusText = '${trigger.emoji} ${trigger.statusText}';
      final item = StatusItem(
        id: 'trigger_${trigger.id}_${DateTime.now().millisecondsSinceEpoch}',
        type: StatusType.text,
        text: statusText,
        createdAt: DateTime.now(),
      );
      await StatusService.instance.addStatusItem(item);
    } catch (_) {}
  }

  Future<void> _persistTriggers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _triggers.map((t) => t.toJson()).toList();
      await prefs.setString(_kStorageKey, jsonEncode(jsonList));
    } catch (_) {}
  }

  Future<void> _loadTriggers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_kStorageKey);
      if (str != null && str.isNotEmpty) {
        final list = jsonDecode(str) as List;
        _triggers = list.map((j) => StatusTrigger.fromJson(j as Map<String, dynamic>)).toList();
      } else {
        _seedDefaultTriggers();
        await _persistTriggers();
      }
    } catch (_) {
      _seedDefaultTriggers();
    }
  }

  void _seedDefaultTriggers() {
    _triggers = [
      StatusTrigger(
        id: 'trig_work',
        type: StatusTriggerType.TIME,
        label: 'Busy at work',
        emoji: '💼',
        statusText: 'Busy at work — Available for calls after 5 PM',
        priority: 5,
        isEnabled: true,
        conditionData: {
          'days': [1, 2, 3, 4, 5],
          'startHour': 9,
          'startMinute': 0,
          'endHour': 17,
          'endMinute': 0,
        },
      ),
      StatusTrigger(
        id: 'trig_sleep',
        type: StatusTriggerType.TIME,
        label: 'Sleeping',
        emoji: '😴',
        statusText: 'Sleeping — Messages will be read in the morning',
        priority: 3,
        isEnabled: true,
        conditionData: {
          'days': [1, 2, 3, 4, 5, 6, 7],
          'startHour': 23,
          'startMinute': 0,
          'endHour': 7,
          'endMinute': 0,
        },
      ),
      StatusTrigger(
        id: 'trig_gym',
        type: StatusTriggerType.LOCATION,
        label: 'At the gym',
        emoji: '🏋️',
        statusText: 'At the gym working out',
        priority: 4,
        isEnabled: false,
        conditionData: {
          'locationName': 'Gym',
          'radiusMeters': 100,
          'isActive': true,
        },
      ),
      StatusTrigger(
        id: 'trig_battery',
        type: StatusTriggerType.BATTERY,
        label: 'Low battery',
        emoji: '🔋',
        statusText: 'Low battery (< 15%) — Phone about to die',
        priority: 10,
        isEnabled: false,
        conditionData: {
          'threshold': 15,
          'isActive': true,
        },
      ),
      StatusTrigger(
        id: 'trig_meeting',
        type: StatusTriggerType.TIME,
        label: 'In a meeting',
        emoji: '📅',
        statusText: 'In a meeting — Urgencies only',
        priority: 7,
        isEnabled: false,
        conditionData: {
          'days': [1, 2, 3, 4, 5],
          'startHour': 14,
          'startMinute': 0,
          'endHour': 15,
          'endMinute': 0,
        },
      ),
      StatusTrigger(
        id: 'trig_dnd',
        type: StatusTriggerType.MANUAL,
        label: 'Do not disturb',
        emoji: '⛔',
        statusText: 'Do not disturb mode active',
        priority: 9,
        isEnabled: false,
        conditionData: {
          'isActive': true,
        },
      ),
    ];
  }
}

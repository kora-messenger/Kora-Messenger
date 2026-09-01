import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import '../../services/status_trigger_service.dart';

/// Screen to view, enable/disable, create, and manage automated status update triggers.
class StatusTriggersScreen extends StatefulWidget {
  const StatusTriggersScreen({super.key});

  @override
  State<StatusTriggersScreen> createState() => _StatusTriggersScreenState();
}

class _StatusTriggersScreenState extends State<StatusTriggersScreen> {

  @override
  void initState() {
    super.initState();
    StatusTriggerService.instance.init();
    StatusTriggerService.instance.addListener(_onServiceUpdate);
  }

  @override
  void dispose() {
    StatusTriggerService.instance.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  void _openAddTriggerFlow() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: KoraColors.surfaceFor(Theme.of(context).brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const _AddTriggerSheet(),
    );
  }

  void _confirmDeleteTrigger(StatusTrigger trigger) {
    final brightness = Theme.of(context).brightness;
    final surface = KoraColors.surfaceFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Trigger?', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to delete "${trigger.label}" (${trigger.emoji})?',
          style: TextStyle(color: textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            child: Text('Cancel', style: TextStyle(color: textSecondary)),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: KoraColors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.pop(ctx);
              StatusTriggerService.instance.removeTrigger(trigger.id);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);

    final triggers = StatusTriggerService.instance.triggers;
    final activeTrigger = StatusTriggerService.instance.activeTrigger;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Status Triggers',
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.w800, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: KoraColors.purple, size: 26),
            tooltip: 'Add Trigger',
            onPressed: _openAddTriggerFlow,
          ),
        ],
      ),
      body: triggers.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bolt, size: 64, color: textSecondary.withValues(alpha: 0.4)),
                  const SizedBox(height: 16),
                  Text('No triggers created yet', style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text('Tap + to create automated status triggers', style: TextStyle(color: textSecondary, fontSize: 14)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _openAddTriggerFlow,
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text('Add Trigger', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      backgroundColor: KoraColors.purple,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                // Info banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: KoraColors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: KoraColors.purple.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: KoraColors.purple.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.bolt, color: KoraColors.purple, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Triggers automatically set your status based on schedule, location, battery, or manual toggle. Highest priority trigger wins.',
                          style: TextStyle(color: textSecondary, fontSize: 12.5, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (activeTrigger != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'ACTIVE NOW',
                      style: TextStyle(color: KoraColors.purple, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                  ),
                ],

                ...triggers.map((trigger) {
                  final isActive = activeTrigger?.id == trigger.id;
                  return _TriggerCard(
                    trigger: trigger,
                    isActive: isActive,
                    onToggle: (val) {
                      StatusTriggerService.instance.toggleTrigger(trigger.id, val);
                    },
                    onLongPress: () => _confirmDeleteTrigger(trigger),
                  );
                }),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddTriggerFlow,
        backgroundColor: Colors.transparent,
        elevation: 0,
        label: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            gradient: KoraColors.brandGradient,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: KoraColors.purple.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Row(
            children: [
              Icon(Icons.add, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Add Trigger', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card component for a single trigger item.
class _TriggerCard extends StatelessWidget {
  final StatusTrigger trigger;
  final bool isActive;
  final ValueChanged<bool> onToggle;
  final VoidCallback onLongPress;

  const _TriggerCard({
    required this.trigger,
    required this.isActive,
    required this.onToggle,
    required this.onLongPress,
  });

  IconData _iconForType(StatusTriggerType type) {
    switch (type) {
      case StatusTriggerType.TIME:
        return Icons.access_time_filled_rounded;
      case StatusTriggerType.LOCATION:
        return Icons.location_on_rounded;
      case StatusTriggerType.BATTERY:
        return Icons.battery_charging_full_rounded;
      case StatusTriggerType.MANUAL:
        return Icons.touch_app_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final cardBg = KoraColors.cardFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);

    final cardContent = Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: isActive
            ? null
            : Border.all(
                color: trigger.isEnabled
                    ? KoraColors.purple.withValues(alpha: 0.25)
                    : KoraColors.borderFor(brightness),
                width: 1,
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Emoji Circle
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isActive
                      ? KoraColors.purple.withValues(alpha: 0.2)
                      : (trigger.isEnabled
                          ? KoraColors.purple.withValues(alpha: 0.12)
                          : KoraColors.inputFillFor(brightness)),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    trigger.emoji,
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Title & Condition Summary
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            trigger.label,
                            style: TextStyle(
                              color: textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isActive) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: KoraColors.brandGradient,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'ACTIVE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          _iconForType(trigger.type),
                          size: 13,
                          color: trigger.isEnabled ? KoraColors.purple : textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            trigger.conditionSummary,
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Toggle Switch
              Switch(
                value: trigger.isEnabled,
                activeColor: KoraColors.purple,
                onChanged: onToggle,
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Status Text Quote
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: KoraColors.inputFillFor(brightness),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.format_quote_rounded, size: 16, color: KoraColors.purple.withValues(alpha: 0.7)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '"${trigger.statusText}"',
                    style: TextStyle(
                      color: textPrimary.withValues(alpha: 0.9),
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: KoraColors.purple.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'P${trigger.priority}',
                    style: const TextStyle(
                      color: KoraColors.purple,
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return InkWell(
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(16),
      child: isActive
          ? Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                gradient: KoraColors.brandGradient,
                borderRadius: BorderRadius.circular(18),
              ),
              child: cardContent,
            )
          : cardContent,
    );
  }
}

/// Modal sheet for creating a new trigger.
class _AddTriggerSheet extends StatefulWidget {
  const _AddTriggerSheet();

  @override
  State<_AddTriggerSheet> createState() => _AddTriggerSheetState();
}

class _AddTriggerSheetState extends State<_AddTriggerSheet> {
  StatusTriggerType _selectedType = StatusTriggerType.TIME;

  final _labelController = TextEditingController(text: 'Work Mode');
  final _statusController = TextEditingController(text: 'Busy at work');
  String _selectedEmoji = '💼';
  int _priority = 5;

  // Time trigger state
  List<int> _selectedDays = [1, 2, 3, 4, 5]; // Mon - Fri
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);

  // Location trigger state
  String _locationName = 'Gym';
  double _radiusMeters = 100;

  // Battery trigger state
  double _batteryThreshold = 15;

  final List<String> _emojiPresets = [
    '💼', '😴', '🏋️', '🔋', '📅', '⛔', '✈️', '🚗', '🎧', '💻', '🏖️', '🍔', '🤫', '🎬'
  ];

  @override
  void dispose() {
    _labelController.dispose();
    _statusController.dispose();
    super.dispose();
  }

  void _onTypeSelected(StatusTriggerType type) {
    setState(() {
      _selectedType = type;
      switch (type) {
        case StatusTriggerType.TIME:
          _labelController.text = 'Work Schedule';
          _statusController.text = 'Busy at work';
          _selectedEmoji = '💼';
          break;
        case StatusTriggerType.LOCATION:
          _labelController.text = 'At the gym';
          _statusController.text = 'Working out at the gym';
          _selectedEmoji = '🏋️';
          break;
        case StatusTriggerType.BATTERY:
          _labelController.text = 'Low Battery';
          _statusController.text = 'Low battery — May reply slowly';
          _selectedEmoji = '🔋';
          break;
        case StatusTriggerType.MANUAL:
          _labelController.text = 'Do Not Disturb';
          _statusController.text = 'Do Not Disturb active';
          _selectedEmoji = '⛔';
          break;
      }
    });
  }

  void _saveTrigger() {
    final label = _labelController.text.trim();
    final statusText = _statusController.text.trim();

    if (label.isEmpty || statusText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide label and status text')),
      );
      return;
    }

    final Map<String, dynamic> condData = {};

    switch (_selectedType) {
      case StatusTriggerType.TIME:
        condData['days'] = _selectedDays;
        condData['startHour'] = _startTime.hour;
        condData['startMinute'] = _startTime.minute;
        condData['endHour'] = _endTime.hour;
        condData['endMinute'] = _endTime.minute;
        break;
      case StatusTriggerType.LOCATION:
        condData['locationName'] = _locationName;
        condData['radiusMeters'] = _radiusMeters.toInt();
        condData['isActive'] = true;
        break;
      case StatusTriggerType.BATTERY:
        condData['threshold'] = _batteryThreshold.toInt();
        condData['simulatedBattery'] = 12;
        condData['isActive'] = true;
        break;
      case StatusTriggerType.MANUAL:
        condData['isActive'] = true;
        break;
    }

    final trigger = StatusTrigger(
      id: 'trig_${DateTime.now().millisecondsSinceEpoch}',
      type: _selectedType,
      label: label,
      emoji: _selectedEmoji,
      statusText: statusText,
      conditionData: condData,
      isEnabled: true,
      priority: _priority,
    );

    StatusTriggerService.instance.addTrigger(trigger);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.surfaceFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: ListView(
            controller: scrollController,
            children: [
              // Sheet Drag Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Row(
                children: [
                  Text(
                    'Create Status Trigger',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Type Selector Cards
              Text('SELECT TRIGGER TYPE',
                  style: TextStyle(color: textSecondary, fontSize: 11.5, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _TypeCard(
                      label: 'Time',
                      icon: Icons.access_time_filled_rounded,
                      isSelected: _selectedType == StatusTriggerType.TIME,
                      onTap: () => _onTypeSelected(StatusTriggerType.TIME),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _TypeCard(
                      label: 'Location',
                      icon: Icons.location_on_rounded,
                      isSelected: _selectedType == StatusTriggerType.LOCATION,
                      onTap: () => _onTypeSelected(StatusTriggerType.LOCATION),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _TypeCard(
                      label: 'Battery',
                      icon: Icons.battery_charging_full_rounded,
                      isSelected: _selectedType == StatusTriggerType.BATTERY,
                      onTap: () => _onTypeSelected(StatusTriggerType.BATTERY),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _TypeCard(
                      label: 'Manual',
                      icon: Icons.touch_app_rounded,
                      isSelected: _selectedType == StatusTriggerType.MANUAL,
                      onTap: () => _onTypeSelected(StatusTriggerType.MANUAL),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Label Input
              Text('TRIGGER LABEL',
                  style: TextStyle(color: textSecondary, fontSize: 11.5, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
              const SizedBox(height: 6),
              TextField(
                controller: _labelController,
                style: TextStyle(color: textPrimary),
                decoration: InputDecoration(
                  hintText: 'e.g. Work Mode',
                  hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.6)),
                  filled: true,
                  fillColor: KoraColors.inputFillFor(brightness),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),

              // Status Text & Emoji
              Text('STATUS UPDATE CONTENT',
                  style: TextStyle(color: textSecondary, fontSize: 11.5, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: KoraColors.inputFillFor(brightness),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(_selectedEmoji, style: const TextStyle(fontSize: 24)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _statusController,
                      style: TextStyle(color: textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Status text to display',
                        hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.6)),
                        filled: true,
                        fillColor: KoraColors.inputFillFor(brightness),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Emoji scroll presets
              SizedBox(
                height: 38,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _emojiPresets.length,
                  itemBuilder: (ctx, i) {
                    final emoji = _emojiPresets[i];
                    final isSel = emoji == _selectedEmoji;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedEmoji = emoji),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSel ? KoraColors.purple.withValues(alpha: 0.25) : KoraColors.inputFillFor(brightness),
                          borderRadius: BorderRadius.circular(20),
                          border: isSel ? Border.all(color: KoraColors.purple, width: 1.5) : null,
                        ),
                        child: Text(emoji, style: const TextStyle(fontSize: 18)),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Priority Slider
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('PRIORITY: $_priority',
                      style: TextStyle(color: textSecondary, fontSize: 11.5, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                  Text(_priority >= 8 ? 'High' : (_priority >= 4 ? 'Medium' : 'Low'),
                      style: const TextStyle(color: KoraColors.purple, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              Slider(
                value: _priority.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                activeColor: KoraColors.purple,
                onChanged: (v) => setState(() => _priority = v.toInt()),
              ),
              const SizedBox(height: 12),

              // Type specific configurations
              if (_selectedType == StatusTriggerType.TIME) ...[
                Text('SCHEDULE (MON - SUN)',
                    style: TextStyle(color: textSecondary, fontSize: 11.5, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(7, (idx) {
                    final dayNum = idx + 1; // 1 = Mon
                    final dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                    final isSel = _selectedDays.contains(dayNum);
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSel) {
                            if (_selectedDays.length > 1) _selectedDays.remove(dayNum);
                          } else {
                            _selectedDays.add(dayNum);
                          }
                        });
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isSel ? KoraColors.purple : KoraColors.inputFillFor(brightness),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            dayLetters[idx],
                            style: TextStyle(
                              color: isSel ? Colors.white : textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('START TIME', style: TextStyle(color: textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: KoraColors.inputFillFor(brightness),
                              side: BorderSide.none,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.access_time, size: 18, color: KoraColors.purple),
                            label: Text(_startTime.format(context), style: TextStyle(color: textPrimary)),
                            onPressed: () async {
                              final picked = await showTimePicker(context: context, initialTime: _startTime);
                              if (picked != null) setState(() => _startTime = picked);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('END TIME', style: TextStyle(color: textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: KoraColors.inputFillFor(brightness),
                              side: BorderSide.none,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.access_time, size: 18, color: KoraColors.purple),
                            label: Text(_endTime.format(context), style: TextStyle(color: textPrimary)),
                            onPressed: () async {
                              final picked = await showTimePicker(context: context, initialTime: _endTime);
                              if (picked != null) setState(() => _endTime = picked);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ] else if (_selectedType == StatusTriggerType.LOCATION) ...[
                Text('LOCATION MAP PLACEHOLDER',
                    style: TextStyle(color: textSecondary, fontSize: 11.5, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                const SizedBox(height: 8),
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: KoraColors.inputFillFor(brightness),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: KoraColors.borderFor(brightness)),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Grid map graphics
                      Positioned.fill(
                        child: CustomPaint(painter: _GridPainter()),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(color: KoraColors.purple, shape: BoxShape.circle),
                            child: const Icon(Icons.my_location_rounded, color: Colors.white, size: 20),
                          ),
                          const SizedBox(height: 6),
                          Text(_locationName, style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('TRIGGER RADIUS', style: TextStyle(color: textSecondary, fontSize: 11.5, fontWeight: FontWeight.bold)),
                    Text('${_radiusMeters.toInt()} meters', style: const TextStyle(color: KoraColors.purple, fontWeight: FontWeight.bold)),
                  ],
                ),
                Slider(
                  value: _radiusMeters,
                  min: 50,
                  max: 1000,
                  divisions: 19,
                  activeColor: KoraColors.purple,
                  onChanged: (v) => setState(() => _radiusMeters = v),
                ),
              ] else if (_selectedType == StatusTriggerType.BATTERY) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('BATTERY THRESHOLD', style: TextStyle(color: textSecondary, fontSize: 11.5, fontWeight: FontWeight.bold)),
                    Text('< ${_batteryThreshold.toInt()}%', style: const TextStyle(color: KoraColors.purple, fontWeight: FontWeight.bold)),
                  ],
                ),
                Slider(
                  value: _batteryThreshold,
                  min: 5,
                  max: 50,
                  divisions: 9,
                  activeColor: KoraColors.purple,
                  onChanged: (v) => setState(() => _batteryThreshold = v),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: KoraColors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.touch_app, color: KoraColors.purple, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Manual triggers can be activated or deactivated with a single tap at any time.',
                          style: TextStyle(color: textSecondary, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Save Button
              ElevatedButton(
                onPressed: _saveTrigger,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: KoraColors.purple,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Save Trigger',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}

class _TypeCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeCard({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? KoraColors.purple.withValues(alpha: 0.2) : KoraColors.inputFillFor(brightness),
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: KoraColors.purple, width: 1.5) : null,
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? KoraColors.purple : KoraColors.textSecondaryFor(brightness), size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? KoraColors.purple : KoraColors.textPrimaryFor(brightness),
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1.0;

    const step = 20.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

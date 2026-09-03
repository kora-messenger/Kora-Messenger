import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/kora_colors.dart';

/// Screen for viewing and creating scheduled call reminders.
class ScheduledCallsScreen extends StatefulWidget {
  const ScheduledCallsScreen({super.key});

  @override
  State<ScheduledCallsScreen> createState() => _ScheduledCallsScreenState();
}

class _ScheduledCallsScreenState extends State<ScheduledCallsScreen> {
  static const _prefsKey = 'kora_scheduled_calls';
  List<Map<String, dynamic>> _calls = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCalls();
  }

  Future<void> _loadCalls() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      try {
        final List<dynamic> list = jsonDecode(raw);
        setState(() {
          _calls = list.cast<Map<String, dynamic>>();
          _loading = false;
        });
        return;
      } catch (_) {}
    }
    setState(() {
      _calls = [];
      _loading = false;
    });
  }

  Future<void> _saveCalls() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_calls));
  }

  void _showAddReminderDialog() {
    final titleController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(hours: 1));
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(selectedDate);

    unawaited(showDialog(
      context: context,
      builder: (ctx) {
        final brightness = Theme.of(context).brightness;
        final textPrimary = KoraColors.textPrimaryFor(brightness);
        final card = KoraColors.cardFor(brightness);

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: card,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                'Schedule Call Reminder',
                style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    style: TextStyle(color: textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Contact or Title',
                      labelStyle: TextStyle(color: KoraColors.textSecondaryFor(brightness)),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: KoraColors.borderFor(brightness))),
                      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: KoraColors.purple)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Date: ${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                      style: TextStyle(color: textPrimary, fontSize: 14),
                    ),
                    trailing: const Icon(Icons.calendar_today, color: KoraColors.purple),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          selectedDate = DateTime(picked.year, picked.month, picked.day, selectedTime.hour, selectedTime.minute);
                        });
                      }
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Time: ${selectedTime.format(context)}',
                      style: TextStyle(color: textPrimary, fontSize: 14),
                    ),
                    trailing: const Icon(Icons.access_time, color: KoraColors.purple),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                      );
                      if (picked != null) {
                        setDialogState(() {
                          selectedTime = picked;
                          selectedDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, picked.hour, picked.minute);
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel', style: TextStyle(color: KoraColors.textSecondaryFor(brightness))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: KoraColors.purple,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    final title = titleController.text.trim();
                    if (title.isNotEmpty) {
                      setState(() {
                        _calls.add({
                          'title': title,
                          'time': selectedDate.toIso8601String(),
                        });
                      });
                      _saveCalls();
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Call scheduled!'),
                          backgroundColor: KoraColors.purple,
                        ),
                      );
                    }
                  },
                  child: const Text('Set Reminder', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() { titleController.dispose(); }));
  }

  void _deleteCall(int index) {
    setState(() {
      _calls.removeAt(index);
    });
    _saveCalls();
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
        title: Text(
          'Scheduled Calls',
          style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: KoraColors.purple))
          : _calls.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_month_outlined, size: 72, color: KoraColors.textMutedFor(brightness)),
                      const SizedBox(height: 16),
                      Text(
                        'No scheduled calls',
                        style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap the button below to schedule a call reminder',
                        style: TextStyle(color: textSecondary, fontSize: 14),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _calls.length,
                  itemBuilder: (context, index) {
                    final item = _calls[index];
                    final date = DateTime.tryParse(item['time'] ?? '') ?? DateTime.now();
                    final formattedDate = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: KoraColors.purple.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.calendar_month, color: KoraColors.purple, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['title'] ?? 'Call',
                                  style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  formattedDate,
                                  style: TextStyle(color: textSecondary, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            onPressed: () => _deleteCall(index),
                          ),
                        ],
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: KoraColors.purple,
        onPressed: _showAddReminderDialog,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

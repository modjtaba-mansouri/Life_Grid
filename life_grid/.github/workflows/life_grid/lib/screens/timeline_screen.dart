import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/daily_entry.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'entry_screen.dart';

/// Lets the user pick any day, then shows a scrollable strip of the
/// 90 days before and after it, colored by that day's overall average.
class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  final _storage = StorageService();
  DateTime _center = DateTime.now();
  Map<String, DailyEntry> _entries = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await _storage.loadAll();
    setState(() => _entries = all);
  }

  Future<void> _pickCenterDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _center,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _center = picked);
  }

  Color _colorFor(double? avg) {
    if (avg == null) return AppColors.border;
    final idx = (avg.round() - 1).clamp(0, 4);
    return AppColors.stageColors[idx];
  }

  @override
  Widget build(BuildContext context) {
    final start = _center.subtract(const Duration(days: 90));
    final days = List.generate(181, (i) => start.add(Duration(days: i)));

    return Scaffold(
      appBar: AppBar(
        title: const Text('90-Day Timeline'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month, size: 20),
            onPressed: _pickCenterDate,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Centered on ${DateFormat('MMM d, yyyy').format(_center)}',
              style: const TextStyle(color: AppColors.textDim, fontSize: 12),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: days.length,
              itemBuilder: (context, i) {
                final day = days[i];
                final key = DailyEntry(date: day).dateKey;
                final entry = _entries[key];
                final isCenter = i == 90;
                return ListTile(
                  dense: true,
                  leading: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _colorFor(entry?.overallAverage),
                    ),
                  ),
                  title: Text(
                    DateFormat('EEE, MMM d, yyyy').format(day),
                    style: TextStyle(
                      fontSize: 13,
                      color: isCenter ? AppColors.accent : AppColors.text,
                      fontWeight:
                          isCenter ? FontWeight.w700 : FontWeight.normal,
                    ),
                  ),
                  subtitle: entry?.note.isNotEmpty == true
                      ? Text(
                          entry!.note,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textDim,
                            fontSize: 11,
                          ),
                        )
                      : null,
                  trailing: entry?.overallAverage != null
                      ? Text(
                          entry!.overallAverage!.toStringAsFixed(1),
                          style: TextStyle(
                            color: _colorFor(entry.overallAverage),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : const Icon(Icons.chevron_right,
                          color: AppColors.textDim, size: 16),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EntryScreen(date: day),
                      ),
                    );
                    _load();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

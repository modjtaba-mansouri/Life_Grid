import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/daily_entry.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'entry_screen.dart';

/// Lets the user pick any day, then shows a scrollable strip of the
/// 90 days before and after it, colored by that day's overall average.
class TimelineScreen extends StatefulWidget {
  TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  final _storage = StorageService();
  DateTime _center = DateTime.now();
  Map<String, DailyEntry> _entries = {};
  double? _personalAverage;

  @override
  void initState() {
    super.initState();
    _load();
    _loadBaseline();
  }

  Future<void> _load() async {
    final start = _center.subtract(Duration(days: 90));
    final end = _center.add(Duration(days: 90));
    final range = await _storage.loadRange(start, end);
    setState(() => _entries = range);
  }

  /// The user's overall average across every entry they've ever made —
  /// the baseline that Timeline days are colored relative to.
  Future<void> _loadBaseline() async {
    final all = await _storage.loadAll();
    final averages = all.values.map((e) => e.overallAverage).whereType<double>().toList();
    if (averages.isEmpty) return;
    setState(() => _personalAverage = averages.reduce((a, b) => a + b) / averages.length);
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

  /// Colors a day relative to the user's personal average, not an
  /// absolute 1-5 scale: well below average -> red, below -> orange,
  /// about the same -> white/gray, above -> light green, well above ->
  /// dark green. Falls back to neutral gray when there's no data yet or
  /// no baseline to compare against.
  Color _colorFor(double? avg) {
    if (avg == null || _personalAverage == null) return AppColors.border;
    final diff = avg - _personalAverage!;
    if (diff <= -1.0) return AppColors.stageColors[0]; // well below — red
    if (diff <= -0.3) return AppColors.stageColors[1]; // below — orange
    if (diff < 0.3) return AppColors.stageColors[2]; // about average — white/gray
    if (diff < 1.0) return AppColors.stageColors[3]; // above — light green
    return AppColors.stageColors[4]; // well above — dark green
  }

  @override
  Widget build(BuildContext context) {
    final start = _center.subtract(Duration(days: 90));
    final days = List.generate(181, (i) => start.add(Duration(days: i)));

    return Scaffold(
      appBar: AppBar(
        title: Text('90-Day Timeline'),
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_month, size: 20),
            onPressed: _pickCenterDate,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Centered on ${DateFormat('MMM d, yyyy').format(_center)}',
              style: TextStyle(color: AppColors.textDim, fontSize: 12),
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
                final hasData = entry?.overallAverage != null;
                final dayColor = _colorFor(entry?.overallAverage);
                return ListTile(
                  dense: true,
                  leading: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: dayColor,
                    ),
                  ),
                  title: Text(
                    DateFormat('EEE, MMM d, yyyy').format(day),
                    style: TextStyle(
                      fontSize: 13,
                      color: isCenter
                          ? AppColors.accent
                          : (hasData ? dayColor : AppColors.text),
                      fontWeight:
                          isCenter ? FontWeight.w700 : FontWeight.normal,
                    ),
                  ),
                  subtitle: entry?.note.isNotEmpty == true
                      ? Text(
                          entry!.note,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
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
                      : Icon(Icons.chevron_right,
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

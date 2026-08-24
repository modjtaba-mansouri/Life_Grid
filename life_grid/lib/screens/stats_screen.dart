import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/daily_entry.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/rating_curve_chart.dart';

enum _Period { weekly, monthly, seasonal, yearly }

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen>
    with SingleTickerProviderStateMixin {
  final _storage = StorageService();
  Map<String, DailyEntry> _entries = {};
  String _category = 'overall'; // 'overall' or a kCategoryKeys entry
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _load();
  }

  Future<void> _load() async {
    final all = await _storage.loadAll();
    setState(() => _entries = all);
  }

  double? _valueFor(DailyEntry? entry) {
    if (entry == null) return null;
    if (_category == 'overall') return entry.overallAverage;
    return entry.ratings[_category]?.toDouble();
  }

  DailyEntry? _entryOn(DateTime day) =>
      _entries[DailyEntry(date: day).dateKey];

  // ---- Period aggregation ----

  ({List<String> labels, List<double?> values, double? avg}) _weekly() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final labels = <String>[];
    final values = <double?>[];
    for (var i = 0; i < 7; i++) {
      final day = DateTime(monday.year, monday.month, monday.day + i);
      labels.add(DateFormat('E').format(day));
      values.add(_valueFor(_entryOn(day)));
    }
    return (labels: labels, values: values, avg: _average(values));
  }

  ({List<String> labels, List<double?> values, double? avg}) _monthly() {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final labels = <String>[];
    final values = <double?>[];
    for (var d = 1; d <= daysInMonth; d++) {
      final day = DateTime(now.year, now.month, d);
      labels.add(d % 5 == 1 ? '$d' : '');
      values.add(_valueFor(_entryOn(day)));
    }
    return (labels: labels, values: values, avg: _average(values));
  }

  ({List<String> labels, List<double?> values, double? avg}) _seasonal() {
    // Meteorological seasons; groups the current season into weekly buckets.
    final now = DateTime.now();
    final seasonStartMonth = ((now.month - 1) ~/ 3) * 3 + 1; // 1,4,7,10
    final seasonStart = DateTime(now.year, seasonStartMonth, 1);
    final seasonEnd = DateTime(now.year, seasonStartMonth + 3, 1);
    final labels = <String>[];
    final values = <double?>[];
    var weekStart = seasonStart;
    var weekNum = 1;
    while (weekStart.isBefore(seasonEnd)) {
      final weekEnd = weekStart.add(const Duration(days: 7));
      final dayVals = <double>[];
      for (var d = weekStart;
          d.isBefore(weekEnd) && d.isBefore(seasonEnd);
          d = d.add(const Duration(days: 1))) {
        final v = _valueFor(_entryOn(d));
        if (v != null) dayVals.add(v);
      }
      labels.add('W$weekNum');
      values.add(dayVals.isEmpty
          ? null
          : dayVals.reduce((a, b) => a + b) / dayVals.length);
      weekStart = weekEnd;
      weekNum++;
    }
    return (labels: labels, values: values, avg: _average(values));
  }

  ({List<String> labels, List<double?> values, double? avg}) _yearly() {
    final now = DateTime.now();
    final labels = <String>[];
    final values = <double?>[];
    for (var m = 1; m <= 12; m++) {
      final daysInMonth = DateTime(now.year, m + 1, 0).day;
      final dayVals = <double>[];
      for (var d = 1; d <= daysInMonth; d++) {
        final v = _valueFor(_entryOn(DateTime(now.year, m, d)));
        if (v != null) dayVals.add(v);
      }
      labels.add(DateFormat('MMM').format(DateTime(now.year, m, 1)));
      values.add(dayVals.isEmpty
          ? null
          : dayVals.reduce((a, b) => a + b) / dayVals.length);
    }
    return (labels: labels, values: values, avg: _average(values));
  }

  double? _average(List<double?> values) {
    final v = values.whereType<double>().toList();
    if (v.isEmpty) return null;
    return v.reduce((a, b) => a + b) / v.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppColors.accent,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textDim,
          labelStyle: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
          tabs: const [
            Tab(text: 'WEEKLY'),
            Tab(text: 'MONTHLY'),
            Tab(text: 'SEASONAL'),
            Tab(text: 'YEARLY'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _CategoryDropdown(
              value: _category,
              onChanged: (v) => setState(() => _category = v),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _periodView(_weekly()),
                _periodView(_monthly()),
                _periodView(_seasonal()),
                _periodView(_yearly()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _periodView(
      ({List<String> labels, List<double?> values, double? avg}) data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: RatingCurveChart(
                xLabels: data.labels,
                values: data.values,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Period average',
                    style: TextStyle(color: AppColors.textDim, fontSize: 12),
                  ),
                  Text(
                    data.avg != null ? data.avg!.toStringAsFixed(2) : '—',
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _CategoryDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final items = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: 'overall', child: Text('Overall average')),
      for (final key in kCategoryKeys)
        DropdownMenuItem(value: key, child: Text(kCategoryLabels[key]!)),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: AppColors.bgElevated,
          style: const TextStyle(color: AppColors.text, fontSize: 13),
          items: items,
          onChanged: (v) => v != null ? onChanged(v) : null,
        ),
      ),
    );
  }
}

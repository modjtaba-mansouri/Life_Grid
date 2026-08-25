import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/daily_entry.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/rating_curve_chart.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _PeriodData {
  final List<String> labels;
  final List<double?> values;
  final List<double?> othersValues;
  final double? avg;
  final double? othersAvg;
  _PeriodData(this.labels, this.values, this.othersValues, this.avg, this.othersAvg);
}

class _StatsScreenState extends State<StatsScreen>
    with SingleTickerProviderStateMixin {
  final _storage = StorageService();
  String _category = 'overall';
  late TabController _tabController;
  bool _loading = true;

  Map<String, DailyEntry> _mine = {};
  Map<String, double?> _others = {};
  DateTime _rangeStart = DateTime.now();
  DateTime _rangeEnd = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this)
      ..addListener(() {
        if (!_tabController.indexIsChanging) _load();
      });
    _load();
  }

  ({DateTime start, DateTime end}) _rangeForTab(int index) {
    final now = DateTime.now();
    switch (index) {
      case 0: // weekly
        final monday = now.subtract(Duration(days: now.weekday - 1));
        return (start: DateTime(monday.year, monday.month, monday.day), end: DateTime(monday.year, monday.month, monday.day + 6));
      case 1: // monthly
        final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
        return (start: DateTime(now.year, now.month, 1), end: DateTime(now.year, now.month, daysInMonth));
      case 2: // seasonal
        final seasonStartMonth = ((now.month - 1) ~/ 3) * 3 + 1;
        final start = DateTime(now.year, seasonStartMonth, 1);
        final end = DateTime(now.year, seasonStartMonth + 3, 1).subtract(const Duration(days: 1));
        return (start: start, end: end);
      case 3: // yearly
      default:
        return (start: DateTime(now.year, 1, 1), end: DateTime(now.year, 12, 31));
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final range = _rangeForTab(_tabController.index);
    _rangeStart = range.start;
    _rangeEnd = range.end;
    final mine = await _storage.loadRange(range.start, range.end);
    final others = await _storage.loadEveryoneAverages(
      range.start,
      range.end,
      categoryKey: _category == 'overall' ? null : _category,
    );
    if (!mounted) return;
    setState(() {
      _mine = mine;
      _others = others;
      _loading = false;
    });
  }

  double? _valueFor(DailyEntry? entry) {
    if (entry == null) return null;
    if (_category == 'overall') return entry.overallAverage;
    return entry.ratings[_category]?.toDouble();
  }

  double? _average(List<double?> values) {
    final v = values.whereType<double>().toList();
    if (v.isEmpty) return null;
    return v.reduce((a, b) => a + b) / v.length;
  }

  _PeriodData _weekly() {
    final labels = <String>[];
    final values = <double?>[];
    final othersValues = <double?>[];
    for (var i = 0; i < 7; i++) {
      final day = DateTime(_rangeStart.year, _rangeStart.month, _rangeStart.day + i);
      final key = DailyEntry(date: day).dateKey;
      labels.add(DateFormat('E').format(day));
      values.add(_valueFor(_mine[key]));
      othersValues.add(_others[key]);
    }
    return _PeriodData(labels, values, othersValues, _average(values), _average(othersValues));
  }

  _PeriodData _monthly() {
    final labels = <String>[];
    final values = <double?>[];
    final othersValues = <double?>[];
    final daysInMonth = _rangeEnd.day;
    for (var d = 1; d <= daysInMonth; d++) {
      final day = DateTime(_rangeStart.year, _rangeStart.month, d);
      final key = DailyEntry(date: day).dateKey;
      labels.add(d % 5 == 1 ? '$d' : '');
      values.add(_valueFor(_mine[key]));
      othersValues.add(_others[key]);
    }
    return _PeriodData(labels, values, othersValues, _average(values), _average(othersValues));
  }

  _PeriodData _weeklyBuckets() {
    final labels = <String>[];
    final values = <double?>[];
    final othersValues = <double?>[];
    var weekStart = _rangeStart;
    var weekNum = 1;
    while (!weekStart.isAfter(_rangeEnd)) {
      final weekEnd = weekStart.add(const Duration(days: 6));
      final mineVals = <double>[];
      final otherVals = <double>[];
      for (var d = weekStart;
          !d.isAfter(weekEnd) && !d.isAfter(_rangeEnd);
          d = d.add(const Duration(days: 1))) {
        final key = DailyEntry(date: d).dateKey;
        final mv = _valueFor(_mine[key]);
        if (mv != null) mineVals.add(mv);
        final ov = _others[key];
        if (ov != null) otherVals.add(ov);
      }
      labels.add('W$weekNum');
      values.add(mineVals.isEmpty ? null : mineVals.reduce((a, b) => a + b) / mineVals.length);
      othersValues.add(otherVals.isEmpty ? null : otherVals.reduce((a, b) => a + b) / otherVals.length);
      weekStart = weekStart.add(const Duration(days: 7));
      weekNum++;
    }
    return _PeriodData(labels, values, othersValues, _average(values), _average(othersValues));
  }

  _PeriodData _monthlyBuckets() {
    final labels = <String>[];
    final values = <double?>[];
    final othersValues = <double?>[];
    for (var m = _rangeStart.month; m <= _rangeEnd.month; m++) {
      final daysInMonth = DateTime(_rangeStart.year, m + 1, 0).day;
      final mineVals = <double>[];
      final otherVals = <double>[];
      for (var d = 1; d <= daysInMonth; d++) {
        final key = DailyEntry(date: DateTime(_rangeStart.year, m, d)).dateKey;
        final mv = _valueFor(_mine[key]);
        if (mv != null) mineVals.add(mv);
        final ov = _others[key];
        if (ov != null) otherVals.add(ov);
      }
      labels.add(DateFormat('MMM').format(DateTime(_rangeStart.year, m, 1)));
      values.add(mineVals.isEmpty ? null : mineVals.reduce((a, b) => a + b) / mineVals.length);
      othersValues.add(otherVals.isEmpty ? null : otherVals.reduce((a, b) => a + b) / otherVals.length);
    }
    return _PeriodData(labels, values, othersValues, _average(values), _average(othersValues));
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
              onChanged: (v) {
                setState(() => _category = v);
                _load();
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _periodView(_weekly()),
                      _periodView(_monthly()),
                      _periodView(_weeklyBuckets()),
                      _periodView(_monthlyBuckets()),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _periodView(_PeriodData data) {
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
                othersValues: data.othersValues,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Your average',
                            style: TextStyle(color: AppColors.textDim, fontSize: 11)),
                        const SizedBox(height: 4),
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
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Everyone\'s average',
                            style: TextStyle(color: AppColors.textDim, fontSize: 11)),
                        const SizedBox(height: 4),
                        Text(
                          data.othersAvg != null
                              ? data.othersAvg!.toStringAsFixed(2)
                              : '—',
                          style: const TextStyle(
                            color: Color(0xFF6B8FA3),
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
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

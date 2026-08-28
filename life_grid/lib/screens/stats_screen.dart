import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/category_schema.dart';
import '../models/daily_entry.dart';
import '../services/parameters_service.dart';
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
  final int? todayIndex;
  _PeriodData(this.labels, this.values, this.othersValues, this.avg, this.othersAvg, {this.todayIndex});
}

class _StatsScreenState extends State<StatsScreen> with SingleTickerProviderStateMixin {
  final _storage = StorageService();
  final _params = ParametersService();
  String? _selectedCategoryId; // null = overall
  String? _selectedItemId; // null = category average (or n/a for solo)
  late TabController _tabController;
  bool _loading = true;

  Map<String, DailyEntry> _mine = {};
  Map<String, double?> _others = {};
  DateTime _rangeStart = DateTime.now();
  DateTime _rangeEnd = DateTime.now();
  List<CategoryDef> _categories = [];
  Set<String> _enabledCategories = {};
  final Map<String, List<ItemDef>> _itemsByCategory = {};
  final Map<String, Set<String>> _enabledItemsByCategory = {};

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
        final end = DateTime(now.year, seasonStartMonth + 3, 1).subtract(Duration(days: 1));
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

    final categories = await _params.allCategories();
    final enabledCategories = await _params.loadEnabledCategories();
    _itemsByCategory.clear();
    _enabledItemsByCategory.clear();
    for (final cat in categories) {
      if (cat.isSolo) continue;
      _itemsByCategory[cat.id] = await _params.allItems(cat);
      _enabledItemsByCategory[cat.id] = await _params.loadEnabledItems(cat.id);
    }

    final mine = await _storage.loadRange(range.start, range.end);
    final others = await _storage.loadEveryoneAverages(
      range.start,
      range.end,
      categoryId: _selectedCategoryId,
      itemId: _selectedItemId,
    );
    if (!mounted) return;
    setState(() {
      _mine = mine;
      _others = others;
      _categories = categories;
      _enabledCategories = enabledCategories;
      if (_selectedCategoryId != null && !enabledCategories.contains(_selectedCategoryId)) {
        _selectedCategoryId = null;
        _selectedItemId = null;
      }
      _loading = false;
    });
  }

  double? _valueFor(DailyEntry? entry) {
    if (entry == null) return null;
    if (_selectedCategoryId == null) return entry.overallAverage;
    if (_selectedItemId != null) {
      return entry.itemValue(_selectedCategoryId!, _selectedItemId!)?.toDouble();
    }
    return entry.categoryAverage(_selectedCategoryId!);
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
    final now = DateTime.now();
    int? todayIndex;
    for (var i = 0; i < 7; i++) {
      final day = DateTime(_rangeStart.year, _rangeStart.month, _rangeStart.day + i);
      final key = DailyEntry(date: day).dateKey;
      labels.add(DateFormat('E').format(day));
      values.add(_valueFor(_mine[key]));
      othersValues.add(_others[key]);
      if (day.year == now.year && day.month == now.month && day.day == now.day) todayIndex = i;
    }
    return _PeriodData(labels, values, othersValues, _average(values), _average(othersValues), todayIndex: todayIndex);
  }

  _PeriodData _monthly() {
    final labels = <String>[];
    final values = <double?>[];
    final othersValues = <double?>[];
    final daysInMonth = _rangeEnd.day;
    final now = DateTime.now();
    int? todayIndex;
    for (var d = 1; d <= daysInMonth; d++) {
      final day = DateTime(_rangeStart.year, _rangeStart.month, d);
      final key = DailyEntry(date: day).dateKey;
      labels.add(d % 5 == 1 ? '$d' : '');
      values.add(_valueFor(_mine[key]));
      othersValues.add(_others[key]);
      if (day.year == now.year && day.month == now.month && day.day == now.day) todayIndex = d - 1;
    }
    return _PeriodData(labels, values, othersValues, _average(values), _average(othersValues), todayIndex: todayIndex);
  }

  _PeriodData _weeklyBuckets() {
    final labels = <String>[];
    final values = <double?>[];
    final othersValues = <double?>[];
    var weekStart = _rangeStart;
    var weekNum = 1;
    while (!weekStart.isAfter(_rangeEnd)) {
      final weekEnd = weekStart.add(Duration(days: 6));
      final mineVals = <double>[];
      final otherVals = <double>[];
      for (var d = weekStart; !d.isAfter(weekEnd) && !d.isAfter(_rangeEnd); d = d.add(Duration(days: 1))) {
        final key = DailyEntry(date: d).dateKey;
        final mv = _valueFor(_mine[key]);
        if (mv != null) mineVals.add(mv);
        final ov = _others[key];
        if (ov != null) otherVals.add(ov);
      }
      labels.add('W$weekNum');
      values.add(mineVals.isEmpty ? null : mineVals.reduce((a, b) => a + b) / mineVals.length);
      othersValues.add(otherVals.isEmpty ? null : otherVals.reduce((a, b) => a + b) / otherVals.length);
      weekStart = weekStart.add(Duration(days: 7));
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
        title: Text('Statistics'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppColors.accent,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textDim,
          labelStyle: TextStyle(fontSize: 12, fontFamily: 'monospace'),
          tabs: [Tab(text: 'WEEKLY'), Tab(text: 'MONTHLY'), Tab(text: 'SEASONAL'), Tab(text: 'YEARLY')],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _CategoryPicker(
              categories: _categories,
              enabledCategories: _enabledCategories,
              itemsByCategory: _itemsByCategory,
              enabledItemsByCategory: _enabledItemsByCategory,
              selectedCategoryId: _selectedCategoryId,
              selectedItemId: _selectedItemId,
              onChanged: (catId, itemId) {
                setState(() {
                  _selectedCategoryId = catId;
                  _selectedItemId = itemId;
                });
                _load();
              },
            ),
          ),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator())
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
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: RatingCurveChart(
                xLabels: data.labels,
                values: data.values,
                othersValues: data.othersValues,
                todayIndex: data.todayIndex,
              ),
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Your average', style: TextStyle(color: AppColors.textDim, fontSize: 11)),
                        SizedBox(height: 4),
                        Text(
                          data.avg != null ? data.avg!.toStringAsFixed(2) : '—',
                          style: TextStyle(color: AppColors.accent, fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Everyone\'s average', style: TextStyle(color: AppColors.textDim, fontSize: 11)),
                        SizedBox(height: 4),
                        Text(
                          data.othersAvg != null ? data.othersAvg!.toStringAsFixed(2) : '—',
                          style: TextStyle(color: Color(0xFF6B8FA3), fontSize: 18, fontWeight: FontWeight.w700),
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

/// Two-step picker: category (or "Overall"), then — if that category has
/// more than one enabled item — which item (or "category average").
class _CategoryPicker extends StatelessWidget {
  final List<CategoryDef> categories;
  final Set<String> enabledCategories;
  final Map<String, List<ItemDef>> itemsByCategory;
  final Map<String, Set<String>> enabledItemsByCategory;
  final String? selectedCategoryId;
  final String? selectedItemId;
  final void Function(String? categoryId, String? itemId) onChanged;

  _CategoryPicker({
    required this.categories,
    required this.enabledCategories,
    required this.itemsByCategory,
    required this.enabledItemsByCategory,
    required this.selectedCategoryId,
    required this.selectedItemId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final visibleCategories = categories.where((c) => enabledCategories.contains(c.id)).toList();
    CategoryDef? selectedCat;
    for (final c in visibleCategories) {
      if (c.id == selectedCategoryId) selectedCat = c;
    }
    final items = selectedCat == null
        ? <ItemDef>[]
        : (itemsByCategory[selectedCat.id] ?? [])
            .where((i) => (enabledItemsByCategory[selectedCat!.id] ?? {}).contains(i.id))
            .toList();

    return Column(
      children: [
        _dropdown<String?>(
          value: selectedCategoryId,
          items: [
            DropdownMenuItem(value: null, child: Text('Overall average')),
            for (final c in visibleCategories) DropdownMenuItem(value: c.id, child: Text(c.label)),
          ],
          onChanged: (v) => onChanged(v, null),
        ),
        if (selectedCat != null && !selectedCat.isSolo && items.length > 1) ...[
          SizedBox(height: 8),
          _dropdown<String?>(
            value: selectedItemId,
            items: [
              DropdownMenuItem(value: null, child: Text('${selectedCat.label} average')),
              for (final i in items) DropdownMenuItem(value: i.id, child: Text(i.label)),
            ],
            onChanged: (v) => onChanged(selectedCat!.id, v),
          ),
        ],
      ],
    );
  }

  Widget _dropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: AppColors.bgElevated,
          style: TextStyle(color: AppColors.text, fontSize: 13),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

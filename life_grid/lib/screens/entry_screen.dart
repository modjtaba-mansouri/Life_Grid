import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/category_schema.dart';
import '../models/daily_entry.dart';
import '../services/forecast_service.dart';
import '../services/parameters_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/birthday_banner.dart';
import '../widgets/stage_selector.dart';

class EntryScreen extends StatefulWidget {
  final DateTime date;
  const EntryScreen({super.key, required this.date});

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
  final _storage = StorageService();
  final _params = ParametersService();
  late DateTime _currentDate;
  late DailyEntry _entry;
  final _noteController = TextEditingController();
  bool _loading = true;
  Forecast? _forecast;

  TrackingMode _mode = TrackingMode.simple;
  List<CategoryDef> _categories = [];
  Set<String> _enabledCategories = {};
  final Map<String, List<ItemDef>> _itemsByCategory = {};
  final Map<String, Set<String>> _enabledItemsByCategory = {};

  @override
  void initState() {
    super.initState();
    _currentDate = DateTime(widget.date.year, widget.date.month, widget.date.day);
    _load();
  }

  bool get _isToday {
    final now = DateTime.now();
    return _currentDate.year == now.year &&
        _currentDate.month == now.month &&
        _currentDate.day == now.day;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final existing = await _storage.loadEntry(_currentDate);
    final mode = await _params.loadMode();
    final categories = await _params.allCategories();
    final enabledCategories = await _params.loadEnabledCategories();

    _itemsByCategory.clear();
    _enabledItemsByCategory.clear();
    for (final cat in categories) {
      if (cat.isSolo) continue;
      final items = await _params.allItems(cat);
      _itemsByCategory[cat.id] = items;
      _enabledItemsByCategory[cat.id] = await _params.loadEnabledItems(cat.id);
    }

    Forecast? forecast;
    if (_isToday) {
      final lookback = await _storage.loadForecastDays();
      final rangeStart = _currentDate.subtract(Duration(days: lookback));
      final rangeEnd = _currentDate.subtract(Duration(days: 1));
      final all = await _storage.loadRange(rangeStart, rangeEnd);
      forecast = computeForecast(entries: all, today: _currentDate, lookbackDays: lookback);
    }

    setState(() {
      _entry = existing ?? DailyEntry(date: _currentDate);
      _noteController.text = _entry.note;
      _forecast = forecast;
      _mode = mode;
      _categories = categories;
      _enabledCategories = enabledCategories;
      _loading = false;
    });
  }

  void _goToDate(DateTime date) {
    setState(() => _currentDate = DateTime(date.year, date.month, date.day));
    _load();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _currentDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) _goToDate(picked);
  }

  Future<void> _save() async {
    final toSave = _entry.copyWith(note: _noteController.text);
    try {
      await _storage.saveEntry(toSave);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not save — data source unreachable.')));
      }
    }
  }

  Future<void> _setSoloOrCombined(String categoryId, int stage) async {
    setState(() => _entry = _entry.withRating(categoryId, categoryId, stage));
  }

  Future<void> _setItemRating(String categoryId, String itemId, int stage) async {
    if (categoryId == 'education' && _entry.educationEnvironment == null) {
      final env = await _askEducationEnvironment();
      if (env == null) return; // user cancelled — don't record without it
      setState(() => _entry = _entry.copyWith(educationEnvironment: env));
    }
    setState(() => _entry = _entry.withRating(categoryId, itemId, stage));
  }

  Future<String?> _askEducationEnvironment() {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        title: Text('Which environment?', style: TextStyle(color: AppColors.text, fontSize: 15)),
        content: Text(
          'This only needs to be set once for your Education tracking.',
          style: TextStyle(color: AppColors.textDim, fontSize: 12),
        ),
        actions: [
          for (final option in ['School', 'College', 'University'])
            TextButton(
              onPressed: () => Navigator.pop(context, option),
              child: Text(option, style: TextStyle(color: AppColors.accent)),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = DateFormat('EEEE, MMM d, yyyy').format(_currentDate);
    final canGoForward = !_currentDate.isAfter(DateTime.now().subtract(Duration(days: 1)));
    return Scaffold(
      appBar: AppBar(title: Text('Life Grid')),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.all(16),
              children: [
                if (_isToday) BirthdayBanner(),
                _DateNav(
                  label: label,
                  isToday: _isToday,
                  onPrev: () => _goToDate(_currentDate.subtract(Duration(days: 1))),
                  onNext: canGoForward ? () => _goToDate(_currentDate.add(Duration(days: 1))) : null,
                  onPickDate: _pickDate,
                ),
                SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _QuickChip(
                      label: 'Yesterday',
                      onTap: () => _goToDate(DateTime.now().subtract(Duration(days: 1))),
                    ),
                    _QuickChip(
                      label: 'Day before',
                      onTap: () => _goToDate(DateTime.now().subtract(Duration(days: 2))),
                    ),
                  ],
                ),
                if (_isToday && _forecast?.projected != null) ...[
                  SizedBox(height: 16),
                  _ForecastCard(forecast: _forecast!),
                ],
                SizedBox(height: 16),
                for (final cat in _categories)
                  if (_enabledCategories.contains(cat.id)) ..._buildCategoryRows(cat),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                  ),
                  child: Text(
                    'This is general information, not medical advice. If your '
                    'symptoms are severe, sudden, or don\'t improve, talk to a '
                    'healthcare professional — or at least consider talking to '
                    'someone. Don\'t keep everything inside and torture yourself.',
                    style: TextStyle(fontSize: 11, color: AppColors.textDim, height: 1.4),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _noteController,
                  maxLines: 3,
                  style: TextStyle(color: AppColors.text, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Note (optional)',
                    labelStyle: TextStyle(color: AppColors.textDim),
                    filled: true,
                    fillColor: AppColors.bgCard,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _save,
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text('SAVE ENTRY'),
                  ),
                ),
              ],
            ),
    );
  }

  List<Widget> _buildCategoryRows(CategoryDef cat) {
    if (cat.isSolo) {
      return [
        StageSelector(
          label: cat.label,
          value: _entry.itemValue(cat.id, cat.id),
          onChanged: (stage) => _setSoloOrCombined(cat.id, stage),
        ),
      ];
    }
    if (_mode == TrackingMode.simple) {
      return [
        StageSelector(
          label: cat.label,
          value: _entry.itemValue(cat.id, cat.id),
          onChanged: (stage) => _setSoloOrCombined(cat.id, stage),
        ),
      ];
    }
    // Precise mode: one row per enabled item, with a category header.
    final items = _itemsByCategory[cat.id] ?? [];
    final enabledItems = _enabledItemsByCategory[cat.id] ?? {};
    final visibleItems = items.where((i) => enabledItems.contains(i.id)).toList();
    if (visibleItems.isEmpty) return [];
    return [
      Padding(
        padding: EdgeInsets.only(top: 10, bottom: 2),
        child: Text(
          cat.label.toUpperCase(),
          style: TextStyle(fontSize: 11, color: AppColors.textDim, letterSpacing: 1),
        ),
      ),
      for (final item in visibleItems)
        StageSelector(
          label: item.label,
          value: _entry.itemValue(cat.id, item.id),
          onChanged: (stage) => _setItemRating(cat.id, item.id, stage),
        ),
    ];
  }
}

class _DateNav extends StatelessWidget {
  final String label;
  final bool isToday;
  final VoidCallback onPrev;
  final VoidCallback? onNext;
  final VoidCallback onPickDate;

  const _DateNav({
    required this.label,
    required this.isToday,
    required this.onPrev,
    required this.onNext,
    required this.onPickDate,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(onPressed: onPrev, icon: Icon(Icons.chevron_left, color: AppColors.textDim)),
        Expanded(
          child: GestureDetector(
            onTap: onPickDate,
            child: Column(
              children: [
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isToday ? AppColors.accent : AppColors.text,
                  ),
                ),
                if (!isToday)
                  Text('Editing a past day', style: TextStyle(fontSize: 10, color: AppColors.textDim)),
              ],
            ),
          ),
        ),
        IconButton(
          onPressed: onNext,
          icon: Icon(Icons.chevron_right, color: onNext == null ? AppColors.border : AppColors.textDim),
        ),
      ],
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label, style: TextStyle(fontSize: 11)),
    );
  }
}

class _ForecastCard extends StatelessWidget {
  final Forecast forecast;
  const _ForecastCard({required this.forecast});

  @override
  Widget build(BuildContext context) {
    final projected = forecast.projected!;
    final idx = (projected.round() - 1).clamp(0, 4);
    final color = AppColors.stageColors[idx];
    return Card(
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Foreseeing today · based on last ${forecast.daysUsed} days',
                    style: TextStyle(fontSize: 11, color: AppColors.textDim),
                  ),
                  Text(
                    forecast.trendLabel,
                    style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            Text(
              projected.toStringAsFixed(1),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

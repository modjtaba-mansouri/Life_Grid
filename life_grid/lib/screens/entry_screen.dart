import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/daily_entry.dart';
import '../services/forecast_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/stage_selector.dart';

class EntryScreen extends StatefulWidget {
  final DateTime date;
  const EntryScreen({super.key, required this.date});

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
  final _storage = StorageService();
  late DateTime _currentDate;
  late DailyEntry _entry;
  final _noteController = TextEditingController();
  bool _loading = true;
  Forecast? _forecast;

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
    Forecast? forecast;
    if (_isToday) {
      final lookback = await _storage.loadForecastDays();
      final rangeStart = _currentDate.subtract(Duration(days: lookback));
      final rangeEnd = _currentDate.subtract(const Duration(days: 1));
      final all = await _storage.loadRange(rangeStart, rangeEnd);
      forecast = computeForecast(
        entries: all,
        today: _currentDate,
        lookbackDays: lookback,
      );
    }
    setState(() {
      _entry = existing ?? DailyEntry(date: _currentDate);
      _noteController.text = _entry.note;
      _forecast = forecast;
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save — data source unreachable.')),
        );
      }
    }
  }

  void _setRating(String key, int stage) {
    setState(() {
      final updated = Map<String, int?>.of(_entry.ratings);
      updated[key] = stage;
      _entry = _entry.copyWith(ratings: updated);
    });
  }

  @override
  Widget build(BuildContext context) {
    final label = DateFormat('EEEE, MMM d, yyyy').format(_currentDate);
    final canGoForward = _currentDate.isBefore(
      DateTime.now().subtract(const Duration(days: 0)),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Life Grid')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _DateNav(
                  label: label,
                  isToday: _isToday,
                  onPrev: () => _goToDate(
                    _currentDate.subtract(const Duration(days: 1)),
                  ),
                  onNext: canGoForward
                      ? () => _goToDate(
                            _currentDate.add(const Duration(days: 1)),
                          )
                      : null,
                  onPickDate: _pickDate,
                  onToday: _isToday ? null : () => _goToDate(DateTime.now()),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _QuickChip(
                      label: 'Yesterday',
                      onTap: () => _goToDate(
                        DateTime.now().subtract(const Duration(days: 1)),
                      ),
                    ),
                    _QuickChip(
                      label: 'Day before',
                      onTap: () => _goToDate(
                        DateTime.now().subtract(const Duration(days: 2)),
                      ),
                    ),
                  ],
                ),
                if (_isToday && _forecast?.projected != null) ...[
                  const SizedBox(height: 16),
                  _ForecastCard(forecast: _forecast!),
                ],
                const SizedBox(height: 16),
                for (final key in kCategoryKeys)
                  StageSelector(
                    label: kCategoryLabels[key]!,
                    value: _entry.ratings[key],
                    onChanged: (stage) => _setRating(key, stage),
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: _noteController,
                  maxLines: 3,
                  style: const TextStyle(color: AppColors.text, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Note (optional)',
                    labelStyle: const TextStyle(color: AppColors.textDim),
                    filled: true,
                    fillColor: AppColors.bgCard,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _save,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text('SAVE ENTRY'),
                  ),
                ),
              ],
            ),
    );
  }
}

class _DateNav extends StatelessWidget {
  final String label;
  final bool isToday;
  final VoidCallback onPrev;
  final VoidCallback? onNext;
  final VoidCallback onPickDate;
  final VoidCallback? onToday;

  const _DateNav({
    required this.label,
    required this.isToday,
    required this.onPrev,
    required this.onNext,
    required this.onPickDate,
    required this.onToday,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onPrev,
          icon: const Icon(Icons.chevron_left, color: AppColors.textDim),
        ),
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
                  const Text(
                    'Editing a past day',
                    style: TextStyle(fontSize: 10, color: AppColors.textDim),
                  ),
              ],
            ),
          ),
        ),
        IconButton(
          onPressed: onNext,
          icon: Icon(
            Icons.chevron_right,
            color: onNext == null ? AppColors.border : AppColors.textDim,
          ),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label, style: const TextStyle(fontSize: 11)),
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
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Foreseeing today · based on last ${forecast.daysUsed} days',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textDim,
                    ),
                  ),
                  Text(
                    forecast.trendLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              projected.toStringAsFixed(1),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

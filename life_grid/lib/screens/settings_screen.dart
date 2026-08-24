import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _storage = StorageService();
  final _notifications = NotificationService();
  TimeOfDay _time = const TimeOfDay(hour: 20, minute: 0);
  bool _enabled = true;
  final _forecastController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final (hour, minute, enabled) = await _storage.loadNotifyTime();
    final forecastDays = await _storage.loadForecastDays();
    setState(() {
      _time = TimeOfDay(hour: hour, minute: minute);
      _enabled = enabled;
      _forecastController.text = forecastDays.toString();
    });
  }

  Future<void> _saveForecastDays(String value) async {
    final parsed = int.tryParse(value);
    if (parsed == null || parsed < 3) return; // need at least 3 points
    await _storage.saveForecastDays(parsed);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Foreseeing window set to $parsed days.')),
      );
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) {
      setState(() => _time = picked);
      await _apply();
    }
  }

  Future<void> _toggleEnabled(bool value) async {
    setState(() => _enabled = value);
    await _apply();
  }

  Future<void> _apply() async {
    await _storage.saveNotifyTime(_time.hour, _time.minute, _enabled);
    if (_enabled) {
      await _notifications.requestPermissions();
      await _notifications.scheduleDaily(_time.hour, _time.minute);
    } else {
      await _notifications.cancelDaily();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: SwitchListTile(
              title: const Text(
                'Daily reminder',
                style: TextStyle(fontSize: 13, color: AppColors.text),
              ),
              subtitle: const Text(
                'Notify me every day to log my entry',
                style: TextStyle(fontSize: 11, color: AppColors.textDim),
              ),
              value: _enabled,
              activeColor: AppColors.accent,
              onChanged: _toggleEnabled,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              title: const Text(
                'Reminder time',
                style: TextStyle(fontSize: 13, color: AppColors.text),
              ),
              subtitle: Text(
                _time.format(context),
                style: const TextStyle(fontSize: 16, color: AppColors.accent),
              ),
              trailing:
                  const Icon(Icons.schedule, color: AppColors.textDim, size: 18),
              onTap: _enabled ? _pickTime : null,
              enabled: _enabled,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Foreseeing window',
                    style: TextStyle(fontSize: 13, color: AppColors.text),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'How many past days to base today\'s forecast on',
                    style: TextStyle(fontSize: 11, color: AppColors.textDim),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _forecastController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppColors.text, fontSize: 13),
                    decoration: InputDecoration(
                      suffixText: 'days',
                      suffixStyle: const TextStyle(color: AppColors.textDim),
                      filled: true,
                      fillColor: AppColors.bg,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radius),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                    onSubmitted: _saveForecastDays,
                    onEditingComplete: () =>
                        _saveForecastDays(_forecastController.text),
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

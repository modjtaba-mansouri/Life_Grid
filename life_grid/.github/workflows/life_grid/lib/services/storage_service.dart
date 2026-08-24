import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/daily_entry.dart';

/// Persists all daily entries as a single JSON map (dateKey -> entry) in
/// SharedPreferences. Simple and dependency-light; swap for sqflite/Hive
/// later if the entry count grows large enough to matter.
class StorageService {
  static const _entriesKey = 'life_grid_entries_v1';
  static const _notifyHourKey = 'life_grid_notify_hour';
  static const _notifyMinuteKey = 'life_grid_notify_minute';
  static const _notifyEnabledKey = 'life_grid_notify_enabled';
  static const _forecastDaysKey = 'life_grid_forecast_days';

  /// Whether the last attempt to read/write local storage succeeded.
  /// Drives the HAL-9000-style status eye: green = connected, red = not.
  static final ValueNotifier<bool> connectionStatus = ValueNotifier(true);

  Future<Map<String, DailyEntry>> loadAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_entriesKey);
      connectionStatus.value = true;
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (key, value) => MapEntry(
          key,
          DailyEntry.fromJson(Map<String, dynamic>.from(value)),
        ),
      );
    } catch (_) {
      connectionStatus.value = false;
      return {};
    }
  }

  Future<void> saveEntry(DailyEntry entry) async {
    try {
      final all = await loadAll();
      all[entry.dateKey] = entry;
      await _saveAll(all);
      connectionStatus.value = true;
    } catch (_) {
      connectionStatus.value = false;
      rethrow;
    }
  }

  Future<void> _saveAll(Map<String, DailyEntry> all) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(all.map((k, v) => MapEntry(k, v.toJson())));
    await prefs.setString(_entriesKey, encoded);
  }

  Future<DailyEntry?> loadEntry(DateTime date) async {
    final all = await loadAll();
    final key = DailyEntry(date: date).dateKey;
    return all[key];
  }

  // ---- Notification preferences ----

  Future<void> saveNotifyTime(int hour, int minute, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_notifyHourKey, hour);
    await prefs.setInt(_notifyMinuteKey, minute);
    await prefs.setBool(_notifyEnabledKey, enabled);
  }

  Future<(int hour, int minute, bool enabled)> loadNotifyTime() async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt(_notifyHourKey) ?? 20; // default 8 PM
    final minute = prefs.getInt(_notifyMinuteKey) ?? 0;
    final enabled = prefs.getBool(_notifyEnabledKey) ?? true;
    return (hour, minute, enabled);
  }

  // ---- Forecast lookback window ----

  Future<void> saveForecastDays(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_forecastDaysKey, days);
  }

  Future<int> loadForecastDays() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_forecastDaysKey) ?? 30; // default: last 30 days
  }
}

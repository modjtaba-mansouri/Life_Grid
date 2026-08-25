import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/firebase_config.dart';
import '../models/daily_entry.dart';
import 'auth_service.dart';
import 'firestore_rest.dart';

/// Persists daily entries to Firestore, scoped to the current logged-in
/// user. Local SharedPreferences is only used for small app settings
/// (notification time, forecast window) — the actual life-tracking data
/// lives in the cloud so it can be compared across users.
class StorageService {
  static const _notifyHourKey = 'life_grid_notify_hour';
  static const _notifyMinuteKey = 'life_grid_notify_minute';
  static const _notifyEnabledKey = 'life_grid_notify_enabled';
  static const _forecastDaysKey = 'life_grid_forecast_days';

  /// Whether the last attempt to read/write Firestore succeeded.
  /// Drives the HAL-9000-style status eye: green = connected, red = not.
  static final ValueNotifier<bool> connectionStatus = ValueNotifier(true);

  final FirestoreRest _db =
      FirestoreRest(projectId: FirebaseConfig.projectId, apiKey: FirebaseConfig.apiKey);

  /// Set by the app shell right after login/session restore.
  static AppUser? currentUser;

  String get _userSlug {
    final user = currentUser;
    if (user == null) throw StateError('No logged-in user.');
    return user.slug;
  }

  Future<DailyEntry?> loadEntry(DateTime date) async {
    final key = DailyEntry(date: date).dateKey;
    try {
      final doc = await _db.getDocument('users/$_userSlug/entries/$key');
      connectionStatus.value = true;
      if (doc == null) return null;
      return _entryFromFields(date, doc);
    } catch (_) {
      connectionStatus.value = false;
      return null;
    }
  }

  Future<void> saveEntry(DailyEntry entry) async {
    try {
      await _db.setDocument(
        'users/$_userSlug/entries/${entry.dateKey}',
        {
          'date': entry.dateKey,
          'note': entry.note,
          'ratings': entry.ratings,
        },
      );
      connectionStatus.value = true;
    } catch (_) {
      connectionStatus.value = false;
      rethrow;
    }
  }

  /// Loads every entry for the current user (used by the timeline).
  Future<Map<String, DailyEntry>> loadAll() async {
    try {
      final docs = await _db.listDocuments('users/$_userSlug/entries');
      connectionStatus.value = true;
      return docs.map((id, fields) {
        final parts = id.split('-');
        final date = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
        return MapEntry(id, _entryFromFields(date, fields));
      });
    } catch (_) {
      connectionStatus.value = false;
      return {};
    }
  }

  /// Loads entries for the current user across a specific date range
  /// (inclusive), using one batched request instead of N individual ones.
  Future<Map<String, DailyEntry>> loadRange(
    DateTime start,
    DateTime end,
  ) async {
    return _loadRangeForUser(_userSlug, start, end);
  }

  /// Loads the same date range for every other known user, and returns
  /// the per-day average across all of them (the "everyone" comparison
  /// line in Stats). Skips the current user.
  Future<Map<String, double?>> loadEveryoneAverages(
    DateTime start,
    DateTime end, {
    String? categoryKey,
  }) async {
    final auth = AuthService();
    final slugs = await auth.allUserSlugs();
    final others = slugs.where((s) => s != _userSlug).toList();
    if (others.isEmpty) return {};

    // date -> list of that day's values across all other users
    final byDate = <String, List<double>>{};
    for (final slug in others) {
      final entries = await _loadRangeForUser(slug, start, end);
      for (final entry in entries.values) {
        final value = categoryKey == null
            ? entry.overallAverage
            : entry.ratings[categoryKey]?.toDouble();
        if (value == null) continue;
        byDate.putIfAbsent(entry.dateKey, () => []).add(value);
      }
    }
    return byDate.map(
      (date, vals) => MapEntry(
        date,
        vals.isEmpty ? null : vals.reduce((a, b) => a + b) / vals.length,
      ),
    );
  }

  Future<Map<String, DailyEntry>> _loadRangeForUser(
    String slug,
    DateTime start,
    DateTime end,
  ) async {
    final paths = <String>[];
    for (var d = start;
        !d.isAfter(end);
        d = d.add(const Duration(days: 1))) {
      paths.add('users/$slug/entries/${DailyEntry(date: d).dateKey}');
    }
    try {
      final docs = await _db.batchGet(paths);
      connectionStatus.value = true;
      return docs.map((id, fields) {
        final parts = id.split('-');
        final date = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
        return MapEntry(id, _entryFromFields(date, fields));
      });
    } catch (_) {
      connectionStatus.value = false;
      return {};
    }
  }

  DailyEntry _entryFromFields(DateTime date, Map<String, dynamic> fields) {
    final rawRatings = Map<String, dynamic>.from(fields['ratings'] ?? {});
    final ratings = <String, int?>{
      for (final k in kCategoryKeys) k: rawRatings[k] as int?,
    };
    return DailyEntry(date: date, ratings: ratings, note: fields['note'] ?? '');
  }

  // ---- Local app settings (device-specific, not synced) ----

  Future<void> saveNotifyTime(int hour, int minute, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_notifyHourKey, hour);
    await prefs.setInt(_notifyMinuteKey, minute);
    await prefs.setBool(_notifyEnabledKey, enabled);
  }

  Future<(int hour, int minute, bool enabled)> loadNotifyTime() async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt(_notifyHourKey) ?? 20;
    final minute = prefs.getInt(_notifyMinuteKey) ?? 0;
    final enabled = prefs.getBool(_notifyEnabledKey) ?? true;
    return (hour, minute, enabled);
  }

  Future<void> saveForecastDays(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_forecastDaysKey, days);
  }

  Future<int> loadForecastDays() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_forecastDaysKey) ?? 30;
  }
}

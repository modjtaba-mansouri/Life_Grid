import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/firebase_config.dart';
import '../models/daily_entry.dart';
import 'auth_service.dart';
import 'firestore_rest.dart';

/// Offline-first storage. Every read/write hits the on-device cache first
/// (so the app fully works with no internet), and writes are queued for
/// Firestore in the background. When a Firestore call succeeds, pending
/// items are flushed. This is deliberately simple last-write-wins sync —
/// fine for a personal/small-group app, not built for heavy concurrent
/// editing of the same day from two offline devices at once.
class StorageService {
  static const _notifyHourKey = 'life_grid_notify_hour';
  static const _notifyMinuteKey = 'life_grid_notify_minute';
  static const _notifyEnabledKey = 'life_grid_notify_enabled';
  static const _forecastDaysKey = 'life_grid_forecast_days';
  static const _lockAfterKey = 'life_grid_lock_after_minutes';

  /// True only while Firestore is actually reachable and responding.
  /// Drives the HAL-9000 status eye: green = connected, red = offline
  /// (the app still works either way — this is informational).
  static final ValueNotifier<bool> connectionStatus = ValueNotifier(true);

  static AppUser? currentUser;

  final FirestoreRest _db =
      FirestoreRest(projectId: FirebaseConfig.projectId, apiKey: FirebaseConfig.apiKey);

  String get _userSlug {
    final user = currentUser;
    if (user == null) throw StateError('No logged-in user.');
    return user.slug;
  }

  String get _localEntriesKey => 'life_grid_local_entries_${_userSlug}_v2';
  String get _pendingKey => 'life_grid_pending_sync_${_userSlug}_v2';

  DateTime _dateFromKey(String key) {
    final parts = key.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }

  // ---- Local cache (source of truth for reads) ----

  Future<Map<String, DailyEntry>> _readLocalCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localEntriesKey);
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(
          k,
          DailyEntry.fromFields(_dateFromKey(k), Map<String, dynamic>.from(v)),
        ));
  }

  Future<void> _writeLocalCache(Map<String, DailyEntry> all) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(all.map((k, v) => MapEntry(k, v.toFields())));
    await prefs.setString(_localEntriesKey, encoded);
  }

  Future<List<String>> _readPending() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_pendingKey) ?? [];
  }

  Future<void> _writePending(List<String> keys) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_pendingKey, keys);
  }

  // ---- Public API used by the UI ----

  Future<DailyEntry?> loadEntry(DateTime date) async {
    final cache = await _readLocalCache();
    return cache[DailyEntry(date: date).dateKey];
  }

  Future<void> saveEntry(DailyEntry entry) async {
    // 1. Always write locally first — this must never fail due to network.
    final cache = await _readLocalCache();
    cache[entry.dateKey] = entry;
    await _writeLocalCache(cache);

    // 2. Try to push to Firestore immediately; if it fails, queue it.
    final pushed = await _tryPush(entry);
    if (!pushed) {
      final pending = await _readPending();
      if (!pending.contains(entry.dateKey)) {
        pending.add(entry.dateKey);
        await _writePending(pending);
      }
    }
  }

  Future<bool> _tryPush(DailyEntry entry) async {
    try {
      await _db.setDocument('users/$_userSlug/entries/${entry.dateKey}', entry.toFields());
      connectionStatus.value = true;
      return true;
    } catch (_) {
      connectionStatus.value = false;
      return false;
    }
  }

  /// Attempts to push every locally-queued entry to Firestore. Safe to
  /// call often (app start, periodic timer, pull-to-refresh) — it's a
  /// no-op when the queue is empty or the network is still down.
  Future<void> syncPending() async {
    final pending = await _readPending();
    if (pending.isEmpty) return;
    final cache = await _readLocalCache();
    final stillPending = <String>[];
    for (final key in pending) {
      final entry = cache[key];
      if (entry == null) continue; // shouldn't happen, but be safe
      final pushed = await _tryPush(entry);
      if (!pushed) stillPending.add(key);
    }
    await _writePending(stillPending);
  }

  Future<int> pendingCount() async => (await _readPending()).length;

  /// Loads every locally-cached entry (used by the timeline), and kicks
  /// off a background refresh from Firestore so the cache stays current
  /// when online — but never blocks on the network.
  Future<Map<String, DailyEntry>> loadAll() async {
    final cache = await _readLocalCache();
    unawaited(_refreshFromCloud());
    return cache;
  }

  Future<Map<String, DailyEntry>> loadRange(DateTime start, DateTime end) async {
    final cache = await _readLocalCache();
    final result = <String, DailyEntry>{};
    for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      final key = DailyEntry(date: d).dateKey;
      if (cache.containsKey(key)) result[key] = cache[key]!;
    }
    return result;
  }

  /// Pulls the user's full entry list from Firestore and merges it into
  /// the local cache (cloud wins for keys not already pending a local
  /// push, so a fresh login on a new device picks up prior history).
  Future<void> _refreshFromCloud() async {
    try {
      final docs = await _db.listDocuments('users/$_userSlug/entries');
      connectionStatus.value = true;
      final pending = await _readPending();
      final cache = await _readLocalCache();
      docs.forEach((id, fields) {
        if (pending.contains(id)) return; // local unsynced edit wins
        cache[id] = DailyEntry.fromFields(_dateFromKey(id), fields);
      });
      await _writeLocalCache(cache);
    } catch (_) {
      connectionStatus.value = false;
    }
  }

  /// Cross-user average for a date range (Stats screen). Requires
  /// connectivity — there's no meaningful offline version of "everyone
  /// else's average". Fails quietly (returns {}) when offline.
  /// If [categoryId] is given alone, averages that whole category; if
  /// [itemId] is also given, averages just that one item.
  Future<Map<String, double?>> loadEveryoneAverages(
    DateTime start,
    DateTime end, {
    String? categoryId,
    String? itemId,
  }) async {
    try {
      final auth = AuthService();
      final slugs = await auth.allUserSlugs();
      final others = slugs.where((s) => s != _userSlug).toList();
      if (others.isEmpty) return {};

      final paths = <String>[];
      for (final slug in others) {
        for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
          paths.add('users/$slug/entries/${DailyEntry(date: d).dateKey}');
        }
      }
      final docs = await _db.batchGet(paths);
      connectionStatus.value = true;

      final byDate = <String, List<double>>{};
      docs.forEach((id, fields) {
        final entry = DailyEntry.fromFields(_dateFromKey(id), fields);
        final value = categoryId == null
            ? entry.overallAverage
            : (itemId != null
                ? entry.itemValue(categoryId, itemId)?.toDouble()
                : entry.categoryAverage(categoryId));
        if (value == null) return;
        byDate.putIfAbsent(id, () => []).add(value);
      });
      return byDate.map((date, vals) => MapEntry(
            date,
            vals.isEmpty ? null : vals.reduce((a, b) => a + b) / vals.length,
          ));
    } catch (_) {
      connectionStatus.value = false;
      return {};
    }
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

  /// 0 means "Never" (no auto-lock).
  Future<void> saveLockAfterMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lockAfterKey, minutes);
  }

  Future<int> loadLockAfterMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_lockAfterKey) ?? 0;
  }
}

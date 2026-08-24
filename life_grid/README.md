# Life Grid

A daily life-tracking app. Every day you rate 12 categories on a 5-stage
scale (Disaster / Bad / Neutral / Good / Wonderful), and the app gives you
weekly, monthly, seasonal, and yearly curves + averages, a ±90-day timeline
around any date you pick, and a daily local notification reminding you to
log the day.

Theme is matched to your **Grid Assistant** reference: near-black
background (`#050607`), bordered flat panels, mono font, green accent
(`#39D98A`), red danger (`#FF5D5D`), 4px radii, no drop shadows.

## Categories (edit freely)

`Today, Family, Friends, Coworkers, Work, Weather, Health, Mental, Mood,
Memory, Society, Luck` — defined in `lib/models/daily_entry.dart` as
`kCategoryKeys` / `kCategoryLabels`. Add, remove, or rename entries there;
every screen (entry form, stats, charts) reads from that list, so nothing
else needs to change.

## Setup

```bash
flutter pub get
flutter run
```

### Android — notification permissions

`android/app/src/main/AndroidManifest.xml` needs, inside `<manifest>`:

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
```

And inside `<application>`, register the exact-alarm receiver used by
`flutter_local_notifications` for reboot-persistent scheduling (see the
package's own README for the latest snippet, since Android's alarm APIs
change across versions).

### iOS

No extra setup beyond what `flutter_local_notifications` documents —
notification permission is requested at runtime from the Settings tab.

## Architecture

- `lib/models/daily_entry.dart` — the category list and the `DailyEntry`
  data model (1–5 rating per category + optional note).
- `lib/services/storage_service.dart` — persistence (SharedPreferences +
  JSON). Swap for sqflite/Hive later if entry volume grows.
- `lib/services/notification_service.dart` — schedules the daily repeating
  local notification via `flutter_local_notifications` + `timezone`.
- `lib/screens/entry_screen.dart` — today's (or any day's) rating form.
- `lib/screens/timeline_screen.dart` — pick a date, scroll ±90 days.
- `lib/screens/stats_screen.dart` — weekly/monthly/seasonal/yearly curves
  and averages, per-category or overall.
- `lib/screens/settings_screen.dart` — reminder time + on/off toggle.
- `lib/theme/app_theme.dart` — the Grid Assistant color/typography tokens.

## Notes on the field list

"Today" is kept as its own rated field (an overall gut-feel rating,
separate from the computed average of the other 11) per your spec — easy
to remove if you'd rather it just be the auto-computed daily average
shown in stats. "Memory," "Society," and "Luck" are kept as-is; all of
this is a one-line edit in `daily_entry.dart` if you want to swap any of
them for something else (e.g. Sleep, Finances, Creativity).

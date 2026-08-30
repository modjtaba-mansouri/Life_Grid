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

Defined in `lib/models/category_schema.dart` as `kBuiltInCategories`.
Users can also add their own from within the app (Settings → Parameters)
without touching code. See "What's new" below for the latest additions
(Intimacy, Practice, counter-style items).

## What's new since the last README update (this pass)

- **Journal tab** (between Timeline and Stats) — write freeform notes on
  any date, edit/delete them, and export everything as plain text
  (currently via clipboard copy — no extra file-sharing package added,
  to keep the build simple; paste into any notes app/email/doc).
- **Tutorial screen**, Settings → Help — explains what the app does and
  why, one section per feature.
- **Counter-style items** — some items (e.g. "Number of Urges") are a
  running tally entered with a +/- stepper instead of a 1-5 rating, and
  are deliberately excluded from every average/statistic.
- **New categories**: Intimacy (Sex, Urges, Sexual Feelings,
  Masturbation, plus counters for urges/masturbation), Practice (Sports,
  Playing Music, Painting, Calligraphy, Yoga).
- **Timeline coloring** is now relative to your personal average, not an
  absolute 1-5 scale: well below your average → red, below → orange,
  about the same → white/gray, above → light green, well above → dark
  green. Both the dot and the date text are colored.
- **Missing Android INTERNET permission fixed** — this was the real
  cause of persistent "failed host lookup" errors on the native Android
  build; Flutter only auto-grants that permission in debug builds, not
  release, so it had to be added explicitly in CI.

## What's new (earlier pass)

- **Offline-first.** Every save writes to an on-device cache immediately,
  so the app fully works with no internet. A background sync (every ~25s
  while open, plus on app resume) pushes anything queued to Firestore
  once connectivity is back. The HAL eye reflects live connection status,
  not whether you can use the app — you always can.
- **Light/dark theme**, toggle in Settings → Appearance.
- **Lock After**, in Settings → Security — re-locks the app with a
  passcode prompt after N minutes in the background. Works offline
  (checks against the passcode hash cached at login).
- **Category checkboxes**, Settings → Categories — hide/show any of the
  12 tracked fields without losing already-recorded data for them.
- **Today marker** on the Weekly/Monthly stats charts — a dashed line
  showing where "today" falls in the period.
- Footer credit line in Settings.

## Cloud setup (Firebase) — required before this app works

Multiple people now share this app: each person signs up with a name,
gender, birthday, and passcode, and Stats shows "your average" next to
"everyone's average." That needs a shared database. The app talks to
Firestore over plain HTTPS (no native SDK, no Android/iOS config, no
extra CLI tools) — you just need a project ID and an API key.

1. Go to https://console.firebase.google.com, sign in with a Google
   account, click **Add project**, name it anything (e.g. `life-grid`),
   and finish the wizard (you can decline Google Analytics).
2. In the left sidebar, click **Build → Firestore Database** → **Create
   database** → pick a location close to you → start in **test mode**
   for now (we'll tighten rules in step 5).
3. Click the gear icon (top left, next to "Project Overview") →
   **Project settings**. Under "Your apps", click the **</>** (web) icon
   to register a web app — you don't need to actually use their web
   SDK, this is just how Firebase issues you an API key. Give it any
   nickname and click **Register app**.
4. You'll see a code snippet with a `firebaseConfig` object. Copy the
   `projectId` and `apiKey` values into
   `lib/config/firebase_config.dart` in this project:
   ```dart
   class FirebaseConfig {
     static const projectId = 'paste-your-project-id-here';
     static const apiKey = 'paste-your-api-key-here';
   }
   ```
5. Back in **Firestore Database → Rules**, replace the rules with:
   ```
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /{document=**} {
         allow read, write: if true;
       }
     }
   }
   ```
   Click **Publish**. **Note on security:** this makes the database
   open to anyone who has your API key (which is visible inside the
   app itself — that's normal for Firebase web apps, but it does mean
   anyone technically inclined could read or write data if they got
   your key). Passcodes are hashed before being stored, so they can't
   be read back out, but entries and profile info (name, gender,
   birthday) are not encrypted. Fine for a small trusted group; if you
   ever want this locked down further, Firestore rules can be written
   to require proper authentication instead of `if true` — ask me if
   you want that upgrade later.
6. Commit the updated `firebase_config.dart` to your GitHub repo the
   same way as any other file edit, and the existing GitHub Actions
   pipeline rebuilds and redeploys automatically — nothing else
   changes.

## Setup (local build, if you have Flutter installed)


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

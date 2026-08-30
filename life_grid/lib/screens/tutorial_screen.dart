import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TutorialScreen extends StatelessWidget {
  const TutorialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('How Life Grid Works')),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          _section(
            'Why this app exists',
            'Most days blur together, and it\'s hard to tell, months later, whether '
                'things are actually getting better or worse in your life — or in which '
                'specific parts of it. Life Grid asks you a few quick questions each day '
                'and turns your answers into real statistics over time, so patterns show '
                'up instead of staying invisible.',
          ),
          _section(
            'Today',
            'Rate however many of the categories feel relevant to your day, on a '
                '5-stage scale from Disaster to Wonderful. You don\'t have to fill in '
                'everything — partial days still count. You can also revisit and edit '
                'any past day using the arrows or the date picker at the top.',
          ),
          _section(
            'Simple vs. Precise mode',
            'Simple mode gives you one rating per category — quick and low-effort. '
                'Precise mode breaks categories like Family or Workplace into specific '
                'sub-items (like "how they treated you" separately from "your own mood"), '
                'for a more detailed picture. Switch anytime in Settings → Parameters.',
          ),
          _section(
            'Categories & Items (Settings → Parameters)',
            'You\'re not stuck with the built-in list. Check or uncheck anything you '
                'don\'t want to track, drag to reorder, and add your own standalone items '
                '(a single flat rating) or whole new categories with their own sub-items. '
                'Built-in items can be hidden but not deleted; anything you add yourself '
                'can be removed too.',
          ),
          _section(
            'Timeline',
            'Pick any date and scroll through the 90 days before and after it. Each '
                'day is color-coded against your personal average, so you can spot '
                'stretches that were unusually good or rough at a glance.',
          ),
          _section(
            'Journal',
            'A dedicated space to actually write — a paragraph, a page, whatever you '
                'need — attached to any date. Separate from the daily ratings, this is '
                'for the context and detail numbers can\'t capture. Tap the + button to '
                'add an entry for any date via the calendar picker, edit or delete any '
                'existing one, and export everything as plain text (date-separated) from '
                'the share icon.',
          ),
          _section(
            'Stats',
            'Weekly, monthly, seasonal, and yearly views, with a curve for your ratings '
                'and — if others use this app too — a second line showing everyone\'s '
                'average for comparison. Pick any category or item from the dropdown to '
                'zoom into just that.',
          ),
          _section(
            'Foreseeing',
            'On today\'s entry, once you have enough history, you\'ll see a projected '
                'rating for today based on your recent trend — not a promise, just a '
                'nudge showing which direction things have been heading.',
          ),
          _section(
            'Works offline',
            'Everything is saved on your device first, so you can use the app with no '
                'internet at all. It quietly syncs to the cloud in the background once '
                'you\'re back online — nothing is lost either way.',
          ),
          _section(
            'Privacy & accounts',
            'Your data is tied to your account (name + passcode) and kept separate from '
                'everyone else\'s. Only aggregated, anonymous averages are ever shown '
                'when comparing against "everyone" in Stats. One category (Intimacy) is '
                'only visible to accounts with a birthday indicating 18 or older.',
          ),
          _section(
            'Locking the app',
            'The lock icon in the top-right corner instantly locks the app, requiring '
                'your passcode to get back in — tap it any time before handing your phone '
                'to someone else. Settings → Security → Lock After also auto-locks after '
                'a period of inactivity, and now applies on every fresh app launch too, '
                'not just when resuming from the background.',
          ),
          _section(
            'The glowing eye',
            'The HAL-9000-style eye at the top center shows whether the app is currently '
                'connected to the cloud (green) or not (red) — the app works fully either '
                'way, this is just informational.',
          ),
          SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _section(String title, String body) {
    return Padding(
      padding: EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(color: AppColors.accent, fontSize: 14, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(color: AppColors.textDim, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }
}

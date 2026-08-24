/// The 12 tracked life categories, each rated 1 (Disaster) to 5 (Wonderful).
/// Edit this list to add/remove/rename categories — the rest of the app
/// (entry form, stats, charts) is driven off it.
const List<String> kCategoryKeys = [
  'today', // overall feel of the day
  'family',
  'friends',
  'coworkers',
  'work',
  'weather',
  'health',
  'mental',
  'mood',
  'memory',
  'society',
  'luck',
];

const Map<String, String> kCategoryLabels = {
  'today': 'Today',
  'family': 'Family',
  'friends': 'Friends',
  'coworkers': 'Coworkers',
  'work': 'Work',
  'weather': 'Weather',
  'health': 'Health',
  'mental': 'Mental',
  'mood': 'Mood',
  'memory': 'Memory',
  'society': 'Society',
  'luck': 'Luck',
};

/// One day's ratings. Missing categories mean "not entered" (null),
/// distinct from a real rating, so averages/charts can skip gaps.
class DailyEntry {
  final DateTime date; // stored at midnight, local time
  final Map<String, int?> ratings; // category key -> 1..5 or null
  final String note;

  DailyEntry({required this.date, Map<String, int?>? ratings, this.note = ''})
      : ratings = ratings ?? {for (final k in kCategoryKeys) k: null};

  String get dateKey =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  /// Average of all entered ratings for the day (null if none entered).
  double? get overallAverage {
    final vals = ratings.values.whereType<int>().toList();
    if (vals.isEmpty) return null;
    return vals.reduce((a, b) => a + b) / vals.length;
  }

  bool get isEmpty => ratings.values.every((v) => v == null) && note.isEmpty;

  DailyEntry copyWith({Map<String, int?>? ratings, String? note}) {
    return DailyEntry(
      date: date,
      ratings: ratings ?? Map.of(this.ratings),
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() => {
        'date': dateKey,
        'ratings': ratings,
        'note': note,
      };

  factory DailyEntry.fromJson(Map<String, dynamic> json) {
    final parts = (json['date'] as String).split('-');
    final date = DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
    final rawRatings = Map<String, dynamic>.from(json['ratings'] ?? {});
    final ratings = <String, int?>{
      for (final k in kCategoryKeys) k: rawRatings[k] as int?,
    };
    return DailyEntry(date: date, ratings: ratings, note: json['note'] ?? '');
  }
}

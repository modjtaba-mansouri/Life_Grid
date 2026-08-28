/// One day's ratings, organized as category id -> item id -> rating
/// (1..5, or absent if not entered). A "solo" category (no sub-items,
/// e.g. Mood) stores its single rating under itemId == categoryId. A
/// category with items stores either one rating under itemId ==
/// categoryId (Simple mode) or several real item ids (Precise mode).
class DailyEntry {
  final DateTime date;
  final Map<String, Map<String, int>> ratings; // categoryId -> itemId -> 1..5
  final String note;
  final String? educationEnvironment; // 'School' | 'College' | 'University'

  DailyEntry({
    required this.date,
    Map<String, Map<String, int>>? ratings,
    this.note = '',
    this.educationEnvironment,
  }) : ratings = ratings ?? {};

  String get dateKey =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  /// Every individual rating entered that day, across all categories.
  List<int> get allValues => ratings.values.expand((m) => m.values).toList();

  /// Average of every rating entered that day (null if none entered).
  double? get overallAverage {
    final vals = allValues;
    if (vals.isEmpty) return null;
    return vals.reduce((a, b) => a + b) / vals.length;
  }

  /// Average within one category (across whichever items are recorded).
  double? categoryAverage(String categoryId) {
    final items = ratings[categoryId];
    if (items == null || items.isEmpty) return null;
    return items.values.reduce((a, b) => a + b) / items.length;
  }

  int? itemValue(String categoryId, String itemId) => ratings[categoryId]?[itemId];

  bool get isEmpty => ratings.values.every((m) => m.isEmpty) && note.isEmpty;

  DailyEntry copyWith({
    Map<String, Map<String, int>>? ratings,
    String? note,
    String? educationEnvironment,
  }) {
    return DailyEntry(
      date: date,
      ratings: ratings ?? {for (final e in this.ratings.entries) e.key: Map.of(e.value)},
      note: note ?? this.note,
      educationEnvironment: educationEnvironment ?? this.educationEnvironment,
    );
  }

  /// Returns a copy with one (category, item) rating set.
  DailyEntry withRating(String categoryId, String itemId, int value) {
    final updated = {for (final e in ratings.entries) e.key: Map<String, int>.of(e.value)};
    updated.putIfAbsent(categoryId, () => {})[itemId] = value;
    return copyWith(ratings: updated);
  }

  Map<String, dynamic> toFields() => {
        'date': dateKey,
        'note': note,
        if (educationEnvironment != null) 'educationEnvironment': educationEnvironment,
        'ratings': ratings.map((catId, items) => MapEntry(catId, items)),
      };

  factory DailyEntry.fromFields(DateTime date, Map<String, dynamic> fields) {
    final rawRatings = Map<String, dynamic>.from(fields['ratings'] ?? {});
    final ratings = rawRatings.map((catId, items) {
      final itemsMap = Map<String, dynamic>.from(items ?? {});
      return MapEntry(
        catId,
        itemsMap.map((itemId, v) => MapEntry(itemId, (v as num).toInt())),
      );
    });
    return DailyEntry(
      date: date,
      ratings: ratings,
      note: fields['note'] ?? '',
      educationEnvironment: fields['educationEnvironment'] as String?,
    );
  }
}

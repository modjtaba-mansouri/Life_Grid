import '../models/daily_entry.dart';

/// Result of a forecast: the projected rating for "today" plus enough
/// context to explain it (how many days of real data it's based on, and
/// the trend direction).
class Forecast {
  final double? projected; // 1..5, null if not enough data
  final int daysUsed;
  final double slope; // change per day; >0 improving, <0 declining

  Forecast({required this.projected, required this.daysUsed, required this.slope});

  String get trendLabel {
    if (projected == null) return 'Not enough data yet';
    if (slope > 0.03) return 'Trending up';
    if (slope < -0.03) return 'Trending down';
    return 'Holding steady';
  }
}

/// Projects today's likely rating from the last [lookbackDays] of history,
/// using simple linear regression over each day's value (overall average,
/// or a single category if [categoryKey] is given). This is a lightweight
/// trend estimate, not a statistical guarantee — it's meant to give a
/// "here's roughly where things are heading" nudge, not a hard prediction.
Forecast computeForecast({
  required Map<String, DailyEntry> entries,
  required DateTime today,
  required int lookbackDays,
  String? categoryKey,
}) {
  final points = <(int x, double y)>[]; // x = days before today, y = value
  for (var i = 1; i <= lookbackDays; i++) {
    final day = DateTime(today.year, today.month, today.day - i);
    final entry = entries[DailyEntry(date: day).dateKey];
    if (entry == null) continue;
    final value = categoryKey == null
        ? entry.overallAverage
        : entry.ratings[categoryKey]?.toDouble();
    if (value == null) continue;
    points.add((-i, value)); // negative so more-recent days have larger x
  }

  if (points.length < 3) {
    return Forecast(projected: null, daysUsed: points.length, slope: 0);
  }

  // Ordinary least squares over (x, y).
  final n = points.length;
  final sumX = points.fold<double>(0, (a, p) => a + p.$1);
  final sumY = points.fold<double>(0, (a, p) => a + p.$2);
  final sumXY = points.fold<double>(0, (a, p) => a + p.$1 * p.$2);
  final sumXX = points.fold<double>(0, (a, p) => a + p.$1 * p.$1);

  final denom = n * sumXX - sumX * sumX;
  final slope = denom == 0 ? 0.0 : (n * sumXY - sumX * sumY) / denom;
  final intercept = (sumY - slope * sumX) / n;

  // Project to x = 0 (today).
  final projectedRaw = intercept + slope * 0;
  final projected = projectedRaw.clamp(1.0, 5.0);

  return Forecast(projected: projected, daysUsed: n, slope: slope);
}

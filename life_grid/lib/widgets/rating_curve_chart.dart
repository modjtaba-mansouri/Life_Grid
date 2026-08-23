import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Renders a smooth (curved) line of average ratings over a series of
/// periods (e.g. days in a week, weeks in a month, months in a year).
class RatingCurveChart extends StatelessWidget {
  final List<String> xLabels;
  final List<double?> values; // 1..5 scale, null = no data for that period
  final double height;

  const RatingCurveChart({
    super.key,
    required this.xLabels,
    required this.values,
    this.height = 220,
  });

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      if (v != null) spots.add(FlSpot(i.toDouble(), v));
    }

    if (spots.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text(
            'No data yet for this period.',
            style: TextStyle(color: AppColors.textDim, fontSize: 12),
          ),
        ),
      );
    }

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: 1,
          maxY: 5,
          gridData: FlGridData(
            show: true,
            horizontalInterval: 1,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: AppColors.border, strokeWidth: 1),
            drawVerticalLine: false,
          ),
          borderData: FlBorderData(
            show: true,
            border: const Border(
              bottom: BorderSide(color: AppColors.border),
              left: BorderSide(color: AppColors.border),
            ),
          ),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: 1,
                getTitlesWidget: (v, meta) => Text(
                  v.toInt().toString(),
                  style: const TextStyle(
                    color: AppColors.textDim,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                getTitlesWidget: (v, meta) {
                  final i = v.toInt();
                  if (i < 0 || i >= xLabels.length) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      xLabels[i],
                      style: const TextStyle(
                        color: AppColors.textDim,
                        fontSize: 9,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true, // the "parabola-like" smooth curve
              curveSmoothness: 0.3,
              color: AppColors.accent,
              barWidth: 2.5,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, bar, index) =>
                    FlDotCirclePainter(
                  radius: 3,
                  color: AppColors.accent,
                  strokeWidth: 0,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.accentSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

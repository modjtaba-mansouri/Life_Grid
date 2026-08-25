import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Renders one or two smooth curves of ratings over a series of periods.
/// [values] is the current user's line (accent green). [othersValues],
/// if given, overlays everyone else's average as a muted second line.
class RatingCurveChart extends StatelessWidget {
  final List<String> xLabels;
  final List<double?> values;
  final List<double?>? othersValues;
  final double height;

  const RatingCurveChart({
    super.key,
    required this.xLabels,
    required this.values,
    this.othersValues,
    this.height = 220,
  });

  List<FlSpot> _spotsFor(List<double?> vals) {
    final spots = <FlSpot>[];
    for (var i = 0; i < vals.length; i++) {
      final v = vals[i];
      if (v != null) spots.add(FlSpot(i.toDouble(), v));
    }
    return spots;
  }

  @override
  Widget build(BuildContext context) {
    final mySpots = _spotsFor(values);
    final otherSpots = othersValues != null ? _spotsFor(othersValues!) : <FlSpot>[];

    if (mySpots.isEmpty && otherSpots.isEmpty) {
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (othersValues != null) ...[
          Row(
            children: [
              _LegendDot(color: AppColors.accent, label: 'You'),
              const SizedBox(width: 14),
              const _LegendDot(color: Color(0xFF6B8FA3), label: 'Everyone'),
            ],
          ),
          const SizedBox(height: 8),
        ],
        SizedBox(
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
                  spots: mySpots,
                  isCurved: true,
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
                    show: othersValues == null,
                    color: AppColors.accentSoft,
                  ),
                ),
                if (otherSpots.isNotEmpty)
                  LineChartBarData(
                    spots: otherSpots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: const Color(0xFF6B8FA3),
                    barWidth: 2,
                    dashArray: [6, 4],
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: false),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
      ],
    );
  }
}

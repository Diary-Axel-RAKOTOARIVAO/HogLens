import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/util/format.dart';
import '../../data/models/stats.dart';

/// Area line chart used for the main events series and trend widgets.
class TrendChart extends StatelessWidget {
  const TrendChart({
    super.key,
    required this.points,
    required this.color,
    this.height = 160,
    this.showAxis = true,
    this.hourly = false,
    this.bare = false,
  });

  final List<SeriesPoint> points;
  final Color color;
  final double height;
  final bool showAxis;
  final bool hourly;

  /// No grid, no axis, no padding: the line touches the card edges.
  final bool bare;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (points.isEmpty) {
      return SizedBox(height: height, child: Center(child: Text('No data', style: TextStyle(color: c.textFaint))));
    }
    final spots = [for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].v.toDouble())];
    final maxY = points.map((p) => p.v.toDouble()).fold<double>(0, (a, b) => a > b ? a : b);
    final labelEvery = (points.length / 4).ceil().clamp(1, 999);

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY == 0 ? 1 : maxY * 1.15,
          clipData: const FlClipData.none(),
          gridData: FlGridData(
            show: showAxis && !bare,
            drawVerticalLine: false,
            horizontalInterval: maxY == 0 ? 1 : maxY / 2,
            getDrawingHorizontalLine: (_) => FlLine(color: c.gridLine, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            topTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: showAxis && !bare,
                reservedSize: 22,
                interval: 1,
                getTitlesWidget: (v, meta) {
                  final i = v.toInt();
                  if (i < 0 || i >= points.length || i % labelEvery != 0) return const SizedBox.shrink();
                  final t = points[i].t;
                  return SideTitleWidget(
                    meta: meta,
                    fitInside: SideTitleFitInsideData.fromTitleMeta(meta, distanceFromEdge: 0),
                    child: Text(
                      hourly ? Fmt.hour(t) : Fmt.monthDay(t),
                      style: TextStyle(fontSize: 10.5, color: c.textFaint),
                    ),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => c.text,
              tooltipBorderRadius: BorderRadius.circular(8),
              fitInsideHorizontally: true,
              getTooltipItems: (spots) => spots
                  .map((s) => LineTooltipItem(
                        '${Fmt.full(s.y)}\n',
                        TextStyle(color: c.bg, fontWeight: FontWeight.w600, fontSize: 12),
                        children: [
                          TextSpan(
                            text: hourly ? Fmt.hour(points[s.x.toInt()].t) : Fmt.monthDay(points[s.x.toInt()].t),
                            style: TextStyle(color: c.bg.withValues(alpha: 0.7), fontWeight: FontWeight.w400, fontSize: 11),
                          ),
                        ],
                      ))
                  .toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              preventCurveOverShooting: true,
              color: color,
              barWidth: bare ? 3 : 2.2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [color.withValues(alpha: bare ? 0.35 : 0.22), color.withValues(alpha: 0.0)],
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 300),
      ),
    );
  }
}

/// Horizontal proportional bars for label/value rows.
class BarList extends StatelessWidget {
  const BarList({super.key, required this.rows, required this.color, this.maxRows = 8});
  final List<(String, num)> rows;
  final Color color;
  final int maxRows;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (rows.isEmpty) return Text('No data', style: TextStyle(color: c.textFaint));
    final max = rows.map((r) => r.$2.toDouble()).fold<double>(0, (a, b) => a > b ? a : b);
    final shown = rows.take(maxRows).toList();
    return Column(
      children: [
        for (var i = 0; i < shown.length; i++) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  shown[i].$1,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                Fmt.compact(shown[i].$2),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: c.text,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: max == 0 ? 0 : shown[i].$2 / max,
              minHeight: 8,
              backgroundColor: c.surfaceRaised,
              color: i == 0 ? color : color.withValues(alpha: 0.45),
            ),
          ),
          if (i != shown.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

/// Tiny column chart. The last column is highlighted in [color].
class MiniBars extends StatelessWidget {
  const MiniBars({super.key, required this.values, required this.color, this.height = 56, this.gap = 4});
  final List<num> values;
  final Color color;
  final double height;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final max = values.fold<double>(0, (a, b) => b > a ? b.toDouble() : a);
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++) ...[
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                height: max == 0 ? 4 : (4 + (height - 4) * values[i] / max),
                decoration: BoxDecoration(
                  color: i == values.length - 1 ? color : color.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            if (i != values.length - 1) SizedBox(width: gap),
          ],
          if (values.isEmpty) Expanded(child: Container(height: 4, color: c.surfaceRaised)),
        ],
      ),
    );
  }
}

/// 24 cells shaded by intensity, one per hour.
class HeatStrip extends StatelessWidget {
  const HeatStrip({super.key, required this.points, required this.color, this.compact = false});
  final List<SeriesPoint> points;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final max = points.fold<double>(0, (a, p) => p.v > a ? p.v.toDouble() : a);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: compact ? 22 : 28,
          child: Row(
            children: [
              for (var i = 0; i < points.length; i++) ...[
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: max == 0
                          ? c.surfaceRaised
                          : Color.lerp(c.surfaceRaised, color, math.pow(points[i].v / max, 1.8).toDouble().clamp(0.06, 1.0)),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                if (i != points.length - 1) const SizedBox(width: 2),
              ],
            ],
          ),
        ),
        if (points.isNotEmpty && !compact) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(Fmt.hour(points.first.t), style: TextStyle(fontSize: 11, color: c.textFaint)),
              Text('now', style: TextStyle(fontSize: 11, color: c.textFaint)),
            ],
          ),
        ],
      ],
    );
  }
}

/// Ranked list with position numbers, share of total and fading bars.
class RankedBars extends StatelessWidget {
  const RankedBars({super.key, required this.rows, required this.color, this.maxRows = 8, this.onTap});
  final List<(String, num)> rows;
  final Color color;
  final int maxRows;
  final ValueChanged<String>? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (rows.isEmpty) return Text('No data', style: TextStyle(color: c.textFaint));
    final total = rows.fold<double>(0, (a, r) => a + r.$2);
    final max = rows.map((r) => r.$2.toDouble()).fold<double>(0, (a, b) => a > b ? a : b);
    final shown = rows.take(maxRows).toList();
    return Column(
      children: [
        for (var i = 0; i < shown.length; i++) ...[
          InkWell(
            onTap: onTap == null ? null : () => onTap!(shown[i].$1),
            borderRadius: BorderRadius.circular(8),
            child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  (i + 1).toString().padLeft(2, '0'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: c.textFaint,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  shown[i].$1,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                total == 0 ? '' : '${(shown[i].$2 / total * 100).toStringAsFixed(shown[i].$2 / total < 0.1 ? 1 : 0)}%',
                style: TextStyle(fontSize: 13, color: c.textMuted, fontFeatures: const [FontFeature.tabularFigures()]),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 54,
                child: Text(
                  Fmt.compact(shown[i].$2),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: c.text,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 6),
                Icon(Icons.chevron_right, size: 16, color: c.textFaint),
              ],
            ],
          ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: max == 0 ? 0 : shown[i].$2 / max,
                minHeight: 6,
                backgroundColor: c.surfaceRaised,
                color: color.withValues(alpha: (1 - i * 0.11).clamp(0.3, 1.0)),
              ),
            ),
          ),
          if (i != shown.length - 1) const SizedBox(height: 14),
        ],
      ],
    );
  }
}

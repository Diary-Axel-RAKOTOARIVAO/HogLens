import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../core/i18n.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/util/format.dart';
import '../../data/models/insights.dart';
import '../../data/providers/providers.dart';
import '../../shared/ui.dart';
import 'sankey.dart';

/// Lifecycle, weekly retention and navigation paths, all from PostHog's
/// own insight engine.
class BehaviorScreen extends ConsumerWidget {
  const BehaviorScreen({super.key, required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final project = ref.watch(projectProvider(projectId));
    final accent = project?.accent ?? c.text;
    final lifecycle = ref.watch(lifecycleProvider(projectId));
    final retention = ref.watch(retentionProvider(projectId));
    final paths = ref.watch(pathsProvider(projectId));
    final range = ref.watch(rangeProvider).resolve(DateTime.now());

    Future<void> refresh() async {
      ref.invalidate(lifecycleProvider(projectId));
      ref.invalidate(retentionProvider(projectId));
      ref.invalidate(pathsProvider(projectId));
      try {
        await Future.wait([
          ref.read(lifecycleProvider(projectId).future),
          ref.read(retentionProvider(projectId).future),
          ref.read(pathsProvider(projectId).future),
        ]);
      } catch (_) {}
    }

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 76,
        leading: Padding(
          padding: const EdgeInsets.only(left: Spacing.page),
          child: Center(child: IconCircleButton(icon: SolarIconsOutline.altArrowLeft, onTap: () => context.pop())),
        ),
        titleSpacing: 12,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tr('Behavior')),
            Text(range.kind.name == 'thisMonth' || range.kind.name == 'custom' || range.kind.name == 'today' ? range.label : '${tr('Last')} ${range.label}',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: c.textMuted)),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(Spacing.page, 4, Spacing.page, 40),
          children: [
            Card1(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CardLabel(tr('User lifecycle'), icon: SolarIconsOutline.usersGroupRounded),
                  const SizedBox(height: 4),
                  Text(tr('Who was new, back again, returning after a break, or gone quiet.'), style: TextStyle(fontSize: 12.5, color: c.textMuted)),
                  const SizedBox(height: 16),
                  lifecycle.when(
                    skipLoadingOnRefresh: true,
                    loading: () => const Skeleton(height: 200, radius: 12),
                    error: (e, _) => ErrorCard(message: '$e', onRetry: refresh),
                    data: (r) => _LifecycleChart(report: r, accent: accent),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms),
            const SizedBox(height: Spacing.gap),
            Card1(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CardLabel(tr('Weekly retention'), icon: SolarIconsOutline.calendar),
                  const SizedBox(height: 4),
                  Text(tr('Of the people first seen each week, how many came back in later weeks.'), style: TextStyle(fontSize: 12.5, color: c.textMuted)),
                  const SizedBox(height: 16),
                  retention.when(
                    skipLoadingOnRefresh: true,
                    loading: () => const Skeleton(height: 220, radius: 12),
                    error: (e, _) => ErrorCard(message: '$e', onRetry: refresh),
                    data: (r) => _RetentionGrid(report: r, accent: accent),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms, delay: 60.ms),
            const SizedBox(height: Spacing.gap),
            Card1(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CardLabel(tr('Navigation paths'), icon: SolarIconsOutline.routing),
                  const SizedBox(height: 4),
                  Text(tr('The most common page-to-page journeys, up to four steps.'), style: TextStyle(fontSize: 12.5, color: c.textMuted)),
                  const SizedBox(height: 16),
                  paths.when(
                    skipLoadingOnRefresh: true,
                    loading: () => const Skeleton(height: 260, radius: 12),
                    error: (e, _) => ErrorCard(message: '$e', onRetry: refresh),
                    data: (r) => r.links.isEmpty
                        ? Text(tr('No journeys in this window.'), style: TextStyle(color: c.textFaint))
                        : SankeyChart(links: r.links, accent: accent, height: 280),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms, delay: 120.ms),
          ],
        ),
      ),
    );
  }
}

class _LifecycleChart extends StatelessWidget {
  const _LifecycleChart({required this.report, required this.accent});
  final LifecycleReport report;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final colors = {'new': accent, 'returning': c.positive, 'resurrecting': const Color(0xFFF59E0B), 'dormant': c.negative};
    final n = report.days.length;
    if (n == 0) return Text('No data', style: TextStyle(color: c.textFaint));
    num pos(int i) => ['new', 'returning', 'resurrecting'].fold<num>(0, (a, s) => a + ((report.series[s] ?? const [])[i < (report.series[s]?.length ?? 0) ? i : 0]));
    num dor(int i) => (report.series['dormant'] ?? const []).length > i ? report.series['dormant']![i] : 0;
    final maxPos = [for (var i = 0; i < n; i++) pos(i)].fold<double>(0, (a, b) => b > a ? b.toDouble() : a);
    final maxDor = [for (var i = 0; i < n; i++) dor(i)].fold<double>(0, (a, b) => b > a ? b.toDouble() : a);
    final labelEvery = (n / 4).ceil().clamp(1, 999);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              maxY: maxPos == 0 ? 1 : maxPos * 1.1,
              minY: maxDor == 0 ? 0 : -maxDor * 1.1,
              alignment: BarChartAlignment.spaceBetween,
              gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: maxPos == 0 ? 1 : maxPos / 2, getDrawingHorizontalLine: (_) => FlLine(color: c.gridLine, strokeWidth: 1)),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                topTitles: const AxisTitles(),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    getTitlesWidget: (v, meta) {
                      final i = v.toInt();
                      if (i < 0 || i >= n || i % labelEvery != 0) return const SizedBox.shrink();
                      return SideTitleWidget(meta: meta, fitInside: SideTitleFitInsideData.fromTitleMeta(meta, distanceFromEdge: 0), child: Text(Fmt.monthDay(report.days[i]), style: TextStyle(fontSize: 10.5, color: c.textFaint)));
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => c.text,
                  getTooltipItem: (group, gi, rod, ri) {
                    final i = group.x;
                    final parts = [for (final s in LifecycleReport.statuses) '${s[0].toUpperCase()}${s.substring(1)} ${Fmt.full((report.series[s] ?? const []).length > i ? report.series[s]![i] : 0)}'];
                    return BarTooltipItem('${Fmt.monthDay(report.days[i])}\n${parts.join('\n')}', TextStyle(color: c.bg, fontSize: 11, height: 1.4));
                  },
                ),
              ),
              barGroups: [
                for (var i = 0; i < n; i++)
                  BarChartGroupData(
                    x: i,
                    barsSpace: 0,
                    barRods: [
                      BarChartRodData(
                        fromY: 0,
                        toY: pos(i).toDouble(),
                        width: (260 / n).clamp(4, 14),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                        rodStackItems: _stack(i, colors),
                      ),
                      BarChartRodData(
                        fromY: -dor(i).toDouble(),
                        toY: 0,
                        width: (260 / n).clamp(4, 14),
                        color: colors['dormant'],
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(3)),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            for (final s in LifecycleReport.statuses)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: colors[s], shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Text('${tr('${s[0].toUpperCase()}${s.substring(1)}')} · ${Fmt.compact(report.total(s))}', style: TextStyle(fontSize: 12, color: c.textMuted)),
                ],
              ),
          ],
        ),
      ],
    );
  }

  List<BarChartRodStackItem> _stack(int i, Map<String, Color> colors) {
    final items = <BarChartRodStackItem>[];
    double from = 0;
    for (final s in ['new', 'returning', 'resurrecting']) {
      final list = report.series[s] ?? const [];
      final v = (list.length > i ? list[i] : 0).toDouble();
      items.add(BarChartRodStackItem(from, from + v, colors[s]!));
      from += v;
    }
    return items;
  }
}

class _RetentionGrid extends StatelessWidget {
  const _RetentionGrid({required this.report, required this.accent});
  final RetentionReport report;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (report.cohorts.isEmpty) return Text('No cohorts yet', style: TextStyle(color: c.textFaint));
    final cols = report.periods.clamp(1, 7);
    return Column(
      children: [
        Row(
          children: [
            SizedBox(width: 58, child: Text(tr('Cohort'), style: TextStyle(fontSize: 11, color: c.textFaint))),
            for (var w = 0; w < cols; w++)
              Expanded(child: Text(w == 0 ? tr('Size') : '${currentLanguage == AppLanguage.fr ? 'S' : 'W'}$w', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: c.textFaint))),
          ],
        ),
        const SizedBox(height: 6),
        for (final cohort in report.cohorts) ...[
          Row(
            children: [
              SizedBox(width: 58, child: Text(Fmt.monthDay(cohort.start), style: TextStyle(fontSize: 11.5, color: c.textMuted, fontFeatures: const [FontFeature.tabularFigures()]))),
              for (var w = 0; w < cols; w++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Builder(builder: (context) {
                      final rate = cohort.rate(w);
                      if (rate == null) return const SizedBox(height: 30);
                      final t = w == 0 ? 1.0 : rate.clamp(0.0, 1.0);
                      final bg = w == 0 ? c.text : Color.lerp(c.surfaceRaised, accent, (0.15 + 0.85 * t).clamp(0, 1))!;
                      final fg = w == 0 || t > 0.45 ? c.bg : c.text;
                      return Container(
                        height: 30,
                        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7)),
                        alignment: Alignment.center,
                        child: Text(
                          w == 0 ? Fmt.compact(cohort.size) : '${(rate * 100).round()}%',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg, fontFeatures: const [FontFeature.tabularFigures()]),
                        ),
                      );
                    }),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

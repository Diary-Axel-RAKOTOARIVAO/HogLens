import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/util/format.dart';
import '../../data/models/project.dart';
import '../../data/models/stats.dart';
import '../../data/providers/providers.dart';
import '../../shared/ui.dart';
import '../widgets/custom_widget_tile.dart';
import '../widgets/widget_builder_sheet.dart';
import 'charts.dart';

const _tileHeight = 236.0;

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key, required this.projectId});
  final String projectId;

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _editing = false;

  Future<void> _refresh() async {
    ref.invalidate(keyStatsProvider(widget.projectId));
    for (final w in ref.read(projectWidgetsProvider(widget.projectId))) {
      ref.invalidate(widgetResultProvider((widget.projectId, w.id)));
    }
    try {
      await ref.read(keyStatsProvider(widget.projectId).future);
    } catch (_) {
      // Error surfaces in the UI via the provider state.
    }
  }

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(projectProvider(widget.projectId));
    if (project == null) return const Scaffold();
    final c = context.colors;
    final range = ref.watch(rangeProvider);
    final stats = ref.watch(keyStatsProvider(widget.projectId));
    final widgets = ref.watch(projectWidgetsProvider(widget.projectId));

    return Scaffold(
      floatingActionButton: PillFab(
        label: 'Add widget',
        icon: SolarIconsOutline.addCircle,
        color: project.accentIndex == Accents.all.length - 1 ? null : project.accent,
        onTap: () => showWidgetBuilder(context, projectId: project.id),
      ),
      body: RefreshIndicator(
        color: project.accent,
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            SliverAppBar(
              pinned: true,
              leadingWidth: 76,
              leading: Padding(
                padding: const EdgeInsets.only(left: Spacing.page),
                child: Center(
                  child: IconCircleButton(icon: SolarIconsOutline.altArrowLeft, onTap: () => context.pop()),
                ),
              ),
              titleSpacing: 12,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(project.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    '${project.hostLabel} · #${project.projectId}',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: c.textMuted),
                  ),
                ],
              ),
              actions: [
                IconCircleButton(
                  icon: SolarIconsOutline.flag,
                  tooltip: 'Feature flags',
                  onTap: () => context.push('/p/${project.id}/flags'),
                ),
                const SizedBox(width: 10),
                IconCircleButton(
                  icon: SolarIconsOutline.settings,
                  tooltip: 'Settings',
                  onTap: () => context.push('/p/${project.id}/settings'),
                ),
                const SizedBox(width: Spacing.page),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(Spacing.page, 8, Spacing.page, 110),
              sliver: SliverList.list(
                children: [
                  _RangeBar(range: range, activeNow: stats.value?.activeNow),
                  const SizedBox(height: 16),
                  stats.when(
                    skipLoadingOnRefresh: true,
                    data: (s) => _KeyStats(stats: s, project: project, range: range),
                    loading: () => const _KeyStatsSkeleton(),
                    error: (e, _) => ErrorCard(message: '$e', onRetry: _refresh),
                  ),
                  const SizedBox(height: Spacing.section),
                  SectionHeader(
                    'Custom widgets',
                    trailing: widgets.isEmpty
                        ? null
                        : TextButton(
                            onPressed: () => setState(() => _editing = !_editing),
                            child: Text(_editing ? 'Done' : 'Edit'),
                          ),
                  ),
                  if (widgets.isEmpty)
                    Card1(
                      onTap: () => showWidgetBuilder(context, projectId: project.id),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: project.accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(SolarIconsOutline.widgetAdd, color: project.accent, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Track anything', style: Theme.of(context).textTheme.titleMedium),
                                const SizedBox(height: 3),
                                Text(
                                  'Any HogQL query as a number, trend, bars or table.',
                                  style: TextStyle(color: c.textMuted, fontSize: 14, height: 1.35),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    CustomWidgetGrid(projectId: project.id, editing: _editing),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RangeBar extends ConsumerWidget {
  const _RangeBar({required this.range, this.activeNow});
  final StatRange range;
  final num? activeNow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.chip)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final r in StatRange.values)
                GestureDetector(
                  onTap: () => ref.read(rangeProvider.notifier).set(r),
                  child: AnimatedContainer(
                    duration: 180.ms,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    decoration: BoxDecoration(
                      color: r == range ? c.text : Colors.transparent,
                      borderRadius: BorderRadius.circular(Radii.chip),
                    ),
                    child: Text(
                      r.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: r == range ? c.bg : c.textMuted,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Spacer(),
        if (activeNow != null)
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: c.positive, shape: BoxShape.circle))
                  .animate(onPlay: (ctl) => ctl.repeat(reverse: true))
                  .fade(begin: 0.4, end: 1, duration: 900.ms),
              const SizedBox(width: 8),
              Text(
                '${Fmt.full(activeNow)} live',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textMuted),
              ),
            ],
          ),
      ],
    );
  }
}

class _KeyStats extends StatelessWidget {
  const _KeyStats({required this.stats, required this.project, required this.range});
  final KeyStats stats;
  final PhProject project;
  final StatRange range;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final start = DateTime.now().subtract(Duration(days: range.days - 1));
    final end = DateTime.now();
    final rangeLabel = range == StatRange.day ? 'Last 24 hours' : '${Fmt.monthDay(start)} – ${Fmt.monthDay(end)}';
    final peak = stats.hourlySeries.isEmpty
        ? null
        : stats.hourlySeries.reduce((a, b) => b.v > a.v ? b : a);
    final sessions = stats.sessions.current;
    final users = stats.users.current;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeroCard(stats: stats, project: project, range: range).animate().fadeIn(duration: 300.ms),
        const SizedBox(height: Spacing.gap),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Tile(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CardLabel('Active users', icon: SolarIconsOutline.usersGroupRounded),
                    const SizedBox(height: 14),
                    BigValue(Fmt.compact(users)),
                    const SizedBox(height: 4),
                    _DeltaLine(stats.users.delta, suffix: 'vs previous'),
                    const Spacer(),
                    MiniBars(values: stats.userSeries.map((p) => p.v).toList(), color: project.accent),
                    const SizedBox(height: 8),
                    Text(
                      range.bucket == 'hour' ? 'Per hour' : 'Per day',
                      style: TextStyle(color: c.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: Spacing.gap),
            Expanded(
              child: _Tile(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CardLabel('Live pulse', icon: SolarIconsOutline.pulse),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        BigValue(Fmt.full(stats.activeNow)),
                        const SizedBox(width: 8),
                        Text('on site', style: TextStyle(color: c.textMuted, fontSize: 15)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Last 5 minutes', style: TextStyle(color: c.textMuted, fontSize: 14)),
                    const Spacer(),
                    HeatStrip(points: stats.hourlySeries, color: project.accent),
                    const SizedBox(height: 6),
                    Text(
                      peak == null ? 'No activity in 24h' : 'Peak ${Fmt.hour(peak.t)} · ${Fmt.compact(peak.v)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ).animate().fadeIn(duration: 300.ms, delay: 60.ms),
        const SizedBox(height: Spacing.gap),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Tile(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CardLabel('Sessions', icon: SolarIconsOutline.cursor),
                    const SizedBox(height: 14),
                    BigValue(Fmt.compact(sessions)),
                    const SizedBox(height: 4),
                    _DeltaLine(stats.sessions.delta, suffix: 'vs previous'),
                    const Spacer(),
                    KeyValueRow('Events / session', sessions == 0 ? '—' : (stats.events.current / sessions).toStringAsFixed(1)),
                    KeyValueRow('Pages / session', sessions == 0 ? '—' : (stats.pageviews.current / sessions).toStringAsFixed(1)),
                    KeyValueRow('Sessions / user', users == 0 ? '—' : (sessions / users).toStringAsFixed(1)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: Spacing.gap),
            Expanded(
              child: _Tile(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CardLabel('Trends · ${range.label}', icon: SolarIconsOutline.graphUp),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _TrendRow('Events', stats.events),
                          _TrendRow('Users', stats.users),
                          _TrendRow('Pageviews', stats.pageviews),
                          _TrendRow('Sessions', stats.sessions),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ).animate().fadeIn(duration: 300.ms, delay: 120.ms),
        const SizedBox(height: Spacing.gap),
        Card1(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CardLabel(rangeLabel, icon: SolarIconsOutline.calendar),
              const SizedBox(height: 14),
              Text('Top events', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 28)),
              const SizedBox(height: 6),
              Text(
                stats.topEvents.isEmpty
                    ? 'No events were captured in this range.'
                    : '${stats.topEvents.length} event types, ${Fmt.compact(stats.events.current)} events in total. '
                        '${stats.topEvents.first.name} leads with '
                        '${stats.totalTop == 0 ? '' : '${(stats.topEvents.first.count / stats.totalTop * 100).round()}% of the top ${stats.topEvents.length}'}.',
                style: TextStyle(color: c.textMuted, fontSize: 15, height: 1.4),
              ),
              if (stats.topEvents.isNotEmpty) ...[
                const SizedBox(height: 20),
                RankedBars(rows: stats.topEvents.map((e) => (e.name, e.count)).toList(), color: project.accent),
              ],
            ],
          ),
        ).animate().fadeIn(duration: 300.ms, delay: 180.ms),
      ],
    );
  }
}

/// Full-width card in the project accent with the events number and a
/// white sparkline. Ink accent falls back to the text color.
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.stats, required this.project, required this.range});
  final KeyStats stats;
  final PhProject project;
  final StatRange range;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ink = project.accentIndex == Accents.all.length - 1;
    final bg = ink ? c.text : project.accent;
    final fg = ink ? c.bg : Colors.white;
    final delta = stats.events.delta;
    return SizedBox(
      height: 250,
      child: Card1(
        color: bg,
        clip: true,
        padding: EdgeInsets.zero,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 120,
              child: TrendChart(
                points: stats.eventSeries,
                color: fg,
                height: 120,
                bare: true,
                hourly: range.bucket == 'hour',
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(SolarIconsOutline.chartSquare, size: 20, color: fg.withValues(alpha: 0.8)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'EVENTS · ${range.label.toUpperCase()}',
                          style: TextStyle(color: fg.withValues(alpha: 0.8), fontSize: 12, letterSpacing: 1.6, fontWeight: FontWeight.w500),
                        ),
                      ),
                      if (delta != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: fg.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(Radii.chip),
                          ),
                          child: Text(
                            Fmt.percent(delta),
                            style: TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  BigValue(Fmt.compact(stats.events.current), size: 44, color: fg),
                  const SizedBox(height: 6),
                  Text(
                    '${Fmt.compact(stats.events.previous)} in the previous ${range.label} · ${Fmt.compact(stats.pageviews.current)} pageviews',
                    style: TextStyle(color: fg.withValues(alpha: 0.8), fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeltaLine extends StatelessWidget {
  const _DeltaLine(this.delta, {required this.suffix});
  final double? delta;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (delta == null) return Text('No previous data', style: TextStyle(color: c.textMuted, fontSize: 14));
    final color = delta == 0 ? c.textMuted : (delta! > 0 ? c.positive : c.negative);
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: Fmt.percent(delta), style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        TextSpan(text: ' $suffix', style: TextStyle(color: c.textMuted)),
      ]),
      style: const TextStyle(fontSize: 14),
    );
  }
}

class _TrendRow extends StatelessWidget {
  const _TrendRow(this.label, this.metric);
  final String label;
  final Metric metric;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final d = metric.delta;
    final color = d == null || d == 0 ? c.textMuted : (d > 0 ? c.positive : c.negative);
    return Row(
      children: [
        Expanded(child: Text(label, style: TextStyle(fontSize: 15, color: c.text, fontWeight: FontWeight.w500))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(Radii.chip)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (d != null && d != 0) ...[
                Icon(d > 0 ? SolarIconsBold.arrowUp : SolarIconsBold.arrowDown, size: 11, color: color),
                const SizedBox(width: 3),
              ],
              Text(
                d == null ? 'new' : Fmt.percent(d),
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: _tileHeight, child: Card1(radius: Radii.tile, child: child));
  }
}

class _KeyStatsSkeleton extends StatelessWidget {
  const _KeyStatsSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget tile() => const _Tile(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Skeleton(width: 110, height: 14),
              SizedBox(height: 16),
              Skeleton(width: 90, height: 30),
              Spacer(),
              Skeleton(height: 18, radius: 9),
            ],
          ),
        );
    return Column(
      children: [
        Row(children: [Expanded(child: tile()), const SizedBox(width: Spacing.gap), Expanded(child: tile())]),
        const SizedBox(height: Spacing.gap),
        Row(children: [Expanded(child: tile()), const SizedBox(width: Spacing.gap), Expanded(child: tile())]),
        const SizedBox(height: Spacing.gap),
        const Card1(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Skeleton(width: 120, height: 14),
              SizedBox(height: 16),
              Skeleton(width: 160, height: 28),
              SizedBox(height: 20),
              Skeleton(height: 120, radius: 12),
            ],
          ),
        ),
      ],
    );
  }
}

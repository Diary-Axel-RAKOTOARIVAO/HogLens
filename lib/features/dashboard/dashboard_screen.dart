import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../core/i18n.dart';
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
import 'event_drill_sheet.dart';
import 'range_sheet.dart';

enum HeroMode { unique, all }

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key, required this.projectId});
  final String projectId;

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _editing = false;
  HeroMode _hero = HeroMode.unique;

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

  void _showProjectMenu(BuildContext context, PhProject project) {
    final c = context.colors;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.page, 0, Spacing.page, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ProjectAvatar(project: project, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(project.name, style: Theme.of(ctx).textTheme.titleLarge),
                        Text('${project.hostLabel} · #${project.projectId}', style: TextStyle(color: c.textMuted, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _MenuRow(
                icon: SolarIconsOutline.pulse,
                label: tr('Live feed'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/p/${project.id}/live');
                },
              ),
              const SizedBox(height: 8),
              _MenuRow(
                icon: SolarIconsOutline.usersGroupRounded,
                label: tr('Behavior · lifecycle, retention, paths'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/p/${project.id}/behavior');
                },
              ),
              const SizedBox(height: 8),
              _MenuRow(
                icon: SolarIconsOutline.global,
                label: tr('Worldwide'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/p/${project.id}/world');
                },
              ),
              const SizedBox(height: 8),
              _MenuRow(
                icon: SolarIconsOutline.dangerTriangle,
                label: tr('Errors'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/p/${project.id}/errors');
                },
              ),
              const SizedBox(height: 8),
              _MenuRow(
                icon: SolarIconsOutline.flag,
                label: tr('Feature flags'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/p/${project.id}/flags');
                },
              ),
              const SizedBox(height: 8),
              _MenuRow(
                icon: SolarIconsOutline.settings,
                label: tr('Project settings'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/p/${project.id}/settings');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(projectProvider(widget.projectId));
    if (project == null) return const Scaffold();
    final c = context.colors;
    final selection = ref.watch(rangeProvider);
    final stats = ref.watch(keyStatsProvider(widget.projectId));
    final widgets = ref.watch(projectWidgetsProvider(widget.projectId));

    return Scaffold(
      floatingActionButton: PillFab(
        label: tr('Add widget'),
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
              actions: [
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _showProjectMenu(context, project),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 240),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(SolarIconsOutline.altArrowDown, size: 16, color: c.textMuted),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      project.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.right,
                                      style: Theme.of(context).appBarTheme.titleTextStyle,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '${project.hostLabel} · #${project.projectId}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: c.textMuted),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        ProjectAvatar(project: project, size: 44),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: Spacing.page - 6),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(Spacing.page, 8, Spacing.page, 110),
              sliver: SliverList.list(
                children: [
                  _RangeBar(selection: selection),
                  if (stats.value?.fromCache == true) ...[
                    const SizedBox(height: 12),
                    _OfflineBadge(savedAt: stats.value!.fetchedAt),
                  ],
                  const SizedBox(height: 16),
                  stats.when(
                    skipLoadingOnRefresh: true,
                    data: (s) => _KeyStats(
                      stats: s,
                      project: project,
                      hero: _hero,
                      onHeroChanged: (m) => setState(() => _hero = m),
                    ),
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
                            child: Text(_editing ? tr('Done') : tr('Edit')),
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
                                Text(tr('Track anything'), style: Theme.of(context).textTheme.titleMedium),
                                const SizedBox(height: 3),
                                Text(
                                  tr('Any HogQL query as a number, trend, bars or table.'),
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

class _OfflineBadge extends StatelessWidget {
  const _OfflineBadge({required this.savedAt});
  final DateTime savedAt;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.chip)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(SolarIconsOutline.cloudCross, size: 15, color: c.textMuted),
              const SizedBox(width: 7),
              Text(
                '${tr('Offline · saved')} ${Fmt.relative(savedAt)}',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Card1(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 20, color: c.textMuted),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15))),
          Icon(SolarIconsOutline.altArrowRight, size: 18, color: c.textFaint),
        ],
      ),
    );
  }
}

/// Shows only the active range; tapping opens the drawer of options.
class _RangeBar extends ConsumerWidget {
  const _RangeBar({required this.selection});
  final RangeSelection selection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final now = DateTime.now();
    final label = switch (selection.kind) {
      RangeKind.thisMonth => selection.label(now),
      RangeKind.custom => selection.label(now),
      _ => '${tr('Last')} ${selection.label(now)}',
    };
    return Row(
      children: [
        Material(
          color: c.surface,
          shape: const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () => showRangeSheet(context),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(SolarIconsOutline.calendar, size: 16, color: c.textMuted),
                  const SizedBox(width: 8),
                  AnimatedSwitcher(
                    duration: 200.ms,
                    child: Text(
                      label,
                      key: ValueKey(label),
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.text),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(SolarIconsOutline.altArrowDown, size: 16, color: c.textMuted),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _KeyStats extends StatelessWidget {
  const _KeyStats({required this.stats, required this.project, required this.hero, required this.onHeroChanged});
  final KeyStats stats;
  final PhProject project;
  final HeroMode hero;
  final ValueChanged<HeroMode> onHeroChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final range = stats.range;
    final rangeLabel = range.kind == RangeKind.day
        ? tr('Last 24 hours')
        : '${Fmt.monthDay(range.start)} – ${Fmt.monthDay(range.end.subtract(const Duration(seconds: 1)))}';
    final peak = stats.hourlySeries.isEmpty ? null : stats.hourlySeries.reduce((a, b) => b.v > a.v ? b : a);
    final sessions = stats.sessions.current;
    final visitors = stats.visitors.current;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeroCard(stats: stats, project: project, mode: hero, onModeChanged: onHeroChanged)
            .animate()
            .fadeIn(duration: 300.ms),
        const SizedBox(height: Spacing.gap),
        Row(
          children: [
            Expanded(
              child: _Tile(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CardLabel(tr('Events'), icon: SolarIconsOutline.chartSquare),
                    const SizedBox(height: 10),
                    AnimatedBigValue(stats.events.current, format: Fmt.compact, size: 26),
                    const SizedBox(height: 2),
                    _DeltaLine(stats.events.delta, suffix: tr('vs previous')),
                    const Spacer(),
                    MiniBars(values: stats.eventSeries.map((p) => p.v).toList(), color: project.accent, height: 40, gap: 3),
                    const SizedBox(height: 6),
                    Text(range.hourly ? tr('Per hour') : tr('Per day'), style: TextStyle(color: c.textMuted, fontSize: 11.5)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: Spacing.gap),
            Expanded(
              child: _Tile(
                onTap: () => context.push('/p/${project.id}/live'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CardLabel(tr('Live pulse'), icon: SolarIconsOutline.pulse),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        AnimatedBigValue(stats.activeNow, format: Fmt.full, size: 26),
                        const SizedBox(width: 6),
                        Text(tr('on site'), style: TextStyle(color: c.textMuted, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(tr('Last 5 minutes'), style: TextStyle(color: c.textMuted, fontSize: 12)),
                    const Spacer(),
                    HeatStrip(points: stats.hourlySeries, color: project.accent, compact: true),
                    const SizedBox(height: 6),
                    Text(
                      peak == null ? tr('Quiet 24h') : '${tr('Peak')} ${Fmt.hour(peak.t)} · ${Fmt.compact(peak.v)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.textMuted, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ).animate().fadeIn(duration: 300.ms, delay: 60.ms),
        const SizedBox(height: Spacing.gap),
        Row(
          children: [
            Expanded(
              child: _Tile(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CardLabel(tr('Sessions'), icon: SolarIconsOutline.cursor),
                    const SizedBox(height: 10),
                    AnimatedBigValue(sessions, format: Fmt.compact, size: 26),
                    const SizedBox(height: 2),
                    _DeltaLine(stats.sessions.delta, suffix: tr('vs previous')),
                    const Spacer(),
                    KeyValueRow(tr('Events / session'), sessions == 0 ? '—' : (stats.events.current / sessions).toStringAsFixed(1), compact: true),
                    KeyValueRow(tr('Views / session'), sessions == 0 ? '—' : (stats.views.current / sessions).toStringAsFixed(1), compact: true),
                    KeyValueRow(tr('Sessions / visitor'), visitors == 0 ? '—' : (sessions / visitors).toStringAsFixed(1), compact: true),
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
                    CardLabel(tr('Trends'), icon: SolarIconsOutline.graphUp),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _TrendRow(tr('Visitors'), stats.visitors),
                          _TrendRow(tr('Views'), stats.views),
                          _TrendRow(tr('Events'), stats.events),
                          _TrendRow(tr('Sessions'), stats.sessions),
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
              Text(tr('Top events'), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 28)),
              const SizedBox(height: 6),
              Text(
                stats.topEvents.isEmpty
                    ? tr('No events were captured in this range.')
                    : '${stats.topEvents.length} ${tr('event types')}, ${Fmt.compact(stats.events.current)} ${tr('events in total')}. '
                        '${stats.topEvents.first.name} ${tr('leads with')} '
                        '${stats.totalTop == 0 ? '' : '${(stats.topEvents.first.count / stats.totalTop * 100).round()}% ${tr('of the top')} ${stats.topEvents.length}'}.',
                style: TextStyle(color: c.textMuted, fontSize: 15, height: 1.4),
              ),
              if (stats.topEvents.isNotEmpty) ...[
                const SizedBox(height: 20),
                RankedBars(
                  rows: stats.topEvents.map((e) => (e.name, e.count)).toList(),
                  color: project.accent,
                  onTap: (name) => showEventDrill(context, projectId: project.id, event: name),
                ),
              ],
            ],
          ),
        ).animate().fadeIn(duration: 300.ms, delay: 180.ms),
      ],
    );
  }
}

/// Full-width card in the project accent showing unique visitors, or all
/// views when toggled, with a white sparkline of the same series.
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.stats, required this.project, required this.mode, required this.onModeChanged});
  final KeyStats stats;
  final PhProject project;
  final HeroMode mode;
  final ValueChanged<HeroMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ink = project.accentIndex == Accents.all.length - 1;
    final bg = ink ? c.text : project.accent;
    final fg = ink ? c.bg : Colors.white;
    final unique = mode == HeroMode.unique;
    final metric = unique ? stats.visitors : stats.views;
    final series = unique ? stats.visitorSeries : stats.viewSeries;
    final delta = metric.delta;
    final range = stats.range;

    return SizedBox(
      height: 260,
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
              height: 116,
              child: TrendChart(
                key: ValueKey(mode),
                points: series,
                color: fg,
                height: 116,
                bare: true,
                hourly: range.hourly,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(SolarIconsOutline.usersGroupRounded, size: 20, color: fg.withValues(alpha: 0.8)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          (unique ? tr('UNIQUE VISITORS') : tr('VIEWS')),
                          style: TextStyle(color: fg.withValues(alpha: 0.8), fontSize: 12, letterSpacing: 1.6, fontWeight: FontWeight.w500),
                        ),
                      ),
                      SlidingToggle<HeroMode>(
                        value: mode,
                        options: const [HeroMode.unique, HeroMode.all],
                        labels: [tr('Unique'), tr('All')],
                        onChanged: onModeChanged,
                        background: fg.withValues(alpha: 0.18),
                        highlight: fg,
                        foreground: fg,
                        highlightForeground: bg,
                        segmentWidth: 62,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      AnimatedBigValue(metric.current, format: Fmt.compact, size: 44, color: fg),
                      const SizedBox(width: 12),
                      if (delta != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: fg.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(Radii.chip)),
                          child: Text(Fmt.percent(delta), style: TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.w700)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    unique
                        ? '${Fmt.compact(metric.previous)} ${tr('in the previous period')} · ${Fmt.compact(stats.views.current)} ${tr('views')}'
                        : '${Fmt.compact(metric.previous)} ${tr('in the previous period')} · ${Fmt.compact(stats.visitors.current)} ${tr('unique')}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
    if (delta == null) return Text(tr('No previous data'), style: TextStyle(color: c.textMuted, fontSize: 12.5));
    final color = delta == 0 ? c.textMuted : (delta! > 0 ? c.positive : c.negative);
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: Fmt.percent(delta), style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        TextSpan(text: ' $suffix', style: TextStyle(color: c.textMuted)),
      ]),
      style: const TextStyle(fontSize: 12.5),
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
    // One line per row: the label truncates before the badge ever wraps.
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13.5, color: c.text, fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(Radii.chip)),
          child: Text(
            d == null ? tr('new') : '${d > 0 ? '↑' : (d < 0 ? '↓' : '')}${Fmt.percent(d)}',
            maxLines: 1,
            softWrap: false,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color, fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ),
      ],
    );
  }
}

/// Square secondary tile.
class _Tile extends StatelessWidget {
  const _Tile({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Card1(radius: Radii.tile, padding: const EdgeInsets.all(18), onTap: onTap, child: child),
    );
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
        const SizedBox(
          height: 260,
          child: Card1(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(width: 140, height: 14),
                SizedBox(height: 18),
                Skeleton(width: 160, height: 44),
                Spacer(),
                Skeleton(height: 90, radius: 12),
              ],
            ),
          ),
        ),
        const SizedBox(height: Spacing.gap),
        Row(children: [Expanded(child: tile()), const SizedBox(width: Spacing.gap), Expanded(child: tile())]),
        const SizedBox(height: Spacing.gap),
        Row(children: [Expanded(child: tile()), const SizedBox(width: Spacing.gap), Expanded(child: tile())]),
      ],
    );
  }
}

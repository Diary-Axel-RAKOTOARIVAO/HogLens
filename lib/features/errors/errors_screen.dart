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
import '../../shared/visible_polling.dart';
import '../dashboard/charts.dart';

/// `$exception` events grouped by type and message over the dashboard window.
class ErrorsScreen extends ConsumerWidget {
  const ErrorsScreen({super.key, required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final report = ref.watch(errorsProvider(projectId));
    final range = ref.watch(rangeProvider).resolve(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 76,
        leading: Padding(
          padding: const EdgeInsets.only(left: Spacing.page),
          child: Center(
            child: IconCircleButton(
              icon: SolarIconsOutline.altArrowLeft,
              onTap: () => context.pop(),
            ),
          ),
        ),
        titleSpacing: 12,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tr('Errors')),
            Text(
              range.kind.name == 'thisMonth' ||
                      range.kind.name == 'custom' ||
                      range.kind.name == 'today'
                  ? range.label
                  : '${tr('Last')} ${range.label}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: c.textMuted,
              ),
            ),
          ],
        ),
      ),
      body: RefreshWhileVisible(
        interval: const Duration(seconds: 60),
        onPoll: () async {
          ref.invalidate(errorsProvider(projectId));
          await ref.read(errorsProvider(projectId).future);
        },
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(errorsProvider(projectId));
            try {
              await ref.read(errorsProvider(projectId).future);
            } catch (_) {}
          },
          child: report.when(
            skipLoadingOnRefresh: true,
            loading: () => ListView(
              padding: const EdgeInsets.all(Spacing.page),
              children: const [
                Skeleton(height: 200, radius: 28),
                SizedBox(height: 12),
                Skeleton(height: 90, radius: 20),
                SizedBox(height: 8),
                Skeleton(height: 90, radius: 20),
              ],
            ),
            error: (e, _) => ListView(
              padding: const EdgeInsets.all(Spacing.page),
              children: [
                ErrorCard(
                  message: '$e',
                  onRetry: () => ref.invalidate(errorsProvider(projectId)),
                ),
              ],
            ),
            data: (r) => ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(
                Spacing.page,
                4,
                Spacing.page,
                40,
              ),
              children: [
                Card1(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CardLabel(
                        tr('Exceptions'),
                        icon: SolarIconsOutline.dangerTriangle,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          AnimatedBigValue(
                            r.total,
                            format: Fmt.compact,
                            size: 40,
                            color: r.total == 0 ? c.text : c.negative,
                          ),
                          const SizedBox(width: 12),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              '${Fmt.compact(r.people)} ${tr('people affected')}',
                              style: TextStyle(
                                color: c.textMuted,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TrendChart(
                        points: r.series,
                        color: c.negative,
                        height: 110,
                        hourly: r.range.hourly,
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 300.ms),
                const SizedBox(height: Spacing.section),
                if (r.groups.isEmpty)
                  EmptyState(
                    icon: SolarIconsBold.checkCircle,
                    title: 'No errors',
                    message: tr(
                      'Nothing was captured as an exception in this window.',
                    ),
                  )
                else ...[
                  SectionHeader(
                    '${r.groups.length} ${r.groups.length == 1 ? tr('issue') : tr('issues')}',
                  ),
                  for (var i = 0; i < r.groups.length; i++) ...[
                    _GroupCard(
                      g: r.groups[i],
                      share: r.total == 0 ? 0 : r.groups[i].count / r.total,
                    ).animate().fadeIn(duration: 250.ms, delay: (30 * i).ms),
                    const SizedBox(height: 8),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.g, required this.share});
  final ErrorGroup g;
  final double share;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Card1(
      radius: 20,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Pill(g.type, color: c.negative),
              const Spacer(),
              Text(
                Fmt.compact(g.count),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: c.text,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                '  · ${(share * 100).toStringAsFixed(share < 0.1 ? 1 : 0)}%',
                style: TextStyle(fontSize: 12.5, color: c.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            g.message.isEmpty ? 'No message' : g.message,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.35,
              color: g.message.isEmpty ? c.textFaint : c.text,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                SolarIconsOutline.usersGroupRounded,
                size: 13,
                color: c.textFaint,
              ),
              const SizedBox(width: 4),
              Text(
                '${Fmt.compact(g.people)} ${tr('people')}',
                style: TextStyle(fontSize: 12, color: c.textMuted),
              ),
              const SizedBox(width: 12),
              Icon(SolarIconsOutline.clockCircle, size: 13, color: c.textFaint),
              const SizedBox(width: 4),
              Text(
                '${tr('last')} ${Fmt.relative(g.lastSeen)}',
                style: TextStyle(fontSize: 12, color: c.textMuted),
              ),
              const Spacer(),
              Text(
                '${tr('first')} ${Fmt.monthDay(g.firstSeen)}',
                style: TextStyle(fontSize: 12, color: c.textFaint),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

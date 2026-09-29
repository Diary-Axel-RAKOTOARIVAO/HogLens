import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../core/i18n.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/util/format.dart';
import '../../data/providers/providers.dart';
import '../../shared/ui.dart';
import 'charts.dart';

/// Drawer with one event's trend, reach and top pages over the window.
Future<void> showEventDrill(BuildContext context, {required String projectId, required String event}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _EventDrillSheet(projectId: projectId, event: event),
  );
}

class _EventDrillSheet extends ConsumerWidget {
  const _EventDrillSheet({required this.projectId, required this.event});
  final String projectId;
  final String event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final project = ref.watch(projectProvider(projectId));
    final accent = project?.accent ?? c.text;
    final drill = ref.watch(eventDrillProvider((projectId, event)));

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.94,
      minChildSize: 0.4,
      builder: (context, ctrl) => ListView(
        controller: ctrl,
        padding: const EdgeInsets.fromLTRB(Spacing.page, 0, Spacing.page, 32),
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: accent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
                child: Icon(SolarIconsOutline.bolt, size: 20, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(event, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 24))),
            ],
          ),
          const SizedBox(height: 18),
          drill.when(
            loading: () => const Column(children: [Skeleton(height: 210, radius: 28), SizedBox(height: 12), Skeleton(height: 160, radius: 28)]),
            error: (e, _) => ErrorCard(message: '$e', onRetry: () => ref.invalidate(eventDrillProvider((projectId, event)))),
            data: (d) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card1(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(tr('OCCURRENCES'), style: Theme.of(context).textTheme.labelSmall),
                                const SizedBox(height: 6),
                                AnimatedBigValue(d.count, format: Fmt.compact, size: 32),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(tr('PEOPLE'), style: Theme.of(context).textTheme.labelSmall),
                                const SizedBox(height: 6),
                                AnimatedBigValue(d.people, format: Fmt.compact, size: 32),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        d.people == 0 ? '' : '${(d.count / d.people).toStringAsFixed(1)} per person · ${d.range.kind.name == 'day' ? 'last 24h' : d.range.label}',
                        style: TextStyle(color: c.textMuted, fontSize: 13),
                      ),
                      const SizedBox(height: 14),
                      TrendChart(points: d.series, color: accent, height: 120, hourly: d.range.hourly),
                    ],
                  ),
                ),
                if (d.topPaths.isNotEmpty) ...[
                  const SizedBox(height: Spacing.gap),
                  Card1(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CardLabel(tr('Where it happens'), icon: SolarIconsOutline.global),
                        const SizedBox(height: 16),
                        BarList(rows: d.topPaths, color: accent, maxRows: 5),
                      ],
                    ),
                  ),
                ],
                if (d.topBrowsers.isNotEmpty) ...[
                  const SizedBox(height: Spacing.gap),
                  Card1(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const CardLabel('Browsers', icon: SolarIconsOutline.monitorSmartphone),
                        const SizedBox(height: 16),
                        BarList(rows: d.topBrowsers, color: accent, maxRows: 5),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

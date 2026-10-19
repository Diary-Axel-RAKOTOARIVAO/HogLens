import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../core/i18n.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/util/format.dart';
import '../../data/models/insights.dart';
import '../../data/models/project.dart';
import '../../data/providers/providers.dart';
import '../../shared/ui.dart';
import '../dashboard/charts.dart';
import 'source_brand.dart';

/// Dashboard card: sessions by channel as one stacked bar, then the top
/// sources with their logos. Tap a source for campaigns and landing pages.
class TrafficSourcesCard extends ConsumerWidget {
  const TrafficSourcesCard({super.key, required this.project, required this.rangeLabel});
  final PhProject project;
  final String rangeLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final report = ref.watch(sourcesProvider(project.id));
    return Card1(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardLabel(rangeLabel, icon: SolarIconsOutline.calendar),
          const SizedBox(height: 14),
          Text(tr('Traffic sources'), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 28)),
          const SizedBox(height: 6),
          report.when(
            skipLoadingOnRefresh: true,
            loading: () => const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Skeleton(width: 240, height: 14), SizedBox(height: 18), Skeleton(height: 14, radius: 7), SizedBox(height: 18), Skeleton(height: 160, radius: 12)],
            ),
            error: (e, _) => Text('$e', style: TextStyle(color: c.negative, fontSize: 13)),
            data: (r) => r.sources.isEmpty
                ? Text(tr('No sessions in this range.'), style: TextStyle(color: c.textMuted, fontSize: 15))
                : _Body(report: r, project: project),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.report, required this.project});
  final SourcesReport report;
  final PhProject project;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final total = report.total;
    final lead = report.sources.first;
    final leadShare = total == 0 ? 0 : (lead.sessions / total * 100).round();
    final paidNote = lead.paid == 0
        ? ''
        : ' · ${(lead.paidShare * 100).round()}% ${tr('paid')}';
    final shown = report.sources.take(8).toList();
    final rest = report.sources.skip(8).fold<num>(0, (a, s) => a + s.sessions);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${lead.name} ${tr('brings')} $leadShare% ${tr('of')} ${Fmt.compact(total)} ${tr('sessions')}$paidNote.',
          style: TextStyle(color: c.textMuted, fontSize: 15, height: 1.4),
        ),
        const SizedBox(height: 18),
        _ChannelBar(channels: report.channels, total: total),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            for (final (ch, n) in report.channels.take(6))
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: channelColor(ch, c), shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Text(
                    '${channelLabel(ch)} ${total == 0 ? '' : '${(n / total * 100).round()}%'}',
                    style: TextStyle(fontSize: 12, color: c.textMuted),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 20),
        for (var i = 0; i < shown.length; i++) ...[
          _SourceRow(
            source: shown[i],
            total: total,
            max: shown.first.sessions,
            accent: project.accent,
            onTap: () => showSourceDetail(context, project: project, source: shown[i]),
          ),
          if (i != shown.length - 1) const SizedBox(height: 14),
        ],
        if (rest > 0) ...[
          const SizedBox(height: 14),
          Text(
            '+ ${report.sources.length - shown.length} ${tr('more sources')} · ${Fmt.compact(rest)} ${tr('sessions')}',
            style: TextStyle(fontSize: 12.5, color: c.textFaint),
          ),
        ],
      ],
    );
  }
}

class _ChannelBar extends StatelessWidget {
  const _ChannelBar({required this.channels, required this.total});
  final List<(String, num)> channels;
  final num total;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (total == 0) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 12,
        child: Row(
          children: [
            for (var i = 0; i < channels.length; i++) ...[
              Expanded(
                flex: (channels[i].$2 / total * 1000).round().clamp(1, 1000),
                child: ColoredBox(color: channelColor(channels[i].$1, c)),
              ),
              if (i != channels.length - 1) const SizedBox(width: 2),
            ],
          ],
        ),
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.source, required this.total, required this.max, required this.accent, required this.onTap});
  final TrafficSource source;
  final num total;
  final num max;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final share = total == 0 ? 0.0 : source.sessions / total;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          SourceLogo(sourceKey: source.key, name: source.name, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(source.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                    if (source.paid > 0) ...[
                      const SizedBox(width: 6),
                      _Tag(text: source.paidShare > 0.95 ? tr('Paid') : '${(source.paidShare * 100).round()}% ${tr('paid')}'),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: max == 0 ? 0 : (source.sessions / max).toDouble(),
                    minHeight: 6,
                    backgroundColor: c.surfaceRaised,
                    color: sourceBrands[source.key]?.color ?? accent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Fmt.compact(source.sessions),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.text, fontFeatures: const [FontFeature.tabularFigures()]),
              ),
              Text(
                '${(share * 100).toStringAsFixed(share < 0.1 ? 1 : 0)}%',
                style: TextStyle(fontSize: 12, color: c.textMuted, fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ],
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, size: 16, color: c.textFaint),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: BorderRadius.circular(Radii.chip)),
      child: Text(text, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: c.textMuted)),
    );
  }
}

/// Drawer with one source's trend, campaigns (UTM campaign and medium) and
/// landing pages over the dashboard window.
Future<void> showSourceDetail(BuildContext context, {required PhProject project, required TrafficSource source}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _SourceSheet(project: project, source: source),
  );
}

class _SourceSheet extends ConsumerWidget {
  const _SourceSheet({required this.project, required this.source});
  final PhProject project;
  final TrafficSource source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final detail = ref.watch(sourceDetailProvider((project.id, source.key)));
    final color = sourceBrands[source.key]?.color ?? project.accent;
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
              SourceLogo(sourceKey: source.key, name: source.name, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(source.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 24)),
                    Text(
                      '${Fmt.full(source.sessions)} ${tr('sessions')} · ${channelLabel(source.channel)}'
                      '${source.paid > 0 ? ' · ${(source.paidShare * 100).round()}% ${tr('paid')}' : ''}',
                      style: TextStyle(fontSize: 13, color: c.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          detail.when(
            loading: () => const Column(children: [Skeleton(height: 170, radius: 28), SizedBox(height: 12), Skeleton(height: 200, radius: 28)]),
            error: (e, _) => ErrorCard(message: '$e', onRetry: () => ref.invalidate(sourceDetailProvider((project.id, source.key)))),
            data: (d) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card1(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CardLabel(tr('Sessions'), icon: SolarIconsOutline.graphUp),
                      const SizedBox(height: 14),
                      TrendChart(points: d.series, color: color, height: 120, hourly: d.series.length > 1 && d.series[1].t.difference(d.series[0].t).inHours < 24),
                    ],
                  ),
                ),
                const SizedBox(height: Spacing.gap),
                Card1(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CardLabel(tr('Campaigns'), icon: SolarIconsOutline.flag),
                      const SizedBox(height: 14),
                      if (d.campaigns.isEmpty)
                        Text(tr('No UTM campaign on these visits.'), style: TextStyle(color: c.textMuted, fontSize: 14))
                      else
                        for (var i = 0; i < d.campaigns.length; i++) ...[
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      d.campaigns[i].campaign.isEmpty ? tr('(no campaign)') : d.campaigns[i].campaign,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        fontFamily: RegExp(r'^\d{6,}$').hasMatch(d.campaigns[i].campaign) ? 'Menlo' : null,
                                      ),
                                    ),
                                    if (d.campaigns[i].medium.isNotEmpty)
                                      Text('utm_medium = ${d.campaigns[i].medium}', style: TextStyle(fontSize: 11.5, color: c.textFaint)),
                                  ],
                                ),
                              ),
                              Text(
                                Fmt.compact(d.campaigns[i].sessions),
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.text, fontFeatures: const [FontFeature.tabularFigures()]),
                              ),
                            ],
                          ),
                          if (i != d.campaigns.length - 1) Divider(height: 18, color: c.border),
                        ],
                    ],
                  ),
                ),
                if (d.landingPages.isNotEmpty) ...[
                  const SizedBox(height: Spacing.gap),
                  Card1(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CardLabel(tr('Landing pages'), icon: SolarIconsOutline.global),
                        const SizedBox(height: 16),
                        BarList(rows: d.landingPages, color: color, maxRows: 6),
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

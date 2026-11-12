import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../core/i18n.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/util/format.dart';
import '../../data/providers/providers.dart';
import '../../shared/ui.dart';
import '../../shared/visible_polling.dart';
import 'globe.dart';

/// Visitors by country on a spinning globe, then the ranked list.
class WorldScreen extends ConsumerWidget {
  const WorldScreen({super.key, required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final project = ref.watch(projectProvider(projectId));
    final accent = project?.accent ?? c.text;
    final geo = ref.watch(geoProvider(projectId));
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
            Text(tr('Worldwide')),
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
          ref.invalidate(geoProvider(projectId));
          await ref.read(geoProvider(projectId).future);
        },
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(geoProvider(projectId));
            try {
              await ref.read(geoProvider(projectId).future);
            } catch (_) {}
          },
          child: geo.when(
            skipLoadingOnRefresh: true,
            loading: () => ListView(
              padding: const EdgeInsets.all(Spacing.page),
              children: const [
                Skeleton(height: 380, radius: 28),
                SizedBox(height: 12),
                Skeleton(height: 300, radius: 28),
              ],
            ),
            error: (e, _) => ListView(
              padding: const EdgeInsets.all(Spacing.page),
              children: [
                ErrorCard(
                  message: '$e',
                  onRetry: () => ref.invalidate(geoProvider(projectId)),
                ),
              ],
            ),
            data: (r) {
              final total = r.totalVisitors;
              return ListView(
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
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: CardLabel(
                                tr('Visitors by country'),
                                icon: SolarIconsOutline.global,
                              ),
                            ),
                            Text(
                              '${r.countries.length} ${tr('countries')}',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: c.textMuted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LayoutBuilder(
                          builder: (context, box) => Globe(
                            countries: r.countries,
                            accent: accent,
                            size: box.maxWidth.clamp(200, 360),
                          ),
                        ),
                        Text(
                          'Drag to spin',
                          style: TextStyle(fontSize: 11.5, color: c.textFaint),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 300.ms),
                  const SizedBox(height: Spacing.gap),
                  Card1(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                tr('Top countries'),
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            Text(
                              '${Fmt.compact(total)} ${tr('visitors')}',
                              style: TextStyle(
                                fontSize: 13,
                                color: c.textMuted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (r.countries.isEmpty)
                          Text(
                            tr('No GeoIP data in this window.'),
                            style: TextStyle(color: c.textFaint),
                          )
                        else
                          for (
                            var i = 0;
                            i < r.countries.length.clamp(0, 12);
                            i++
                          ) ...[
                            _CountryRow(
                              code: r.countries[i].code,
                              name: r.countries[i].name,
                              visitors: r.countries[i].visitors,
                              share: total == 0
                                  ? 0
                                  : r.countries[i].visitors / total,
                              fraction: r.countries.first.visitors == 0
                                  ? 0
                                  : r.countries[i].visitors /
                                        r.countries.first.visitors,
                              color: accent.withValues(
                                alpha: (1 - i * 0.07).clamp(0.3, 1.0),
                              ),
                            ),
                            if (i != r.countries.length.clamp(0, 12) - 1)
                              const SizedBox(height: 14),
                          ],
                      ],
                    ),
                  ).animate().fadeIn(duration: 300.ms, delay: 80.ms),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CountryRow extends StatelessWidget {
  const _CountryRow({
    required this.code,
    required this.name,
    required this.visitors,
    required this.share,
    required this.fraction,
    required this.color,
  });
  final String code;
  final String name;
  final num visitors;
  final double share;
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        Row(
          children: [
            code.length == 2
                ? CountryFlag.fromCountryCode(code, theme: const ImageTheme(width: 24, height: 24, shape: Circle()))
                : const SizedBox(width: 24, height: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              Fmt.compact(visitors),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: c.text,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            SizedBox(
              width: 52,
              child: Text(
                '${(share * 100).toStringAsFixed(share < 0.1 ? 1 : 0)}%',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12.5,
                  color: c.textMuted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 28),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction.clamp(0, 1),
              minHeight: 6,
              backgroundColor: c.surfaceRaised,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

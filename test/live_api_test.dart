// ignore_for_file: avoid_print
// Live integration test against a real PostHog host.
//
//   PH_KEY=phx_… PH_PROJECTS=123,456 [PH_HOST=https://eu.posthog.com] \
//     flutter test test/live_api_test.dart -r expanded --concurrency=1
//
// Skipped when the variables are absent so `flutter test` stays offline.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoglens/data/api/behavior_repository.dart';
import 'package:hoglens/data/models/insights.dart';
import 'package:hoglens/data/api/insights_repository.dart';
import 'package:hoglens/data/api/posthog_client.dart';
import 'package:hoglens/data/api/sources_repository.dart';
import 'package:hoglens/data/api/stats_repository.dart';
import 'package:hoglens/data/models/stats.dart';
import 'package:hoglens/features/widgets/widget_presets.dart';

void main() {
  final key = Platform.environment['PH_KEY'] ?? '';
  final host = Platform.environment['PH_HOST'] ?? 'https://us.posthog.com';
  final ids = (Platform.environment['PH_PROJECTS'] ?? '')
      .split(',')
      .where((s) => s.trim().isNotEmpty)
      .map((s) => int.parse(s.trim()))
      .toList();

  if (key.isEmpty || ids.isEmpty) {
    test('live API', () {}, skip: 'set PH_KEY and PH_PROJECTS');
    return;
  }

  final client = PosthogClient(host: host, apiKey: key);
  const slow = Timeout(Duration(minutes: 2));

  test('listProjects', () async {
    final list = await client.listProjects();
    print('listProjects → ${list.map((p) => '${p.id}:${p.name}').join(', ')}');
    expect(list, isNotEmpty);
  }, timeout: slow);

  for (final id in ids) {
    group('project $id', () {
      test('getProject', () async {
        final p = await client.getProject(id);
        print('getProject → ${p.id} "${p.name}"');
        expect(p.id, id);
      }, timeout: slow);

      for (final sel in [...RangeSelection.presets, RangeSelection(RangeKind.custom, customStart: DateTime.now().subtract(const Duration(days: 10)), customEnd: DateTime.now().subtract(const Duration(days: 3)))]) {
        final r = sel.resolve(DateTime.now());
        test('key stats ${r.label}', () async {
          final s = await StatsRepository(client, id).fetch(r);
          print('stats ${r.label} → events ${s.events.current} (prev ${s.events.previous}), '
              'visitors ${s.visitors.current}, views ${s.views.current}, '
              'sessions ${s.sessions.current}, live ${s.activeNow}, '
              'series ${s.eventSeries.length}/${r.bucketCount} pts, hourly ${s.hourlySeries.length}, ');
          expect(s.eventSeries.length, r.bucketCount);
          expect(s.hourlySeries.length, 24);
        }, timeout: slow);
      }

      test('projects page and dashboard agree on visitors today', () async {
        final repo = StatsRepository(client, id);
        final g = await repo.glance();
        final s = await repo.fetch(RangeSelection.today.resolve(DateTime.now()));
        print('glance today ${g.today} vs dashboard today ${s.visitors.current}; week ${g.week}; daily ${g.daily}');
        expect((g.today - s.visitors.current).abs(), lessThanOrEqualTo(3));
        expect(g.daily.length, 7);
      }, timeout: slow);

      test('live feed, errors and drill-down', () async {
        final repo = InsightsRepository(client, id);
        final r = RangeSelection.week.resolve(DateTime.now());
        final live = await repo.liveFeed();
        print('live → ${live.length} events, newest ${live.isEmpty ? '-' : '${live.first.event} @ ${live.first.at} ${live.first.path}'}');
        final filtered = await repo.liveFeed(filter: 'pageview');
        print('live(filter) → ${filtered.length}, all pageview: ${filtered.every((e) => e.event.contains('pageview'))}');
        final errors = await repo.errors(r);
        print('errors → total ${errors.total}, people ${errors.people}, groups ${errors.groups.length}, series ${errors.series.length}; top: ${errors.groups.take(2).map((g) => '${g.type}: ${g.message.substring(0, g.message.length.clamp(0, 40))} (${g.count})').join(' | ')}');
        expect(errors.series.length, r.bucketCount);
        final drill = await repo.drill('\$pageview', r);
        print('drill → count ${drill.count}, people ${drill.people}, series ${drill.series.length}, paths ${drill.topPaths.take(3)}, browsers ${drill.topBrowsers.take(2)}');
        expect(drill.series.length, r.bucketCount);
      }, timeout: slow);

      test('lifecycle, retention, paths, countries', () async {
        final repo = BehaviorRepository(client, id);
        final r = RangeSelection.week.resolve(DateTime.now());
        final lc = await repo.lifecycle(r);
        print('lifecycle → days ${lc.days.length}, ${LifecycleReport.statuses.map((s) => '$s=${lc.total(s)}').join(' ')}');
        expect(lc.series.keys, containsAll(LifecycleReport.statuses));
        final rt = await repo.retention();
        print('retention → cohorts ${rt.cohorts.length}, first size ${rt.cohorts.firstOrNull?.size}, w1 ${rt.cohorts.firstOrNull?.rate(1)}');
        expect(rt.cohorts, isNotEmpty);
        final pt = await repo.paths(r);
        print('paths → ${pt.links.length} links, top ${pt.links.take(3).map((l) => '${l.fromStep}:${l.from}→${l.to}=${l.value}').join(' | ')}');
        final geo = await repo.countries(r);
        print('geo → ${geo.countries.length} countries, top ${geo.countries.take(3).map((c) => '${c.flag} ${c.name} ${c.visitors}').join(', ')}');
        expect(geo.countries, isNotEmpty);
      }, timeout: slow);

      test('traffic sources, source detail, top events', () async {
        final r = RangeSelection.week.resolve(DateTime.now());
        final repo = SourcesRepository(client, id);
        final report = await repo.sources(r);
        print('sources → ${report.sources.length} sources, ${report.total} ${report.visitors ? 'visitors' : 'sessions (fallback)'}; '
            'channels ${report.channels.take(4).map((c) => '${c.$1}=${c.$2}').join(' ')}; '
            'top ${report.sources.take(6).map((s) => '${s.name}=${s.count}${s.paid > 0 ? '(paid ${(s.paidShare * 100).round()}%)' : ''}').join(', ')}');
        expect(report.sources, isNotEmpty);
        expect(report.sources.fold<num>(0, (a, s) => a + s.count), report.total);
        // Each visitor is credited to one source, so the card adds up to the hero.
        expect(report.visitors, isTrue);
        expect(report.total, (await StatsRepository(client, id).fetch(r)).visitors.current);
        final detail = await repo.detail(report.sources.first, r, visitors: report.visitors);
        print('detail(${report.sources.first.name}) → campaigns ${detail.campaigns.length} '
            '(${detail.campaigns.take(2).map((c) => '${c.campaign}/${c.medium}=${c.count}').join(', ')}), '
            'landing ${detail.landingPages.take(3)}, series ${detail.series.length}');
        expect(detail.series.length, r.bucketCount);
        final top = await StatsRepository(client, id).topEvents(r);
        print('top events → ${top.take(3).map((e) => '${e.name}=${e.count}').join(', ')}');
        expect(top, isNotEmpty);
      }, timeout: slow);

      test('flags', () async {
        final f = await client.listFlags(id);
        print('flags → ${f.length}: ${f.take(5).map((x) => '${x.key}${x.active ? '' : '(off)'}').join(', ')}');
      }, timeout: slow);

      for (final preset in widgetPresets) {
        test('preset ${preset.id}', () async {
          final q = StatsRepository.resolve(preset.hogql, RangeSelection.week.resolve(DateTime.now()));
          final r = await client.query(id, q, name: 'hoglens_test');
          print('preset ${preset.id} → ${r.rows.length} rows, cols ${r.columns}, first ${r.rows.isEmpty ? '-' : r.rows.first}');
        }, timeout: slow);
      }
    });
  }
}

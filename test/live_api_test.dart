// ignore_for_file: avoid_print
// Live integration test against a real PostHog host.
//
//   PH_KEY=phx_… PH_PROJECTS=123,456 [PH_HOST=https://eu.posthog.com] \
//     flutter test test/live_api_test.dart -r expanded --concurrency=1
//
// Skipped when the variables are absent so `flutter test` stays offline.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoglens/data/api/posthog_client.dart';
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
              'series ${s.eventSeries.length}/${r.bucketCount} pts, hourly ${s.hourlySeries.length}, '
              'top ${s.topEvents.take(3).map((e) => '${e.name}=${e.count}').join(' ')}');
          expect(s.eventSeries.length, r.bucketCount);
          expect(s.hourlySeries.length, 24);
        }, timeout: slow);
      }

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

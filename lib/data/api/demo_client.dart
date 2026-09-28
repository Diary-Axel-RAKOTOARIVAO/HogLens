import 'dart:math';

import '../models/stats.dart';
import 'posthog_client.dart';

/// Deterministic fake data so the app can be explored without a key.
class DemoClient implements PhApi {
  final _rng = Random(7);

  @override
  Future<List<RemoteProject>> listProjects() async => const [RemoteProject(id: 1, name: 'Demo')];

  @override
  Future<RemoteProject> getProject(int projectId) async => const RemoteProject(id: 1, name: 'Demo');

  @override
  Future<QueryResult> query(int projectId, String hogql, {String? name}) async {
    await Future.delayed(Duration(milliseconds: 250 + _rng.nextInt(400)));
    final q = hogql.toLowerCase();
    final now = DateTime.now();

    if (name == 'hoglens_glance') {
      final today = DateTime(now.year, now.month, now.day);
      return QueryResult(columns: const ['d', 'count'], rows: [
        for (var i = 6; i >= 0; i--)
          [today.subtract(Duration(days: i)).toIso8601String(), i == 0 ? 6314 : 5200 + ((i * 1373) % 2900)],
      ]);
    }
    if (name == 'hoglens_hourly') {
      final rows = <List<dynamic>>[];
      for (var i = 23; i >= 0; i--) {
        final t = DateTime(now.year, now.month, now.day, now.hour).subtract(Duration(hours: i));
        final phase = (t.hour - 14).abs() / 14;
        rows.add([t.toIso8601String(), (2600 * (1 - 0.6 * phase) * (0.85 + _rng.nextDouble() * 0.3)).round()]);
      }
      return QueryResult(columns: const ['bucket', 'count'], rows: rows);
    }
    if (name == 'hoglens_summary') {
      return const QueryResult(
        columns: ['e', 'ep', 'vis', 'visp', 'views', 'viewsp', 's', 'sp', 'live'],
        rows: [[48213, 41980, 2980, 3210, 19870, 17210, 5410, 5102, 23]],
      );
    }
    if (q.contains('tostartofhour') || q.contains('tostartofday')) {
      final hourly = q.contains('tostartofhour');
      // Window from the toDateTime literals when present, else a default.
      final lits = RegExp(r"todatetime\('([^']+)'\)").allMatches(q).map((m) => DateTime.parse('${m.group(1)}Z').toLocal()).toList();
      final end = lits.length >= 2 ? lits[1] : now;
      final start = lits.isNotEmpty ? lits[0] : (hourly ? now.subtract(const Duration(hours: 24)) : now.subtract(const Duration(days: 7)));
      final rows = <List<dynamic>>[];
      var t = hourly ? DateTime(start.year, start.month, start.day, start.hour) : DateTime(start.year, start.month, start.day);
      while (t.isBefore(end)) {
        final phase = hourly ? (t.hour - 14).abs() / 14 : (t.weekday >= 6 ? 0.55 : 1.0);
        final base = hourly ? 2600 : 7200;
        final v = (base * (1 - 0.5 * phase) * (0.85 + _rng.nextDouble() * 0.3)).round();
        rows.add([t.toUtc().toIso8601String(), v, (v * 0.062).round(), (v * 0.41).round()]);
        t = hourly ? t.add(const Duration(hours: 1)) : DateTime(t.year, t.month, t.day + 1);
      }
      return QueryResult(columns: const ['bucket', 'count', 'visitors', 'views'], rows: rows);
    }
    if (name == 'hoglens_top' || q.contains('group by event')) {
      return const QueryResult(columns: ['event', 'c'], rows: [
        ['\$pageview', 19870], ['\$autocapture', 12040], ['\$identify', 4210],
        ['search performed', 3980], ['listing viewed', 3120], ['booking started', 1210],
        ['booking confirmed', 640], ['\$feature_flag_called', 512],
      ]);
    }
    if (q.contains('geoip_country')) {
      return const QueryResult(columns: ['country', 'users'], rows: [
        ['Madagascar', 1820], ['France', 610], ['Mauritius', 240], ['Réunion', 190], ['Germany', 88],
      ]);
    }
    if (q.contains('\$browser')) {
      return const QueryResult(columns: ['browser', 'sessions'], rows: [
        ['Chrome', 3120], ['Safari', 1410], ['Firefox', 420], ['Edge', 260], ['Samsung Internet', 200],
      ]);
    }
    if (q.contains('\$os')) {
      return const QueryResult(columns: ['os', 'users'], rows: [
        ['Android', 1710], ['iOS', 980], ['Windows', 310], ['Mac OS X', 120],
      ]);
    }
    if (q.contains('\$pathname')) {
      return const QueryResult(columns: ['path', 'views'], rows: [
        ['/', 8210], ['/search', 4120], ['/listing/1182', 1330], ['/pricing', 980], ['/login', 760], ['/help', 410],
      ]);
    }
    if (q.contains('order by timestamp desc')) {
      return QueryResult(columns: const ['event', 'distinct_id', 'timestamp'], rows: [
        for (var i = 0; i < 8; i++)
          [
            const ['\$pageview', 'listing viewed', 'search performed', 'booking started'][i % 4],
            'user_${1000 + _rng.nextInt(9000)}',
            now.subtract(Duration(minutes: i * 3 + _rng.nextInt(3))).toIso8601String(),
          ],
      ]);
    }
    if (q.contains('group by')) {
      return QueryResult(columns: const ['label', 'value'], rows: [
        for (var i = 0; i < 5; i++) ['Group ${String.fromCharCode(65 + i)}', 900 - i * 160 + _rng.nextInt(60)],
      ]);
    }
    return QueryResult(columns: const ['count'], rows: [[120 + _rng.nextInt(2400)]]);
  }

  @override
  Future<List<FeatureFlag>> listFlags(int projectId) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final now = DateTime.now();
    return [
      FeatureFlag(id: 1, key: 'new-checkout', name: 'Redesigned checkout flow', active: true, rolloutPercentage: 50, createdAt: now.subtract(const Duration(days: 3))),
      FeatureFlag(id: 2, key: 'map-search', name: 'Map-based search', active: true, rolloutPercentage: 100, createdAt: now.subtract(const Duration(days: 21))),
      FeatureFlag(id: 3, key: 'dark-mode', name: '', active: false, rolloutPercentage: null, createdAt: now.subtract(const Duration(days: 60))),
      FeatureFlag(id: 4, key: 'referral-program', name: 'Invite friends banner', active: true, rolloutPercentage: 10, createdAt: now.subtract(const Duration(hours: 5))),
    ];
  }
}

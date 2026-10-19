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
  Future<QueryResult> query(int projectId, String hogql, {String? name, bool fresh = false}) async {
    await Future.delayed(Duration(milliseconds: 250 + _rng.nextInt(400)));
    final q = hogql.toLowerCase();
    final now = DateTime.now();

    if (name == 'hoglens_glance') {
      final today = DateTime(now.year, now.month, now.day);
      return QueryResult(columns: const ['d', 'visitors'], rows: [
        for (var i = 6; i >= 0; i--)
          [today.subtract(Duration(days: i)).toIso8601String(), i == 0 ? 412 : 380 + ((i * 97) % 190)],
      ]);
    }
    if (name == 'hoglens_glance_week') {
      return const QueryResult(columns: ['visitors'], rows: [[2980]]);
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
    if (name == 'hoglens_sources') {
      return const QueryResult(columns: ['src', 'ref', 'ch', 'sessions'], rows: [
        ['fb', 'm.facebook.com', 'Paid Social', 2065], ['', r'$direct', 'Direct', 701], ['', 'example.com', 'Referral', 410],
        ['', 'm.facebook.com', 'Organic Social', 667], ['fb', 'facebook.com', 'Paid Social', 322], ['', 'www.google.com', 'Organic Search', 245],
        ['ig', 'instagram.com', 'Paid Social', 136], ['', 'instagram.com', 'Organic Social', 58], ['chatgpt.com', r'$direct', 'AI', 94],
        ['', 'l.facebook.com', 'Organic Social', 55], ['', 'www.bing.com', 'Organic Search', 21], ['gemini', r'$direct', 'AI', 62], ['', 'claude.ai', 'AI', 48],
        ['', 'duckduckgo.com', 'Organic Search', 9], ['', 'wa.me', 'Organic Social', 31], ['', 'www.tiktok.com', 'Organic Social', 18],
        ['newsletter', 'mail.google.com', 'Email', 26],
      ]);
    }
    if (name == 'hoglens_source_campaigns') {
      return const QueryResult(columns: ['c', 'm', 'n'], rows: [
        ['autumn_rentals', 'paid', 922], ['antananarivo_flats', 'paid', 534], ['retargeting_7d', 'paid', 461], ['', 'social', 205],
      ]);
    }
    if (name == 'hoglens_source_landing') {
      return const QueryResult(columns: ['p', 'n'], rows: [['/', 1210], ['/recherche', 880], ['/listing/1182', 312], ['/pricing', 140]]);
    }
    if (name == 'hoglens_geo') {
      return const QueryResult(columns: ['cc', 'name', 'visitors', 'events'], rows: [
        ['MG', 'Madagascar', 4749, 86132], ['FR', 'France', 610, 4120], ['US', 'United States', 142, 354],
        ['MU', 'Mauritius', 120, 980], ['DE', 'Germany', 66, 200], ['RE', 'Réunion', 60, 410],
        ['CN', 'China', 58, 94], ['GB', 'United Kingdom', 34, 101], ['CA', 'Canada', 22, 60],
        ['BR', 'Brazil', 16, 40], ['IN', 'India', 14, 30], ['AU', 'Australia', 9, 20],
      ]);
    }
    if (name == 'hoglens_live') {
      return QueryResult(columns: const ['event', 'distinct_id', 'timestamp', 'path', 'browser', 'os'], rows: [
        for (var i = 0; i < 40; i++)
          [
            const ['\$pageview', 'listing viewed', 'search performed', '\$autocapture', 'booking started', '\$exception'][i % 6],
            'user_${1000 + (i * 137) % 900}',
            now.subtract(Duration(seconds: i * 23 + _rng.nextInt(20))).toUtc().toIso8601String(),
            const ['/', '/recherche', '/listing/1182', '/pricing', '/login'][i % 5],
            const ['Chrome', 'Safari', 'Firefox'][i % 3],
            const ['Android', 'iOS', 'Windows'][i % 3],
          ],
      ]);
    }
    if (name == 'hoglens_errors') {
      return QueryResult(columns: const ['type', 'message', 'c', 'people', 'first', 'last'], rows: [
        ['TypeError', 'Failed to fetch dynamically imported module: /_app/immutable/nodes/1.js', 412, 301, now.subtract(const Duration(days: 6)).toUtc().toIso8601String(), now.subtract(const Duration(minutes: 12)).toUtc().toIso8601String()],
        ['Error', 'Error invoking postMessage: Java object is gone', 188, 140, now.subtract(const Duration(days: 20)).toUtc().toIso8601String(), now.subtract(const Duration(hours: 3)).toUtc().toIso8601String()],
        ['NetworkError', 'Load failed', 96, 88, now.subtract(const Duration(days: 2)).toUtc().toIso8601String(), now.subtract(const Duration(hours: 1)).toUtc().toIso8601String()],
        ['RangeError', 'Maximum call stack size exceeded', 14, 9, now.subtract(const Duration(days: 1)).toUtc().toIso8601String(), now.subtract(const Duration(hours: 9)).toUtc().toIso8601String()],
      ]);
    }
    if (name == 'hoglens_drill_summary') {
      return const QueryResult(columns: ['c', 'u'], rows: [[19870, 2980]]);
    }
    if (name == 'hoglens_drill_paths') {
      return const QueryResult(columns: ['p', 'c'], rows: [['/', 8210], ['/recherche', 4120], ['/listing/1182', 1330], ['/pricing', 980], ['/login', 760]]);
    }
    if (name == 'hoglens_drill_browsers') {
      return const QueryResult(columns: ['b', 'c'], rows: [['Chrome', 9120], ['Safari', 6410], ['Firefox', 2420], ['Edge', 1260]]);
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
  Future<List<dynamic>> insight(int projectId, Map<String, dynamic> query, {String? name}) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final now = DateTime.now();
    switch (query['kind']) {
      case 'LifecycleQuery':
        final days = [for (var i = 13; i >= 0; i--) DateTime(now.year, now.month, now.day - i)];
        List<dynamic> series(String status, int base, double spread) => [
              for (var i = 0; i < days.length; i++) (base + spread * base * ((i * 37) % 10 - 5) / 10).round(),
            ];
        return [
          for (final (status, base, spread) in [('new', 180, 0.5), ('returning', 420, 0.3), ('resurrecting', 90, 0.6), ('dormant', 150, 0.5)])
            {
              'status': status,
              'label': '\$pageview - $status',
              'data': series(status, base, spread),
              'days': days.map((d) => d.toIso8601String().substring(0, 10)).toList(),
            },
        ];
      case 'RetentionQuery':
        return [
          for (var c = 0; c < 7; c++)
            {
              'date': now.subtract(Duration(days: 7 * (6 - c))).toUtc().toIso8601String(),
              'values': [
                for (var w = 0; w < 7 - c; w++) {'count': w == 0 ? 1800 + c * 120 : ((1800 + c * 120) * (0.42 / (w + 0.2)) * (0.9 + (c * 13 % 7) / 35)).round()},
              ],
            },
        ];
      case 'PathsQuery':
        return [
          {'source': '1_https://app.example.com/', 'target': '2_https://app.example.com/recherche', 'value': 640},
          {'source': '1_https://app.example.com/', 'target': '2_https://app.example.com/login', 'value': 210},
          {'source': '1_https://app.example.com/pricing', 'target': '2_https://app.example.com/register', 'value': 120},
          {'source': '2_https://app.example.com/recherche', 'target': '3_https://app.example.com/listing/1182', 'value': 410},
          {'source': '2_https://app.example.com/recherche', 'target': '3_https://app.example.com/recherche?city=x', 'value': 150},
          {'source': '2_https://app.example.com/login', 'target': '3_https://app.example.com/profil', 'value': 160},
          {'source': '2_https://app.example.com/register', 'target': '3_https://app.example.com/profil', 'value': 90},
          {'source': '3_https://app.example.com/listing/1182', 'target': '4_https://app.example.com/booking', 'value': 230},
          {'source': '3_https://app.example.com/listing/1182', 'target': '4_https://app.example.com/contact', 'value': 110},
          {'source': '3_https://app.example.com/profil', 'target': '4_https://app.example.com/favoris', 'value': 140},
        ];
    }
    return const [];
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

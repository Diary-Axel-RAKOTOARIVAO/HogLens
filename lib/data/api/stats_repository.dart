import '../models/stats.dart';
import 'posthog_client.dart';

/// Builds the HogQL behind the key-stats dashboard.
class StatsRepository {
  StatsRepository(this._client, this._projectId);

  final PhApi _client;
  final int _projectId;

  Future<KeyStats> fetch(StatRange range) async {
    final cur = 'timestamp >= now() - ${range.interval}';
    final prev = 'timestamp < now() - ${range.interval}';

    final summaryQ = '''
SELECT
  countIf($cur), countIf($prev),
  uniqIf(person_id, $cur), uniqIf(person_id, $prev),
  countIf(event = '\$pageview' AND $cur), countIf(event = '\$pageview' AND $prev),
  uniqIf(properties.\$session_id, $cur), uniqIf(properties.\$session_id, $prev),
  uniqIf(person_id, timestamp >= now() - INTERVAL 5 MINUTE)
FROM events
WHERE timestamp >= now() - ${range.doubleInterval}
  AND timestamp <= now()
''';

    final bucketFn = range.bucket == 'hour' ? 'toStartOfHour' : 'toStartOfDay';
    final seriesQ = '''
SELECT $bucketFn(timestamp) AS bucket, count(), uniq(person_id)
FROM events
WHERE $cur AND timestamp <= now()
GROUP BY bucket
ORDER BY bucket
''';

    final topQ = '''
SELECT event, count() AS c
FROM events
WHERE $cur AND timestamp <= now()
GROUP BY event
ORDER BY c DESC
LIMIT 8
''';

    const hourlyQ = '''
SELECT toStartOfHour(timestamp) AS bucket, count()
FROM events
WHERE timestamp >= now() - INTERVAL 24 HOUR AND timestamp <= now()
GROUP BY bucket
ORDER BY bucket
''';

    final results = await Future.wait([
      _client.query(_projectId, summaryQ, name: 'hoglens_summary'),
      _client.query(_projectId, seriesQ, name: 'hoglens_series'),
      _client.query(_projectId, topQ, name: 'hoglens_top'),
      if (range != StatRange.day) _client.query(_projectId, hourlyQ, name: 'hoglens_hourly'),
    ]);

    final s = results[0].rows.isEmpty ? List<num>.filled(9, 0) : results[0].rows.first;
    num n(dynamic v) => v is num ? v : num.tryParse('$v') ?? 0;

    final eventSeries = <SeriesPoint>[];
    final userSeries = <SeriesPoint>[];
    for (final r in results[1].rows) {
      final t = DateTime.tryParse('${r[0]}')?.toLocal();
      if (t == null) continue;
      eventSeries.add(SeriesPoint(t, n(r[1])));
      userSeries.add(SeriesPoint(t, n(r[2])));
    }

    final hourly = <SeriesPoint>[];
    if (range != StatRange.day) {
      for (final r in results[3].rows) {
        final t = DateTime.tryParse('${r[0]}')?.toLocal();
        if (t != null) hourly.add(SeriesPoint(t, n(r[1])));
      }
    }

    return KeyStats(
      events: Metric(current: n(s[0]), previous: n(s[1])),
      users: Metric(current: n(s[2]), previous: n(s[3])),
      pageviews: Metric(current: n(s[4]), previous: n(s[5])),
      sessions: Metric(current: n(s[6]), previous: n(s[7])),
      activeNow: n(s[8]),
      eventSeries: fill(eventSeries, range),
      userSeries: fill(userSeries, range),
      hourlySeries: range == StatRange.day ? fill(eventSeries, range) : fill(hourly, StatRange.day),
      topEvents: results[2].rows.map((r) => TopEvent('${r[0]}', n(r[1]))).toList(),
      fetchedAt: DateTime.now(),
    );
  }

  /// Fills missing buckets with zeros so charts have a stable x-axis.
  static List<SeriesPoint> fill(List<SeriesPoint> pts, StatRange range) {
    final now = DateTime.now();
    final byKey = {for (final p in pts) _key(p.t, range): p.v};
    final out = <SeriesPoint>[];
    if (range.bucket == 'hour') {
      final start = DateTime(now.year, now.month, now.day, now.hour).subtract(const Duration(hours: 23));
      for (var i = 0; i < 24; i++) {
        final t = start.add(Duration(hours: i));
        out.add(SeriesPoint(t, byKey[_key(t, range)] ?? 0));
      }
    } else {
      final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: range.days - 1));
      for (var i = 0; i < range.days; i++) {
        final t = start.add(Duration(days: i));
        out.add(SeriesPoint(t, byKey[_key(t, range)] ?? 0));
      }
    }
    return out;
  }

  static String _key(DateTime t, StatRange r) =>
      r.bucket == 'hour' ? '${t.year}-${t.month}-${t.day}-${t.hour}' : '${t.year}-${t.month}-${t.day}';

  /// Resolves `{range}` placeholders in custom widget queries.
  static String resolve(String hogql, StatRange range) =>
      hogql.replaceAll('{range}', 'now() - ${range.interval}');
}

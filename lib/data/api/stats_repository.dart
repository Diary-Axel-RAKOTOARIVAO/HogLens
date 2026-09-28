import '../models/stats.dart';
import 'posthog_client.dart';

/// Builds the HogQL behind the key-stats dashboard.
class StatsRepository {
  StatsRepository(this._client, this._projectId);

  final PhApi _client;
  final int _projectId;

  static const _isView = "event IN ('\$pageview', '\$screen')";

  Future<KeyStats> fetch(StatRange range) async {
    final cur = range.whereCurrent;
    final prev = range.wherePrevious;

    final summaryQ = '''
SELECT
  countIf($cur), countIf($prev),
  uniqIf(person_id, $_isView AND $cur), uniqIf(person_id, $_isView AND $prev),
  countIf($_isView AND $cur), countIf($_isView AND $prev),
  uniqIf(properties.\$session_id, $cur), uniqIf(properties.\$session_id, $prev),
  uniqIf(person_id, timestamp >= now() - INTERVAL 5 MINUTE)
FROM events
WHERE ${range.whereBoth} OR timestamp >= now() - INTERVAL 5 MINUTE
''';

    final bucketFn = range.hourly ? 'toStartOfHour' : 'toStartOfDay';
    final seriesQ = '''
SELECT $bucketFn(timestamp) AS bucket, count(), uniqIf(person_id, $_isView), countIf($_isView)
FROM events
WHERE $cur
GROUP BY bucket
ORDER BY bucket
LIMIT 2000
''';

    final topQ = '''
SELECT event, count() AS c
FROM events
WHERE $cur
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
      _client.query(_projectId, hourlyQ, name: 'hoglens_hourly'),
    ]);

    final s = results[0].rows.isEmpty ? List<num>.filled(9, 0) : results[0].rows.first;
    num n(dynamic v) => v is num ? v : num.tryParse('$v') ?? 0;

    final eventSeries = <SeriesPoint>[];
    final visitorSeries = <SeriesPoint>[];
    final viewSeries = <SeriesPoint>[];
    for (final r in results[1].rows) {
      final t = DateTime.tryParse('${r[0]}')?.toLocal();
      if (t == null) continue;
      eventSeries.add(SeriesPoint(t, n(r[1])));
      visitorSeries.add(SeriesPoint(t, n(r[2])));
      viewSeries.add(SeriesPoint(t, n(r[3])));
    }

    final hourly = <SeriesPoint>[];
    for (final r in results[3].rows) {
      final t = DateTime.tryParse('${r[0]}')?.toLocal();
      if (t != null) hourly.add(SeriesPoint(t, n(r[1])));
    }
    final now = DateTime.now();
    final last24 = StatRange(start: now.subtract(const Duration(hours: 24)), end: now, label: '24h', kind: RangeKind.day);

    return KeyStats(
      range: range,
      events: Metric(current: n(s[0]), previous: n(s[1])),
      visitors: Metric(current: n(s[2]), previous: n(s[3])),
      views: Metric(current: n(s[4]), previous: n(s[5])),
      sessions: Metric(current: n(s[6]), previous: n(s[7])),
      activeNow: n(s[8]),
      eventSeries: fill(eventSeries, range),
      visitorSeries: fill(visitorSeries, range),
      viewSeries: fill(viewSeries, range),
      hourlySeries: fill(hourly, last24),
      topEvents: results[2].rows.map((r) => TopEvent('${r[0]}', n(r[1]))).toList(),
      fetchedAt: now,
    );
  }

  /// Fills missing buckets with zeros so charts have a stable x-axis.
  static List<SeriesPoint> fill(List<SeriesPoint> pts, StatRange range) {
    final byKey = {for (final p in pts) _key(p.t, range.hourly): p.v};
    final out = <SeriesPoint>[];
    if (range.hourly) {
      // The last N whole hours ending with the hour that contains `end`, so a
      // window starting mid-hour still yields exactly bucketCount cells.
      final lastT = range.end.subtract(const Duration(seconds: 1));
      final last = DateTime(lastT.year, lastT.month, lastT.day, lastT.hour);
      final count = range.bucketCount;
      for (var i = count - 1; i >= 0; i--) {
        final t = last.subtract(Duration(hours: i));
        out.add(SeriesPoint(t, byKey[_key(t, true)] ?? 0));
      }
    } else {
      var t = DateTime(range.start.year, range.start.month, range.start.day);
      final lastT = range.end.subtract(const Duration(seconds: 1));
      final last = DateTime(lastT.year, lastT.month, lastT.day);
      while (!t.isAfter(last)) {
        out.add(SeriesPoint(t, byKey[_key(t, false)] ?? 0));
        t = DateTime(t.year, t.month, t.day + 1);
      }
    }
    return out;
  }

  static String _key(DateTime t, bool hourly) =>
      hourly ? '${t.year}-${t.month}-${t.day}-${t.hour}' : '${t.year}-${t.month}-${t.day}';

  /// Resolves `{range}` (window start) and `{range_end}` placeholders in
  /// custom widget queries.
  static String resolve(String hogql, StatRange range) =>
      hogql.replaceAll('{range}', range.startSql).replaceAll('{range_end}', range.endSql);
}

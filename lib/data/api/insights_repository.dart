import '../models/insights.dart';
import '../models/stats.dart';
import 'posthog_client.dart';
import 'stats_repository.dart';

/// Queries behind the live feed, the errors screen and event drill-downs.
class InsightsRepository {
  InsightsRepository(this._client, this._projectId);

  final PhApi _client;
  final int _projectId;

  static num _n(dynamic v) => v is num ? v : num.tryParse('$v') ?? 0;
  static DateTime? _t(dynamic v) => DateTime.tryParse('$v')?.toLocal();

  Future<List<LiveEvent>> liveFeed({String? filter, int limit = 60}) async {
    final where = filter == null || filter.trim().isEmpty
        ? ''
        : "AND event ILIKE '%${filter.trim().replaceAll("'", "''")}%'";
    final r = await _client.query(
      _projectId,
      '''
SELECT event, distinct_id, timestamp,
  coalesce(properties.\$pathname, properties.\$screen_name),
  properties.\$browser, properties.\$os
FROM events
WHERE timestamp >= now() - INTERVAL 1 DAY AND timestamp <= now() $where
ORDER BY timestamp DESC
LIMIT $limit
''',
      name: 'hoglens_live',
    );
    return [
      for (final row in r.rows)
        if (_t(row[2]) != null)
          LiveEvent(
            event: '${row[0]}',
            distinctId: '${row[1]}',
            at: _t(row[2])!,
            path: row[3]?.toString(),
            browser: row[4]?.toString(),
            os: row[5]?.toString(),
          ),
    ];
  }

  Future<ErrorsReport> errors(StatRange range) async {
    final cur = range.whereCurrent;
    final bucketFn = range.hourly ? 'toStartOfHour' : 'toStartOfDay';
    final results = await Future.wait([
      _client.query(
        _projectId,
        '''
SELECT
  coalesce(properties.\$exception_list[1].type, properties.\$exception_type, 'Error') AS type,
  coalesce(properties.\$exception_list[1].value, properties.\$exception_message, '') AS message,
  count() AS c, uniq(person_id), min(timestamp), max(timestamp)
FROM events
WHERE event = '\$exception' AND $cur
GROUP BY type, message
ORDER BY c DESC
LIMIT 40
''',
        name: 'hoglens_errors',
      ),
      _client.query(
        _projectId,
        '''
SELECT $bucketFn(timestamp) AS bucket, count()
FROM events
WHERE event = '\$exception' AND $cur
GROUP BY bucket ORDER BY bucket LIMIT 2000
''',
        name: 'hoglens_errors_series',
      ),
    ]);
    final groups = [
      for (final row in results[0].rows)
        ErrorGroup(
          type: '${row[0]}',
          message: '${row[1]}',
          count: _n(row[2]),
          people: _n(row[3]),
          firstSeen: _t(row[4]) ?? DateTime.now(),
          lastSeen: _t(row[5]) ?? DateTime.now(),
        ),
    ];
    final series = <SeriesPoint>[
      for (final row in results[1].rows)
        if (_t(row[0]) != null) SeriesPoint(_t(row[0])!, _n(row[1])),
    ];
    return ErrorsReport(
      range: range,
      total: groups.fold<num>(0, (a, g) => a + g.count),
      people: groups.fold<num>(0, (a, g) => a + g.people),
      groups: groups,
      series: StatsRepository.fill(series, range),
    );
  }

  Future<EventDrill> drill(String event, StatRange range) async {
    final cur = range.whereCurrent;
    final ev = event.replaceAll("'", "''");
    final bucketFn = range.hourly ? 'toStartOfHour' : 'toStartOfDay';
    final results = await Future.wait([
      _client.query(
        _projectId,
        "SELECT count(), uniq(person_id) FROM events WHERE event = '$ev' AND $cur",
        name: 'hoglens_drill_summary',
      ),
      _client.query(
        _projectId,
        "SELECT $bucketFn(timestamp) AS bucket, count() FROM events WHERE event = '$ev' AND $cur GROUP BY bucket ORDER BY bucket LIMIT 2000",
        name: 'hoglens_drill_series',
      ),
      _client.query(
        _projectId,
        "SELECT coalesce(properties.\$pathname, properties.\$screen_name) AS p, count() AS c FROM events WHERE event = '$ev' AND $cur AND p IS NOT NULL GROUP BY p ORDER BY c DESC LIMIT 5",
        name: 'hoglens_drill_paths',
      ),
      _client.query(
        _projectId,
        "SELECT properties.\$browser AS b, count() AS c FROM events WHERE event = '$ev' AND $cur AND b IS NOT NULL GROUP BY b ORDER BY c DESC LIMIT 5",
        name: 'hoglens_drill_browsers',
      ),
    ]);
    final s = results[0].rows.isEmpty ? [0, 0] : results[0].rows.first;
    final series = <SeriesPoint>[
      for (final row in results[1].rows)
        if (_t(row[0]) != null) SeriesPoint(_t(row[0])!, _n(row[1])),
    ];
    List<(String, num)> pairs(List<List<dynamic>> rows) => [for (final r in rows) ('${r[0]}', _n(r[1]))];
    return EventDrill(
      event: event,
      range: range,
      count: _n(s[0]),
      people: _n(s[1]),
      series: StatsRepository.fill(series, range),
      topPaths: pairs(results[2].rows),
      topBrowsers: pairs(results[3].rows),
    );
  }
}

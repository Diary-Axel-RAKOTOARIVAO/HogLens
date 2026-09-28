import '../models/insights.dart';
import '../models/stats.dart';
import 'posthog_client.dart';

/// Lifecycle, retention, paths and geography. The first three use PostHog's
/// insight queries so the heavy lifting (and caching) happens server-side.
class BehaviorRepository {
  BehaviorRepository(this._client, this._projectId);

  final PhApi _client;
  final int _projectId;

  static const _viewEvents = [r'$pageview', r'$screen'];
  static num _n(dynamic v) => v is num ? v : num.tryParse('$v') ?? 0;
  static String _date(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<LifecycleReport> lifecycle(StatRange range) async {
    final results = await _client.insight(
      _projectId,
      {
        'kind': 'LifecycleQuery',
        'series': [
          {'kind': 'EventsNode', 'event': r'$pageview', 'math': 'total'},
        ],
        'dateRange': {'date_from': _date(range.start), 'date_to': _date(range.end)},
        'interval': range.hourly ? 'hour' : 'day',
      },
      name: 'hoglens_lifecycle',
    );
    List<DateTime> days = const [];
    final series = <String, List<num>>{};
    for (final r in results) {
      final m = r as Map;
      final status = (m['status'] as String?) ?? _statusFromLabel('${m['label']}');
      final data = ((m['data'] as List?) ?? const []).map(_n).map((v) => v.abs()).toList();
      series[status] = data;
      if (days.isEmpty) {
        days = ((m['days'] as List?) ?? const []).map((d) => DateTime.tryParse('$d') ?? DateTime.now()).toList();
      }
    }
    return LifecycleReport(days: days, series: series);
  }

  static String _statusFromLabel(String label) {
    for (final s in LifecycleReport.statuses) {
      if (label.toLowerCase().endsWith(s)) return s;
    }
    return 'returning';
  }

  Future<RetentionReport> retention({int periods = 7}) async {
    final results = await _client.insight(
      _projectId,
      {
        'kind': 'RetentionQuery',
        'retentionFilter': {
          'targetEntity': {'id': r'$pageview', 'type': 'events'},
          'returningEntity': {'id': r'$pageview', 'type': 'events'},
          'period': 'Week',
          'totalIntervals': periods,
          'retentionType': 'retention_first_time',
        },
      },
      name: 'hoglens_retention',
    );
    final cohorts = <RetentionCohort>[];
    for (final r in results) {
      final m = r as Map;
      final start = DateTime.tryParse('${m['date']}')?.toLocal();
      if (start == null) continue;
      final values = ((m['values'] as List?) ?? const []).map((v) => _n((v as Map)['count'])).toList();
      cohorts.add(RetentionCohort(start: start, values: values));
    }
    return RetentionReport(cohorts: cohorts, periods: periods);
  }

  Future<PathsReport> paths(StatRange range, {int stepLimit = 4}) async {
    final results = await _client.insight(
      _projectId,
      {
        'kind': 'PathsQuery',
        'pathsFilter': {'includeEventTypes': _viewEvents, 'stepLimit': stepLimit},
        'dateRange': {'date_from': _date(range.start), 'date_to': _date(range.end)},
      },
      name: 'hoglens_paths',
    );
    // Merge links whose URLs differ only by origin or query string.
    final merged = <String, PathLink>{};
    for (final r in results) {
      final m = r as Map;
      final (fromStep, from) = _node('${m['source']}');
      final (_, to) = _node('${m['target']}');
      if (from == to) continue;
      final key = '$fromStep|$from|$to';
      final prev = merged[key];
      merged[key] = PathLink(fromStep: fromStep, from: from, to: to, value: (prev?.value ?? 0) + _n(m['value']));
    }
    final links = merged.values.toList()..sort((a, b) => b.value.compareTo(a.value));
    return PathsReport(links: links);
  }

  /// "2_https://app.example.com/search?x=1" → (2, "/search").
  static (int, String) _node(String raw) {
    final us = raw.indexOf('_');
    final step = int.tryParse(us > 0 ? raw.substring(0, us) : '') ?? 1;
    var label = us > 0 ? raw.substring(us + 1) : raw;
    final uri = Uri.tryParse(label);
    if (uri != null && uri.hasScheme) {
      label = uri.path.isEmpty ? '/' : uri.path;
    }
    if (label.length > 1 && label.endsWith('/')) label = label.substring(0, label.length - 1);
    return (step, label);
  }

  Future<GeoReport> countries(StatRange range) async {
    final r = await _client.query(
      _projectId,
      '''
SELECT properties.\$geoip_country_code AS cc, any(properties.\$geoip_country_name) AS name,
  uniq(person_id) AS visitors, count() AS events
FROM events
WHERE ${range.whereCurrent} AND cc IS NOT NULL AND cc != ''
GROUP BY cc
ORDER BY visitors DESC
LIMIT 60
''',
      name: 'hoglens_geo',
    );
    return GeoReport(
      countries: [
        for (final row in r.rows)
          CountryStat(code: '${row[0]}', name: '${row[1]}', visitors: _n(row[2]), events: _n(row[3])),
      ],
    );
  }
}

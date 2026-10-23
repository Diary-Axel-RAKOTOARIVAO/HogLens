import '../../features/sources/source_brand.dart';
import '../models/insights.dart';
import '../models/stats.dart';
import 'posthog_client.dart';
import 'stats_repository.dart';

/// Where visitors come from. Each unique visitor (a person with a pageview or
/// screen in the window, the same set the dashboard hero counts) is credited
/// to the entry UTM source, referring domain and channel of their first visit,
/// so the sources add up to the hero number. If the project's HogQL can't join
/// events to sessions, falls back to counting sessions from the sessions table.
class SourcesRepository {
  SourcesRepository(this._client, this._projectId);

  final PhApi _client;
  final int _projectId;

  static num _n(dynamic v) => v is num ? v : num.tryParse('$v') ?? 0;
  static String _q(String s) => s.replaceAll(r'\', r'\\').replaceAll("'", r"\'");

  static String _window(StatRange r) => '\$start_timestamp >= ${r.startSql} AND \$start_timestamp < ${r.endSql}';

  /// One row per visitor with the entry fields of their first view in [r].
  static String _firstTouch(StatRange r) => '''
SELECT person_id,
  argMin(coalesce(session.\$entry_utm_source, ''), timestamp) AS src,
  argMin(coalesce(session.\$entry_referring_domain, ''), timestamp) AS ref,
  argMin(coalesce(session.\$channel_type, 'Unknown'), timestamp) AS ch,
  argMin(coalesce(session.\$entry_utm_campaign, ''), timestamp) AS c,
  argMin(coalesce(session.\$entry_utm_medium, ''), timestamp) AS m,
  argMin(coalesce(session.\$entry_pathname, '/'), timestamp) AS p,
  min(timestamp) AS t
FROM events
WHERE event IN ('\$pageview', '\$screen') AND ${r.whereCurrent}
GROUP BY person_id''';

  /// Errors from the query itself (unknown field, timeout), not auth or network.
  static bool _queryFailed(Object e) => e is PosthogException && (e.statusCode == 400 || e.statusCode == 500);

  Future<SourcesReport> sources(StatRange range) async {
    // Sessions per source, used for the visit counts, or as the main counts
    // when the visitor query isn't available.
    final sessionsQ = _client.query(
      _projectId,
      '''
SELECT coalesce(\$entry_utm_source, '') AS src, coalesce(\$entry_referring_domain, '') AS ref,
  coalesce(\$channel_type, 'Unknown') AS ch, count() AS sessions
FROM sessions
WHERE ${_window(range)}
GROUP BY src, ref, ch
ORDER BY sessions DESC
LIMIT 1000
''',
      name: 'hoglens_sources_sessions',
    );
    QueryResult? byVisitor;
    try {
      byVisitor = await _client.query(
        _projectId,
        'SELECT src, ref, ch, count() AS n FROM (${_firstTouch(range)}) GROUP BY src, ref, ch ORDER BY n DESC LIMIT 1000',
        name: 'hoglens_sources',
      );
    } catch (e) {
      if (!_queryFailed(e)) rethrow;
    }
    final bySession = await sessionsQ;

    final visits = <String, num>{};
    for (final row in bySession.rows) {
      final (key, _) = classifySource('${row[0] ?? ''}', '${row[1] ?? ''}');
      visits[key] = (visits[key] ?? 0) + _n(row[3]);
    }

    final bySource = <String, _Acc>{};
    final byChannel = <String, num>{};
    for (final row in (byVisitor ?? bySession).rows) {
      final src = '${row[0] ?? ''}', ref = '${row[1] ?? ''}', ch = '${row[2] ?? 'Unknown'}';
      final n = _n(row[3]);
      byChannel[ch] = (byChannel[ch] ?? 0) + n;
      final (key, name) = classifySource(src, ref);
      final acc = bySource.putIfAbsent(key, () => _Acc(key, name));
      acc.count += n;
      if (ch.startsWith('Paid')) acc.paid += n;
      acc.channels[ch] = (acc.channels[ch] ?? 0) + n;
      acc.pairs.add((src, ref));
    }
    final sources = bySource.values.map((a) => a.build(visits[a.key] ?? a.count)).toList()
      ..sort((a, b) => b.count.compareTo(a.count));
    final channels = byChannel.entries.map((e) => (e.key, e.value)).toList()..sort((a, b) => b.$2.compareTo(a.$2));
    return SourcesReport(
      sources: sources,
      channels: channels,
      visitors: byVisitor != null,
      visits: visits.values.fold<num>(0, (a, n) => a + n),
    );
  }

  /// Campaigns, landing pages and a trend for one source, in the same unit as
  /// the report it came from.
  Future<SourceDetail> detail(TrafficSource source, StatRange range, {required bool visitors}) async {
    final bucket = range.hourly ? 'toStartOfHour' : 'toStartOfDay';
    final List<QueryResult> results;
    if (visitors) {
      final pairs = source.pairs.take(80).map((p) => "(src = '${_q(p.$1)}' AND ref = '${_q(p.$2)}')");
      final from = 'FROM (${_firstTouch(range)}) WHERE ${pairs.join(' OR ')}';
      results = await Future.wait([
        _client.query(_projectId, 'SELECT c, m, count() AS n $from GROUP BY c, m ORDER BY n DESC LIMIT 8', name: 'hoglens_source_campaigns'),
        _client.query(_projectId, 'SELECT p, count() AS n $from GROUP BY p ORDER BY n DESC LIMIT 6', name: 'hoglens_source_landing'),
        _client.query(_projectId, 'SELECT $bucket(t) AS b, count() $from GROUP BY b ORDER BY b LIMIT 2000', name: 'hoglens_source_series'),
      ]);
    } else {
      final pairs = source.pairs.take(80).map((p) =>
          "(coalesce(\$entry_utm_source, '') = '${_q(p.$1)}' AND coalesce(\$entry_referring_domain, '') = '${_q(p.$2)}')");
      final where = '${_window(range)} AND (${pairs.join(' OR ')})';
      results = await Future.wait([
        _client.query(
          _projectId,
          "SELECT coalesce(\$entry_utm_campaign, '') AS c, coalesce(\$entry_utm_medium, '') AS m, count() AS n "
          'FROM sessions WHERE $where GROUP BY c, m ORDER BY n DESC LIMIT 8',
          name: 'hoglens_source_campaigns',
        ),
        _client.query(
          _projectId,
          "SELECT coalesce(\$entry_pathname, '/') AS p, count() AS n FROM sessions WHERE $where GROUP BY p ORDER BY n DESC LIMIT 6",
          name: 'hoglens_source_landing',
        ),
        _client.query(
          _projectId,
          'SELECT $bucket(\$start_timestamp) AS b, count() FROM sessions WHERE $where GROUP BY b ORDER BY b LIMIT 2000',
          name: 'hoglens_source_series',
        ),
      ]);
    }
    final series = <SeriesPoint>[
      for (final row in results[2].rows)
        if (DateTime.tryParse('${row[0]}') != null) SeriesPoint(DateTime.parse('${row[0]}').toLocal(), _n(row[1])),
    ];
    return SourceDetail(
      campaigns: [
        for (final row in results[0].rows)
          if ('${row[0]}'.isNotEmpty || '${row[1]}'.isNotEmpty)
            SourceCampaign(campaign: '${row[0]}', medium: '${row[1]}', count: _n(row[2])),
      ],
      landingPages: [for (final row in results[1].rows) ('${row[0]}', _n(row[1]))],
      series: StatsRepository.fill(series, range),
    );
  }
}

class _Acc {
  _Acc(this.key, this.name);
  final String key;
  final String name;
  num count = 0;
  num paid = 0;
  final Map<String, num> channels = {};
  final List<(String, String)> pairs = [];

  TrafficSource build(num visits) {
    final top = channels.entries.reduce((a, b) => b.value > a.value ? b : a).key;
    return TrafficSource(key: key, name: name, count: count, visits: visits, paid: paid, channel: top, pairs: pairs);
  }
}

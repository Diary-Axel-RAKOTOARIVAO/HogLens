import '../../features/sources/source_brand.dart';
import '../models/insights.dart';
import '../models/stats.dart';
import 'posthog_client.dart';
import 'stats_repository.dart';

/// Where visitors come from, from PostHog's sessions table: each session's
/// entry UTM source, referring domain and PostHog's own channel type.
class SourcesRepository {
  SourcesRepository(this._client, this._projectId);

  final PhApi _client;
  final int _projectId;

  static num _n(dynamic v) => v is num ? v : num.tryParse('$v') ?? 0;
  static String _q(String s) => s.replaceAll(r'\', r'\\').replaceAll("'", r"\'");

  static String _window(StatRange r) => '\$start_timestamp >= ${r.startSql} AND \$start_timestamp < ${r.endSql}';

  Future<SourcesReport> sources(StatRange range) async {
    final r = await _client.query(
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
      name: 'hoglens_sources',
    );

    final bySource = <String, _Acc>{};
    final byChannel = <String, num>{};
    for (final row in r.rows) {
      final src = '${row[0] ?? ''}', ref = '${row[1] ?? ''}', ch = '${row[2] ?? 'Unknown'}';
      final n = _n(row[3]);
      byChannel[ch] = (byChannel[ch] ?? 0) + n;
      final (key, name) = classifySource(src, ref);
      final acc = bySource.putIfAbsent(key, () => _Acc(key, name));
      acc.sessions += n;
      if (ch.startsWith('Paid')) acc.paid += n;
      acc.channels[ch] = (acc.channels[ch] ?? 0) + n;
      acc.pairs.add((src, ref));
    }
    final sources = bySource.values.map((a) => a.build()).toList()..sort((a, b) => b.sessions.compareTo(a.sessions));
    final channels = byChannel.entries.map((e) => (e.key, e.value)).toList()..sort((a, b) => b.$2.compareTo(a.$2));
    return SourcesReport(sources: sources, channels: channels);
  }

  /// Campaigns, landing pages and a trend for one source.
  Future<SourceDetail> detail(TrafficSource source, StatRange range) async {
    final pairs = source.pairs.take(80).map((p) =>
        "(coalesce(\$entry_utm_source, '') = '${_q(p.$1)}' AND coalesce(\$entry_referring_domain, '') = '${_q(p.$2)}')");
    final where = '${_window(range)} AND (${pairs.join(' OR ')})';
    final bucket = range.hourly ? 'toStartOfHour' : 'toStartOfDay';
    final results = await Future.wait([
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
    final series = <SeriesPoint>[
      for (final row in results[2].rows)
        if (DateTime.tryParse('${row[0]}') != null) SeriesPoint(DateTime.parse('${row[0]}').toLocal(), _n(row[1])),
    ];
    return SourceDetail(
      campaigns: [
        for (final row in results[0].rows)
          if ('${row[0]}'.isNotEmpty || '${row[1]}'.isNotEmpty)
            SourceCampaign(campaign: '${row[0]}', medium: '${row[1]}', sessions: _n(row[2])),
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
  num sessions = 0;
  num paid = 0;
  final Map<String, num> channels = {};
  final List<(String, String)> pairs = [];

  TrafficSource build() {
    final top = channels.entries.reduce((a, b) => b.value > a.value ? b : a).key;
    return TrafficSource(key: key, name: name, sessions: sessions, paid: paid, channel: top, pairs: pairs);
  }
}

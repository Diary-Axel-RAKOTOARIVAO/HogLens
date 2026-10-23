import 'package:flutter/foundation.dart';

import 'stats.dart';

@immutable
class LiveEvent {
  const LiveEvent({
    required this.event,
    required this.distinctId,
    required this.at,
    this.path,
    this.browser,
    this.os,
  });
  final String event;
  final String distinctId;
  final DateTime at;
  final String? path;
  final String? browser;
  final String? os;

  Map<String, dynamic> toJson() =>
      {'e': event, 'd': distinctId, 't': at.toIso8601String(), 'p': path, 'b': browser, 'o': os};
  factory LiveEvent.fromJson(Map<String, dynamic> j) => LiveEvent(
        event: j['e'] as String,
        distinctId: j['d'] as String,
        at: DateTime.parse(j['t'] as String),
        path: j['p'] as String?,
        browser: j['b'] as String?,
        os: j['o'] as String?,
      );
}

@immutable
class ErrorGroup {
  const ErrorGroup({
    required this.type,
    required this.message,
    required this.count,
    required this.people,
    required this.firstSeen,
    required this.lastSeen,
  });
  final String type;
  final String message;
  final num count;
  final num people;
  final DateTime firstSeen;
  final DateTime lastSeen;

  Map<String, dynamic> toJson() => {
        't': type,
        'm': message,
        'c': count,
        'p': people,
        'f': firstSeen.toIso8601String(),
        'l': lastSeen.toIso8601String(),
      };
  factory ErrorGroup.fromJson(Map<String, dynamic> j) => ErrorGroup(
        type: j['t'] as String,
        message: j['m'] as String,
        count: j['c'] as num,
        people: j['p'] as num,
        firstSeen: DateTime.parse(j['f'] as String),
        lastSeen: DateTime.parse(j['l'] as String),
      );
}

@immutable
class ErrorsReport {
  const ErrorsReport({required this.range, required this.total, required this.people, required this.groups, required this.series});
  final StatRange range;
  final num total;
  final num people;
  final List<ErrorGroup> groups;
  final List<SeriesPoint> series;

  Map<String, dynamic> toJson() => {
        'range': range.toJson(),
        'total': total,
        'people': people,
        'groups': groups.map((g) => g.toJson()).toList(),
        'series': series.map((p) => p.toJson()).toList(),
      };
  factory ErrorsReport.fromJson(Map<String, dynamic> j) => ErrorsReport(
        range: StatRange.fromJson(j['range'] as Map<String, dynamic>),
        total: j['total'] as num,
        people: j['people'] as num,
        groups: (j['groups'] as List).map((g) => ErrorGroup.fromJson(g as Map<String, dynamic>)).toList(),
        series: (j['series'] as List).map((p) => SeriesPoint.fromJson(p as List<dynamic>)).toList(),
      );
}

/// One event name explored over the dashboard window.
@immutable
class EventDrill {
  const EventDrill({
    required this.event,
    required this.range,
    required this.count,
    required this.people,
    required this.series,
    required this.topPaths,
    required this.topBrowsers,
  });
  final String event;
  final StatRange range;
  final num count;
  final num people;
  final List<SeriesPoint> series;
  final List<(String, num)> topPaths;
  final List<(String, num)> topBrowsers;
}

@immutable
class AppUpdate {
  const AppUpdate({required this.version, required this.url, required this.notes});
  final String version;
  final String url;
  final String notes;
}

/// Home-card numbers: unique visitors per day for the last 7 days (last is
/// today) and the deduplicated 7-day total.
@immutable
class Glance {
  const Glance({required this.daily, required this.week});
  final List<num> daily;
  final num week;

  num get today => daily.isEmpty ? 0 : daily.last;

  Map<String, dynamic> toJson() => {'d': daily, 'w': week};
  factory Glance.fromJson(Map<String, dynamic> j) =>
      Glance(daily: (j['d'] as List).cast<num>(), week: j['w'] as num);
}

/// Lifecycle insight: per bucket, how many people were new, returning,
/// resurrecting or dormant (dormant is stored positive, drawn below zero).
@immutable
class LifecycleReport {
  const LifecycleReport({required this.days, required this.series});
  final List<DateTime> days;

  /// Keys: new, returning, resurrecting, dormant.
  final Map<String, List<num>> series;

  static const statuses = ['new', 'returning', 'resurrecting', 'dormant'];

  num total(String status) => (series[status] ?? const []).fold<num>(0, (a, b) => a + b);

  Map<String, dynamic> toJson() => {'days': days.map((d) => d.toIso8601String()).toList(), 'series': series};
  factory LifecycleReport.fromJson(Map<String, dynamic> j) => LifecycleReport(
        days: (j['days'] as List).map((d) => DateTime.parse(d as String)).toList(),
        series: (j['series'] as Map).map((k, v) => MapEntry(k as String, (v as List).cast<num>())),
      );
}

@immutable
class RetentionCohort {
  const RetentionCohort({required this.start, required this.values});
  final DateTime start;

  /// values[0] is the cohort size, later entries are people who came back.
  final List<num> values;

  num get size => values.isEmpty ? 0 : values.first;
  double? rate(int i) => i >= values.length || size == 0 ? null : (values[i] / size).toDouble();

  Map<String, dynamic> toJson() => {'s': start.toIso8601String(), 'v': values};
  factory RetentionCohort.fromJson(Map<String, dynamic> j) =>
      RetentionCohort(start: DateTime.parse(j['s'] as String), values: (j['v'] as List).cast<num>());
}

@immutable
class RetentionReport {
  const RetentionReport({required this.cohorts, required this.periods});
  final List<RetentionCohort> cohorts;
  final int periods;

  Map<String, dynamic> toJson() => {'c': cohorts.map((c) => c.toJson()).toList(), 'p': periods};
  factory RetentionReport.fromJson(Map<String, dynamic> j) => RetentionReport(
        cohorts: (j['c'] as List).map((c) => RetentionCohort.fromJson(c as Map<String, dynamic>)).toList(),
        periods: (j['p'] as num).toInt(),
      );
}

@immutable
class PathLink {
  const PathLink({required this.fromStep, required this.from, required this.to, required this.value});
  final int fromStep;
  final String from;
  final String to;
  final num value;

  List<dynamic> toJson() => [fromStep, from, to, value];
  factory PathLink.fromJson(List<dynamic> j) =>
      PathLink(fromStep: (j[0] as num).toInt(), from: j[1] as String, to: j[2] as String, value: j[3] as num);
}

@immutable
class PathsReport {
  const PathsReport({required this.links});
  final List<PathLink> links;

  Map<String, dynamic> toJson() => {'l': links.map((l) => l.toJson()).toList()};
  factory PathsReport.fromJson(Map<String, dynamic> j) =>
      PathsReport(links: (j['l'] as List).map((l) => PathLink.fromJson(l as List<dynamic>)).toList());
}

@immutable
class CountryStat {
  const CountryStat({required this.code, required this.name, required this.visitors, required this.events});
  final String code;
  final String name;
  final num visitors;
  final num events;

  /// Regional-indicator flag for the ISO code.
  String get flag => code.length == 2
      ? String.fromCharCodes(code.toUpperCase().codeUnits.map((c) => 0x1F1E6 + c - 65))
      : '🏳️';

  List<dynamic> toJson() => [code, name, visitors, events];
  factory CountryStat.fromJson(List<dynamic> j) =>
      CountryStat(code: j[0] as String, name: j[1] as String, visitors: j[2] as num, events: j[3] as num);
}

@immutable
class GeoReport {
  const GeoReport({required this.countries});
  final List<CountryStat> countries;

  num get totalVisitors => countries.fold<num>(0, (a, c) => a + c.visitors);

  Map<String, dynamic> toJson() => {'c': countries.map((c) => c.toJson()).toList()};
  factory GeoReport.fromJson(Map<String, dynamic> j) =>
      GeoReport(countries: (j['c'] as List).map((c) => CountryStat.fromJson(c as List<dynamic>)).toList());
}

/// One traffic source (Facebook, Google, ChatGPT, a referring domain…) over
/// the dashboard window: unique visitors whose first visit came from it, or
/// sessions when the report fell back to the sessions table.
@immutable
class TrafficSource {
  const TrafficSource({
    required this.key,
    required this.name,
    required this.count,
    required this.paid,
    required this.channel,
    required this.pairs,
  });
  final String key;
  final String name;
  final num count;

  /// Visitors (or sessions) PostHog classified as a paid channel.
  final num paid;

  /// The channel most of this source's traffic falls in.
  final String channel;

  /// Raw (utm_source, referring_domain) pairs that make up this source,
  /// used to filter the detail queries.
  final List<(String, String)> pairs;

  double get paidShare => count == 0 ? 0 : paid / count;

  Map<String, dynamic> toJson() => {
        'k': key,
        'n': name,
        's': count,
        'p': paid,
        'c': channel,
        'r': [for (final (u, d) in pairs) [u, d]],
      };
  factory TrafficSource.fromJson(Map<String, dynamic> j) => TrafficSource(
        key: j['k'] as String,
        name: j['n'] as String,
        count: j['s'] as num,
        paid: j['p'] as num,
        channel: j['c'] as String,
        pairs: [for (final r in (j['r'] as List)) ((r as List)[0] as String, r[1] as String)],
      );
}

@immutable
class SourcesReport {
  const SourcesReport({required this.sources, required this.channels, required this.visitors});
  final List<TrafficSource> sources;

  /// Counts per PostHog channel type, largest first.
  final List<(String, num)> channels;

  /// True when counts are unique visitors (matching the dashboard hero),
  /// false when they are sessions.
  final bool visitors;

  num get total => channels.fold<num>(0, (a, c) => a + c.$2);

  Map<String, dynamic> toJson() => {
        's': sources.map((s) => s.toJson()).toList(),
        'c': [for (final (k, v) in channels) [k, v]],
        'v': visitors,
      };
  factory SourcesReport.fromJson(Map<String, dynamic> j) => SourcesReport(
        visitors: j['v'] as bool? ?? false,
        sources: (j['s'] as List).map((s) => TrafficSource.fromJson(s as Map<String, dynamic>)).toList(),
        channels: [for (final c in (j['c'] as List)) ((c as List)[0] as String, c[1] as num)],
      );
}

@immutable
class SourceCampaign {
  const SourceCampaign({required this.campaign, required this.medium, required this.count});
  final String campaign;
  final String medium;
  final num count;
}

@immutable
class SourceDetail {
  const SourceDetail({required this.campaigns, required this.landingPages, required this.series});
  final List<SourceCampaign> campaigns;
  final List<(String, num)> landingPages;
  final List<SeriesPoint> series;
}

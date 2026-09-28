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

import 'package:flutter/foundation.dart';

enum StatRange {
  day('24h', 1, 'hour'),
  week('7d', 7, 'day'),
  month('30d', 30, 'day');

  const StatRange(this.label, this.days, this.bucket);
  final String label;
  final int days;

  /// Bucket used for series: 'hour' for 24h, 'day' otherwise.
  final String bucket;

  String get interval => 'INTERVAL $days DAY';
  String get doubleInterval => 'INTERVAL ${days * 2} DAY';
}

@immutable
class Metric {
  const Metric({required this.current, required this.previous});
  final num current;
  final num previous;

  double? get delta {
    if (previous == 0) return current == 0 ? 0 : null;
    return (current - previous) / previous;
  }
}

@immutable
class SeriesPoint {
  const SeriesPoint(this.t, this.v);
  final DateTime t;
  final num v;
}

@immutable
class TopEvent {
  const TopEvent(this.name, this.count);
  final String name;
  final num count;
}

@immutable
class KeyStats {
  const KeyStats({
    required this.events,
    required this.users,
    required this.pageviews,
    required this.sessions,
    required this.activeNow,
    required this.eventSeries,
    required this.userSeries,
    required this.hourlySeries,
    required this.topEvents,
    required this.fetchedAt,
  });

  final Metric events;
  final Metric users;
  final Metric pageviews;
  final Metric sessions;
  final num activeNow;
  final List<SeriesPoint> eventSeries;
  final List<SeriesPoint> userSeries;

  /// Events per hour over the last 24 hours, independent of the range.
  final List<SeriesPoint> hourlySeries;
  final List<TopEvent> topEvents;

  num get totalTop => topEvents.fold<num>(0, (a, e) => a + e.count);
  final DateTime fetchedAt;
}

@immutable
class QueryResult {
  const QueryResult({required this.columns, required this.rows});
  final List<String> columns;
  final List<List<dynamic>> rows;

  bool get isEmpty => rows.isEmpty;
  dynamic get firstCell => rows.isEmpty || rows.first.isEmpty ? null : rows.first.first;
}

@immutable
class FeatureFlag {
  const FeatureFlag({
    required this.id,
    required this.key,
    required this.name,
    required this.active,
    required this.rolloutPercentage,
    required this.createdAt,
  });
  final int id;
  final String key;
  final String name;
  final bool active;
  final int? rolloutPercentage;
  final DateTime? createdAt;

  factory FeatureFlag.fromJson(Map<String, dynamic> j) {
    int? rollout;
    final groups = (j['filters'] as Map?)?['groups'] as List?;
    if (groups != null && groups.isNotEmpty) {
      final r = (groups.first as Map)['rollout_percentage'];
      if (r is num) rollout = r.toInt();
    }
    return FeatureFlag(
      id: (j['id'] as num).toInt(),
      key: j['key'] as String? ?? '',
      name: j['name'] as String? ?? '',
      active: j['active'] as bool? ?? false,
      rolloutPercentage: rollout,
      createdAt: DateTime.tryParse(j['created_at'] as String? ?? ''),
    );
  }
}

@immutable
class RemoteProject {
  const RemoteProject({required this.id, required this.name});
  final int id;
  final String name;
}

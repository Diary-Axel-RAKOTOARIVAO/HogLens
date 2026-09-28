import 'package:flutter/foundation.dart';

enum RangeKind { day, week, month, thisMonth, custom }

/// What the user picked. Resolved into a concrete [StatRange] at query time
/// so "now" is fresh on every refresh.
@immutable
class RangeSelection {
  const RangeSelection(this.kind, {this.customStart, this.customEnd});

  final RangeKind kind;
  final DateTime? customStart;
  final DateTime? customEnd;

  static const day = RangeSelection(RangeKind.day);
  static const week = RangeSelection(RangeKind.week);
  static const month = RangeSelection(RangeKind.month);
  static const thisMonth = RangeSelection(RangeKind.thisMonth);

  static const presets = [day, week, month, thisMonth];

  String label(DateTime now) => switch (kind) {
        RangeKind.day => '24h',
        RangeKind.week => '7d',
        RangeKind.month => '30d',
        RangeKind.thisMonth => _monthName(now.month),
        RangeKind.custom => customStart == null || customEnd == null
            ? 'Custom'
            : '${_short(customStart!)} – ${_short(customEnd!)}',
      };

  StatRange resolve(DateTime now) {
    switch (kind) {
      case RangeKind.day:
        return StatRange(start: now.subtract(const Duration(hours: 24)), end: now, label: label(now), kind: kind);
      case RangeKind.week:
        return StatRange(start: now.subtract(const Duration(days: 7)), end: now, label: label(now), kind: kind);
      case RangeKind.month:
        return StatRange(start: now.subtract(const Duration(days: 30)), end: now, label: label(now), kind: kind);
      case RangeKind.thisMonth:
        return StatRange(start: DateTime(now.year, now.month), end: now, label: label(now), kind: kind);
      case RangeKind.custom:
        final s = customStart ?? now.subtract(const Duration(days: 7));
        final e = customEnd ?? now;
        final endOfDay = DateTime(e.year, e.month, e.day).add(const Duration(days: 1));
        return StatRange(
          start: DateTime(s.year, s.month, s.day),
          end: endOfDay.isAfter(now) ? now : endOfDay,
          label: label(now),
          kind: kind,
        );
    }
  }

  static String _monthName(int m) =>
      const ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'][m - 1];
  static String _short(DateTime d) =>
      '${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.month - 1]} ${d.day}';

  @override
  bool operator ==(Object other) =>
      other is RangeSelection && other.kind == kind && other.customStart == customStart && other.customEnd == customEnd;

  @override
  int get hashCode => Object.hash(kind, customStart, customEnd);
}

/// A concrete window [start, end) in local time, plus the previous window of
/// the same length used for deltas.
@immutable
class StatRange {
  const StatRange({required this.start, required this.end, required this.label, required this.kind});

  final DateTime start;
  final DateTime end;
  final String label;
  final RangeKind kind;

  Duration get span => end.difference(start);
  DateTime get previousStart => start.subtract(span);

  /// Hourly buckets for windows up to two days, daily otherwise.
  bool get hourly => span.inHours <= 48;
  String get bucket => hourly ? 'hour' : 'day';

  /// Number of buckets the filled series will contain.
  int get bucketCount {
    if (hourly) return (span.inMinutes / 60).ceil().clamp(1, 1 << 20);
    final s = DateTime(start.year, start.month, start.day);
    final last = end.subtract(const Duration(seconds: 1));
    final e = DateTime(last.year, last.month, last.day);
    return e.difference(s).inDays + 1;
  }

  static String _sql(DateTime t) {
    final u = t.toUtc();
    String two(int v) => v.toString().padLeft(2, '0');
    return "toDateTime('${u.year}-${two(u.month)}-${two(u.day)} ${two(u.hour)}:${two(u.minute)}:${two(u.second)}')";
  }

  String get startSql => _sql(start);
  String get endSql => _sql(end);
  String get previousStartSql => _sql(previousStart);

  String get whereCurrent => 'timestamp >= $startSql AND timestamp < $endSql';
  String get wherePrevious => 'timestamp >= $previousStartSql AND timestamp < $startSql';
  String get whereBoth => 'timestamp >= $previousStartSql AND timestamp < $endSql';
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
    required this.range,
    required this.events,
    required this.visitors,
    required this.views,
    required this.sessions,
    required this.activeNow,
    required this.eventSeries,
    required this.visitorSeries,
    required this.viewSeries,
    required this.hourlySeries,
    required this.topEvents,
    required this.fetchedAt,
  });

  final StatRange range;
  final Metric events;

  /// Unique people who produced a view event (`$pageview` or `$screen`).
  final Metric visitors;

  /// View events, i.e. non-unique visits.
  final Metric views;
  final Metric sessions;
  final num activeNow;
  final List<SeriesPoint> eventSeries;
  final List<SeriesPoint> visitorSeries;
  final List<SeriesPoint> viewSeries;

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

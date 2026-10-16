import 'package:flutter/foundation.dart';

import '../../core/i18n.dart';

enum RangeKind { today, day, week, month, thisMonth, custom }

/// What the user picked. Resolved into a concrete [StatRange] at query time
/// so "now" is fresh on every refresh.
@immutable
class RangeSelection {
  const RangeSelection(this.kind, {this.customStart, this.customEnd});

  final RangeKind kind;
  final DateTime? customStart;
  final DateTime? customEnd;

  static const today = RangeSelection(RangeKind.today);
  static const day = RangeSelection(RangeKind.day);
  static const week = RangeSelection(RangeKind.week);
  static const month = RangeSelection(RangeKind.month);
  static const thisMonth = RangeSelection(RangeKind.thisMonth);

  static const presets = [today, day, week, month, thisMonth];

  String label(DateTime now) => switch (kind) {
        RangeKind.today => tr('Today'),
        RangeKind.day => '24h',
        RangeKind.week => '7d',
        RangeKind.month => '30d',
        RangeKind.thisMonth => monthName(now.month),
        RangeKind.custom => customStart == null || customEnd == null
            ? tr('Custom')
            : '${monthDay(customStart!)} – ${monthDay(customEnd!)}',
      };

  StatRange resolve(DateTime now) {
    switch (kind) {
      case RangeKind.today:
        return StatRange(start: DateTime(now.year, now.month, now.day), end: now, label: label(now), kind: kind);
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

  /// Month name for calendar headers.
  String copyMonthName(int m) => monthName(m);

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

  /// Today compares with the same hours yesterday; other windows with the
  /// window of equal length just before.
  DateTime get previousStart => kind == RangeKind.today ? start.subtract(const Duration(days: 1)) : start.subtract(span);
  DateTime get previousEnd => kind == RangeKind.today ? end.subtract(const Duration(days: 1)) : start;

  /// Hourly buckets for windows up to two days, daily otherwise.
  bool get hourly => kind == RangeKind.today || span.inHours <= 48;
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
  String get previousEndSql => _sql(previousEnd);

  /// Stable key for caching results of this window. Rolling windows share a
  /// key per kind so the newest fetch replaces the previous one.
  String get cacheKey => switch (kind) {
        RangeKind.custom => 'custom_${start.millisecondsSinceEpoch}_${end.year}${end.month}${end.day}',
        RangeKind.thisMonth => 'month_${start.year}${start.month}',
        // Dated, so yesterday's numbers are never shown as today's.
        RangeKind.today => 'today_${start.year}${start.month}${start.day}',
        _ => kind.name,
      };

  Map<String, dynamic> toJson() =>
      {'start': start.toIso8601String(), 'end': end.toIso8601String(), 'label': label, 'kind': kind.name};

  factory StatRange.fromJson(Map<String, dynamic> j) => StatRange(
        start: DateTime.parse(j['start'] as String),
        end: DateTime.parse(j['end'] as String),
        label: j['label'] as String,
        kind: RangeKind.values.byName(j['kind'] as String),
      );

  String get whereCurrent => 'timestamp >= $startSql AND timestamp < $endSql';
  String get wherePrevious => 'timestamp >= $previousStartSql AND timestamp < $previousEndSql';
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

  List<num> toJson() => [current, previous];
  factory Metric.fromJson(List<dynamic> j) => Metric(current: j[0] as num, previous: j[1] as num);
}

@immutable
class SeriesPoint {
  const SeriesPoint(this.t, this.v);
  final DateTime t;
  final num v;

  List<dynamic> toJson() => [t.toIso8601String(), v];
  factory SeriesPoint.fromJson(List<dynamic> j) => SeriesPoint(DateTime.parse(j[0] as String), j[1] as num);
}

@immutable
class TopEvent {
  const TopEvent(this.name, this.count);
  final String name;
  final num count;

  List<dynamic> toJson() => [name, count];
  factory TopEvent.fromJson(List<dynamic> j) => TopEvent(j[0] as String, j[1] as num);
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
    this.fromCache = false,
    this.offline = false,
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

  /// True when this is the last saved result shown because the network
  /// fetch failed; [fetchedAt] is then the time it was saved.
  final bool fromCache;

  /// The network fetch failed and this is the last saved copy.
  final bool offline;

  num get totalTop => topEvents.fold<num>(0, (a, e) => a + e.count);

  KeyStats asCached(DateTime savedAt, {bool offline = false}) => KeyStats(
        range: range,
        events: events,
        visitors: visitors,
        views: views,
        sessions: sessions,
        activeNow: activeNow,
        eventSeries: eventSeries,
        visitorSeries: visitorSeries,
        viewSeries: viewSeries,
        hourlySeries: hourlySeries,
        topEvents: topEvents,
        fetchedAt: savedAt,
        fromCache: true,
        offline: offline,
      );

  Map<String, dynamic> toJson() => {
        'range': range.toJson(),
        'events': events.toJson(),
        'visitors': visitors.toJson(),
        'views': views.toJson(),
        'sessions': sessions.toJson(),
        'activeNow': activeNow,
        'eventSeries': eventSeries.map((p) => p.toJson()).toList(),
        'visitorSeries': visitorSeries.map((p) => p.toJson()).toList(),
        'viewSeries': viewSeries.map((p) => p.toJson()).toList(),
        'hourlySeries': hourlySeries.map((p) => p.toJson()).toList(),
        'topEvents': topEvents.map((e) => e.toJson()).toList(),
        'fetchedAt': fetchedAt.toIso8601String(),
      };

  factory KeyStats.fromJson(Map<String, dynamic> j) {
    List<SeriesPoint> series(String k) =>
        (j[k] as List).map((e) => SeriesPoint.fromJson(e as List<dynamic>)).toList();
    return KeyStats(
      range: StatRange.fromJson(j['range'] as Map<String, dynamic>),
      events: Metric.fromJson(j['events'] as List<dynamic>),
      visitors: Metric.fromJson(j['visitors'] as List<dynamic>),
      views: Metric.fromJson(j['views'] as List<dynamic>),
      sessions: Metric.fromJson(j['sessions'] as List<dynamic>),
      activeNow: j['activeNow'] as num,
      eventSeries: series('eventSeries'),
      visitorSeries: series('visitorSeries'),
      viewSeries: series('viewSeries'),
      hourlySeries: series('hourlySeries'),
      topEvents: (j['topEvents'] as List).map((e) => TopEvent.fromJson(e as List<dynamic>)).toList(),
      fetchedAt: DateTime.parse(j['fetchedAt'] as String),
    );
  }
  final DateTime fetchedAt;
}

@immutable
class QueryResult {
  const QueryResult({required this.columns, required this.rows, this.fromCache = false, this.offline = false, this.savedAt, this.previous});
  final List<String> columns;
  final List<List<dynamic>> rows;
  final bool fromCache;
  final bool offline;
  final DateTime? savedAt;

  /// First cell of the same query over the previous window, when compared.
  final num? previous;

  bool get isEmpty => rows.isEmpty;

  double? get delta {
    final cur = firstCell;
    if (previous == null || cur is! num) return null;
    return Metric(current: cur, previous: previous!).delta;
  }

  QueryResult asCached(DateTime at, {bool offline = false}) =>
      QueryResult(columns: columns, rows: rows, fromCache: true, offline: offline, savedAt: at, previous: previous);
  QueryResult withPrevious(num? p) => QueryResult(columns: columns, rows: rows, fromCache: fromCache, savedAt: savedAt, previous: p);
  Map<String, dynamic> toJson() => {'columns': columns, 'rows': rows, 'previous': previous};
  factory QueryResult.fromJson(Map<String, dynamic> j) => QueryResult(
        columns: (j['columns'] as List).map((c) => c.toString()).toList(),
        rows: (j['rows'] as List).map((r) => (r as List).cast<dynamic>()).toList(),
        previous: j['previous'] as num?,
      );
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

  Map<String, dynamic> toCache() =>
      {'id': id, 'key': key, 'name': name, 'active': active, 'rollout': rolloutPercentage, 'createdAt': createdAt?.toIso8601String()};

  factory FeatureFlag.fromCache(Map<String, dynamic> j) => FeatureFlag(
        id: (j['id'] as num).toInt(),
        key: j['key'] as String,
        name: j['name'] as String,
        active: j['active'] as bool,
        rolloutPercentage: (j['rollout'] as num?)?.toInt(),
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? ''),
      );

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

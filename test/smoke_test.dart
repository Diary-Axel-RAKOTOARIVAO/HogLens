import 'package:flutter_test/flutter_test.dart';
import 'package:hoglens/data/api/stats_repository.dart';
import 'package:hoglens/data/models/project.dart';
import 'package:hoglens/data/models/stats.dart';
import 'package:hoglens/data/models/widget_spec.dart';

void main() {
  test('project json round-trips and derives host label', () {
    final p = PhProject(
      id: 'x',
      name: 'Madarent App',
      host: 'https://eu.posthog.com',
      projectId: 42,
      accentIndex: 3,
      createdAt: DateTime(2026, 9, 28),
    );
    final back = PhProject.fromJson(p.toJson());
    expect(back.name, 'Madarent App');
    expect(back.projectId, 42);
    expect(back.hostKind, PhHost.eu);
    expect(back.initials, 'MA');
    expect(PhProject.fromJson({...p.toJson(), 'host': 'https://ph.example.com'}).hostLabel, 'ph.example.com');
  });

  test('widget spec json round-trips', () {
    const w = StatWidgetSpec(id: '1', title: 'T', hogql: 'SELECT 1', kind: WidgetKind.bars, size: WidgetSize.full);
    final back = StatWidgetSpec.fromJson(w.toJson());
    expect(back.kind, WidgetKind.bars);
    expect(back.size, WidgetSize.full);
  });

  test('range placeholder resolves to the window start', () {
    final r = RangeSelection.week.resolve(DateTime(2026, 9, 28, 12));
    expect(StatsRepository.resolve('WHERE t >= {range}', r), startsWith("WHERE t >= toDateTime('2026-09-21"));
    expect(r.bucketCount, 8);
    expect(r.hourly, isFalse);
  });

  test('this month and custom ranges resolve', () {
    final now = DateTime(2026, 9, 28, 12);
    final m = RangeSelection.thisMonth.resolve(now);
    expect(m.start, DateTime(2026, 9, 1));
    expect(m.label, 'September');
    expect(m.bucketCount, 28);
    final c = RangeSelection(RangeKind.custom, customStart: DateTime(2026, 9, 3), customEnd: DateTime(2026, 9, 9)).resolve(now);
    expect(c.start, DateTime(2026, 9, 3));
    expect(c.end, DateTime(2026, 9, 10));
    expect(c.bucketCount, 7);
    expect(c.label, 'Sep 3 – Sep 9');
    expect(RangeSelection.day.resolve(now).hourly, isTrue);
    expect(RangeSelection.day.resolve(now).bucketCount, 24);
  });

  test('metric delta', () {
    expect(const Metric(current: 120, previous: 100).delta, closeTo(0.2, 1e-9));
    expect(const Metric(current: 5, previous: 0).delta, isNull);
    expect(const Metric(current: 0, previous: 0).delta, 0);
  });
}

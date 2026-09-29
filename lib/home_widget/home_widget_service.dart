import 'dart:io';

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:workmanager/workmanager.dart';

import '../core/i18n.dart';
import '../core/util/format.dart';
import '../data/api/demo_client.dart';
import '../data/api/insights_repository.dart';
import '../data/api/posthog_client.dart';
import '../data/api/stats_repository.dart';
import '../data/models/insights.dart';
import '../data/models/project.dart';
import '../data/models/stats.dart';
import '../data/storage/project_store.dart';

const _taskName = 'mg.aureon.hoglens.widgetRefresh';

/// The Android home-screen widgets, smallest to largest. `androidName` is
/// the AppWidgetProvider class; the cell size matches its provider XML.
enum HomeWidgetKind {
  small('HogLensSmallWidgetProvider', 'Visitors', '2 × 1', 'Today’s unique visitors, nothing else.'),
  live('HogLensLiveWidgetProvider', 'Live now', '2 × 2', 'People on the site in the last five minutes.'),
  errors('HogLensErrorsWidgetProvider', 'Errors', '2 × 2', 'Exceptions today and the most frequent one.'),
  medium('HogLensWidgetProvider', 'Week', '3 × 2', 'Visitors today, change versus yesterday, seven-day strip.'),
  overview('HogLensOverviewWidgetProvider', 'Overview', '4 × 2', 'Visitors, views, sessions and live, side by side.'),
  trend('HogLensTrendWidgetProvider', 'Trend', '4 × 3', 'Today’s hourly curve with the key numbers.');

  const HomeWidgetKind(this.androidName, this.title, this.cells, this.description);
  final String androidName;
  final String title;
  final String cells;
  final String description;
}

/// Feeds every widget from a shared set of values and keeps them fresh in
/// the background every 30 minutes.
class HomeWidgetService {
  static bool get supported => Platform.isAndroid;

  static Future<void> init() async {
    if (!supported) return;
    await Workmanager().initialize(widgetCallbackDispatcher);
    await Workmanager().registerPeriodicTask(
      _taskName,
      _taskName,
      frequency: const Duration(minutes: 30),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }

  static Future<void> _save(Map<String, Object?> values) async {
    for (final e in values.entries) {
      final v = e.value;
      if (v == null) continue;
      if (v is int) {
        await HomeWidget.saveWidgetData<int>(e.key, v);
      } else {
        await HomeWidget.saveWidgetData<String>(e.key, '$v');
      }
    }
  }

  static Future<void> _refreshAll() async {
    for (final k in HomeWidgetKind.values) {
      await HomeWidget.updateWidget(name: k.androidName, androidName: k.androidName);
    }
  }

  static Map<String, Object?> _labels(PhProject project) => {
        'title': project.name,
        'accent': project.accent.toARGB32(),
        'l_visitors_today': tr('visitors today'),
        'l_on_site': tr('on site now'),
        'l_live': tr('LIVE'),
        'l_views': tr('Views'),
        'l_sessions': tr('Sessions'),
        'l_visitors': tr('Visitors'),
        'l_errors_today': tr('errors today'),
        'l_updated': tr('Updated'),
        'l_this_week': tr('this week'),
        'updated': Fmt.hour(DateTime.now()),
      };

  /// Visitors today, yesterday delta, week total and the seven-day strip.
  static Future<void> pushGlance(PhProject project, Glance glance) async {
    if (!supported) return;
    try {
      final today = glance.today;
      final yesterday = glance.daily.length >= 2 ? glance.daily[glance.daily.length - 2] : 0;
      final delta = Metric(current: today, previous: yesterday).delta;
      await _save({
        ..._labels(project),
        'visitors': Fmt.compact(today),
        'week': '${Fmt.compact(glance.week)} ${tr('this week')}',
        'delta': delta == null ? '' : '${Fmt.percent(delta)} ${tr('vs yesterday')}',
        'deltaSign': delta == null ? 0 : (delta > 0 ? 1 : (delta < 0 ? -1 : 0)),
      });
      await HomeWidget.renderFlutterWidget(
        _Bars(values: glance.daily, color: project.accent),
        key: 'bars',
        logicalSize: const Size(140, 36),
        pixelRatio: 3,
      );
      await _refreshAll();
    } catch (_) {}
  }

  /// Views, sessions, live count and the hourly curve for today.
  static Future<void> pushToday(PhProject project, KeyStats s) async {
    if (!supported || s.range.kind != RangeKind.today) return;
    try {
      await _save({
        ..._labels(project),
        'views': Fmt.compact(s.views.current),
        'sessions': Fmt.compact(s.sessions.current),
        'live': Fmt.full(s.activeNow),
      });
      await HomeWidget.renderFlutterWidget(
        _Spark(points: s.visitorSeries.map((p) => p.v).toList(), color: project.accent),
        key: 'spark',
        logicalSize: const Size(300, 70),
        pixelRatio: 3,
      );
      await _refreshAll();
    } catch (_) {}
  }

  static Future<void> pushErrors(PhProject project, ErrorsReport r) async {
    if (!supported) return;
    try {
      await _save({
        ..._labels(project),
        'errors': Fmt.compact(r.total),
        'topError': r.groups.isEmpty ? tr('No errors today') : '${r.groups.first.type}: ${r.groups.first.message}',
      });
      await _refreshAll();
    } catch (_) {}
  }

  /// Full refresh without the app running: glance, today's stats, errors.
  static Future<bool> refreshInBackground() async {
    try {
      final store = await ProjectStore.open();
      final id = store.widgetProjectId;
      if (id == null) return true;
      final project = store.loadProjects().where((p) => p.id == id).firstOrNull;
      if (project == null) return true;
      final PhApi client;
      if (project.isDemo) {
        client = DemoClient();
      } else {
        final key = await store.readKey(project.id);
        if (key == null) return true;
        client = PosthogClient(host: project.host, apiKey: key);
      }
      final lang = store.prefs.getString('hoglens.language');
      currentLanguage = AppLanguage.values.asNameMap()[lang ?? ''] ?? AppLanguage.en;

      const isView = "event IN ('\$pageview', '\$screen')";
      const window = 'timestamp >= toStartOfDay(now()) - INTERVAL 6 DAY AND timestamp <= now()';
      final results = await Future.wait([
        client.query(project.projectId,
            'SELECT toStartOfDay(timestamp) AS d, uniq(person_id) FROM events WHERE $isView AND $window GROUP BY d ORDER BY d',
            name: 'hoglens_glance'),
        client.query(project.projectId, 'SELECT uniq(person_id) FROM events WHERE $isView AND $window', name: 'hoglens_glance_week'),
      ]);
      final pts = <SeriesPoint>[];
      for (final row in results[0].rows) {
        final t = DateTime.tryParse('${row[0]}')?.toLocal();
        final v = row.length > 1 ? row[1] : 0;
        if (t != null) pts.add(SeriesPoint(t, v is num ? v : num.tryParse('$v') ?? 0));
      }
      final now = DateTime.now();
      final weekRange = StatRange(start: DateTime(now.year, now.month, now.day - 6), end: now, label: '7d', kind: RangeKind.week);
      final w = results[1].firstCell;
      await pushGlance(project, Glance(daily: StatsRepository.fill(pts, weekRange).map((p) => p.v).toList(), week: w is num ? w : 0));

      final today = RangeSelection.today.resolve(now);
      final stats = await StatsRepository(client, project.projectId).fetch(today);
      await pushToday(project, stats);
      final errors = await InsightsRepository(client, project.projectId).errors(today);
      await pushErrors(project, errors);
      return true;
    } catch (_) {
      return false;
    }
  }
}

@pragma('vm:entry-point')
void widgetCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    return HomeWidgetService.refreshInBackground();
  });
}

class _Bars extends StatelessWidget {
  const _Bars({required this.values, required this.color});
  final List<num> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final max = values.fold<double>(0, (a, b) => b > a ? b.toDouble() : a);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++) ...[
            Expanded(
              child: Container(
                height: max == 0 ? 4 : 4 + 32 * values[i] / max,
                decoration: BoxDecoration(
                  color: i == values.length - 1 ? color : color.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            if (i != values.length - 1) const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }
}

/// Smooth area curve rendered to a bitmap for the large widget.
class _Spark extends StatelessWidget {
  const _Spark({required this.points, required this.color});
  final List<num> points;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: CustomPaint(size: const Size(300, 70), painter: _SparkPainter(points, color)),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.points, this.color);
  final List<num> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final max = points.fold<double>(0, (a, b) => b > a ? b.toDouble() : a);
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = size.width * i / (points.length - 1);
      final y = max == 0 ? size.height - 2 : size.height - 4 - (size.height - 8) * points[i] / max;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        final px = size.width * (i - 1) / (points.length - 1);
        final py = max == 0 ? size.height - 2 : size.height - 4 - (size.height - 8) * points[i - 1] / max;
        path.cubicTo(px + (x - px) / 2, py, px + (x - px) / 2, y, x, y);
      }
    }
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) => old.points != points || old.color != color;
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:workmanager/workmanager.dart';

import '../core/util/format.dart';
import '../data/api/demo_client.dart';
import '../data/api/posthog_client.dart';
import '../data/api/stats_repository.dart';
import '../data/models/insights.dart';
import '../data/models/project.dart';
import '../data/models/stats.dart';
import '../data/storage/project_store.dart';

const _providerName = 'HogLensWidgetProvider';
const _taskName = 'mg.aureon.hoglens.widgetRefresh';

/// Feeds the Android home-screen widget: writes the numbers and a rendered
/// bar strip, and keeps them fresh every 30 minutes in the background.
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

  static Future<void> push(PhProject project, Glance glance) async {
    if (!supported) return;
    try {
      final today = glance.today;
      final yesterday = glance.daily.length >= 2 ? glance.daily[glance.daily.length - 2] : 0;
      final delta = Metric(current: today, previous: yesterday).delta;
      await HomeWidget.saveWidgetData<String>('title', project.name);
      await HomeWidget.saveWidgetData<String>('visitors', Fmt.compact(today));
      await HomeWidget.saveWidgetData<String>('week', '${Fmt.compact(glance.week)} this week');
      await HomeWidget.saveWidgetData<String>('delta', delta == null ? '' : '${Fmt.percent(delta)} vs yesterday');
      await HomeWidget.saveWidgetData<int>('deltaSign', delta == null ? 0 : (delta > 0 ? 1 : (delta < 0 ? -1 : 0)));
      await HomeWidget.saveWidgetData<String>('updated', Fmt.hour(DateTime.now()));
      await HomeWidget.saveWidgetData<int>('accent', project.accent.toARGB32());
      await HomeWidget.renderFlutterWidget(
        _Bars(values: glance.daily, color: project.accent),
        key: 'bars',
        logicalSize: const Size(140, 36),
        pixelRatio: 3,
      );
      await HomeWidget.updateWidget(name: _providerName, androidName: _providerName);
    } catch (_) {
      // The widget is a convenience; never let it break the app.
    }
  }

  /// Fetches the widget project's numbers without the app running.
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
      final range = StatRange(start: DateTime(now.year, now.month, now.day - 6), end: now, label: '7d', kind: RangeKind.week);
      final w = results[1].firstCell;
      await push(project, Glance(daily: StatsRepository.fill(pts, range).map((p) => p.v).toList(), week: w is num ? w : 0));
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

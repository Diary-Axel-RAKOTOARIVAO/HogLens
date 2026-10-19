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

  /// Provider class names of the HogLens widgets currently on the home
  /// screen. Empty for most people, in which case nothing is written or
  /// rendered at all.
  static Future<Set<String>> _installed() async {
    try {
      final list = await HomeWidget.getInstalledWidgets();
      return {for (final w in list) (w.androidClassName ?? '').split('.').last}..remove('');
    } catch (_) {
      return const {};
    }
  }

  static Future<void> _refresh(Set<String> installed) async {
    for (final k in HomeWidgetKind.values) {
      if (installed.contains(k.androidName)) {
        await HomeWidget.updateWidget(name: k.androidName, androidName: k.androidName);
      }
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
      final installed = await _installed();
      if (installed.isEmpty) return;
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
      // The widget draws the bars itself from these numbers (Android Canvas),
      // so nothing is rendered offscreen by Flutter.
      await HomeWidget.saveWidgetData<String>('barsData', glance.daily.join(','));
      await _refresh(installed);
    } catch (_) {}
  }

  /// Views, sessions, live count and the hourly curve for today.
  static Future<void> pushToday(PhProject project, KeyStats s) async {
    if (!supported || s.range.kind != RangeKind.today) return;
    try {
      final installed = await _installed();
      if (installed.isEmpty) return;
      await _save({
        ..._labels(project),
        'views': Fmt.compact(s.views.current),
        'sessions': Fmt.compact(s.sessions.current),
        'live': Fmt.full(s.activeNow),
      });
      await HomeWidget.saveWidgetData<String>('sparkData', s.visitorSeries.map((p) => p.v).join(','));
      await _refresh(installed);
    } catch (_) {}
  }

  static Future<void> pushErrors(PhProject project, ErrorsReport r) async {
    if (!supported) return;
    try {
      final installed = await _installed();
      if (installed.isEmpty) return;
      await _save({
        ..._labels(project),
        'errors': Fmt.compact(r.total),
        'topError': r.groups.isEmpty ? tr('No errors today') : '${r.groups.first.type}: ${r.groups.first.message}',
      });
      await _refresh(installed);
    } catch (_) {}
  }

  /// Full refresh without the app running: glance, today's stats, errors.
  static Future<bool> refreshInBackground() async {
    try {
      if ((await _installed()).isEmpty) return true;
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

      await pushGlance(project, await StatsRepository(client, project.projectId).glance());
      final now = DateTime.now();
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

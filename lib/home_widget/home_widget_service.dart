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
/// `ranged` kinds can show Today, 7 days or 30 days; the others are fixed.
enum HomeWidgetKind {
  project('HogLensProjectWidgetProvider', 'Project card', '4 × 1', 'The card from the home screen: logo, visitors today and the week.', false),
  small('HogLensSmallWidgetProvider', 'Visitors', '2 × 1', 'Visitors for the period you pick, nothing else.', true),
  live('HogLensLiveWidgetProvider', 'Live now', '2 × 2', 'People on the site in the last five minutes. Tap to open the live feed.', false),
  errors('HogLensErrorsWidgetProvider', 'Errors', '2 × 2', 'Exceptions and the most frequent one. Tap to open Errors.', true),
  medium('HogLensWidgetProvider', 'Week', '3 × 2', 'Visitors today, change versus yesterday, seven-day strip.', false),
  overview('HogLensOverviewWidgetProvider', 'Overview', '4 × 2', 'Visitors, views, sessions and live, side by side.', true),
  trend('HogLensTrendWidgetProvider', 'Trend', '4 × 3', 'The curve for the period with the key numbers.', true);

  const HomeWidgetKind(this.androidName, this.title, this.cells, this.description, this.ranged);
  final String androidName;
  final String title;
  final String cells;
  final String description;
  final bool ranged;

  static HomeWidgetKind? byClass(String? name) =>
      HomeWidgetKind.values.where((k) => k.androidName == (name ?? '').split('.').last).firstOrNull;
}

/// Period a widget covers.
enum WidgetRange {
  today('today', 'Today', RangeKind.today),
  week('week', '7 days', RangeKind.week),
  month('month', '30 days', RangeKind.month);

  const WidgetRange(this.key, this.label, this.kind);
  final String key;
  final String label;
  final RangeKind kind;

  RangeSelection get selection => RangeSelection(kind);

  static WidgetRange fromKey(String? k) => WidgetRange.values.where((r) => r.key == k).firstOrNull ?? WidgetRange.today;
}

/// One widget instance on the home screen with its own project and period.
class PlacedWidget {
  const PlacedWidget(this.id, this.kind, this.projectId, this.range);
  final int id;
  final HomeWidgetKind kind;
  final String projectId;
  final WidgetRange range;
}

/// Feeds every widget from per-project, per-period values (`p_<project>_<range>_*`)
/// and keeps them fresh in the background every 30 minutes.
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
    await HomeWidget.registerInteractivityCallback(widgetInteractivity);
  }

  static String _prefix(String projectId, WidgetRange r) => 'p_${projectId}_${r.key}_';

  static Future<void> _save(String prefix, Map<String, Object?> values) async {
    for (final e in values.entries) {
      final v = e.value;
      if (v == null) continue;
      if (v is int) {
        await HomeWidget.saveWidgetData<int>('$prefix${e.key}', v);
      } else {
        await HomeWidget.saveWidgetData<String>('$prefix${e.key}', '$v');
      }
    }
  }

  /// Widgets currently on the home screen, with their project and period.
  /// Widgets without a stored choice get the default project and Today, and
  /// that choice is written back so the native side finds their data.
  static Future<List<PlacedWidget>> placed(ProjectStore store) async {
    if (!supported) return const [];
    try {
      final out = <PlacedWidget>[];
      final fallback = store.widgetProjectId;
      for (final w in await HomeWidget.getInstalledWidgets()) {
        final id = w.androidWidgetId;
        final kind = HomeWidgetKind.byClass(w.androidClassName);
        if (id == null || kind == null) continue;
        var pid = await HomeWidget.getWidgetData<String>('cfg_${id}_project');
        var range = await HomeWidget.getWidgetData<String>('cfg_${id}_range');
        if (pid == null) {
          if (fallback == null) continue;
          pid = fallback;
          await HomeWidget.saveWidgetData<String>('cfg_${id}_project', pid);
          await HomeWidget.saveWidgetData<String>('cfg_${id}_range', WidgetRange.today.key);
        }
        out.add(PlacedWidget(id, kind, pid, kind.ranged ? WidgetRange.fromKey(range) : WidgetRange.today));
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  /// Changes the project and period of one placed widget and redraws it.
  static Future<void> configure(PlacedWidget w, String projectId, WidgetRange range, ProjectStore store) async {
    await HomeWidget.saveWidgetData<String>('cfg_${w.id}_project', projectId);
    await HomeWidget.saveWidgetData<String>('cfg_${w.id}_range', range.key);
    await refreshAll(store: store);
  }

  static Future<void> _redraw() async {
    for (final k in HomeWidgetKind.values) {
      await HomeWidget.updateWidget(name: k.androidName, androidName: k.androidName);
    }
  }

  static Future<bool> _isUsed(String projectId, WidgetRange r) async {
    final store = await ProjectStore.open();
    final list = await placed(store);
    return list.any((w) => w.projectId == projectId && w.range == r);
  }

  static Map<String, Object?> _labels(PhProject project, WidgetRange r) {
    final suffix = switch (r) {
      WidgetRange.today => '',
      WidgetRange.week => ' · 7d',
      WidgetRange.month => ' · 30d',
    };
    final period = switch (r) {
      WidgetRange.today => tr('today'),
      WidgetRange.week => tr('7 days'),
      WidgetRange.month => tr('30 days'),
    };
    final now = DateTime.now();
    return {
      'title': '${project.name}$suffix',
      'accent': project.accent.toARGB32(),
      'initials': project.initials,
      'logo': project.logoPath ?? '',
      'host': project.hostLabel,
      'pid': '#${project.projectId}',
      'l_visitors_today': r == WidgetRange.today ? tr('visitors today') : '${tr('visitors')}, $period',
      'l_on_site': tr('on site now'),
      'l_live': tr('LIVE'),
      'l_views': tr('Views'),
      'l_sessions': tr('Sessions'),
      'l_visitors': tr('Visitors'),
      'l_errors_today': r == WidgetRange.today ? tr('errors today') : '${tr('errors')}, $period',
      'l_updated': tr('Updated'),
      'l_stale': tr('Stale'),
      'l_this_week': tr('this week'),
      'updated': Fmt.hour(now),
      'updatedAt': '${now.millisecondsSinceEpoch}',
    };
  }

  /// Visitors today, yesterday delta, week total and the seven-day strip.
  static Future<void> pushGlance(PhProject project, Glance glance, {bool force = false}) async {
    if (!supported) return;
    try {
      if (!force && !await _isUsed(project.id, WidgetRange.today)) return;
      final today = glance.today;
      final yesterday = glance.daily.length >= 2 ? glance.daily[glance.daily.length - 2] : 0;
      final delta = Metric(current: today, previous: yesterday).delta;
      final prefix = _prefix(project.id, WidgetRange.today);
      await _save(prefix, {
        ..._labels(project, WidgetRange.today),
        'visitors': Fmt.compact(today),
        'week': '${Fmt.compact(glance.week)} ${tr('this week')}',
        'delta': delta == null ? '' : '${Fmt.percent(delta)} ${tr('vs yesterday')}',
        'deltaSign': delta == null ? 0 : (delta > 0 ? 1 : (delta < 0 ? -1 : 0)),
      });
      // The widget draws the bars itself from these numbers (Android Canvas),
      // so nothing is rendered offscreen by Flutter.
      await HomeWidget.saveWidgetData<String>('${prefix}barsData', glance.daily.join(','));
      await _redraw();
    } catch (_) {}
  }

  /// Views, sessions, live count and the hourly curve for today.
  static Future<void> pushToday(PhProject project, KeyStats s, {bool force = false}) async {
    if (!supported || s.range.kind != RangeKind.today) return;
    try {
      if (!force && !await _isUsed(project.id, WidgetRange.today)) return;
      final prefix = _prefix(project.id, WidgetRange.today);
      await _save(prefix, {
        ..._labels(project, WidgetRange.today),
        'views': Fmt.compact(s.views.current),
        'sessions': Fmt.compact(s.sessions.current),
        'live': Fmt.full(s.activeNow),
      });
      await HomeWidget.saveWidgetData<String>('${prefix}sparkData', s.visitorSeries.map((p) => p.v).join(','));
      await _redraw();
    } catch (_) {}
  }

  static Future<void> pushErrors(PhProject project, ErrorsReport r, {WidgetRange range = WidgetRange.today, bool force = false}) async {
    if (!supported) return;
    try {
      if (!force && !await _isUsed(project.id, range)) return;
      await _save(_prefix(project.id, range), {
        ..._labels(project, range),
        'errors': Fmt.compact(r.total),
        'topError': r.groups.isEmpty
            ? (range == WidgetRange.today ? tr('No errors today') : tr('No errors'))
            : '${r.groups.first.type}: ${r.groups.first.message}',
      });
      await _redraw();
    } catch (_) {}
  }

  /// A 7- or 30-day period: everything comes from one stats fetch.
  static Future<void> _pushPeriod(PhProject project, WidgetRange r, KeyStats s) async {
    final prefix = _prefix(project.id, r);
    final delta = s.visitors.delta;
    await _save(prefix, {
      ..._labels(project, r),
      'visitors': Fmt.compact(s.visitors.current),
      'views': Fmt.compact(s.views.current),
      'sessions': Fmt.compact(s.sessions.current),
      'live': Fmt.full(s.activeNow),
      'delta': delta == null ? '' : '${Fmt.percent(delta)} ${tr('vs previous')}',
      'deltaSign': delta == null ? 0 : (delta > 0 ? 1 : (delta < 0 ? -1 : 0)),
    });
    await HomeWidget.saveWidgetData<String>('${prefix}sparkData', s.visitorSeries.map((p) => p.v).join(','));
  }

  static Future<PhApi?> _clientFor(ProjectStore store, PhProject project) async {
    if (project.isDemo) return DemoClient();
    final key = await store.readKey(project.id);
    if (key == null) return null;
    return PosthogClient(host: project.host, apiKey: key);
  }

  /// Fetches and writes one project and period. Used for refreshes and before
  /// pinning, so a new widget has data the moment it appears.
  static Future<void> refreshPair(ProjectStore store, PhProject project, WidgetRange r) async {
    final client = await _clientFor(store, project);
    if (client == null) return;
    final repo = StatsRepository(client, project.projectId);
    final range = r.selection.resolve(DateTime.now());
    if (r == WidgetRange.today) {
      await pushGlance(project, await repo.glance(), force: true);
      await pushToday(project, await repo.fetch(range), force: true);
    } else {
      await _pushPeriod(project, r, await repo.fetch(range));
    }
    await pushErrors(project, await InsightsRepository(client, project.projectId).errors(range), range: r, force: true);
  }

  /// Chosen project and period are stored first, then the new widget adopts
  /// them when Android creates it.
  static Future<void> pin(HomeWidgetKind kind, PhProject project, WidgetRange range, ProjectStore store) async {
    final r = kind.ranged ? range : WidgetRange.today;
    await HomeWidget.saveWidgetData<String>('pending_project', project.id);
    await HomeWidget.saveWidgetData<String>('pending_range', r.key);
    try {
      await refreshPair(store, project, r);
    } catch (_) {}
    await HomeWidget.requestPinWidget(name: kind.androidName, androidName: kind.androidName);
  }

  /// Refreshes every project and period that a placed widget uses.
  static Future<bool> refreshAll({ProjectStore? store}) async {
    var ok = true;
    try {
      store ??= await ProjectStore.open();
      final list = await placed(store);
      if (list.isEmpty) return true;
      final lang = store.prefs.getString('hoglens.language');
      currentLanguage = AppLanguage.values.asNameMap()[lang ?? ''] ?? AppLanguage.en;
      final projects = {for (final p in store.loadProjects()) p.id: p};
      final pairs = {for (final w in list) '${w.projectId}|${w.range.key}': (w.projectId, w.range)};
      for (final (pid, range) in pairs.values) {
        final project = projects[pid];
        if (project == null) continue;
        try {
          await refreshPair(store, project, range);
        } catch (_) {
          ok = false;
        }
      }
      await _redraw();
    } catch (_) {
      return false;
    }
    return ok;
  }

  /// Full refresh without the app running.
  static Future<bool> refreshInBackground() => refreshAll();
}

@pragma('vm:entry-point')
void widgetCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    return HomeWidgetService.refreshInBackground();
  });
}

/// Runs when someone taps a widget's refresh label.
@pragma('vm:entry-point')
Future<void> widgetInteractivity(Uri? uri) async {
  WidgetsFlutterBinding.ensureInitialized();
  await HomeWidgetService.refreshInBackground();
}

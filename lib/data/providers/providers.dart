import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../api/demo_client.dart';
import '../api/posthog_client.dart';
import '../api/stats_repository.dart';
import '../models/project.dart';
import '../models/stats.dart';
import '../models/widget_spec.dart';
import '../storage/cache_store.dart';
import '../storage/project_store.dart';

/// Opened once in main() and overridden into the ProviderScope.
final storeProvider = Provider<ProjectStore>((ref) => throw UnimplementedError());
final cacheProvider = Provider<CacheStore>((ref) => throw UnimplementedError());

/// Emits the last saved value first (marked as cached), then the fresh one.
/// If the fetch fails and a saved value exists, that value is kept.
Future<T> _cached<T>({
  required void Function(T stale) emit,
  required CacheStore cache,
  required String key,
  required T Function(Map<String, dynamic> data, DateTime savedAt) decode,
  required Map<String, dynamic> Function(T value) encode,
  required Future<T> Function() fetch,
}) async {
  T? stale;
  final saved = await cache.read(key);
  if (saved != null) {
    try {
      stale = decode(saved.$1, saved.$2);
      emit(stale as T);
    } catch (_) {
      stale = null;
    }
  }
  try {
    final fresh = await fetch();
    await cache.write(key, encode(fresh));
    return fresh;
  } catch (e) {
    if (stale != null) return stale;
    rethrow;
  }
}

// ---- projects -----------------------------------------------------------

class ProjectsNotifier extends Notifier<List<PhProject>> {
  @override
  List<PhProject> build() => ref.read(storeProvider).loadProjects();

  ProjectStore get _store => ref.read(storeProvider);

  Future<PhProject> add({
    required String name,
    required String host,
    required int projectId,
    required String apiKey,
    File? logo,
    int accentIndex = 0,
  }) async {
    final id = const Uuid().v4();
    await _store.writeKey(id, apiKey);
    String? logoPath;
    if (logo != null) logoPath = await _store.storeLogo(id, logo);
    final p = PhProject(
      id: id,
      name: name,
      host: host,
      projectId: projectId,
      logoPath: logoPath,
      accentIndex: accentIndex,
      createdAt: DateTime.now(),
    );
    state = [...state, p];
    await _store.saveProjects(state);
    return p;
  }

  Future<void> update(PhProject updated, {File? newLogo, bool removeLogo = false, String? newKey}) async {
    var p = updated;
    if (removeLogo) {
      await _store.deleteLogo(p.logoPath);
      p = p.copyWith(clearLogo: true);
    } else if (newLogo != null) {
      await _store.deleteLogo(p.logoPath);
      p = p.copyWith(logoPath: await _store.storeLogo(p.id, newLogo));
    }
    if (newKey != null && newKey.isNotEmpty) {
      await _store.writeKey(p.id, newKey);
      ref.invalidate(apiKeyProvider(p.id));
    }
    state = [for (final x in state) x.id == p.id ? p : x];
    await _store.saveProjects(state);
  }

  Future<void> remove(String id) async {
    final p = state.where((x) => x.id == id).firstOrNull;
    await _store.deleteKey(id);
    await _store.deleteLogo(p?.logoPath);
    state = state.where((x) => x.id != id).toList();
    await _store.saveProjects(state);
    await ref.read(widgetsProvider.notifier).removeProject(id);
    await ref.read(cacheProvider).removeProject(id);
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final list = [...state];
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    state = list;
    await _store.saveProjects(state);
  }
}

final projectsProvider = NotifierProvider<ProjectsNotifier, List<PhProject>>(ProjectsNotifier.new);

final projectProvider = Provider.family<PhProject?, String>((ref, id) {
  return ref.watch(projectsProvider).where((p) => p.id == id).firstOrNull;
});

final apiKeyProvider = FutureProvider.family<String, String>((ref, projectId) async {
  final key = await ref.watch(storeProvider).readKey(projectId);
  if (key == null || key.isEmpty) throw PosthogException('No API key stored for this project.');
  return key;
});

final clientProvider = FutureProvider.family<PhApi, String>((ref, projectId) async {
  final project = ref.watch(projectProvider(projectId));
  if (project == null) throw PosthogException('Project removed.');
  if (project.isDemo) return DemoClient();
  final key = await ref.watch(apiKeyProvider(projectId).future);
  return PosthogClient(host: project.host, apiKey: key);
});

// ---- range & stats ------------------------------------------------------

class RangeNotifier extends Notifier<RangeSelection> {
  @override
  RangeSelection build() => RangeSelection.week;
  void set(RangeSelection r) => state = r;
}

final rangeProvider = NotifierProvider<RangeNotifier, RangeSelection>(RangeNotifier.new);

/// The selection resolved against "now". Re-resolved whenever the selection
/// changes or a dependent provider is invalidated.
StatRange currentRange(Ref ref) => ref.watch(rangeProvider).resolve(DateTime.now());

class KeyStatsNotifier extends AsyncNotifier<KeyStats> {
  KeyStatsNotifier(this.projectId);
  final String projectId;

  @override
  Future<KeyStats> build() async {
    final project = ref.watch(projectProvider(projectId));
    if (project == null) throw PosthogException('Project removed.');
    final range = currentRange(ref);
    final cache = ref.read(cacheProvider);
    return _cached<KeyStats>(
      emit: (v) => state = AsyncData(v),
      cache: cache,
      key: 'stats_${projectId}_${range.cacheKey}',
      decode: (d, at) => KeyStats.fromJson(d).asCached(at),
      encode: (v) => v.toJson(),
      fetch: () async {
        final client = await ref.watch(clientProvider(projectId).future);
        return StatsRepository(client, project.projectId).fetch(range);
      },
    );
  }
}

final keyStatsProvider = AsyncNotifierProvider.family<KeyStatsNotifier, KeyStats, String>(KeyStatsNotifier.new);

/// Daily event counts for the last 7 days (last element is today), used by
/// the project cards on the home screen. One query per project.
class GlanceNotifier extends AsyncNotifier<List<num>> {
  GlanceNotifier(this.projectId);
  final String projectId;

  @override
  Future<List<num>> build() async {
    final project = ref.watch(projectProvider(projectId));
    if (project == null) return const [];
    return _cached<List<num>>(
      emit: (v) => state = AsyncData(v),
      cache: ref.read(cacheProvider),
      key: 'glance_$projectId',
      decode: (d, _) => (d['v'] as List).cast<num>(),
      encode: (v) => {'v': v},
      fetch: () async {
        final client = await ref.watch(clientProvider(projectId).future);
        final r = await client.query(
          project.projectId,
          'SELECT toStartOfDay(timestamp) AS d, count() FROM events '
          'WHERE timestamp >= toStartOfDay(now()) - INTERVAL 6 DAY AND timestamp <= now() '
          'GROUP BY d ORDER BY d',
          name: 'hoglens_glance',
        );
        final pts = <SeriesPoint>[];
        for (final row in r.rows) {
          final t = DateTime.tryParse('${row[0]}')?.toLocal();
          final v = row.length > 1 ? row[1] : 0;
          if (t != null) pts.add(SeriesPoint(t, v is num ? v : num.tryParse('$v') ?? 0));
        }
        return StatsRepository.fill(pts, RangeSelection.week.resolve(DateTime.now())).map((p) => p.v).toList();
      },
    );
  }
}

final glanceProvider = AsyncNotifierProvider.family<GlanceNotifier, List<num>, String>(GlanceNotifier.new);

class FlagsNotifier extends AsyncNotifier<List<FeatureFlag>> {
  FlagsNotifier(this.projectId);
  final String projectId;

  @override
  Future<List<FeatureFlag>> build() async {
    final project = ref.watch(projectProvider(projectId));
    if (project == null) throw PosthogException('Project removed.');
    return _cached<List<FeatureFlag>>(
      emit: (v) => state = AsyncData(v),
      cache: ref.read(cacheProvider),
      key: 'flags_$projectId',
      decode: (d, _) => (d['v'] as List).map((f) => FeatureFlag.fromCache(f as Map<String, dynamic>)).toList(),
      encode: (v) => {'v': v.map((f) => f.toCache()).toList()},
      fetch: () async {
        final client = await ref.watch(clientProvider(projectId).future);
        return client.listFlags(project.projectId);
      },
    );
  }
}

final flagsProvider = AsyncNotifierProvider.family<FlagsNotifier, List<FeatureFlag>, String>(FlagsNotifier.new);

// ---- custom widgets -----------------------------------------------------

class WidgetsNotifier extends Notifier<Map<String, List<StatWidgetSpec>>> {
  @override
  Map<String, List<StatWidgetSpec>> build() => ref.read(storeProvider).loadWidgets();

  List<StatWidgetSpec> forProject(String projectId) => state[projectId] ?? const [];

  Future<void> _persist() => ref.read(storeProvider).saveWidgets(state);

  Future<StatWidgetSpec> add(String projectId, StatWidgetSpec spec) async {
    state = {...state, projectId: [...forProject(projectId), spec]};
    await _persist();
    return spec;
  }

  Future<void> update(String projectId, StatWidgetSpec spec) async {
    state = {
      ...state,
      projectId: [for (final w in forProject(projectId)) w.id == spec.id ? spec : w],
    };
    await _persist();
    ref.invalidate(widgetResultProvider((projectId, spec.id)));
  }

  Future<void> remove(String projectId, String widgetId) async {
    state = {...state, projectId: forProject(projectId).where((w) => w.id != widgetId).toList()};
    await _persist();
  }

  Future<void> reorder(String projectId, int oldIndex, int newIndex) async {
    final list = [...forProject(projectId)];
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    state = {...state, projectId: list};
    await _persist();
  }

  Future<void> removeProject(String projectId) async {
    final next = {...state}..remove(projectId);
    state = next;
    await _persist();
  }
}

final widgetsProvider =
    NotifierProvider<WidgetsNotifier, Map<String, List<StatWidgetSpec>>>(WidgetsNotifier.new);

final projectWidgetsProvider = Provider.family<List<StatWidgetSpec>, String>(
  (ref, projectId) => ref.watch(widgetsProvider)[projectId] ?? const [],
);

typedef CustomWidgetKey = (String projectId, String widgetId);

class WidgetResultNotifier extends AsyncNotifier<QueryResult> {
  WidgetResultNotifier(this.key);
  final CustomWidgetKey key;

  @override
  Future<QueryResult> build() async {
    final (projectId, widgetId) = key;
    final project = ref.watch(projectProvider(projectId));
    // Select only this widget's spec so adding or reordering siblings does not
    // refetch every widget (the API allows 3 concurrent queries).
    final spec = ref.watch(
      projectWidgetsProvider(projectId).select((l) => l.where((w) => w.id == widgetId).firstOrNull),
    );
    if (project == null || spec == null) throw PosthogException('Widget removed.');
    final range = currentRange(ref);
    return _cached<QueryResult>(
      emit: (v) => state = AsyncData(v),
      cache: ref.read(cacheProvider),
      key: 'widget_${projectId}_${widgetId}_${range.cacheKey}',
      decode: (d, at) => QueryResult.fromJson(d).asCached(at),
      encode: (v) => v.toJson(),
      fetch: () async {
        final client = await ref.watch(clientProvider(projectId).future);
        return client.query(project.projectId, StatsRepository.resolve(spec.hogql, range), name: 'hoglens_widget');
      },
    );
  }
}

final widgetResultProvider =
    AsyncNotifierProvider.family<WidgetResultNotifier, QueryResult, CustomWidgetKey>(WidgetResultNotifier.new);

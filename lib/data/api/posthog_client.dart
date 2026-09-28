import 'dart:async';
import 'dart:collection';

import 'package:dio/dio.dart';

import '../models/stats.dart';

class PosthogException implements Exception {
  PosthogException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

/// Read-only surface of PostHog that the app depends on.
abstract class PhApi {
  Future<List<RemoteProject>> listProjects();
  Future<RemoteProject> getProject(int projectId);
  Future<QueryResult> query(int projectId, String hogql, {String? name});
  Future<List<FeatureFlag>> listFlags(int projectId);
}

/// Thin client over the PostHog private API using a personal API key.
///
/// The query endpoint allows at most 3 concurrent queries per key, so all
/// calls go through a small semaphore.
class PosthogClient implements PhApi {
  PosthogClient({required String host, required String apiKey})
      : _dio = Dio(BaseOptions(
          baseUrl: host.endsWith('/') ? host.substring(0, host.length - 1) : host,
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
        ));

  final Dio _dio;
  final _Semaphore _slots = _Semaphore(3);

  /// Projects visible to this key. Used by the add-project flow.
  @override
  Future<List<RemoteProject>> listProjects() async {
    try {
      final res = await _guard(() => _dio.get('/api/projects/', queryParameters: {'limit': 100}));
      return _toProjects((res.data as Map)['results'] as List? ?? const []);
    } on PosthogException catch (e) {
      if (e.statusCode != 403) rethrow;
      // Project-scoped keys cannot hit /api/projects/, but /api/users/@me/
      // still lists the organization's teams. Not all of them will be
      // readable with this key; the add flow validates the pick.
      final res = await _guard(() => _dio.get('/api/users/@me/'));
      final org = (res.data as Map)['organization'];
      final teams = org is Map ? (org['teams'] as List? ?? const []) : const <dynamic>[];
      return _toProjects(teams);
    }
  }

  static List<RemoteProject> _toProjects(List<dynamic> raw) => raw
      .whereType<Map>()
      .map((p) => RemoteProject(
            id: (p['id'] as num).toInt(),
            name: (p['name'] as String?)?.trim().isNotEmpty == true
                ? p['name'] as String
                : 'Project ${p['id']}',
          ))
      .toList();

  @override
  Future<RemoteProject> getProject(int projectId) async {
    final res = await _guard(() => _dio.get('/api/projects/$projectId/'));
    final p = res.data as Map;
    return RemoteProject(id: (p['id'] as num).toInt(), name: p['name'] as String? ?? '');
  }

  /// Runs a HogQL query and returns columns + rows.
  @override
  Future<QueryResult> query(int projectId, String hogql, {String? name}) async {
    await _slots.acquire();
    try {
      final res = await _guard(() => _dio.post(
            '/api/projects/$projectId/query/',
            data: {
              'query': {'kind': 'HogQLQuery', 'query': hogql},
              'name': ?name,
            },
          ));
      final data = res.data as Map;
      final cols = ((data['columns'] as List?) ?? const []).map((c) => c.toString()).toList();
      final rows = ((data['results'] as List?) ?? const [])
          .map((r) => (r as List).cast<dynamic>())
          .toList();
      return QueryResult(columns: cols, rows: rows);
    } finally {
      _slots.release();
    }
  }

  @override
  Future<List<FeatureFlag>> listFlags(int projectId) async {
    final res = await _guard(() => _dio.get(
          '/api/projects/$projectId/feature_flags/',
          queryParameters: {'limit': 100},
        ));
    final results = (res.data as Map)['results'] as List;
    return results.map((f) => FeatureFlag.fromJson(f as Map<String, dynamic>)).toList();
  }

  Future<Response<dynamic>> _guard(Future<Response<dynamic>> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      final body = e.response?.data;
      String detail = '';
      if (body is Map && body['detail'] is String) detail = body['detail'] as String;
      switch (code) {
        case 401:
          throw PosthogException('Invalid or expired API key.', statusCode: code);
        case 403:
          throw PosthogException(
            detail.isEmpty
                ? 'This key lacks permission. It needs project:read and query:read scopes.'
                : detail,
            statusCode: code,
          );
        case 404:
          throw PosthogException('Project not found on this host.', statusCode: code);
        case 429:
          throw PosthogException('Rate limited by PostHog. Try again shortly.', statusCode: code);
        case null:
          final cause = e.error == null ? '' : ' (${e.error.runtimeType}: ${e.error})';
          throw PosthogException(
            e.type == DioExceptionType.connectionTimeout ||
                    e.type == DioExceptionType.receiveTimeout
                ? 'Timed out reaching PostHog.'
                : 'Could not reach ${_dio.options.baseUrl}$cause',
          );
        default:
          throw PosthogException(
            detail.isEmpty ? 'PostHog returned HTTP $code.' : detail,
            statusCode: code,
          );
      }
    }
  }
}

class _Semaphore {
  _Semaphore(this._free);
  int _free;
  final Queue<Completer<void>> _waiters = Queue();

  Future<void> acquire() {
    if (_free > 0) {
      _free--;
      return Future.value();
    }
    final c = Completer<void>();
    _waiters.add(c);
    return c.future;
  }

  void release() {
    if (_waiters.isNotEmpty) {
      _waiters.removeFirst().complete();
    } else {
      _free++;
    }
  }
}

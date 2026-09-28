import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Last-known API results, one JSON file per key, so the app can show data
/// without a connection. Values are wrapped with the time they were saved.
class CacheStore {
  CacheStore(this._dir);

  final Directory _dir;

  static Future<CacheStore> open() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/cache');
    if (!await dir.exists()) await dir.create(recursive: true);
    return CacheStore(dir);
  }

  File _file(String key) => File('${_dir.path}/${key.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_')}.json');

  Future<(Map<String, dynamic> data, DateTime savedAt)?> read(String key) async {
    try {
      final f = _file(key);
      if (!await f.exists()) return null;
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      final at = DateTime.tryParse(j['at'] as String? ?? '');
      final data = j['data'];
      if (at == null || data is! Map<String, dynamic>) return null;
      return (data, at);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String key, Map<String, dynamic> data) async {
    try {
      await _file(key).writeAsString(jsonEncode({'at': DateTime.now().toIso8601String(), 'data': data}));
    } catch (_) {
      // Caching is best effort.
    }
  }

  Future<void> removeProject(String projectId) async {
    try {
      await for (final e in _dir.list()) {
        if (e is File && e.uri.pathSegments.last.contains(projectId)) await e.delete();
      }
    } catch (_) {}
  }
}

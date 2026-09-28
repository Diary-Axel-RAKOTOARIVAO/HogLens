import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/project.dart';
import '../models/widget_spec.dart';

/// Persists project metadata (prefs), widget specs (prefs), and API keys
/// (Keychain / EncryptedSharedPreferences).
class ProjectStore {
  ProjectStore(this._prefs, this._secure);

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  /// Shared preferences for small app-level flags.
  SharedPreferences get prefs => _prefs;

  static const _widgetProjectKey = 'hoglens.widgetProject';

  /// Project shown on the Android home-screen widget (first project if unset).
  String? get widgetProjectId => _prefs.getString(_widgetProjectKey) ?? loadProjects().firstOrNull?.id;
  Future<void> setWidgetProjectId(String id) => _prefs.setString(_widgetProjectKey, id);

  static const _projectsKey = 'ph.projects.v1';
  static const _widgetsKey = 'ph.widgets.v1';
  static String _keyFor(String id) => 'ph.apikey.$id';

  static Future<ProjectStore> open() async {
    final prefs = await SharedPreferences.getInstance();
    const secure = FlutterSecureStorage(
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    );
    return ProjectStore(prefs, secure);
  }

  // ---- projects -------------------------------------------------------

  List<PhProject> loadProjects() {
    final raw = _prefs.getString(_projectsKey);
    if (raw == null) return const [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list.map(PhProject.fromJson).toList();
  }

  Future<void> saveProjects(List<PhProject> projects) =>
      _prefs.setString(_projectsKey, jsonEncode(projects.map((p) => p.toJson()).toList()));

  // ---- api keys -------------------------------------------------------

  Future<String?> readKey(String projectId) => _secure.read(key: _keyFor(projectId));
  Future<void> writeKey(String projectId, String key) =>
      _secure.write(key: _keyFor(projectId), value: key);
  Future<void> deleteKey(String projectId) => _secure.delete(key: _keyFor(projectId));

  // ---- logos ----------------------------------------------------------

  /// Copies [source] into the app documents directory and returns the path.
  Future<String> storeLogo(String projectId, File source) async {
    final dir = await getApplicationDocumentsDirectory();
    final logos = Directory('${dir.path}/logos');
    if (!await logos.exists()) await logos.create(recursive: true);
    final ext = source.path.split('.').last.toLowerCase();
    final target = File('${logos.path}/$projectId.${ext.isEmpty ? 'png' : ext}');
    await source.copy(target.path);
    return target.path;
  }

  Future<void> deleteLogo(String? path) async {
    if (path == null) return;
    final f = File(path);
    if (await f.exists()) await f.delete();
  }

  // ---- widgets --------------------------------------------------------

  Map<String, List<StatWidgetSpec>> loadWidgets() {
    final raw = _prefs.getString(_widgetsKey);
    if (raw == null) return {};
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return map.map((k, v) => MapEntry(
          k,
          (v as List).cast<Map<String, dynamic>>().map(StatWidgetSpec.fromJson).toList(),
        ));
  }

  Future<void> saveWidgets(Map<String, List<StatWidgetSpec>> all) => _prefs.setString(
        _widgetsKey,
        jsonEncode(all.map((k, v) => MapEntry(k, v.map((w) => w.toJson()).toList()))),
      );
}

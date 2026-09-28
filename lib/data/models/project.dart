import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

enum PhHost {
  us('https://us.posthog.com', 'US Cloud'),
  eu('https://eu.posthog.com', 'EU Cloud'),
  custom('', 'Self-hosted');

  const PhHost(this.baseUrl, this.label);
  final String baseUrl;
  final String label;
}

/// A PostHog project the user has added. The personal API key lives in
/// secure storage keyed by [id]; only metadata is persisted here.
@immutable
class PhProject {
  const PhProject({
    required this.id,
    required this.name,
    required this.host,
    required this.projectId,
    this.logoPath,
    this.accentIndex = 0,
    required this.createdAt,
  });

  /// Local UUID.
  final String id;
  final String name;

  /// Fully qualified base URL, e.g. https://us.posthog.com
  final String host;

  /// PostHog numeric project id.
  final int projectId;

  /// Absolute path to the logo file copied into app documents, or null.
  final String? logoPath;
  final int accentIndex;
  final DateTime createdAt;

  static const demoHost = 'demo://hoglens';

  Color get accent => Accents.at(accentIndex);
  bool get isDemo => host == demoHost;

  PhHost get hostKind {
    if (host == PhHost.us.baseUrl) return PhHost.us;
    if (host == PhHost.eu.baseUrl) return PhHost.eu;
    return PhHost.custom;
  }

  String get hostLabel => isDemo
      ? 'Demo'
      : hostKind == PhHost.custom
      ? Uri.tryParse(host)?.host ?? host
      : hostKind.label;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  PhProject copyWith({
    String? name,
    String? host,
    int? projectId,
    String? logoPath,
    bool clearLogo = false,
    int? accentIndex,
  }) =>
      PhProject(
        id: id,
        name: name ?? this.name,
        host: host ?? this.host,
        projectId: projectId ?? this.projectId,
        logoPath: clearLogo ? null : (logoPath ?? this.logoPath),
        accentIndex: accentIndex ?? this.accentIndex,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'host': host,
        'projectId': projectId,
        'logoPath': logoPath,
        'accentIndex': accentIndex,
        'createdAt': createdAt.toIso8601String(),
      };

  factory PhProject.fromJson(Map<String, dynamic> j) => PhProject(
        id: j['id'] as String,
        name: j['name'] as String,
        host: j['host'] as String,
        projectId: (j['projectId'] as num).toInt(),
        logoPath: j['logoPath'] as String?,
        accentIndex: (j['accentIndex'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

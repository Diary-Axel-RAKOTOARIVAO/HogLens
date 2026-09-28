import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/project.dart';
import '../../data/models/widget_spec.dart';
import '../../data/providers/providers.dart';
import '../widgets/widget_presets.dart';

/// Adds a demo project with a few preset widgets and opens it.
Future<void> addDemoProject(BuildContext context, WidgetRef ref) async {
  final p = await ref.read(projectsProvider.notifier).add(
        name: 'Demo project',
        host: PhProject.demoHost,
        projectId: 1,
        apiKey: 'demo',
        accentIndex: 1,
      );
  final w = ref.read(widgetsProvider.notifier);
  for (final id in ['signups', 'exceptions', 'countries', 'browsers', 'top_pages']) {
    final preset = widgetPresets.firstWhere((x) => x.id == id);
    await w.add(p.id, preset.toSpec(const Uuid().v4()).copyWith(size: preset.size == WidgetSize.full ? WidgetSize.full : WidgetSize.half));
  }
  if (context.mounted) context.push('/p/${p.id}');
}

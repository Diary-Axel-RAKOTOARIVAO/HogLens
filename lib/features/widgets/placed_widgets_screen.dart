import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../core/i18n.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/providers/providers.dart';
import '../../home_widget/home_widget_service.dart';
import '../../shared/ui.dart';

/// Widgets currently on the home screen, each with its own project and period.
class PlacedWidgetsScreen extends ConsumerStatefulWidget {
  const PlacedWidgetsScreen({super.key});

  @override
  ConsumerState<PlacedWidgetsScreen> createState() => _PlacedWidgetsScreenState();
}

class _PlacedWidgetsScreenState extends ConsumerState<PlacedWidgetsScreen> {
  late Future<List<PlacedWidget>> _future = _load();
  bool _refreshing = false;

  Future<List<PlacedWidget>> _load() => HomeWidgetService.placed(ref.read(storeProvider));

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    await HomeWidgetService.refreshAll(store: ref.read(storeProvider));
    if (mounted) setState(() => _refreshing = false);
  }

  Future<void> _edit(PlacedWidget w) async {
    final projects = ref.read(projectsProvider);
    var pid = projects.any((p) => p.id == w.projectId) ? w.projectId : projects.first.id;
    var range = w.range;
    final c = context.colors;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(Spacing.page, 0, Spacing.page, 24),
          children: [
            Text(tr(w.kind.title), style: Theme.of(ctx).textTheme.headlineMedium),
            const SizedBox(height: 14),
            Text(tr('Project').toUpperCase(), style: Theme.of(ctx).textTheme.labelSmall),
            const SizedBox(height: 8),
            for (final p in projects)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: ProjectAvatar(project: p, size: 32),
                title: Text(p.name),
                trailing: pid == p.id ? Icon(SolarIconsBold.checkCircle, color: c.text, size: 20) : null,
                onTap: () => setSheet(() => pid = p.id),
              ),
            if (w.kind.ranged) ...[
              const SizedBox(height: 12),
              Text(tr('Period').toUpperCase(), style: Theme.of(ctx).textTheme.labelSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final r in WidgetRange.values)
                    ChoiceChip(label: Text(tr(r.label)), selected: range == r, onSelected: (_) => setSheet(() => range = r)),
                ],
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Save'))),
          ],
        ),
      ),
    );
    if (saved != true || !mounted) return;
    await HomeWidgetService.configure(w, pid, range, ref.read(storeProvider));
    if (mounted) setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final projects = ref.watch(projectsProvider);
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: Spacing.page),
          child: Center(child: IconCircleButton(icon: SolarIconsOutline.altArrowLeft, onTap: () => context.pop())),
        ),
        titleSpacing: 12,
        title: Text(tr('Home screen widgets')),
        actions: [
          IconButton(
            onPressed: _refreshing ? null : _refresh,
            icon: _refreshing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(SolarIconsOutline.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<PlacedWidget>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final list = snap.data!;
          if (list.isEmpty) {
            return EmptyState(
              icon: SolarIconsOutline.widgetAdd,
              title: tr('No widgets yet'),
              message: tr('Add one from a project’s settings, or long-press your home screen.'),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(Spacing.page, 4, Spacing.page, 40),
            children: [
              Text(tr('Tap a widget to change its project or period. Tap the time on a widget to refresh it.'),
                  style: TextStyle(color: c.textMuted, fontSize: 13)),
              const SizedBox(height: 14),
              for (final w in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card1(
                    radius: 20,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    onTap: () => _edit(w),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(12)),
                          child: Text(w.kind.cells, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.text)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(tr(w.kind.title), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                              Text(
                                [
                                  projects.where((p) => p.id == w.projectId).firstOrNull?.name ?? tr('Removed project'),
                                  if (w.kind.ranged) tr(w.range.label),
                                ].join(' · '),
                                style: TextStyle(fontSize: 12.5, color: c.textMuted),
                              ),
                            ],
                          ),
                        ),
                        Icon(SolarIconsOutline.altArrowRight, size: 18, color: c.textFaint),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

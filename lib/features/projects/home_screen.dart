import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/util/format.dart';
import '../../data/models/project.dart';
import '../../data/providers/providers.dart';
import '../../shared/ui.dart';
import '../dashboard/charts.dart';
import 'demo.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsProvider);
    final c = context.colors;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            titleSpacing: Spacing.page,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Projects'),
                Text(
                  projects.isEmpty
                      ? 'Nothing connected yet'
                      : '${projects.length} connected · ${Fmt.monthDay(DateTime.now())}',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: c.textMuted),
                ),
              ],
            ),
            actions: [
              IconCircleButton(
                icon: SolarIconsOutline.addCircle,
                tooltip: 'Add project',
                onTap: () => context.push('/add'),
              ),
              const SizedBox(width: Spacing.page),
            ],
          ),
          if (projects.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: SolarIconsOutline.chartSquare,
                title: 'No projects yet',
                message: 'Add a PostHog project with a personal API key to see its pulse.',
                action: Column(
                  children: [
                    FilledButton(
                      onPressed: () => context.push('/add'),
                      style: FilledButton.styleFrom(minimumSize: const Size(180, 48)),
                      child: const Text('Add project'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => addDemoProject(context, ref),
                      child: Text('Explore with demo data', style: TextStyle(color: c.textMuted)),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(Spacing.page, 8, Spacing.page, 40),
              sliver: SliverReorderableList(
                itemCount: projects.length,
                onReorderItem: (a, b) => ref.read(projectsProvider.notifier).reorder(a, b),
                proxyDecorator: (child, _, _) => Material(color: Colors.transparent, child: child),
                itemBuilder: (context, i) {
                  final p = projects[i];
                  return Padding(
                    key: ValueKey(p.id),
                    padding: const EdgeInsets.only(bottom: Spacing.gap),
                    child: ReorderableDelayedDragStartListener(
                      index: i,
                      child: _ProjectCard(project: p)
                          .animate()
                          .fadeIn(duration: 250.ms, delay: (40 * i).ms)
                          .slideY(begin: 0.05, end: 0, curve: Curves.easeOut),
                    ),
                  );
                },
              ),
            ),
          if (projects.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: Text(
                  'Hold and drag to reorder',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.textFaint, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProjectCard extends ConsumerWidget {
  const _ProjectCard({required this.project});
  final PhProject project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final glance = ref.watch(glanceProvider(project.id));

    return Card1(
      onTap: () => context.push('/p/${project.id}'),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          ProjectAvatar(project: project, size: 56),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  project.name,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Pill(project.hostLabel, icon: SolarIconsOutline.global),
                    const SizedBox(width: 6),
                    Pill('#${project.projectId}'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 104,
            child: glance.when(
              data: (v) => Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  BigValue(Fmt.compact(v.isEmpty ? 0 : v.last), size: 24),
                  const SizedBox(height: 2),
                  Text('events today', style: TextStyle(color: c.textMuted, fontSize: 13)),
                  const SizedBox(height: 8),
                  MiniBars(values: v, color: project.accent, height: 22, gap: 3),
                ],
              ),
              loading: () => const Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [Skeleton(width: 56, height: 24), SizedBox(height: 8), Skeleton(width: 80, height: 12)],
              ),
              error: (_, _) => Icon(SolarIconsOutline.dangerCircle, size: 18, color: c.negative),
            ),
          ),
        ],
      ),
    );
  }
}

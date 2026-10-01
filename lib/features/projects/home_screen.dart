import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/i18n.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/util/format.dart';
import '../../data/models/project.dart';
import '../../data/providers/providers.dart';
import '../../shared/ui.dart';
import '../../shared/visible_polling.dart';
import '../dashboard/charts.dart';
import 'demo.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with VisiblePolling {
  @override
  Duration get pollInterval => const Duration(seconds: 60);

  @override
  Future<void> poll() async {
    final ids = ref.read(projectsProvider).map((p) => p.id).toList();
    for (final id in ids) {
      ref.invalidate(glanceProvider(id));
    }
    await Future.wait(ids.map((id) => ref.read(glanceProvider(id).future).then<void>((_) {}, onError: (_) {})));
  }

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(projectsProvider);
    final c = context.colors;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            titleSpacing: Spacing.page,
            title: Row(
              children: [
                const Padding(padding: EdgeInsets.all(6), child: BrandLogo(size: 40)),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(tr('Projects')),
                Text(
                  projects.isEmpty
                      ? tr('Nothing connected yet')
                      : '${projects.length} ${tr('connected')} · ${Fmt.monthDay(DateTime.now())}',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: c.textMuted),
                ),
              ],
            ),
                ),
              ],
            ),
            actions: [
              IconCircleButton(
                icon: SolarIconsOutline.settings,
                tooltip: tr('Settings'),
                onTap: () => context.push('/settings'),
              ),
              const SizedBox(width: 10),
              IconCircleButton(
                icon: SolarIconsOutline.addCircle,
                tooltip: tr('Add project'),
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
                leading: const BrandLogo(size: 96),
                title: tr('No projects yet'),
                message: tr('Add a PostHog project with a personal API key to see its pulse.'),
                action: Column(
                  children: [
                    FilledButton(
                      onPressed: () => context.push('/add'),
                      style: FilledButton.styleFrom(minimumSize: const Size(180, 48)),
                      child: Text(tr('Add project')),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => addDemoProject(context, ref),
                      child: Text(tr('Explore with demo data'), style: TextStyle(color: c.textMuted)),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(Spacing.page, 4, Spacing.page, 12),
              sliver: SliverToBoxAdapter(child: _Overview(projects: projects)),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(Spacing.page, 0, Spacing.page, 40),
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
          ],
          if (projects.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: Text(
                  tr('Hold and drag to reorder'),
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

/// Totals across every project from the glance data already loaded, plus a
/// banner when a newer GitHub release exists.
class _Overview extends ConsumerWidget {
  const _Overview({required this.projects});
  final List<PhProject> projects;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    num today = 0, week = 0;
    var loaded = 0;
    for (final p in projects) {
      final g = ref.watch(glanceProvider(p.id)).value;
      if (g == null) continue;
      loaded++;
      today += g.today;
      week += g.week;
    }
    final update = ref.watch(updateCheckProvider).value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (update != null) ...[
          Card1(
            radius: 20,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            onTap: () => launchUrl(Uri.parse(update.url), mode: LaunchMode.externalApplication),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: c.text, borderRadius: BorderRadius.circular(11)),
                  child: Icon(SolarIconsOutline.download, size: 18, color: c.bg),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('HogLens ${update.version} ${tr('is out')}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                      Text(tr('Tap to open the release and download the APK'), style: TextStyle(fontSize: 12, color: c.textMuted)),
                    ],
                  ),
                ),
                Icon(SolarIconsOutline.altArrowRight, size: 18, color: c.textFaint),
              ],
            ),
          ),
          const SizedBox(height: Spacing.gap),
        ],
        Card1(
          radius: 20,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('VISITORS TODAY'), maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: 6),
                    loaded == 0 ? const Skeleton(width: 80, height: 26) : AnimatedBigValue(today, format: Fmt.compact, size: 26),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('UNIQUE, 7 DAYS'), maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: 6),
                    loaded == 0 ? const Skeleton(width: 80, height: 26) : AnimatedBigValue(week, format: Fmt.compact, size: 26),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
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
                  AnimatedBigValue(v.today, format: Fmt.compact, size: 24),
                  const SizedBox(height: 2),
                  Text(tr('visitors today'), style: TextStyle(color: c.textMuted, fontSize: 13)),
                  const SizedBox(height: 8),
                  MiniBars(values: v.daily, color: project.accent, height: 22, gap: 3),
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

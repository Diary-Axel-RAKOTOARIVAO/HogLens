import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _reordering = false;

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
                onReorderStart: (_) => HapticFeedback.mediumImpact(),
                onReorderEnd: (_) => HapticFeedback.selectionClick(),
                onReorderItem: (a, b) => ref.read(projectsProvider.notifier).reorder(a, b),
                proxyDecorator: (child, _, animation) => AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    final t = Curves.easeOut.transform(animation.value);
                    return Transform.scale(
                      scale: 1 + 0.03 * t,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(Radii.card),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18 * t), blurRadius: 24 * t, offset: Offset(0, 10 * t))],
                        ),
                        child: Material(color: Colors.transparent, child: child),
                      ),
                    );
                  },
                  child: child,
                ),
                itemBuilder: (context, i) {
                  final p = projects[i];
                  final card = _ProjectCard(project: p, reordering: _reordering, index: i);
                  return Padding(
                    key: ValueKey(p.id),
                    padding: const EdgeInsets.only(bottom: Spacing.gap),
                    // Long-press anywhere drags; in reorder mode the handle drags at once.
                    child: _reordering ? card : ReorderableDelayedDragStartListener(index: i, child: card),
                  );
                },
              ),
            ),
          ],
          if (projects.length > 1)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: Column(
                  children: [
                    if (!_reordering)
                      Text(
                        tr('Hold a card to move it'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: c.textFaint, fontSize: 12),
                      ),
                    const SizedBox(height: 8),
                    Center(
                      child: Material(
                        color: _reordering ? c.text : c.surface,
                        shape: const StadiumBorder(),
                        child: InkWell(
                          customBorder: const StadiumBorder(),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _reordering = !_reordering);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_reordering ? Icons.check_rounded : Icons.swap_vert_rounded, size: 17, color: _reordering ? c.bg : c.text),
                                const SizedBox(width: 6),
                                Text(
                                  _reordering ? tr('Done') : tr('Reorder'),
                                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: _reordering ? c.bg : c.text),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
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
  const _ProjectCard({required this.project, this.reordering = false, this.index = 0});
  final PhProject project;
  final bool reordering;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final glance = ref.watch(glanceProvider(project.id));

    return Card1(
      onTap: reordering ? null : () => context.push('/p/${project.id}'),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: reordering
                ? ReorderableDragStartListener(
                    index: index,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Container(
                        width: 36,
                        height: 56,
                        decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: BorderRadius.circular(12)),
                        child: Icon(Icons.drag_indicator_rounded, color: c.textMuted),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
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

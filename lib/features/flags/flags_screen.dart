import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/util/format.dart';
import '../../data/providers/providers.dart';
import '../../shared/ui.dart';

class FlagsScreen extends ConsumerWidget {
  const FlagsScreen({super.key, required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final flags = ref.watch(flagsProvider(projectId));
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 76,
        leading: Padding(
          padding: const EdgeInsets.only(left: Spacing.page),
          child: Center(child: IconCircleButton(icon: SolarIconsOutline.altArrowLeft, onTap: () => context.pop())),
        ),
        titleSpacing: 12,
        title: const Text('Feature flags'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(flagsProvider(projectId));
          try {
            await ref.read(flagsProvider(projectId).future);
          } catch (_) {}
        },
        child: flags.when(
          loading: () => ListView(
            padding: const EdgeInsets.all(Spacing.page),
            children: [for (var i = 0; i < 6; i++) const Padding(padding: EdgeInsets.only(bottom: 10), child: Skeleton(height: 64, radius: 16))],
          ),
          error: (e, _) => ListView(
            padding: const EdgeInsets.all(Spacing.page),
            children: [ErrorCard(message: '$e', onRetry: () => ref.invalidate(flagsProvider(projectId)))],
          ),
          data: (list) => list.isEmpty
              ? ListView(children: const [SizedBox(height: 120), EmptyState(icon: SolarIconsOutline.flag, title: 'No flags', message: 'This project has no feature flags yet.')])
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(Spacing.page, 4, Spacing.page, 40),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final f = list[i];
                    return Card1(
                      radius: 22,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(color: f.active ? c.positive : c.textFaint, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(f.key, style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Menlo', fontSize: 13.5)),
                                if (f.name.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: c.textMuted)),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Pill(
                                f.active ? '${f.rolloutPercentage ?? 100}%' : 'off',
                                color: f.active ? c.positive : c.textMuted,
                              ),
                              if (f.createdAt != null) ...[
                                const SizedBox(height: 4),
                                Text(Fmt.relative(f.createdAt!), style: TextStyle(fontSize: 11, color: c.textFaint)),
                              ],
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

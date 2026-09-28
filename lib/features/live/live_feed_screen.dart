import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/util/format.dart';
import '../../data/models/insights.dart';
import '../../data/providers/providers.dart';
import '../../shared/ui.dart';

/// Tail of the newest events, refreshed every ten seconds.
class LiveFeedScreen extends ConsumerStatefulWidget {
  const LiveFeedScreen({super.key, required this.projectId});
  final String projectId;

  @override
  ConsumerState<LiveFeedScreen> createState() => _LiveFeedScreenState();
}

class _LiveFeedScreenState extends ConsumerState<LiveFeedScreen> {
  final _filter = TextEditingController();
  String _applied = '';

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final project = ref.watch(projectProvider(widget.projectId));
    final feed = ref.watch(liveFeedProvider((widget.projectId, _applied)));
    final accent = project?.accent ?? c.text;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 76,
        leading: Padding(
          padding: const EdgeInsets.only(left: Spacing.page),
          child: Center(child: IconCircleButton(icon: SolarIconsOutline.altArrowLeft, onTap: () => context.pop())),
        ),
        titleSpacing: 12,
        title: Row(
          children: [
            const Text('Live feed'),
            const SizedBox(width: 10),
            Container(width: 8, height: 8, decoration: BoxDecoration(color: c.positive, shape: BoxShape.circle))
                .animate(onPlay: (ctl) => ctl.repeat(reverse: true))
                .fade(begin: 0.3, end: 1, duration: 900.ms),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Spacing.page, 4, Spacing.page, 12),
            child: TextField(
              controller: _filter,
              textInputAction: TextInputAction.search,
              onSubmitted: (v) => setState(() => _applied = v.trim()),
              decoration: InputDecoration(
                hintText: 'Filter by event name',
                prefixIcon: Icon(Icons.search, size: 22, color: c.textMuted),
                suffixIcon: _applied.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _filter.clear();
                          setState(() => _applied = '');
                        },
                      ),
              ),
            ),
          ),
          Expanded(
            child: feed.when(
              skipLoadingOnRefresh: true,
              loading: () => ListView(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.page),
                children: [for (var i = 0; i < 8; i++) const Padding(padding: EdgeInsets.only(bottom: 8), child: Skeleton(height: 64, radius: 18))],
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(Spacing.page),
                child: ErrorCard(message: '$e', onRetry: () => ref.invalidate(liveFeedProvider((widget.projectId, _applied)))),
              ),
              data: (events) => events.isEmpty
                  ? const EmptyState(icon: SolarIconsOutline.pulse, title: 'Nothing yet', message: 'No matching events in the last 24 hours.')
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(Spacing.page, 0, Spacing.page, 40),
                      itemCount: events.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) => _EventRow(e: events[i], accent: accent)
                          .animate(key: ValueKey('${events[i].at.millisecondsSinceEpoch}${events[i].event}'))
                          .fadeIn(duration: 250.ms),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.e, required this.accent});
  final LiveEvent e;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final system = e.event.startsWith(r'$');
    final isError = e.event == r'$exception';
    return Card1(
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: (isError ? c.negative : accent).withValues(alpha: system ? 0.10 : 0.16),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              isError ? SolarIconsOutline.dangerTriangle : (system ? SolarIconsOutline.cursor : SolarIconsOutline.bolt),
              size: 18,
              color: isError ? c.negative : accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.event, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                const SizedBox(height: 2),
                Text(
                  [if (e.path != null && e.path!.isNotEmpty) e.path!, if (e.browser != null) '${e.browser}${e.os != null ? ' · ${e.os}' : ''}'].join('  ·  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: c.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(Fmt.relative(e.at), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.text)),
              const SizedBox(height: 2),
              Text(e.distinctId.length > 10 ? '${e.distinctId.substring(0, 8)}…' : e.distinctId,
                  style: TextStyle(fontSize: 11, color: c.textFaint, fontFamily: 'Menlo')),
            ],
          ),
        ],
      ),
    );
  }
}

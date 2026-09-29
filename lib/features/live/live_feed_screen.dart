import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../core/i18n.dart';
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
            Text(tr('Live feed')),
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
                  ? EmptyState(icon: SolarIconsOutline.pulse, title: 'Nothing yet', message: tr('No matching events in the last 24 hours.'))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(Spacing.page, 0, Spacing.page, 40),
                      itemCount: events.length,
                      itemBuilder: (context, i) => _EventRow(e: events[i], accent: accent, last: i == events.length - 1)
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
  const _EventRow({required this.e, required this.accent, this.last = false});
  final LiveEvent e;
  final Color accent;
  final bool last;

  (IconData, Color?) _style(AppColors c) {
    final n = e.event.toLowerCase();
    if (n == r'$exception') return (SolarIconsOutline.dangerTriangle, c.negative);
    if (n == r'$pageview' || n == r'$screen') return (SolarIconsOutline.eye, null);
    if (n == r'$pageleave') return (SolarIconsOutline.logout, null);
    if (n == r'$autocapture' || n == r'$rageclick') return (SolarIconsOutline.cursor, null);
    if (n == r'$feature_flag_called') return (SolarIconsOutline.flag, null);
    if (n == r'$identify' || n.contains('sign') || n.contains('register')) return (SolarIconsOutline.userCheck, c.positive);
    if (n.contains('purchase') || n.contains('booking') || n.contains('order') || n.contains('pay')) return (SolarIconsOutline.cart, accent);
    if (n.contains('search')) return (Icons.search, null);
    return (SolarIconsOutline.bolt, accent);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (icon, tint) = _style(c);
    final system = e.event.startsWith(r'$');
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 44,
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: tint == null ? c.surface : tint.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 17, color: tint ?? (system ? c.textMuted : c.text)),
                ),
                if (!last) Expanded(child: Container(width: 2, margin: const EdgeInsets.symmetric(vertical: 4), color: c.border)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(e.event, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      ),
                      const SizedBox(width: 10),
                      Text(Fmt.relative(e.at), style: TextStyle(fontSize: 12, color: c.textMuted)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(e.distinctId, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: c.textMuted, fontFamily: 'Menlo')),
                  if ((e.path != null && e.path!.isNotEmpty) || e.browser != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      [if (e.path != null && e.path!.isNotEmpty) e.path!, if (e.browser != null) '${e.browser}${e.os != null ? ' · ${e.os}' : ''}'].join('  ·  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: c.textFaint),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

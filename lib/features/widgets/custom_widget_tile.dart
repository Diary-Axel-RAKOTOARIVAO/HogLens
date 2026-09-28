import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/util/format.dart';
import '../../data/models/stats.dart';
import '../../data/models/widget_spec.dart';
import '../../data/providers/providers.dart';
import '../../shared/ui.dart';
import '../dashboard/charts.dart';
import 'widget_builder_sheet.dart';

/// Lays out half-width widgets in pairs and full-width widgets alone,
/// preserving user order. In edit mode it becomes a reorderable list.
class CustomWidgetGrid extends ConsumerWidget {
  const CustomWidgetGrid({super.key, required this.projectId, required this.editing});
  final String projectId;
  final bool editing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final widgets = ref.watch(projectWidgetsProvider(projectId));

    if (editing) {
      return ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        proxyDecorator: (child, _, _) => Material(color: Colors.transparent, child: child),
        itemCount: widgets.length,
        onReorderItem: (a, b) => ref.read(widgetsProvider.notifier).reorder(projectId, a, b),
        itemBuilder: (context, i) => Padding(
          key: ValueKey(widgets[i].id),
          padding: const EdgeInsets.only(bottom: Spacing.gap),
          child: _EditRow(projectId: projectId, spec: widgets[i], index: i),
        ),
      );
    }

    final rows = <Widget>[];
    var i = 0;
    while (i < widgets.length) {
      final w = widgets[i];
      if (w.size == WidgetSize.full) {
        rows.add(CustomWidgetTile(projectId: projectId, spec: w));
        i++;
      } else {
        final next = i + 1 < widgets.length && widgets[i + 1].size == WidgetSize.half ? widgets[i + 1] : null;
        rows.add(Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: CustomWidgetTile(projectId: projectId, spec: w)),
            const SizedBox(width: Spacing.gap),
            Expanded(child: next == null ? const SizedBox() : CustomWidgetTile(projectId: projectId, spec: next)),
          ],
        ));
        i += next == null ? 1 : 2;
      }
    }
    return Column(
      children: [
        for (var k = 0; k < rows.length; k++) ...[
          rows[k].animate().fadeIn(duration: 250.ms, delay: (40 * k).ms),
          if (k != rows.length - 1) const SizedBox(height: Spacing.gap),
        ],
      ],
    );
  }
}

class _EditRow extends ConsumerWidget {
  const _EditRow({required this.projectId, required this.spec, required this.index});
  final String projectId;
  final StatWidgetSpec spec;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return Card1(
      radius: 20,
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(SolarIconsOutline.hamburgerMenu, size: 20, color: c.textFaint),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(spec.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text('${spec.kind.label} · ${spec.size == WidgetSize.full ? 'full' : 'half'} width',
                    style: TextStyle(fontSize: 12, color: c.textMuted)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(SolarIconsOutline.pen, size: 18),
            onPressed: () => showWidgetBuilder(context, projectId: projectId, existing: spec),
          ),
          IconButton(
            icon: Icon(SolarIconsOutline.trashBinMinimalistic, size: 18, color: c.negative),
            onPressed: () => ref.read(widgetsProvider.notifier).remove(projectId, spec.id),
          ),
        ],
      ),
    );
  }
}

class CustomWidgetTile extends ConsumerWidget {
  const CustomWidgetTile({super.key, required this.projectId, required this.spec});
  final String projectId;
  final StatWidgetSpec spec;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final project = ref.watch(projectProvider(projectId));
    final accent = project?.accent ?? Accents.all.first;
    final result = ref.watch(widgetResultProvider((projectId, spec.id)));

    return Card1(
      radius: Radii.tile,
      padding: const EdgeInsets.all(20),
      onLongPress: () => showWidgetBuilder(context, projectId: projectId, existing: spec),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: CardLabel(spec.title, icon: _iconFor(spec.kind))),
              if (result.value?.fromCache == true)
                Icon(SolarIconsOutline.cloudCross, size: 14, color: c.textFaint),
            ],
          ),
          const SizedBox(height: 14),
          result.when(
            skipLoadingOnRefresh: true,
            loading: () => Skeleton(height: spec.kind == WidgetKind.number ? 28 : 80, width: spec.kind == WidgetKind.number ? 70 : null),
            error: (e, _) => Text('$e', style: TextStyle(color: c.negative, fontSize: 12, height: 1.3), maxLines: 3, overflow: TextOverflow.ellipsis),
            data: (r) => _body(context, r, accent),
          ),
          if (spec.subtitle != null && spec.subtitle!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(spec.subtitle!, style: TextStyle(fontSize: 11.5, color: c.textFaint)),
          ],
        ],
      ),
    );
  }

  static IconData _iconFor(WidgetKind k) => switch (k) {
        WidgetKind.number => SolarIconsOutline.hashtagSquare,
        WidgetKind.sparkline => SolarIconsOutline.graphNew,
        WidgetKind.bars => SolarIconsOutline.chart_2,
        WidgetKind.table => SolarIconsOutline.list,
      };

  Widget _body(BuildContext context, QueryResult r, Color accent) {
    final c = context.colors;
    num n(dynamic v) => v is num ? v : num.tryParse('$v') ?? 0;
    switch (spec.kind) {
      case WidgetKind.number:
        final v = r.firstCell;
        return v is num ? AnimatedBigValue(v, format: Fmt.compact) : BigValue(v?.toString() ?? '—');
      case WidgetKind.sparkline:
        final pts = <SeriesPoint>[];
        for (final row in r.rows) {
          if (row.length < 2) continue;
          final t = DateTime.tryParse('${row[0]}')?.toLocal();
          if (t != null) pts.add(SeriesPoint(t, n(row[1])));
        }
        final hourly = pts.length > 1 && pts[1].t.difference(pts[0].t).inHours < 24;
        return TrendChart(points: pts, color: accent, height: spec.size == WidgetSize.full ? 140 : 80, showAxis: spec.size == WidgetSize.full, hourly: hourly);
      case WidgetKind.bars:
        return BarList(
          rows: r.rows.where((row) => row.length >= 2).map((row) => ('${row[0] ?? '(none)'}', n(row[1]))).toList(),
          color: accent,
          maxRows: spec.size == WidgetSize.full ? 8 : 5,
        );
      case WidgetKind.table:
        if (r.isEmpty) return Text('No rows', style: TextStyle(color: c.textFaint));
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 32,
            dataRowMinHeight: 32,
            dataRowMaxHeight: 36,
            columnSpacing: 20,
            horizontalMargin: 0,
            headingTextStyle: TextStyle(fontSize: 11.5, color: c.textMuted, fontWeight: FontWeight.w600),
            dataTextStyle: TextStyle(fontSize: 12.5, color: c.text),
            columns: [for (final col in r.columns) DataColumn(label: Text(col))],
            rows: [
              for (final row in r.rows.take(10))
                DataRow(cells: [
                  for (final cell in row)
                    DataCell(ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160),
                      child: Text(_cell(cell), overflow: TextOverflow.ellipsis),
                    )),
                ]),
            ],
          ),
        );
    }
  }

  static String _cell(dynamic v) {
    if (v == null) return '—';
    if (v is num) return Fmt.full(v);
    final s = '$v';
    final t = DateTime.tryParse(s);
    if (t != null && s.length > 15) return Fmt.relative(t.toLocal());
    return s;
  }
}

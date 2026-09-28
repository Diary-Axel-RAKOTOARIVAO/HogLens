import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/api/posthog_client.dart';
import '../../data/api/stats_repository.dart';
import '../../data/models/widget_spec.dart';
import '../../data/providers/providers.dart';
import '../../shared/ui.dart';
import 'widget_presets.dart';

Future<void> showWidgetBuilder(BuildContext context, {required String projectId, StatWidgetSpec? existing}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _WidgetBuilderSheet(projectId: projectId, existing: existing),
  );
}

class _WidgetBuilderSheet extends ConsumerStatefulWidget {
  const _WidgetBuilderSheet({required this.projectId, this.existing});
  final String projectId;
  final StatWidgetSpec? existing;

  @override
  ConsumerState<_WidgetBuilderSheet> createState() => _WidgetBuilderSheetState();
}

class _WidgetBuilderSheetState extends ConsumerState<_WidgetBuilderSheet> {
  StatWidgetSpec? _draft;
  late final TextEditingController _title;
  late final TextEditingController _query;
  late final TextEditingController _subtitle;
  bool _testing = false;
  String? _testMessage;
  bool _testOk = false;

  @override
  void initState() {
    super.initState();
    _draft = widget.existing;
    _title = TextEditingController(text: _draft?.title ?? '');
    _query = TextEditingController(text: _draft?.hogql ?? '');
    _subtitle = TextEditingController(text: _draft?.subtitle ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _query.dispose();
    _subtitle.dispose();
    super.dispose();
  }

  void _pick(WidgetPreset p) {
    setState(() {
      _draft = p.toSpec(const Uuid().v4());
      _title.text = p.title;
      _query.text = p.hogql;
      _subtitle.text = '';
      _testMessage = null;
    });
  }

  Future<void> _test() async {
    final project = ref.read(projectProvider(widget.projectId));
    if (project == null) return;
    setState(() {
      _testing = true;
      _testMessage = null;
    });
    try {
      final client = await ref.read(clientProvider(widget.projectId).future);
      final range = ref.read(rangeProvider).resolve(DateTime.now());
      final r = await client.query(project.projectId, StatsRepository.resolve(_query.text, range));
      setState(() {
        _testOk = true;
        _testMessage = r.isEmpty
            ? 'Query ran, returned no rows.'
            : '${r.rows.length} row${r.rows.length == 1 ? '' : 's'} · ${r.columns.join(', ')} · first: ${r.firstCell}';
      });
    } on PosthogException catch (e) {
      setState(() {
        _testOk = false;
        _testMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _testOk = false;
        _testMessage = '$e';
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    final d = _draft!.copyWith(
      title: _title.text.trim().isEmpty ? 'Untitled' : _title.text.trim(),
      hogql: _query.text.trim(),
      subtitle: _subtitle.text.trim(),
    );
    final notifier = ref.read(widgetsProvider.notifier);
    if (widget.existing == null) {
      await notifier.add(widget.projectId, d);
    } else {
      await notifier.update(widget.projectId, d);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      maxChildSize: 0.96,
      minChildSize: 0.5,
      builder: (context, ctrl) => ListView(
        controller: ctrl,
        padding: EdgeInsets.fromLTRB(Spacing.page, 0, Spacing.page, 32 + bottom),
        children: _draft == null ? _presetGallery(c) : _editor(c),
      ),
    );
  }

  List<Widget> _presetGallery(AppColors c) => [
        Text('New widget', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 4),
        Text('Start from a preset, then tweak the query.', style: TextStyle(color: c.textMuted)),
        const SizedBox(height: 20),
        for (final p in widgetPresets)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card1(
              radius: Radii.tile,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              onTap: () => _pick(p),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(12)),
                    child: Icon(_iconFor(p.kind), size: 18, color: c.text),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(p.description, style: TextStyle(fontSize: 12.5, color: c.textMuted)),
                      ],
                    ),
                  ),
                  Pill(p.kind.label),
                ],
              ),
            ),
          ),
      ];

  List<Widget> _editor(AppColors c) {
    final d = _draft!;
    return [
      Row(
        children: [
          if (widget.existing == null)
            IconButton(
              padding: EdgeInsets.zero,
              color: c.text,
              icon: const Icon(SolarIconsOutline.altArrowLeft),
              onPressed: () => setState(() => _draft = null),
            ),
          Expanded(
            child: Text(widget.existing == null ? 'Configure' : 'Edit widget',
                style: Theme.of(context).textTheme.headlineMedium),
          ),
        ],
      ),
      const SizedBox(height: 18),
      Text('TITLE', style: Theme.of(context).textTheme.labelSmall),
      const SizedBox(height: 8),
      TextField(controller: _title, decoration: const InputDecoration(hintText: 'Sign-ups')),
      const SizedBox(height: 18),
      Text('DISPLAY', style: Theme.of(context).textTheme.labelSmall),
      const SizedBox(height: 8),
      Row(
        children: [
          for (final k in WidgetKind.values) ...[
            Expanded(
              child: _KindChip(
                kind: k,
                selected: d.kind == k,
                onTap: () => setState(() => _draft = d.copyWith(kind: k)),
              ),
            ),
            if (k != WidgetKind.values.last) const SizedBox(width: 8),
          ],
        ],
      ),
      const SizedBox(height: 6),
      Text(d.kind.hint, style: TextStyle(fontSize: 12, color: c.textFaint)),
      const SizedBox(height: 18),
      Row(
        children: [
          Text('WIDTH', style: Theme.of(context).textTheme.labelSmall),
          const Spacer(),
          SegmentedButton<WidgetSize>(
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
            segments: const [
              ButtonSegment(value: WidgetSize.half, label: Text('Half')),
              ButtonSegment(value: WidgetSize.full, label: Text('Full')),
            ],
            selected: {d.size},
            onSelectionChanged: (s) => setState(() => _draft = d.copyWith(size: s.first)),
          ),
        ],
      ),
      if (d.kind == WidgetKind.number) ...[
        const SizedBox(height: 14),
        Card1(
          radius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Compare with previous period', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    Text('Runs the query again for the window before', style: TextStyle(fontSize: 12, color: c.textMuted)),
                  ],
                ),
              ),
              Switch.adaptive(
                value: d.compare,
                activeTrackColor: c.text,
                onChanged: (v) => setState(() => _draft = d.copyWith(compare: v)),
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 18),
      Text('HOGQL', style: Theme.of(context).textTheme.labelSmall),
      const SizedBox(height: 8),
      TextField(
        controller: _query,
        minLines: 4,
        maxLines: 10,
        autocorrect: false,
        enableSuggestions: false,
        style: const TextStyle(fontFamily: 'Menlo', fontSize: 13, height: 1.45),
        decoration: const InputDecoration(hintText: 'SELECT count() FROM events WHERE timestamp >= {range}'),
        onChanged: (_) => setState(() => _testMessage = null),
      ),
      const SizedBox(height: 6),
      Text('{range} and {range_end} become the dashboard window, e.g. toDateTime(\'2026-09-21 00:00:00\').',
          style: TextStyle(fontSize: 12, color: c.textFaint)),
      const SizedBox(height: 18),
      Text('SUBTITLE (OPTIONAL)', style: Theme.of(context).textTheme.labelSmall),
      const SizedBox(height: 8),
      TextField(controller: _subtitle, decoration: const InputDecoration(hintText: 'Shown under the value')),
      const SizedBox(height: 20),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _testing ? null : _test,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                foregroundColor: c.text,
                backgroundColor: c.surface,
                side: BorderSide.none,
                shape: const StadiumBorder(),
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
              child: _testing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Test query'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: _query.text.trim().isEmpty ? null : _save,
              child: Text(widget.existing == null ? 'Add widget' : 'Save'),
            ),
          ),
        ],
      ),
      if (_testMessage != null) ...[
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              _testOk ? SolarIconsBold.checkCircle : SolarIconsBold.dangerCircle,
              size: 16,
              color: _testOk ? c.positive : c.negative,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(_testMessage!, style: TextStyle(fontSize: 12.5, color: c.textMuted, height: 1.35))),
          ],
        ),
      ],
    ];
  }

  static IconData _iconFor(WidgetKind k) => switch (k) {
        WidgetKind.number => SolarIconsOutline.hashtagSquare,
        WidgetKind.sparkline => SolarIconsOutline.graphNew,
        WidgetKind.bars => SolarIconsOutline.chart_2,
        WidgetKind.table => SolarIconsOutline.list,
      };
}

class _KindChip extends StatelessWidget {
  const _KindChip({required this.kind, required this.selected, required this.onTap});
  final WidgetKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? c.text : c.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(_WidgetBuilderSheetState._iconFor(kind), size: 18, color: selected ? c.bg : c.text),
            const SizedBox(height: 4),
            Text(kind.label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: selected ? c.bg : c.text)),
          ],
        ),
      ),
    );
  }
}

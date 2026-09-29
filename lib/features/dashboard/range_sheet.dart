import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../core/i18n.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/util/format.dart';
import '../../data/models/stats.dart';
import '../../data/providers/providers.dart';
import '../../shared/ui.dart';

/// Bottom drawer for picking the dashboard window: presets first, then an
/// in-sheet calendar for custom dates. Same look as the widget builder.
Future<void> showRangeSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _RangeSheet(),
  );
}

class _RangeSheet extends ConsumerStatefulWidget {
  const _RangeSheet();

  @override
  ConsumerState<_RangeSheet> createState() => _RangeSheetState();
}

class _RangeSheetState extends ConsumerState<_RangeSheet> {
  bool _calendar = false;
  DateTime? _start;
  DateTime? _end;
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final sel = ref.read(rangeProvider);
    final now = DateTime.now();
    if (sel.kind == RangeKind.custom) {
      _start = sel.customStart;
      _end = sel.customEnd;
    }
    final anchor = _end ?? now;
    _month = DateTime(anchor.year, anchor.month);
  }

  void _pick(RangeSelection r) {
    ref.read(rangeProvider.notifier).set(r);
    Navigator.pop(context);
  }

  void _tapDay(DateTime d) {
    setState(() {
      if (_start == null || (_start != null && _end != null)) {
        _start = d;
        _end = null;
      } else if (d.isBefore(_start!)) {
        _start = d;
      } else {
        _end = d;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: _calendar ? 0.86 : 0.62,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (context, ctrl) => AnimatedSwitcher(
        duration: 220.ms,
        switchInCurve: Curves.easeOut,
        transitionBuilder: (child, a) => FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween(begin: const Offset(0.04, 0), end: Offset.zero).animate(a),
            child: child,
          ),
        ),
        child: ListView(
          key: ValueKey(_calendar),
          controller: ctrl,
          padding: EdgeInsets.fromLTRB(Spacing.page, 0, Spacing.page, 28 + bottom),
          children: _calendar ? _calendarView(c) : _listView(c),
        ),
      ),
    );
  }

  List<Widget> _listView(AppColors c) {
    final sel = ref.watch(rangeProvider);
    final now = DateTime.now();
    final items = <(RangeSelection?, IconData, String, String)>[
      (RangeSelection.day, SolarIconsOutline.clockCircle, tr('Last 24 hours'), tr('Rolling, hour by hour')),
      (RangeSelection.week, SolarIconsOutline.calendarMinimalistic, tr('Last 7 days'), tr('Rolling, day by day')),
      (RangeSelection.month, SolarIconsOutline.calendarMinimalistic, tr('Last 30 days'), tr('Rolling, day by day')),
      (RangeSelection.thisMonth, SolarIconsOutline.calendar, RangeSelection.thisMonth.label(now), tr('This month, from the 1st to today')),
      (null, SolarIconsOutline.calendarSearch, tr('Custom dates'), sel.kind == RangeKind.custom ? sel.label(now) : tr('Pick a start and an end day')),
    ];
    return [
      Text(tr('Time range'), style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 4),
      Text(tr('Every number on the dashboard follows this window.'), style: TextStyle(color: c.textMuted)),
      const SizedBox(height: 20),
      for (final (r, icon, title, subtitle) in items)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _Row(
            icon: icon,
            title: title,
            subtitle: subtitle,
            selected: r == null ? sel.kind == RangeKind.custom : sel == r,
            onTap: () => r == null ? setState(() => _calendar = true) : _pick(r),
          ),
        ),
    ];
  }

  List<Widget> _calendarView(AppColors c) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final canGoForward = DateTime(_month.year, _month.month + 1).isBefore(today.add(const Duration(days: 1)));
    final days = _end == null || _start == null ? null : _end!.difference(_start!).inDays + 1;
    final summary = _start == null
        ? 'Tap a start day'
        : _end == null
            ? '${Fmt.monthDay(_start!)} → tap an end day'
            : '${Fmt.monthDay(_start!)} – ${Fmt.monthDay(_end!)} · $days day${days == 1 ? '' : 's'}';

    return [
      Row(
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            color: c.text,
            icon: const Icon(SolarIconsOutline.altArrowLeft),
            onPressed: () => setState(() => _calendar = false),
          ),
          Expanded(child: Text(tr('Custom dates'), style: Theme.of(context).textTheme.headlineMedium)),
        ],
      ),
      const SizedBox(height: 4),
      Text(summary, style: TextStyle(color: c.textMuted)),
      const SizedBox(height: 18),
      Card1(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
        child: Column(
          children: [
            Row(
              children: [
                IconCircleButton(
                  icon: SolarIconsOutline.altArrowLeft,
                  onTap: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
                ),
                Expanded(
                  child: Text(
                    '${RangeSelection.thisMonth.copyMonthName(_month.month)} ${_month.year}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Opacity(
                  opacity: canGoForward ? 1 : 0.3,
                  child: IconCircleButton(
                    icon: SolarIconsOutline.altArrowRight,
                    onTap: () {
                      if (canGoForward) setState(() => _month = DateTime(_month.year, _month.month + 1));
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _CalendarGrid(month: _month, start: _start, end: _end, today: today, onTap: _tapDay),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          for (final (label, d) in [(tr('Last 14 days'), 14), (tr('Last 60 days'), 60), (tr('Last 90 days'), 90)]) ...[
            Expanded(
              child: _QuickChip(
                label: label,
                onTap: () => setState(() {
                  _end = today;
                  _start = today.subtract(Duration(days: d - 1));
                  _month = DateTime(today.year, today.month);
                }),
              ),
            ),
            if (d != 90) const SizedBox(width: 8),
          ],
        ],
      ),
      const SizedBox(height: 20),
      FilledButton(
        onPressed: _start == null
            ? null
            : () => _pick(RangeSelection(RangeKind.custom, customStart: _start, customEnd: _end ?? _start)),
        child: Text(_end == null && _start != null ? 'Use ${Fmt.monthDay(_start!)} only' : 'Apply'),
      ),
    ];
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.title, required this.subtitle, required this.selected, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Card1(
      radius: Radii.tile - 6,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: selected ? c.text : c.bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 19, color: selected ? c.bg : c.text),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                Text(subtitle, style: TextStyle(fontSize: 12.5, color: c.textMuted)),
              ],
            ),
          ),
          if (selected) Icon(SolarIconsBold.checkCircle, size: 20, color: c.text),
        ],
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.surface,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: c.text),
          ),
        ),
      ),
    );
  }
}

/// Month grid, Monday first. Start and end days are filled circles; the
/// days between get a soft band.
class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({required this.month, required this.start, required this.end, required this.today, required this.onTap});
  final DateTime month;
  final DateTime? start;
  final DateTime? end;
  final DateTime today;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = (first.weekday - DateTime.monday) % 7;
    final cells = <DateTime?>[...List.filled(leading, null), for (var d = 1; d <= daysInMonth; d++) DateTime(month.year, month.month, d)];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    bool same(DateTime? a, DateTime? b) => a != null && b != null && a.year == b.year && a.month == b.month && a.day == b.day;
    bool inRange(DateTime d) => start != null && end != null && !d.isBefore(start!) && !d.isAfter(end!);

    return Column(
      children: [
        Row(
          children: [
            for (final w in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
              Expanded(
                child: Text(w, textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: c.textFaint)),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (var r = 0; r < cells.length ~/ 7; r++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Builder(builder: (context) {
                      final d = cells[r * 7 + i];
                      if (d == null) return const SizedBox(height: 40);
                      final disabled = d.isAfter(today);
                      final isStart = same(d, start);
                      final isEnd = same(d, end) || (isStart && end == null);
                      final banded = inRange(d);
                      return GestureDetector(
                        onTap: disabled ? null : () => onTap(d),
                        child: Container(
                          height: 40,
                          decoration: banded
                              ? BoxDecoration(
                                  color: c.bg,
                                  borderRadius: BorderRadius.horizontal(
                                    left: isStart ? const Radius.circular(20) : Radius.zero,
                                    right: isEnd ? const Radius.circular(20) : Radius.zero,
                                  ),
                                )
                              : null,
                          child: Center(
                            child: AnimatedContainer(
                              duration: 150.ms,
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isStart || isEnd ? c.text : Colors.transparent,
                                shape: BoxShape.circle,
                                border: same(d, today) && !(isStart || isEnd) ? Border.all(color: c.textFaint) : null,
                              ),
                              child: Center(
                                child: Text(
                                  '${d.day}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isStart || isEnd ? FontWeight.w700 : FontWeight.w500,
                                    color: disabled ? c.textFaint : (isStart || isEnd ? c.bg : c.text),
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

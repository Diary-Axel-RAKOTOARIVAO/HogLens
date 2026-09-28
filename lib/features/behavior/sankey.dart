import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/insights.dart';

/// Step-by-step flow between pages drawn as ribbons between node bars.
class SankeyChart extends StatelessWidget {
  const SankeyChart({super.key, required this.links, required this.accent, this.height = 280, this.maxPerStep = 5});
  final List<PathLink> links;
  final Color accent;
  final double height;
  final int maxPerStep;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _SankeyPainter(links: links, accent: accent, text: c.text, muted: c.textMuted, faint: c.surfaceRaised, maxPerStep: maxPerStep),
      ),
    );
  }
}

class _Node {
  _Node(this.step, this.label);
  final int step;
  final String label;
  double inflow = 0;
  double outflow = 0;
  double top = 0;
  double h = 0;
  double usedIn = 0;
  double usedOut = 0;
  double get weight => inflow > outflow ? inflow : outflow;
}

class _SankeyPainter extends CustomPainter {
  _SankeyPainter({required this.links, required this.accent, required this.text, required this.muted, required this.faint, required this.maxPerStep});
  final List<PathLink> links;
  final Color accent;
  final Color text;
  final Color muted;
  final Color faint;
  final int maxPerStep;

  static const _palette = [Color(0xFFF54E00), Color(0xFF7C3AED), Color(0xFFF59E0B), Color(0xFF16A34A), Color(0xFF1C7CF2)];

  @override
  void paint(Canvas canvas, Size size) {
    // Build nodes per step, keep the heaviest few per column.
    final nodes = <String, _Node>{};
    _Node node(int step, String label) => nodes.putIfAbsent('$step|$label', () => _Node(step, label));
    for (final l in links) {
      node(l.fromStep, l.from).outflow += l.value;
      node(l.fromStep + 1, l.to).inflow += l.value;
    }
    final steps = nodes.values.map((n) => n.step).toSet().toList()..sort();
    if (steps.isEmpty) return;
    final kept = <String>{};
    for (final s in steps) {
      final col = nodes.values.where((n) => n.step == s).toList()..sort((a, b) => b.weight.compareTo(a.weight));
      for (final n in col.take(maxPerStep)) {
        kept.add('${n.step}|${n.label}');
      }
    }
    final shown = links.where((l) => kept.contains('${l.fromStep}|${l.from}') && kept.contains('${l.fromStep + 1}|${l.to}')).toList();
    nodes.removeWhere((k, _) => !kept.contains(k));
    for (final n in nodes.values) {
      n.inflow = 0;
      n.outflow = 0;
    }
    for (final l in shown) {
      nodes['${l.fromStep}|${l.from}']!.outflow += l.value;
      nodes['${l.fromStep + 1}|${l.to}']!.inflow += l.value;
    }

    const nodeW = 6.0;
    const gap = 10.0;
    const labelW = 96.0;
    final colX = <int, double>{};
    final usable = size.width - labelW;
    for (var i = 0; i < steps.length; i++) {
      colX[steps[i]] = steps.length == 1 ? 0 : usable * i / (steps.length - 1);
    }
    var maxTotal = 0.0;
    for (final s in steps) {
      final col = nodes.values.where((n) => n.step == s).toList();
      final total = col.fold<double>(0, (a, n) => a + n.weight);
      if (total > maxTotal) maxTotal = total;
    }
    final scale = maxTotal == 0 ? 0 : (size.height - gap * (maxPerStep - 1)) / maxTotal;
    for (final s in steps) {
      final col = nodes.values.where((n) => n.step == s).toList()..sort((a, b) => b.weight.compareTo(a.weight));
      var y = 0.0;
      for (final n in col) {
        n.h = (n.weight * scale).clamp(3.0, size.height);
        n.top = y;
        y += n.h + gap;
      }
    }

    // Ribbons.
    for (final l in shown..sort((a, b) => b.value.compareTo(a.value))) {
      final a = nodes['${l.fromStep}|${l.from}']!;
      final b = nodes['${l.fromStep + 1}|${l.to}']!;
      final ha = l.value * scale;
      final y0 = a.top + a.usedOut;
      final y1 = b.top + b.usedIn;
      a.usedOut += ha;
      b.usedIn += ha;
      final x0 = colX[a.step]! + nodeW;
      final x1 = colX[b.step]!;
      final mid = (x0 + x1) / 2;
      final path = Path()
        ..moveTo(x0, y0)
        ..cubicTo(mid, y0, mid, y1, x1, y1)
        ..lineTo(x1, y1 + ha)
        ..cubicTo(mid, y1 + ha, mid, y0 + ha, x0, y0 + ha)
        ..close();
      final color = _palette[(steps.indexOf(a.step)) % _palette.length];
      canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.28));
    }

    // Node bars and labels.
    for (final n in nodes.values) {
      final x = colX[n.step]!;
      final color = _palette[(steps.indexOf(n.step)) % _palette.length];
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, n.top, nodeW, n.h), const Radius.circular(3)), Paint()..color = color);
      final tp = TextPainter(
        text: TextSpan(text: n.label, style: TextStyle(fontSize: 10.5, color: text, fontWeight: FontWeight.w500)),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: labelW - 8);
      final ly = (n.top + n.h / 2 - tp.height / 2).clamp(0.0, size.height - tp.height);
      tp.paint(canvas, Offset(x + nodeW + 5, ly));
    }
  }

  @override
  bool shouldRepaint(covariant _SankeyPainter old) => old.links != links || old.accent != accent;
}

import 'dart:math' as math;
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/theme/app_theme.dart';
import '../../core/util/format.dart';
import '../../data/models/insights.dart';
import 'countries.dart';
import 'land_mask.dart';

/// Rotating dotted globe with visitor bubbles per country. Drag to spin,
/// it drifts on its own when idle.
class Globe extends StatefulWidget {
  const Globe({super.key, required this.countries, required this.accent, this.size = 320, this.maxMarkers = 8});
  final List<CountryStat> countries;
  final Color accent;
  final double size;
  final int maxMarkers;

  @override
  State<Globe> createState() => _GlobeState();
}

class _GlobeState extends State<Globe> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _yaw = 0.6;
  double _pitch = 0.35;
  double _velocity = 0.004;
  bool _dragging = false;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    final first = widget.countries.where((c) => countryCentroids.containsKey(c.code)).firstOrNull;
    if (first != null) {
      final (lat, lon) = countryCentroids[first.code]!;
      _yaw = -lon * math.pi / 180;
      _pitch = (lat * math.pi / 180).clamp(-0.9, 0.9) * 0.6;
    }
    _ticker = createTicker(_tick)..start();
  }

  void _tick(Duration t) {
    final dt = _last == Duration.zero ? 16 : (t - _last).inMilliseconds.clamp(0, 50);
    _last = t;
    if (_dragging) return;
    if (_velocity.abs() < 0.0012) {
      _velocity = _velocity.isNegative ? -0.0012 : 0.0012;
    } else if (_velocity.abs() > 0.0012) {
      _velocity *= 0.96;
    }
    setState(() => _yaw += _velocity * dt / 16);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final r = widget.size / 2;
    return GestureDetector(
      onPanStart: (_) => _dragging = true,
      onPanUpdate: (d) => setState(() {
        _yaw += d.delta.dx / r;
        _pitch = (_pitch + d.delta.dy / r).clamp(-1.1, 1.1);
        _velocity = d.delta.dx / r * 0.5;
      }),
      onPanEnd: (_) => _dragging = false,
      onPanCancel: () => _dragging = false,
      child: CustomPaint(
        size: Size.square(widget.size),
        painter: _GlobePainter(
          yaw: _yaw,
          pitch: _pitch,
          countries: widget.countries.take(widget.maxMarkers).toList(),
          accent: widget.accent,
          ocean: c.surfaceRaised,
          land: c.textFaint,
          text: c.text,
          bubbleText: c.bg,
          dark: Theme.of(context).brightness == Brightness.dark,
        ),
      ),
    );
  }
}

class _GlobePainter extends CustomPainter {
  _GlobePainter({
    required this.yaw,
    required this.pitch,
    required this.countries,
    required this.accent,
    required this.ocean,
    required this.land,
    required this.text,
    required this.bubbleText,
    required this.dark,
  });

  final double yaw;
  final double pitch;
  final List<CountryStat> countries;
  final Color accent;
  final Color ocean;
  final Color land;
  final Color text;
  final Color bubbleText;
  final bool dark;

  /// Projects lat/lon (degrees) to (x, y, depth) on the unit sphere.
  (double, double, double) _project(double latDeg, double lonDeg) {
    final lat = latDeg * math.pi / 180;
    final lon = lonDeg * math.pi / 180 + yaw;
    final x = math.cos(lat) * math.sin(lon);
    final y = math.sin(lat);
    final z = math.cos(lat) * math.cos(lon);
    final cp = math.cos(pitch), sp = math.sin(pitch);
    final y2 = y * cp - z * sp;
    final z2 = y * sp + z * cp;
    return (x, y2, z2);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2 - 26;
    final center = Offset(size.width / 2, size.height / 2);

    // Sphere with a soft light from the top-left.
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.5),
          radius: 1.1,
          colors: [ocean.withValues(alpha: dark ? 0.9 : 1), Color.lerp(ocean, text, dark ? 0.08 : 0.16)!],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );

    // Land dots, bucketed by depth so we only issue a few draw calls.
    final buckets = List.generate(4, (_) => <Offset>[]);
    for (var row = 0; row < landRows; row++) {
      final lat = 90 - (row + 0.5) * 180 / landRows;
      final bits = landRowsBits[row];
      for (var col = 0; col < landCols; col++) {
        if (bits.codeUnitAt(col) != 49) continue;
        final lon = -180 + (col + 0.5) * 360 / landCols;
        final (x, y, z) = _project(lat, lon);
        if (z <= 0.02) continue;
        buckets[(z * 3.99).floor()].add(Offset(center.dx + x * r, center.dy - y * r));
      }
    }
    for (var i = 0; i < 4; i++) {
      if (buckets[i].isEmpty) continue;
      canvas.drawPoints(
        PointMode.points,
        buckets[i],
        Paint()
          ..color = land.withValues(alpha: 0.25 + 0.2 * i)
          ..strokeWidth = 2.4 + 0.5 * i
          ..strokeCap = StrokeCap.round,
      );
    }

    // Markers, back to front.
    final markers = <(double, Offset, CountryStat)>[];
    final maxV = countries.fold<double>(0, (a, c) => c.visitors > a ? c.visitors.toDouble() : a);
    for (final c in countries) {
      final cen = countryCentroids[c.code];
      if (cen == null) continue;
      final (x, y, z) = _project(cen.$1, cen.$2);
      if (z <= -0.1) continue;
      markers.add((z, Offset(center.dx + x * r, center.dy - y * r), c));
    }
    markers.sort((a, b) => a.$1.compareTo(b.$1));
    for (final (z, p, c) in markers) {
      final vis = ((z + 0.1) / 1.1).clamp(0.15, 1.0);
      final weight = maxV == 0 ? 0.5 : (c.visitors / maxV).clamp(0.2, 1.0);
      final glow = 10 + 18 * weight;
      canvas.drawCircle(p, glow, Paint()..color = accent.withValues(alpha: 0.18 * vis));
      canvas.drawCircle(p, 4, Paint()..color = accent.withValues(alpha: vis));
      canvas.drawCircle(p, 4, Paint()..color = bubbleText.withValues(alpha: 0.9 * vis)..style = PaintingStyle.stroke..strokeWidth = 1.5);
    }

    // Flag above, count bubble below. Busiest countries claim space first and
    // neighbours whose labels would overlap keep only their dot, so clusters
    // like France/Germany or Madagascar/Mauritius stay readable.
    final placed = <Rect>[];
    final byTraffic = [...markers]..sort((a, b) => b.$3.visitors.compareTo(a.$3.visitors));
    for (final (z, p, c) in byTraffic) {
      if (z <= 0.15) continue;
      final vis = ((z + 0.1) / 1.1).clamp(0.15, 1.0);
      final flag = TextPainter(
        text: TextSpan(text: c.flag, style: const TextStyle(fontSize: 16)),
        textDirection: TextDirection.ltr,
      )..layout();
      final label = TextPainter(
        text: TextSpan(
          text: Fmt.compact(c.visitors),
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: bubbleText.withValues(alpha: vis)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final bubble = Rect.fromCenter(center: p + const Offset(0, 16), width: label.width + 14, height: label.height + 6);
      final flagRect = Rect.fromLTWH(p.dx - flag.width / 2, p.dy - flag.height - 8, flag.width, flag.height);
      final footprint = flagRect.expandToInclude(bubble).inflate(2);
      if (placed.any((r) => r.overlaps(footprint))) continue;
      placed.add(footprint);

      flag.paint(canvas, flagRect.topLeft);
      canvas.drawRRect(RRect.fromRectAndRadius(bubble, const Radius.circular(9)), Paint()..color = accent.withValues(alpha: vis));
      label.paint(canvas, Offset(bubble.center.dx - label.width / 2, bubble.center.dy - label.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _GlobePainter old) =>
      old.yaw != yaw || old.pitch != pitch || old.countries != countries || old.accent != accent;
}

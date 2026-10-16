import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// The most prominent saturated colors in an image, most common first.
/// Greys, near-white and near-black pixels are ignored, so a logo on a white
/// background yields its brand colors. Returns at most [max] colors.
Future<List<Color>> extractLogoColors(String path, {int max = 5}) async {
  try {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 64);
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
    frame.image.dispose();
    if (data == null) return const [];

    final buckets = <int, _Bucket>{};
    for (var i = 0; i + 3 < data.lengthInBytes; i += 4) {
      final r = data.getUint8(i), g = data.getUint8(i + 1), b = data.getUint8(i + 2), a = data.getUint8(i + 3);
      if (a < 200) continue;
      final hsv = HSVColor.fromColor(Color.fromARGB(255, r, g, b));
      if (hsv.saturation < 0.28 || hsv.value < 0.2) continue;
      final key = (r >> 4) << 8 | (g >> 4) << 4 | (b >> 4);
      (buckets[key] ??= _Bucket()).add(r, g, b);
    }
    final sorted = buckets.values.toList()..sort((x, y) => y.n.compareTo(x.n));
    final out = <Color>[];
    for (final bucket in sorted) {
      final c = bucket.color;
      if (out.every((o) => _distance(o, c) > 70)) out.add(c);
      if (out.length >= max) break;
    }
    return out;
  } catch (_) {
    return const [];
  }
}

double _distance(Color a, Color b) {
  final dr = (a.r - b.r) * 255, dg = (a.g - b.g) * 255, db = (a.b - b.b) * 255;
  return math.sqrt(dr * dr + dg * dg + db * db);
}

class _Bucket {
  int n = 0, r = 0, g = 0, b = 0;
  void add(int rr, int gg, int bb) {
    n++;
    r += rr;
    g += gg;
    b += bb;
  }

  Color get color => Color.fromARGB(255, r ~/ n, g ~/ n, b ~/ n);
}

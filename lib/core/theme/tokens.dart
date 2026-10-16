import 'package:flutter/material.dart';

/// Design tokens for HogLens. Neutral surfaces, one accent per project.
class AppColors {
  const AppColors({
    required this.bg,
    required this.surface,
    required this.surfaceRaised,
    required this.border,
    required this.text,
    required this.textMuted,
    required this.textFaint,
    required this.positive,
    required this.negative,
    required this.gridLine,
  });

  final Color bg;
  final Color surface;
  final Color surfaceRaised;
  final Color border;
  final Color text;
  final Color textMuted;
  final Color textFaint;
  final Color positive;
  final Color negative;
  final Color gridLine;

  static const light = AppColors(
    bg: Color(0xFFEBEBEB),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFF0F0F0),
    border: Color(0xFFE3E3E3),
    text: Color(0xFF111111),
    textMuted: Color(0xFF6B6B6B),
    textFaint: Color(0xFFA3A3A3),
    positive: Color(0xFF22C55E),
    negative: Color(0xFFEF4444),
    gridLine: Color(0xFFEFEFEF),
  );

  static const dark = AppColors(
    bg: Color(0xFF0A0A0A),
    surface: Color(0xFF1A1A1B),
    surfaceRaised: Color(0xFF262628),
    border: Color(0xFF2C2C2E),
    text: Color(0xFFF3F3F1),
    textMuted: Color(0xFF9A9A97),
    textFaint: Color(0xFF5E5E5C),
    positive: Color(0xFF3FCB7C),
    negative: Color(0xFFF06B6B),
    gridLine: Color(0xFF222225),
  );
}

/// Brand colors from the logo. Projects still carry their own accent.
class Brand {
  static const Color orange = Color(0xFFFF6600);
  static const Color ink = Color(0xFF505050);
}

/// Accent colors. Projects store the color itself; [legacy] maps the old
/// stored index to a color for migration.
class Accents {
  static const List<Color> presets = [
    Brand.orange,
    Color(0xFFEF4444), // red
    Color(0xFFDB2777), // pink
    Color(0xFFC026D3), // fuchsia
    Color(0xFF7C3AED), // violet
    Color(0xFF4F46E5), // indigo
    Color(0xFF1C7CF2), // blue
    Color(0xFF0EA5E9), // sky
    Color(0xFF0D9488), // teal
    Color(0xFF16A34A), // green
    Color(0xFF65A30D), // lime
    Color(0xFFF59E0B), // amber
    Color(0xFF92400E), // brown
    Color(0xFF475569), // slate
    Color(0xFF3F3F46), // graphite
    Color(0xFF111111), // ink
  ];

  static const List<Color> legacy = [
    Brand.orange,
    Color(0xFF1C7CF2),
    Color(0xFF16A34A),
    Color(0xFF7C3AED),
    Color(0xFFDB2777),
    Color(0xFF0D9488),
    Color(0xFFF59E0B),
    Color(0xFF111111),
  ];

  static Color fromLegacyIndex(int i) => legacy[i.clamp(0, legacy.length - 1)];
}

extension AccentColorX on Color {
  /// Text/icon color that reads on top of this color.
  Color get onAccent => computeLuminance() > 0.45 ? const Color(0xFF111111) : Colors.white;

  /// "#FF6600"
  String get hex => '#${(toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  /// Contrast ratio against [other] (1 to 21).
  double contrastWith(Color other) {
    final a = computeLuminance(), b = other.computeLuminance();
    final hi = a > b ? a : b, lo = a > b ? b : a;
    return (hi + 0.05) / (lo + 0.05);
  }
}

Color? parseHexColor(String input) {
  var t = input.trim().replaceFirst('#', '');
  if (t.length == 3) t = t.split('').map((c) => '$c$c').join();
  if (t.length != 6 || int.tryParse(t, radix: 16) == null) return null;
  return Color(0xFF000000 | int.parse(t, radix: 16));
}

class Radii {
  static const double card = 28;
  static const double tile = 28;
  static const double chip = 999;
  static const double input = 18;
}

class Spacing {
  static const double page = 20;
  static const double gap = 12;
  static const double section = 28;
}

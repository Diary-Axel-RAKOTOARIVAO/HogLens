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

/// Accent palette a project can pick from. Index is persisted, not the color.
class Accents {
  static const List<Color> all = [
    Brand.orange, // logo orange
    Color(0xFF1C7CF2), // blue
    Color(0xFF16A34A), // green
    Color(0xFF7C3AED), // violet
    Color(0xFFDB2777), // pink
    Color(0xFF0D9488), // teal
    Color(0xFFF59E0B), // amber
    Color(0xFF111111), // ink
  ];

  static Color at(int i) => all[i.clamp(0, all.length - 1)];
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

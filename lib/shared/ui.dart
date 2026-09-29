import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shimmer/shimmer.dart';
import 'package:solar_icons/solar_icons.dart';

import '../core/i18n.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/tokens.dart';
import '../data/models/project.dart';

/// The HogLens mark. The hedgehog uses `currentColor`, so it follows the
/// text color of the theme while the bars stay brand orange.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 40, this.color});
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/brand/logo.svg',
      width: size,
      height: size,
      colorFilter: null,
      theme: SvgTheme(currentColor: color ?? context.colors.text),
    );
  }
}

/// Borderless white card on the gray canvas. No shadows anywhere in the app.
class Card1 extends StatelessWidget {
  const Card1({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.onLongPress,
    this.radius = Radii.card,
    this.color,
    this.clip = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double radius;
  final Color? color;

  /// Clips children to the rounded shape, for full-bleed charts.
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget body = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? c.surface,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );
    if (clip) body = ClipRRect(borderRadius: BorderRadius.circular(radius), child: body);
    if (onTap == null && onLongPress == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        onLongPress: onLongPress,
        child: body,
      ),
    );
  }
}

class ProjectAvatar extends StatelessWidget {
  const ProjectAvatar({super.key, required this.project, this.size = 48, this.file});

  final PhProject project;
  final double size;

  /// Overrides [project.logoPath], used while picking a logo.
  final File? file;

  @override
  Widget build(BuildContext context) {
    final path = file?.path ?? project.logoPath;
    final radius = BorderRadius.circular(size * 0.28);
    if (path != null && File(path).existsSync()) {
      return ClipRRect(
        borderRadius: radius,
        child: Image.file(File(path), width: size, height: size, fit: BoxFit.cover),
      );
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: project.accent, borderRadius: radius),
      child: Text(
        project.initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.38,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
      child: Row(
        children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
          ?trailing,
        ],
      ),
    );
  }
}

/// Small icon + letter-spaced uppercase label used at the top of stat cards.
class CardLabel extends StatelessWidget {
  const CardLabel(this.text, {super.key, required this.icon});
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        Icon(icon, size: 20, color: c.textMuted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      ],
    );
  }
}

/// Big number under a [CardLabel].
class BigValue extends StatelessWidget {
  const BigValue(this.text, {super.key, this.size = 30, this.color});
  final String text;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: size,
        height: 1.1,
        fontWeight: FontWeight.w600,
        letterSpacing: -1,
        color: color ?? context.colors.text,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

/// [BigValue] that counts from its previous value to the new one whenever
/// the number changes, so refreshes are visible.
class AnimatedBigValue extends StatelessWidget {
  const AnimatedBigValue(this.value, {super.key, this.format, this.size = 30, this.color, this.decimals = 0});
  final num value;
  final String Function(num)? format;
  final double size;
  final Color? color;

  /// Decimal places kept in intermediate frames (0 rounds to integers).
  final int decimals;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.toDouble()),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        final n = decimals == 0 ? v.round() : double.parse(v.toStringAsFixed(decimals));
        return BigValue(format == null ? '$n' : format!(n), size: size, color: color);
      },
    );
  }
}

/// Two-option switch whose highlight slides between the labels.
class SlidingToggle<T> extends StatelessWidget {
  const SlidingToggle({
    super.key,
    required this.value,
    required this.options,
    required this.labels,
    required this.onChanged,
    required this.background,
    required this.highlight,
    required this.foreground,
    required this.highlightForeground,
    this.segmentWidth = 64,
  });

  final T value;
  final List<T> options;
  final List<String> labels;
  final ValueChanged<T> onChanged;
  final Color background;
  final Color highlight;
  final Color foreground;
  final Color highlightForeground;
  final double segmentWidth;

  @override
  Widget build(BuildContext context) {
    final index = options.indexOf(value);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(Radii.chip)),
      child: SizedBox(
        width: segmentWidth * options.length,
        height: 30,
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              alignment: Alignment(options.length == 1 ? 0 : -1 + 2 * index / (options.length - 1), 0),
              child: Container(
                width: segmentWidth,
                height: 30,
                decoration: BoxDecoration(color: highlight, borderRadius: BorderRadius.circular(Radii.chip)),
              ),
            ),
            Row(
              children: [
                for (var i = 0; i < options.length; i++)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(options[i]),
                    child: SizedBox(
                      width: segmentWidth,
                      height: 30,
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 240),
                          style: TextStyle(
                            color: i == index ? highlightForeground : foreground,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                          child: Text(labels[i]),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Thick rounded progress bar.
class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key, required this.value, required this.color, this.height = 18});
  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: LinearProgressIndicator(
          value: value.clamp(0, 1),
          backgroundColor: c.surfaceRaised,
          color: color,
        ),
      ),
    );
  }
}

/// Red → yellow → green meter with a knob, for a signed score in [-1, 1].
class GradientMeter extends StatelessWidget {
  const GradientMeter({super.key, required this.score});
  final double score;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = ((score + 1) / 2).clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, box) {
        const knob = 22.0;
        return SizedBox(
          height: knob,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 12,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEF4444), Color(0xFFF59E0B), Color(0xFFFACC15), Color(0xFF22C55E)],
                  ),
                ),
              ),
              Positioned(
                left: (box.maxWidth - knob) * t,
                child: Container(
                  width: knob,
                  height: knob,
                  decoration: BoxDecoration(
                    color: c.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.bg, width: 2),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Label on the left, bold value on the right.
class KeyValueRow extends StatelessWidget {
  const KeyValueRow(this.label, this.value, {super.key, this.compact = false});
  final String label;
  final String value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final size = compact ? 11.5 : 15.0;
    return Padding(
      padding: EdgeInsets.only(top: compact ? 3 : 6),
      child: Row(
        children: [
          Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textMuted, fontSize: size))),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: size,
              color: c.text,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Black pill floating action button.
class PillFab extends StatelessWidget {
  const PillFab({super.key, required this.label, required this.icon, required this.onTap, this.color});
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  /// Background; defaults to the text color (black on light, white on dark).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    const fg = Colors.white;
    return Material(
      color: color ?? Brand.orange,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: fg),
              const SizedBox(width: 10),
              Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color, this.icon});
  final String text;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = color ?? c.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color == null ? c.surfaceRaised : fg.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Radii.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: fg), const SizedBox(width: 4)],
          Text(text, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: fg)),
        ],
      ),
    );
  }
}

class Skeleton extends StatelessWidget {
  const Skeleton({super.key, this.width, this.height = 16, this.radius = 8});
  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Shimmer.fromColors(
      baseColor: c.surfaceRaised,
      highlightColor: c.surface,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: c.surfaceRaised,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.leading,
  });
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  /// Replaces the icon circle, e.g. with the brand logo.
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            leading ??
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(color: c.surfaceRaised, shape: BoxShape.circle),
                  child: Icon(icon, color: c.textMuted, size: 28),
                ),
            const SizedBox(height: 18),
            Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textMuted, height: 1.4),
            ),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

class ErrorCard extends StatelessWidget {
  const ErrorCard({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Card1(
      child: Row(
        children: [
          Icon(SolarIconsOutline.dangerTriangle, color: c.negative, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: TextStyle(color: c.text, height: 1.35))),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: Text(tr('Retry'))),
        ],
      ),
    );
  }
}

class IconCircleButton extends StatelessWidget {
  const IconCircleButton({super.key, required this.icon, required this.onTap, this.tooltip});
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final b = Material(
      color: c.surface,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 48, height: 48, child: Icon(icon, size: 22, color: c.text)),
      ),
    );
    return tooltip == null ? b : Tooltip(message: tooltip!, child: b);
  }
}

void showToast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

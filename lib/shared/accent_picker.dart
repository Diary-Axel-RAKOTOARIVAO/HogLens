import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:solar_icons/solar_icons.dart';

import '../core/i18n.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/tokens.dart';

/// Inline accent chooser: logo suggestions and presets as a scrolling row,
/// ending with a "custom" swatch that opens the full picker.
class AccentField extends StatelessWidget {
  const AccentField({
    super.key,
    required this.value,
    required this.onChanged,
    this.logoColors = const [],
  });
  final Color value;
  final ValueChanged<Color> onChanged;
  final List<Color> logoColors;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Seven quick picks (logo colors first) plus the custom button, sized to
    // fit the width so nothing hides off screen.
    final quick = <Color>[];
    for (final q in [...logoColors, ...Accents.presets]) {
      if (quick.length == 7) break;
      if (quick.every((u) => u.toARGB32() != q.toARGB32())) quick.add(q);
    }
    final isCustom = quick.every((u) => u.toARGB32() != value.toARGB32());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, box) {
            const gap = 8.0;
            final size = ((box.maxWidth - gap * 7) / 8).clamp(30.0, 46.0);
            return Row(
              children: [
                for (final color in quick) ...[
                  SizedBox(
                    width: size,
                    height: size,
                    child: FittedBox(
                      child: _Swatch(
                        color: color,
                        selected: color.toARGB32() == value.toARGB32(),
                        onTap: () => onChanged(color),
                        fromLogo: logoColors.contains(color),
                      ),
                    ),
                  ),
                  const SizedBox(width: gap),
                ],
                SizedBox(
                  width: size,
                  height: size,
                  child: FittedBox(
                    child: _CustomSwatch(
                      selected: isCustom ? value : null,
                      onTap: () async {
                        final picked = await showAccentPicker(
                          context,
                          initial: value,
                          logoColors: logoColors,
                        );
                        if (picked != null) onChanged(picked);
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: value, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              value.hex,
              style: TextStyle(
                fontSize: 12.5,
                color: c.textMuted,
                fontFamily: 'Menlo',
              ),
            ),
            if (logoColors.isNotEmpty) ...[
              const SizedBox(width: 10),
              Icon(SolarIconsOutline.gallery, size: 13, color: c.textFaint),
              const SizedBox(width: 4),
              Text(
                tr('from your logo'),
                style: TextStyle(fontSize: 12, color: c.textFaint),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
    this.fromLogo = false,
  });
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final bool fromLogo;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 44,
        height: 44,
        padding: EdgeInsets.all(selected ? 4 : 0),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: color.contrastWith(c.bg) < 1.4
                ? Border.all(color: c.textFaint, width: 1)
                : null,
          ),
          child: fromLogo && !selected
              ? Align(
                  alignment: Alignment.bottomRight,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: c.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      SolarIconsBold.gallery,
                      size: 9,
                      color: c.textMuted,
                    ),
                  ),
                )
              : selected
              ? Icon(Icons.check_rounded, size: 18, color: color.onAccent)
              : null,
        ),
      ),
    );
  }
}

class _CustomSwatch extends StatelessWidget {
  const _CustomSwatch({required this.onTap, this.selected});
  final VoidCallback onTap;
  final Color? selected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        padding: EdgeInsets.all(selected != null ? 4 : 0),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: selected ?? Colors.transparent, width: 2),
        ),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected,
            gradient: selected == null
                ? const SweepGradient(
                    colors: [
                      Color(0xFFFF3B30),
                      Color(0xFFFF9500),
                      Color(0xFFFFCC00),
                      Color(0xFF34C759),
                      Color(0xFF00C7BE),
                      Color(0xFF007AFF),
                      Color(0xFFAF52DE),
                      Color(0xFFFF3B30),
                    ],
                  )
                : null,
          ),
          child: Icon(
            selected == null ? Icons.add_rounded : Icons.tune_rounded,
            size: 18,
            color: selected?.onAccent ?? Colors.white,
            shadows: selected == null
                ? [Shadow(color: c.text.withValues(alpha: 0.4), blurRadius: 4)]
                : null,
          ),
        ),
      ),
    );
  }
}

/// Full picker sheet: preview, logo colors, presets, and a custom
/// saturation/brightness pad with hue slider and hex input.
Future<Color?> showAccentPicker(
  BuildContext context, {
  required Color initial,
  List<Color> logoColors = const [],
}) {
  return showModalBottomSheet<Color>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _AccentSheet(initial: initial, logoColors: logoColors),
  );
}

class _AccentSheet extends StatefulWidget {
  const _AccentSheet({required this.initial, required this.logoColors});
  final Color initial;
  final List<Color> logoColors;

  @override
  State<_AccentSheet> createState() => _AccentSheetState();
}

class _AccentSheetState extends State<_AccentSheet> {
  late HSVColor _hsv = HSVColor.fromColor(widget.initial);
  late final TextEditingController _hex = TextEditingController(
    text: widget.initial.hex,
  );
  bool _lockScroll = false;

  Color get _color => _hsv.toColor();

  void _set(HSVColor h, {bool fromHex = false}) {
    setState(() => _hsv = h);
    if (!fromHex) _hex.text = _color.hex;
  }

  void _setColor(Color color) {
    HapticFeedback.selectionClick();
    _set(HSVColor.fromColor(color));
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = _color;
    final fill = context.accentFill(color);
    // Check both themes: the user can switch, and charts sit on cards.
    final tooLight = color.contrastWith(AppColors.light.surface) < 1.5;
    final tooDark = color.contrastWith(AppColors.dark.surface) < 1.5;
    final warning = tooLight
        ? tr('Very light: charts may be hard to see in light mode.')
        : tooDark
        ? tr('Very dark: charts may be hard to see in dark mode.')
        : null;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        physics: _lockScroll ? const NeverScrollableScrollPhysics() : null,
        padding: const EdgeInsets.fromLTRB(Spacing.page, 0, Spacing.page, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr('Accent color'),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 14),
            // Live preview: the hero card in miniature.
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              height: 86,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          tr('UNIQUE VISITORS'),
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.4,
                            color: fill.onAccent.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '2.98K',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: fill.onAccent,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  for (final h in const [14.0, 24.0, 18.0, 30.0, 22.0, 36.0])
                    Container(
                      width: 8,
                      height: h,
                      margin: const EdgeInsets.only(left: 5),
                      decoration: BoxDecoration(
                        color: fill.onAccent.withValues(
                          alpha: h == 36 ? 1 : 0.45,
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                ],
              ),
            ),
            if (widget.logoColors.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                tr('FROM YOUR LOGO'),
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final l in widget.logoColors)
                    _Swatch(
                      color: l,
                      selected: l.toARGB32() == color.toARGB32(),
                      onTap: () => _setColor(l),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            Text(tr('PRESETS'), style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, box) {
                const per = 8;
                final size = ((box.maxWidth - (per - 1) * 8) / per).clamp(
                  28.0,
                  44.0,
                );
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final p in Accents.presets)
                      SizedBox(
                        width: size,
                        height: size,
                        child: FittedBox(
                          child: _Swatch(
                            color: p,
                            selected: p.toARGB32() == color.toARGB32(),
                            onTap: () => _setColor(p),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            Text(tr('CUSTOM'), style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 10),
            _SvPad(
              hsv: _hsv,
              onChanged: (h) => _set(h),
              onLock: (v) => setState(() => _lockScroll = v),
            ),
            const SizedBox(height: 14),
            _HueSlider(
              hue: _hsv.hue,
              onChanged: (h) => _set(_hsv.withHue(h)),
              onLock: (v) => setState(() => _lockScroll = v),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _hex,
                    autocorrect: false,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(fontFamily: 'Menlo', fontSize: 15),
                    decoration: const InputDecoration(
                      hintText: '#FF6600',
                      isDense: true,
                    ),
                    onChanged: (t) {
                      final parsed = parseHexColor(t);
                      if (parsed != null) {
                        _set(HSVColor.fromColor(parsed), fromHex: true);
                      }
                    },
                  ),
                ),
              ],
            ),
            if (warning != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    SolarIconsOutline.dangerCircle,
                    size: 14,
                    color: c.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      warning,
                      style: TextStyle(fontSize: 12, color: c.textMuted),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: fill,
                foregroundColor: fill.onAccent,
              ),
              onPressed: () => Navigator.pop(context, color),
              child: Text(tr('Use this color')),
            ),
          ],
        ),
      ),
    );
  }
}

/// Saturation (x) and brightness (y) for the current hue. Raw pointer events
/// so the sheet doesn't scroll while you drag.
class _SvPad extends StatelessWidget {
  const _SvPad({
    required this.hsv,
    required this.onChanged,
    required this.onLock,
  });
  final HSVColor hsv;
  final ValueChanged<HSVColor> onChanged;
  final ValueChanged<bool> onLock;

  @override
  Widget build(BuildContext context) {
    const h = 170.0;
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        void set(Offset p) => onChanged(
          hsv
              .withSaturation((p.dx / w).clamp(0.0, 1.0))
              .withValue((1 - p.dy / h).clamp(0.0, 1.0)),
        );
        return _ClaimTouch(
          child: Listener(
            onPointerDown: (e) {
              onLock(true);
              set(e.localPosition);
            },
            onPointerMove: (e) => set(e.localPosition),
            onPointerUp: (_) => onLock(false),
            onPointerCancel: (_) => onLock(false),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                width: w,
                height: h,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: ColoredBox(
                        color: HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor(),
                      ),
                    ),
                    const Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.white, Color(0x00FFFFFF)],
                          ),
                        ),
                      ),
                    ),
                    const Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x00000000), Colors.black],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: hsv.saturation * w - 13,
                      top: (1 - hsv.value) * h - 13,
                      child: _Thumb(color: hsv.toColor()),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HueSlider extends StatelessWidget {
  const _HueSlider({
    required this.hue,
    required this.onChanged,
    required this.onLock,
  });
  final double hue;
  final ValueChanged<double> onChanged;
  final ValueChanged<bool> onLock;

  @override
  Widget build(BuildContext context) {
    const h = 30.0;
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        void set(Offset p) => onChanged(((p.dx / w).clamp(0.0, 1.0) * 359.9));
        return _ClaimTouch(
          child: Listener(
            onPointerDown: (e) {
              onLock(true);
              set(e.localPosition);
            },
            onPointerMove: (e) => set(e.localPosition),
            onPointerUp: (_) => onLock(false),
            onPointerCancel: (_) => onLock(false),
            child: SizedBox(
              width: w,
              height: h,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(h / 2),
                        gradient: LinearGradient(
                          colors: [
                            for (var i = 0; i <= 6; i++)
                              HSVColor.fromAHSV(
                                1,
                                i * 60.0 % 360,
                                1,
                                1,
                              ).toColor(),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: hue / 360 * w - 13,
                    top: 2,
                    child: _Thumb(
                      color: HSVColor.fromAHSV(1, hue, 1, 1).toColor(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Wins the gesture arena on pointer down, so ancestors (the sheet's
/// drag-to-dismiss, the scroll view) never see the drag.
class _ClaimTouch extends StatelessWidget {
  const _ClaimTouch({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => RawGestureDetector(
    gestures: {
      EagerGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
            EagerGestureRecognizer.new,
            (_) {},
          ),
    },
    child: child,
  );
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 26,
    height: 26,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 3),
      boxShadow: const [
        BoxShadow(
          color: Color(0x40000000),
          blurRadius: 6,
          offset: Offset(0, 1),
        ),
      ],
    ),
  );
}

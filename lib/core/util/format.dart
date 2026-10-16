import 'package:intl/intl.dart';

import '../i18n.dart' as i18n;

class Fmt {
  static final _compact = NumberFormat.compact();
  static final _full = NumberFormat.decimalPattern();

  static String compact(num? v) {
    if (v == null) return '—';
    if (v.abs() < 1000) return _full.format(v);
    return _compact.format(v);
  }

  static String full(num? v) => v == null ? '—' : _full.format(v);

  static String percent(double? v) {
    if (v == null || v.isNaN || v.isInfinite) return '—';
    final s = (v * 100).abs().toStringAsFixed(v.abs() < 0.1 ? 1 : 0);
    return '${v >= 0 ? '+' : '−'}$s%';
  }

  static String relative(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60) return i18n.tr('just now');
    final fr = i18n.currentLanguage == i18n.AppLanguage.fr;
    String ago(String v) => fr ? 'il y a $v' : '$v ago';
    if (d.inMinutes < 60) return ago('${d.inMinutes}m');
    if (d.inHours < 24) return ago('${d.inHours}h');
    return ago('${d.inDays}${fr ? 'j' : 'd'}');
  }

  /// "just now", "25s ago", "3m ago", "2h ago": finer than [relative].
  static String ago(DateTime t) {
    final d = DateTime.now().difference(t);
    final fr = i18n.currentLanguage == i18n.AppLanguage.fr;
    String f(String v) => fr ? 'il y a $v' : '$v ago';
    if (d.inSeconds < 10) return i18n.tr('just now');
    if (d.inSeconds < 60) return f('${d.inSeconds}s');
    if (d.inMinutes < 60) return f('${d.inMinutes}m');
    if (d.inHours < 24) return f('${d.inHours}h');
    return f('${d.inDays}${fr ? 'j' : 'd'}');
  }

  static String shortDay(DateTime t) => DateFormat('E').format(t);
  static String monthDay(DateTime t) => i18n.monthDay(t);
  static String hour(DateTime t) => DateFormat('HH:mm').format(t);
}

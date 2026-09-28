import 'package:intl/intl.dart';

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
    if (d.inSeconds < 60) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  static String shortDay(DateTime t) => DateFormat('E').format(t);
  static String monthDay(DateTime t) => DateFormat('MMM d').format(t);
  static String hour(DateTime t) => DateFormat('HH:mm').format(t);
}

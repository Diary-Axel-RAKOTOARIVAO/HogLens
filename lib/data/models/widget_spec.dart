import 'package:flutter/foundation.dart';

import '../../core/i18n.dart';

/// How a custom widget renders its HogQL result.
enum WidgetKind {
  number('Number', 'First cell of the first row'),
  sparkline('Trend', 'Rows of (time, value)'),
  bars('Bars', 'Rows of (label, value)'),
  table('Table', 'Raw rows and columns');

  const WidgetKind(this._label, this.hint);
  final String _label;
  String get label => tr(_label);
  final String hint;
}

enum WidgetSize { half, full }

/// A user-defined dashboard widget backed by a HogQL query.
///
/// The query may contain `{range}` which is replaced with the active
/// dashboard range, e.g. `now() - INTERVAL 7 DAY`.
@immutable
class StatWidgetSpec {
  const StatWidgetSpec({
    required this.id,
    required this.title,
    required this.hogql,
    required this.kind,
    this.size = WidgetSize.half,
    this.subtitle,
    this.presetId,
    this.compare = false,
  });

  final String id;
  final String title;
  final String hogql;
  final WidgetKind kind;
  final WidgetSize size;
  final String? subtitle;
  final String? presetId;

  /// Number widgets only: also run the query for the previous window and
  /// show the change. Requires `{range}` in the query.
  final bool compare;

  StatWidgetSpec copyWith({
    String? title,
    String? hogql,
    WidgetKind? kind,
    WidgetSize? size,
    String? subtitle,
    bool? compare,
  }) =>
      StatWidgetSpec(
        id: id,
        title: title ?? this.title,
        hogql: hogql ?? this.hogql,
        kind: kind ?? this.kind,
        size: size ?? this.size,
        subtitle: subtitle ?? this.subtitle,
        presetId: presetId,
        compare: compare ?? this.compare,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'hogql': hogql,
        'kind': kind.name,
        'size': size.name,
        'subtitle': subtitle,
        'presetId': presetId,
        'compare': compare,
      };

  factory StatWidgetSpec.fromJson(Map<String, dynamic> j) => StatWidgetSpec(
        id: j['id'] as String,
        title: j['title'] as String,
        hogql: j['hogql'] as String,
        kind: WidgetKind.values.byName(j['kind'] as String? ?? 'number'),
        size: WidgetSize.values.byName(j['size'] as String? ?? 'half'),
        subtitle: j['subtitle'] as String?,
        presetId: j['presetId'] as String?,
        compare: j['compare'] as bool? ?? false,
      );
}

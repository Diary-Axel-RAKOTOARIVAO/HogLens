import '../../data/models/widget_spec.dart';

class WidgetPreset {
  const WidgetPreset({
    required this.id,
    required this.title,
    required this.description,
    required this.kind,
    required this.hogql,
    this.size = WidgetSize.half,
  });

  final String id;
  final String title;
  final String description;
  final WidgetKind kind;
  final String hogql;
  final WidgetSize size;

  StatWidgetSpec toSpec(String id) => StatWidgetSpec(
        id: id,
        title: title,
        hogql: hogql,
        kind: kind,
        size: size,
        presetId: this.id,
      );
}

/// Starting points for custom widgets. `{range}` is swapped for the
/// dashboard range at query time.
const List<WidgetPreset> widgetPresets = [
  WidgetPreset(
    id: 'signups',
    title: 'Sign-ups',
    description: 'Count of a custom event in range',
    kind: WidgetKind.number,
    hogql: "SELECT count() FROM events WHERE event = 'user signed up' AND timestamp >= {range}",
  ),
  WidgetPreset(
    id: 'new_users',
    title: 'New users',
    description: 'People first seen in range',
    kind: WidgetKind.number,
    hogql: 'SELECT count() FROM persons WHERE created_at >= {range}',
  ),
  WidgetPreset(
    id: 'events_per_hour',
    title: 'Events per hour',
    description: 'Hourly trend of all events',
    kind: WidgetKind.sparkline,
    size: WidgetSize.full,
    hogql: 'SELECT toStartOfHour(timestamp) AS h, count() FROM events WHERE timestamp >= {range} GROUP BY h ORDER BY h LIMIT 1000',
  ),
  WidgetPreset(
    id: 'top_pages',
    title: 'Top pages',
    description: 'Most viewed URLs',
    kind: WidgetKind.bars,
    size: WidgetSize.full,
    hogql: "SELECT properties.\$pathname AS path, count() AS views FROM events WHERE event = '\$pageview' AND timestamp >= {range} GROUP BY path ORDER BY views DESC LIMIT 6",
  ),
  WidgetPreset(
    id: 'countries',
    title: 'Countries',
    description: 'Users by GeoIP country',
    kind: WidgetKind.bars,
    hogql: 'SELECT properties.\$geoip_country_name AS country, uniq(person_id) AS users FROM events WHERE timestamp >= {range} AND country IS NOT NULL GROUP BY country ORDER BY users DESC LIMIT 5',
  ),
  WidgetPreset(
    id: 'browsers',
    title: 'Browsers',
    description: 'Sessions by browser',
    kind: WidgetKind.bars,
    hogql: 'SELECT properties.\$browser AS browser, uniq(properties.\$session_id) AS sessions FROM events WHERE timestamp >= {range} AND browser IS NOT NULL GROUP BY browser ORDER BY sessions DESC LIMIT 5',
  ),
  WidgetPreset(
    id: 'os',
    title: 'Operating systems',
    description: 'Users by OS',
    kind: WidgetKind.bars,
    hogql: 'SELECT properties.\$os AS os, uniq(person_id) AS users FROM events WHERE timestamp >= {range} AND os IS NOT NULL GROUP BY os ORDER BY users DESC LIMIT 5',
  ),
  WidgetPreset(
    id: 'exceptions',
    title: 'Exceptions',
    description: 'Errors captured in range',
    kind: WidgetKind.number,
    hogql: "SELECT count() FROM events WHERE event = '\$exception' AND timestamp >= {range}",
  ),
  WidgetPreset(
    id: 'flag_calls',
    title: 'Flag evaluations',
    description: 'Feature flag calls in range',
    kind: WidgetKind.number,
    hogql: "SELECT count() FROM events WHERE event = '\$feature_flag_called' AND timestamp >= {range}",
  ),
  WidgetPreset(
    id: 'recent_events',
    title: 'Recent events',
    description: 'Latest 8 events with person',
    kind: WidgetKind.table,
    size: WidgetSize.full,
    hogql: 'SELECT event, distinct_id, timestamp FROM events WHERE timestamp >= {range} ORDER BY timestamp DESC LIMIT 8',
  ),
  WidgetPreset(
    id: 'blank',
    title: 'Blank query',
    description: 'Start from scratch',
    kind: WidgetKind.number,
    hogql: 'SELECT count() FROM events WHERE timestamp >= {range}',
  ),
];

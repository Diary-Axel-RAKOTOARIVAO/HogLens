# HogLens

**All your PostHog projects. One lens.**

A clean, native-feeling PostHog companion for iOS and Android, built with Flutter.

- Add any number of PostHog projects: US Cloud, EU Cloud or self-hosted.
- Each project gets a name, an uploaded logo and an accent color.
- Key stats per project with deltas versus the previous period: events, active users, pageviews, sessions, events per user, and people active in the last five minutes.
- Events trend chart and top events, switchable between 24h / 7d / 30d.
- Custom widgets backed by any HogQL query, rendered as a number, trend, bar list or table, half or full width, reorderable. A preset gallery gets you started.
- Live feed of the newest events, refreshed every ten seconds, with a filter by event name.
- Errors screen grouping `$exception` events by type and message with counts, people affected and a trend.
- Tap a top event to see its trend, reach, top pages and browsers over the window.
- Behavior: lifecycle, weekly retention and navigation paths from PostHog's insight engine.
- Worldwide: visitors by country on a rotating 3D globe with a ranked list.
- Android home-screen widget with visitors today, refreshed in the background every 30 minutes.
- Feature flags list per project.
- Home screen visitor totals across all projects and an update banner when a newer GitHub release exists.
- Traffic sources from UTM tags and referrers, with brand logos, campaigns and landing pages.
- Light and dark themes follow the system.
- A demo project with fake data lets you explore without a key.

## Connecting a project

1. In PostHog go to Settings → Personal API keys and create a key with at least the `project:read`, `query:read` and `feature_flag:read` scopes.
2. In HogLens tap **Add project**, choose the host, paste the key and tap **Connect**.
3. Pick a project. Project-scoped keys cannot list projects directly, so the app falls back to the organization's team list and validates the pick; you can also type the numeric project ID from the PostHog URL.
4. Name it, upload a logo, pick an accent.

The key is stored in the iOS Keychain / Android encrypted storage and is only ever sent to the host you chose.

## Custom widgets

Widgets run a HogQL query through `POST /api/projects/:id/query/`. Use `{range}` (window start) and optionally `{range_end}` in the query to follow the dashboard range, for example:

```sql
SELECT count() FROM events WHERE event = 'user signed up' AND timestamp >= {range}
```

- **Number** shows the first cell of the first row. Turn on "Compare with previous period" to also show the change versus the window before.
- **Trend** expects rows of `(time, value)`.
- **Bars** expects rows of `(label, value)`.
- **Table** renders the raw result, up to ten rows.

PostHog limits personal keys to three concurrent queries and 240 requests per minute; the client serializes calls accordingly.

## Brand

The brand source files live in `brand/`. To rebuild the app's icons, splash screens and in-app logo from them:

```bash
tool/brand.sh
```

## Development

```bash
flutter pub get
flutter run
```

```bash
flutter analyze && flutter test
```

Live check against a real host (skipped when the variables are absent):

```bash
PH_KEY=phx_… PH_PROJECTS=12345 flutter test test/live_api_test.dart -r expanded --concurrency=1
```

Layout:

- `lib/core` theme tokens and formatters
- `lib/data` models, secure storage, API client, stats queries, Riverpod providers
- `lib/features` projects, dashboard, custom widgets, flags
- `lib/shared` reusable UI pieces

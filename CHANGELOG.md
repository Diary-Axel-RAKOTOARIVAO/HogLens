# Changelog

All notable changes to HogLens. Format follows [Keep a Changelog](https://keepachangelog.com/);
the section for a tag becomes the GitHub Release notes.

## [Unreleased]

## [1.2.1] - 2026-10-19

### Fixed
- Traffic sources show the real ChatGPT, Claude and Gemini logos, as their own app icons present them: the OpenAI knot on black, Claude's starburst in terracotta on cream, and Gemini's four-color star. ChatGPT previously had a generic sparkle, and Claude and Gemini were flattened to one color.

## [1.2.0] - 2026-10-19

### Added
- Traffic sources on the dashboard, in place of Top events: a channel bar (paid social, social, direct, referral, search, AI, email…) and the top sources with their logos, such as Facebook, Instagram, Google, ChatGPT, Gemini, WhatsApp and TikTok, showing sessions, share and how much of it is paid. Tap a source for its trend, UTM campaigns with their medium, and landing pages. Built from PostHog's sessions table, so UTM tags and referrers are both counted.

### Changed
- New Eyepiece Glint brand: launcher icons (including Android themed icons), splash screens and the logo inside the app.
- Top events moved to the Behavior screen, still with tap-to-drill-down. The dashboard makes one query fewer per refresh.

### Fixed
- The app could crash shortly after opening on some Android devices: home-screen widget images were rendered with Flutter in the background, which failed on some graphics drivers. Widgets now draw their charts natively, and nothing is rendered or fetched for widgets when none is on the home screen.
- Home-screen widget charts used the default orange instead of the project's accent color.

## [1.1.0] - 2026-10-16

### Added
- New accent color picker: colors suggested from your uploaded logo, 16 presets, and a custom picker with a saturation/brightness pad, hue slider and hex field, all with a live preview. Uploading a logo when adding a project picks its main color automatically.
- "Updated 20s ago" next to the refresh button, so you can see how fresh the dashboard is.
- Reorder mode on the projects page with drag handles, plus a lift and haptic tap when you long-press a card to move it.

### Changed
- The dashboard refreshes every 30 seconds while open (was 60). Coming back to any screen refreshes it right away if its data is more than 15 seconds old.
- Errors and Worldwide refresh every minute while open; every screen loads fresh data each time you open it, showing the saved copy until the new one arrives.
- Accent colors are stored as real colors. Existing projects keep their color.

### Fixed
- Opening the app on a new day showed yesterday's numbers as "Today" until the network answered.
- The "Offline" badge flashed on every launch while fresh data was loading.
- When PostHog is briefly overloaded or rate-limiting, requests are retried instead of failing, and a refresh that really fails says "Couldn't refresh" rather than "Offline".

## [1.0.0] - 2026-10-01

First stable release. Same app as 0.10.0, now considered ready for everyday use.

### Highlights
- Any number of PostHog projects on US, EU or self-hosted instances, each with its own name, logo and accent, keys kept in the device keychain.
- Dashboard with unique visitors, events, live pulse, sessions and trends over Today, rolling, this-month or custom windows, plus custom HogQL widgets.
- Live feed, errors, behavior (lifecycle, retention, paths), a 3D world view and feature flags.
- Six Android home-screen widgets from 2×1 to 4×3.
- Offline copies of everything already loaded, refresh-while-visible, English and French, light and dark themes.

## [0.10.0] - 2026-10-01

### Added
- Data stays fresh while you look at it: the projects page and the dashboard refresh every minute, the live feed every ten seconds. Polling only runs while that screen is open and the app is in the foreground; coming back to the app refreshes anything older than the interval right away.

### Fixed
- The live feed kept querying PostHog every ten seconds after leaving the screen. It now stops as soon as the screen is closed or the app goes to the background.
- The live feed and custom widgets ask PostHog for a fresh result instead of a cached one.
- Refreshes no longer flash the "Offline" badge for a moment.

## [0.9.2] - 2026-10-01

### Added
- Refresh button next to the time range on the dashboard. It reloads the stats and every custom widget, and spins while loading.

## [0.9.1] - 2026-09-29

### Fixed
- Visitors today on the projects page now matches the dashboard: both count from local midnight, not UTC midnight.
- Splash screen shows the logo cleanly instead of a cropped white disc, on Android 12+ and older versions, light and dark.
- Dragging the globe vertically now tilts it the way your finger moves.
- A little more breathing room around the logo on the projects page.

## [0.9.0] - 2026-09-29

### Added
- Six Android home-screen widgets, smallest to largest: Visitors (2×1), Live now (2×2), Errors (2×2), Week (3×2), Overview (4×2) and Trend (4×3) with today's hourly curve. Pick them from Project settings → Add to home screen. All follow the same project, adapt to dark mode and refresh every 30 minutes in the background.

## [0.8.1] - 2026-09-29

### Fixed
- Launcher icons had too much padding; the logo now fills the icon properly on Android and iOS.

## [0.8.0] - 2026-09-29

### Added
- The HogLens logo everywhere: launcher icons on Android (adaptive, with a monochrome variant) and iOS, a light and dark splash screen, the projects page header, the empty state and the About card.
- "Today" time range, from midnight to now with hourly buckets, compared with the same hours yesterday. It is the default when opening a project, matching the visitors-today number on the projects page.

### Changed
- Base theme uses the logo orange for primary buttons, the add-widget pill and progress indicators. Projects keep their own accent colors.
- Language options show flags instead of globe icons.

## [0.7.0] - 2026-09-29

### Added
- App settings, reachable from the gear on the projects page: appearance (system, light or dark), language (English or French), the app version, a check-for-updates action, and links to star HogLens on GitHub or report a problem.
- French translation of every main screen, including dates and relative times.

### Fixed
- Trends tile rows no longer wrap on narrow phones: labels truncate and the change badges stay on one line.

## [0.6.0] - 2026-09-28

### Added
- Behavior screen: user lifecycle (new, returning, resurrecting, dormant) as stacked bars, weekly retention cohorts as a heat grid, and navigation paths as a flow diagram. These use PostHog's own insight engine, so they are computed and cached server-side instead of scanning events with hand-written queries.
- Worldwide screen: visitors by country on a rotating 3D globe with flag markers and counts, plus the ranked list with shares.
- Android home-screen widget showing a project's visitors today, change versus yesterday, the seven-day strip and the weekly total, refreshed every 30 minutes in the background. Pick the project and add the widget from Project settings.
- The live feed is a timeline: connected icon markers per event type, person id and page on each entry.

## [0.5.1] - 2026-09-28

### Changed
- The projects page shows unique visitors instead of events: each card has today's visitors with a seven-day strip, and the totals strip shows visitors today and unique visitors over seven days across all projects.

## [0.5.0] - 2026-09-28

### Added
- Live feed: tap the Live pulse tile (or open it from the project menu) to tail the newest events, refreshed every ten seconds, with a filter by event name.
- Errors screen: `$exception` events over the selected window grouped by type and message, with counts, people affected, first and last seen, and a trend.
- Tap any row in Top events to see that event's trend, reach, top pages and browsers over the window.
- Number widgets can compare with the previous period and show the change.
- The home screen sums today's and the last seven days' events across all projects, at no extra cost.
- An update banner appears on the home screen when a newer release exists on GitHub, linking to the download.

## [0.4.2] - 2026-09-28

### Changed
- The time range drawer matches the rest of the app: preset cards with icons and descriptions, and a built-in calendar for custom dates instead of the system picker. Tap a start day, then an end day; quick chips give the last 14, 60 or 90 days.

## [0.4.1] - 2026-09-28

### Changed
- The project logo and name sit on the right of the dashboard header, opposite the back button.

## [0.4.0] - 2026-09-28

### Changed
- The dashboard header shows the project logo and name; tap it for feature flags and project settings. The two header buttons are gone.
- The time range is a single pill showing the active range; tapping it opens the list of ranges and the custom date picker, so nothing is clipped on narrow phones.
- The Unique / All switch slides between its options instead of snapping.
- Numbers count up to their new value on load and on every refresh.
- Smaller type inside the square tiles so the session ratios and captions no longer collide.

## [0.3.0] - 2026-09-28

### Added
- Offline mode: the last fetched dashboard, custom widget results, feature flags and home-card numbers are saved on the device. Without a connection the app shows them with an "Offline · saved …" badge and refreshes when the network is back.

### Changed
- APKs are much smaller: native libraries are now compressed inside the package and Java code is shrunk with R8.
- APKs are signed with the v1, v2 and v3 schemes so older or stricter sideload installers accept them.

## [0.2.0] - 2026-09-28

### Added
- Date range picker now offers the current month by name (for example "September") and a custom start and end date, alongside 24h, 7d and 30d. Custom widgets follow the chosen window through `{range}` and the new `{range_end}` placeholder.
- The hero card shows unique visitors, with a toggle to all views, over the selected window. Both count `$pageview` and `$screen` events, so mobile projects are covered too.

### Changed
- Secondary tiles are square: events with a per-bucket column chart, live pulse with the 24-hour strip, sessions with engagement ratios, and a trends scoreboard for visitors, views, events and sessions.
- Windows are sent to PostHog as explicit timestamps instead of "now minus N days", so the previous-period comparison always covers exactly the same length.

### Fixed
- Hourly series no longer gain an extra empty bucket when the window starts mid-hour.

## [0.1.1] - 2026-09-28

### Fixed
- Release builds on Android could not reach any PostHog host ("Could not reach https://us.posthog.com") because the internet permission was only declared for debug builds. Connecting now works on installed APKs.
- Network errors now include the underlying cause to make them easier to diagnose.

## [0.1.0] - 2026-09-28

### Added
- Connect any number of PostHog projects on US Cloud, EU Cloud or a self-hosted instance with a personal API key. Keys are stored in the device Keychain or encrypted storage and only ever sent to the host you chose.
- Name each project, upload a logo and pick an accent color. Project-scoped keys are supported: the app lists the organization's teams and validates the one you pick, or takes a project ID typed by hand.
- Dashboard per project with a 24h / 7d / 30d switch: events with trend and change versus the previous period, active users with a daily column chart, live users in the last five minutes with a 24-hour activity strip, sessions with engagement ratios, a trends scoreboard, and ranked top events with share of total.
- Custom widgets backed by any HogQL query, shown as a number, trend, bars or table at half or full width, with a preset gallery, a test-query button, editing and drag-to-reorder.
- Feature flags list per project with rollout percentage and status.
- Project cards on the home screen with today's event count and a seven-day bar strip, reorderable by long press.
- Light and dark themes following the system, and a demo project with sample data to explore without a key.

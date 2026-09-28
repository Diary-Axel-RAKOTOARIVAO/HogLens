# Changelog

All notable changes to HogLens. Format follows [Keep a Changelog](https://keepachangelog.com/);
the section for a tag becomes the GitHub Release notes.

## [Unreleased]

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

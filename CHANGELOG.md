# Changelog

All notable changes to HogLens. Format follows [Keep a Changelog](https://keepachangelog.com/);
the section for a tag becomes the GitHub Release notes.

## [Unreleased]

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

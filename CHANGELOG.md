# Changelog

## Unreleased

## 0.5.3 — 2026-09-12

First repository prerelease. Requires macOS 15+. Ad-hoc signed; not notarized.

- Native per-application mixer, device choices, profiles, EQ and Audio Unit effects.
- Bundled local Chromium tab companion (0.5.0), including Arc integration.
- Vinyl/artwork listening views, customization and native/browser metadata integrations.
- Default-on automatic artwork for the selected visible song, with debounce and cooldown.
- Temporary service-error retry, Retry-After backoff and title-only public-page suggestions.
- Measured cover-quality preference, bounded JPEG cache, and preserved covers during failed refresh.

Validation: 31 native checks and 83 listening checks passed locally. Browser checks run in CI. Recent artwork changes were not live-tested with providers, browsers or audio hardware. Independent Safari tab capture is not implemented.

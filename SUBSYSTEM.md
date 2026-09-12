---
name: application-listening-control
definition: >
  Provide independently operable application listening choices, optional tab choices in supported browsers, and source-bound listening presentation and supported media actions while preserving ordinary playback whenever controlled delivery is inactive or cannot be established. Without this system the listener cannot consistently direct application sound or understand whether requested adjustments are active.
inputs:
  - name: listener-intent
    description: >
      Requested application and browser-tab listening changes, focused presentation, visual theme, fallback photo mood, record motion speed and source pinning, optional media access, supported playback actions, selected-track cover lookup and retention choices, browser activation gestures, and recovery actions, supplied by the listener so listening behavior reflects their choices.
  - name: platform-observation
    description: >
      Available applications and browser tabs, independently scoped device and effect capabilities, device visibility permissions, actual settings and listening-window presentation state, local companion installation and browser-integration availability, and lifecycle changes, supplied by the host so listening decisions reflect current conditions.
  - name: source-audio
    description: >
      Time-ordered application or independently captured tab sound and its source identity, supplied by audio producers so each chosen adjustment affects the intended sound.
  - name: retained-intent
    description: >
      Previously retained listening choices and visual theme, fallback photo mood, scene, speed and automatic-artwork preferences identified independently of transient source instances, supplied by durable storage so durable choices survive relaunch without restoring stale source pins.
  - name: media-observation
    description: >
      Source-bound published track details, artwork references or content, playback state, available action capabilities, access failures, and requested action outcomes, supplied by media publishers so listening context reflects actual source information.
  - name: artwork-observation
    description: >
      Candidate cover identity, candidate artist and release, catalog or public-page provenance, corroborated-match or title-only-suggestion status, same-cover image variants and measured dimensions and size, and absent, blocked, or failed outcomes, supplied by media publishers so image quality can be assessed without changing or overstating source identity.
  - name: artwork-cache-observation
    description: >
      Previously retained verified covers, explicitly labeled title-only suggestions, or known misses with matching and quality-policy identity, provenance, measured image dimensions, expiration, and retained size, supplied by local retention so current imagery remains reusable without confusing confidence, quality, or policy validity.
outputs:
  - name: listener-feedback
    description: >
      Available listening controls and actual outcomes, including unavailable choices and recovery actions, so the listener can understand and direct playback.
  - name: platform-adjustment
    description: >
      Requested device settings, interception lifetime changes, listening-window presentation changes, and application-owned local companion availability and browser registration, supplied to the host so listening behavior and presentation follow intent without listener-managed files or host configuration.
  - name: delivered-audio
    description: >
      Time-ordered adjusted sound assigned to the selected available output, supplied to audio consumers so the intended listening result is audible.
  - name: intent-retention
    description: >
      Current durable listening choices and visual theme, fallback photo mood, scene, speed and automatic-artwork preferences, supplied to storage so future sessions recover preferences without treating them as confirmed playback or restoring stale source pins.
  - name: media-request
    description: >
      Source-scoped requests for permitted media observations or explicitly requested supported playback actions, supplied to media publishers so context and actions are limited to the authorized source and capability.
  - name: artwork-request
    description: >
      An authorized automatic or explicitly requested cover lookup for the selected visible source containing observed media identity or a clearly distinguished title-only search hint and an optional permitted public source reference, supplied to approved catalogs or bounded public-page discovery so verified and suggested artwork remain limited to the current source and retained lookup preference.
  - name: artwork-cache-retention
    description: >
      Bounded verified-cover, title-only-suggestion or miss entries with matching and quality-policy identity, candidate attribution, measured prepared dimensions, retained size and expiry, together with explicit refresh and clear intent, supplied to local retention so reuse remains time-limited, attributable, quality-aware, and removable.
---

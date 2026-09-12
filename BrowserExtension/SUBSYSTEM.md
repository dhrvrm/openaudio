---
name: browser-tab-delivery
definition: >
  Give each explicitly activated tab in a supported browser its own listening level and permitted destination while holding exclusive ownership of the participating browser playback, and provide permitted source-bound page media context and fixed playback actions only where the current player exposes a verified capability. Without this boundary independently audible tabs collapse into one application source and cannot be controlled separately.
inputs:
  - name: tab-delivery-intent
    description: >
      The desired independently controlled tab levels, mute states, browser-scoped output choices, explicit source focus and optional page access, fixed capability-gated playback requests bound to the current browser session, tab and document, exclusive playback ownership grants, and release requests, supplied by control so browser behavior follows intent without overlapping native delivery or acting on another page.
  - name: listener-intent
    description: >
      Requested application and browser-tab listening changes, focused presentation, visual theme, fallback photo mood, record motion speed and source pinning, optional media access, supported playback actions, selected-track cover lookup and retention choices, browser activation gestures, and recovery actions, supplied by the listener so listening behavior reflects their choices.
  - name: platform-observation
    description: >
      Available applications and browser tabs, independently scoped device and effect capabilities, device visibility permissions, actual settings and listening-window presentation state, local companion installation and browser-integration availability, and lifecycle changes, supplied by the host so listening decisions reflect current conditions.
  - name: source-audio
    description: >
      Time-ordered application or independently captured tab sound and its source identity, supplied by audio producers so each chosen adjustment affects the intended sound.
  - name: media-observation
    description: >
      Source-bound published track details, artwork references or content, playback state, available action capabilities, access failures, and requested action outcomes, supplied by media publishers so listening context reflects actual source information.
outputs:
  - name: tab-delivery-observation
    description: >
      Browser, session, tab and document identity, automatically refreshed activity, permitted source-bound media context and known-player observations with provenance and freshness, available fixed playback capabilities and request outcomes, permitted browser outputs and catalog freshness, ownership, applied settings, failures, and confirmed capture release, supplied by browser delivery so control can show actual capabilities and outcomes.
  - name: listener-feedback
    description: >
      Available listening controls and actual outcomes, including unavailable choices and recovery actions, so the listener can understand and direct playback.
  - name: platform-adjustment
    description: >
      Requested device settings, interception lifetime changes, listening-window presentation changes, and application-owned local companion availability and browser registration, supplied to the host so listening behavior and presentation follow intent without listener-managed files or host configuration.
  - name: delivered-audio
    description: >
      Time-ordered adjusted sound assigned to the selected available output, supplied to audio consumers so the intended listening result is audible.
  - name: media-request
    description: >
      Source-scoped requests for permitted media observations or explicitly requested supported playback actions, supplied to media publishers so context and actions are limited to the authorized source and capability.
---

---
name: listening-control
definition: >
  Own durable application listening intent, session-scoped tab choices, application-owned optional browser availability, and exclusive native or browser playback ownership, and reconcile its presentation with observed delivery without claiming that a requested change has already succeeded. Without this boundary choices would diverge across presentations or disappear between sessions.
inputs:
  - name: listening-edit
    description: >
      Requested source-specific changes to routing, processing, device settings, listening focus, visual theme and fallback photo mood, scene selection and motion preference, optional media access, supported playback actions, selected-track cover lookup and retention choices, browser activation, and control lifetime, supplied by the interface so intent has a single authority.
  - name: delivery-observation
    description: >
      Observed native sources and device capabilities, permission status, confirmed interception exclusions, active delivery outcomes, activity, and failures, supplied by delivery so control can distinguish intent from reality.
  - name: retained-intent
    description: >
      Previously retained listening choices and visual theme, fallback photo mood, scene, speed and automatic-artwork preferences identified independently of transient source instances, supplied by durable storage so durable choices survive relaunch without restoring stale source pins.
  - name: tab-delivery-observation
    description: >
      Browser, session, tab and document identity, automatically refreshed activity, permitted source-bound media context and known-player observations with provenance and freshness, available fixed playback capabilities and request outcomes, permitted browser outputs and catalog freshness, ownership, applied settings, failures, and confirmed capture release, supplied by browser delivery so control can show actual capabilities and outcomes.
  - name: platform-observation
    description: >
      Available applications and browser tabs, independently scoped device and effect capabilities, device visibility permissions, actual settings and listening-window presentation state, local companion installation and browser-integration availability, and lifecycle changes, supplied by the host so listening decisions reflect current conditions.
  - name: listening-context
    description: >
      The resolved source identity, provenance and freshness of observed track details, verified or explicitly suggested artwork with candidate attribution, fallback reason, supported media actions, and action outcomes, supplied by context resolution so presentation never represents a suggestion as identified source metadata.
outputs:
  - name: delivery-intent
    description: >
      The complete desired native source routing and processing configuration, requested device settings, exclusive browser ownership exclusions, and control lifetime, supplied by control so native delivery has an unambiguous target.
  - name: listening-presentation
    description: >
      Current application and browser-tab choices, observed outcomes, source-specific capabilities and freshness, focused media context, visual theme and fallback photo mood, scene, motion and automatic-artwork preferences, observed playback or source-audio activity with provenance and action outcomes, guided local companion availability, ownership restrictions, activity, and actionable failures, supplied by control so every presentation reports the same listening state.
  - name: intent-retention
    description: >
      Current durable listening choices and visual theme, fallback photo mood, scene, speed and automatic-artwork preferences, supplied to storage so future sessions recover preferences without treating them as confirmed playback or restoring stale source pins.
  - name: tab-delivery-intent
    description: >
      The desired independently controlled tab levels, mute states, browser-scoped output choices, explicit source focus and optional page access, fixed capability-gated playback requests bound to the current browser session, tab and document, exclusive playback ownership grants, and release requests, supplied by control so browser behavior follows intent without overlapping native delivery or acting on another page.
  - name: platform-adjustment
    description: >
      Requested device settings, interception lifetime changes, listening-window presentation changes, and application-owned local companion availability and browser registration, supplied to the host so listening behavior and presentation follow intent without listener-managed files or host configuration.
  - name: listening-focus
    description: >
      The current candidate source identities and observed activity, explicit or automatic focus intent, source pin, presentation visibility, retained automatic-artwork preference, permitted metadata access, and browser-supplied media facts, supplied by listening control so focused context and authorized artwork lookup belong to the intended visible source.
  - name: media-action-intent
    description: >
      An explicit request for a supported native playback action or selected-track cover lookup, refresh, or cache clearing, supplied by listening control so media actions cannot be inferred from presentation changes or applied to a replacement source.
---

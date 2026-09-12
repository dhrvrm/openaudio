---
name: audio-delivery
definition: >
  Deliver each selected native source through its chosen processing and available output exactly once, exclude browser sources owned by independent tab delivery, and relinquish interception whenever delivery cannot remain valid. Without this boundary choices cannot become audible behavior with bounded timing and recoverable ownership.
inputs:
  - name: delivery-intent
    description: >
      The complete desired native source routing and processing configuration, requested device settings, exclusive browser ownership exclusions, and control lifetime, supplied by control so native delivery has an unambiguous target.
  - name: platform-observation
    description: >
      Available applications and browser tabs, independently scoped device and effect capabilities, device visibility permissions, actual settings and listening-window presentation state, local companion installation and browser-integration availability, and lifecycle changes, supplied by the host so listening decisions reflect current conditions.
  - name: source-audio
    description: >
      Time-ordered application or independently captured tab sound and its source identity, supplied by audio producers so each chosen adjustment affects the intended sound.
outputs:
  - name: delivery-observation
    description: >
      Observed native sources and device capabilities, permission status, confirmed interception exclusions, active delivery outcomes, activity, and failures, supplied by delivery so control can distinguish intent from reality.
  - name: platform-adjustment
    description: >
      Requested device settings, interception lifetime changes, listening-window presentation changes, and application-owned local companion availability and browser registration, supplied to the host so listening behavior and presentation follow intent without listener-managed files or host configuration.
  - name: delivered-audio
    description: >
      Time-ordered adjusted sound assigned to the selected available output, supplied to audio consumers so the intended listening result is audible.
---

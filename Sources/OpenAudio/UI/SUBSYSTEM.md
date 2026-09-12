---
name: listening-interface
definition: >
  Make the available listening choices and their actual outcomes understandable and operable through consistent compact, mixer, and immersive presentations with continuous motion and clearly attributed fallback atmospheres that respect visual and accessibility preferences without pretending to be track artwork and a guided installation flow that distinguishes application-managed setup from browser-required local extension loading and permission choices. Without this boundary the listener cannot inspect, change, or recover listening behavior.
inputs:
  - name: listener-intent
    description: >
      Requested application and browser-tab listening changes, focused presentation, visual theme, fallback photo mood, record motion speed and source pinning, optional media access, supported playback actions, selected-track cover lookup and retention choices, browser activation gestures, and recovery actions, supplied by the listener so listening behavior reflects their choices.
  - name: listening-presentation
    description: >
      Current application and browser-tab choices, observed outcomes, source-specific capabilities and freshness, focused media context, visual theme and fallback photo mood, scene, motion and automatic-artwork preferences, observed playback or source-audio activity with provenance and action outcomes, guided local companion availability, ownership restrictions, activity, and actionable failures, supplied by control so every presentation reports the same listening state.
  - name: platform-observation
    description: >
      Available applications and browser tabs, independently scoped device and effect capabilities, device visibility permissions, actual settings and listening-window presentation state, local companion installation and browser-integration availability, and lifecycle changes, supplied by the host so listening decisions reflect current conditions.
outputs:
  - name: listening-edit
    description: >
      Requested source-specific changes to routing, processing, device settings, listening focus, visual theme and fallback photo mood, scene selection and motion preference, optional media access, supported playback actions, selected-track cover lookup and retention choices, browser activation, and control lifetime, supplied by the interface so intent has a single authority.
  - name: listener-feedback
    description: >
      Available listening controls and actual outcomes, including unavailable choices and recovery actions, so the listener can understand and direct playback.
  - name: platform-adjustment
    description: >
      Requested device settings, interception lifetime changes, listening-window presentation changes, and application-owned local companion availability and browser registration, supplied to the host so listening behavior and presentation follow intent without listener-managed files or host configuration.
---

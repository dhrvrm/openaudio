# Verification

## 2026-09-12 Suggested artwork and interaction (0.5.1)

Passed: 31 native/model assertions, 60 listening/artwork assertions, debug/release builds, static compact/normal window rendering, bundle version/resource checks and ad-hoc signature verification. Independent review confirmed the source-art priority and request-generation corrections. Installed app remains untouched.

Added title-only suggested artwork, separate cache policy, candidate artist/release attribution, source-art loading priority and per-request progress generations. Needle/record state now falls back to fresh source audio activity, labeled Audio detected; player pause takes precedence. Controls have explicit pointer/hover feedback and at least 32×36-point label targets.

Pure checks cover recognized suffix removal (including Hit the Road Jack | YouTube Music), preserving meaningful title text, rejecting generic pages, keeping hints separate from observed metadata, same-document title invalidation, unavailable/paused/audio-only source states, candidate order/provenance/deduplication, the three-release cap, cache separation and suggestion provenance round-trip. No title-only cover service query or live player/cursor test was performed.

Source review corrected fallback interrupting an in-progress source cover load and stale same-track progress callbacks. Artwork ownership is now explicit state; progress publication requires the current request UUID and context. Companion remains 0.5.0; the native app is 0.5.1.


## 2026-09-12 Vinyl polish (0.5.0)

31 native audio/model assertions, 48 listening/cache/motion/fallback assertions, 36 Node browser/metadata/transport/extractor tests and four filesystem registration checks passed. Release build, ad-hoc signature verification, plist validation, app/extension version parity, ZIP/bundled companion byte parity, fixed cover-reader packaging and three credited 1800×1100 mood photos passed. The Homebrew Python XML parser was broken on this machine; the resource check passed using system Python without changing the environment.

Static previews use mock sources and artwork with monitoring disabled. SwiftUI ImageRenderer checks the stage; an unattached NSHostingView renders actual native controls without a window. Compact 820×640, normal 1100×780, wide/short stage, missing metadata, missing artwork, artwork-only and artwork-present compositions were inspected. Initial rendering caught a height-dependent sleeve gap, truncated fallback title, per-child shadows low-contrast scene labels and a compact sleeve overflowing into metadata; these were corrected. The preview renderer's AppKit rasterization is not a display-frame-rate or VoiceOver test.

Independent source review caught and corrected fullscreen transition-watchdog races, Escape/reopen lifecycle gaps, stale headless evaluation callbacks, MainActor image decoding and asynchronous browser authorization checks. Browser fixtures exercise exact document targeting, replacement sessions, stale media, revoked observation, navigation during dispatch, permission failures and unsupported controls. The final pre-injection authorization guard contains no intervening await.

Built-in WebKit cover lookup remains live-unverified: public search can be blocked or return no usable JSON-LD; no matching cover is guaranteed. Native Music/Spotify and browser transport integrations, actual fullscreen desktop transitions, physical audio/device behavior and assistive technology have not been exercised. No installed app replacement, app launch, browser interaction, permission prompt, actual music command or cover-provider query occurred. Public reference/photo downloads and isolated fixture rendering are the only visual work performed.

Artifact: `dist/OpenAudio.app` version 0.5.0, local ad-hoc signed development build. `dist/OpenAudio-Tabs.zip` contains companion 0.5.0 and requires browser reload. Existing installed/running app is untouched. Publisher Developer ID signing and notarization remain outside this local build.


## 2026-09-12 Vinyl iteration (0.4.0)

Automated results: 31 audio/model assertions, 33 listening/cache assertions, 23 browser tests and four filesystem registration/preparation checks passed. Release build, local signature and plist checks passed.

The native build includes a dedicated Vinyl/artwork window, full-screen entry, source pinning, native music adapters, browser Media Session reading, and explicit MusicBrainz/Cover Art Archive lookup with bounded TTL caching. Unit checks exercise automatic/sticky focus, paused and missing sources, duplicate browser aggregates, stale/future observations, artwork revisions, ambiguous releases, malformed references/images, cache expiry, corrupt cache removal, cache-only reuse and clearing. Browser tests use synthetic objects, never a browser or playing tab.

Independent source review produced fixes for native process lifetime binding, transport targeting, cancel-before-start races, off-main image decoding, cache reuse/validation, embedded artwork changes, and queued metadata reads after Vinyl closes. A metadata payload budget preserves audio-control reports when many tracks are present; metadata beyond that budget is temporarily omitted rather than growing the audio mailbox without bound.

No app launches, installed-app replacement, browser interaction, Automation prompts, music commands, live API queries, audio playback/capture or full-screen/VoiceOver interaction were performed for this iteration. The layout was checked in source and compiled, not visually exercised. Apple Music and Spotify scripting, browser site metadata, actual cover availability and accessibility interaction remain runtime validation work. Spotify was not installed. Prior audio verification below is historical evidence and does not establish these new paths.

## 2026-09-12 local companion and device refresh

Version 0.3.0 builds successfully. The native model/processor harness passes 31 assertions. All 16 browser checks pass and cover independent tab control, lifecycle failures, and device enumeration using simulated devices. Isolated filesystem checks exercise native registration and repeated local extension preparation, preserving the folder and extension identity while replacing stale files. No live browser, audio, permission, or installed-app testing was performed for this update. In particular, exposing and routing to the user's TUFTON from Arc remains unverified on hardware.

The release bundle includes the complete local extension. Browser device refresh runs on device/permission changes, periodically, and on explicit refresh. A grant with no named devices is distinguished from missing permission. New audible-tab events trigger catalog refresh; first capture still requires a browser gesture.

## Earlier verification — 2026-09-11

Environment: macOS 26.2, Apple silicon, Swift 6.2.3 Command Line Tools. Xcode, XCTest, and Swift Testing were not installed. Canonical automated checks therefore use `Scripts/test.sh`, which compiles an assertion runner against the actual models and C audio processor.

## Results

- `Scripts/test.sh`: **27 checks passed**. [Full output](evidence/unit-checks.txt).
- `Scripts/build-app.sh`: release build and local ad-hoc code-signature verification passed.
- `plutil -lint Resources/Info.plist`: passed.
- Native light/dark UI rendered and inspected. [Light](evidence/mixer-light.png), [dark](evidence/mixer-dark.png).
- Independent source review found no remaining P1 in the corrected route lifecycle, capture scope, and software-level handling. Its findings produced fixes for stale callback detection, global/explicit tap overlap, failed teardown ownership, startup mute, mono downmix, ephemeral identity, output-scoped master gain, and undo consistency.

## Live synthetic-source tests

Each test launched the signed application through Launch Services, played an isolated quiet `afplay` source, measured nonzero processed audio, and checked that the test tap was removed. The input amplitude was 0.015 and the route gain 0.5, so the expected processed peak was approximately 0.0075.

| Path | Frames | Peak | Result |
| --- | ---: | ---: | --- |
| MacBook speakers, per-process | 193,536 | 0.00750006 | Signal present, no render error, tap released |
| TUFTON Bluetooth, 44.1 kHz | 177,664 | 0.00750005 | Signal present, no render error, tap released |
| MacBook speakers + TUFTON group | 193,024 | 0.00750007 | Two input/four output channels, no render error, tap released |
| Global tap excluding other processes | 193,536 | 0.00750006 | Isolated test source processed, tap released |
| Device-scoped exclusion tap | 193,536 | 0.00750007 | Default-device stream processed, tap released |

Evidence: [Bluetooth](evidence/smoke-bluetooth.txt), [group](evidence/smoke-20260911-193046.txt), [global](evidence/smoke-20260911-192627.txt), [device-scoped](evidence/smoke-20260911-193004.txt).

The first shell-launched test produced only zero samples. TCC logs attributed responsibility to the terminal. Launching the signed bundle with `open` produced the expected nonzero samples without further permission changes by the user. A first cleanup assertion also observed the tap list before macOS had published removal; after a bounded run-loop observation interval the tap list was empty and no owned resources were awaiting retry. The smoke helper now includes that observation interval.

The first grouped-device attempt exposed only two shared output channels with the aggregate's stacked option enabled. Disabling that option exposed four channels; the renderer now also uses the aggregate's actual active-subdevice order for channel and software-gain mapping. The corrected grouped test passed twice.

## Controller integration and UI investigation

The user reported volume and output controls doing nothing. Persisted state showed bypass enabled while the UI still accepted listening edits. Actual accessibility-driven mouse input reached the Arc route once control was enabled. Sound edits now activate processing; favorite-only edits do not.

`Scripts/smoke.sh --controller --output BuiltInSpeakerDevice --output 54-B7-E5-DD-B1-B5:output` passed using temporary controller preferences and a real isolated source. Volume 0.5 produced peak 0.00749997; volume 0.2 produced 0.00300003; mute produced approximately zero. Sequential speaker and Bluetooth routes received nonzero signal, and bypass removed captures. [Evidence](evidence/smoke-20260911-233339.txt).

This closes the earlier engine-only test gap for controller reconciliation. Physical audibility and an entire mouse-driven regression remain separate checks.

## What this does not establish

Callback counts, processed peaks, buffer tests, and cleanup checks establish exercised software paths. They do not establish listener-confirmed physical audibility, frequency response at the speakers, end-to-end latency, or synchronization quality between separate physical devices.

Remaining manual checks:

1. Listen to two real apps routed to different outputs; verify mute, volume, balance, EQ and restoration on bypass/quit.
2. Disconnect/reconnect the selected Bluetooth or USB output during playback; verify ordinary playback restoration, unavailable status, then saved-route recovery.
3. Sleep/wake while routing; restart an app and verify its saved identity recovers correctly.
4. Exercise volume keys after enabling Accessibility; verify fixed-output software mute and volume-up recovery.
5. Try AirPlay, USB interfaces with physical inputs, third-party Audio Units, and longer grouped playback. Unsupported non-stereo aggregate layouts currently fail before interception.
6. Inject failed HAL teardown operations and verify deferred ownership cleanup under those failures; source review covered the ownership path, while real tests exercised successful teardown.

Use [feature-matrix.md](feature-matrix.md) for capability boundaries. No complete SoundSource-parity claim is made.

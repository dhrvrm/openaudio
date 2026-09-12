# OpenAudio systems structure

The supported delivery contract is [Product delivery](product-delivery.md). It supersedes development-only installation assumptions: the standalone signed application is the baseline; browser-tab support is an optional locally bundled companion with browser-required approval. Safari full-tab support is outside the verified capability boundary.

## Behavioral contract

OpenAudio exists to let a listener independently choose where application sound plays and how it sounds, inspect actual playback status, and recover ordinary playback when control stops. The platform is macOS 15 or newer; the compact menu-bar presentation and expanded window share one listening state. OpenLoop supplies the visual reference, not an additional functional dependency.

The baseline behavior is per-application output selection, gain, mute, balance, ten-band equalization, ordered supported audio effects, current device controls, activity indication, persistent choices, and explicit recovery. System-wide processing follows the same contract: it covers sources that are not separately controlled and excludes OpenAudio's delivered audio. A source must never be processed through both its own route and the system-wide route.

The user has authorized this behavior through the SoundSource recreation request and supplied the project location. No additional product decision blocks the baseline design. Audible correctness remains an empirical acceptance condition; compilation cannot establish it.

## Declared implementation nodes

`SUBSYSTEM.md` at the project root declares the enclosing application. The four child contracts are colocated with their responsibilities. BrowserExtension declares browser-tab-delivery; its complete contract and ownership flow appear in the browser-tab amendment below. Internal relations below compose inside the root boundary; they do not add environmental behavior.

```text
[application-listening-control] — independent listening choices with observable delivery and recoverable ownership
  ← [listener]: listener-intent — requested changes; the application requires the listener's desired outcome
  → [listener]: listener-feedback — available controls and actual outcomes; the listener requires intelligible status
  ← [host-platform]: platform-observation — sources, devices, effects, permissions, settings, and lifecycle; the application requires current capabilities
  → [host-platform]: platform-adjustment — device and interception requests; the platform requires the requested changes
  ← [audio-producers]: source-audio — identified application sound; the application requires the sound it adjusts
  → [audio-consumers]: delivered-audio — adjusted sound assigned to an output; consumers require the signal to play
  ← [listening-store]: retained-intent — earlier choices; the application requires durable preferences to recover them
  → [listening-store]: intent-retention — updated choices; storage requires what should survive relaunch

[listening-interface] — intelligible, consistent menu and window interaction
  ← [listener]: listener-intent — choices and recovery requests; the interface requires the listener's intent
  → [listener]: listener-feedback — controls and truthful outcomes; the listener requires an understandable presentation
  → [listening-control]: listening-edit — requested listening changes; control requires edits to establish intent
  ← [listening-control]: listening-presentation — choices, capabilities, outcomes, and failures; the interface requires one authoritative presentation

[listening-control] — durable intent reconciled with actual outcomes
  ← [listening-interface]: listening-edit — requested changes; control requires the listener's edits
  → [listening-interface]: listening-presentation — desired and observed state; the interface requires consistent feedback
  → [audio-delivery]: delivery-intent — complete desired routing, processing, device choices, and control lifetime; delivery requires an unambiguous target
  ← [audio-delivery]: delivery-observation — capabilities, actual routes, activity, permissions, and failures; control requires evidence of outcomes
  ← [listening-store]: retained-intent — prior durable choices; control requires preferences after relaunch
  → [listening-store]: intent-retention — durable current choices; storage requires the next retained state

[audio-delivery] — correctly timed, exactly-once processing and recoverable delivery
  ← [listening-control]: delivery-intent — desired listening behavior; delivery requires the authoritative target
  → [listening-control]: delivery-observation — actual capabilities and outcomes; control requires evidence for truthful status
  ← [host-platform]: platform-observation — live sources, devices, permissions, effects, and settings; delivery requires available capabilities
  → [host-platform]: platform-adjustment — device settings and interception ownership; the host requires the requested changes
  ← [audio-producers]: source-audio — identified sound; delivery requires the signal to process
  → [audio-consumers]: delivered-audio — adjusted sound and selected destination; the consumer requires the signal to reproduce
```

Each arrow denotes the direction information flows. Its named kind classifies the meaning; the prose explicitly states which receiving node depends on the providing node. Identically named relations in the root and child contracts represent boundary composition, not an additional transmission.

## Environmental counterparts

These nodes are explicit external boundaries, not directories or implementation subsystems owned by this repository. They complete the input/output graph without claiming ownership of the listener, operating system, other applications, hardware, or durable storage medium.

```yaml
environment:
  - name: listener
    definition: Chooses and evaluates the audible result.
    inputs: [listener-feedback]
    outputs: [listener-intent]
  - name: host-platform
    definition: Supplies current execution capabilities and applies authorized device and interception requests.
    inputs: [platform-adjustment]
    outputs: [platform-observation]
  - name: audio-producers
    definition: Supplies the application sound whose listening behavior is controlled.
    inputs: []
    outputs: [source-audio]
  - name: audio-consumers
    definition: Reproduces delivered sound at the selected destination.
    inputs: [delivered-audio]
    outputs: []
  - name: listening-store
    definition: Retains listening choices and bounded corroborated artwork across application lifetimes.
    inputs: [intent-retention, artwork-cache-retention]
    outputs: [retained-intent, artwork-cache-observation]
  - name: media-publishers
    definition: Publishes source-bound media information, corroborating artwork-catalog results, and supported explicitly requested source-action outcomes.
    inputs: [media-request, artwork-request]
    outputs: [media-observation, artwork-observation]
```

The listener's feedback relation includes requested actions, success, failure, waiting, bypassed state, and the currently effective output. Platform observation includes capability restrictions; a setting the device does not support must remain unavailable rather than look writable. Storage retains preferences, never a claim that a route is currently active.

## State and lifecycle invariants

- Desired and applied state remain distinct. A displayed active route requires observed successful delivery; a saved route alone is insufficient.
- Native application identity survives process relaunch. Browser tab identity is session-scoped and must not survive a tab or browser session replacement. Device identity survives device enumeration changes. A disappearing process ends its live ownership; an equivalent new instance can recover the retained choice.
- The default output choice follows the current system default. An explicit missing output retains its identity and shows unavailable. Interception ends and ordinary playback resumes until that device becomes available; no arbitrary substitute is silently selected.
- Original playback is suppressed only while controlled delivery is established. Any partial setup failure, stop, disconnect, permission loss, or teardown releases owned interception and rendering resources. A deliberately muted route remains silent while controlled delivery is active.
- Recovery must not overwrite unrelated system changes made by the listener or another application. Only changes still owned by OpenAudio may be restored.
- Source identity and control ownership prevent recapture, duplicate playback, and processing feedback. System-wide and explicitly controlled application membership are disjoint.
- All selected processing runs in the declared order. Unsupported or unavailable effects are identified and bypassed visibly rather than substituted under the same name. Gain and equalization cannot claim proprietary SoundSource processing equivalence.
- Processing has bounded execution and memory use per audio interval. No allocation, blocking synchronization, preference access, UI work, or device discovery may occur in deadline-bound signal delivery. Configuration changes and teardown must not invalidate state still used by delivery.
- Source format, channel layout, timing, and output format changes require valid delivery re-establishment before the route is shown active. Hardware tests must cover these changes.
- Permission denial produces actionable feedback and leaves ordinary playback intact. Capture permission is requested in context; repeated failures do not silently loop requests.
- Closing the window keeps intended menu-bar control running. Quitting the application relinquishes all controlled delivery. Relaunch recovers intent and discovers reality anew.

## Conceptual handoff

The control-to-delivery relation carries stable application identity, current source membership, stable output selection or follow-default intent, gain/mute/balance, an ordered effects description and retained effect settings, processing scope, and control lifetime. Device operations include requested defaults and supported level, mute, balance, and format changes. These are meanings the implementation must represent, not prescribed interfaces.

Delivery observations carry current source and device identities, supported controls and effects, actual default selections, actual route status, meters, permission status, and actionable errors. Route status must distinguish inactive, establishing, active, unavailable, and failed outcomes. Presentation may derive display names and grouping but cannot invent successful application of a request.

The interface sends edits, retry, bypass, reset, and stop actions through control. Both presentations consume the same reconciled state. Control owns persistence and validation of user intent; delivery owns the changing platform state and all signal-lifetime decisions. Signal processing is an interior responsibility of audio delivery, not an independent subsystem whose configuration could diverge from route ownership.

## Minimality analysis

Four implementation nodes remain. The original three remain because listener interaction, durable desired state, and deadline-bound live delivery have different environmental obligations. Combining the interface with control would duplicate intent when compact and expanded presentations evolve; combining control with delivery would mix durable user preference with transient platform ownership.

Separate routing managers, effect managers, permission managers, device registries, meters, and recovery coordinators are not declared as peers. Their responsibilities remain inside audio delivery because they share the invariant that an active route is audibly valid and owned exactly once. Persistence remains inside control because it stores the same intent control already owns. Menu and window remain inside one interface because they express the same behavior.

No event bus, service broker, remote service, accounts, telemetry, or additional storage service is needed by the external contract. Every internal relation carries either an authoritative request or an observed result; neither can be derived from the other. Boundary relations preserve separate external sources of meaning even when one host supplies several of them.

## Reference scope and unresolved acceptance

The [SoundSource product page](https://rogueamoeba.com/soundsource/) describes per-app routing and effects, system device controls and effects, grouped outputs, AirPlay, volume keys, and Shortcuts. Its ten-band EQ and Audio Unit support anchor the generic effects requirement. Its branded enhancement effects have proprietary behavior that this project must not claim to reproduce exactly.

The contract accommodates generic functional equivalents. Full product parity additionally requires verified multi-output grouping, network output behavior, keyboard volume handling for fixed-volume devices, automation, system-wide processing, and headphone correction workflows. These are acceptance obligations rather than permission to label an incomplete implementation complete. An implementation that omits them must report the omitted behavior explicitly.

No unresolved why blocks baseline implementation. Remaining uncertainties concern platform feasibility and measured behavior: permission delivery, protected or noncapturable sources, application helper identity, output disconnect recovery, independent device clocking, effects compatibility, and restoration after failures. They require targeted implementation research and live tests; they do not justify speculative subsystem proliferation.

## Design readiness

READY for implementation of the declared baseline and its explicit lifecycle invariants. The affected graph consists of one enclosing contract, four implementation contracts, and five explicit environmental counterparts. The browser-tab amendment adds two internal relation kinds without adding an external system boundary. Schema, matching relation kinds, unique definitions, internal-boundary composition, and external-boundary composition were validated after materialization. Product parity and audible correctness remain pending implementation evidence.


## Browser-tab amendment

The listener now requires multiple audible tabs from one browser to appear as separate sources with independent volume, mute, and output controls. A native process source is not evidence of tab identity: multiple tabs may share application audio infrastructure. Browser-local delivery is therefore a fourth necessary responsibility. It retains the original exactly-once and native-playback restoration invariants.

```text
[browser-tab-delivery] — independently deliver explicitly activated tabs under exclusive browser playback ownership
  ← [listening-control]: tab-delivery-intent — desired per-tab levels, mute, browser output choices, ownership grants, and release requests; browser delivery requires authoritative intent and confirmed permission to own playback
  → [listening-control]: tab-delivery-observation — session and tab identities, current capabilities, ownership requests, applied revisions, and confirmed releases; control requires actual outcomes before changing ownership or presentation
  ← [listener]: listener-intent — browser activation gestures and output-device permission choices; browser delivery requires browser-recognized user authorization
  → [listener]: listener-feedback — capture activation, browser permission guidance, and release status; the listener requires browser-local feedback when the native window cannot perform the required gesture
  ← [host-platform]: platform-observation — browser tabs, capture capability, permitted output devices, device permissions, and lifecycle; browser delivery requires browser-scoped capabilities
  → [host-platform]: platform-adjustment — tab capture and output requests and their release; the host requires explicit ownership changes
  ← [audio-producers]: source-audio — independently identified tab sound; browser delivery requires the separate signal before it becomes a browser mix
  → [audio-consumers]: delivered-audio — adjusted tab sound at its permitted destination; consumers require the independently controlled signal

[listening-control] — existing durable intent authority, extended with session tab choices and exclusive browser ownership
  ← [browser-tab-delivery]: tab-delivery-observation — browser identity, requested ownership, actual settings, and release evidence; control requires facts to arbitrate native versus browser playback
  → [browser-tab-delivery]: tab-delivery-intent — current choices, ownership grant, and release request; browser delivery requires authorization and intent
  → [audio-delivery]: delivery-intent — existing relation now also carries whole-browser exclusions; native delivery requires the ownership boundary
  ← [audio-delivery]: delivery-observation — existing relation now also confirms released native interception and established exclusions; control requires proof before granting browser capture
  → [listening-interface]: listening-presentation — existing relation now includes tab rows, browser-scoped capabilities, and suspended native browser controls; the interface requires truthful controls
  ← [listening-interface]: listening-edit — existing relation now includes tab changes and browser activation requests; control requires edits without confusing native and browser identities
```

The enclosing application still consumes listener-intent, platform-observation, source-audio, and retained-intent, and provides listener-feedback, platform-adjustment, delivered-audio, and intent-retention. The environmental counterpart definitions above now include the browser within host-platform and individual tab sound within audio-producers. Browser output devices remain audio-consumers. No browser-owned state is treated as a native device capability.

The browser node must remain separate: its user-activation boundary and access to independent tab sound cannot be supplied by the native source node. A transport relay does not need a fifth node; it transfers the two new relation meanings unchanged and remains an interior mechanism of listening-control. The browser's capture and replay duties remain together because neither has useful independent behavior in this application.

[Browser-tab design and acceptance](browser-tabs.md) completes this amendment with ownership transitions, source identity, failure behavior, platform evidence, and test obligations. This amendment supersedes baseline statements about durable source identity where the source is a browser tab. It does not expand tab effect capabilities to match native application effects.


## Product delivery amendment

The baseline is a normally installed native application with independent per-application control, including Arc and Safari as whole applications. Browser-tab delivery is optional and must not be required to use baseline audio controls. The authorized local companion flow makes its stable app-owned folder accessible and guides browser-required local loading and permission approval. No supported user flow asks the listener to run commands, build software, or edit native-host configuration.

The graph retains four implementation nodes. Listening-control owns availability of its local browser integration because it already owns the native endpoint and its capability state. The two following flows reuse existing environmental relation kinds; they introduce no environmental counterparty or independent transport service.

```text
[listening-control] — listening intent, playback ownership, and local availability of optional integration
  ← [host-platform]: platform-observation — installation location and current local browser registration availability; control requires evidence that the embedded companion endpoint is reachable
  → [host-platform]: platform-adjustment — registration and repair of this application's own local browser endpoint; the host requires the changes that make installed optional integration reachable
```

Root and child relation descriptions include this meaning. Listening-interface provides ordinary installation and permission guidance through existing listener-feedback and receives the listener's choices through listener-intent. Browser installation remains a browser-mediated user action; control must not silently install or enable an extension. Publisher signing is an external delivery dependency, not a runtime subsystem. Store review is not required for the currently authorized local companion.

See [Safari capability boundary](safari-support.md) for the reason Safari's per-tab request cannot be promised by the current browser-delivery contract. No partial media-player substitute is added. READY for the product delivery implementation described in product-delivery.md; this is not a claim that the existing development build is distributable.


## Local companion and discovery amendment

[Local companion setup](local-companion.md) is the current setup contract. The application supplies and maintains the companion locally, registers its embedded bridge, and exposes the browser-required approval steps. Store publication is optional. The existing four-node structure remains minimal.

Listening-control's platform-adjustment relation now expressly includes app-owned local companion availability; platform-observation carries its installation and registration state. Listening-interface presents local preparation, browser loading, connection, and permission states through existing feedback relations. Browser-tab-delivery's tab-delivery-observation now expressly carries automatically refreshed sources, browser-device visibility permission, and catalog freshness, so a missing output is never misrepresented by a generic selectable label.

All new meaning fits the existing root environmental boundary and existing directed relations. No new node or relation kind is needed. READY for this bounded amendment; verification is restricted to static/code checks and pure state tests. No live browser or audio action is included.


## Vinyl listening amendment

[Vinyl mode](vinyl-mode.md) extends the supported presentation to an immersive source-bound listening view. One additional implementation node, listening-context, resolves focus, optional media information, and bounded supported media actions. Audio-delivery is structurally unchanged; the feature must remain usable while native audio control is bypassed.

The requested-and-related graph gains the media-publishers environmental boundary and the following directed flows. These augment, rather than replace, the earlier baseline relations. The current complete graph therefore contains one enclosing contract, five implementation contracts, six environmental counterparts, and twenty-three relation kinds.

```text
[listening-control] — existing listening intent authority, now also supplying the requested presentation focus
  → [listening-context]: listening-focus — candidate identities/activity, pin, metadata consent, and browser media facts; context resolution requires the listener's intended source
  → [listening-context]: media-action-intent — explicit supported playback action for a specific source/session; the context owner requires intent before acting
  ← [listening-context]: listening-context — resolved source, verified media facts, fallback, capabilities, and action outcome; control requires a coherent presentation rather than unrelated metadata

[listening-context] — source selection, truthful media context, and bounded supported source actions
  ← [listening-control]: listening-focus — source candidates and focus intent; context resolution requires the intended source
  ← [listening-control]: media-action-intent — explicit source-scoped playback request; the action boundary requires user intent
  → [listening-control]: listening-context — resolved source and truthful media/action state; presentation requires a source-correlated result
  → [media-publishers]: media-request — permitted metadata reads or explicitly requested supported actions; the publisher requires the requested capability and source
  ← [media-publishers]: media-observation — source-bound track/artwork/playback facts and action outcomes; context resolution requires publisher evidence

[browser-tab-delivery] — existing browser boundary, extended with optional tab metadata observation
  → [media-publishers]: media-request — permitted read of the explicitly identified page's published media context or fixed capability-gated playback intent; the page boundary requires authorized source and document scope
  ← [media-publishers]: media-observation — page-published facts for the current document; browser delivery requires source-bound metadata rather than guessed tracks
  → [listening-control]: tab-delivery-observation — existing flow additionally carries tab metadata, document identity, consent and freshness; control requires facts associated with its existing source identity

[listening-interface] — existing interface, extended with the reusable Vinyl presentation
  → [listening-control]: listening-edit — existing flow additionally carries focus, pin, optional access consent, and explicit supported playback intent; control requires the listener's choices
  ← [listening-control]: listening-presentation — existing flow additionally carries focused media context, fallback, and pending/action results; every presentation requires the same source truth
```

At the root, media-request is an output and media-observation is an input, both matched by media-publishers. Native player applications and browser pages are members of that environment. Artwork retrieval is bounded observation of publisher-provided media, not a new general browsing or remote-command service. Existing audio-producers and audio-consumers remain independent signal boundaries.

Metadata cannot be inferred from audio samples or device names. That independent environmental dependency justifies listening-context as a fifth implementation node. Source selection and late-result validity share one invariant, so they remain together. No separate artwork broker, transport daemon, or fullscreen audio session is required. Root and affected child contracts are materialized. See vinyl-mode.md for readiness and the static-only verification boundary.


### Explicit cover lookup and bounded retention

```text
[listening-context] — existing source-correlated media boundary, also owning optional cover corroboration
  → [media-publishers]: artwork-request — explicit selected-track title/artist/available album lookup; the catalog requires the bounded track query
  ← [media-publishers]: artwork-observation — corroborating identities, cover provenance, and lookup outcomes; context resolution requires evidence before assigning a remote cover
  → [listening-store]: artwork-cache-retention — verified cover or known-miss identity, expiry, size, and explicit refresh/clear intent; retention requires the bounded reusable result
  ← [listening-store]: artwork-cache-observation — retained corroborated cover or miss and its validity; context resolution requires evidence before cache reuse
```

The external retention boundary formerly labeled intent-store is now listening-store because it contains both durable listening preferences and bounded artwork retention. This does not add an implementation subsystem. Media-publishers includes the optional catalog and cover providers. Root inputs and outputs compose these four external relation kinds. Lookup intent reaches listening-context through media-action-intent; returned artwork and status reach all presentations through listening-context and listening-presentation. No independent headless-browser or generic web-retrieval subsystem is introduced; rendered discovery, when explicitly requested, remains within listening-context.


## Rendered cover fallback and continuous motion amendment

The existing artwork-request/artwork-observation relation pair now includes explicit bounded public search and approved music-page discovery after structured cover lookup yields no usable result or fails. Media-publishers includes the relevant public pages. Corroboration, provenance, restricted rendering, cancellation, and finite work limits remain obligations of listening-context. The cache relations include provider-policy generation so prior negative results cannot suppress a new permitted provider strategy. There is no new runtime node or relation kind.

Listening-interface owns one continuous whole-record visual phase and smoothly approaches the listener's requested visual speed. Speed intent travels through listening-edit, the selected preference through listening-presentation, and accessibility/activity state constrains local presentation motion. The existing audio delivery relations are unchanged. The motion model cannot alter source playback rate or require an additional audio stream.

The detailed behavior is recorded in vinyl-mode.md under Rendered public-page cover fallback and Continuous record motion and fullscreen refinement. READY for implementation with static/code, fixture, and build validation only. The complete graph remains six contracts, five implementation nodes, six environmental counterparts, and twenty-three relation kinds.


### Owning-window presentation boundary

```text
[listening-interface] — existing listening presentation, including its actual containing native window
  → [host-platform]: platform-adjustment — requested fullscreen transition for the listening presentation's owning window; the host requires the correctly targeted presentation intent
  ← [host-platform]: platform-observation — actual owning-window availability and fullscreen transition outcome; the interface requires evidence before displaying successful fullscreen state
```

These two existing relation kinds now include window-presentation meaning and are matched by the root boundary and host-platform counterpart. This adds no node or relation kind. Record and Artwork scene invariants, explicit missing-artwork recovery, and the MD Vinyl reference boundary are documented in vinyl-mode.md. READY includes these latest corrections; live fullscreen or browser/provider validation remains excluded from this work unit.


## Customization, fixed browser playback, and tonearm amendment

The existing listening preference relations now explicitly retain visual theme, scene, and record speed. Pins remain session-scoped, and Automatic is the initial mode. Listening-interface depicts a decorative tonearm from observed playback state without adding a seeking or audio-control relation.

Browser-tab-delivery now receives fixed supported playback requests with immutable browser/session/tab/document targets through tab-delivery-intent and supplies current action capabilities, outcomes, document identity, and known-player metadata provenance through tab-delivery-observation. Its existing media-request/media-observation environment relations cover those permitted page-player operations. Native media-action-intent remains addressed to listening-context, and browser actions must not also be dispatched through that native path.

The current known-page fallback is YouTube Music current-player metadata when media-session information is absent. Generic media playback is limited to an unambiguous element's supported Play/Pause. Unsupported page commands and uncorroborated metadata remain unavailable. The detailed edge-case and decorative-tonearm contract is in vinyl-mode.md.

These changes add no node or relation kind. The graph remains six contracts, five implementation nodes, six environmental counterparts, and twenty-three matched relation kinds. READY applies to the bounded changes and static/fixture/build validation only; no live behavior is claimed.


## Bundled mood-photo fallback amendment

Listening-interface uses bundled, attributed photographic atmospheres when current album artwork is unavailable. Warm, After dark, and Nature are explicit user-selected appearance preferences, not inferred track moods. Their intent and presentation reuse listening-edit/listening-presentation; persistence reuses intent-retention/retained-intent. Real current-source artwork has priority, and the missing-cover sleeve/record label remains truthfully distinct from the background photo.

The asset library is an interior presentation resource prepared with per-photo provenance and applicable-license records. It creates no runtime dependency on Unsplash or any other photo service. No automatic network request accompanies fallback presentation. The graph is unchanged: six contracts, five implementation nodes, six environmental counterparts, twenty-three relation kinds. READY for the bounded amendment with static/resource/fixture validation only.


## Title-only suggested-cover amendment

The user's explicit suggested-artwork request adds a title-only matching policy within listening-context. Existing artwork-request distinguishes observed identity from a cleaned title hint; artwork-observation distinguishes verified matches from recommendations and carries candidate artist/release attribution. The cache relations maintain separate matching-policy identities so suggestions cannot be reused as verified artwork. Listening-context and listening-presentation preserve the difference between source-observed facts and recommended imagery.

The first usable cover among at most three ranked candidates may be recommended when a known release and valid image are available, without asserting identification of the playing recording. Native/page artwork and verified matches retain priority. The complete behavior is documented in vinyl-mode.md. No node or relation kind is added: six contracts, five implementation nodes, six environmental counterparts, twenty-three kinds. READY with static/fixture/build validation only.


## Source-activity tonearm amendment

Listening-presentation explicitly distinguishes fresh playback state from fresh selected-source audio activity and carries their provenance. Listening-interface may use activity to lower the decorative needle when playback metadata is missing or stale, displaying Audio detected rather than inventing a known track state. Fresh authoritative Pause/Stop remains higher priority. This is local presentation of existing observations, not new audio capture or playback behavior.

Artwork request progress and pointer/hit feedback are independently truthful presentation obligations. No cassette subsystem or needle-seeking action is added. The graph remains six contracts, five implementation nodes, six environmental counterparts, and twenty-three relation kinds. READY with static/fixture/build verification only.


## Bounded measured-cover quality amendment

The existing artwork-observation relation now explicitly carries publisher-declared same-cover variants and actual measured image dimensions/size. Listening-context chooses a bounded useful-resolution variant without changing accepted cover identity or recommendation confidence. Artwork cache observation/retention carries matching and quality-policy identity plus final prepared dimensions and size.

The behavior in vinyl-mode.md sets an 800-pixel desired short edge, 1200-pixel prepared longest edge, no upscaling, at most three same-cover variants, 2 MiB per downloaded image, 6 MiB image payload per lookup, and at most 1 MiB per prepared cached JPEG. Source-provided artwork retains priority. Existing low-resolution art stays visible until an explicit refresh improves it; quality-policy invalidation does not cause hidden networking or erase a usable cover.

No subsystem or relation kind is added. READY with the existing six contracts, five implementation nodes, six environmental counterparts, and twenty-three matched relation kinds. Verification remains static/fixture/build only.


## Automatic artwork and rendered-suggestion recovery amendment

The retained listening preference now includes default-on automatic artwork lookup. Listening-focus carries that preference and presentation visibility; listening-context schedules only the debounced eligible selected-source request. Artwork-request therefore includes authorized automatic requests as well as explicit requests. Existing media-publishers covers the current catalog and rendered-page providers and transient retry/defer outcomes. No new node or relation kind is needed.

Automatic scheduling respects source/cache priority, cancellation, and ten-minute per-key failure/miss cooldown. Temporary provider responses allow one bounded retry respecting Retry-After; long waits defer the provider. The existing rendered-page fallback supports a title-only suggestion only when the page publishes an exact matching title, nonempty artist and album, and a safe image, preserving suggested attribution. No new catalog integration is added. Existing measured-image and shared payload/cache limits remain in force.

This is the current artwork scheduling authority and supersedes earlier explicit-only wording. The graph remains six contracts, five implementation nodes, six environmental counterparts, twenty-three relation kinds. READY for static/fixture/build validation only; no live-provider or application behavior is claimed.

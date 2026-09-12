# Independent browser tabs

Current supported setup: optional companion bundled locally with OpenAudio, with an app-owned stable copy and automatically registered embedded native bridge. The listener completes browser-required local loading and permission approval through in-app guidance. No store listing is required. See [Local companion setup](local-companion.md) and [Product delivery](product-delivery.md). Safari full-tab behavior is not supported by this design; see [Safari capability boundary](safari-support.md).

## Required result

Two simultaneously playing tabs in one supported browser appear as separate OpenAudio sources. After browser-authorized activation, each tab has its own volume, mute, and output choice. Adjusting one tab must not change the other's settings or native applications. Displayed applied state requires acknowledgement from actual tab delivery. The existing native volume/output failure remains a separate defect; tab integration must not mask it.

The system structure and complete directed graph are declared in [architecture.md](architecture.md#browser-tab-amendment) and the four implementation contracts. Only browser-tab-delivery is new. It resides at BrowserExtension; the native command relay remains inside listening-control. Implementation may choose a private per-user local mailbox for the native relay, provided it satisfies the message and ownership invariants below. No audio crosses that relay.

## Browser constraints established by primary documentation

Chrome requires extension invocation to begin tab capture. Capturing suppresses normal playback, so the extension must deliver captured sound itself. Capture remains associated with the tab across navigation and ends when the tab or captured stream closes. A native-window click cannot be represented as the required browser gesture. [Tab capture API](https://developer.chrome.com/docs/extensions/reference/api/tabCapture)

Chrome documents background tab capture through an extension worker and an offscreen document from version 116. This supports keeping playback alive when a popup closes. The extension can own several independent tab playback graphs within its background lifetime; actual concurrent behavior remains a live acceptance check. [Background capture guidance](https://developer.chrome.com/docs/extensions/how-to/web-platform/screen-capture)

Web Audio permits output switching to browser-permitted devices. The browser supplies its own device identifiers; the native hardware identifiers are not interchangeable. Without microphone permission, Chrome documents a restricted device list. A visible browser setup action may request that permission to expose output choices, immediately releasing any temporary input capture. Denial leaves permitted outputs usable and explains why others are absent. No microphone signal becomes tab audio. [Output selection documentation](https://developer.chrome.com/blog/audiocontext-setsinkid)

Native messaging supplies an extension-to-native control channel restricted to listed extension origins. The host is a separate process and therefore cannot assume it is the existing OpenAudio GUI instance. The native relay forwards current observations and receives commands from the running listening authority. [Native messaging](https://developer.chrome.com/docs/extensions/develop/concepts/native-messaging)

An offscreen document supports background media but only limited extension APIs. Its creation reason affects lifetime; a playback-only reason may close it after silence. Capture resources must therefore have explicit lifecycle management, including silence and sleeping conditions. [Offscreen document](https://developer.chrome.com/docs/extensions/reference/api/offscreen)

Arc compatibility is a hypothesis to validate against the installed Arc version. Shared Chromium ancestry alone does not prove capture, output permissions, or native-host registration work identically. Feature detection and a real Arc two-tab test are required before claiming support.

## Minimal user flow

1. The companion automatically refreshes currently audible tabs and already managed tabs, including quiet or muted managed tabs. Newly audible tabs appear without reopening the popup or manually reloading the extension; they still require browser-authorized activation before capture. Rows identify browser, tab title, and a compact site label; identical titles remain distinct sources. Full URLs are unnecessary.
2. An unmanaged row offers Open tab to enable. The listener activates that tab and invokes the companion there. The native app cannot silently start capture from that button.
3. Before capture begins, control grants exclusive ownership of the browser playback only after native delivery confirms its own browser interception has ended and system capture excludes the browser.
4. The companion establishes the selected tab's delivery, then reports applied state. Other managed tabs continue independently. An unactivated tab remains ordinary browser playback.
5. Each managed tab exposes volume, mute, one permitted output, and Release tab. Native-only effect, multi-output, and device-format controls are absent or visibly unavailable for tabs. A common row appearance does not imply identical capability.
6. The native browser row states Controlled by browser tabs and suspends its native audio controls while any tab ownership reservation exists. Other audio visibly excludes that browser, including unactivated tabs. The browser's saved native settings remain intact.
7. App bypass, sleep, and quit request release of every tab capture. Releasing the final capture allows native browser control to resume only after confirmed release. Ordinary tab playback recovers when capture ends.

This deliberately exposes the ownership consequence: while tabs are managed, remaining browser sound uses native browser playback and is outside OpenAudio's native browser and Other audio controls. Do not hide that limitation under a working-looking browser slider.

## Identity and state

A tab source is identified by the browser application, profile/companion identity, browser-session generation, and tab identity. Its title, site, activity, and position are presentation attributes, not identity. A closed tab or new browser session invalidates old tab intent. Restoring a tab at the same URL must not inherit old mute or output controls accidentally.

Tab settings are session-scoped. Native application preferences remain durable. Do not place tab keys in ordinary persisted routes or reusable profiles unless a separately designed durable matching rule exists. No such rule is required now.

Browser output choices carry the companion's output identity and label. System default is explicit and distinct from a selected physical device. Two devices with identical labels remain separate choices. Device identifiers never cross into native output selection. After browser identity or device permission changes, refresh capabilities and validate the selected identity anew.

The browser observation includes companion identity, browser application identity verified by the local host context, current session generation, source catalog, output catalog, per-tab capture state, effective volume/mute/output, revision acknowledgement, failures, and owned-capture count. Browser request values are not accepted as proof that capture or output switching succeeded.

## Exclusive ownership transitions

The ownership unit is the entire browser application and all its relevant audio processes, across profiles. A browser-profile reservation prevents native interception of any process that can contain companion replay. Multiple profiles can hold tab ownership simultaneously; the native browser cannot resume until all have released.

- Native: the browser has no confirmed or unresolved companion ownership. Native application control is available.
- Preparing tabs: a browser activation has requested ownership. Control stops the native browser route, excludes all current browser audio processes from native system delivery, and waits for confirmed native release. Missing browser identity or failed native cleanup prevents a grant.
- Tabs owned: control grants the current browser/session ownership generation. Only then may tab capture start. New browser processes are included in the exclusion set before they can be admitted to native system processing. If this cannot be guaranteed during a topology transition, suspend native system processing until its exclusion set is valid.
- Releasing tabs: control revokes permission to start captures and requests all current captures stop. Native exclusions stay in force. The companion reports release only after all streams and replay resources are stopped, including any in-flight start operation.
- Native restored: an acknowledgement for the current release generation confirms zero owned capture. Native delivery can remove the exclusion and apply saved browser settings. Browser process termination also invalidates all captures for that process lifetime.
- Unconfirmed release: a stale connection, missing heartbeat, or relay exit does not prove the offscreen playback stopped. Keep native exclusion and report Waiting for browser audio to release. A matching confirmed release or verified browser lifetime termination resolves it. Restarting the native app must not discard unresolved reservations before companion state is reconciled.

Only a grant from the current control generation can start capture. Late commands or observations from an earlier generation cannot recreate ownership. App bypass cannot leave an independent browser gain active while the interface says bypassed; until release is confirmed it displays Releasing browser audio.

The companion must stop captures when its current authority lease expires, when control requests release, on tab closure, and on unsupported delivery failure. This gives app or relay failure a bounded recovery path. The offscreen owner must observe lease expiry itself; it cannot depend solely on a service worker that may be suspended. Failure to prove that this recovery works blocks browser feature completion.

## Local control exchange invariants

A private per-user local mailbox is sufficient; an additional network service is unnecessary. Command and observation snapshots must be replaced atomically, scoped to one verified companion session, bounded in size, and versioned. Readers reject malformed data, stale generations, invalid source identities, nonfinite levels, and unknown output choices. Native host registration accepts only the installed companion origin; no browser message can choose a filesystem path or execute a command.

Control publishes desired revision, ownership generation, session identity, authority lease expiry, and current commands. The companion publishes the exact applied revision, actual capture/output state, and failures. Rapid slider edits may supersede pending revisions; stale acknowledgements cannot overwrite newer desired values. Reapplying the same revision does not start an additional capture.

Desired snapshots and observed snapshots have one writer each. Relay traffic contains control and display metadata only. It does not persist tab history, full page URLs, or sound. Diagnostics must distinguish absent companion, permission-required, native exclusion pending, capture pending, active, output unavailable, failed, and releasing states.

## Failure policy

A rejected or unavailable output never becomes an active route in the UI. Stop the affected tab capture, restore ordinary playback, and retain its session-scoped requested choice with an explicit failure. Reactivation follows the browser's gesture requirements; device reconnection alone does not manufacture a new activation grant. This matches the native restoration principle without assuming that browser recapture can be automatic.

Stopping or failing one tab must not destroy other active tab routes. Failure during the first capture releases the otherwise-unused browser reservation after confirmed zero captures. If a sink change fails while other tabs remain active, their applied state remains unchanged. Explicit mute changes signal gain only while tab delivery is owned; release restores the browser's ordinary playback state.

## Required verification

1. Use two distinguishable continuous test sounds in separate tabs. Activate both, set the first to zero, confirm only that sound stops, restore it, and repeat for the second. Verify mute independently of remembered gain.
2. With two physical outputs, route each tab to a different output and confirm source identity at each device. Switching one output must leave the other unchanged. A default-only browser environment cannot establish this acceptance result.
3. Exercise native browser routing and Other audio before activation. Activate a tab and confirm native browser interception is released, all browser audio is excluded from Other audio, and companion replay is not recaptured. Add a new browser audio process while owned.
4. Bypass, quit, sleep, disconnect the relay, and terminate the app. Observe confirmed capture release or bounded lease expiry and ordinary playback restoration. Native browser control must remain suspended until release evidence exists.
5. Close a tab, navigate it, open a same-title replacement, and restart the browser. Verify session identity and absence of accidental preference inheritance.
6. Deny capture/output permissions, remove an output, provide invalid messages, deliver acknowledgements out of order, and start/release concurrently. Verify truthful state and isolation of the surviving tab.
7. Separately rerun the native controller smoke test for application gain, mute, and actual output changes. Browser success does not verify that defect.

Model tests can validate identity, revision ordering, ownership arbitration, and command capability restrictions. They cannot establish audible separation, device routing, browser permission behavior, or restoration. Those require the live tests above.

## Readiness

READY for implementation. No unresolved product why blocks the specified volume/mute/output baseline. Contracts and affected graph are materialized and validated. Live Arc capability, native-host registration, concurrent-tab playback, device permissions, process exclusion coverage, and lease recovery remain explicit empirical gates to a completion claim.


## Fresh browser output catalogs

The companion publishes output identity, meaningful label, permission state, last successful refresh, and any current discovery error as one coherent observation. Distinguish fresh permitted outputs from restricted visibility, refreshing, stale data, and discovery failure. A failed refresh is not an empty successful catalog.

Refresh when new audio sources appear, output topology or visibility permission changes, the control surface opens, or the companion reconnects, with periodic reconciliation for missed events. Discovery refresh does not request permission automatically or start capture. New source discovery does not manufacture a capture activation gesture.

Only browser-returned nonempty selectable identities appear as physical choices. System default is a separate explicit choice. A nameless permitted output can be described as unnamed, but must not be presented as TUFTON or any other native device by guessing. Native hardware visibility does not establish browser permission or browser identity. When visibility is restricted, show the permission action next to the output chooser; when a chosen output is unavailable, retain the choice and explain the actual state. A selector labeled only Permitted output is not adequate feedback for either case.

The current user constraint forbids live browser and audio testing. Schema checks, static code review, and pure state tests can verify catalog reconciliation; audible routing and permission-prompt results remain unclaimed until a later authorized session.

# Local companion setup

The companion is delivered with OpenAudio and does not require a browser-store listing. This is the currently authorized setup path and supersedes earlier store-only assumptions. Native per-application audio controls remain usable without the companion.

## Application-owned setup

OpenAudio prepares a complete, versioned companion copy in a stable per-user location it owns. The listener does not find a checkout or choose a build directory. The in-app setup can reveal the prepared folder and identify it clearly for the browser's folder picker. Preparation is idempotent and reports failures before claiming the companion is ready.

The embedded native bridge registers automatically for supported installed browsers and the bundled companion's stable identity. Neither a browser-supplied arbitrary origin nor an arbitrary executable path is accepted. Moving or updating OpenAudio repairs its own registration while preserving unrelated integrations. No Terminal command or hand-edited registration file belongs in setup.

The local copy remains available when the application moves or updates. An update preserves companion identity and reports if browser reload is required. Do not silently replace active playback resources or claim that a running browser has loaded a new version just because files were copied. A missing prepared folder can be recreated through the same in-app action.

## Browser-owned approval

The app guides the listener to the browser's extension management surface, explains its required development setting, and identifies Load unpacked plus the prepared folder. The browser requires the listener to approve these actions. OpenAudio cannot truthfully promise a silent installation, automatically grant browser permissions, or equate copying files with loading an extension.

Present progress as companion prepared, browser loading required, connecting, connected, or failed with an actionable reason. A prepared folder and a registered bridge are insufficient evidence of a connected companion. Browser-session observations provide that evidence.

After connection, newly audible tabs appear automatically. Discovery does not start capture: each unmanaged tab still requires the browser-authorized activation already described in browser-tabs.md. Quiet or muted managed tabs remain visible so the listener can release or restore them.

## Output-device state

The companion automatically refreshes its browser-permitted output catalog and reports permission status and freshness. The native app uses this catalog for tab routing; it does not substitute CoreAudio identities or infer a device from a matching name. TUFTON appearing among native devices does not establish that the browser currently exposes it.

When visibility is restricted, explain the browser permission needed to expose more outputs and provide the action in the browser context. Refresh after that action completes, after device changes, on control opening, on reconnect, and through periodic reconciliation. Refreshing discovery must not repeatedly request microphone permission or capture audio without the listener's explicit action.

Show System default as an explicit choice. Ignore empty nonselectable device identities. Distinguish unnamed permitted devices, missing chosen devices, stale catalogs, denied visibility, and discovery errors. A generic Permitted output label must not obscure those differences. Never replace a previously valid catalog with an apparently successful empty result when discovery actually failed.

## Responsibilities and readiness

Listening-control owns the prepared companion and native registration; listening-interface owns the setup guidance; browser-tab-delivery owns browser authorization, observed tab activity, and its device catalog. These responsibilities reuse the declared environmental relations and add no subsystem.

READY for implementation with static/code validation and pure state tests. The current user instruction prohibits live browser and audio tests. No installation, permission-prompt, or audible-routing success may be claimed from this design amendment alone.

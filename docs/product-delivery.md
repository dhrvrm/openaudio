# Product delivery

## Smallest shippable product

Ship one Developer ID-signed, notarized Mac application in a normal downloadable disk image. The listener installs OpenAudio in Applications, opens it, grants the required macOS audio-capture permission, and adjusts application volume, mute, and output. Arc and Safari both appear as whole applications. No extension is needed for that baseline.

The baseline includes honest applied-state feedback, saved application choices, menu and window controls, and reliable release on bypass, quit, permission failure, and output loss. Existing effects and device controls may ship only to the extent already verified. Full SoundSource parity is not the release label for this scope.

The native baseline remains an ordinary app installation. For the optional companion, the currently authorized delivery is local and bundled, without a store requirement. OpenAudio owns companion preparation and bridge registration. Browser-required local loading and permission approval are explained in the app; the listener does not run scripts, build software, or edit host configuration.

## Optional Chromium tabs

Provide the optional Chromium companion with OpenAudio. Arc is the primary target; Chrome is a compatibility target. OpenAudio prepares a stable, app-owned local copy and guides the listener through the browser's required extension loading and approval. A store account, published listing, and store review are not prerequisites for this authorized local flow. See [Local companion setup](local-companion.md) for the exact behavioral boundary.

The native bridge is embedded inside the signed OpenAudio application. OpenAudio registers and repairs its own per-user browser integration automatically after it is installed at a stable location. Its registration points to the embedded executable and allows only the identity of the bundled companion. Moving or upgrading the app repairs that registration; unrelated hosts and browser profiles remain untouched. A diagnostics action can retry registration without exposing implementation files to the listener.

Registering the bridge is application setup work. Installing or enabling the extension remains a browser-mediated user choice. Browser capture activation for each tab and any browser output-device permission are real platform requirements; they must be explained concisely. They cannot be bypassed by making native setup invisible. [Native messaging requirements](https://developer.chrome.com/docs/extensions/develop/concepts/native-messaging)

The current exclusive-ownership rules remain: active tab control suspends the browser's native route and excludes its sound from Other audio. Bypass releases captures before native routing resumes. The local setup states accurately that the browser requires its extension-development setting and Load unpacked approval. OpenAudio must not promise silent installation. A future store listing may simplify this flow, but it is not part of the present delivery requirement.

## Safari scope

Safari's combined application audio uses the native baseline. Full independent Safari-tab capture/routing is unsupported by the verified API boundary. Do not offer a media-element-only fallback as equivalent. The evidence and limits are recorded in [Safari support](safari-support.md).

## Responsibility and minimality

The product still has four implementation nodes. Listening-interface explains permissions and optional browser installation. Listening-control owns local browser availability, desired state, and playback ownership. Audio-delivery handles native signals and devices. Browser-tab-delivery is optional and handles eligible independent tab signals.

Local registration belongs to listening-control because it makes the existing control relation available; it does not justify a new setup daemon or network service. Signing, notarization, release assembly, and store submission belong to the publisher's environment, not the user's listening flow. The optional companion is supplied locally by the application; browser approval remains environmental behavior and does not justify a separate installer service.

## Actual publisher dependencies

For the baseline, the publisher needs an Apple Developer Program team, a usable Developer ID Application certificate and its private key, and authorized access to Apple's notarization service. All executable contents must be signed consistently, built with the required hardened-runtime settings and narrowly required entitlements, and validated as the delivered package. Apple supports custom notarization workflows and ticket stapling through command-line tools. [Developer ID and notarization](https://developer.apple.com/developer-id/)

This machine currently reports zero valid code-signing identities. The selected installation is Command Line Tools, and xcodebuild cannot run. However, notarytool and stapler are present. Full Xcode is not a justified prerequisite for the existing native Swift-package application solely because its project lacks an Xcode project; the immediate verified release blocker is the absent valid signing identity, followed by authenticated notarization and release validation. Notarization account credentials have not been inspected, and no claim about their availability is made.

A normally distributed Safari native-messaging extension would add Apple's packaging and signing requirements; the documented local converter is absent here. That work is excluded because it would not solve full-tab audio isolation. Do not ask the listener to install Xcode.

Browser-store publication is a possible future distribution channel, with its own publisher account, identity, review, and disclosure obligations. None blocks the current locally bundled companion. [Chrome Web Store publication](https://developer.chrome.com/docs/webstore/publish)

## Release acceptance

- A clean Mac can download, install, and launch the delivered application with ordinary Gatekeeper behavior and without Terminal, developer mode, disabled system security, or a local build toolchain.
- The initial audio permission step leads to working native gain, mute, and output changes for Arc and Safari; denial leaves playback intact and offers useful recovery.
- The shipped app has been signed and notarized, its ticket checked, and its downloaded artifact tested rather than only the build-tree executable.
- Updating, moving, bypassing, and quitting do not strand native capture or optional browser ownership. An older optional extension version produces a clear compatibility state.
- If Chromium tabs are included, the app prepares the local companion and embedded bridge; the listener completes only the browser-required loading and permission steps. The bridge connects without scripts or manual host edits. Local copy identity and update behavior are verified.
- Safari is described as application-level support. No interface or release text implies unsupported per-tab parity.

## Readiness

READY for implementation of the native-first, ordinarily installed product and automatic optional integration. No additional runtime subsystem is required. Signing identity, notarization, and clean-machine acceptance remain release dependencies for a normally distributed signed app; browser-store publication is not required for the authorized local companion. Design readiness does not claim that installation, audio routing, or release packaging has passed unperformed verification. Current work is restricted to static/code validation; no live browser or audio testing is authorized.

# Safari capability boundary

Safari is supported by the product design as a whole native application. Independent complete Safari-tab volume and output routing is not a supported promise. The Chromium companion cannot be labeled Safari-compatible merely by repackaging its files.

## Evidence checked

Local read-only checks on September 12, 2026 found Safari 26.2, build 21623.1.14.11.9; the macOS 26.2 Command Line Tools SDK; no available safari-web-extension-converter; and no working xcodebuild under the selected Command Line Tools installation. The installed SafariServices tab header provides page/tab operations without an audio-stream capture interface. The installed WebKit extension-tab protocol includes audio activity and tab mute, plus an image snapshot operation; these are not independently routable tab sound.

The public WebKit extension namespace at a pre-Safari-26.2 revision declares no tabCapture or offscreen API. This is source-level evidence, not a JavaScript runtime probe of the installed Safari binary. Neither the reviewed public API surface nor the installed SDK establishes a supported equivalent of Chromium's complete-tab audio capture. Do not infer such an API from the existence of tab mute or screenshots. [WebKit namespace source, revision 7770114b9d455b0b501b8de4f8b680b7783abf05](https://raw.githubusercontent.com/WebKit/WebKit/7770114b9d455b0b501b8de4f8b680b7783abf05/Source/WebKit/WebProcess/Extensions/API/WebExtensionAPINamespace.h)

WebKit documents speaker enumeration after microphone permission and HTMLMediaElement output routing through setSinkId on macOS beginning with Safari 18.4. This establishes a media-element capability, not capture of a complete tab's mixed signal. [Safari 18.4 media features](https://webkit.org/blog/16574/webkit-features-in-safari-18-4/)

Current Apple documentation allows temporary unpackaged extension testing without Xcode, while explicitly requiring a packaged project for messaging with a native app. This documentation does not establish that every described temporary-loading feature exists in the installed Safari 26.2. Temporary installation also expires; it is not the supported product installation model. [Running Safari web extensions](https://developer.apple.com/documentation/safariservices/running-your-safari-web-extension)

## Why the partial substitute is rejected

A page companion could potentially adjust accessible HTML audio/video elements' volume and mute, and select their permitted outputs. That scope does not include arbitrary Web Audio graphs, every WebRTC playback path, inaccessible frames, or all dynamically created media. Page-level device permissions and device identities also differ from extension or native application state. Individual elements can change or be replaced independently, so a single tab-level success indicator would overstate coverage.

Such a feature would need a separately defined media-player contract and its own restoration and ownership proof. It would not satisfy the complete-tab requirement, and it adds installation cost the user explicitly rejected. No implementation, node, or supported user flow for that subset is authorized by this design amendment.

## What can ship

Use OpenAudio's native application route for Safari's combined sound, with the same gain, mute, and output controls as other native applications. Keep independent Chromium tab controls optional. Safari full-tab parity requires a verified supported source of independent complete-tab audio or a browser capability change. Installing Xcode, signing an extension, or changing its packaging does not supply that missing audio boundary.

This document records a capability limit, not an instruction to investigate increasingly invasive workarounds. Safari runtime tab-audio parity remains unverified and outside the smallest shippable scope.

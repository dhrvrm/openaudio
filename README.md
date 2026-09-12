# OpenAudio

A native macOS audio mixer and vinyl listening room. Control application volume and outputs, manage supported browser tabs, and give the music you're playing a home on your desktop.

[Download prereleases](https://github.com/dhrvrm/openaudio/releases) · [Report a bug](https://github.com/dhrvrm/openaudio/issues) · [Changelog](CHANGELOG.md)

## What it does

- **Application mixer:** independent volume, mute and output selection; multiple outputs, stereo balance, ten-band EQ and Audio Unit effects.
- **Browser tabs:** independent controls through the bundled local Chromium companion, including Arc. No extension-store download required.
- **Vinyl and artwork views:** animated record and tonearm, full-screen presentation, themes, record colors, visual RPM controls and offline photographic backgrounds.
- **Track context:** Apple Music and Spotify integrations, plus supported browser metadata and available playback controls.
- **Automatic artwork:** source artwork first, then cache, then catalog lookup and public-page fallback. Title-only results are clearly labeled suggestions. Covers target useful 800–1200px resolution with bounded downloads, retries and caching.
- **Saved listening choices:** profiles, menu-bar controls and URL automation.

## Requirements and installation

macOS 15 or newer. Prerelease downloads currently target Apple silicon. Source builds target the Mac on which they are built; Intel runtime behavior is not validated.

Download the ZIP from [Releases](https://github.com/dhrvrm/openaudio/releases), extract it, and move OpenAudio.app to Applications. The bundled browser companion is included.

**Current prereleases are ad-hoc signed, not Developer ID signed or notarized.** macOS may block downloaded builds. Building locally is available below; these prereleases are intended for development and evaluation. Do not treat a passing build as a guarantee of device, browser or player compatibility.

## Start listening

1. Play audio in an application and find it in **Applications**.
2. Change its volume or choose an output. Allow macOS audio capture when requested. Bypass releases OpenAudio's audio control.
3. Open **Vinyl** from the sidebar or a source row. Choose Automatic source or pin a source.
4. Connect Apple Music or Spotify under **Connections & sound** when you want native track details and supported playback actions.

Artwork fetching is on by default while the listening view is visible. Disable it using **Cover lookup options → Fetch artwork automatically**. Manual refresh and cache clearing remain available. Missing or ambiguous metadata can produce an attributed suggestion or a fallback scene instead of a cover.

## Browser setup

Open **Browser tabs → Set up or update the local browser companion → Prepare local extension**. Show or copy the prepared folder, open your browser's Extensions settings, enable Developer mode and choose **Load unpacked**. Select that folder. Reload the extension after updating its local copy.

Click the OpenAudio extension toolbar button in each tab you want to capture; no popup is required. Newly audible tabs are discovered automatically, but browser approval is still required for first capture. For track details, enable the companion's optional metadata access.

If a speaker is missing, use **Allow output device access…**, then **Refresh devices**. Browser device visibility depends on browser permissions; macOS device discovery cannot replace those permissions.

**Limits:** Arc/Chrome tab integration is implemented. Safari is supported as a combined application; independent Safari tabs are not implemented. Other Chromium browsers and sites need compatibility validation. Applications that do not publish track metadata can still appear in the mixer without offering album details or playback controls.

## Privacy and permissions

Audio processing stays on your Mac. OpenAudio has no account, hosted audio processing service or language model in the audio path. macOS audio capture, optional Accessibility volume-key control, native-player Automation and browser permissions are separate features.

Automatic artwork can send the selected song's title, artist and album—or a cleaned browser title hint—to MusicBrainz and public music search/pages. Artwork downloads contact their publishers. The cache uses seven-day image and ten-minute miss expiry with an approximately 32 MB cap. Only the selected visible listening source is searched; disabling automatic artwork leaves explicit lookup available. See [Privacy](PRIVACY.md).

## Build and test

Install Xcode Command Line Tools with a Swift 6 toolchain. Node.js 22 is used for companion checks.

```sh
git clone https://github.com/dhrvrm/openaudio.git
cd openaudio
Scripts/test.sh
Scripts/build-app.sh
Scripts/check-browser.sh
```

The application is at `dist/OpenAudio.app`. Open it manually when you want to use it. These checks do not run live audio capture, browser interaction or player control. `Scripts/smoke.sh` is a separate, opt-in live audio test and is never run by CI.

For personal SSH access on the maintainer's configured machine:

```sh
git clone git@github.com-personal:dhrvrm/openaudio.git
```

## Development and releases

[Contributing](CONTRIBUTING.md) covers checks and changes. [Release maintenance](docs/releases.md) explains versioning, automated prerelease ZIPs and checksums, and the separate Developer ID/notarization path. The current application is **0.5.3**; its bundled companion is **0.5.0**.

See the [feature matrix](docs/feature-matrix.md), [architecture](docs/architecture.md), [browser documentation](docs/browser-tabs.md) and [latest artwork verification](docs/automatic-artwork-verification.md) for implementation boundaries. Live player, device and fullscreen behavior remains separately verified; recent artwork iterations used fixtures and source review.

## License

OpenAudio source is [MIT licensed](LICENSE), copyright 2026 Dhruv Verma. Bundled photographs retain their own license and attribution; see [Third-party notices](THIRD_PARTY_NOTICES.md). Music services, album artwork and third-party Audio Units are not relicensed by this repository.

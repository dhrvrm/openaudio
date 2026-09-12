# Release maintenance

Git uses the maintainer's personal SSH alias: `git@github.com-personal:dhrvrm/openaudio.git`. Commit identity is local to this repository: Dhruv Verma and the dhrvrm GitHub noreply address. No signing keys or GitHub access tokens belong in this repository.

## Development prereleases

1. Update `Resources/Info.plist` application version and build number. Update the artwork User-Agent version if applicable. The browser companion has an independent version; only increment it when its implementation changes.
2. Update CHANGELOG.md and add `docs/releases/vVERSION.md`, including platform requirements, known limitations, signing status and verification scope.
3. Run `Scripts/test.sh`, `Scripts/build-app.sh`, `Scripts/check-browser.sh` and `Scripts/package-prerelease.sh`. Inspect `dist/release/` and verify SHA256SUMS.
4. Commit and push main through the personal SSH remote. Wait for the Build and release workflow to pass.
5. Create an annotated tag matching the application version and push it:

   ```sh
   git tag -a v0.5.3 -m 'OpenAudio 0.5.3 prerelease'
   git push origin v0.5.3
   ```

The tag workflow checks its version, runs fixtures, builds on an Apple-silicon macOS 15 runner, packages the app with license/notices and a checksum, and publishes a GitHub prerelease through the repository's GITHUB_TOKEN. It never uses the maintainer's work account. Pull requests have read-only workflow permissions. Release publication has write permission only in its separate tag job.

Published releases are not overwritten. For corrections, increment the version and publish a new tag. App binaries stay out of Git; release assets and temporary Actions artifacts carry them. CI does not launch the app, play sound, interact with browsers or request capture permissions.

## Signed, notarized distribution

The separate `Scripts/package-release.sh` requires `OPENAUDIO_SIGNING_IDENTITY` for a Developer ID Application identity and `OPENAUDIO_NOTARY_PROFILE` for a configured notarytool keychain profile. It signs the app, submits it to Apple, staples and assesses it, creates a DMG, and notarizes/staples that image.

This path requires publisher credentials and is not enabled by the prerelease workflow. Do not mark development ZIPs as notarized or remove their development notice. Before offering stable releases, validate physical-device routing, browser permissions, player control and fullscreen behavior on supported systems, and review external artwork-provider distribution terms.

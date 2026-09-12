#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
: "${OPENAUDIO_SIGNING_IDENTITY:?Set the publisher Developer ID Application signing identity}"
: "${OPENAUDIO_NOTARY_PROFILE:?Set the publisher notarytool keychain profile}"
[[ "$OPENAUDIO_SIGNING_IDENTITY" != "-" ]] || { print -u2 'A Developer ID signing identity is required'; exit 1; }
Scripts/build-app.sh
app="$PWD/dist/OpenAudio.app"
archive="$PWD/dist/OpenAudio-notarization.zip"
ditto -c -k --keepParent "$app" "$archive"
xcrun notarytool submit "$archive" --keychain-profile "$OPENAUDIO_NOTARY_PROFILE" --wait
xcrun stapler staple "$app"
xcrun stapler validate "$app"
spctl --assess --type execute --verbose "$app"
staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT
ditto "$app" "$staging/OpenAudio.app"
ln -s /Applications "$staging/Applications"
hdiutil create -volname OpenAudio -srcfolder "$staging" -ov -format UDZO "$PWD/dist/OpenAudio.dmg"
codesign --timestamp --sign "$OPENAUDIO_SIGNING_IDENTITY" "$PWD/dist/OpenAudio.dmg"
xcrun notarytool submit "$PWD/dist/OpenAudio.dmg" --keychain-profile "$OPENAUDIO_NOTARY_PROFILE" --wait
xcrun stapler staple "$PWD/dist/OpenAudio.dmg"
xcrun stapler validate "$PWD/dist/OpenAudio.dmg"

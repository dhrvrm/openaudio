#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
swift build -c release
app="$PWD/dist/OpenAudio.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp .build/release/OpenAudio "$app/Contents/MacOS/OpenAudio"
cp Resources/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"
cp Resources/browser-host "$app/Contents/Resources/browser-host"
mkdir -p "$app/Contents/Resources/BrowserExtension"
for resource in manifest.json worker.js engine.js report.js media.js device-catalog.js offscreen.html offscreen.js options.html options.js popup.css; do
    cp "BrowserExtension/$resource" "$app/Contents/Resources/BrowserExtension/$resource"
done
mkdir -p "$app/Contents/Resources/Moods"
cp Resources/Moods/*.jpg Resources/Moods/Credits.json "$app/Contents/Resources/Moods/"
cp Resources/CoverPage.js "$app/Contents/Resources/CoverPage.js"
cp Resources/Info.plist "$app/Contents/Info.plist"
signing_identity="${OPENAUDIO_SIGNING_IDENTITY:--}"
if [[ "$signing_identity" == "-" ]]; then
    codesign --force --entitlements Resources/Audio.entitlements --sign - "$app"
else
    codesign --force --entitlements Resources/Audio.entitlements --options runtime --timestamp --sign "$signing_identity" "$app"
fi
codesign --verify --deep --strict "$app"
printf '%s\n' "$app"

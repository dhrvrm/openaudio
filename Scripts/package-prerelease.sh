#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
app="$PWD/dist/OpenAudio.app"
codesign --verify --deep --strict "$app"
version="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist")"
source_version="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)"
[[ "$version" == "$source_version" ]] || { print -u2 'Rebuild the app before packaging'; exit 1; }
architecture="$(uname -m)"
[[ "$architecture" == arm64 || "$architecture" == x86_64 ]] || exit 1
lipo "$app/Contents/MacOS/OpenAudio" -verify_arch "$architecture"
output="$PWD/dist/release"
mkdir -p "$output"
staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT
ditto "$app" "$staging/OpenAudio.app"
cp LICENSE THIRD_PARTY_NOTICES.md "$staging/"
cp "docs/releases/v$version.md" "$staging/README.md"
archive="OpenAudio-$version-macos-$architecture.zip"
ditto -c -k "$staging" "$output/$archive"
(cd "$output" && shasum -a 256 "$archive" > SHA256SUMS)
print "$output/$archive"

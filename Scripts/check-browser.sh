#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
for script in BrowserExtension/*.js; do node --check "$script"; done
node --test Tests/browser-engine.test.mjs Tests/device-catalog.test.mjs Tests/media.test.mjs Tests/cover-page.test.mjs Tests/browser-transport.test.mjs
checks="$(mktemp -d)"
trap 'rm -rf "$checks"' EXIT
swiftc Sources/OpenAudio/Listening/MediaModels.swift Sources/OpenAudio/Control/BrowserBridge.swift Sources/OpenAudio/Control/BrowserIntegration.swift Tests/BrowserRegistrationChecks.swift -o "$checks/check-registration"
"$checks/check-registration" "${1:-$PWD/dist/OpenAudio.app}"

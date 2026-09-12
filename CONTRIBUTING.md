# Contributing

Use focused branches and pull requests. Explain the user-visible problem, resulting behavior and verification. Run `Scripts/test.sh`, `Scripts/build-app.sh` and `Scripts/check-browser.sh` on macOS 15+ with Swift 6 and Node 22 before submitting changes.

Tests must use fixtures or synthetic in-memory audio by default. Live capture, playback, browser interaction and permission prompts are opt-in and must never enter CI. Do not commit local listening history, credentials, private device diagnostics or signing material.

Read the relevant `SUBSYSTEM.md` contracts before changing behavior, and update architecture documentation when its boundaries change. Keep explanatory rationale in the PR; avoid comments that merely restate code. UI changes should include a mock-data preview and accessibility considerations.

Update CHANGELOG.md for user-visible changes. Release tags and artifacts follow [the release guide](docs/releases.md). Contributions are provided under the repository's MIT license; retain third-party attribution.

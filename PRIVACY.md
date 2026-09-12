# Privacy

Audio processing happens locally. No account or audio-upload backend is required. Settings, profiles, companion registration and artwork cache are stored locally.

Optional permissions serve separate purposes: macOS capture for audio routing; Accessibility for volume keys; Automation for Music/Spotify metadata and commands; browser permissions for tab capture, device names and optional track details. Granting one does not grant the others.

While the listening view is visible, automatic artwork may send the selected song title, artist and album, or a cleaned tab-title hint, to MusicBrainz and public music search/pages. Cover downloads contact the artwork host. Source-provided artwork URLs can also be fetched. Remote providers receive normal network request information including IP address. OpenAudio does not control their privacy policies.

Turn off **Fetch artwork automatically** in cover options to stop automatic external searches. Explicit lookup remains available. Clear retained lookup images using **Clear saved cover lookups**. Successful covers expire after seven days and misses after ten minutes; cache storage is capped at approximately 32 MB.

Do not post raw diagnostics publicly without reviewing app names, device identifiers, file paths and song/tab details they may contain.

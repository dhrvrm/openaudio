# Feature scope

| Capability | Implementation | Remaining qualification |
| --- | --- | --- |
| Per-app volume, mute, balance | Native controls and C signal processing | Protected/noncapturable sources can still return silence |
| Per-app output routing | Core Audio process taps and private aggregates | Physical audibility and disconnect/reconnect need listener/device testing |
| Multiple selected outputs | Aggregate output channels with per-device mapping and drift compensation | Device-pair synchronization and long-duration drift need measurement |
| Ten-band EQ | Peaking filters with flat, speech, bass, and gentle-treble presets | Bands above Nyquist are bypassed |
| Boost | Up to +12 dB with full-scale output cap | Hard clipping protection; not Rogue Amoeba's proprietary boost algorithm |
| Audio Unit effects | Ordered stereo effect chain, bypass, reorder, generic parameter sliders | Apple low-pass effect tested; third-party compatibility not exhaustively tested; no custom plugin editor or factory-preset browser |
| System processing | Other-audio route covers sources without explicit processing; excludes mixer and explicit routes | Does not cascade the Other-audio EQ into explicit app routes |
| System devices | Default input/output/effects, supported volume/mute and nominal rates | Unsupported hardware writes remain unavailable |
| Fixed-volume devices | Per-destination software gain/mute on controlled audio | Nondefault device audio outside OpenAudio control is unaffected |
| Volume keys | Accessibility-gated event tap controlling current output | Physical key handling requires Accessibility approval and manual check |
| Menu bar | Compact live mixer, app selection opens full editor | Favorites and playing apps appear in compact list |
| Profiles and persistence | Saved routing/effects, unique names, undo, retained enable state | Profiles do not capture hardware defaults or software device-master levels |
| Automation | Validated URL actions usable with Shortcuts Open URLs | No native App Intents metadata |
| AirPlay | OS-exposed AirPlay outputs appear like other devices | No independent AirPlay discovery/connection implementation; no AirPlay hardware available for validation |
| Headphone correction | Manual ten-band EQ saved in profiles | No headphone-model correction database or parametric import |
| Appearance and login | Native light/dark/system appearance, launch-at-login integration | Login registration needs the app kept at a stable location |
| Safe lifetime | Startup rollback, callback watchdog, disjoint route membership, retryable cleanup, sleep/wake handling | Physical removal, wake, coreaudiod restart, and forced teardown failures need expanded integration testing |

OpenAudio implements the central mixer workflow. It is not a claim of complete SoundSource feature parity or identical proprietary audio processing. See the original [SoundSource feature list](https://rogueamoeba.com/soundsource/) for the broader reference.


## Vinyl mode (0.5.1)

| Capability | Implemented behavior | Verification / limit |
| --- | --- | --- |
| Listening composition | Album sleeve, grooved colored record, metallic tonearm, square Artwork scene | Static mock-data renders inspected at compact and wide sizes |
| Appearance | Cream/Ink/Album, four record colors, four visual speeds, persistent selected mood | Native controls and resource packaging checked; no live interaction |
| Motion | Continuous phase, smooth acceleration/deceleration, Reduce Motion, player/audio-activity tonearm | Pure motion checks; animation timing not measured on display |
| Mood fallback | Bundled Unsplash Warm/After dark/Nature photos and contrast overlays, photographer links | Offline resources; photos do not masquerade as album covers |
| Fullscreen | Actual containing window binding, transition observation, watchdog, Escape and Control–Command–F | Built and independently reviewed; desktop transition still live-unverified |
| Source detection | Automatic source selection, sticky active player, session pin, unavailable/stale states | Pure selection/freshness fixtures |
| Apple Music / Spotify | Current track, artwork, play/pause/next/previous behind explicit Automation connection | Native provider integration remains live-unverified |
| Arc / Chrome metadata | Media Session plus scoped YouTube Music current-player fallback | Synthetic fixtures; extension must be reloaded |
| Browser transport | Play/pause for one unambiguous HTML player; YouTube Music queue controls when available | Exact document, session, capability and authorization checks; navigation/revocation/error fixtures |
| Covers | Source artwork, cache, explicit MusicBrainz/CAA lookup, built-in WebKit public-page fallback | Verified identity matching or clearly labeled title-only suggestions, 7-day hit/10-minute miss TTL, 32MB cap, refresh/clear; no live provider validation |
| Safari / arbitrary apps | Native application sound remains separate from optional track metadata | No Safari per-tab adapter or universal metadata/transport API |
| Library / interaction | Current listening presentation | No record collection/library, drag-to-seek needle, lyrics, track recognition, or MD Vinyl feature-parity claim |

The visual reference is [MD Vinyl's iPad presentation](https://apps.apple.com/us/app/md-vinyl-music-app/id1606306441). OpenAudio has its own artwork treatment and mixer workflow. Static rendering and fixture success do not establish live player compatibility, audible routing, fullscreen interaction or VoiceOver usability.

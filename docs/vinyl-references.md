# Vinyl mode references — 2026-09-12

The reviewed products are references, not an exhaustive census of every store listing.

| Product | Relevant idea | Published integration scope |
| --- | --- | --- |
| [VinylPlayer](https://myvinylplayer.com/) | Artwork-derived spinning records, floating widget, turntable finishes | Apple Music |
| [Vinyl for Mac](https://www.vinylformac.com/) | Album sleeve beside a rendered turntable, desktop scene | Apple Music and Spotify |
| [Sleeve](https://replay.software/sleeve) | Clear now-playing information, desktop presence, accessible controls | Apple Music, Spotify, Doppler |
| [Tuneful](https://tuneful.app/) | Quick access through menu bar, notch, mini player | Apple Music and Spotify |
| [Marquee](https://marquee.fm/) | Vinyl/cassette listening views around an existing music library | Apple Music |
| [VinylPod](https://apps.apple.com/us/app/vinylpod-music-widget/id6443989711) | Compact record artwork widgets | Listing describes multiple services; platform-specific behavior needs separate verification |

The intended emotional target is quiet absorption. OpenAudio keeps the original mixer structure and adds a dedicated listening window: warm ink, ivory type, a restrained grooved record, real artwork in its center label, and an artwork-only view. No invented album art represents a real track. UI access from every audio source is distinct from metadata availability for every source.

## Data sources and boundaries

- [Chrome scripting API](https://developer.chrome.com/docs/extensions/reference/api/scripting): scripting requires page access through activeTab or granted host permissions. Read Media Session in the page's MAIN world without changing its playback behavior. Optional broader access makes metadata discovery independent of tab audio capture.
- [W3C Media Session](https://www.w3.org/TR/mediasession/): pages can publish title, artist, album and artwork. Sites may provide nothing, stale values, or misleading data; bind observations to the exact tab and navigation.
- [Apple NSAppleScript](https://developer.apple.com/documentation/foundation/nsapplescript): use the installed application's scripting dictionary for supported commands. Music's local dictionary exposes current track, artist, album, duration, player position, player state and artwork raw data. Spotify's adapter remains runtime-unverified on this Mac because Spotify is not installed.
- [MusicBrainz API](https://musicbrainz.org/doc/MusicBrainz_API): search by title/artist, compare album when available, require an unambiguous match. No API key is required; noncommercial service use is free, while commercial use has separate plans. A shipping commercial product must choose an appropriate service arrangement.
- [Cover Art Archive API](https://musicbrainz.org/doc/Cover_Art_Archive/API): obtain front artwork and available large thumbnails from matched release IDs. Not every recording/release has a cover.
- [MusicBrainz rate limits](https://musicbrainz.org/doc/MusicBrainz_API/Rate_Limiting): meaningful User-Agent and no more than one request per second per client. Lookup is explicit, coalesced and cached, with no retry loop on a miss or server failure.

A headless browser is not required for these structured sources. It would add a browser runtime, page-layout dependencies and possible sign-in challenges without making track identity reliable. Keep it out of this iteration.

The on-demand lookup cache keys include normalized title, artist and album plus provider version. Successful images expire after seven days; confirmed misses expire after ten minutes; transport failures are errors, not cached no-match claims. Manual refresh invalidates the selected key. Cache eviction bounds disk usage and a clear action removes saved cover lookups.

No live music playback, browser interaction, permission prompt or installed-app testing is authorized for this iteration.

## Current visual reference and fallback assets

The user-selected [MD Vinyl iPad screenshot](https://is1-ssl.mzstatic.com/image/thumb/PurpleSource211/v4/32/98/95/3298957d-8f6a-9eeb-1a98-3977e617bb82/01.png/626x470bb.webp) informs the sleeve/front-left, colored record/right and outer tonearm composition. No MD branding or album image is bundled.

Mood backdrops are bundled photographs under the [Unsplash License](https://unsplash.com/license), verified September 12, 2026. Per-image photographer, original page, image transformation URL, retrieval date and license URL are in `Resources/Moods/Credits.json`. The application does not use the Unsplash API or fetch mood photos at runtime.

The 0.5 implementation uses built-in [WKWebView](https://developer.apple.com/documentation/webkit/wkwebview/) for explicit cover fallback after catalog miss/error. It uses an ephemeral store, no visible window, no media playback, bounded approved navigation, fixed JSON-LD extraction and title/artist/album corroboration. This supersedes the earlier omission of a headless fallback. Public-page layouts and anti-bot responses are runtime limitations; no CAPTCHA or login bypass is attempted.

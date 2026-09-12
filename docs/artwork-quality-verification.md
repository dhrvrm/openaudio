# Artwork quality — 0.5.2

Catalog artwork checks actual decoded dimensions. Published variants of the same approved front cover are tried in priority order: 1200, original, large, 500, deduplicated and capped at three. A prepared short edge of 800 pixels is sufficient; otherwise the best smaller usable cover remains. Artist/release candidate ordering is unchanged.

Prepared JPEGs have a maximum long edge of 1200 pixels, never upscale, and occupy at most 1 MiB. Each image request is limited to 2 MiB. A shared three-request budget bounds catalog and headless image transfers to 6 MiB per lookup, conservatively charging failed requests too. Source-supplied artwork is unchanged.

Existing cache entries remain readable. Explicit lookup upgrades legacy quality policy; Refresh retries current entries. Failed or lower-resolution replacement retains the previous cover and reports the outcome without overwriting its cached provenance or timestamp.

Verification: 31 native checks and 67 listening checks passed, including generated-image fixtures for resolution preference, size preparation, no upscaling, oversized alternatives, deduplication and cancellation. Release build and strict signature verification passed. Targeted review findings were fixed and rechecked. No live provider, browser, playback or installed-app testing was performed.

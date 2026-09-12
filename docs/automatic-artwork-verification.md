# Automatic artwork — 0.5.3

Automatic artwork is enabled by default and can be disabled in the listening view's cover options. Only the selected visible source is searched, after an 800 ms debounce. Source-provided artwork and fresh positive cache entries take precedence. Same-key automatic attempts have a ten-minute cooldown; manual refresh remains available. Changes to track identity, visibility or the setting cancel obsolete automatic work, with generation checks on result publication.

External lookup retries temporary 429/502/503/504 failures once with a bounded wait. Retry-After supports seconds and HTTP dates; waits over five seconds defer the service. Backoff applies to original and redirected response hosts, retains the longest deadline, and blocks redirects into deferred hosts. Source-provided artwork fetch behavior is unchanged. Image retries count against the existing shared three-attempt, 6 MiB maximum lookup budget.

Catalog errors and misses can continue into existing public-page discovery, including title-only hints. Suggestions require exact title and published artist/album; known album and artist constraints remain binding. No new catalog was added. Artwork availability still depends on the remote services and readable page metadata.

Verification: 31 native checks and 83 listening checks passed. Fixtures cover transient recovery, retry exhaustion, long Retry-After, HTTP-date parsing, canceled waits, shared image-attempt budget, per-key cooldown, exact-title fallback and known-album constraints. Controller scheduling and redirect/backoff enforcement received source review; no live provider, browser, app, audio or permission tests were performed. The installed application was not replaced.

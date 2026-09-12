---
name: listening-context
definition: >
  Resolve the intended listening source into truthful media context and bounded supported playback actions without taking ownership of audio delivery. Without this boundary source selection, delayed artwork, and optional publisher access could misidentify the sound or act on an unintended source.
inputs:
  - name: listening-focus
    description: >
      The current candidate source identities and observed activity, explicit or automatic focus intent, source pin, presentation visibility, retained automatic-artwork preference, permitted metadata access, and browser-supplied media facts, supplied by listening control so focused context and authorized artwork lookup belong to the intended visible source.
  - name: media-action-intent
    description: >
      An explicit request for a supported native playback action or selected-track cover lookup, refresh, or cache clearing, supplied by listening control so media actions cannot be inferred from presentation changes or applied to a replacement source.
  - name: media-observation
    description: >
      Source-bound published track details, artwork references or content, playback state, available action capabilities, access failures, and requested action outcomes, supplied by media publishers so listening context reflects actual source information.
  - name: artwork-observation
    description: >
      Candidate cover identity, candidate artist and release, catalog or public-page provenance, corroborated-match or title-only-suggestion status, same-cover image variants and measured dimensions and size, and absent, blocked, or failed outcomes, supplied by media publishers so image quality can be assessed without changing or overstating source identity.
  - name: artwork-cache-observation
    description: >
      Previously retained verified covers, explicitly labeled title-only suggestions, or known misses with matching and quality-policy identity, provenance, measured image dimensions, expiration, and retained size, supplied by local retention so current imagery remains reusable without confusing confidence, quality, or policy validity.
outputs:
  - name: listening-context
    description: >
      The resolved source identity, provenance and freshness of observed track details, verified or explicitly suggested artwork with candidate attribution, fallback reason, supported media actions, and action outcomes, supplied by context resolution so presentation never represents a suggestion as identified source metadata.
  - name: media-request
    description: >
      Source-scoped requests for permitted media observations or explicitly requested supported playback actions, supplied to media publishers so context and actions are limited to the authorized source and capability.
  - name: artwork-request
    description: >
      An authorized automatic or explicitly requested cover lookup for the selected visible source containing observed media identity or a clearly distinguished title-only search hint and an optional permitted public source reference, supplied to approved catalogs or bounded public-page discovery so verified and suggested artwork remain limited to the current source and retained lookup preference.
  - name: artwork-cache-retention
    description: >
      Bounded verified-cover, title-only-suggestion or miss entries with matching and quality-policy identity, candidate attribution, measured prepared dimensions, retained size and expiry, together with explicit refresh and clear intent, supplied to local retention so reuse remains time-limited, attributable, quality-aware, and removable.
---

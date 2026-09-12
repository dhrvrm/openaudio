# Vinyl listening mode

Current artwork policy: automatically look up a stable eligible selected source while Vinyl is visible, unless the saved automatic-artwork toggle is off or source artwork/a fresh positive cache already satisfies it. The Automatic artwork and transient-provider recovery amendment below supersedes earlier explicit-only lookup restrictions; manual Find/Suggest/Refresh remains available.

## Behavioral contract

Vinyl mode presents a selected application, process, or browser tab as an immersive listening scene with album art when available and a physical-looking record. It is available from every source row, the mixer toolbar, the menu-bar interface, and an application menu command with a keyboard shortcut. Opening, pinning, entering fullscreen, or closing this view does not change routing, enable interception, or start playback.

Apple Music and Spotify receive explicitly enabled native media integrations. Other applications and arbitrary processes can always open Vinyl mode, but receive a named source fallback when metadata is unavailable. Eligible browser tabs may supply their page-published media metadata after authorized access. Source availability is universal within the mixer's known sources; song-title and artwork availability is not.

The full requested-and-related graph appears in [architecture.md](architecture.md#vinyl-listening-amendment). Listening owns source-bound media context and bounded supported source actions; Control owns focus/consent intent and presentation distribution; UI owns the scene; BrowserExtension provides browser-authorized metadata through its existing observation path. The audio-delivery contract does not change.

## Source selection and identity

Opening Vinyl from an application, process, or tab explicitly selects and pins that source. Opening it globally uses the current pin if one exists; otherwise it uses automatic selection. A visible source chooser and a labeled pin/automatic control make this behavior inspectable. Selecting a different item explicitly pins the new source. Returning to automatic is a deliberate action.

Automatic selection keeps the current source while it remains observed active, avoiding switches caused solely by a metadata update or louder peak. When it must choose a replacement, it selects the eligible source most recently observed becoming active, breaking equal timestamps by stable source identity. If no source is active, retain the current still-existing source as idle; otherwise show an empty listening scene with a source-selection action. Initial discovery uses a deterministic stable-identity tie-break when actual start order is unknown.

A native browser aggregate is excluded from automatic candidates when a distinct active tab from that browser is present, preventing the same listening activity from winning twice. Explicit selection still permits the aggregate with an application-level fallback. The system-wide Other audio mix is selectable as an aggregate fallback, but does not win automatic selection over an identified active source.

Pins are session-scoped. A pinned source that exits remains visibly unavailable and does not silently select another. Application identity follows the mixer's existing identity; a process pin also requires its current process lifetime; a browser pin requires browser/profile/session/tab identity. Track facts additionally require the current provider and document/track generation. Browser tab replacement or navigation invalidates previous document metadata.

Metadata is never assigned by app name similarity, renderer process guess, title matching, foreground status alone, or inference from audio samples. Delayed results must match the selected source and current request/track generation before becoming visible.

## Media context and consent

Each context identifies its source, observation time, provider, and status: unsupported, not enabled, access required, loading, available, idle, stale, or failed. Track title, artist, album, artwork, playback state, and progress are independently optional fields. A tab title or application name remains labeled source information and is not promoted to a track title.

Native integrations are limited to known Apple Music and Spotify capabilities, with one explicit opt-in per application before any Automation request. Polling cannot prompt for new access merely because the application is running or Vinyl opened. Opting out stops further reads and clears adapter-derived context. Reads and commands do not launch an application; an explicit Open source action may focus or launch that application.

Every native observation and action is bounded in execution time and payload size. Only fixed supported operations addressed to the verified application identity are accepted. No browser metadata, artwork value, title, or external message may become executable script or a free-form command. Explicit selected-track cover lookup, refresh, and cache-clear actions also cross media-action-intent with immutable source/track identity. Media work never enters audio callbacks or blocks the main interaction loop. Repeated failure becomes an actionable unavailable state rather than a prompt loop.

Metadata observation and artwork work are active only while the listening presentation needs them. Closing the last Vinyl presentation ends its polling and cancels obsolete work. Native permission denial, application exit, or missing current-track data affects only media context; the mixer's listening controls continue to operate.

## Browser context boundary

The companion can read page-published media context for a specific authorized tab/document. The initial access follows the browser's clicked-tab grant; observing other tabs or continuing across permissions boundaries requires explicit optional host access where supported. Existing tab-audio capture authorization is not assumed to grant page metadata access.

The browser observation associates page metadata with the existing tab identity plus current document identity and freshness. Navigation, denied access, absent page metadata, or failed refresh clears or marks that source's context appropriately. Reading metadata does not mutate page playback, inject arbitrary caller-supplied code, or capture additional audio. Explicit supported playback actions are separate requests with document-bound targets and observed outcomes.

Browser Vinyl offers Open tab, existing mixer controls for managed tabs, and fixed playback actions only when a supported current-page adapter reports those capabilities. A page-published media description alone does not establish remote playback support. The Browser playback and metadata amendment below defines the authorized adapter boundary.

## Supported native playback actions

Native Play/Pause, Next, and Previous appear only for a selected supported, enabled, running application whose adapter supplies those capabilities. Their intent crosses media-action-intent with immutable source/session identity and a unique request identity. Changing selection cannot redirect a pending action to a different application.

A pending action is visibly pending and prevents duplicate activation of that same operation. Completion reports command acceptance or a concrete failure; playback state and track changes update only from subsequent source observation. A successful command return is not evidence that the new track is already playing. Timeout, revoked Automation access, unavailable target, and unsupported command remain distinct actionable outcomes.

Actions queued for an obsolete source session are discarded. Results from an already dispatched action remain associated with their original source and cannot overwrite the new selection's state. Playback controls are explicit user actions; opening the view, selecting artwork, or entering fullscreen cannot trigger them.

Volume, mute, and output controls continue to use existing mixer edit relations and retain their existing effects on audio-control activation. Browser ownership restrictions remain visible. Metadata failure cannot disable otherwise valid mixer controls.

## Artwork and fallback

The selected source alone receives bounded artwork retrieval and decoding. Browser-provided artwork references are untrusted: accept supported HTTPS references only, enforce bounded response size, dimensions, and time, reject unsupported or malformed content, and cancel obsolete retrieval. Reject redirects or responses that escape the permitted reference policy. Artwork never grants filesystem access or permission to issue arbitrary commands.

Native application artwork may arrive as bounded source-provided image content or an explicitly supported remote reference. A missing image, access failure, stale reference, or failed decode falls back to source identity. Artwork for the previous track must not remain presented as current while a new track loads. An image cache cannot override source/track-generation checks.

Fallback is intentionally designed: a source icon or restrained monogram on the record label, source name, and a brief status such as Track details unavailable. It does not invent an album, musician, duration, or progress. Empty and unavailable states use the same scene rather than a broken-image panel.

## Visual and interaction contract

Use warm cream, dark ink, subdued metallic record details, and generous negative space. The vinyl record is a scalable physical composition with concentric grooves, a label, and a spindle; it remains coherent with or without artwork. Album art supplies the scene's atmospheric color only when it is valid for the current source. A softened enlarged art backdrop may carry the dreamy effect while readable text stays on predictable contrast.

One reusable listening window owns native fullscreen presentation. The mixer, compact menu, source rows, and menu shortcut all reach it. Source-specific entry preserves the clicked identity. Fullscreen emphasizes art and record; controls can recede after inactivity but return on pointer movement or keyboard focus. An accessible exit and the source identity remain discoverable. Exiting fullscreen restores the window; closing it leaves audio and the mixer running.

Motion follows known playback or observed source activity and stops for known pause/idle. It does not imply a known track when metadata is absent. Reduced Motion replaces continuous spinning and large transitions with a static record and restrained state changes. VoiceOver receives meaningful source, track, artist, playback, pin, and control labels; decorative grooves and atmosphere are hidden from accessibility navigation.

Every action is keyboard reachable, with visible focus and predictable order. Escape and normal macOS fullscreen controls provide a return path. An art-focused scene must not trap keyboard focus or hide all controls from assistive technology. Progress appears only when its source provides meaningful timing; unknown duration remains unknown.

## Minimality and readiness

Listening-context is one necessary new node because metadata and source actions are an independent environmental relation that cannot be derived from audio routing. Selection, provenance, stale-result rejection, and action targeting preserve one source-correlation invariant, so they remain together. Artwork loading and optional adapters remain its interior concerns. The scene stays inside listening-interface, and the existing browser boundary carries browser metadata. No second audio session, media daemon, or generic page-command channel is introduced.

READY for implementation against the materialized root, Control, Listening, UI, and BrowserExtension contracts. Audio-delivery remains unchanged. The graph contains six contracts, five implementation nodes, six environmental counterparts, and twenty-three matched relation kinds.

The current instruction permits static/code validation and pure model tests only. No browser interaction, audio playback/capture, Automation request, permission prompt, or live application command is authorized for verification. Selection ordering, pin behavior, generation invalidation, command targeting, metadata fallbacks, and bounded input handling can be verified without those actions. Actual provider responses, image retrieval, native Automation, playback commands, fullscreen interaction, and audible behavior remain unclaimed until separately authorized live validation.


## Optional high-quality cover lookup

Artwork supplied by the native application or authorized page has priority. A fresh, previously corroborated local cover may follow. When those are unavailable, Find cover offers an explicit lookup of the selected track through MusicBrainz and Cover Art Archive. Automatic lookup follows the current visibility, preference, debounce, cache, and cooldown policy below; manual Find cover remains available. Only the selected track's observed title, artist, available album identity, and an optional verified public source reference leave the application. Source lists, private browser URLs, listening history, and audio do not.

For verified matching, a meaningful title and artist are required. Match their normalized identities exactly, and also require album identity when the source supplies it. The title-only suggested-cover path below is separately authorized when verified identity is unavailable. Search ranking alone is not corroboration. If absent album information or multiple releases leave the cover ambiguous, report No unambiguous cover rather than silently choosing a different release. Catalog information does not overwrite the source's track facts. Accepted artwork is labeled with MusicBrainz / Cover Art Archive provenance and can link to its matched release.

The lookup distinguishes pending, matched, no match, ambiguous, unavailable artwork, service failure, and cancelled/obsolete request. Selection or track-generation changes cancel or invalidate its result. The saved automatic-artwork preference authorizes eligible selected-source queries; Find cover and Refresh cover are explicit requests for the current selection. Clear downloaded covers removes retained images and lookup results without modifying the source's own artwork or audio state.

Successful corroborated cover entries expire after seven days. Known misses and ambiguous results expire after ten minutes. Transport/service errors are not cached as proof that a cover does not exist. Retention uses normalized title, artist, and album identity together with provider provenance, and remains bounded to approximately 32 MB with deterministic eviction. Expired entries do not initiate hidden-view lookup; eligible visible-source lookup follows the automatic policy and the listener can also refresh. Corrupt entries are discarded. Clearing the cache must also invalidate in-flight work so a late response cannot repopulate it unexpectedly.

MusicBrainz documents no API-key requirement, a meaningful client identifier, and at most one request per second. Its public service is free for non-commercial use; commercial distribution must resolve the provider's commercial terms rather than advertising universal free access. Structured metadata lookup is attempted first; the explicitly authorized rendered-page fallback described below can continue that same Find cover request. [MusicBrainz API terms and limits](https://musicbrainz.org/doc/MusicBrainz_API)

Cover Art Archive supplies cover references associated with MusicBrainz release identities. Use bounded, supported image retrieval and decoding; a matched release need not have usable artwork. The provider does not supply a guarantee of complete or correct coverage. [Cover Art Archive API](https://musicbrainz.org/doc/Cover_Art_Archive/API)

The four new external flows are artwork-request, artwork-observation, artwork-cache-retention, and artwork-cache-observation. They are materialized on the root and listening-context contracts and matched by the existing media-publishers and renamed listening-store boundaries in architecture.md. No additional runtime node is needed. Lookup/cache behavior can be validated with fixtures and an injected clock; no live provider request is authorized as a test in this work unit.


## Rendered public-page cover fallback

The user's requested headless fallback is part of an authorized automatic or manual selected-source cover operation. After the structured provider returns no usable cover, an ambiguous result, or a recoverable service error, the same bounded request may continue through browser-rendered public-page discovery. Automatic requests occur only after the current visible-source eligibility and debounce checks. Status makes the stage visible: Searching catalog, Checking public music pages, then Matched, No corroborated cover, Lookup blocked, or Lookup failed.

The fallback is an interior mechanism of listening-context, using an isolated, ephemeral system-provided page renderer. It requires no downloaded browser, access to the user's running browser, saved browser profile, cookies, login session, or existing tabs. Closing Vinyl, cancelling the lookup, changing source/track generation, or clearing downloaded covers ends the request and invalidates all late results.

Title and artist search must work without a supplied page URL. The provider policy may use a bounded public search for the observed title, artist, and available album, then inspect a small bounded set of approved public music pages. A verified public source URL can be an additional candidate, but a URL-only fallback does not satisfy this requirement. Discovery pages identify candidates; search-result thumbnails or ranking are never sufficient cover evidence.

Only approved public search and music-provider destinations may be visited. Candidate and redirected destinations must remain within the declared provider policy and use supported secure transport. A page requesting login, subscription access, CAPTCHA, or other access challenge is skipped or reported blocked. There is no challenge bypass and no attempt to reuse the listener's credentials. Requests cannot select arbitrary local resources, arbitrary scripts, or arbitrary browser commands.

Candidate music pages must publish structured recording or release facts that corroborate the normalized title and artist, and album when supplied. Public JSON-LD or equivalent publisher metadata can provide these facts. A generic social-preview image with no corroborating track identity is not accepted. Multiple plausible releases, a mismatched album, missing artist, or an unresolvable redirect leaves the result unavailable rather than selecting the first image.

The renderer performs metadata discovery only: no audio/video playback, autoplay, capture, permission request, new window, download, external-app launch, or page playback action is permitted. Audio restrictions must be in effect before remote content is loaded. If the platform cannot enforce the required restricted rendering behavior, this stage reports unavailable instead of silently using an unrestricted browsing session.

Each lookup has finite navigation, response, decoded-image, candidate-count, and wall-clock budgets, with one active selected-track request. Public-page and image failures cannot block the interface or audio delivery. A matched cover records the originating publisher, verified page/release reference, and lookup-policy generation, and remains subject to the same source/track-generation check as native artwork.

The seven-day success lifetime, ten-minute known-miss lifetime, explicit refresh/clear behavior, and approximately 32 MB retained-image budget remain. Cache identity additionally includes provider-policy generation so a prior structured-only miss does not suppress a newly available rendered fallback. Errors and access challenges do not become cached proof that no cover exists. The fallback's provider attribution remains visible and does not claim that catalog-supplied art came from the playing application.

This mechanism adds no node or relation kind: artwork-request and artwork-observation now expressly include bounded public-page discovery; the two cache relations carry provider-policy generation. The existing media-publishers environment includes public music pages. The user's current request supersedes the earlier design's omission of a headless fallback.

## Continuous record motion and fullscreen refinement

The motion choices are Calm · 6 RPM, 12 RPM, 33⅓ RPM, and 45 RPM. Calm · 6 RPM is the initial visual preference. These values describe the depicted record's visual rotation only and never change playback rate or pitch. The visible speed text reflects the chosen preference; the view must not label a fixed unrelated animation as 33⅓ RPM.

Use one continuous clockwise record phase for the entire physical rotating assembly: grooves, printed label, label artwork, and record body rotate together. The spindle and environmental lighting remain stationary where their physical meaning requires it. Artwork-only mode keeps the album cover upright. Record-phase state belongs to the listening presentation, not to a metadata response or image-loading event.

At a steady selected speed, a full turn lasts ten seconds at 6 RPM, five seconds at 12 RPM, 1.8 seconds at 33⅓ RPM, and four-thirds of a second at 45 RPM. Starting or resuming approaches the target smoothly; pause or known idle smoothly decelerates to rest. Speed changes approach the new target continuously. Acceleration is bounded, phase does not jump, and angular velocity never reverses merely because a target changes.

Pause, resume, artwork replacement, source switch, window resizing, fullscreen transition, and changing speed preserve the current phase. Returning from suspension must not introduce a large accumulated-angle jump. User-selected mute alone does not imply the player paused. When actual playback state is unknown, any animation is based on explicitly labeled observed source activity rather than invented track progress.

Reduced Motion freezes the assembly at its current phase immediately and suppresses continuous spinning and large spatial transitions. Turning Reduced Motion off resumes from that phase, with smooth acceleration only if playback/activity warrants it. Hidden or closed Vinyl presentations do not continue an unnecessary animation loop.

The fullscreen composition gives the art/record a clear central role and uses generous proportional spacing instead of enlarging every control. Source and track hierarchy remain readable; the speed chooser, pin, artwork-only switch, and exit remain keyboard reachable. Receding controls reappear on pointer movement or focus and cannot vanish while keyboard or assistive-technology interaction is active. Smaller windows preserve readable labels, usable controls, and a complete visible record without clipped edges.

Pure fixtures validate elapsed-time phase integration at each speed, continuous speed transitions, deceleration, pause/resume, phase preservation across state changes, Reduced Motion freeze, and suspension bounds. Browser fallback fixtures validate discovery without a source URL, approved destination checks, exact identity corroboration, ambiguity, blocked pages, budget termination, stale-result rejection, and provider-policy cache invalidation. This work authorizes builds and pure/static tests only; no live application, browser, audio, provider lookup, or permission action is authorized for verification.


## Fullscreen, scene correctness, and reference audit

The user's [MD Vinyl reference](https://apps.apple.com/us/app/md-vinyl-music-app/id1606306441) informs the physical-record emphasis, album-led composition, and restrained listening controls. Its product identity or feature set is not a claim about OpenAudio. The active work is the defined artwork fallback, continuous record motion, working fullscreen, and coherent listening scene; additional reference features require their own verified capability and implementation.

Fullscreen targets the actual native window that contains the Vinyl presentation. The action cannot depend on whichever window happens to be globally first, key, or named similarly. UI owns the relation to that containing window, observes actual entering/entered/exiting/failed outcomes, and presents its current fullscreen state. During a transition, repeated requests cannot race contradictory state. A missing owning window leaves the action unavailable with a clear reason; it must not pretend fullscreen succeeded.

The window supports normal macOS fullscreen eligibility and an explicit Enter fullscreen / Exit fullscreen action, with a discoverable keyboard path and Escape return where applicable. Switching the scene, changing source, or resizing does not replace its ownership or reset the record. Exiting restores the same listening window. Verification of this binding can use a test window abstraction; actual desktop transition success remains unclaimed without an authorized live session.

Record and Artwork are independent explicit scene states. Selecting Artwork always produces an upright square album-cover scene. If no cover is available, Artwork displays a deliberate square source fallback with track/source context and a primary recovery action; it never silently renders the record instead. Record always retains the physical-record composition with or without label artwork. Loading, failed, missing, and available cover states preserve the chosen scene and its layout.

Scene controls reserve enough width for their complete labels; Scene must not wrap into fragments. The scene selector, speed chooser, source selection, and fullscreen control retain stable placement and focus order at the minimum supported window size. Artwork mode suppresses irrelevant spinning controls without shifting its source and recovery actions unpredictably.

Metadata recovery is visible in the primary composition, not hidden behind an overflow menu. For a supported native source without consent, show Enable track details. For an authorized but failed/stale source, show Retry track details with the actual state. For known title and artist but missing cover, show Find cover or Refresh cover with lookup progress; for a usable title-only hint, show Suggest cover with explicit suggestion attribution. For a browser source needing access, show Open tab for track details. Unsupported processes show Track details unavailable with Open source rather than a nonfunctional lookup button.

A reference gap report distinguishes implemented, fixture/build verified, live-unverified, and unsupported behavior. A screenshot or a successful build cannot establish native metadata permission, provider availability, generic browser transport, or fullscreen transition success. No blanket MD Vinyl parity or universal metadata claim belongs in the new build description.


## Saved customization and automatic detection

The listening view exposes a discoverable Customize control with visual themes Cream, Ink, and Album; fallback photo moods Warm, After dark, and Nature; Record or Artwork scene; and the defined 6, 12, 33⅓, or 45 RPM visual speed choices. Theme, fallback photo mood, scene, and speed persist across closing the window and relaunching OpenAudio. They share the existing preference authority and are independent of audio-route settings, browser permissions, and transient source pins.

Cream and Ink maintain predictable readable contrast. Album derives its atmosphere from valid current artwork and uses the chosen bundled photo mood when artwork is absent, with predictable Cream-style readable surfaces, preserving Album as the selected preference. Reset appearance restores the documented default theme, Warm fallback photo mood, Record scene, and Calm 6 RPM without clearing source permissions, saved routes, or downloaded-cover policy.

Automatic is the initial source mode for each new application session. New application/process activity and authorized browser tabs are discovered without opening a separate source picker or enabling a metadata integration for every poll. Automatic selection follows the deterministic sticky policy already specified. Explicitly opening a row still pins that source, and the active Automatic/Pinned state stays visible so a pin cannot look like failed detection.

Automatic source discovery does not imply automatic permission grants. Apple Music and Spotify metadata is read automatically while Vinyl is visible after that adapter's explicit opt-in; without consent, their source row and scene still appear with a prominent Enable track details action. Browser metadata refreshes under existing page permission; missing permission exposes Open tab for track details. Known current source artwork loads automatically when available; external catalog or rendered-page searching follows the saved automatic-artwork preference or a manual Find cover operation.

A missing cover is handled through the primary recovery action appropriate to the actual cause: enable access, retry metadata, find a corroborated cover, or open an unsupported source. When only a usable title hint is available, the scene offers Suggest cover under the explicit suggested-artwork contract below. If no usable title hint exists, it offers source/metadata recovery rather than an ineffective lookup.

## Browser playback and metadata amendment

The native and browser command paths are distinct. Native playback continues through media-action-intent to listening-context. Browser playback crosses the existing tab-delivery-intent to browser-tab-delivery; tab-delivery-observation returns capability and outcome. A request is dispatched through exactly one provider path. No generic remote-script channel is added.

The initial known-page adapter is YouTube Music. When the page does not publish usable media-session context, its explicitly identified current-player fields may supply title, artist, album when present, and a current poster/artwork reference. Each field is marked with YouTube Music player provenance and current document identity. Do not parse artist/title from the tab title, concatenate unrelated page text, use recommendation artwork, or invent an album when the player does not provide it.

YouTube Music playback support is the fixed Play, Pause, Next, and Previous operations whose existing current-player controls can be identified unambiguously and are presently available. A generic HTML media adapter may offer only Play and Pause when it identifies one unambiguous active/current media element. Multiple competing elements, unavailable elements, missing permission, or unknown player state remove that capability and keep Open tab available. A Spotify web adapter is optional only when fixed known-player controls and reliable source association are separately established; Spotify application scripting does not establish Spotify web support.

Adapters publish capability before the native UI enables an action. Previous or Next must be disabled when the page control is absent or disabled, including queue boundaries. Unsupported actions never fall back to a guessed selector, global keyboard shortcut, or arbitrary page evaluation. Page state can change after a capability snapshot; the adapter revalidates immediately before acting and returns Unsupported or Unavailable if the action no longer exists.

Every request is bound to browser identity, profile/session generation, tab identity, current document identity, adapter identity, and unique command identity. Navigation or source replacement rejects the stale request before any action. Changing Vinyl selection cannot retarget it. Repeated delivery of a completed command identity does not click or invoke playback again; this is especially important for Next and Previous.

Play/Pause presentation resolves an explicit desired Play or Pause from the last reliable observed state rather than sending an unqualified toggle that may invert a changed state. If state is unknown, expose only a meaningful supported operation or require returning to the source. Only one action per source is pending at a time. Duplicate clicks are disabled while pending, and queued commands cannot survive a source/document change.

Outcomes distinguish pending, accepted, observed state change, stale target, unsupported capability, permission denied, browser user-activation required, unavailable player, timeout, and adapter failure. A resolved page invocation or synthetic control activation is not proof that audio started or a new track loaded. Accepted commands trigger a bounded metadata/playback refresh; the scene changes its playback indicators only from the resulting observation. Browser autoplay restrictions remain real and can require the listener to interact with the original tab.

No browser action starts a tab-capture session, changes outputs, or enables native interception merely to control the webpage's existing player. It does not accept a caller-provided script, selector, method name, URL navigation, or arbitrary arguments. The allowed operations and page adapters are fixed implementation-owned capabilities. Native play/pause/next/previous retains the same pending, immutable-target, timeout, and observed-result discipline.

## Decorative tonearm

Record scene includes a coherent tonearm anchored beside the record. A reliable fresh observed Playing state moves the arm smoothly from its rest onto the record grooves; reliable fresh Pause or Stop returns it smoothly. When track playback metadata is absent or stale, fresh source-specific audio activity may also move the arm onto the grooves, labeled Audio detected. With neither fresh playback nor fresh activity evidence, the arm rests; failed or unavailable metadata alone must not suppress otherwise valid source-audio activity. Artwork scene does not display a record or tonearm.

The tonearm is decorative state feedback. It does not expose drag-to-seek, map its angle to invented track progress, modify source playback, or claim physical needle interaction. If duration and position are unavailable, no sweep across the record implies elapsed track position. It remains fixed in the scene while the record assembly rotates beneath it.

Rapid play/pause observations smoothly retarget from the current pose instead of resetting the arm. Source changes invalidate the prior source's playback and activity evidence; stale metadata cannot leave its Playing pose indefinitely. Reduced Motion updates to the correct resting or playing pose without spatial travel; the arm remains hidden from accessibility navigation as decoration while playback state is announced through meaningful text/control labels.

Fixture coverage includes persisted appearance migration/defaults, Automatic versus session-pin state, absent-cover recovery actions, known-player metadata versus absent media-session facts, unique versus ambiguous generic players, missing queue controls, navigation between dispatch and execution, duplicate command IDs, timeout/permission/user-activation outcomes, and tonearm pose transitions. This amendment is READY after contract/graph validation. Builds and pure/static fixture tests remain the only authorized verification; no live browser, player, Automation, audio, or permission interaction is added.


## Bundled mood-photo atmosphere

When real album artwork is unavailable, loading, or rejected, the listening stage uses a curated photographic atmosphere instead of an unfinished blank backdrop. The user-requested Unsplash direction is interpreted as high-quality editorial photography: Warm, After dark, and Nature are selectable visual moods, with Warm as the default. These labels describe the listener's chosen appearance; they do not classify the track's emotional content or infer a song mood from audio.

Mood photographs are bundled application assets prepared by the publisher. They appear immediately offline, require no runtime photo service, and do not initiate network requests on source changes or Vinyl opening. Each bundled asset has a provenance record with photographer, original photo page, source, applicable license, and the version/date of the terms used for inclusion. Inclusion requires confirmed permission under those actual terms; an Unsplash source label alone is not a blanket license assumption. Photographer/source credits are reachable from the appearance controls without dominating the stage.

Valid current-source artwork retains priority. The photo atmosphere is used only when that artwork is absent or unusable. A fresh corroborated external cover remains a real-cover candidate under the existing attribution policy. Selecting another photo mood never replaces a valid album cover or starts a cover search. The selected mood persists so it is ready when a later source lacks artwork.

The photo fills the stage with a deliberate crop and restrained warmth, desaturation, vignette, or contrast overlay appropriate to the chosen theme. Text, transport controls, the scene selector, recovery actions, and record details sit on predictable readable regions. Readability must not depend on a particular photograph's accidental dark corner. The backdrop does not spin with the record, pulse with unmeasured audio, or invent track progress. Reduced Motion removes large photo transitions.

Record scene keeps the vinyl assembly and a source-icon/monogram label when no cover exists. Artwork scene keeps its upright square unavailable-cover sleeve with source identity and the primary recovery action. Neither places an unrelated mood photo on the record label or sleeve as if it were the album cover. A concise Mood background / Album cover unavailable state makes the distinction intelligible without unnecessary warnings.

Photo switching and appearance changes preserve record phase, source pin, playback controls, and fullscreen state. An absent or corrupt packaged photo falls back to the matching solid tonal atmosphere; it does not show a broken-image marker or trigger a network repair. Clear downloaded covers affects external artwork retention and leaves bundled atmosphere assets intact.

The photos and their presentation are interior resources of listening-interface, like its other fixed visual assets. Listener choice flows through listening-edit and listening-presentation and persists through intent-retention/retained-intent. No remote-photo service, new runtime node, or artwork-request side effect is introduced. Static resource checks, metadata/provenance checks, and pure priority/fallback fixtures are sufficient for this work unit's permitted verification. No live browser, application, audio, permission, or provider test is authorized.


## Explicit title-only artwork suggestions

The user has authorized a suggested cover even when artist or complete track metadata is missing. Suggest cover is therefore available for a selected source with a meaningful title hint. This is a separate matching policy from verified cover identification and supersedes earlier requirements that all cover requests need a known artist.

A hint may be the observed track title or a cleaned title from a known browser source. For example, Hit the Road Jack | YouTube Music can provide the search hint Hit the Road Jack after removing the recognized site suffix. Preserve the original source title and identify the cleaned value as a search hint; do not convert it into an observed track identity or infer an artist from it. Empty titles, generic site names, unknown process names, and unusable hints retain source/metadata recovery instead of issuing a broad meaningless query.

An eligible automatic lookup or explicit Find cover / Suggest cover action initiates the request. Native/page-supplied current artwork remains highest priority; a verified matched cover outranks a suggestion. When verified matching is unavailable or returns no usable cover, the authorized request may use the title-only policy. A new selected source can trigger the current automatic policy; missing artist alone does not bypass title-hint eligibility, debounce, cache priority, or cooldown.

The suggestion policy queries the existing MusicBrainz/Cover Art Archive providers by the cleaned title and examines at most three ranked candidates. A candidate must contain usable title identity and a known release with a valid accessible cover. Choose the first ranked candidate that satisfies those image/release requirements. This ranking is a recommendation mechanism, not proof that the playing recording is that release. All existing request, provider-rate, image-size, timeout, and cancellation limits continue to apply.

A displayed suggestion includes Suggested artwork and its candidate artist and album/release, with provider attribution and a link to the candidate release where available. The original player-reported title, artist, album, and source remain separate and unchanged. Missing candidate attribution is not invented. A suggested image may be used in the sleeve/record and atmospheric scene because that use is explicitly requested, but its visible and accessible suggestion label must remain discoverable in both Record and Artwork modes and fullscreen.

If no candidate yields a usable image, retain the chosen bundled mood atmosphere and report No suggested cover found. Provider errors remain errors rather than a false no-match. A suggestion must never silently replace a valid source-supplied or verified cover that arrives while the request is pending; source/track-generation checks and artwork priority are revalidated before display.

Suggestion cache entries use a namespace distinct from verified matching, keyed by normalized search hint, suggestion-policy generation and candidate provenance. They retain candidate title, artist/release, matching status, and expiry. A cached suggestion cannot satisfy a later verified-identity request, and a verified-policy miss cannot suppress a suggestion request. Successful suggestions use the existing seven-day lifetime; known suggestion misses use ten minutes; all images share the existing approximately 32 MB retention cap. Refresh and Clear downloaded covers apply with the same cancellation semantics.

This amendment changes the meaning carried by existing artwork request/observation/cache and listening-context relations without adding a node or relation kind. Fixture tests cover recognized suffix removal, unusable title rejection, three-candidate bounds, ranking-to-first-usable selection, separate attribution, immutable observed metadata, source-art priority, cache separation, and stale cancellation. READY is limited to static/fixture/build verification; no live browser, player, audio, provider, or permission testing is authorized.


## Audio-activity needle and interaction amendment

The needle remains the vinyl tonearm; no separate cassette mode is implied. Its pose follows a deterministic evidence order: fresh authoritative source playback state first, then fresh source-specific audio activity if playback state is absent or stale, then rest. Fresh explicit Pause or Stop outranks an older audible indicator. Activity from another tab, browser aggregate, or process cannot animate the selected source's needle.

The activity fallback uses the same selected-source identity and freshness boundary as the scene. Audio detected is the visible and accessible state when no reliable track playback state exists. It does not manufacture a title, elapsed time, duration, album, or assurance that routed output is audible. Upstream source activity can continue while the user mutes its route; show the route's mute state separately rather than pretending the player paused.

The active tonearm endpoint visibly intersects the groove area and the rest endpoint visibly clears the record. Retargeting begins from the current pose and does not reset on a metadata refresh. Reduced Motion selects the correct pose immediately. Source disappearance, expired activity, or session/document replacement removes the old evidence and returns the arm to rest unless the new selected source supplies fresh evidence.

Artwork sourcing remains an independent observable state: show whether source artwork is present, a cover lookup/suggestion is available, a request is pending in its current stage, a suggestion or verified result was obtained, or the request failed/found nothing. A spinning record or lowered needle is not evidence that an artwork lookup is running or successful. Primary artwork recovery remains reachable without a hidden menu.

Controls require clear hover/pointer feedback where appropriate, keyboard focus, and hit regions large enough to use reliably around the visible icon or label. Decorative record and tonearm surfaces must not look clickable when they provide no action. These interaction refinements remain internal to listening-interface and do not add a source-action relation.

Pure fixtures cover fresh playing, fresh paused with stale audio activity, missing metadata with fresh selected-source activity, stale activity, unrelated-source activity, source replacement, mute with upstream activity, and Reduced Motion. The graph is unchanged and READY for implementation. Static/fixture/build checks only; no live app, browser, audio, provider, or permission tests are authorized.


## Measured cover quality within fixed budgets

Explicit cover lookup and Refresh prefer a good-quality image of the already accepted front cover. Requested URL dimensions and provider labels are not evidence of actual resolution: inspect the decoded image dimensions. A returned image around 300 pixels wide is still a small image even when the request asked for 1200.

The desired prepared image has at least an 800-pixel short edge where the publisher provides it, with the longest edge capped at 1200 pixels. Preserve aspect ratio and never upscale. Assess useful dimensions after this preparation limit as well as the downloaded dimensions; a very tall narrow source is not automatically a high-quality square cover.

For the same approved front cover, consider available publisher-declared variants such as 1200, original, large, and 500, deduplicate their actual references, and try at most three distinct variants. Prefer the measured image that meets the desired quality with suitable bounded size; retain the best usable smaller version if none meets the target. Do not manufacture unadvertised high-resolution URLs or equate larger encoded bytes with better resolution.

Identity and candidate ordering remain higher priority than pixels. A title-only suggestion still examines the existing bounded ranked candidates until the first usable known release/cover is found; quality improvement then concerns variants of that cover. Do not choose a different artist, album, release, back cover, or unrelated image solely because it has more pixels. Source-supplied native/page artwork remains higher priority and is not modified by this external-cover preparation policy.

Each downloaded candidate image is limited to 2 MiB, and combined downloaded image payload for one lookup is limited to 6 MiB across candidates and variants. Enforce limits on actual received data rather than trusting a declared response size. Existing finite request/time/candidate and safe decode limits remain. Oversized, corrupt, or unusable variants may fail without discarding a smaller usable version already obtained.

External cached images are prepared as JPEG with a maximum 1200-pixel longest edge, no upscaling, and at most 1 MiB encoded size. Preserve useful resolution where possible while fitting the retained-image budget; if size constraints require a smaller preparation, record its actual final dimensions rather than reporting the source's dimensions. The existing aggregate approximately 32 MB cache budget and verified/suggested provenance separation remain.

Introduce a quality-policy generation in cache identity. A miss or quality decision from the old policy must not prevent an explicit new-policy Refresh. An existing valid lower-resolution cover remains visible on the same selected source until explicit Refresh supplies a better usable result, the source/track changes, or the listener clears covers. A policy update alone does not erase it, start a network request, or display a misleading loading state. Failed or lower-quality refresh leaves that usable image in place with the actual refresh outcome.

Pure fixtures validate declared-versus-actual dimensions, deduplication and three-variant bounds, preferred good-quality and best-smaller selection, preserved candidate identity, per-image/combined payload limits, maximum prepared edge and JPEG size, no upscaling, quality-policy cache invalidation, and retention of visible low-resolution art during failed refresh. This amendment is READY for static/fixture/build validation only; no live provider, browser, application, or audio testing is authorized.


## Automatic artwork and transient-provider recovery

Automatically find artwork is a persistent preference, initially enabled, exposed in the existing Vinyl options/customization surface. It authorizes cover queries only for the currently selected visible listening source. It does not enable native Automation, grant browser permissions, capture sound, or search the user's whole source list. Turning it off cancels scheduled and in-flight automatic work and leaves manual Find/Suggest/Refresh available.

An automatic lookup requires a valid source/track generation, usable observed title or eligible cleaned title hint, no usable source-provided artwork, and no fresh positive verified/suggested cache entry. Wait approximately 800 milliseconds after selection or metadata settles, coalescing repeated observations of the same lookup key. Only one selected-source request is active. Source changes, track changes, view closure, source-art arrival, or disabling automatic lookup cancels obsolete work; late results must still pass source-generation and priority checks.

After an automatic miss, ambiguity, or failed overall lookup, do not automatically request that same normalized track/hint and matching-policy key again for ten minutes. This cooldown prevents a frequently refreshed source from flooding a failing provider. Keep at most 256 recent automatic-attempt keys, discarding expired records before evicting the oldest retained attempts. This scheduling state is distinct from a cache assertion that artwork does not exist: failures retain their actual error state. A successful lookup uses the existing positive cache. Clear downloaded covers suppresses automatic refetch of the current key until its cooldown expires or the listener explicitly refreshes, so clearing does not immediately redownload it. Manual Refresh can bypass the automatic per-key cooldown, but cannot bypass provider rate limits or a future Retry-After deadline.

Keep any currently usable low-resolution or suggested cover visible during an explicit refresh. The new automatic policy does not require replacing it or seeking higher resolution in the background. Source-provided current artwork remains first priority, followed by fresh positive cached artwork, then newly obtained verified artwork or clearly attributed suggestions, then the bundled mood atmosphere.

Structured lookup uses the existing MusicBrainz/Cover Art Archive path, followed by the existing bounded rendered public-page fallback. No new catalog integration is added in this work unit. For a title-only request, a rendered candidate must publish an exactly normalized matching title, nonempty artist and album/release identity, and a safe usable image. The first eligible page candidate may supply Suggested artwork with that published artist and album visible. If the source supplies an artist or album, preserve the corresponding exact-match constraints. Page suggestions never become observed track metadata and do not change candidate identity solely to obtain more pixels.

Transient HTTP 429, 502, 503, and 504 responses permit at most one retry of the affected request within the existing overall request budget. Respect Retry-After in either seconds or date form. If it exceeds the short bounded in-request wait, defer that provider until its deadline instead of blocking Vinyl or retrying early; another eligible provider may continue. Without a usable Retry-After, use one short delayed retry. Provider backoff applies across external-cover requests to the same host, not only the individual candidate; it does not change direct source-supplied artwork behavior. No unbounded retry loop or automatic permission request is introduced.

The implementation defines and tests a finite inline retry-wait ceiling, at most five seconds, inside the existing total lookup timeout. Cancellation remains effective during that wait. A retried provider's failure does not overwrite an already usable cover. UI reports provider unavailable or retry deferred when relevant and presents progress through alternate sources without exposing raw transport codes as the only recovery explanation.

The existing quality and bandwidth contract remains: prefer actual prepared short edge of at least 800 pixels where available, longest edge at most 1200, no upscaling, at most three same-cover variants, 2 MiB per downloaded candidate image, 6 MiB combined image payload per lookup, and at most 1 MiB per cached JPEG. The 6 MiB budget spans all providers and retry image payloads in the same lookup, rather than restarting for every fallback. The approximately 32 MB retained-image cap and seven-day positives remain.

Matching/provider-policy generation includes rendered title-only suggestions so old policy misses do not prevent using the new fallback. Fresh positive cached artwork remains usable and is not erased solely because the policy changed. Current-source fields are immutable under suggested artwork, and attribution continues to identify the actual provider.

Fixture validation covers default-on preference decoding and persistence, 800-millisecond debounce, hidden-view suppression, source-art/cache priority, per-key ten-minute failure/miss cooldown, manual refresh versus provider backoff, seconds/date Retry-After, long defer, one-retry limit, structured-provider failure followed by rendered success, exact title/known-identity page matching, title-only attribution, cancellation, and a combined image budget across providers. READY after materialized contract/graph validation. No live provider, browser, application, audio, or permission tests are authorized; builds and pure/static fixtures only.

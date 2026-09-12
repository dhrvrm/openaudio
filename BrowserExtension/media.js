export function readPageMedia(operation = null) {
  const bounded = (value, limit = 256) => typeof value === "string" ? value.trim().slice(0, limit) : "";
  const metadata = navigator.mediaSession?.metadata;
  const nodes = document.querySelectorAll("audio,video");
  const elements = [];
  for (let index = 0; index < Math.min(nodes.length, 32); index++) elements.push(nodes[index]);
  const playingElements = elements.filter(value => !value.paused && !value.ended);
  const element = playingElements.length === 1 ? playingElements[0] : elements.length === 1 ? elements[0] : null;
  const bar = globalThis.location?.hostname === "music.youtube.com" ? document.querySelector("ytmusic-player-bar") : null;
  const enabled = node => !!node && !node.disabled && node.getAttribute("aria-disabled") !== "true" && node.getClientRects().length > 0;
  const next = bar?.querySelector(".next-button");
  const previous = bar?.querySelector(".previous-button");
  const commands = [];
  if (element && elements.length === 1) commands.push("playpause");
  if (enabled(next)) commands.push("next");
  if (enabled(previous)) commands.push("previous");
  if (operation !== null) {
    if (!["playpause", "next", "previous"].includes(operation) || !commands.includes(operation)) return {error: "This player no longer supports that control."};
    if (operation === "next") next.click();
    else if (operation === "previous") previous.click();
    else if (element.paused || element.ended) return Promise.resolve(element.play()).then(() => ({accepted: true}), () => ({error: "The page blocked playback. Open the tab and press Play."}));
    else element.pause();
    return {accepted: true};
  }
  let details = metadata;
  let provider = "Browser Media Session";
  if (bar) {
    const title = bounded(bar.querySelector(".title")?.textContent);
    const byline = bar.querySelectorAll(".byline a");
    const artist = bounded(byline[0]?.textContent);
    const album = bounded(byline[1]?.textContent);
    const cover = bar.querySelector("img");
    if (title && artist) {
      details = {title, artist, album, artwork: cover ? [{src: bounded(cover.currentSrc || cover.src, 2048), sizes: `${cover.naturalWidth || 0}x${cover.naturalHeight || 0}`}] : []};
      provider = "YouTube Music player";
    }
  }
  if (!details?.title) return null;
  return {title: bounded(details.title), artist: bounded(details.artist), album: bounded(details.album), artwork: details.artwork?.slice(0, 8).map(value => ({src: bounded(value.src, 2048), sizes: bounded(value.sizes, 64)})),
    playing: element ? !element.paused && !element.ended : navigator.mediaSession?.playbackState === "playing" ? true : navigator.mediaSession?.playbackState === "paused" ? false : null,
    position: element?.currentTime, duration: element?.duration, commands, provider};
}
export function normalizeMedia(raw, now = Date.now() / 1000) {
  if (!raw || typeof raw.title !== "string" || !raw.title.trim()) return null;
  const text = value => typeof value === "string" ? value.trim().slice(0, 256) : "";
  const artwork = (Array.isArray(raw.artwork) ? raw.artwork : []).slice(0, 8).filter(value => {
    try { const url = new URL(value.src); return value.src.length <= 2048 && url.protocol === "https:" && !url.username && !url.password; } catch { return false; }
  }).sort((a, b) => (parseInt(b.sizes) || 0) - (parseInt(a.sizes) || 0));
  const positive = value => typeof value === "number" && Number.isFinite(value) && value >= 0 && value < 1e8 ? value : null;
  return {title: text(raw.title), artist: text(raw.artist), album: text(raw.album), artworkURL: artwork[0]?.src || null,
    duration: positive(raw.duration), position: positive(raw.position), playing: typeof raw.playing === "boolean" ? raw.playing : null,
    updatedAt: now, commands: ["playpause", "next", "previous"].filter(value => Array.isArray(raw.commands) && raw.commands.includes(value)), provider: raw.provider === "YouTube Music player" ? raw.provider : "Browser Media Session"};
}

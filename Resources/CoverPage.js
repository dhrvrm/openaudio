(() => {
  const text = value => typeof value === "string" ? value.trim().slice(0, 512) : "";
  const items = [];
  let visited = 0;
  const name = value => typeof value === "string" ? text(value) : text(value?.name);
  const image = value => {
    const values = Array.isArray(value) ? value.slice(0, 8) : [value];
    return values.map(value => typeof value === "string" ? value : value?.url || value?.contentUrl).filter(value => typeof value === "string" && value.length <= 4096).slice(0, 8);
  };
  function walk(value, depth = 0) {
    if (!value || depth > 8 || visited++ > 200) return;
    if (Array.isArray(value)) { for (const item of value.slice(0, 40)) walk(item, depth + 1); return; }
    if (typeof value !== "object") return;
    const types = Array.isArray(value["@type"]) ? value["@type"] : [value["@type"]];
    if (types.includes("MusicRecording")) {
      const artists = Array.isArray(value.byArtist) ? value.byArtist : [value.byArtist];
      items.push({title: text(value.name), artist: artists.slice(0, 8).map(name).filter(Boolean).join(" ").slice(0, 512), album: name(value.inAlbum), images: image(value.image || value.inAlbum?.image)});
    }
    for (const key of ["@graph", "mainEntity", "itemListElement", "item", "track", "hasPart"]) if (key in value) walk(value[key], depth + 1);
  }
  const scripts = document.querySelectorAll('script[type="application/ld+json"]');
  for (let index = 0; index < Math.min(scripts.length, 12); index++) {
    const body = scripts[index].textContent;
    if (body.length > 200000) continue;
    try { walk(JSON.parse(body)); } catch {}
  }
  const links = [];
  const anchors = document.querySelectorAll("a[href]");
  for (let index = 0; index < Math.min(anchors.length, 200); index++) {
    try {
      let url = new URL(anchors[index].getAttribute("href"), location.href);
      if (url.hostname === "www.google.com" && url.pathname === "/url") url = new URL(url.searchParams.get("q") || url.searchParams.get("url"));
      if (url.protocol === "https:" && ["music.apple.com", "open.spotify.com"].includes(url.hostname) && url.href.length <= 2048) links.push(url.href);
    } catch {}
  }
  return JSON.stringify({items: items.slice(0, 20), links: [...new Set(links)].slice(0, 20)});
})()

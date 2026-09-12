import {boundedReport} from "./report.js";
import {readPageMedia, normalizeMedia} from "./media.js";
let creating, port, waiting, pumping, lastCommand;
let nativeError = "";
let catalog = [];
let requestOpenApp = false;
const mediaContexts = new Map();
const mediaGenerations = new Map();
let mediaRefresh = false;
let lastMediaRefresh = 0;
async function refreshMedia(tabs) {
  if (mediaRefresh || Date.now() - lastMediaRefresh < 2000) return;
  if (!lastCommand?.observeMedia || lastCommand.expires * 1000 < Date.now()) { mediaContexts.clear(); return; }
  mediaRefresh = true;
  lastMediaRefresh = Date.now();
  const queue = tabs.filter(tab => tab.audible || mediaContexts.has(tab.id) || catalog.some(item => item.id === tab.id && item.active));
  try {
    await Promise.all(Array.from({length: Math.min(4, queue.length)}, async () => {
      while (queue.length) {
        if (!lastCommand?.observeMedia || lastCommand.expires * 1000 < Date.now()) break;
        const tab = queue.shift();
        const generation = mediaGenerations.get(tab.id) || 0;
        try {
          let timer;
          const results = await Promise.race([
            chrome.scripting.executeScript({target: {tabId: tab.id}, world: "MAIN", func: readPageMedia}),
            new Promise((_, reject) => { timer = setTimeout(() => reject(new Error("Metadata timed out")), 1500); })
          ]).finally(() => clearTimeout(timer));
          if ((mediaGenerations.get(tab.id) || 0) !== generation || !lastCommand?.observeMedia || lastCommand.expires * 1000 < Date.now()) continue;
          const media = normalizeMedia(results[0]?.result);
          if (media) mediaContexts.set(tab.id, {media, document: results[0]?.documentId || String(generation)});
          else mediaContexts.delete(tab.id);
        } catch { if ((mediaGenerations.get(tab.id) || 0) === generation) mediaContexts.delete(tab.id); }
      }
    }));
  } finally { mediaRefresh = false; }
}
let operationAck = "";
let mediaOutcome = null;
let mediaOperationPending = false;
const activations = new Map();
const activationErrors = new Map();
const companion = chrome.storage.session.get(["companion", "operationAck"]).then(async value => {
  operationAck = value.operationAck || "";
  if (value.companion) return value.companion;
  const id = crypto.randomUUID();
  await chrome.storage.session.set({companion: id});
  return id;
});
async function offscreen() {
  if (await chrome.offscreen.hasDocument()) return;
  if (!creating) creating = chrome.offscreen.createDocument({url: "offscreen.html", reasons: ["USER_MEDIA"], justification: "Play explicitly activated tabs with independent volume and output."}).finally(() => { creating = null; });
  await creating;
}
async function audio(type, data = {}) {
  await offscreen();
  const reply = await chrome.runtime.sendMessage({target: "offscreen", type, ...data});
  if (!reply?.ok) throw new Error(reply?.error || "Tab playback companion is unavailable");
  return reply.value;
}
function connect() {
  if (port) return;
  port = chrome.runtime.connectNative("com.dhrvrm.openaudio");
  port.onMessage.addListener(command => { waiting?.resolve(command); waiting = null; nativeError = ""; });
  port.onDisconnect.addListener(() => {
    nativeError = chrome.runtime.lastError?.message || "OpenAudio bridge disconnected";
    port = null;
    waiting?.reject(new Error(nativeError)); waiting = null;
  });
}
async function exchange(report) {
  connect();
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => { waiting = null; port?.disconnect(); port = null; reject(new Error("OpenAudio bridge timed out")); }, 2000);
    waiting = {resolve: value => { clearTimeout(timer); resolve(value); }, reject: error => { clearTimeout(timer); reject(error); }};
    port.postMessage(report);
  });
}
function site(url) { try { return new URL(url).hostname.slice(0, 256); } catch { return ""; } }
async function pump() {
  if (pumping) return pumping;
  pumping = (async () => {
    const state = await audio("state");
    const routes = new Map(state.routes.map(route => [route.id, route]));
    const tabs = await chrome.tabs.query({});
    refreshMedia(tabs).catch(() => {});
    for (const id of mediaContexts.keys()) if (!tabs.some(tab => tab.id === id)) mediaContexts.delete(id);
    const previousIDs = catalog.map(tab => tab.id);
    catalog = tabs.filter(tab => tab.audible || mediaContexts.has(tab.id) || routes.has(tab.id) || state.errors[tab.id] || activationErrors.has(tab.id)).sort((a, b) => Number(routes.has(b.id)) - Number(routes.has(a.id))).slice(0, 200).map(tab => {
      const route = routes.get(tab.id);
      return {media: mediaContexts.get(tab.id)?.media, document: mediaContexts.get(tab.id)?.document, id: tab.id, title: (tab.title || "Untitled tab").slice(0, 512), site: site(tab.url), audible: !!tab.audible, active: !!route,
        status: activationErrors.get(tab.id) || state.errors[tab.id] || (route ? "Playing through OpenAudio" : "Activate OpenAudio in this tab"),
        peak: route?.peak || 0, settings: route?.settings || {volume: 1, muted: false, output: "default", release: false}, revision: route?.revision || 0};
    });
    for (const route of state.routes) if (!tabs.some(tab => tab.id === route.id)) await audio("stop", {id: route.id});
    let mediaBudget = 40000;
    for (const tab of catalog) {
      if (!tab.media) continue;
      const size = new TextEncoder().encode(JSON.stringify(tab.media)).length;
      if (size > mediaBudget) delete tab.media;
      else mediaBudget -= size;
    }
    const openApp = requestOpenApp;
    const command = await exchange(boundedReport({companion: await companion, openApp, acknowledgedOperation: operationAck, mediaOutcome, owns: state.owns, released: state.released, tabs: catalog, outputs: state.outputs, companionVersion: chrome.runtime.getManifest().version, devicesUpdatedAt: state.devicesUpdatedAt, deviceStatus: state.deviceStatus, deviceError: state.deviceError, error: nativeError}));
    if (openApp) requestOpenApp = false;
    lastCommand = command;
    await audio("command", {command});
    for (const id of previousIDs.filter(id => !catalog.some(tab => tab.id === id))) {
      chrome.action.setBadgeText({tabId: id, text: ""}).catch(() => {});
      chrome.action.setTitle({tabId: id, title: "Control this tab in OpenAudio"}).catch(() => {});
    }
    for (const tab of catalog) {
      const text = activationErrors.has(tab.id) || state.errors[tab.id] ? "!" : tab.active ? "ON" : "";
      chrome.action.setBadgeText({tabId: tab.id, text}).catch(() => {});
      chrome.action.setTitle({tabId: tab.id, title: text === "!" ? tab.status : tab.active ? "Controlled in OpenAudio · click to release" : "Control this tab in OpenAudio"}).catch(() => {});
    }
    const operation = command?.operation;
    if (operation && operation.id !== operationAck) {
      if (["playpause", "next", "previous"].includes(operation.action)) {
        if (!mediaOperationPending) performMediaOperation(operation, command).catch(() => {});
        return command;
      }
      if (operation.action === "setup") await chrome.runtime.openOptionsPage();
      else if (operation.action === "refresh") await audio("devices");
      else if (operation.action === "focus" && Number.isInteger(operation.tab)) {
        const tab = await chrome.tabs.update(operation.tab, {active: true}).catch(() => null);
        if (tab) await chrome.windows.update(tab.windowId, {focused: true});
      }
      await chrome.storage.session.set({operationAck: operation.id});
      operationAck = operation.id;
    }
    return command;
  })().catch(error => { nativeError = error.message; throw error; }).finally(() => { pumping = null; });
  return pumping;
}
async function performMediaOperation(operation, command) {
  mediaOperationPending = true;
  try {
    const companionID = await companion;
    operationAck = operation.id;
    mediaOutcome = {id: operation.id, pending: true};
    await chrome.storage.session.set({operationAck});
    const current = mediaContexts.get(operation.tab);
    if (lastCommand?.session !== command.session || lastCommand?.authority !== command.authority || !lastCommand?.observeMedia || lastCommand.expires * 1000 < Date.now() || command.session !== companionID || !command.observeMedia || command.expires * 1000 < Date.now() || !operation.document || current?.document !== operation.document || Date.now() / 1000 - current.media.updatedAt >= 8 || !current.media.commands?.includes(operation.action)) throw new Error("The tab changed. Wait for current track details.");
    let timer;
    const results = await Promise.race([
      chrome.scripting.executeScript({target: {tabId: operation.tab, documentIds: [operation.document]}, world: "MAIN", func: readPageMedia, args: [operation.action]}),
      new Promise((_, reject) => { timer = setTimeout(() => reject(new Error("The player did not respond. Check the tab before trying again.")), 1800); })
    ]).finally(() => clearTimeout(timer));
    if (results[0]?.documentId !== operation.document || mediaContexts.get(operation.tab)?.document !== operation.document) throw new Error("The tab navigated while the command was pending.");
    if (results[0]?.result?.accepted !== true) throw new Error(results[0]?.result?.error || "The player could not accept this command.");
    mediaOutcome = {id: operation.id, pending: false};
    lastMediaRefresh = 0;
  } catch (error) { mediaOutcome = {id: operation.id, pending: false, error: String(error.message).slice(0, 256)}; }
  finally { mediaOperationPending = false; }
}
chrome.runtime.onMessage.addListener((message, sender, respond) => {
  if (message.target !== "worker" || sender.id !== chrome.runtime.id) return;
  (async () => {
    if (message.type === "pulse") { await pump(); return {}; }
    if (message.type === "status") { await pump().catch(() => {}); return {error: nativeError, tabs: catalog, connected: !!lastCommand, enabled: !!lastCommand?.allow}; }
    if (message.type === "devices") return audio("devices");
    if (message.type === "start") { await activateTab(message.id); return {}; }
    if (message.type === "stop") { await audio("stop", {id: message.id}); await pump(); return {}; }
  })().then(value => respond({ok: true, value}), error => respond({ok: false, error: error.message}));
  return true;
});
chrome.tabs.onRemoved.addListener(id => { mediaContexts.delete(id); mediaGenerations.set(id, (mediaGenerations.get(id) || 0) + 1); activationErrors.delete(id); audio("stop", {id}).then(pump).catch(() => {}); });

async function activateTab(id) {
  if (activations.has(id)) return activations.get(id);
  const activation = (async () => {
    activationErrors.delete(id);
    requestOpenApp = true;
    await audio("reserve");
    try {
      const deadline = Date.now() + 6000;
      do {
        await pump();
        if (lastCommand?.allow && lastCommand.expires * 1000 > Date.now()) break;
        await new Promise(resolve => setTimeout(resolve, 100));
      } while (Date.now() < deadline);
      if (!lastCommand?.allow) throw new Error("Enable audio control in OpenAudio, then click the toolbar button again");
      const streamId = await chrome.tabCapture.getMediaStreamId({targetTabId: id});
      await audio("start", {id, streamId});
      await pump();
    } catch (error) {
      activationErrors.set(id, error.message);
      await audio("cancel");
      await pump().catch(() => {});
      throw error;
    }
  })().finally(() => { activations.delete(id); });
  activations.set(id, activation);
  return activation;
}
chrome.action.onClicked.addListener(async tab => {
  if (!Number.isInteger(tab.id)) return;
  try {
    const state = await audio("state");
    if (state.routes.some(route => route.id === tab.id)) {
      await audio("stop", {id: tab.id});
      await pump();
    } else { await activateTab(tab.id); }
  } catch (error) {
    await chrome.action.setBadgeText({tabId: tab.id, text: "!"}).catch(() => {});
    await chrome.action.setTitle({tabId: tab.id, title: error.message}).catch(() => {});
    await chrome.runtime.openOptionsPage().catch(() => {});
  }
});
chrome.runtime.onInstalled.addListener(() => pump().catch(() => {}));

chrome.tabs.onUpdated.addListener((id, changes) => {
  if (changes.url || changes.status === "loading") { mediaContexts.delete(id); mediaGenerations.set(id, (mediaGenerations.get(id) || 0) + 1); }
  if (["audible", "status", "title", "url"].some(key => key in changes)) pump().catch(() => {});
});
chrome.tabs.onCreated.addListener(() => pump().catch(() => {}));
chrome.runtime.onStartup.addListener(() => pump().catch(() => {}));

import {TabEngine} from "./engine.js";
import {readDeviceCatalog} from "./device-catalog.js";
const engine = new TabEngine();
let applying = Promise.resolve();
let outputs = [];
let deviceStatus = "checking";
let deviceError = "";
let refreshing;
let devicesUpdatedAt = 0;
async function devices() {
  if (refreshing) return refreshing;
  refreshing = (async () => {
    try {
      const catalog = await readDeviceCatalog(navigator.mediaDevices, navigator.permissions);
      outputs = catalog.outputs;
      devicesUpdatedAt = Date.now();
      deviceStatus = catalog.status;
      deviceError = "";
      const available = new Set(outputs.map(output => output.id));
      for (const [id, route] of engine.routes) {
        if (route.settings.output !== "default" && !available.has(route.settings.output)) await engine.stop(id, "Output unavailable · ordinary browser playback restored");
      }
    } catch (error) {
      deviceStatus = "error";
      deviceError = `Could not refresh output devices: ${error.message}`;
    }
  })().finally(() => { refreshing = null; });
  return refreshing;
}
function peak(route) {
  if (!route.meter) return 0;
  route.meter.getFloatTimeDomainData(route.samples);
  return route.samples.reduce((maximum, sample) => Math.max(maximum, Math.abs(sample)), 0);
}
function state() {
  return {owns: engine.owns, released: engine.released, routes: [...engine.routes].map(([id, route]) => ({id, settings: route.settings, revision: route.revision, peak: peak(route)})), errors: Object.fromEntries(engine.errors), outputs, deviceStatus, deviceError, devicesUpdatedAt};
}
chrome.runtime.onMessage.addListener((message, sender, respond) => {
  if (message.target !== "offscreen" || sender.id !== chrome.runtime.id) return;
  (async () => {
    if (message.type === "state") return state();
    if (message.type === "reserve") { engine.reserve(); return state(); }
    if (message.type === "cancel") { engine.cancelReservation(); return state(); }
    if (message.type === "devices") { await devices(); return state(); }
    if (message.type === "start") { await engine.start(message.id, message.streamId); return state(); }
    if (message.type === "stop") { await engine.stop(message.id); return state(); }
    if (message.type === "command") {
      if (message.command && !message.command.allow && (engine.pending > 0 || engine.routes.size > 0)) await engine.stopAll();
      applying = applying.catch(() => {}).then(() => engine.apply(message.command));
      await applying;
      return state();
    }
  })().then(value => respond({ok: true, value}), error => respond({ok: false, error: error.message}));
  return true;
});
setInterval(() => {
  engine.tick().catch(() => {});
  for (const [id, route] of engine.routes) {
    if (route.context.state !== "running" && !route.switching) engine.stop(id, "Browser audio interrupted · activate this tab again").catch(() => {});
  }
  chrome.runtime.sendMessage({target: "worker", type: "pulse"}).catch(() => {});
}, 125);
navigator.mediaDevices.addEventListener("devicechange", () => devices().catch(() => {}));
devices().catch(() => {});

setInterval(() => devices(), 2000);
navigator.permissions.query({name: "microphone"}).then(permission => {
  permission.addEventListener("change", () => devices());
}).catch(() => {});

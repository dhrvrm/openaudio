const status = document.querySelector("#status");
const start = document.querySelector("#start");
const stop = document.querySelector("#stop");
let tab;
async function send(type) {
  const result = await chrome.runtime.sendMessage({target: "worker", type, id: tab.id});
  if (!result?.ok) throw new Error(result?.error || "OpenAudio is unavailable");
  return result.value;
}
async function refresh() {
  [tab] = await chrome.tabs.query({active: true, currentWindow: true});
  document.querySelector("#title").textContent = tab?.title || "This tab";
  const state = await send("status");
  const active = state.tabs.find(item => item.id === tab.id)?.active;
  start.hidden = !!active;
  stop.hidden = !active;
  status.textContent = state.error || (active ? "This tab is controlled independently." : "Activate this tab to give it its own audio controls.");
}
for (const [button, action] of [[start, "start"], [stop, "stop"]]) {
  button.addEventListener("click", async () => {
    button.disabled = true;
    status.textContent = action === "start" ? "Preparing tab audio…" : "Restoring browser playback…";
    try { await send(action); await refresh(); }
    catch (error) { status.textContent = error.message; }
    finally { button.disabled = false; }
  });
}
refresh().catch(error => { status.textContent = error.message; });

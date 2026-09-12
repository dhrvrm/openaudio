document.querySelector("#enable").addEventListener("click", async () => {
  const status = document.querySelector("#status");
  let stream;
  try {
    stream = await navigator.mediaDevices.getUserMedia({audio: true, video: false});
    stream.getTracks().forEach(track => track.stop());
    const reply = await chrome.runtime.sendMessage({target: "worker", type: "devices"});
    if (!reply?.ok) throw new Error(reply?.error || "Could not refresh devices");
    if (reply.value?.deviceStatus === "error") throw new Error(reply.value.deviceError || "Device refresh failed");
    const outputs = reply.value?.outputs || [];
    status.textContent = outputs.length ? `Access granted. Outputs: ${outputs.map(output => output.label).join(", ")}. Return to OpenAudio to choose one.` : "Access was granted, but this browser has not exposed named outputs yet. Check macOS microphone permission for this browser, then refresh devices.";
  } catch (error) { status.textContent = `${error.message}. System default remains available.`; }
  finally { stream?.getTracks().forEach(track => track.stop()); }
});
chrome.runtime.sendMessage({target: "worker", type: "status"}).then(reply => {
  const state = reply?.value;
  document.querySelector("#connection").textContent = state?.error || (state?.connected ? "Connected to OpenAudio." : "Open the OpenAudio app to connect.");
}).catch(error => { document.querySelector("#connection").textContent = error.message; });

document.querySelector("#refresh").addEventListener("click", async () => {
  const status = document.querySelector("#status");
  try {
    const reply = await chrome.runtime.sendMessage({target: "worker", type: "devices"});
    if (!reply?.ok) throw new Error(reply?.error || "Device refresh failed");
    if (reply.value?.deviceStatus === "error") throw new Error(reply.value.deviceError || "Device refresh failed");
    const outputs = reply.value?.outputs || [];
    status.textContent = outputs.length ? `Available: ${outputs.map(output => output.label).join(", ")}` : "No named outputs exposed. Allow device discovery above to make additional speakers available.";
  } catch (error) { status.textContent = error.message; }
});

const mediaOrigins = ["https://*/*", "http://*/*"];
async function showMetadataAccess() {
  const granted = await chrome.permissions.contains({origins: mediaOrigins});
  document.querySelector("#metadata-status").textContent = granted ? "Website metadata access is enabled. Open Vinyl in OpenAudio to read playing tabs." : "Website metadata access is off. Toolbar-approved tabs may still share details.";
}
document.querySelector("#metadata").addEventListener("click", async () => {
  try { await chrome.permissions.request({origins: mediaOrigins}); await showMetadataAccess(); }
  catch (error) { document.querySelector("#metadata-status").textContent = error.message; }
});
document.querySelector("#revoke-metadata").addEventListener("click", async () => {
  try { await chrome.permissions.remove({origins: mediaOrigins}); await showMetadataAccess(); }
  catch (error) { document.querySelector("#metadata-status").textContent = error.message; }
});
showMetadataAccess().catch(() => {});

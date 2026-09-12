export function outputDevices(devices) {
  const seen = new Set();
  return devices.filter(device => device.kind === "audiooutput" && device.deviceId && !["default", "communications"].includes(device.deviceId) && !seen.has(device.deviceId) && seen.add(device.deviceId))
    .map(device => ({id: device.deviceId, label: device.label?.trim() || "Unnamed output (name unavailable)"}));
}
export async function readDeviceCatalog(media, permissions) {
  let permission = "prompt";
  try { permission = (await permissions.query({name: "microphone"})).state; } catch {}
  const devices = await media.enumerateDevices();
  const outputs = outputDevices(devices);
  return {outputs, status: permission === "denied" ? "denied" : outputs.some(output => !output.label.startsWith("Unnamed output")) ? "ready" : permission === "granted" ? "unavailable" : "permission-required"};
}

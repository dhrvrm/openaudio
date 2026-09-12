const encoder = new TextEncoder();
export function bytes(value) { return encoder.encode(JSON.stringify(value)).length; }
function text(value, limit) {
  const string = String(value ?? "");
  const data = encoder.encode(string);
  if (data.length <= limit) return string;
  let end = limit;
  while (end > 0 && (data[end] & 0xC0) === 0x80) end--;
  return new TextDecoder().decode(data.subarray(0, end));
}
export function boundedReport(input, limit = 250000) {
  if (bytes(input) <= limit) return input;
  const report = {...input, error: text(input.error, 512), deviceError: text(input.deviceError, 512), tabs: input.tabs.map(tab => ({...tab, title: text(tab.title, 192), status: text(tab.status, 192), site: text(tab.site, 128)})), outputs: input.outputs.map(output => ({...output, label: text(output.label, 192)}))};
  if (bytes(report) <= limit) return report;
  for (const tab of report.tabs) delete tab.media;
  if (bytes(report) <= limit) return report;
  const passive = report.tabs.filter(tab => !tab.active);
  for (const tab of passive.reverse()) {
    report.tabs = report.tabs.filter(value => value.id !== tab.id);
    if (bytes(report) <= limit) return report;
  }
  const chosen = new Set(report.tabs.map(tab => tab.settings.output));
  report.outputs = report.outputs.filter(output => chosen.has(output.id));
  for (const tab of report.tabs) { tab.title = ""; tab.status = ""; tab.site = ""; }
  if (bytes(report) > limit) throw new Error("Active tab report exceeds the supported bridge size");
  return report;
}

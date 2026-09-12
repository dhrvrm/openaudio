import test from 'node:test';
import assert from 'node:assert/strict';
import {outputDevices, readDeviceCatalog} from '../BrowserExtension/device-catalog.js';
const output = (id, label) => ({kind: 'audiooutput', deviceId: id, label});
test('anonymous default devices never become a misleading selectable output', () => {
  assert.deepEqual(outputDevices([output('', ''), output('default', 'Default'), output('communications', 'Communications')]), []);
});
test('granting access exposes TUFTON on the next refresh', async () => {
  let granted = false;
  const media = {enumerateDevices: async () => granted ? [output('speaker', 'MacBook Air Speakers'), output('tufton-browser-id', 'TUFTON')] : [output('', '')]};
  const permissions = {query: async () => ({state: granted ? 'granted' : 'prompt'})};
  assert.equal((await readDeviceCatalog(media, permissions)).status, 'permission-required');
  granted = true;
  const result = await readDeviceCatalog(media, permissions);
  assert.equal(result.status, 'ready');
  assert.deepEqual(result.outputs.map(device => device.label), ['MacBook Air Speakers', 'TUFTON']);
});
test('newly connected and removed outputs are reflected without restart', async () => {
  let current = [output('speaker', 'Speakers')];
  const media = {enumerateDevices: async () => current};
  const permissions = {query: async () => ({state: 'granted'})};
  assert.equal((await readDeviceCatalog(media, permissions)).outputs.length, 1);
  current.push(output('tufton', 'TUFTON'));
  assert.equal((await readDeviceCatalog(media, permissions)).outputs.length, 2);
  current = [output('tufton', 'TUFTON')];
  assert.deepEqual((await readDeviceCatalog(media, permissions)).outputs.map(device => device.id), ['tufton']);
});
test('denial is explicit and duplicate device IDs are removed', async () => {
  const result = await readDeviceCatalog({enumerateDevices: async () => []}, {query: async () => ({state: 'denied'})});
  assert.equal(result.status, 'denied');
  assert.equal(outputDevices([output('a', 'Speaker'), output('a', 'Speaker')]).length, 1);
});

test('unnamed device identity survives label redaction', () => {
  assert.deepEqual(outputDevices([output('speaker', '')]), [{id: 'speaker', label: 'Unnamed output (name unavailable)'}]);
});
test('granted access with no outputs is unavailable', async () => {
  assert.equal((await readDeviceCatalog({enumerateDevices: async () => []}, {query: async () => ({state: 'granted'})})).status, 'unavailable');
});

import test from 'node:test';
import assert from 'node:assert/strict';
import {TabEngine} from '../BrowserExtension/engine.js';
class Context {
  sinkId = ''; state = 'running'; currentTime = 0; destination = {};
  createMediaStreamSource() { return {connect: node => node, disconnect() {}}; }
  createGain() { return {gain: {value: 0, setTargetAtTime(value) { this.value = value; }}, connect() {}, disconnect() {}}; }
  async setSinkId(id) { if (id === 'missing') throw new Error('removed'); this.sinkId = id; }
  async resume() {}
  async close() { this.state = 'closed'; }
}
function fixture(media) {
  let clock = 1000;
  const tracks = [];
  const engine = new TabEngine({Context, now: () => clock, media: media || {async getUserMedia() {
    const track = {stopped: false, stop() { this.stopped = true; }, addEventListener() {}};
    tracks.push(track); return {getTracks: () => [track]};
  }}});
  const command = {session: 'session', authority: 'authority', revision: 1, expires: 6, allow: true, tabs: {
    1: {volume: .5, muted: false, output: 'speakers'}, 2: {volume: .8, muted: false, output: 'headphones'}
  }};
  return {engine, command, tracks, advance: value => { clock = value; }};
}
test('independent tab gains, mute, and sinks', async () => {
  const {engine, command} = fixture();
  await engine.apply(command); await engine.start(1, 'first'); await engine.start(2, 'second');
  assert.equal(engine.routes.get(1).gain.gain.value, .5);
  assert.equal(engine.routes.get(2).context.sinkId, 'headphones');
  await engine.apply({...command, revision: 2, tabs: {...command.tabs, 1: {...command.tabs[1], muted: true, output: 'headphones'}}});
  assert.equal(engine.routes.get(1).gain.gain.value, 0);
  assert.equal(engine.routes.get(2).gain.gain.value, .8);
  assert.equal(engine.routes.get(2).context.sinkId, 'headphones');
});
test('sink failure restores only affected tab', async () => {
  const {engine, command, tracks} = fixture();
  await engine.apply(command); await engine.start(1, 'first'); await engine.start(2, 'second');
  await engine.apply({...command, revision: 2, tabs: {...command.tabs, 1: {...command.tabs[1], output: 'missing'}}});
  assert.equal(engine.routes.has(1), false); assert.equal(tracks[0].stopped, true);
  assert.equal(engine.routes.has(2), true); assert.equal(tracks[1].stopped, false);
});
test('lease expiry releases every stream without worker participation', async () => {
  const {engine, command, tracks, advance} = fixture();
  await engine.apply(command); await engine.start(1, 'first'); await engine.start(2, 'second');
  advance(7000); await engine.tick();
  assert.equal(engine.owns, false); assert.ok(tracks.every(track => track.stopped));
  assert.equal(engine.released, 'authority');
});
test('older revisions cannot overwrite newer controls', async () => {
  const {engine, command} = fixture();
  await engine.apply(command); await engine.start(1, 'first');
  await engine.apply({...command, revision: 3, tabs: {1: {...command.tabs[1], volume: .1}}});
  await engine.apply({...command, revision: 2});
  assert.equal(engine.routes.get(1).gain.gain.value, .1);
});
test('release during getUserMedia cannot create a late playing stream', async () => {
  let resolve;
  const track = {stopped: false, stop() { this.stopped = true; }, addEventListener() {}};
  const {engine, command} = fixture({getUserMedia: () => new Promise(done => { resolve = done; })});
  await engine.apply(command);
  const starting = engine.start(1, 'first');
  await engine.apply({...command, revision: 2, allow: false});
  assert.equal(engine.owns, true);
  resolve({getTracks: () => [track]});
  await assert.rejects(starting, /cancelled/);
  assert.equal(engine.owns, false); assert.equal(track.stopped, true);
  assert.equal(engine.released, 'authority');
});
test('initial reservation survives mailbox latency but expires', async () => {
  const {engine, command, advance} = fixture();
  engine.reserve(); await engine.apply(null); await engine.tick();
  assert.equal(engine.owns, true);
  await engine.apply({...command, allow: false});
  assert.equal(engine.owns, true);
  await engine.apply({...command, revision: 2});
  await engine.start(1, 'first'); assert.equal(engine.routes.size, 1);
  await engine.stopAll(); engine.reserve(); advance(8000); await engine.tick(); assert.equal(engine.owns, false);
});
test('stopping one pending tab cancels its late start', async () => {
  let resolve;
  const track = {stopped: false, stop() { this.stopped = true; }, addEventListener() {}};
  const {engine, command} = fixture({getUserMedia: () => new Promise(done => { resolve = done; })});
  await engine.apply(command);
  const starting = engine.start(1, 'first');
  await engine.start(1, 'duplicate');
  assert.equal(engine.pending, 1);
  await engine.stop(1);
  resolve({getTracks: () => [track]});
  await assert.rejects(starting, /cancelled/);
  assert.equal(engine.owns, false); assert.equal(track.stopped, true);
});
test('lease expiry stops acquired tracks even when sink setup stalls', async () => {
  const {engine, command, tracks, advance} = fixture();
  let resolve;
  engine.Context = class extends Context { setSinkId() { return new Promise(done => { resolve = done; }); } };
  await engine.apply(command);
  const starting = engine.start(1, 'first');
  await new Promise(done => setImmediate(done));
  advance(7000); await engine.tick();
  assert.equal(tracks[0].stopped, true);
  resolve(); await assert.rejects(starting);
  assert.equal(engine.owns, false);
});
test('startup applies the newest revision before acknowledging it', async () => {
  const {engine, command} = fixture();
  let resolve;
  engine.Context = class extends Context { async setSinkId(id) { this.sinkId = id; await new Promise(done => { resolve = done; }); } };
  await engine.apply(command);
  const starting = engine.start(1, 'first');
  await new Promise(done => setImmediate(done));
  await engine.apply({...command, revision: 2, tabs: {...command.tabs, 1: {...command.tabs[1], volume: .1}}});
  resolve(); await starting;
  assert.equal(engine.routes.get(1).gain.gain.value, .1);
  assert.equal(engine.routes.get(1).revision, 2);
});
test('a failed old sink operation cannot stop a replacement route', async () => {
  const {engine, command, tracks} = fixture();
  await engine.apply(command); await engine.start(1, 'first');
  let reject;
  engine.routes.get(1).context.setSinkId = () => new Promise((_, fail) => { reject = fail; });
  const applying = engine.apply({...command, revision: 2, tabs: {1: {...command.tabs[1], output: 'headphones'}}});
  await engine.stop(1);
  await engine.start(1, 'replacement');
  reject(new Error('old switch failed')); await applying;
  assert.equal(engine.routes.has(1), true);
  assert.equal(tracks[1].stopped, false);
});

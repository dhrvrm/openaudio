import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import {readFileSync} from 'node:fs';
const worker = readFileSync(new URL('../BrowserExtension/worker.js', import.meta.url), 'utf8').replace(/^import .*;$/gm, '');
function fixture(execute = async request => [{documentId: request.target.documentIds[0], result: {accepted: true}}]) {
  const event = {addListener() {}};
  const requests = [];
  const context = vm.createContext({setTimeout, clearTimeout, URL, TextEncoder, crypto: {randomUUID: () => 'session'}, readPageMedia() {}, chrome: {
    storage: {session: {get: async () => ({companion: 'session'}), set: async () => {}}},
    scripting: {executeScript: async request => { requests.push(request); return execute(request); }},
    runtime: {onMessage: event, onInstalled: event, onStartup: event},
    tabs: {onRemoved: event, onUpdated: event, onCreated: event}, action: {onClicked: event}
  }});
  vm.runInContext(worker + '\nglobalThis.harness = {performMediaOperation, mediaContexts, authorize: value => { lastCommand = value; }, outcome: () => mediaOutcome, ack: () => operationAck};', context);
  const harness = context.harness;
  harness.mediaContexts.set(7, {document: 'doc-A', media: {updatedAt: Date.now() / 1000, commands: ['next']}});
  harness.authorize({session: "session", authority: "owner", observeMedia: true, expires: Date.now() / 1000 + 5});
  return {harness, requests, operation: {id: 'command-1', tab: 7, document: 'doc-A', action: 'next'}, command: {session: 'session', authority: 'owner', observeMedia: true, expires: Date.now() / 1000 + 5}};
}
test('transport targets the exact document and acknowledges without claiming observed playback', async () => {
  const f = fixture();
  await f.harness.performMediaOperation(f.operation, f.command);
  assert.equal(f.requests.length, 1);
  assert.deepEqual(Array.from(f.requests[0].target.documentIds), ['doc-A']);
  assert.equal(f.requests[0].target.tabId, 7);
  assert.equal(f.harness.ack(), 'command-1');
  assert.equal(f.harness.outcome().pending, false);
  assert.equal(f.harness.outcome().playing, undefined);
});
test('navigation, expired access, stale metadata and unsupported actions fail before injection', async () => {
  for (const kind of ['navigation', 'expired', 'stale', 'unsupported', 'session', 'permission']) {
    const f = fixture();
    if (kind === 'navigation') f.operation.document = 'doc-B';
    if (kind === 'expired') f.command.expires = 0;
    if (kind === 'stale') f.harness.mediaContexts.get(7).media.updatedAt = 0;
    if (kind === 'unsupported') f.operation.action = 'previous';
    if (kind === 'session') f.command.session = 'replacement';
    if (kind === 'permission') f.command.observeMedia = false;
    await f.harness.performMediaOperation(f.operation, f.command);
    assert.equal(f.requests.length, 0, kind);
    assert.ok(f.harness.outcome().error, kind);
  }
});
test('permission failure is a media outcome and cannot throw into the audio lease pump', async () => {
  const f = fixture(async () => { throw new Error('Cannot access this page'); });
  await f.harness.performMediaOperation(f.operation, f.command);
  assert.match(f.harness.outcome().error, /Cannot access/);
});
test('navigation during an in-flight action does not report successful delivery', async () => {
  let release;
  const f = fixture(() => new Promise(resolve => { release = resolve; }));
  const pending = f.harness.performMediaOperation(f.operation, f.command);
  while (!release) await new Promise(resolve => setTimeout(resolve, 0));
  f.harness.mediaContexts.delete(7);
  release([{documentId: 'doc-A', result: {accepted: true}}]);
  await pending;
  assert.match(f.harness.outcome().error, /navigated/);
});

test('latest authority or visibility revocation blocks a queued command', async () => {
  const f = fixture();
  f.harness.authorize({session: 'session', authority: 'replacement', observeMedia: false, expires: Date.now() / 1000 + 5});
  await f.harness.performMediaOperation(f.operation, f.command);
  assert.equal(f.requests.length, 0);
  assert.ok(f.harness.outcome().error);
});

import {boundedReport, bytes} from '../BrowserExtension/report.js';
import test from 'node:test';
import assert from 'node:assert/strict';
import {normalizeMedia, readPageMedia} from '../BrowserExtension/media.js';
test('missing page metadata is not replaced with a guessed tab title', () => {
  assert.equal(normalizeMedia(null), null);
  assert.equal(normalizeMedia({title: ''}), null);
});
test('page metadata selects a larger HTTPS image and preserves source timing', () => {
  const result = normalizeMedia({title: ' Song ', artist: 'Artist', album: 'Album', artwork: [{src: 'https://example.com/s.jpg', sizes: '100x100'}, {src: 'https://example.com/l.jpg', sizes: '1200x1200'}], playing: false, duration: 200, position: 50}, 100);
  assert.equal(result.artworkURL, 'https://example.com/l.jpg');
  assert.equal(result.playing, false);
  assert.equal(result.updatedAt, 100);
  assert.equal(result.title, 'Song');
});
test('unsafe artwork and unbounded timing are discarded', () => {
  const result = normalizeMedia({title: 'x'.repeat(5000), artist: {}, duration: Infinity, position: -5, artwork: [{src: 'file:///secret'}, {src: 'http://example.com/a.jpg'}, {src: 'https://user:password@example.com/a'}]});
  assert.equal(result.title.length, 256);
  assert.equal(result.artist, '');
  assert.equal(result.position, null);
  assert.equal(result.duration, null);
  assert.equal(result.artworkURL, null);
});
test('changing tracks cannot retain the previous track artwork', () => {
  const first = normalizeMedia({title: 'First', artwork: [{src: 'https://example.com/first.jpg'}]});
  const second = normalizeMedia({title: 'Second'});
  assert.notEqual(first.title, second.title);
  assert.equal(second.artworkURL, null);
});
test('read-only Media Session extraction handles WebAudio without a media element', () => {
  Object.defineProperty(globalThis, 'navigator', {value: {mediaSession: {metadata: {title: 'Track', artist: 'A', artwork: []}, playbackState: 'playing'}}, configurable: true});
  globalThis.document = {querySelectorAll: () => []};
  assert.equal(readPageMedia().playing, true);
  assert.equal(normalizeMedia(readPageMedia()).position, null);
});

test('injected reader bounds page data before it crosses the scripting boundary', () => {
  Object.defineProperty(globalThis, 'navigator', {value: {mediaSession: {metadata: {title: 'x'.repeat(100000), artist: 'y'.repeat(100000), album: 'z'.repeat(100000), artwork: [{src: 'a'.repeat(100000), sizes: 'b'.repeat(10000)}]}}}, configurable: true});
  globalThis.document = {querySelectorAll: () => []};
  const raw = readPageMedia();
  assert.equal(raw.title.length, 256);
  assert.equal(raw.artwork[0].src.length, 2048);
  assert.equal(raw.artwork[0].sizes.length, 64);
});

test('large Unicode catalogs preserve active routes and fit the complete mailbox budget', () => {
  const tabs = Array.from({length: 200}, (_, id) => ({id, title: '音'.repeat(512), site: 'a'.repeat(256), status: '音'.repeat(512), active: true, settings: {volume: 1, muted: false, output: 'default', release: false}, media: {title: '音'.repeat(256), artist: 'a', artworkURL: 'https://example.com/' + 'a'.repeat(2048)}}));
  const report = boundedReport({tabs, outputs: [], owns: true, released: '', error: '', deviceError: ''});
  assert.ok(bytes(report) <= 250000);
  assert.equal(report.owns, true);
  assert.deepEqual(report.tabs.map(tab => tab.id), tabs.map(tab => tab.id));
  assert.ok(report.tabs.every(tab => tab.active && tab.settings.volume === 1));
});

test('YouTube Music current player supplies metadata without Media Session', () => {
  Object.defineProperty(globalThis, 'navigator', {value: {}, configurable: true});
  globalThis.location = {hostname: 'music.youtube.com'};
  const player = {paused: false, ended: false, currentTime: 12, duration: 180};
  const button = {disabled: false, getAttribute: () => null, getClientRects: () => [1]};
  const bar = {
    querySelector: selector => ({'.title': {textContent: 'Actual song'}, 'img': {currentSrc: 'https://example.com/cover.jpg', naturalWidth: 600, naturalHeight: 600}, '.next-button': button, '.previous-button': {...button, disabled: true}})[selector],
    querySelectorAll: () => [{textContent: 'Actual artist'}, {textContent: 'Actual album'}]
  };
  globalThis.document = {querySelector: () => bar, querySelectorAll: () => [player]};
  const media = normalizeMedia(readPageMedia());
  assert.equal(media.title, 'Actual song');
  assert.equal(media.artist, 'Actual artist');
  assert.equal(media.provider, 'YouTube Music player');
  assert.deepEqual(media.commands, ['playpause', 'next']);
});
test('generic multiple players cannot advertise ambiguous playback controls', () => {
  globalThis.location = {hostname: 'example.com'};
  Object.defineProperty(globalThis, 'navigator', {value: {mediaSession: {metadata: {title: 'Song'}}}, configurable: true});
  globalThis.document = {querySelectorAll: () => [{paused: true}, {paused: false}]};
  assert.deepEqual(readPageMedia().commands, []);
  assert.ok(readPageMedia('playpause').error);
  assert.ok(readPageMedia('arbitrary code').error);
});
test('single-player play rejection is surfaced and pause acts only once', async () => {
  let pauses = 0;
  const player = {paused: true, ended: false, play: () => Promise.reject(new Error('blocked')), pause: () => { pauses++; }};
  globalThis.document = {querySelectorAll: () => [player]};
  assert.match((await readPageMedia('playpause')).error, /blocked playback/);
  player.paused = false;
  assert.equal(readPageMedia('playpause').accepted, true);
  assert.equal(pauses, 1);
});
test('capabilities cannot include arbitrary commands', () => {
  assert.deepEqual(normalizeMedia({title: 'Song', commands: ['next', 'eval', 'next']}).commands, ['next']);
});

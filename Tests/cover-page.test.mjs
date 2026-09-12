import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
const script = readFileSync(new URL('../Resources/CoverPage.js', import.meta.url), 'utf8');
function extract(data, links = []) {
  const document = {querySelectorAll: selector => selector === 'a[href]' ? links.map(href => ({getAttribute: () => href})) : data.map(value => ({textContent: typeof value === 'string' ? value : JSON.stringify(value)}))};
  return JSON.parse(vm.runInNewContext(script, {document, URL, location: {href: 'https://www.google.com/search?q=track'}}, {timeout: 100}));
}
test('public-page extraction reads recording facts and album image without executing markup', () => {
  const result = extract([{'@graph': [{'@type': 'MusicRecording', name: 'Song', byArtist: {name: 'Artist'}, inAlbum: {name: 'Album', image: 'https://example.com/a.jpg'}}]}]);
  assert.deepEqual(result.items, [{title: 'Song', artist: 'Artist', album: 'Album', images: ['https://example.com/a.jpg']}]);
});
test('discovery unwraps approved public music links and rejects unrelated schemes and hosts', () => {
  const result = extract([], ['/url?q=https%3A%2F%2Fmusic.apple.com%2Fus%2Falbum%2Ftest%2F123', 'https://evil.example/music.apple.com', 'javascript:alert(1)', 'http://open.spotify.com/track/a']);
  assert.deepEqual(result.links, ['https://music.apple.com/us/album/test/123']);
});
test('malformed, oversized and unrelated page data cannot become track facts', () => {
  assert.equal(extract(['{', 'x'.repeat(200001), {'@type': 'Product', name: 'Song', image: 'https://example.com/a'}]).items.length, 0);
});
test('page output is bounded for hostile graphs and repeated links', () => {
  const result = extract([Array.from({length: 500}, () => ({'@type': 'MusicRecording', name: 'x'.repeat(50000), byArtist: 'a'.repeat(50000)}))]);
  assert.ok(result.items.length <= 20);
  assert.ok(JSON.stringify(result).length < 262144);
});

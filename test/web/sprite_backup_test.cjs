const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const script = fs.readFileSync('web/sprite_backup.js', 'utf8');
let blob, clicked = false, removed = false, timer, revoked;
const anchor = { click() { clicked = true; }, remove() { removed = true; } };
const context = {
  window: {}, Blob,
  URL: { createObjectURL(value) { blob = value; return 'blob:test'; }, revokeObjectURL(url) { revoked = url; } },
  document: { createElement(tag) { assert.equal(tag, 'a'); return anchor; }, body: { appendChild(value) { assert.equal(value, anchor); } } },
  setTimeout(fn, delay) { assert.equal(delay, 60000); timer = fn; }
};
vm.runInNewContext(script, context);
(async () => {
  const bytes = new Uint8Array([1, 2, 3]);
  context.window.ballwarsSpriteBackup.download(bytes, 'sprites.bwsprites');
  assert.equal(anchor.download, 'sprites.bwsprites');
  assert.equal(anchor.href, 'blob:test');
  assert.equal(clicked, true);
  assert.equal(removed, true);
  assert.deepEqual(new Uint8Array(await blob.arrayBuffer()), bytes);
  timer(); assert.equal(revoked, 'blob:test');
  console.log('Sprite backup browser download test passed.');
})().catch(error => { console.error(error); process.exitCode = 1; });

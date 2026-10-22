// Ball Wars offline store (lib/core/offline/offline_store_web.dart): keeps the
// pack catalog, ball images, groups and settings in Cache Storage so the app
// works offline. Keys are arbitrary strings, mapped to fake https URLs.
window.ballwarsStore = (() => {
  const NAME = 'ballwars-offline-v1';
  const url = (key) => 'https://offline.ballwars/' + encodeURIComponent(key);
  const open = () => caches.open(NAME);
  return {
    supported: () => typeof caches !== 'undefined',
    async get(key) {
      const res = await (await open()).match(url(key));
      return res ? new Uint8Array(await res.arrayBuffer()) : null;
    },
    async put(key, bytes) {
      await (await open()).put(url(key), new Response(bytes));
    },
    async missing(keys) {
      const present = new Set((await (await open()).keys()).map((r) => r.url));
      return keys.filter((k) => !present.has(url(k)));
    },
  };
})();

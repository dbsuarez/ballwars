// Ball Wars offline store (lib/core/offline/offline_store_web.dart): keeps the
// pack catalog, ball images, groups and settings in Cache Storage so the app
// works offline. Keys are arbitrary strings, mapped to fake https URLs.
window.ballwarsStore = (() => {
  const NAME = 'ballwars-offline-v1';
  const PREF_PREFIX = 'pref:';
  const LOCAL_PREFIX = 'ballwars:';
  const url = (key) => 'https://offline.ballwars/' + encodeURIComponent(key);
  const open = () => caches.open(NAME);
  const localKey = (key) => LOCAL_PREFIX + key;
  const isPref = (key) => key.startsWith(PREF_PREFIX);

  const readLocal = (key) => {
    const value = localStorage.getItem(localKey(key));
    if (value === null) return null;
    try {
      return new Uint8Array(JSON.parse(value));
    } catch (_) {
      localStorage.removeItem(localKey(key));
      return null;
    }
  };

  const writeLocal = (key, bytes) => {
    localStorage.setItem(localKey(key), JSON.stringify(Array.from(bytes)));
  };

  return {
    supported: () =>
      typeof caches !== 'undefined' && typeof localStorage !== 'undefined',
    async get(key) {
      if (isPref(key)) {
        const local = readLocal(key);
        if (local !== null) return local;
        // One-time migration for preferences written by older releases.
        const old = await (await open()).match(url(key));
        if (old) {
          const bytes = new Uint8Array(await old.arrayBuffer());
          writeLocal(key, bytes);
          return bytes;
        }
        return null;
      }
      const res = await (await open()).match(url(key));
      return res ? new Uint8Array(await res.arrayBuffer()) : null;
    },
    async put(key, bytes) {
      if (isPref(key)) {
        writeLocal(key, bytes);
        return;
      }
      await (await open()).put(url(key), new Response(bytes));
    },
    async missing(keys) {
      const present = new Set((await (await open()).keys()).map((r) => r.url));
      return keys.filter(
        (k) =>
          !(isPref(k) && localStorage.getItem(localKey(k)) !== null) &&
          !present.has(url(k)),
      );
    },
  };
})();

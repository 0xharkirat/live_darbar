// Retires the service worker that the old darbar.live registered at "/".
//
// Until the landing page shipped, the Flutter web app lived at the root and
// registered its service worker here, scoped to "/". That worker answers "/"
// from its cache, so a returning browser would keep showing the old app
// instead of the landing page. The browser re-fetches this exact URL to look
// for an update. This file is the update: it clears the caches, removes
// itself, and reloads open tabs. The app now lives at /app/ and registers its
// own worker there, with its own scope.
//
// Keep this file at the root for as long as old browsers may still return.
self.addEventListener('install', () => self.skipWaiting());

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      for (const key of await caches.keys()) {
        await caches.delete(key);
      }
      await self.registration.unregister();
      const tabs = await self.clients.matchAll({ type: 'window' });
      for (const tab of tabs) {
        tab.navigate(tab.url);
      }
    })(),
  );
});

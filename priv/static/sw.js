// Service worker (ADR 0022): only shows an offline page when a page can't be
// loaded. It caches nothing else, so no private data or stale pages end up in
// the browser cache; with network everything works as without it.

const CACHE = "plattensammlung-offline-v1"
// Relative to the worker's location, so the optional path prefix (PHX_PATH) works
const OFFLINE = new URL("offline.html", self.location).href

self.addEventListener("install", event => {
  event.waitUntil(caches.open(CACHE).then(cache => cache.add(OFFLINE)))
  self.skipWaiting()
})

self.addEventListener("activate", event => {
  event.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(key => key !== CACHE).map(key => caches.delete(key))))
      .then(() => self.clients.claim())
  )
})

self.addEventListener("fetch", event => {
  if (event.request.mode !== "navigate") return

  event.respondWith(fetch(event.request).catch(() => caches.match(OFFLINE)))
})

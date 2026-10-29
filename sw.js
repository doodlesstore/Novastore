/* Nova Stone service worker: makes the site installable and serves the
   app shell assets offline. Page HTML itself is always network-first so
   updates (mint state, rule texts) are never stuck behind a stale cache. */
var CACHE = "nova-v1";
var SHELL = ["manifest.json", "icon-192.png", "icon-512.png", "icon-512-maskable.png"];

self.addEventListener("install", function (event) {
  event.waitUntil(
    caches.open(CACHE).then(function (cache) { return cache.addAll(SHELL); })
  );
});

self.addEventListener("activate", function (event) {
  event.waitUntil(
    caches.keys().then(function (keys) {
      return Promise.all(keys.filter(function (k) { return k !== CACHE; }).map(function (k) { return caches.delete(k); }));
    })
  );
});

self.addEventListener("fetch", function (event) {
  if (event.request.method !== "GET") return;
  var url = new URL(event.request.url);
  if (url.origin !== self.location.origin) return;
  var path = url.pathname.replace(/^\//, "");
  if (SHELL.indexOf(path) !== -1) {
    event.respondWith(
      caches.match(event.request).then(function (hit) {
        return hit || fetch(event.request);
      })
    );
  }
});

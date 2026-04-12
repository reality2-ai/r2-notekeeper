// R2 Notekeeper Service Worker
// Caches all app files on first visit. Serves from cache when offline.

const CACHE_NAME = 'notekeeper-0.4.5';
const ASSETS = [
    './',
    './index.html',
    './manifest.json',
    './qrcode.min.js',
    './pkg/r2_wasm.js',
    './pkg/r2_wasm_bg.wasm',
    './icons/notekeeper.svg',
    './icons/icon-192.png',
    './icons/icon-512.png',
];

// Install: cache all assets
self.addEventListener('install', (event) => {
    event.waitUntil(
        caches.open(CACHE_NAME).then((cache) => cache.addAll(ASSETS))
    );
    self.skipWaiting();
});

// Activate: clean up old caches
self.addEventListener('activate', (event) => {
    event.waitUntil(
        caches.keys().then((keys) =>
            Promise.all(keys.filter((k) => k !== CACHE_NAME).map((k) => caches.delete(k)))
        )
    );
    self.clients.claim();
});

// Fetch: serve from cache, fall back to network, update cache
self.addEventListener('fetch', (event) => {
    // Don't cache WebSocket, relay, or external requests
    if (event.request.url.includes('/r2') ||
        event.request.url.includes('relay.reality2.ai') ||
        event.request.url.startsWith('ws')) {
        return;
    }

    event.respondWith(
        caches.match(event.request).then((cached) => {
            // Return cache immediately, but also fetch and update cache in background
            const fetchPromise = fetch(event.request).then((response) => {
                if (response.ok) {
                    const clone = response.clone();
                    caches.open(CACHE_NAME).then((cache) => cache.put(event.request, clone));
                }
                return response;
            }).catch(() => cached); // network failed, use cache

            return cached || fetchPromise;
        })
    );
});

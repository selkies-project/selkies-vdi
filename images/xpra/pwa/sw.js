var cacheName = 'hello-pwa';
var filesToCache = [
  '/',
  '/index.html',
  '/background.png',
  '/connect.html',
  '/default-settings.txt',
  '/css/bootstrap.css',
  '/css/client.css',
  '/css/icon.css',
  '/css/menu-skin.css',
  '/css/menu.css',
  '/css/signin.css',
  '/css/spinner.css',
  '/js/Client.js',
  '/js/Keycodes.js',
  '/js/MediaSourceUtil.js',
  '/js/Menu-custom.js',
  '/js/Menu.js',
  '/js/Notifications.js',
  '/js/Protocol.js',
  '/js/Utilities.js',
  '/js/Window.js',
  '/js/auto-fullscreen.js',
  '/js/fix-printing.js',
  '/js/keyboard-lock.js',
  '/js/lib/AudioContextMonkeyPatch.js',
  '/js/lib/FileSaver.js',
  '/js/lib/bencode.js',
  '/js/lib/brotli_decode.js',
  '/js/lib/es6-shim.js',
  '/js/lib/forge.js',
  '/js/lib/jquery-ui.js',
  '/js/lib/jquery.ba-throttle-debounce.js',
  '/js/lib/jquery.js',
  '/js/lib/jsmpeg.js',
  '/js/lib/jszip.js',
  '/js/lib/lz4.js',
  '/js/lib/wsworker_check.js',
  '/js/lib/zlib.js',
];

/* Start the service worker and cache all of the app's content */
self.addEventListener('install', function(e) {
  e.waitUntil(
    caches.open(cacheName).then(function(cache) {
      return cache.addAll(filesToCache);
    })
  );
});

/* Serve cached content when offline */
self.addEventListener('fetch', function(e) {
  e.respondWith(
    caches.match(e.request).then(function(response) {
      return response || fetch(e.request);
    })
  );
});

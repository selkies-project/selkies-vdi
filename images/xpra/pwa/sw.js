/**
 * Copyright 2021 The Selkies Authors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/*
Initialize the cache but don't cache any resources since this is a streaming app with no offline concept.
*/
const cacheVersion = "CACHE_VERSION";
var cacheName = 'XPRA_PWA_CACHE';
var filesToCache = [
  '/',
  '/index.html',
  '/connect.html',
  '/icon-192x192.png',
  '/icon-512x512.png'
];

function getCacheName() {
  return cacheName + "_" + cacheVersion;
}

// on activation we clean up the previously registered service workers
self.addEventListener('activate', evt => {
  evt.waitUntil(
    caches.keys().then(cacheNames => {
      return Promise.all(
        cacheNames.map(name => {
          if (name.startsWith(cacheName) && name !== getCacheName()) {
            return caches.delete(name);
          }
        })
      );
    })
  )
});

/* Start the service worker and cache all of the app's content */
self.addEventListener('install', function(e) {
  e.waitUntil(
    caches.open(getCacheName()).then(function(cache) {
      return cache.addAll(filesToCache);
    })
  );
});

/* Serve cached content when offline */
self.addEventListener('fetch', function(e) {
  e.respondWith(
    caches.match(e.request)
      .then(function(response) {
        return response || fetch(e.request, {
          credentials: 'include',
        })
      })
      .catch(function(e) { return new Response() })
    );
});

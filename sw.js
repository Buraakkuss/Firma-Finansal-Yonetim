/* NakitPilot service worker.
   Cache adı 'nakitpilot' içermek zorundadır: index.html içindeki
   clearOldPwaCachesForVersion() eski sürüm cache'lerini bu ada göre temizler. */
const APP_VERSION = '0.12.0';
const CACHE_NAME = 'nakitpilot-shell-v' + APP_VERSION;
const APP_SHELL = [
  './',
  './index.html',
  './manifest.webmanifest',
  './icons/nakitpilot-icon.svg',
  './icons/icon-192.png',
  './icons/icon-512.png'
];

async function deleteOtherCaches() {
  const keys = await caches.keys();
  await Promise.all(keys.filter((key) => key !== CACHE_NAME).map((key) => caches.delete(key)));
}

self.addEventListener('install', (event) => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE_NAME);
    // Tek tek ekleniyor: addAll'da bir dosya 404 verirse kurulumun tamamı iptal olur.
    await Promise.all(APP_SHELL.map((url) => cache.add(url).catch((err) => {
      console.warn('SW app shell dosyası önbelleğe alınamadı:', url, err);
    })));
    await self.skipWaiting();
  })());
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    await deleteOtherCaches();
    await self.clients.claim();
  })());
});

self.addEventListener('message', (event) => {
  const type = event.data && event.data.type;
  if (type === 'SKIP_WAITING') self.skipWaiting();
  if (type === 'CLEAR_OLD_CACHES') event.waitUntil(deleteOtherCaches());
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;

  const url = new URL(request.url);
  // Supabase ve diğer çapraz kaynak istekleri hiç önbelleğe alınmaz.
  if (url.hostname.includes('supabase.co')) return;
  if (url.origin !== location.origin) return;

  const isDocument = request.mode === 'navigate' || (request.headers.get('accept') || '').includes('text/html');

  if (isDocument) {
    // Uygulama sürümü hep taze gelsin; ağ yoksa önbellekteki kabuk gösterilir.
    event.respondWith((async () => {
      try {
        const response = await fetch(request);
        if (response && response.ok) {
          const clone = response.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put('./index.html', clone)).catch(() => {});
        }
        return response;
      } catch (err) {
        return (await caches.match(request)) || (await caches.match('./index.html')) || Response.error();
      }
    })());
    return;
  }

  event.respondWith((async () => {
    const cached = await caches.match(request);
    if (cached) return cached;
    try {
      const response = await fetch(request);
      if (response && response.ok) {
        const clone = response.clone();
        caches.open(CACHE_NAME).then((cache) => cache.put(request, clone)).catch(() => {});
      }
      return response;
    } catch (err) {
      return (await caches.match('./index.html')) || Response.error();
    }
  })());
});

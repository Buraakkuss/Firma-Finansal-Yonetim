# Orbita — oyun projesi

Tek dokunuşlu sonsuz arcade oyunu. **Tek HTML dosyası** (`www/index.html`) + Capacitor.
Güncel sürüm: **v1.0.1**. Bu depo NakitPilot / MT-PRO-Finans projesinden tamamen bağımsızdır.

## Çalışma kuralları

1. Oyun mantığı, arayüz, reklam ve satın alma köprüsü **tek dosyada** kalır: `www/index.html`.
   Yeni dosya açma; kullanıcı yazılımcı değil, tek dosyayı kopyalayarak güncelleme yapabilmeli.
2. Sürüm yükseltirken birlikte güncellenir: `www/index.html` içindeki `CFG.version`,
   `app.config.json` içindeki `version` ve `versionCode`, `store/*.md` sürüm notları.
3. **Git commit mesajı sadece sürüm numarasıdır.** Örnek: `v1.0.1`
4. Her değişiklikten sonra `node tools/check.js` çalıştırılır. Yeşil değilse commit yok.
5. Görsel değiştiyse `bash tools/gen.sh` ile tüm mağaza görselleri yeniden üretilir.
6. Reklam kimlikleri, e-posta ve bundle id **yalnız `app.config.json`** içinde değiştirilir,
   ardından `bash tools/set-identity.sh` çalıştırılır.
7. Token tasarrufu: `index.html` ~950 satırdır, tamamını okuma; `grep -n` ile hedefe git.

## Mimari notlar

- Oyun döngüsü: `update(dt)` → `render()`, `requestAnimationFrame(loop)` ile.
- Durumlar: `menu · orbit · fly · dead` (`G.mode`).
- Zorluk: menüdeki üç mod (`easy · normal · hard`) `DIFF` tablosundan gelir, `DF()` ile okunur.
  Denge ayarı **yalnız `DIFF` tablosundan** yapılır — `omega()`, `flySpeed()`, `planetR()`,
  `spikeCount()`, yakalama toleransı ve PERFECT açısı hepsi bu tablodan çarpan alır.
  `hard` modu v1.0.0'ın orijinal dengesidir. Rekorlar mod başına ayrı tutulur (`S.best`).
- `easy` modunda (ve `normal`'da ilk 3 gezegende) nişan çizgisi çizilir; mekaniği öğreten şey budur.
- `U = W/400` ölçek birimi. **Tüm mesafeler `U` ile çarpılır**, yoksa zorluk cihaz genişliğine göre değişir.
- `capture()` içinde "adaletsiz iniş" koruması var: top dikenin üstüne düşerse gezegenin
  dikenleri 180° döndürülür. Bu kaldırılırsa oyun haksız ölümler üretir.
- Ses dosyası yok; sesler WebAudio ile üretiliyor (`Snd`). Yeni ses eklenecekse yine sentezle.
- `Ads` ve `IAP` nesneleri native değilse sessizce devre dışı kalır — tarayıcıda test hep çalışır.

## Test modları

| URL | Ne yapar |
|---|---|
| `www/index.html` | normal oyun |
| `www/index.html?selftest=1&diff=easy` | 9000 kare otomatik oynar, sonucu `document.title` içine yazar (`diff` isteğe bağlı) |
| `www/index.html?shot=1&...` | mağaza ekran görüntüsü kompozisyonu üretir |

## Tuzaklar

- `CFG.ads.useTest` **true** ile yayına çıkılırsa hiç gelir olmaz. `tools/check.js` bunu yakalar.
- Gerçek AdMob kimlikleriyle kendi reklamına tıklamak hesabı kalıcı kapattırır.
- Android `versionCode` her yüklemede artmalı.
- `orbita-release.jks` imza anahtarı kaybolursa uygulama bir daha güncellenemez.
- Mağaza dağıtımından Türkiye çıkarılmışsa bu bir **vergi gereği**dir (KVK 10/1-g), yanlışlıkla açma.
  Gerekçe `LAUNCH-CHECKLIST.md` Aşama 0'da.

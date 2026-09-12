# Orbita v1.0.0

Tek dokunuşlu, sonsuz arcade oyunu. Tek HTML dosyası + Capacitor ile iOS ve Android.
Mağazaya gönderilmeye hazır: oyun, reklamlar, satın alma, simgeler, ekran görüntüleri,
gizlilik politikası, kullanım şartları, mağaza metinleri ve içerik planı dahil.

## 30 saniyede dene
```bash
npx --yes serve www -l 5173     # sonra tarayıcıda http://localhost:5173
```
veya `www/index.html` dosyasına çift tıkla. Boşluk tuşu = dokunma.

## Klasörler
| Klasör | İçerik |
|---|---|
| `www/index.html` | **Oyunun tamamı.** Tek dosya, bağımlılık yok. Reklam ve satın alma köprüleri içinde. |
| `app.config.json` | Kimlik bilgilerinin tek kaynağı (bundle id, e-posta, AdMob kimlikleri). |
| `assets/` | Simgeler, açılış ekranı, öne çıkan grafik, 10 mağaza ekran görüntüsü — hepsi üretilmiş. |
| `docs/` | GitHub Pages ile yayına girecek gizlilik/şartlar/destek sayfaları (EN + TR). |
| `store/` | Play ve App Store metinleri, Veri Güvenliği, App Privacy ve yaş derecelendirme cevapları. |
| `native/` | Android ve iOS derleme adımları, kopyalanabilir Manifest/Info.plist parçaları. |
| `marketing/` | 15 TikTok/Reels senaryosu, story planı, hashtag setleri, yayın takvimi. |
| `tools/` | Görsel üretici, doğrulama scripti, kimlik güncelleyici, depo ayırıcı. |
| `LAUNCH-CHECKLIST.md` | **Sıfırdan yayına kadar sıralı liste. Buradan başla.** |

## Komutlar
```bash
node tools/check.js          # yayın öncesi tam doğrulama (oyun + görseller + ayarlar)
bash tools/gen.sh            # tüm mağaza görsellerini yeniden üret
bash tools/set-identity.sh   # app.config.json'daki değerleri tüm dosyalara yaz
npm install && npx cap add android && npx cap add ios
```

## Oyun nasıl çalışıyor
Top bir gezegenin yörüngesinde döner. Dokunduğunda **döndüğü yönün teğeti** boyunca fırlar —
hedefe doğru değil. Bir sonraki gezegenin yörüngesine girerse yakalanır ve puan gelir.
Tam hedefe bırakırsan **PERFECT** (çift puan). Gezegenlerin etrafında dönen kırmızı yaylar öldürür.
Her gezegen bir öncekinden hızlı, küçük ve daha korumalı.

Zorluk `omega()`, `flySpeed()`, `planetR()` ve `spikeCount()` fonksiyonlarında; oyun dengesi
bu dört satırla ayarlanır.

## Bilinmesi gerekenler
- Kod şu an **Google'ın resmi test reklam kimlikleriyle** geliyor. AdMob hesabın açılınca
  `app.config.json` içindeki `admob.real` alanlarını doldur, `useTest`'i `false` yap,
  `bash tools/set-identity.sh` çalıştır. `node tools/check.js` bunu kontrol ediyor.
- `www/index.html` içinde `?selftest=1` otomatik oyun testi, `?shot=1` mağaza görseli modu var.
- Destek e-postası şu an `t.burakkus@gmail.com`. Yayınlandığında mağaza sayfasında **herkese
  görünür.** Ayrı bir adres istiyorsan `app.config.json` içinde değiştirip `set-identity.sh` çalıştır.

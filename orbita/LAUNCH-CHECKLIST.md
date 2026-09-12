# Orbita — yayına çıkış listesi

Sırayla git. Solundaki kutu senin yapman gerekeni, **(K)** işareti bende olan işi gösterir.
Yazılım tarafı bitti; kalan her şey hesap, imza ve gönderim işi — bunlar senin kimliğinle yapılır.

---

## AŞAMA 0 — Karar (5 dakika)

- [ ] **Kurumsal mı, şahıs mı?** Bu karar iki şeyi belirliyor:
  - **KUŞ GRUP Ltd (organization):** Play'de 12 testçi/14 gün şartı **yok**, ev adresin görünmez,
    D-U-N-S doğrulaması 1-3 hafta sürer. KVK 10/1-g ile kurumlar vergisi %0 olabilmesi için
    uygulamanın **münhasıran yurt dışı** kullanıcılara açık olması gerekir → mağaza dağıtımından
    **Türkiye'yi çıkar**. `store/*.md` dosyaları bu varsayımla yazıldı.
  - **Şahıs / gerçek kişi:** hemen başlar, ama Play'de 12 testçi × 14 gün kapalı test şartı var
    (hesap başına tek sefer) ve ad-adres mağazada görünür. GVK mük. 20/B ile %15 banka stopajı
    nihai vergi olur, 2026 sınırı 5.300.000 TL — aşarsan istisna geriye dönük tamamen kalkar.
  - Karar verene kadar **1-5 arası adımların hepsi yapılabilir**; hiçbiri hesaba bağlı değil.

---

## AŞAMA 1 — Hesaplar (paralel yürüt, bekleme süresi burada)

- [ ] Apple Developer Program kaydı (99 $/yıl) · organization ise D-U-N-S numarası
- [ ] Google Play Console kaydı (25 $ tek sefer)
- [ ] AdMob hesabı aç, **ödeme adresi doğrulama PIN'i** iste (posta ile gelir, 2-4 hafta sürer — şimdi başlat)
- [ ] Apple: Agreements, Tax and Banking → Paid Apps sözleşmesi + banka + vergi formları (**W-8BEN-E** kurumsal / **W-8BEN** şahıs)
- [ ] Google Play: Ödemeler profili + vergi bilgileri
- [ ] GitHub deposu aç ve projeyi taşı: `bash tools/extract-repo.sh ~/orbita-game`
- [ ] GitHub → Settings → Pages → Source: `main` / `docs` → gizlilik sayfaları yayına girer
- [ ] Yayına giren adresi doğrula: `https://<kullanıcı>.github.io/orbita-game/privacy.html` açılıyor mu?

---

## AŞAMA 2 — Reklam ve satın alma kimlikleri

- [ ] AdMob → Uygulama ekle (**Android**) → App ID'yi kopyala
- [ ] AdMob → Uygulama ekle (**iOS**) → App ID'yi kopyala
- [ ] Her iki uygulama için **Interstitial** ve **Rewarded** reklam birimi oluştur (4 kimlik)
- [ ] `app.config.json` → `admob.real` alanlarını doldur, `useTest: false` yap
- [ ] `bash tools/set-identity.sh` çalıştır
- [ ] `native/android.md` adım 3'teki Manifest `APPLICATION_ID` satırını gerçek kimlikle değiştir
- [ ] `native/ios.md` adım 5'teki `GADApplicationIdentifier` satırını gerçek kimlikle değiştir
- [ ] Play Console → Ürünler → Uygulama içi ürünler → `remove_ads` (tek seferlik, ~2,99 $)
- [ ] App Store Connect → Uygulama içi satın alma → `remove_ads` (**Non-Consumable**, aynı fiyat)
- [ ] `node tools/check.js` → "Hata yok, 0 uyarı" görmeden devam etme

---

## AŞAMA 3 — Derleme

- [ ] `npm install`
- [ ] `npx cap add android && npx cap add ios && npx cap sync`
- [ ] `native/android.md` adımlarını uygula (simgeler, Manifest, imza anahtarı, versionCode)
- [ ] **İmza anahtarını (`orbita-release.jks`) ve parolasını yedekle.** Kaybedersen uygulamayı bir daha güncelleyemezsin.
- [ ] `native/ios.md` adımlarını uygula (Info.plist, In-App Purchase capability, sadece iPhone, portrait)
- [ ] Gerçek Android cihazda test: reklam "Test Ad" yerine gerçek reklam gelmeli, `remove_ads` satın alınabilmeli
- [ ] Gerçek iPhone'da test: ATT istemi çıkmalı, reddedince oyun sorunsuz çalışmalı
- [ ] Ödüllü reklam → "Continue" gerçekten devam ettiriyor mu?
- [ ] Uçak modunda aç: oyun oynanabilmeli (offline vaadi mağaza metninde yazıyor)

---

## AŞAMA 4 — Mağaza gönderimi

### Google Play
- [ ] Uygulama oluştur → ad: `Orbita: One Tap Orbit Jump`
- [ ] Mağaza girişi: `store/google-play.md` içindeki metinleri yapıştır
- [ ] Grafikler: `assets/icon-512.png`, `assets/feature-graphic-1024x500.png`, `assets/screenshots/android-*.png`
- [ ] Veri güvenliği formu: `store/data-safety.md`
- [ ] İçerik derecelendirme: `store/content-rating.md`
- [ ] Hedef kitle: **13+** (13 yaş altını seçme)
- [ ] Reklam içeriyor: **Evet**
- [ ] Ülkeler: karar 0'a göre (kurumsal ise **Türkiye hariç**)
- [ ] AAB yükle → Kapalı test → sonra Üretim

### App Store
- [ ] App Store Connect → Yeni uygulama → bundle id `com.kusgrup.orbita`
- [ ] Metinler: `store/app-store.md`
- [ ] Ekran görüntüleri: `assets/screenshots/ios67-*.png` (6.7")
- [ ] App Privacy: `store/app-privacy.md`
- [ ] IDFA beyanı: **Yes → Serve advertisements within the app**
- [ ] `remove_ads` ürününü **ilk sürümle birlikte** incelemeye gönder (yoksa 3.1.1 reddi gelir)
- [ ] App Review notlarını yapıştır (`store/app-store.md` içinde hazır)
- [ ] Xcode'dan Archive → Upload → sürüme ekle → Gönder

---

## AŞAMA 5 — İçerik (onay beklerken yap, boşa bekleme)

- [ ] Telefonda 6-8 dakika oyna, ekran kaydı al (`marketing/tiktok-reels.md` adım listesi)
- [ ] 15 videoyu CapCut'ta kes
- [ ] TikTok + Instagram hesaplarını aç, bio'ya link koy
- [ ] İlk gün 2 TikTok + 1 Reels + 2 story (takvim `marketing/tiktok-reels.md` sonunda)
- [ ] Her videoya kendi sabit yorumunu at

---

## AŞAMA 6 — Yayın sonrası ilk 14 gün

- [ ] Gün 1-3: yorumların hepsine cevap ver (ilk saat en kritik)
- [ ] Gün 7: Play Console → İstatistikler → **1. gün elde tutma** oranına bak
- [ ] Gün 14 kararı:
  - D1 > **%30** ve ortalama oturum > 3 dk → **büyüt** (yeni gezegen tipi, günlük hedef, içerik dalgası)
  - D1 < **%20** → **dur**, içerik üretmeyi kes, sıradaki oyuna geç (uygulama mağazada kalsın)
- [ ] Bir video 100 bin izlenmeyi geçerse 72 saat içinde güncelleme çıkar

---

## Yayından önce son kontrol

```bash
node tools/check.js
```

| Kontrol | Neden önemli |
|---|---|
| `useTest: false` | Test kimliğiyle yayına çıkarsan **hiç gelir olmaz** |
| Kodda `3940256099942544` kalmamalı | Gerçek hesapla test reklamına tıklarsan AdMob hesabın kapanır |
| Gizlilik URL'si açılıyor | Her iki mağaza da erişilemeyen URL'yi reddeder |
| `versionCode` artırıldı | Aynı numarayla ikinci kez yükleme yapılamaz |
| İmza anahtarı yedeklendi | Kaybı geri dönüşü olmayan tek hatadır |

## Bilinen riskler (dürüst liste)

1. **İsim çakışması.** "Orbita" adında başka uygulamalar olabilir. Göndermeden önce her iki
   mağazada arat. Çakışma varsa yedek isimler: *Orbit Leap*, *Tangent*, *Ring Drift*, *Orbita Dash*.
   İsim değişimi tek yerden yapılır: `app.config.json` + `bash tools/set-identity.sh`.
2. **İlk uygulama incelemesi uzun sürer.** Apple'da ilk gönderim 1-3 gün, bazen daha fazla.
3. **AdMob ödeme eşiği 100 $.** Altında ödeme yapılmaz, birikir.
4. **Vergi rejimi kararı geri dönüşü zordur.** Mağaza hesabının sahibi sonradan değiştirilemez;
   uygulamayı başka hesaba devretmek gerekir (mümkün ama zahmetli). Aşama 0'ı muhasebecine danışmadan geçme.

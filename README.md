# NakitPilot / MT-PRO-Finans — Marmara Teknik

Marmara Teknik için geliştirilen, çok firmalı web tabanlı finans ve proje takip uygulaması.
Tek HTML dosyası (vanilla JS + CSS) üzerinde çalışır, verisini Supabase'te tutar.

**Güncel sürüm: v0.12.0**

## Dosya yapısı

| Yol | Açıklama |
| --- | --- |
| `index.html` | Uygulamanın tamamı. Domain'e yüklenen dosya budur. |
| `manifest.webmanifest` | PWA / ana ekran bilgileri. |
| `sw.js` | Service worker. HTML ağdan, statik dosyalar önbellekten servis edilir. |
| `icons/` | `nakitpilot-icon.svg` (favicon) ve 192/512 px PWA ikonları. |
| `docs/` | Proje bağlamı, veri modeli, iş kuralları, sürüm geçmişi, Supabase aktarım rehberi. |
| `sql/` | Supabase kurulum ve migration dosyaları. |
| `version-notes/` | Sürüm bazlı değişiklik özeti, kurulum notu, Supabase notu ve test raporu. |
| `requirements/` | Banka Merkezi geliştirme talebinin orijinal metni. |
| `scripts/fetch-tcmb-rates.mjs` | TCMB kurlarını çekip Supabase'e yazan script. |
| `.github/workflows/tcmb-rates.yml` | Yukarıdaki scripti otomatik çalıştıran workflow. |

## Geliştirmeye başlamadan önce

`docs/` klasörü projenin tek doğru kaynağıdır. Özellikle şunlar okunmalıdır:

- `docs/02_PROJE_TAM_BAGLAM.md` — mimari, sayfalar, roller, finans çekirdeği, Banka Merkezi kuralları.
- `docs/03_VERI_MODELI_VE_IS_KURALLARI.md` — veri modeli ve iş kuralları.
- `docs/04_SURUM_GECMISI.md` — sürüm geçmişi.
- `docs/05_SUPABASE_VE_CANLI_VERI_AKTARIMI.md` — Supabase şeması ve canlı veri aktarımı.
- `docs/01_CLAUDE_ILK_MESAJ.txt` — üzerinde çalışırken uyulacak kurallar.

## Çalışma kuralları (özet)

1. Mevcut özellikleri bozma, veri kaybına yol açma.
2. Tek HTML ağırlıklı mimariyle devam et.
3. Güncelleme, kullanıcının dosyayı domain'e kopyalaması ile uygulanabilir olsun.
4. Supabase değişikliği gerekiyorsa tek parça, kopyalanabilir SQL ver.
5. Her yeni sürümde `APP_VERSION` yükselt (`index.html` içinde), `sw.js` ve `manifest.webmanifest` sürüm bilgisini de eşitle.
6. Git commit mesajı sadece sürüm numarasıdır. Örnek: `v0.8.3`.
7. Gelir yeşil, gider/borç kırmızı, risk/uyarı turuncu.

## Sürüm çıkarma

1. `index.html` içindeki `APP_VERSION` değerini yükselt (sayfa başlığı ve sidebar sürüm yazısı dahil).
2. `sw.js` içindeki `APP_VERSION` ve `manifest.webmanifest` içindeki `start_url` sürüm parametresini güncelle.
3. `version-notes/` altına `DEGISIKLIK-OZETI`, `KURULUM-NOTU`, `SUPABASE-NOTU` ve `TEST-RAPORU` dosyalarını yeni sürüm numarasıyla ekle.
4. Supabase değişikliği varsa SQL dosyasını `sql/` altına ekle.
5. Commit mesajı olarak yalnız sürüm numarasını kullan.

## Veri sıfırlama

Sıfırdan veri girişine geçmek için `sql/nakitpilot-veri-sifirlama-v0.8.3.sql`
dosyasının tamamını Supabase > SQL Editor'a yapıştırıp bir kez çalıştırın.

- Siler: gelir, gider, sabit/kesin kalemler, tahminler, döviz dönüşümleri,
  kart ödemeleri ve tüm banka hareketleri; hesap/KMH/kart bakiyeleri sıfırlanır.
- Korur: firma, kullanıcı, rol ve izinler; banka, hesap, kart ve KMH tanımları;
  Proje Takip kayıtları; kategori listeleri.
- Çalışmadan önce her firmanın verisini `company_backups` tablosuna yedekler;
  geri alma adımları script'in sonundadır.

Normalize finans tabloları `trg_company_data_banking_sync` tetikleyicisi ile
otomatik aynılanır, onlar için ayrı komut gerekmez.

## TCMB kur otomasyonu

Workflow hafta içi günde üç kez (Türkiye saatiyle 15:40, 16:15 ve 17:00) çalışır ve
`firma_finans_fx_rate_cache` tablosuna `rate_date` üzerinden upsert yapar; tekrar eden
çalışmalar veriyi bozmaz. Canlı çekim başarısız olursa önbellekteki son kur kullanılmaya
devam eder ve workflow hata vermeden sonlanır.

Çalışması için repo ayarlarında `SUPABASE_SERVICE_ROLE_KEY` secret'ı tanımlı olmalıdır:
Settings > Secrets and variables > Actions.

## Canlı veri

Supabase'teki canlı firma kayıtları bu repoda tutulmaz. Yedek almak için uygulama içindeki
**Yasal & Hesap > JSON dışa aktarma** bölümü kullanılır; detaylar
`docs/05_SUPABASE_VE_CANLI_VERI_AKTARIMI.md` dosyasındadır.

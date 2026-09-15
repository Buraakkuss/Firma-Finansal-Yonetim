# NakitPilot / MT-PRO-Finans

Marmara Teknik için çok firmalı web tabanlı finans ve proje takip uygulaması.
Güncel sürüm: **v0.22.3**. Tek HTML (vanilla JS + CSS) + Supabase.

## 0. Limit kullanımı — her zaman geçerli

Kullanıcının Claude kotası sınırlıdır. **Her oturumda mümkün olan en az token /
en az araç çağrısı ile çalış, ama işi asla eksik veya hatalı bırakma.**

- Aynı dosyayı iki kez okuma. Okuduğunu hatırla.
- Koca dosyaları baştan sona okuma; `grep -n` ile hedefe git, sonra dar aralık oku.
  `index.html` ~13.000 satırdır, tamamını asla okuma.
- Birbirine bağlı olmayan komutları tek bir araç çağrısında birleştir.
- Doğrulamayı tek toplu komutla yap, adım adım değil.
- Ne yapacağını anlatıp sonra yapma; doğrudan yap ve sonucu kısaca söyle.
- Cevaplar kısa ve maddeli olsun. Uzun teknik anlatım yerine sonucu ver.
- Gereksiz alt ajan (Agent) çalıştırma — kullanıcı açıkça istemedikçe yasak.
- Ama: finansal hesap, veri silme veya migration söz konusuysa doğrulamadan geçme.
  Tasarruf uğruna test atlama.

## 1. Çalışma kuralları (kullanıcının kendi kuralları)

1. Mevcut özellikleri bozma, veri kaybına yol açma.
2. Tek HTML ağırlıklı mimariyle devam et; kullanıcı yazılımcı değildir.
3. Güncelleme, dosyayı domain'e kopyalayıp üzerine yazmakla uygulanabilir olsun.
4. Supabase değişikliği gerekiyorsa tek parça, kopyalanabilir SQL ver.
5. Her yeni sürümde `index.html` içindeki `APP_VERSION`, sayfa başlığı, sidebar
   sürüm yazısı, `sw.js` içindeki `APP_VERSION` ve `manifest.webmanifest`
   içindeki `start_url` birlikte yükseltilir.
6. **Git commit mesajı sadece sürüm numarasıdır.** Örnek: `v0.8.4`
7. Gelir yeşil, gider/borç kırmızı, risk/uyarı turuncu.
8. Arayüz sade ve işletme sahibinin anlayacağı düzeyde olsun.
9. Yeni işe başlamadan önce ilgili fonksiyonu kodda incele; varsayım yapma.

Ayrıntı: `docs/` klasörü projenin tek doğru kaynağıdır.
`docs/02` mimari ve sayfalar, `docs/03` veri modeli ve 15 muhasebe kuralı,
`docs/04` sürüm geçmişi, `docs/05` Supabase ve canlı veri aktarımı.

## 2. Bilinmesi gereken tuzaklar

- **`sql/` altındaki eski kurulum/migration dosyalarını yeniden çalıştırma.**
  Banka Merkezi migration'ı `np_sync_company_banking_snapshot` fonksiyonunun
  `search_path`'ini `public` yapar ve v0.7.4'teki pgcrypto/`digest()`
  düzeltmesini geri alır.
- `company_data.data` tek doğru kaynaktır. Üzerindeki
  `trg_company_data_banking_sync` tetikleyicisi normalize finans tablolarını
  (bank_accounts, credit_cards, ...) silip JSON'dan yeniden yazar. Normalize
  tablolara elle yazma.
- `amountTL()` TRY kayıtlarda `amountTry` alanını okumaz, `amount` alanını okur.
  `amountTry` yalnız TRY olmayan ve `rate > 1` olan kayıtlarda kullanılır.
- Para alanı yazan her yeni kod `withMoneyMeta(obj, prefix)` üzerinden geçmelidir;
  aksi halde `currency` / `rate` / `amountTry` bayat kalır (v0.8.3'te düzeltilen hata).
- KMH kullanımı ve kredi kartı borcu ödemesi gelir/gider değildir; varlıklar arası
  harekettir ve Banka Merkezi üzerinden işlenir. KMH faizi ve banka komisyonu
  gerçek giderdir.
- Zamanlanmış GitHub Actions yalnız **varsayılan daldan (main)** çalışır.
  Workflow düzeltmesi main'e merge edilmeden devreye girmez.

## 3. Doğrulama

Sürüm çıkarmadan önce:

```bash
node -e "const h=require('fs').readFileSync('index.html','utf8');const re=/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/g;let m,i=0,b=0;while((m=re.exec(h))){i++;try{new Function(m[1])}catch(e){b++;console.log(e.message)}}console.log(i+' blok, '+b+' hata')"
node --check sw.js && node -e "JSON.parse(require('fs').readFileSync('manifest.webmanifest','utf8'))"
```

SQL yazıldıysa yerel PostgreSQL'de gerçek şema ve gerçek yedek veriyle test et
(`/usr/lib/postgresql/16/bin`, Supabase için `auth.uid()` / `auth.jwt()` stub'ı gerekir).

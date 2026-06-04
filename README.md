# Firma Finansal Yönetim — Supabase + GitHub Pages

Bu paket, tek dosyalık finans uygulamasının Supabase bulut veritabanı ve GitHub Pages yayını için hazırlanmış sürümüdür.

## İçerik

- `index.html`: Yayınlanacak ana uygulama dosyası.
- `manifest.webmanifest`: Mobil ana ekran / PWA bilgileri.
- `sw.js`: Uygulama kabuğu için servis worker.
- `.github/workflows/pages.yml`: GitHub Pages otomatik yayın workflow dosyası.
- `supabase-firma-finans-kurulum.sql`: Supabase SQL kurulumu.

## Link formatı

GitHub Pages aktif olunca adres şu formatta olur:

`https://GITHUB_KULLANICI_ADI.github.io/firma-finansal-yonetim/`

Supabase > Authentication > URL Configuration bölümünde Site URL ve Redirect URLs alanına canlı linki ekleyin.

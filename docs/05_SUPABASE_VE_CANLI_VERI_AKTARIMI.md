# Supabase ve Canlı Veri Aktarımı

## A. Claude'a canlı şirket verisini aktarmanın EN KOLAY ve EN DOĞRU yolu
NakitPilot v0.8.2 içinde ham JSON dışa aktarma zaten vardır.

Her firma için:
1. NakitPilot'a yönetici/rapor indirme yetkili kullanıcıyla giriş yapın.
2. Üst bardan aktaracağınız firmayı seçin.
3. Sol menüden **Ayarlar** ekranına girin.
4. **Veri ve Yasal İşlemler** panelindeki **JSON Yedek Al** butonuna basın.
5. Tarayıcı şu yapıda bir dosya indirir: `nakitpilot-yedek-FIRMA-ADI.json`.
6. Birden fazla firma varsa firma seçiciden diğer firmaya geçip aynı işlemi tekrar yapın.
7. İndirdiğiniz tüm JSON dosyalarını Claude Project Files'a yükleyin.

Bu JSON şu bilgileri taşır:
- product / version / export tarihi
- aktif kullanıcı rol bilgisi
- firma id/ad/plan/durum
- tamamlanmış gelirler
- tamamlanmış giderler
- gelecekteki kesin kalemler
- tahminler
- döviz dönüşümleri
- kredi kartları ve ödemeleri
- banka merkezi verileri
- bankalar / hesaplar / transferler / KMH / kart hareketleri / taksitler / yatırım hareketleri / reversals
- MT Pro müşteri görüşmeleri / projeler / maliyetler / teklifler / dosya metadata'ları / aktiviteler
- kategoriler

Bu yüzden Claude'a iş mantığını anlatmak için en değerli canlı veri dosyası budur.

## B. Supabase veritabanının tam teknik yedeği
Claude'a yalnız geliştirme bağlamı aktaracaksanız A yöntemi yeterlidir.
Sunucu/veritabanı taşınacaksa ayrıca Supabase'in tam DB yedeğini alın.

### Supabase Dashboard üzerinden
Supabase Dashboard > Database > Backups alanında projenizin planının izin verdiği yedek seçeneklerini kullanın.

### pg_dump ile
Supabase Dashboard > Connect bölümünden Postgres connection string alın. Parolayı kimseyle paylaşmayın.
Bilgisayarınızda PostgreSQL araçları kuruluysa:

```bash
pg_dump "SUPABASE_POSTGRES_CONNECTION_STRING" \
  --format=custom \
  --no-owner \
  --no-acl \
  --file=nakitpilot-supabase-full.dump
```

Yalnız şema için:
```bash
pg_dump "SUPABASE_POSTGRES_CONNECTION_STRING" \
  --schema-only \
  --no-owner \
  --no-acl \
  --file=nakitpilot-schema.sql
```

Yalnız public verileri için:
```bash
pg_dump "SUPABASE_POSTGRES_CONNECTION_STRING" \
  --data-only \
  --schema=public \
  --no-owner \
  --no-acl \
  --file=nakitpilot-public-data.sql
```

`SUPABASE_POSTGRES_CONNECTION_STRING` değerini Claude'a yüklemeyin. DB şifresi ve service_role anahtarı gizli kalmalıdır.

## C. Supabase Storage dosyaları
NakitPilot proje dosyaları `project-files` bucket'ına yüklenebilir.
JSON yedek, dosya içeriğinin kendisini değil dosya kaydını/linkini taşır.
Bu nedenle Storage dosyalarını ayrıca indirin veya mevcut Supabase projesini kullanmaya devam edecekseniz Claude'a yalnız bucket yapısını anlatın.

## D. Auth kullanıcıları
Supabase Auth kullanıcı parolalarını düz metin olarak dışarı aktarmaya/Claude'a vermeye çalışmayın.
Başka Supabase projesine gerçek migration yapılacaksa kullanıcı geçişi ayrı bir auth migration çalışmasıdır.
Claude'a geliştirme bağlamı için kullanıcıların parolaları gerekmez.

## E. SQL dosyaları
Bu aktarım paketinde bilinen temel SQL'ler vardır:
- `nakitpilot-mtpro-finans-kurulum-v0.3.4-mt.5.sql`
- `nakitpilot-proje-takip-kurulum-v0.5.0.sql`
- `nakitpilot-banka-merkezi-migration-v0.6.0.sql`
- `nakitpilot-supabase-digest-fix-v0.7.4.sql`

Yeni bir Supabase projesi kurulacaksa SQL'ler körlemesine art arda çalıştırılmamalıdır; önce mevcut v0.8.2 kaynak kodunun beklediği RPC/tablo yapısı kontrol edilmelidir.

## F. Claude'a yüklerken güvenlik
Yüklenebilir:
- index.html
- migration SQL'leri
- JSON yedekler
- proje bağlam dokümanları
- ekran görüntüleri

Yüklemeyin:
- Supabase DB parolası
- service_role secret
- SMTP şifresi
- kullanıcı parolaları
- banka internet şubesi şifreleri

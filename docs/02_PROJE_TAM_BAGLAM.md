# NakitPilot / MT-PRO-Finans — Tam Proje Bağlamı

## 1. Amaç
NakitPilot, şirketin günlük finans hareketlerini, gelecekteki kesin gelir/giderlerini, tahminlerini, banka hesaplarını, kredi kartlarını, KMH'larını, fon/vadeli/yatırım varlıklarını, proje finansını ve nakit akışı projeksiyonunu tek uygulamada yönetmek için geliştirilmiştir.

Ana hedef, bir firma sahibinin “Bugün ne durumdayım, hangi ay para sıkışır, hangi ay rahatım, hangi ödeme/tahsilat nereden geçti ve gelecekte ne olacak?” sorularını tek ekrandan anlayabilmesidir.

## 2. Kullanım ve tasarım ilkeleri
- Kullanıcı yazılımcı değildir; kurulum/güncelleme mümkün olduğunca dosya yükleme + gerekirse SQL Editor'a kod yapıştırıp Run şeklinde olmalıdır.
- Arayüz sade, profesyonel ve kullanıcı dostu olmalıdır.
- Gelir/pozitif bakiye yeşil; gider/borç/eksi bakiye kırmızı; uyarı/sıkışıklık turuncu/sarı tonlarda gösterilir.
- Banka Merkezi gibi yoğun ekranlarda tüm formlar aynı anda gösterilmez; sekme/panel mantığı kullanılır.
- Finans grafikleri ilk bakışta işletme sahibinin anlayacağı kadar basit, isteğe bağlı veri katmanlarıyla daha profesyonel analizlere açılabilir olmalıdır.
- GitHub commit mesajı sadece yeni sürüm numarasıdır (örn. `v0.8.3`).
- HTML/uygulama güncellemesi paylaşılırken gereksiz görsel önizleme üretilmemelidir; dosya linki + kısa açıklama tercih edilir.

## 3. Mevcut uygulama mimarisi
- Tek HTML ağırlıklı web uygulaması (`index.html`).
- Vanilla JavaScript + CSS.
- Supabase JS v2 CDN üzerinden yüklenir.
- Supabase Auth ile kullanıcı girişi.
- Firma bazlı veri ayrımı ve rol kontrolü.
- Ana işletme verisi `company_data.data` JSONB içinde tutulur; uygulama `np_get_company_data` ve `np_save_company_data` RPC'leriyle okur/yazar.
- Banka merkezi migration'ı ayrıca normalize finans tablolarına snapshot/senkronizasyon yapısı sağlar.
- Yerel cache/localStorage vardır; asıl kalıcı veri Supabase bulutundadır.
- Proje dosyaları Supabase Storage `project-files` bucket'ında tutulabilir.

## 4. Mevcut sayfalar
Mevcut kodda sayfa isimleri:
- Özet Paneli
- AI Finans Asistanı
- Tamamlanmış Gelir/Gider Kayıt
- Gelecekteki Kesin Gelir/Gider
- Tahmini Gelir/Gider
- Banka Merkezi
- Kredi Kartları
- Proje Takip · Müşteri Görüşmeleri
- Proje Takip · Projeler
- Proje Takip · Teklif & Maliyet
- Proje Takip · Üretim Takibi
- Proje Takip · Dosyalar
- Proje Takip · Proje Finans Durumu
- Raporlar
- 5 Yıllık Plan
- Kategori Yönetimi
- Rapor İndirme
- Firma & Ekip
- Paket & Abonelik
- Yasal & Hesap
- Ayarlar
- İletişim / Destek
- Admin Paneli

## 5. Roller
Kodda temel roller:
- `admin` → Yönetici
- `accounting` → Muhasebe
- `engineer` → Mühendis / Proje
- `viewer` → Rapor Kullanıcısı

Önemli kullanım kararı: Muhasebe kullanıcısının Firma & Ekip sayfasını görmese bile üst bardaki firma seçicisinden yetkili olduğu firmalar arasında geçiş yapabilmesi gerekir.

Finans tarafında ayrıca granular izinler vardır:
- `view_banks`
- `manage_banks`
- `manage_credit_cards`
- `manage_overdrafts`
- `manage_investments`
- `make_transfers`
- `manage_income_expense`
- `download_reports`

## 6. Firma yapısı
- Bir kullanıcı birden fazla firmaya yetkili olabilir.
- Aktif firma üst bardan değiştirilebilir.
- Veriler firma bazında ayrılır.
- Firma oluşturma, ekip daveti, rol güncelleme ve üyelik işlemleri Supabase RPC'leriyle yürür.

## 7. Finans çekirdeği
### Tamamlanmış gelir/gider
- Gelir veya gider eklerken ödeme/tahsilat yöntemi seçilir.
- Banka hesabı, kredi kartı, nakit kasa, KMH veya çoklu yöntem kullanılabilir.
- İşlem geçmişinde tekli düzenleme/silme yanında çoklu seçim ve toplu silme mantığı bulunur.
- Silme/iptal işlemlerinde bağlı banka/kart/KMH etkileri geri alınmalıdır.

### Gelecekteki kesin gelir/gider
- Düzenli veya tek seferlik kesin kalemler.
- Kira, maaş, SGK, kredi, leasing, tek seferlik tahsilat vb.
- Kısmi ödeme/tahsilatla eşleştirilebilir.

### Tahmini gelir/gider
- Aylık tahmini kalemler.
- Dashboard projeksiyonunda kullanılır.

## 8. Banka Merkezi
Amaç: şirketin tüm banka varlık/borç ilişkisini tek yerde yönetmek.

Desteklenen öğeler:
- Bankalar
- Banka hesapları (TL/EUR/USD/Gram Altın vb.)
- Kredi kartları
- KMH
- Fon/vadeli/yatırım hesapları
- Hesaplar arası transfer / döviz dönüşümü
- Banka hareketleri ve raporlama

UX kararları:
- Banka kartına tıklanınca sayfa aşağı kaymamalı; modal detay penceresi açılmalıdır.
- Modalda bankaya bağlı hesaplar, kartlar ve KMH kayıtları görünür.
- Pozitif bakiyeler yeşil, negatif bakiyeler ve borçlar kırmızı olmalıdır.
- “Bankalar & Hesaplar / Transfer-Havale / Kredi Kartları / KMH / Fon-Vade-Yatırım / Tüm Hareketler” ana sekmeleri tasarımlı olmalıdır; ham gri HTML buton görünümü olmamalıdır.
- Alt formlar yalnız seçilen işlem için açılmalıdır; bir sekmeye tıklayınca başka sekmenin formu görünmemelidir.

## 9. Banka hesapları
Her banka altında birden fazla hesap bulunabilir:
- Vadesiz TL
- Vadesiz EUR
- Vadesiz USD
- Gram altın
- Birikim
- Vadeli mevduat
- Fon
- Yatırım
- Diğer

Temel alanlar:
- Banka
- Hesap adı
- Hesap türü
- Para/varlık türü
- Başlangıç/güncel bakiye
- Bloke tutar
- IBAN / hesap no
- Açılış tarihi
- Vade tarihi (yalnız ilgili hesap türlerinde)
- Faiz/getiri
- Stopaj
- Açıklama
- Durum

Vadesiz hesapta vade/faiz/stopaj alanları kullanılmamalı veya gizlenmelidir.

## 10. Kredi kartları
Alanlar:
- Banka
- Kart adı
- Son 4 hane
- Para birimi
- Toplam limit
- Güncel dönem borcu / açılış borcu
- Bekleyen provizyon
- Taksitli işlem toplamı
- Önceki dönem borcu
- Asgari ödeme
- Hesap kesim günü
- Son ödeme günü
- Bağlı ödeme hesabı
- Durum
- Açıklama

Kredi kartı seçim listelerinde kart adının yanında son dört hane görünmelidir.

Kart hareketleri silinebilir/düzenlenebilir olmalı; kart borç ödemesi silinirse banka hesabı ve kart borcu ters etkiyle doğru hesaplanmalıdır.

## 11. KMH
Alanlar:
- Banka
- KMH adı
- Bağlı banka hesabı
- Para birimi
- Toplam limit
- Güncel borç/kullanım
- Faiz oranı
- Son ödeme tarihi
- Faiz tahakkuk tarihi
- Durum
- Açıklama

KMH kullanımı banka hesabı normal bakiyesiyle karıştırılmamalıdır.

## 12. Transfer / havale
Transfer gelir/gider değildir; varlıklar arası harekettir.

Alanlar:
- Tarih
- Çıkan hesap
- Giren hesap
- Gönderilen tutar
- Alınan tutar
- Kullanılan kur
- Banka masrafı
- Vergi/komisyon
- Açıklama
- Referans
- Kâr/zarar

Transfer geçmişinde düzenleme ve iptal desteklenir. Düzenlemede eski transfer etkisi geri alınmalı, yeni değerler tek kez uygulanmalıdır.

## 13. Fon / vadeli / yatırım
Ana para transferi gelir/gideri şişirmemelidir. Gerçekleşen getiri/zarar, komisyon, vergi/stopaj ayrı finansal etki olarak işlenmelidir.

## 14. Dashboard ve nakit akışı
Özet Paneli banka + kasa + kart/KMH borçlarını tutarlı göstermelidir.

Nakit akışı/projeksiyon tercih edilen görünüm:
- Tamamlanmış Gelir
- Tamamlanmış Gider
- Gelecekteki Kesin Gelir
- Gelecekteki Kesin Gider
- Tahmini Gelir
- Tahmini Gider
- Ay sonu portföy/net likidite çizgisi

Grafik ilk bakışta kolay okunur olmalı; profesyonel ek katmanlar isteğe bağlı açılmalıdır.

v0.8.1 ile eklenen isteğe bağlı katmanlar:
- Aylık net nakit
- Gider bütçe sapması
- Güvenli tampon
- Sıfır çizgisi
- Risk bölgeleri
- Temkinli senaryo karşılaştırması
- Stres senaryosu karşılaştırması
- Büyük hareketli aylar

Her katmanın hover açıklaması, kullanıcıya “bunu açarsam ne görürüm ve nasıl yorumlarım?” sorusunun cevabını vermelidir.

v0.8.2 ile ayrıca:
- “Kredi kartı borçlarını hariç tut” alternatif projeksiyonu
- “KMH borçlarını hariç tut” alternatif projeksiyonu
eklendi.
Bunlar gerçek veriyi değiştirmez; sadece “borcu bugün tamamen kapatmazsam ne olur?” analizidir.

## 15. Döviz / TCMB
- TL/EUR/USD/Gram Altın varlıkları ayrı tutulur.
- TCMB satış kuru günlük otomatik sistemle kullanılır.
- Eski iş kuralı: güncel kur yaklaşık 15:35 sonrası; daha erken ise önceki yayın dikkate alınabilir.
- İşlem özelinde bankanın gerçek kuru farklıysa gerçek kur girilebilmelidir.
- Kur farkları doğru raporlanmalıdır.

## 16. Proje Takip
NakitPilot içinde proje takibi de bulunur:
- Müşteri görüşmeleri
- Projeler
- Teklif & maliyet
- Üretim takibi
- Proje dosyaları
- Proje finans durumu

Proje kodlama örneği `MTP26-x`.
Proje ödeme planı finans modülünde gelecekteki gelir kalemlerine aktarılabilir.

## 17. Raporlama
- Dashboard KPI'ları
- Gelir/gider dağılımları
- Dönemsel tahmin
- 5 yıllık plan
- Excel/CSV/HTML/JSON dışa aktarma
- Banka hareketi filtreleri
- Proje finans durumu

## 18. Yedekleme
- Uygulama içinden bulut yedek `company_backups` tablosuna alınabilir.
- Yasal & Hesap bölümünde JSON yedek dışa aktarımı vardır.
- JSON dışa aktarımı canlı şirket verisini Claude'a aktarmanın en doğru yöntemidir.

## 19. Bilinen Supabase düzeltmesi
Kredi kartıyla gelir/gider kaydı sırasında `function digest(text, unknown) does not exist` hatası görülmüştür.
Çözüm: pgcrypto `extensions` şemasında etkinleştirilmiş ve `np_sync_company_banking_snapshot(uuid,jsonb)` fonksiyonunun `search_path` değeri `public, extensions` olarak ayarlanmıştır.
Düzeltme SQL'i pakette `sql/nakitpilot-supabase-digest-fix-v0.7.4.sql` olarak bulunur.

## 20. Güncel sürüm
Bu aktarım paketinin baz aldığı uygulama sürümü: **v0.8.2**.

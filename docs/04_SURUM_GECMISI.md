# NakitPilot Sürüm Geçmişi — Bu konuşmadaki ana gelişmeler

## v0.5.23
- Muhasebe rolü için üst bardan aktif firma değiştirme ihtiyacı ele alındı.

## v0.6.0
- Banka Merkezi büyük kapsamlı mimari/migration.
- Banka, banka hesabı, kart, KMH, yatırım, transfer ve hareket altyapısı.

## v0.6.2–v0.6.5
- Banka Merkezi sadeleştirme ve görsel düzenlemeler.
- Dashboard banka/net varlık özetleri iyileştirildi.

## v0.6.6
- Tamamlanmış Gelir/Gider işlem geçmişine çoklu seçim ve toplu silme mantığı.

## v0.6.7–v0.6.8
- Banka/kart/KMH/hesap silme kontrolleri.
- Kredi kartı hareketlerinde silme/geri alma çıkmazı düzeltildi.

## v0.6.9
- Dashboard banka/kasa toplamlarının aynı finansal mantığa bağlanması.

## v0.7.0–v0.7.1
- Banka Merkezi sekmeli/panel kullanımına geçirildi.
- Aynı anda ilgisiz formların açılması hataları temizlendi.

## v0.7.2
- Banka kartına tıklayınca hesap/kart/KMH detay modalı.

## v0.7.3
- Ödeme hesabı listesinde kredi kartı adının yanında son 4 hane gösterimi.

## v0.7.4
- Banka detay modalının tekrar doğru çalışması.
- Ham/gri sekme görünümünün düzeltilmesi.
- Supabase `digest()` hatası için `pgcrypto` / search_path düzeltmesi uygulandı.

## v0.7.5
- Transfer geçmişinde düzenleme; eski etkinin geri alınarak yeni transferin tek kez uygulanması.

## v0.7.6
- Bankalar ve Hesaplar listesinin profesyonel kart görünümüne geçirilmesi.

## v0.7.7
- Pozitif bakiyelerin yeşil, borç/eksi bakiyelerin kırmızı gösterilmesi.

## v0.7.8
- Nakit Akışı / Likidite Riski / Portföy Projeksiyonu yönetim görünümü.

## v0.7.9
- Profesyonel senaryo analizi ve likidite yönetim paneli denendi; kullanıcı için fazla karmaşık bulundu.

## v0.8.0
- Likidite paneli sadeleştirildi.

## v0.8.1
- Kullanıcının daha anlaşılır bulduğu eski ana grafik mantığı profesyonel katmanlı yapıyla geri getirildi:
  gerçekleşen/gelecek kesin/tahmini gelir-gider + ay sonu portföy çizgisi.
- İsteğe bağlı analiz katmanları ve hover açıklamaları eklendi.

## v0.8.2
- Projeksiyon için “kredi kartı borçlarını hariç tut” ve “KMH borçlarını hariç tut” alternatif görünüm seçenekleri.
- Bu seçenekler yalnız analiz içindir, gerçek borçları silmez/değiştirmez.

## v0.8.3
- Sabit/gelecek kalem düzenlemesinde para birimi, kur ve TL karşılığının (`amountTry`)
  güncellenmemesi hatası giderildi. Düzenleme artık `withMoneyMeta()` üzerinden geçiyor.
- Düzenleme penceresindeki kur doğrulaması ekleme formunun alanlarını okuyordu; kendi
  alanlarını okuyacak şekilde düzeltildi.
- Sabit/gelecek kalem düzenleme penceresine Para Birimi ve Kur alanları eklendi; döviz
  kalemlerin kayıt kuru artık düzenlenebiliyor.
- Veri yüklenirken TL kayıtlarda `amountTry` alanı `amount` ile eşitlenerek eski
  sürümlerden kalan sapmalar otomatik onarılıyor.
- Tüm firmalar için işlem verisi sıfırlama script'i eklendi
  (`sql/nakitpilot-veri-sifirlama-v0.8.3.sql`); tanımlar ve Proje Takip korunur.

## v0.9.0
- Proje Takip: maliyet çalışmasına kalem bazlı detay eklendi (grup, açıklama, adet,
  birim, ağırlık, birim fiyat, tedarikçi). Kalem girilince toplam maliyet otomatik
  hesaplanır; kalem girilmezse eski tek tutarlı çalışma korunur.
- "Tahsilat Tamamlandı" proje durumu eklendi.
- Statü geçiş kuralları: ret nedeni, takip tarihi, teslim tarihi ve irsaliye
  girilmeden ilgili duruma geçilemiyor; geri alma onay istiyor ve loglanıyor.
- Proje hareket geçmişi eklendi: durum, maliyet ve teklif değişiklikleri tarih ve
  kullanıcı bilgisiyle saklanıyor.

## v0.9.1
- Teklif çıktısı kurumsal belge olarak baştan yazıldı: markalı kapak, bölümlenmiş
  sayfalar ve A4 yazdırma düzeni.
- İki şablon eklendi: "Teknik ve Ticari Teklif (proje)" ve "Ürün / Yedek Parça Teklifi".
- Teklife çok satırlı POZ fiyat tablosu eklendi; tutar kalemlerden hesaplanıyor.
- Müşteri iletişim bilgileri, konu, talep no, hazırlayan, teslim yeri, proje
  başlangıç şartı ve garanti süresi alanları eklendi.
- Kurumsal metinler (firma tanıtımı, kapsam dışı işler, garanti maddeleri,
  sipariş formu ile kabul) koda gömüldü; belgeye dahil edilmesi seçimlik.

## v0.9.2
- Fatura kaydı eklendi: no, tarih, tutar, para birimi, kur, KDV, vade.
- Tahsilat kaydı eklendi: faturaya bağlı, kısmi tahsilat destekli, kalan alacak
  otomatik hesaplanır.
- Vade takibi: gecikmiş / vadesi yaklaşan faturalar için Özet Paneli ve Proje
  Finans Durumu ekranında uyarı kartı.
- Otomatik durum geçişleri: ilk fatura ile "Faturalandırıldı", alacak sıfırlanınca
  "Tahsilat Tamamlandı".
- Geçiş kuralları: fatura olmadan faturalandırılamaz, alacak kapanmadan tahsilat
  tamamlanamaz.
- Teklif belgesine örnek proje görseli eklenebiliyor; görsel Storage'da kalır,
  yalnız yazdırma anında belgeye gömülür ve sayfa düzenini bozmaz.
- Teklif kapağı için kurumsal logo desteği.

Güncel baz sürüm: **v0.9.2**

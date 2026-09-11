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

## v0.9.3
- Teklif belgesinin kapağına Marmara Teknik kurumsal logosu eklendi; logo belgeye
  gömülü taşınır, kaydedilen PDF'te de görünür.
- Kapak bilgi tablosunda sağ sütunu boş kalan satırlardaki boş kutu giderildi.

## v0.9.4
- Uygulama ve teklif belgesi renk paleti Marmara Teknik logosunun renklerine göre
  yeniden kuruldu: ana renk lacivert #2E4F6E, sol menü #142D48, vurgu çelik mavi
  #7FA8CC, zeminler soğuk gri.
- PWA simgeleri, favicon ve tema renkleri logo gradyanıyla güncellendi.
- Anlam taşıyan renkler korundu: gelir yeşil, gider/borç kırmızı, uyarı turuncu.

## v0.9.5
- Proje kodu (örn. MTP26-1) sistem genelinde takip anahtarı hâline getirildi.
- Teklif fiyat tablosundaki açıklama sütunu varsayılan olarak proje kodunu gösterir.
- Teklif penceresinde ilk kalem proje koduyla dolu açılır.
- Fatura ve tahsilat açıklamaları proje koduyla ön doldurulur; kayıtta kod yoksa
  başa eklenir, varsa tekrar eklenmez. Kayıtlara ayrıca projectCode alanı yazılır.

## v0.9.6
- Proje ile finans modülü birbirine bağlandı. Proje tahsilatı artık şirketin
  gelir defterine yazılıyor, seçilen banka hesabına işliyor ve ödeme planındaki
  beklenen gelir kalemini kapatıyor.
- Tahsilat formuna "Tahsil Edilen Hesap" ve "Ödeme Planı Kalemi" alanları eklendi.
- Tahsilat düzenlenince bağlı gelir güncelleniyor, silinince geri alınıyor.
- Ödeme planı oluşturulurken durum değişikliği artık geçiş kurallarından geçiyor.

## v0.10.0
- ERP temeli: sistem altı modüle bölündü (Finans, Proje, Satın Alma, Cari,
  Yönetim Raporları, Sistem).
- Üç seviyeli izin: her kullanıcının her modülde erişim yok / görüntüleme /
  düzenleme seviyesi olabilir. Seviye kullanıcı iznine, yoksa rol varsayılanına bakar.
- Firma & Ekip sayfasına "Modül Yetkileri" matrisi eklendi.
- "Satın Alma" rolü eklendi (sql/nakitpilot-satinalma-rolu-v0.10.0.sql).
- Firma & Ekip ve Yasal sayfaları için yetki sıkılaştırıldı.

## v0.11.0
- Satın Alma modülü eklendi: Tedarikçiler, Satın Alma Siparişleri,
  Tedarikçi Faturaları ve Ödemeler.
- Otomatik sipariş kodu (SA26-1), çok satırlı kalem tablosu, mal kabul ve
  teslim oranı takibi.
- Finans entegrasyonu: tedarikçi faturası gelecekteki kesin gider oluşturur,
  ödeme tamamlanmış gider oluşturup bankadan düşer ve beklenen gideri kapatır.
- Projeye bağlanan tedarikçi faturaları projenin gerçek maliyetini oluşturur.

## v0.12.0
- Cari Hesaplar modülü: Alacaklar ve Borçlar ekranları.
- Alacak müşteri bazında (proje faturaları − tahsilatlar), borç tedarikçi
  bazında (tedarikçi faturaları − ödemeler) otomatik hesaplanır.
- Yaşlandırma: Vadesi Gelmedi / 1-30 / 31-60 / 61-90 / 90+ gün.
- Yönetim Raporu modülü: Yönetici Paneli.
- Sekiz özet kart (pipeline, geciken proje, tahsil edilecek, ödenecek,
  teklif onay oranı, onaylanan ciro) ve proje kârlılığı tablosu.
- Kârlılık tablosunda tahmini maliyet (maliyet çalışması) ile gerçek maliyet
  (projeye bağlı tedarikçi faturaları) yan yana; gerçek kâr ve marj hesaplanır.
- Her iki modül salt okunurdur; veri kaynağı proje ve satın alma kayıtlarıdır.

## v0.13.0
- Sol menü modül başlıkları altında gruplandı (akordiyon); 30 buton yerine
  8 başlık. Aktif sayfanın grubu otomatik açılır, yetkisiz grup gizlenir.
- Satın alma siparişlerine kalıcı **SAP No**: projeye bağlıysa proje kodundan
  (MTP26-1-SAP1), projesizse genel koddan (GEN26-SAP1) üretilir.
- SAP No bir kez verilir ve düzenlemede asla değişmez (tedarikçi faturası bu
  numaraya kesilir).
- "Genel Satın Alma (projesiz)" seçeneği: proje bilinmeden acil sipariş açılır,
  sonradan düzenlenerek projeye bağlanır.
- Sonradan projeye bağlanan siparişin faturaları yeni projenin gerçek
  maliyetine taşınır; gelecekteki gider ve ödeme kayıtları yenilenir.
- Faturada proje boşsa bağlı olduğu siparişin projesi devralınır.
- A4 / PDF **Satın Alma Sipariş Formu** (logo, SAP No, proje kodu, tedarikçi,
  kalem tablosu, imza alanları).
- Fatura girişinde sipariş seçilince tedarikçi, proje, para birimi ve kur
  otomatik dolar.
- Mobil: sol menü çekmece oldu (☰), formlar tek sütuna iner, tablolar kendi
  içinde kaydırılır, sayfalarda yatay taşma yok.

## v0.14.0
- Sipariş formuna 19 maddelik **Satın Alma Genel Şartları** (alıcıyı koruyan
  hukuki metin) ayrı sayfa olarak eklendi; teklif formuna 7 maddelik
  **Teklif Talep Şartları**.
- Şartlardaki sayılar (teyit 2 iş günü, gecikme cezası günlük ‰1 / en çok %10,
  muayene 10 iş günü, garanti 24 ay, mücbir sebep 30 gün, yetkili mahkeme)
  MT_PO_TERM_VALUES sabitinden tek yerden değiştirilebilir.
- Tedarikçi (cari) kartına **Ödeme Vadesi (gün)** alanı; sipariş formunda
  "fatura tarihinden N gün · tahmini vade GG.AA.YYYY" olarak yazar.
- Siparişe özel vade alanı cari vadesini ezebilir.
- Tedarikçi faturasında vade tarihi cari vadesinden otomatik hesaplanır;
  elle girilen vade korunur.
- **Teklif isteme akışı**: yeni "Teklif İstendi" durumu. Talep/Teklif İstendi
  durumlarında fiyat zorunlu değildir; form fiyatsız **Teklif Talep Formu**
  olarak basılır (tutar sütunları tedarikçinin doldurması için boş).
- Teklif gelince aynı kayıt düzenlenip fiyatlar girilir, durum "Sipariş
  Verildi" yapılır ve genel şartlı sipariş formu basılır. **SAP No değişmez.**
- "Sipariş Verildi" ve sonrası durumlarda fiyatsız kayıt engellenir.

## v0.14.1
- Düzeltme: teklif talep formu cari kartındaki ödeme vadesini yazmıyordu,
  sabit olarak "Teklifinizde belirtiniz" basıyordu. Artık cari vadesi yazılır.
- Sipariş ekranındaki "Ödeme Vadesi (gün)" alanı, tedarikçi seçilince cari
  kartındaki vadeyle otomatik dolar; elle farklı gün yazılırsa yalnız o
  sipariş için geçerli olur.
- Vade cari ile aynıysa siparişe kaydedilmez; cari kartı güncellenince
  varsayılan vadeli tüm siparişler yeni vadeyi kullanır.
- Form üstündeki açıklama vadenin cariden mi yoksa siparişe özel mi
  geldiğini söyler.

## v0.14.2
- Tüm modüller demo veriyle uçtan uca test edildi (464 senaryo); bulunan
  8 hata düzeltildi.
- **Teklif penceresi açılmıyordu**: `_quoteBaseline` tanımsızdı, sayfa
  açıldıktan sonraki ilk teklif açılışında ReferenceError veriyordu.
- **Üretim Takibi ekranı geçiş kurallarını atlıyordu**: durum doğrudan
  atanıyor, irsaliye/fatura/tahsilat şartı denetlenmiyor ve hareket geçmişine
  yazılmıyordu. Artık `applyProjectStatusChange` üzerinden geçer; aşama ve not
  değişiklikleri de geçmişe yazılır.
- **Durum eşitlemesi iki yönlü oldu**: tahsilat silinir/azaltılır veya yeni
  fatura eklenirse proje "Faturalandırıldı"ya geri döner; son fatura silinirse
  "Teslim Edildi"ye döner.
- **Fazla tahsilat/ödeme engellendi**: proje tahsilatı faturanın kalanını,
  tedarikçi ödemesi faturanın kalan borcunu aşamaz.
- **Yönetici panelinde yanıltıcı kâr**: gerçek maliyeti girilmemiş projede
  "gerçek kâr = satış, marj %100" yerine "ölçülemiyor" gösterilir.
- **Proje kodu açıklamaya iki kez yazılıyordu**: proje değişince otomatik kod
  yenilenir, kullanıcı metni korunur; kod eşleşmesi sınır duyarlı oldu.
- **Talep aşamasındaki siparişte "Mal Kabul"** butonu kaldırıldı.
- **Raporlardaki "Toplam Portföy"** etiketi "Kasa Portföyü · banka hesapları
  hariç" olarak netleştirildi (hesap değişmedi).
- Liste ekranlarında işlem butonları için sütun genişletildi; boş vade ipucu
  satırı gizlendi.

## v0.15.0
- Yeni ekran: **Ayarlar > Kişi Kartları**. Ad soyad, unvan, e-posta, telefon,
  cep ve not. E-posta, giriş yapan kullanıcıyla eşleştirme için kullanılır.
- Kendi kartını herkes düzenler; başkasının kartını ve silmeyi yalnız yönetici
  yapar. Teklif veya siparişte geçen kart silinemez.
- Teklif penceresine ve satın alma sipariş formuna **Sorumlu Kişi** seçimi
  eklendi. Varsayılan olarak işlemi yapan kullanıcının kartı gelir; listeden
  başka bir kişi seçilirse ad, telefon ve e-posta ona göre değişir.
- Teklif PDF'inde "Hazırlayan" artık unvanla birlikte, iletişim bilgileri
  seçilen kişinin bilgileri olarak basılır; imza kutusundaki ad da odur.
- Sipariş ve teklif talep formunda "Sorumlu Kişi" / "Talep Eden" satırı ve
  imza kutusunda kişinin unvanı, telefonu ve e-postası yer alır.
- Kart seçilmezse firma varsayılanları basılır (eski davranış korunur).
- Düzeltme: imza kutusundaki sabit yükseklik kişi bilgileriyle taşıyordu.

Güncel baz sürüm: **v0.15.0**

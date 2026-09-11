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

## v0.15.1
- Kişi kartında telefon ikiye ayrıldı: **Sabit Telefon (firma)** ve
  **Cep Telefonu**. Yeni kartta sabit telefon 0262 666 00 00 hazır gelir.
- Belgelerde sorumlu kişinin **cep** numarası yazar (teklifte "CEP TELEFONU"
  satırı, sipariş/talep formunda "Cep: ..."); cep boşsa sabit numaraya düşer.
- Belge künyesi yeni sıraya getirildi ve **firma sabit telefonu** eklendi:
  unvan · şehir · web · 0262 666 00 00.
- Teklif PDF'inde künye artık imza sayfasının en altında da basılıyor.
- MT_COMPANY.phone firma santral numarası olarak güncellendi.

## v0.16.0
- Sol menüye **Kullanım Kılavuzu** eklendi (Özet Paneli'nin altında, tüm
  rollerde görünür).
- Sayfanın üstünde yapışkan **arama çubuğu**: kelime yazıldıkça ilgisiz
  konular gizlenir, eşleşen kelime vurgulanır. Türkçe karakter ve büyük/küçük
  harf duyarsız (ırsalıye = İRSALİYE). "3 / 38 konu" sayacı ve 12 başlıklı
  içindekiler.
- İçerik: 12 bölüm, 38 konu, 24 ekran görüntüsü, 95 numaralı adım, 60 görsel
  üstü işaretli açıklama, 3 akış şeması, 31 dikkat/ipucu kutusu.
- Bölümler: başlarken · ilk kurulum · günlük finans · proje süreci (10 adım) ·
  satın alma · cari hesaplar · yönetim raporu · kişi kartları · yetkiler ·
  mobil · uyarı mesajlarının anlamı · altın kurallar.
- Kılavuz görselleri `guide/` klasöründe tutulur ve yalnız kılavuz açıldığında
  indirilir; otomatik yayın akışına bu klasör eklendi.

## v0.17.0
- Sol menüye **Mühendislik** başlığı eklendi (Proje Takip ile Satın Alma
  arasında). Tasarım ve maliyet çalışmasında kullanılan araçlar buraya gelecek.
- İlk araç: **Ağırlık Hesaplama**. 12 kesit tipi (sac, lama, kare/yuvarlak
  dolu, boru, kutu profil kare ve dikdörtgen, altıgen, köşebent, U, T, I/H),
  24 malzeme ve özel yoğunluk girişi.
- Her kesit için ölçü harflerini gösteren şema; kesit alanı, kg/m, parça ve
  toplam ağırlık ile hesabın adım adım açıklaması.
- Hesap listesi: birden çok kalem, toplam ağırlık, TL/kg fiyatıyla tutar ve
  panoya kopyalama.
- Et kalınlığı dış ölçüyü aşarsa, uzunluk veya yoğunluk boşsa hesaplama
  yapılmaz. L/U/T/I profillerde radyus ihmali ekranda belirtilir.
- Yetki: tüm roller kullanabilir; düzenleme seviyesi yönetici ve mühendiste.
- Kullanım kılavuzuna "Mühendislik araçları" bölümü eklendi (13 bölüm,
  39 konu, 25 görsel).

## v0.18.0
- Mühendislik başlığının altına **Standart Ekipmanlar** bölümü eklendi; içinde
  iki kütüphane var: **Hazır CAD Datalar** ve **Kataloglar**.
- Hazır CAD Datalar ilk açılışta beş hazır başlıkla gelir: Yataklı Rulmanlar
  CAD, Doğuş Kalıp CAD, Alhan CAD, Emes Teker CAD, Surfence CAD. Bu başlıklar
  bir kez oluşturulur; silinirse geri gelmez.
- Kullanıcı **kendi klasörlerini** istediği kademede açabilir
  (Yataklı Rulmanlar CAD › UCF Serisi › UCF205). Kök seviyede klasör açmak yeni
  bir kütüphane başlığı demektir; sistem böylece kullanıcı tarafından
  çoğaltılabilir.
- Her klasöre **dosya yüklenebilir** (STEP, STP, DWG, DXF, IGES, PDF, resim;
  birden fazla dosya aynı anda). Mühendis **⬇️ İndir** ile dosyayı doğrudan
  indirir; PDF ve resimlerde **👁** yeni sekmede açar. Dış bağlantı adresi de
  kaydedilebilir.
- Yol çubuğu (breadcrumb), üst klasör butonu, klasör içi sayımlar
  (kaç klasör / kaç dosya), dosya türü ikonları ve boyut gösterimi.
- **Arama**: klasör adı, dosya adı ve notlar içinde kütüphanenin tamamında
  arar; sonuçta dosyanın hangi klasörde olduğu yazar.
- Yeniden adlandırma ve silme. Dolu klasör silinmez (veri kaybı koruması);
  dosya silindiğinde Storage'dan da kaldırılır.
- Yetki: Mühendislik modülünde **görüntüleme** yetkisi olan herkes indirir,
  **düzenleme** yetkisi olan klasör açar, yükler ve siler.
- Veri `company_data.data.stdlib` içinde, dosyalar Supabase Storage
  `project-files` bucket'ında `<firmaId>/stdlib/<kütüphane>/...` yolunda durur.
  Bucket politikaları yolun ilk parçasındaki firma kimliğine baktığı için
  **ek SQL gerekmez**.
- Kullanım kılavuzuna "Standart Ekipmanlar" konusu eklendi (13 bölüm, 40 konu).

## v0.19.0
- Standart Ekipmanlar kütüphanelerine **klasörün tamamını yükleme** eklendi.
  Tarayıcının klasör seçicisiyle (webkitdirectory) seçilen klasör, **alt klasör
  yapısı korunarak** sisteme aktarılır; eksik klasörler `webkitRelativePath`
  üzerinden otomatik oluşturulur.
- Yükleme sırasında ilerleme çubuğu: kaçıncı dosya, yüzde, aktarılan/toplam
  boyut ve yeterli örnek toplanınca tahmini kalan süre. Her 20 dosyada bir
  kayıt ve liste yenilenir.
- **⛔ Yüklemeyi Durdur**: o ana kadar yüklenenler kalıcıdır. Aynı klasör aynı
  yerde tekrar seçilirse yüklenmiş dosyalar (ad + boyut aynıysa) atlanır ve
  yükleme kaldığı yerden devam eder — büyük kütüphaneler birkaç oturumda
  yüklenebilir.
- Başlamadan önce kaç dosya, kaç MB ve hangi klasöre yükleneceği onaya sunulur;
  1 GB üstü yüklemelerde ek uyarı gösterilir.
- 50 MB üstü dosyalar atlanır ve sonunda adlarıyla listelenir. Thumbs.db,
  desktop.ini, .DS_Store gibi sistem dosyaları alınmaz.
- Tek dosyadaki hata yüklemeyi durdurmaz; hata sayısı ve son hata özette
  bildirilir. Arka arkaya 10 hatada yükleme kendiliğinden durur.
- Düzeltme: `.pro-grid .form-action .btn` kuralı `display:flex !important`
  olduğu için satır içi `display:none` çalışmıyordu; gizleme artık
  `.stdlib-gizli` sınıfı ile yapılıyor.
- Kullanım kılavuzunun "Standart Ekipmanlar" konusuna klasör yükleme adımları
  eklendi.

## v0.20.0
- **Yeni kullanıcı kaydı ve yönetici onayı akışı eklendi.** Giriş ekranı artık
  iki sekmeli: *Giriş Yap* ve *Kayıt Ol*. Kayıt formunda ad soyad, e-posta,
  telefon ve iki kez şifre istenir; ad ve telefon kullanıcı bilgisine yazılır,
  doğrulama maili uygulamanın adresine döner.
- Hesap açan kullanıcı bir firmaya bağlı değilse **üyelik talebi** ekranı gelir:
  firma seçer, istediği rolü, adını, telefonunu ve notunu yazıp talep gönderir.
  Talep beklerken durum, tarih ve *Talebi Geri Çek* düğmesi görünür;
  *Onaylandı mı? Kontrol Et* ile yetki yeniden sorgulanır. Reddedilen kullanıcı
  yöneticinin yazdığı sebebi görür ve yeniden talep gönderebilir.
- Firma & Ekip ekranına **Üyelik Talepleri** kartı eklendi: bekleyen talepler
  ad, e-posta, telefon, not ve istenen rolle listelenir; yönetici rolü seçip
  onaylar veya sebep yazarak reddeder. Karara bağlanan talepler geçmiş
  tablosunda kalır. "Yeni üyelik taleplerine açık" anahtarıyla firma talebe
  kapatılabilir.
- **Davet akışı düzeltildi:**
  - Davet rolleri eksikti; artık beş rol de seçilebiliyor (Rapor Kullanıcısı,
    Muhasebe, Mühendis/Proje, Satın Alma, Yönetici). Sunucudaki
    `np_invite_member` ve `np_update_member_role` fonksiyonları `engineer` ve
    `purchasing` rollerini sessizce `viewer` yapıyordu; düzeltildi.
  - Davet jetonu tarayıcıda saklanıyor. E-posta doğrulaması gibi araya giren
    yönlendirmelerde adresteki `?invite=` kaybolsa bile davet uygulanıyor.
  - Davet bağlantısıyla gelen kişiye giriş ekranında açıklayıcı bir bant
    gösteriliyor; "Mail ile Gönder" düğmesi hazır metinle mail açıyor.
  - Aynı e-postaya ikinci davet açılırsa eski davet iptal ediliyor; zaten üye
    olan bir e-posta davet edilemiyor; geçersiz e-posta reddediliyor.
  - Firma sahibinin yönetici yetkisi artık geri alınamıyor.
- Rol etiketlerinde eksik olan **Satın Alma** rolü eklendi (ekip listesi ve rol
  değiştirme kutusu).
- Supabase: `sql/nakitpilot-uyelik-onay-v0.20.0.sql` tek parça çalıştırılmalıdır
  (join_requests tablosu, companies.allow_join_requests kolonu, 9 RPC ve rol
  kısıtı düzeltmesi). Dosya iki kez çalıştırılabilir, veriye dokunmaz.

Güncel baz sürüm: **v0.20.0**

# Google Play — Veri Güvenliği formu cevapları

Formu Play Console → Politika → Uygulama içeriği → Veri güvenliği yolundan doldur.
Bu cevaplar uygulamanın **gerçekte** yaptığı işe göre yazıldı (kendi analitiğimiz yok,
sunucumuz yok; tek veri toplayan bileşen Google Mobile Ads SDK'sıdır).

## Genel
| Soru | Cevap |
|---|---|
| Uygulaman kullanıcı verisi topluyor veya paylaşıyor mu? | **Evet** (reklam SDK'sı nedeniyle) |
| Toplanan tüm veriler aktarım sırasında şifreleniyor mu? | **Evet** |
| Kullanıcılar verilerinin silinmesini isteyebiliyor mu? | **Evet** — uygulamayı kaldırmak yerel veriyi siler; reklam kimliği işletim sistemi ayarlarından sıfırlanabilir |
| Play Families politikasına tabi mi? | **Hayır** (hedef kitle 13+) |

## Veri türleri
Yalnızca **tek bir** kalem işaretlenir:

### Cihaz veya diğer kimlikler (Device or other IDs)
| Alan | Cevap |
|---|---|
| Toplanıyor mu? | **Evet** |
| Paylaşılıyor mu? | **Evet** (Google AdMob / reklam ağları ile) |
| İşlenme amacı | **Reklamcılık veya pazarlama** |
| Zorunlu mu, isteğe bağlı mı? | **İsteğe bağlı** — AEA/BK'de kullanıcı onayına tabidir, iOS'ta ATT ile reddedilebilir |
| Kullanıcı kimliğiyle ilişkilendiriliyor mu? | **Evet** (kişiselleştirilmiş reklam için) |
| Geçici mi? | Hayır |

### İşaretlenmeyecekler (uygulama bunları toplamıyor)
Konum · Kişisel bilgiler · Finansal bilgiler · Sağlık · Mesajlar · Fotoğraf/Video ·
Ses · Dosyalar · Takvim · Kişiler · Uygulama etkinliği · Web geçmişi · Uygulama bilgileri ve performansı

> **Satın alma geçmişi neden işaretlenmiyor?** "Remove Ads" satın alması tamamen Google Play
> Faturalandırma tarafından işlenir; uygulama ödeme verisine erişmez ve saklamaz.
> Google Play'in kendi işlediği veriler geliştirici beyanına dahil edilmez.

> **Uyarı:** AdMob'a mediation (AppLovin, Unity Ads, ironSource vb.) eklersen bu form değişir —
> yeni ağın veri toplama beyanını eklemen gerekir. v1.0'da mediation yok.

# App Store Connect — App Privacy (gizlilik etiketi) cevapları

App Store Connect → Uygulaman → App Privacy → Get Started.

## 1. "Do you or your third-party partners collect data from this app?"
**Yes**

## 2. Toplanan veri türleri

### Identifiers → Device ID
| Alan | Cevap |
|---|---|
| Kullanım amacı | **Third-Party Advertising** |
| Kullanıcı kimliğine bağlı mı? (Linked to You) | **Hayır** |
| İzleme için kullanılıyor mu? (Used for Tracking) | **Evet** |

### Usage Data → Advertising Data
| Alan | Cevap |
|---|---|
| Kullanım amacı | **Third-Party Advertising**, **Analytics** |
| Kullanıcı kimliğine bağlı mı? | **Hayır** |
| İzleme için kullanılıyor mu? | **Evet** |

### Diagnostics → Crash Data / Performance Data
**İşaretleme.** Uygulamada kendi çökme raporlama aracımız yok.
(Apple'ın kendi topladığı çökme verisi beyana dahil edilmez.)

## 3. Seçilmeyecek kategoriler
Contact Info · Health & Fitness · Financial Info · Location · Sensitive Info ·
Contacts · User Content · Browsing History · Search History · Purchases · Other Data

> **Purchases neden yok?** StoreKit satın almayı Apple işler, uygulama satın alma
> geçmişini toplamaz veya saklamaz.

## 4. App Tracking Transparency
- `NSUserTrackingUsageDescription` Info.plist'te tanımlı (metin `native/ios.md` içinde).
- Kullanıcı reddederse IDFA kullanılmaz, reklamlar kişiselleştirilmez, oyun tam çalışır.
- **"Used for Tracking = Yes" işaretlediğin için ATT istemi göstermek zorunludur** — uygulama gösteriyor.

> **Uyarı:** Mediation eklersen bu etiket de güncellenmelidir.

# iOS derleme — adım adım

Gereken: macOS, Xcode (son sürüm), CocoaPods, Apple Developer üyeliği.

## 1. Projeyi hazırla
```bash
npm install
npx cap add ios
npx cap sync ios     # pod install'u da çalıştırır
npx cap open ios
```

## 2. Xcode → App hedefi → General
- **Display Name:** `Orbita`
- **Bundle Identifier:** `com.kusgrup.orbita`
- **Version:** `1.0.0` · **Build:** `1`
- **Supported Destinations:** yalnız **iPhone** (iPad'i kaldır — yoksa App Store iPad ekran görüntüsü ister)
- **Device Orientation:** yalnız **Portrait**
- **Minimum Deployments:** iOS 14.0

## 3. Signing & Capabilities
- Team'i seç, "Automatically manage signing" açık
- `+ Capability` → **In-App Purchase** ekle

## 4. Simge ve açılış ekranı
- `assets/icon-1024.png` → Xcode `Assets.xcassets` → `AppIcon` (tek kutu, 1024×1024)
- `assets/splash-2732.png` → `Assets.xcassets` → `Splash` (üç boyuta da aynı dosya verilebilir)

## 5. `ios/App/App/Info.plist` — eklenecek anahtarlar
```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-3940256099942544~1458002511</string>

<key>NSUserTrackingUsageDescription</key>
<string>Your choice here only affects how relevant the ads in Orbita are. The game itself works exactly the same either way.</string>

<key>ITSAppUsesNonExemptEncryption</key>
<false/>

<key>UIRequiresFullScreen</key>
<true/>

<key>UISupportedInterfaceOrientations</key>
<array>
  <string>UIInterfaceOrientationPortrait</string>
</array>

<key>SKAdNetworkItems</key>
<array>
  <dict><key>SKAdNetworkIdentifier</key><string>cstr6suwn9.skadnetwork</string></dict>
  <!-- Buraya Google'ın güncel tam listesini yapıştır:
       https://developers.google.com/admob/ios/quick-start#update_your_infoplist
       Liste eksik olursa reklam gelirin düşer, uygulama reddedilmez. -->
</array>
```
> `GADApplicationIdentifier` şu an **test** kimliğidir. Gerçek AdMob hesabın açılınca
> hem burayı hem `www/index.html` içindeki `CFG.ads.real.ios` alanını doldur ve `useTest: false` yap.

> `ITSAppUsesNonExemptEncryption = false` sayesinde her yüklemede ihracat uyumluluğu sorusu sorulmaz.
> Bu doğru bir beyandır: uygulama yalnızca işletim sisteminin standart HTTPS'ini kullanır.

## 6. Arşivle ve gönder
- Xcode → Product → **Destination: Any iOS Device (arm64)** → **Archive**
- Organizer → **Distribute App** → App Store Connect → Upload
- App Store Connect'te build işlendikten sonra (10-30 dk) sürüme ekle

## 7. Gerçek cihazda test
- Reklamlar "Test Ad" etiketiyle görünmeli
- IAP testi için App Store Connect → Users and Access → **Sandbox Tester** hesabı oluştur,
  cihazda Ayarlar → App Store → Sandbox Account ile giriş yap

## Sık karşılaşılan hatalar
| Belirti | Sebep / çözüm |
|---|---|
| Build "GADApplicationIdentifier missing" diye çöküyor | Info.plist anahtarı eklenmemiş |
| ATT istemi hiç çıkmıyor | iOS Ayarlar → Gizlilik → İzleme → "Uygulamaların istemesine izin ver" kapalı olabilir; ayrıca istem uygulama başına yalnız bir kez gösterilir (silip yeniden kur) |
| Reddedilme: "Guideline 3.1.1 — IAP" | "Remove Ads" ürünü App Store Connect'te oluşturulmamış veya incelemeye gönderilmemiş. Ürünü ilk sürümle birlikte gönder |
| Reddedilme: "Guideline 2.1 — Information Needed / IDFA" | App Store Connect'te IDFA kullanımı beyan edilmemiş. `store/app-store.md` formuna bak |

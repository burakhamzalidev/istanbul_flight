# iOS TestFlight beta hazırlığı: İstanbul Flight 1.0.0 (Görev 9)

> Not: Bu numara `11_halic_gercek_referans.md` ile aynı; dosya adı görevde istendiği gibi bırakıldı.
> Kontrol listesi: [IOS_TESTFLIGHT_CHECKLIST.md](../IOS_TESTFLIGHT_CHECKLIST.md) · beta metinleri: [testflight/beta_materials.md](testflight/beta_materials.md) · genel yayın hazırlığı: [10_android_ios_release_readiness.md](10_android_ios_release_readiness.md)

## Özet: dört ayrı durum

| Durum | Sonuç |
|---|---|
| **Hazır** (kod, yapılandırma, belge) | **Evet.** iOS yapılandırması, Codemagic iş akışları, beta metinleri ve test planı hazır. Analiz temiz, 98/98 test geçiyor |
| **Gerçekten derlendi** (iOS) | **Evet (22 Ekim 2026).** Codemagic `ios-ipa` derleme #1 başarılı: imzalı `Istanbul_Flight.ipa` (23,2 MB), 1.0.0 (1), `com.burakhamzali.istanbulFlight`, iOS 15.0. Yerelde derlenmedi (Windows) |
| **TestFlight'a yüklendi** | **Evet (22 Ekim 2026, onayınla).** Codemagic `ios-testflight` derleme #2: 1.0.0 (1) App Store Connect'e ulaştı, "Processing". Apple'ın son durum çağrısındaki geçici 500 yüzünden Codemagic "failed" gösteriyor. Yalnızca dahili test; henüz test grubu yok |
| **Cihazda test edildi** | **Hayır.** 20 senaryonun hepsi NOT RUN. FPS ve bellek **ölçülmedi** |

App Store dağıtım imzalı IPA Codemagic'te **oluşturuldu**; App Store Connect'e **yüklenmedi**.

## 1. Ortam ve proje analizi

| Konu | Durum |
|---|---|
| Flutter / Dart / Flame | 3.47.7 / 3.13.5 / 1.38.2 |
| iOS eklentileri | shared_preferences, audioplayers (darwin 6.5.0), share_plus 13.3.1. Hepsi Swift Package Manager ile geliyor; Podfile yok |
| iOS proje dosyaları | `ios/Runner` (AppDelegate, SceneDelegate, Info.plist, Assets, LaunchScreen) |
| Sürüm | `pubspec.yaml`: `1.0.0+1`. Derleme numarasını Codemagic belirliyor (§4.3) |
| Dağıtım hedefi | iOS 15.0 (Apple şartı: iOS 13+, 9 Eylül 2026'dan beri) |
| Cihaz ailesi | iPhone + iPad (`TARGETED_DEVICE_FAMILY = "1,2"`) |
| İmzalama | Xcode projesinde Automatic. CI'da Codemagic profili uyguluyor (`xcode-project use-profiles`) |
| Yerel araçlar | `flutter doctor -v` (21 Ekim 2026): Flutter ✓, Chrome ✓, Android SDK ✗, Visual Studio ✗. **Xcode yok** |

## 2. iOS yapılandırması

| Gereksinim | Durum | Nerede |
|---|---|---|
| Uygulama adı "İstanbul Flight" | ✓ `CFBundleDisplayName`. Kısa ad `CFBundleName` = "Istanbul Flight" | `ios/Runner/Info.plist` |
| Bundle ID | ✓ **Kesinleşti:** `com.burakhamzali.istanbulFlight` (§3) | `project.pbxproj`, `codemagic.yaml` |
| Dikey yön | ✓ iPhone'da yalnızca Portrait (plist + `SystemChrome.setPreferredOrientations`). iPad'de dört yön tanımlı; iPad çoklu görev doğrulaması bunu istiyor. Oyun kod düzeyinde dikey kilitli | `Info.plist`, `lib/main.dart:25` |
| Safe Area / Dynamic Island | ✓ Bütün katmanlar `SafeArea` içinde. Oyun dünyası tam ekran çiziliyor; skor ve düğmeler çentiğin altında kalıyor. **Gerçek cihazda görülmedi** | `hud_overlay.dart`, `menu_overlays.dart`, `postcard_overlay.dart` |
| Açılış ekranı | ✓ Koyu arka plan (#0E1433) + Simit (1x/2x/3x) | `LaunchScreen.storyboard`, `LaunchImage.imageset` |
| Uygulama ikonu | ✓ 15 boyut, 1024 px opak (alfa yok) | `Assets.xcassets/AppIcon.appiconset` |
| İzinler | ✓ Yalnızca bir açıklama metni: `NSPhotoLibraryAddUsageDescription`. Bu bir izin isteği değil; yalnızca kullanıcı paylaşım menüsünde "Resmi Kaydet"e basarsa sorulur. Anahtar olmazsa iOS bu seçenekte uygulamayı **kapatır**. Kamera, konum, mikrofon, takip ve bildirim yok. `UIBackgroundModes` yok | `Info.plist` |
| Şifreleme beyanı | ✓ `ITSAppUsesNonExemptEncryption = false` (TestFlight'ta her derlemede soru çıkmaz) | `Info.plist` |
| Yaşam döngüsü | ✓ `inactive`, `hidden` ve `paused` durumlarının her biri oyunu PAUSED'a alıyor ve sesi durduruyor. `resumed` olunca oyun **kendiliğinden başlamıyor**; oyuncu "Devam"a basıyor (3-2-1) | `istanbul_flight_game.dart:687`, test |
| Arka planda otomatik duraklatma | ✓ Kontrol Merkezi, Bildirim Merkezi, gelen arama, kilit, ana ekran, uygulama değiştirici | yukarıdaki ile aynı |
| Ses oturumu | ✓ `AVAudioSessionCategory.ambient`: sessiz anahtarına uyar, başka uygulamanın müziğini durdurmaz | `audio_service.dart:23` |
| Titreşim | ✓ `HapticFeedback` (hafif/orta/ağır). Ayarlardan kapatılabiliyor. Ek izin gerekmiyor | `haptics_service.dart` |
| Paylaşım | ✓ share_plus ile PNG kartpostal + metin. **iPad düzeltmesi:** Paylaş düğmesinin dikdörtgeni `sharePositionOrigin` olarak veriliyor; verilmezse iPad'de menü açılmıyor (§5) | `share_service.dart`, `postcard_overlay.dart` |
| 120 Hz (ProMotion) | ✓ `CADisableMinimumFrameDurationOnPhone = true`. Fizik 120 Hz sabit adımda; kare hızından bağımsız | `Info.plist` |
| İnternet | Gerekmiyor; ağ çağrısı yok | — |

## 3. Bundle Identifier: kesinleşti

**Karar (21 Ekim 2026): `com.burakhamzali.istanbulFlight` (seçenek A).** Projede ve `codemagic.yaml`da zaten bu değer olduğu için dosya değişmedi. Aşağıdaki tablo karar öncesi seçenekleri gösteriyor.

**Bundle ID ilk TestFlight yüklemesinden sonra değiştirilemez.** Bu yüzden onay beklenmişti.

| Seçenek | Değer | Not |
|---|---|---|
| A: şimdiki | `com.burakhamzali.istanbulFlight` | Flutter'ın ürettiği biçim. Android kimliğinden (`com.burakhamzali.istanbul_flight`) farklı |
| **B: önerilen** | **`com.burakhamzali.istanbulflight`** | Tamamı küçük harf, alt çizgisiz. Android'de de geçerli bir biçim; ileride iki platform aynı kimliği kullanabilir. Uygulamanın yeni adıyla uyumlu |
| C: Görev 8 önerisi | `com.burakhamzali.martiistanbulflight` | Uygulamanın adı artık "İstanbul Flight" olduğu için daha az uygun |

Onaylarsan değişecek yerler (yalnızca iOS): `ios/Runner.xcodeproj/project.pbxproj` (Runner hedefinin 3 yapılandırması ve RunnerTests) ve `codemagic.yaml` (`bundle_identifier`, iki yer). Android'e dokunulmayacak.

## 4. İmzalama ve Codemagic

### 4.1 İş akışları (`codemagic.yaml`)

| İş akışı | Tetikleyici | Ne yapar | Yükler mi |
|---|---|---|---|
| `ios-check` | PR | İmzasız `flutter build ios --release --no-codesign` | Hayır |
| `ios-ipa` | `v*` etiketi | Testler + imzalı IPA; çıktılar: IPA, xcodebuild günlükleri, dSYM | **Hayır** |
| `ios-testflight` | **Yok; yalnızca elle** | `ios-ipa` ile aynı + App Store Connect'e yükleme, TestFlight işleme | **Evet, yalnızca dahili test.** Harici grup, herkese açık bağlantı ve App Store gönderimi yok (`submit_to_app_store: false`) |

`ios-testflight` akışını Codemagic'te "Start new build" ile başlatmak, yükleme onayı anlamına geliyor. Bu yüzden otomatik tetikleyicisi yok.

### 4.2 İmzalama

- `ios_signing: distribution_type: app_store` + `bundle_identifier`.
- Codemagic, takımdaki **Apple Distribution** sertifikasını ve **App Store** provisioning profile'ını kullanıyor. API anahtarıyla bunları kendisi de oluşturabiliyor (Code signing identities → iOS → "Fetch/Generate").
- `xcode-project use-profiles` profili Xcode projesine uyguluyor ve `/Users/builder/export_options.plist` dosyasını yazıyor. `flutter build ipa` bunu kullanıyor.
- **Depoda gizli bilgi yok:** Sertifika, `.p12`, `.p8` ve parolalar yalnızca Codemagic'te saklanıyor.

### 4.3 Derleme numarası

```
LATEST = app-store-connect get-latest-testflight-build-number $APP_STORE_APPLE_ID   (hiç yoksa 0)
NEXT   = LATEST + 1
flutter build ipa --release --build-number=$NEXT
```

Sürüm adı (`1.0.0`) `pubspec.yaml`'dan geliyor. App Store Connect aynı sürüm için tekrarlanan derleme numarasını reddettiği için her yükleme otomatik olarak bir artırılıyor.

### 4.4 Codemagic'te bir kez yapılacaklar

1. Projeyi bir git deposuna koy (GitHub/GitLab/Bitbucket) ve Codemagic'e ekle. *Şu an proje git deposu değil.*
2. **Team settings → Integrations → Developer Portal / App Store Connect:** §6.6'daki API anahtarını ekle. Anahtar adı: **`marti_asc`** (Issuer ID, Key ID, `.p8` dosyası).
3. **Team settings → Code signing identities → iOS certificates:** Apple Distribution sertifikası oluştur ya da yükle. **iOS provisioning profiles:** Bundle ID için App Store profili.
4. **App → Environment variables:** grup **`marti_ios`**, değişken **`APP_STORE_APPLE_ID`** = App Store Connect'teki sayısal Apple ID (§6.5).
5. Önce `ios-check` ile imzasız derlemeyi, sonra `ios-ipa` ile imzalı IPA'yı dene. Bunlar yükleme yapmaz. En son, onay verirsen `ios-testflight`.

## 5. Bu görevdeki kod değişiklikleri

| Dosya | Değişiklik | Neden |
|---|---|---|
| `lib/services/share_service.dart` | `sharePostcard(..., {Rect? origin})` → `ShareParams.sharePositionOrigin` | iPad'de paylaşım menüsü bir başlangıç noktası ister |
| `lib/ui/overlays/postcard_overlay.dart` | Paylaş düğmesinin ekrandaki dikdörtgeni (`GlobalKey`) hesaplanıp iletiliyor | Aynı |
| `ios/Runner/Info.plist` | `CFBundleDisplayName` "İstanbul Flight", `CFBundleName` "Istanbul Flight", `NSPhotoLibraryAddUsageDescription` | Ad; "Resmi Kaydet"te çökmeyi önlemek |
| `codemagic.yaml` | Eski `ios-release` yerine `ios-ipa` ve `ios-testflight`; derleme numarası; dSYM | TestFlight |
| `test/game_test.dart` | iOS yaşam döngüsü testi: inactive, hidden, paused → duraklar; resumed sonrası kendiliğinden başlamaz; menüdeyken durum değişmez | Kontrol Merkezi / arama / kilit |
| `test/experience_ui_test.dart` | Paylaşım başlangıç noktası boş değil ve Paylaş düğmesini içeriyor | iPad paylaşımı |
| `test/services_test.dart` | Başlangıç noktası share_plus'a aynen iletiliyor; verilmezse `null` | iPad paylaşımı |
| `test/fakes.dart` | `FakeShare.lastOrigin` | Testler için |

Oyun mekaniklerine, görsellere ve Android'e dokunulmadı.

## 6. Apple Developer ve App Store Connect: adım adım (senin yapacakların)

### 6.1 Apple Developer Program üyeliği
1. <https://developer.apple.com/programs/enroll/> adresinden Apple hesabınla (iki adımlı doğrulama açık olmalı) **Individual** ya da **Organization** olarak kaydol. Yıllık ücret 99 USD. Organization için D-U-N-S numarası gerekir.
2. Onay e-postasını bekle (genellikle 24–48 saat).

### 6.2 Team ID
**developer.apple.com → Account → Membership details → Team ID** (10 karakter). Codemagic ve profiller bu takımla eşleşir.

### 6.3 Bundle ID kaydı
1. **Certificates, Identifiers & Profiles → Identifiers → +**.
2. **App IDs → App** seçip devam et.
3. Açıklama: `Istanbul Flight`. Bundle ID: **Explicit**, §3'te onaylanan değer.
4. Capabilities: hiçbirini işaretleme (oyun ek yetenek kullanmıyor). **Register**.

### 6.4 Dağıtım sertifikası ve provisioning profile
İki yol var; Mac'in yoksa **Codemagic yolu** daha kolay:
- **Codemagic:** API anahtarı (§6.6) ekledikten sonra Code signing identities → iOS certificates → **Generate certificate** (Apple Distribution). Ardından iOS provisioning profiles → **Fetch profiles** ya da otomatik oluşturma. Oluşan sertifikanın `.p12` dosyasını ve parolasını **güvenli bir yere yedekle**.
- **Elle:** Certificates → + → **Apple Distribution** (CSR gerekir; Mac'te Anahtar Zinciri ya da `openssl` ile). Profiles → + → **App Store Connect** → Bundle ID → sertifika → indir ve Codemagic'e yükle.

### 6.5 App Store Connect'te uygulama kaydı
1. <https://appstoreconnect.apple.com> → **Apps → + → New App**.
2. Platform: iOS. Ad: **İstanbul Flight** (App Store'da benzersiz olmalı; alınmışsa ör. "İstanbul Flight: Martı"). Birincil dil: Türkçe. Bundle ID: §6.3'teki. SKU: ör. `istanbulflight001`. Erişim: Full Access.
3. **App Information → General → Apple ID** sayısını Codemagic'te `APP_STORE_APPLE_ID` olarak gir.
4. TestFlight dahili test için mağaza sayfası, ekran görüntüsü ve inceleme gerekmez. Ama **App Privacy** ve **Export Compliance** soruları önceden doldurulabilir; yanıtlar `docs/store/store_listing.md`'de.

### 6.6 App Store Connect API anahtarı
1. **Users and Access → Integrations → App Store Connect API → Team Keys → +** (hesap sahibi ya da Admin yapabilir).
2. Ad: `Codemagic`. Erişim: **App Manager**.
3. `.p8` dosyasını indir. **Yalnızca bir kez indirilebilir.** Issuer ID ve Key ID'yi not al.
4. Bu üçünü Codemagic'e `marti_asc` adıyla gir (§4.4). `.p8` dosyasını depoya **koyma**.

### 6.7 Dahili test grubu
1. Uygulama → **TestFlight → Internal Testing → +** ile grup oluştur (ör. `Ekip`). **"Enable automatic distribution"** açık olursa yeni derlemeler gruba kendiliğinden gider.
2. Testçiler: App Store Connect'te **Users and Access**'e eklenmiş kişiler (en fazla 100). Her biri TestFlight uygulamasıyla davet alır.
3. **Harici test grubu ve herkese açık bağlantı oluşturma.** Harici test Beta App Review gerektirir; bu aşamanın dışında.

### 6.8 İlk yükleme (yalnızca onayınla)
1. Codemagic → `ios-testflight` → **Start new build**.
2. App Store Connect'te derleme 10–30 dakikada "Processing"den çıkar. Export compliance önceden yanıtlandığı için soru beklenmez.
3. Dahili gruba otomatik dağıtım kapalıysa derlemeyi gruba elle ekle.
4. "What to Test" metnini `docs/testflight/beta_materials.md` §2'den yapıştır.
5. Uyarı e-postalarını kontrol et; özellikle **ITMS-91053 (zorunlu gerekçe API / gizlilik manifesti)** gelebilir (§10).

## 7. TestFlight süreci (bu beta için)

- **Yalnızca dahili test:** En fazla 100 kişi, App Store Connect kullanıcısı olmaları gerekiyor, Beta App Review yok.
- Bir derleme **90 gün** test edilebilir.
- Geri bildirim: TestFlight içindeki ekran görüntüsü ve "Beta Geri Bildirimi Gönder". App Store Connect → TestFlight → Feedback'te görünür. Çökme raporları da orada (dSYM Codemagic çıktısında).
- Sonraki derleme: Codemagic `ios-testflight`'ı yeniden başlat; derleme numarası otomatik artar.
- **Harici test, herkese açık bağlantı, App Store gönderimi: yapılmayacak.**

## 8. Gerçek iPhone test planı

Durum: PASS · FAIL · BLOCKED · NOT RUN. **Cihaz ve derleme yok → hepsi NOT RUN.** Son sütun cihaz dışında neyin doğrulandığını gösterir; cihaz testinin yerini tutmaz.

**Önerilen cihazlar:** iOS 15–16 çalışan eski bir iPhone (ör. iPhone 8 / SE 2), Dynamic Island'lı güncel bir iPhone (iOS 26) ve bir iPad.

| # | Senaryo | Adımlar / beklenen | Durum | Cihaz dışı kanıt |
|---|---|---|---|---|
| 1 | TestFlight'tan kurulum | Davet → TestFlight → Yükle. İkon doğru; ad "İstanbul Flight" (kesiliyor mu not et) | NOT RUN | — |
| 2 | İlk açılış | Koyu açılış ekranı + Simit, beyaz parlama yok, menü gelir. Süre ölçülür | NOT RUN | web'de menü açılıyor |
| 3 | Dynamic Island / çentik | Skor, duraklat ve menü düğmeleri kapanmıyor; ana ekran çubuğu düğmeleri kapatmıyor | NOT RUN | `SafeArea` (kod); web'de çentik yok |
| 4 | Dikey kilit | Telefonu yan çevir; oyun dikey kalır | NOT RUN | plist + kod |
| 5 | Dokunma | Her dokunuş tek kanat çırpma; hızlı dokunuşlar kaçmıyor; gecikme yok | NOT RUN | girdi testleri |
| 6 | Akıcılık | 60 Hz ve 120 Hz (ProMotion) cihazda takılma yok; bölge geçişlerinde (15/35/60/90) duraklama yok | NOT RUN | 30/60 fps fizik eşdeğerlik testi |
| 7 | Çarpışmalar | Görsel ile hitbox uyumlu, haksız çarpışma yok | NOT RUN | yerleşim testleri |
| 8 | Simit ve kıl payı | Ses, titreşim, sayaç, "KIL PAYI!" | NOT RUN | testler |
| 9 | Duraklat / devam | Duraklat, 3-2-1 ile devam, ana menü | NOT RUN | testler |
| 10 | Ana ekrana gitme | Oyun duraklar, ses kesilir; dönüşte duraklatma ekranı, kendiliğinden başlamaz | NOT RUN | yaşam döngüsü testi |
| 11 | Kontrol Merkezi / Bildirim Merkezi | Aşağı çekince oyun duraklar (`inactive`) | NOT RUN | yaşam döngüsü testi |
| 12 | Gelen arama / FaceTime | Oyun duraklar; arama bitince ses geri gelir ve "Devam" çalışır | NOT RUN | yaşam döngüsü testi |
| 13 | Ekran kilidi | Kilitle ve aç; duraklatılmış, ses yok | NOT RUN | yaşam döngüsü testi |
| 14 | Sessiz anahtar | Sessiz modda oyun sesi çıkmaz; titreşim ayara göre çalışır | NOT RUN | `ambient` (kod) |
| 15 | Başka uygulamanın müziği | Müzik/Podcast çalarken oyunu aç; dış müzik durmaz, sesler karışır | NOT RUN | `ambient` (kod) |
| 16 | Ayarlar ve titreşim | Ses, müzik, titreşim, azaltılmış hareket düğmeleri anında etki eder | NOT RUN | ayar testleri |
| 17 | Rekor kalıcılığı | Uygulamayı zorla kapat ve aç; rekor ve ayarlar duruyor | NOT RUN | kalıcı kayıt testleri |
| 18 | Kartpostal paylaşımı | Paylaş → Mesajlar/WhatsApp/AirDrop; PNG ve metin gidiyor. "Resmi Kaydet" izin sorusu çıkar ve Fotoğraflar'a kaydeder; reddedilince çökme yok | NOT RUN | PNG üretimi ve paylaşım testleri |
| 19 | iPad | Oyun açılıyor; Paylaş menüsü düğmenin yanında açılıyor; çoklu görev (Split View) bozulmuyor | NOT RUN | origin testleri; web'de 1032×1376 |
| 20 | Uzun oturum, FPS, bellek | 30 dk oyun; ısınma ve pil. Profile derlemesi + DevTools ya da `MARTI_STATS=true` ile FPS; bellek artışı yok | NOT RUN | 10 dk simülasyon testi |

## 9. iPhone deneyimi değerlendirmesi

- **Kare hızı ve bellek: ÖLÇÜLMEDİ.** Gerçek cihaz yok. Kod incelemesinde 60 FPS'e engel görülmedi (≤ 512 px kaplamalar, shader yok, kare başına nesne üretilmiyor, sınırlı efekt havuzu). Ama bu bir ölçüm değil. Ayrıntı: docs/10 §5.
- **120 Hz:** Açık. Pil tüketimi cihazda değerlendirilmeli; gerekirse 60 Hz'e sınırlanabilir.
- **Dokunma gecikmesi:** Girdi doğrudan Flame'in dokunma olayında işleniyor. Ölçülmedi.
- **Açılış:** 58 görsel paralel yükleniyor. Eski iPhone'da süre ölçülmeli.
- **Ses gecikmesi:** Efektler `AudioPool` ile önceden yükleniyor. Cihazda dinlenmedi.
- **Paket boyutu:** WAV sesler 3 MB. Sıkıştırma önerisi docs/10 §6'da.

## 10. Bilinen sorunlar ve riskler

1. **audioplayers_darwin'de gizlilik manifesti yok.** Yükleme sonrası e-postada ITMS-91053 uyarısı gelirse `PrivacyInfo.xcprivacy` eklenmeli. Proje dosyası Mac olmadan elle düzenlenmediği için eklenmedi. Diğer eklentiler manifestlerini taşıyor.
2. **iPad'de arayüz küçük** (telefon mantıksal boyutu); taşma yok.
3. **Ana ekranda ad kısalabilir:** "İstanbul Flight" 15 karakter. iOS sığmayan adı "…" ile kısaltır. Cihazda bakılmalı; gerekirse ana ekran adı (`CFBundleDisplayName`) kısaltılabilir. App Store adı değişmez.
4. **Arayüz yalnızca Türkçe.**
5. **İkon programatik pixel art;** tasarımcı incelemesi önerilir.
6. **Hiç derlenmedi:** İlk Codemagic çalıştırmasında Xcode/SPM'e özgü bir derleme hatası çıkabilir. Önce `ios-check` çalıştırılmalı.

## 11. Bu görevde çalıştırılan komutlar (21 Ekim 2026, Windows 11)

| Komut | Sonuç |
|---|---|
| `flutter doctor -v` | Flutter 3.47.7 ✓, Chrome ✓, ağ ✓. Android SDK ✗, Visual Studio ✗. **iOS/Xcode bölümü yok** (Windows) |
| `flutter pub get` | ✓ Bağımlılıklar alındı |
| `flutter analyze` | ✓ **No issues found** |
| `flutter test` | ✓ **98/98** (Görev 8'de 96; yaşam döngüsü ve iPad paylaşımı için +2) |
| `flutter build ipa --release` | ✗ **Çalıştırılamadı:** Windows'ta `build ipa` komutu yok ("Could not find an option named --release"). macOS + Xcode gerekir; Codemagic `ios-ipa` bunu yapar |

## 12. Hesap kurulumu (22 Ekim 2026)

Senin onayınla tarayıcı panelinde yapıldı (giriş bilgilerini sen girdin):

| Adım | Sonuç |
|---|---|
| Bundle ID | `com.burakhamzali.istanbulFlight` kaydedildi (Team MF9WSY29TD) |
| App Store Connect | "İstanbul Flight" oluşturuldu: Apple ID **6825523571**, SKU `istanbulflight001`, birincil dil Türkçe |
| Provisioning profile | `istanbulflight_appstore` (App Store, mevcut Distribution sertifikası); Codemagic'e çekildi |
| API anahtarı | Yeni anahtar oluşturulmadı; Codemagic'teki mevcut "Zar ASC Key" kullanılıyor |
| Depo | Özel `github.com/burakhamzalidev/istanbul_flight`; Codemagic GitHub uygulamasına bu depo eklendi; Codemagic'te uygulama oluşturuldu |
| `codemagic.yaml` | Entegrasyon adı `Zar ASC Key`; `APP_STORE_APPLE_ID` doğrudan `vars` içinde (gizli değil); `marti_ios` grubuna gerek kalmadı |

Not: `verify` iş akışı her push'ta Linux makinede çalışır (yükleme yapmaz).

### İlk imzalı derleme

Codemagic `ios-ipa`, derleme #1 (commit 164afe6, Mac mini M2, Xcode latest, Flutter 3.47.7): toplam 3 dk 51 sn. Bağımlılıklar, analiz ve testler geçti; profil uygulandı; Xcode arşivi 48 sn (177,8 MB); IPA 23,2 MB. Flutter uygulama ayarları doğrulaması: 1.0.0 / 1 / "İstanbul Flight" / iOS 15.0 / `com.burakhamzali.istanbulFlight`. Çıktılar: IPA + 5 dSYM. Yükleme yok.

## 13. Senden beklenen kararlar

1. ~~Bundle ID~~: kesinleşti, `com.burakhamzali.istanbulFlight`.
2. **TestFlight yüklemesi:** §4.4 ve §6 hazır olduktan sonra `ios-testflight`'ı başlatmak (ya da benim başlatmam) için açık onay. Codemagic çalıştırmalarını şu an ben başlatamıyorum; hesap ve depo yok.

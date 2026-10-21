# 10 · Android ve iOS yayın hazırlığı (Görev 8)

> Dosya adı görevde istendiği gibi `10_` ile başlıyor. Aynı numarada bir de `10_kiz_kulesi_gercek_referans.md` var; ikisi farklı belgeler.

## Özet: hangi durum, nerede

| Durum | Android | iOS |
|---|---|---|
| **Yapılandırma hazır** | ✅ kimlik, ad, SDK seviyeleri, izinler, imzalama, ikon, açılış ekranı, geri tuşu | ✅ ad, yönler, şifreleme beyanı, ikon, açılış ekranı, ses oturumu |
| **Gerçekten derlendi** | ❌ **Android SDK yok** → APK/AAB alınamadı | ❌ **macOS / Xcode yok** → `flutter build ios` Windows'ta mevcut değil |
| **CI/CD** | ✅ `codemagic.yaml` hazır, YAML ayrıştırması doğrulandı, **hiç çalıştırılmadı** | aynı |
| **Cihazda test edildi** | ❌ cihaz yok (bütün cihaz testleri NOT RUN) | ❌ |
| **Mağaza onayı** | ❌ yüklenmedi (kullanıcı onayı bekleniyor) | ❌ |
| **Doğrulanan** | analiz temiz, **96/96 test**, web release derlemesi; arayüz ve oyun web derlemesinde 5 çözünürlükte çalışıyor | aynı |

---

## 1. Proje ve ortam analizi (çalışmaya başlamadan önceki durum)

| Konu | Bulgu |
|---|---|
| Flutter / Dart | Flutter 3.47.7 (stable, 8 Ekim 2026), Dart 3.13.5 |
| Flame | 1.38.2 (flame_test 2.3.1) |
| Bağımlılıklar | flame, shared_preferences 2.5.6, audioplayers 6.8.1, share_plus 13.3.1, cupertino_icons. Hepsi Android ve iOS'u destekliyor. 16 paketin daha yeni ama kısıtlarla uyumsuz sürümü var; yükseltme bu görevde yapılmadı (kararlılık önceliği) |
| `flutter doctor` | ✅ Flutter, Chrome, ağ. ❌ **Android toolchain: SDK yok.** ❌ Visual Studio (yalnızca Windows masaüstü için; bu projeyi etkilemez). JDK 21 kurulu. **macOS yok** |
| Android klasörü | Şablon hâlinde: ad `istanbul_flight`, release **debug anahtarıyla** imzalanıyordu, varsayılan Flutter ikonu, beyaz açılış ekranı. AGP 9.1.0, Kotlin 2.4.0, Gradle 9.3.1, Java 17 |
| iOS klasörü | Şablon: Bundle ID `com.burakhamzali.istanbulFlight`, görünen ad `Istanbul Flight`; iPhone'da yatay yönler de açıktı (kod dikeye kilitli); dağıtım hedefi iOS 15.0; Swift Package Manager (Podfile yok) |
| Testler | Başlangıçta **95/95 geçiyordu**, başarısız test yoktu. Bu görevde 1 test eklendi → **96** |
| Asset'ler | 58 PNG, diskte ≈ 115 KB, belleğe çözülmüş ≈ 6,6 MB RGBA. 15 WAV ses dosyası, toplam **3,0 MB** (en büyük ikisi müzik: 1,0 MB ve 0,76 MB). Font 14 KB. Eski vektör set `art/` altında, pakete girmiyor |
| Git | **Proje bir git deposu değil.** Sürüm kontrolü yok; CI bağlanabilmesi için gerekli (bkz. §12) |
| CI/CD | Yoktu |
| Önceki belgeler | docs/01–14 okundu (oyun, görsel sistem, ses, testler) |

## 2. Yapılan değişiklikler

### Kod (oyun mekaniği değişmedi)

1. **Android geri tuşu** (`IstanbulFlightGame.handleBack`, `main.dart` → `PopScope`):
   - pencere açıksa kapatır,
   - oyunda duraklatır,
   - duraklatma, oyun sonu ya da "dokun" ekranındaysa ana menüye döner,
   - **yalnızca ana menüde** uygulamadan çıkar.

   Yeni test: `experience_game_test.dart` → "Android geri tuşu…".
2. **Ses oturumu** (`configureAudioSession`, audio_service.dart):
   - iOS'ta `AVAudioSession.ambient` → **sessiz anahtarına uyar**, kullanıcının müziğiyle karışır. Varsayılan `playback` sessiz modu yok sayıyordu.
   - Android'de `usage=game`, ses odağı alınmaz → arka planda çalan müzik durmaz.
   - Web'de ve hata durumunda hiçbir şey yapmaz.
3. **Sistem çubukları:** Kenardan kenara, saydam durum ve gezinme çubuğu, açık ikonlar (oyunun gök ve deniz tonları koyu).
4. **Demo seçenekleri** (yalnızca `MARTI_DEMO` derlemesinde): `&card=1` ve `&play=1`. Ekran görüntüsü ve doğrulama için; normal derlemede etkisiz.

### Android

| Konu | Önce | Sonra |
|---|---|---|
| Görünen ad | `istanbul_flight` | **Martı** |
| applicationId | `com.burakhamzali.istanbul_flight` | Değişmedi. **Kesinleştirme senin kararın** (§Kimlik önerisi) |
| minSdk / targetSdk / compileSdk | Flutter varsayılanı | Aynı: **24 / 36 / 36.** Google Play şartı 31 Ağustos 2026'dan beri **API 36**; karşılanıyor |
| Sürüm | 1.0.0+1 | Aynı (versionName 1.0.0, versionCode 1); CI'da `--build-number=$BUILD_NUMBER` |
| İmzalama | Release debug anahtarıyla | Önce CI ortam değişkenleri (`CM_KEYSTORE_*`), sonra `android/key.properties` (gitignore'da, örneği `key.properties.example`). İkisi de yoksa uyarı verip debug anahtarıyla imzalar (yalnızca yerel deneme, **mağazaya yüklenemez**) |
| Yön | Kodda dikey kilit | Manifest'e `screenOrientation="portrait"` eklendi (Flutter başlamadan dönme olmasın). **Not:** Android 16'da hedef API 36 olan uygulamalarda **büyük ekranlarda** yön kilidi yok sayılır. Oyun yatay ekranda dikey bir sütunda ortalandığı için düzen bozulmaz (web'de 1024×768 testi var) |
| İzinler | Release manifestinde yok (INTERNET yalnızca debug/profile) | Aynı, belgelendi. Titreşim (`HapticFeedback`) ve paylaşım (share_plus FileProvider) izin gerektirmez |
| İkon | Flutter varsayılanı | Oyunun pixel art'ından **adaptif ikon:** arka plan manzara, ön plan Simit, Android 13+ tema ikonu için tek renk katman. Ayrıca 5 yoğunlukta klasik ikon |
| Açılış ekranı | Beyaz | Android 12+ SplashScreen API (koyu arka plan + ikonun ön planı); Android 11 ve öncesinde koyu arka plan + ortada pixel art Simit. Açık ve koyu sistem temasında aynı |
| Edge-to-edge / Safe Area | — | Android 15+ zorunlu kenardan kenara davranışla uyumlu: arayüz `SafeArea` içinde, oyun alanı tam ekran |
| Ses odağı / yaşam döngüsü | Oyun arka plana gidince duraklıyor, ses duruyordu | Aynı + ses odağı alınmıyor |

### iOS

| Konu | Önce | Sonra |
|---|---|---|
| Görünen ad | Istanbul Flight | **Martı** (CFBundleName `Marti`) |
| Bundle ID | `com.burakhamzali.istanbulFlight` | Değişmedi; Android ile **tutarsız** (§Kimlik önerisi) |
| Dağıtım hedefi | iOS 15.0 | Aynı. Apple şartı iOS 13+ (9 Eylül 2026'dan beri); karşılanıyor |
| Yönler | iPhone: dikey + yatay | **iPhone yalnızca dikey.** iPad'de dört yön açık kaldı: çoklu görev desteği için Apple doğrulaması bunu ister. Kod çalışırken dikeye kilitliyor |
| Şifreleme beyanı | Yok | `ITSAppUsesNonExemptEncryption = false`: uygulama şifreleme kullanmıyor; her yüklemede ihracat sorusu çıkmaz |
| İkon | Flutter varsayılanı | 15 boyutun hepsi pixel art ikondan; 1024'lük ikon opak, alfa kanalı yok |
| Açılış ekranı | Beyaz | Koyu arka plan (#0E1433) + ortada Simit (@1x/@2x/@3x, ölçeklenmeden) |
| Ses oturumu | `playback` (sessiz modu yok sayar) | `ambient` |
| Haptik | `HapticFeedback` | Değişmedi; iOS'ta UIImpactFeedbackGenerator'a karşılık gelir, desteklenmeyen cihazda sessizce atlanır |
| Paylaşım | share_plus | Değişmedi. iPad'de paylaşım menüsünün konum (sourceRect) davranışı **cihazda test edilmeli** |
| Gizlilik manifesti | — | Eklenmedi: Flutter, shared_preferences ve share_plus kendi manifestlerini taşıyor. audioplayers_darwin'de manifest yok (§11) |
| SDK şartı | — | 28 Nisan 2026'dan beri **Xcode 26 + iOS 26 SDK** zorunlu. Codemagic'te `xcode: latest` |

### Web

Manifest ve başlık "Martı" oldu; ikonlar yeni ikondan, tema rengi #0E1433.

### Kimlik önerisi (karar senin)

Android ve iOS kimlikleri farklı (`istanbul_flight` / `istanbulFlight`). İkisi de şablondan geliyor ve ilk mağaza yüklemesinden sonra **değiştirilemez.**

- **Öneri:** Her iki platformda aynı ve alt çizgisiz bir kimlik, ör. **`com.burakhamzali.martiistanbulflight`**.
- **Değiştirmek için:**
  - Android: `android/app/build.gradle.kts` içinde `applicationId` ve `namespace`; ayrıca `MainActivity.kt` paket yolu.
  - iOS: Xcode'da `PRODUCT_BUNDLE_IDENTIFIER` ve `codemagic.yaml` içindeki `bundle_identifier`.
- Ben değiştirmedim; rastgele bir kimliği kesinleştirmemek için.

## 3. CI/CD (Codemagic)

Dosya: [`codemagic.yaml`](../codemagic.yaml). YAML ayrıştırması `package:yaml` ile doğrulandı: 4 iş akışı, bütün adımlar çözümleniyor. **Codemagic üzerinde hiç çalıştırılmadı.**

| İş akışı | Makine | Tetikleyici | Adımlar | Çıktılar |
|---|---|---|---|---|
| `verify` | linux_x2 | push, PR | pub get, analyze, test (rapor), web release | build/web, test raporu |
| `android-release` | linux_x2 | `v*` etiketi | pub get, analyze, test, imza anahtarı kontrolü, AAB, APK | `.aab`, `.apk`, mapping.txt |
| `ios-check` | mac_mini_m2 | PR | pub get, test, `flutter build ios --release --no-codesign` | `.app` (imzasız) |
| `ios-release` | mac_mini_m2 | `v*` etiketi | pub get, analyze, test, profilleri uygula, `flutter build ipa` | `.ipa` |

**Gizli bilgiler:**

- Depoda gizli bilgi yok.
- Android anahtarı Codemagic "Android keystores" bölümünde `marti_upload_keystore` referansıyla tutulur.
- iOS için App Store Connect API anahtarı (`marti_asc`) ile dağıtım sertifikası ve profil Codemagic'te tutulur.

**Mağazaya otomatik yükleme bilinçli olarak kapalı.** Nasıl açılacağı dosyada yorum olarak duruyor.

## 4. Derleme çıktıları

| Komut | Sonuç | Çıktı |
|---|---|---|
| `flutter doctor -v` | Android toolchain ❌ (SDK yok), Visual Studio ❌ (gereksiz), diğerleri ✅ | — |
| `flutter pub get` | ✅ | — |
| `flutter analyze` | ✅ No issues found! | — |
| `flutter test` | ✅ **96/96** | — |
| `flutter build web --release` | ✅ | `build/web/` (44 MB, main.dart.js 2,4 MB) |
| `flutter build apk --release` | ❌ `No Android SDK found` | — |
| `flutter build appbundle --release` | ❌ `No Android SDK found` | — |
| `flutter build ios --release` | ❌ Windows'ta bu komut yok (yalnızca macOS) | — |

**Çözüm yolları:**

- **Android:** Bu makineye Android SDK kurmak (Android Studio ya da komut satırı araçları; birkaç GB indirme ve Android SDK lisansının kabulü, senin onayınla), **ya da** Codemagic `android-release`.
- **iOS:** Mac + Xcode 26, **ya da** Codemagic `ios-check` (imzasız) / `ios-release` (Apple Developer hesabı gerekir).
- **Önemli:** Android Gradle yapılandırması (`build.gradle.kts`, imzalama mantığı) **hiç derlenmedi.** İlk derlemede küçük bir yazım hatası çıkabilir.

## 5. Performans değerlendirmesi (kod incelemesi; cihazda ÖLÇÜLMEDİ)

| Alan | Bulgu | Risk |
|---|---|---|
| Kaplama boyutları | En büyük görsel 480×200 px; hepsi ≤ 512 px. Toplam ≈ 6,6 MB RGBA | Düşük |
| Atlas ve önbellek | Görseller bir kez yükleniyor (Flame `Images` önbelleği); bölge geçişinde yeni yükleme yok | Düşük |
| Çizim | Pikselde `FilterQuality.none`; kare başına ≈ 100 `drawImageRect`, gölgelendirici (shader) yok | Düşük |
| Bellek tahsisi | Kare başına `Paint`/liste üretilmiyor (alanlarda saklanıyor). Efekt havuzu sabit (24). Engeller ekran dışında kaldırılıyor | Düşük |
| Uzun oturum | 10 dakikalık simülasyon testi nesne sayısının sınırlı kaldığını doğruluyor | Düşük |
| Fizik | 120 Hz sabit adım; kare hızından bağımsız (30 ve 60 fps aynı sonuç, test) | — |
| 120 Hz ekran | `CADisableMinimumFrameDurationOnPhone = true` (iOS ProMotion) | Pil kullanımı cihazda ölçülmeli |
| Ses | Efektler `AudioPool` ile önceden yükleniyor (düşük gecikme); müzik akış olarak çalıyor. WAV toplam 3 MB | Paket boyutu (§6) |
| Arka plan / ön plan | Oyun arka plana gidince duraklıyor (PAUSED) ve ses duruyor; dönüşte oyuncu "Devam"a basıyor (3-2-1 geri sayım) | — |
| Açılış | 58 görsel paralel yükleniyor | Düşük donanımlı cihazda ölçülmeli |

**Hedef 60 FPS:** Kod düzeyinde engel yok. **Gerçek kare hızı ve bellek ölçülmedi.** Ölçüm için Flutter DevTools (profile modu) ya da `MARTI_STATS=true` derlemesindeki FPS göstergesi kullanılmalı.

## 6. Ses ve titreşim

- **Dosyalar:** 15 özgün WAV (Görev 5'te prosedürel üretildi; lisans sorunu yok). Toplam 3,0 MB.
- **Format önerisi:** Müzik ve ortam döngüleri Android için **OGG Vorbis**, iOS için **AAC/M4A**. audioplayers ikisini de destekliyor. Yaklaşık 3 MB → 0,5 MB beklenir. **Bu makinede kodlayıcı (ffmpeg vb.) olmadığı için dönüştürülmedi.** Efektler kısa olduğu için WAV kalabilir (gecikme düşük).
- **Doğrulananlar** (kod ve test düzeyinde):
  - Müzik döngüleri `ReleaseMode.loop`.
  - Efekt başına ses sayısı sınırlı (havuz 1–4).
  - Arka plana geçince müzik ve ortam sesi duruyor, dönüşte devam ediyor; duraklatılmışsa "Devam"a basınca devam ediyor.
  - Bütün ses çağrıları hata yakalıyor; ses olmayan platformda oyun etkilenmiyor.
  - Titreşim desteklenmeyen platformda (web) sessizce atlanıyor.
- **Cihazda doğrulanmalı:**
  - iOS'ta sessiz anahtarla gerçekten susması (`ambient`).
  - Android'de Spotify vb. çalarken müziğin durmaması.
  - Haptik şiddeti.

## 7. Görsel kalite ve ekran uyumluluğu

Web derlemesinde, headless tarayıcıda doğrulandı (Görev 6–7 ve bu görevin mağaza görüntüleri):

- **Çözünürlükler:** 320×568, 360×640, 375×812, 390×844, 393×852, 412×915, 440×956, 768×1024, 800×1422 ve 1032×1376 (iPad 13").
- **Taşma yok:** Widget testleri 320×568, 360×640, 390×844, 768×1024 ve 1024×768'de taşma olmadığını doğruluyor.
- **Keskinlik:** Pikseller en yakın komşu ölçekleniyor, bulanıklık yok; parallax şeritlerinde dikiş yok (test).
- **Simgeler ve Simit:** Simgeler her bölgede görünür, Simit okunur.
- **Tablet (bilinen sorun):** iPad ve tablette arayüz telefondaki mantıksal boyutta kalıyor. Kartpostal ve düğmeler ekrana göre küçük görünüyor; taşma yok. Ölçeklemek pixel font keskinliğini ve ekran testlerini etkileyebileceği için bu görevde yapılmadı.
- **Çentik / Safe Area:** Arayüz `SafeArea` içinde. **Gerçek çentikli cihazda test edilmedi;** headless tarayıcı çentik çizmez.

## 8. Gerçek cihaz test planı

Durum anahtarı: PASS · FAIL · BLOCKED · NOT RUN. **Cihaz erişimi yok → bütün cihaz testleri NOT RUN.** "Otomatik / web kanıtı" sütunu, cihaz dışında bugüne kadar neyin doğrulandığını gösterir; cihaz testinin yerini tutmaz.

| # | Senaryo | Adımlar / beklenen | Android | iOS | Otomatik / web kanıtı |
|---|---|---|---|---|---|
| 1 | İlk kurulum | Mağaza/TestFlight'tan kur; ikon ve ad "Martı" | NOT RUN | NOT RUN | — |
| 2 | İlk açılış | Koyu açılış ekranı + Simit, sonra menü; çökme yok; ilk açılış süresi ölçülür | NOT RUN | NOT RUN | Web'de menü açılıyor |
| 3 | Ana menü | Düğmeler, rekor rozeti, ayarlar, nasıl oynanır | NOT RUN | NOT RUN | widget testleri, web |
| 4 | Dokunmatik kontrol | Her dokunuşta tek kanat çırpma; hızlı dokunuşlarda kaçırma yok | NOT RUN | NOT RUN | testler (girdi) |
| 5 | Oyun fiziği | Yerçekimi, kanat, eğim; 60/120 Hz ekranda aynı his | NOT RUN | NOT RUN | 30/60 fps eşdeğerlik testi |
| 6 | Beş bölge geçişi | 0→90 puan; arka plan geçişleri, simgeler | NOT RUN | NOT RUN | demo derlemesinde web |
| 7 | Engel çarpışmaları | Görsel ile hitbox uyumu, haksız çarpışma yok | NOT RUN | NOT RUN | yerleşim testleri (15) |
| 8 | Simit toplama | Ses, titreşim, sayaç | NOT RUN | NOT RUN | testler |
| 9 | Kıl payı bonusu | "KIL PAYI!", ses | NOT RUN | NOT RUN | testler |
| 10 | Duraklatma | Duraklat, 3-2-1 ile devam; geri tuşu (Android) | NOT RUN | NOT RUN | testler (geri tuşu dahil) |
| 11 | Arka plana alma | Ana ekran tuşu; oyun duraklar, ses susar | NOT RUN | NOT RUN | yaşam döngüsü kodu |
| 12 | Geri dönme | Duraklatma ekranı, ses yeniden başlar | NOT RUN | NOT RUN | yaşam döngüsü kodu |
| 13 | Ses ve titreşim | Ses düzeyleri, sessiz mod (iOS), başka uygulamanın müziği, titreşim kapalı/açık | NOT RUN | NOT RUN | sahte servislerle testler |
| 14 | Skor kaydı | Rekor kaydedilir | NOT RUN | NOT RUN | testler |
| 15 | Kapatıp açma | Rekor ve ayarlar korunur | NOT RUN | NOT RUN | kalıcı kayıt testleri |
| 16 | Kartpostal | Doğru bölge, skor, rekor damgası | NOT RUN | NOT RUN | web'de 5 bölge + rekor damgası |
| 17 | Paylaşım | Sistem paylaşım menüsü; PNG gider; iPad'de menü konumu | NOT RUN | NOT RUN | PNG üretimi testi; tarayıcıda basılmadı |
| 18 | Farklı ekranlar | Küçük telefon, büyük telefon, tablet, katlanabilir; çentik | NOT RUN | NOT RUN | web'de 10 çözünürlük |
| 19 | Uzun süreli oyun | 30 dk; ısınma, kare düşmesi, bellek artışı | NOT RUN | NOT RUN | 10 dk simülasyon testi |
| 20 | Bellek ve FPS | Profile derlemesi + DevTools; hedef 60 FPS, kararlı bellek | NOT RUN | NOT RUN | — |

**Önerilen test cihazları:**

- **Android:** Bir düşük donanımlı cihaz (Android 7–9, 2–3 GB RAM), bir güncel cihaz (Android 15–16) ve bir tablet.
- **iOS:** Bir eski iPhone (iOS 15), bir güncel iPhone ve bir iPad.

## 9. Mağaza materyalleri

Ayrıntı: [docs/store/store_listing.md](store/store_listing.md).

- **Metinler:** Ad, kısa ve uzun açıklama, alt başlık, anahtar kelimeler (TR/EN). Karakter sayıları ölçüldü, sınırların içinde.
- **Görseller:**
  - İkonlar: Play 512, App Store 1024.
  - Tanıtım görseli: 1024×500.
  - 30 ekran görüntüsü: Play telefon ve tablet, iPhone 6,1" ve 6,9", iPad 13". Hepsi alfa kanalsız 24 bit PNG.
  - Ekran görüntüleri web derlemesinden alındı; gerçek cihaz görüntüsü değiller.
- **Diğer:** İçerik derecelendirmesi, veri güvenliği ve App Privacy yanıt hazırlıkları; test dağıtım planı.
- **Gizlilik politikası taslağı:** [docs/store/privacy_policy.md](store/privacy_policy.md). Yayımlanacak bir URL gerekiyor.

## 10. Güvenlik ve gizlilik değerlendirmesi

| Konu | Bulgu |
|---|---|
| İzinler | Release'de **hiç izin yok** (Android manifesti); iOS'ta kullanım açıklaması gerektiren izin yok |
| Kullanıcı verisi | Yalnızca cihazda: en iyi skor (`best_score_v1`), ayarlar (`settings_v1`), ilerleme (`progress_v1`, JSON). Kişisel veri yok |
| Ağ | Uygulama kodunda ağ erişimi yok; release'de INTERNET izni yok |
| Üçüncü taraf SDK | Yok (analitik, reklam, çökme raporu yok). Eklenmedi |
| Paylaşım | share_plus: PNG geçici dosyaya yazılıp sistem paylaşım menüsüne veriliyor; yalnızca kullanıcı başlatınca |
| Gizli anahtarlar | Depoda yok. `key.properties` ve `*.jks` `.gitignore`'da; CI anahtarları Codemagic'te |
| Günlükler | 14 `debugPrint` çağrısı: yalnızca hata mesajları (ses, kayıt, titreşim); kişisel bilgi yok. Release'de `debugPrint` konsola yazmaya devam eder ama hassas veri içermez |
| Kod karartma | Flutter release derlemesi Dart kodunu AOT derler. İstenirse `--obfuscate --split-debug-info` eklenebilir; tek kişilik bir oyun için gerekli görülmedi |

## 11. Bilinen sorunlar

1. **audioplayers_darwin gizlilik manifesti yok.** İlk App Store yüklemesinde "zorunlu gerekçe API" uyarısı gelirse `ios/Runner/PrivacyInfo.xcprivacy` eklenip Xcode projesine bağlanmalı. Mac olmadan proje dosyasını elle düzenlemek riskli olduğu için yapılmadı.
2. **Tablette arayüz küçük kalıyor** (§7); taşma yok.
3. **Ses dosyaları WAV** (3 MB); sıkıştırılmış format önerisi §6.
4. **Android Gradle yapılandırması derlenmedi** (SDK yok); ilk derleme bu ortamın dışında yapılacak.
5. **Web'de hızlı duraklat/devam** sırasında yakalanmış `AbortError` ses günlükleri (Görev 5'ten). Mobilde görülmesi beklenmez; işlevi etkilemiyor.
6. **İkon programatik bir pixel art.** Küçük boyutta okunuyor; yayından önce tasarımcı incelemesi önerilir.

## 12. Yayını engelleyen eksikler (senin yapman gerekenler)

| # | İş | Neden |
|---|---|---|
| 1 | **Uygulama kimliğine karar ver** (§2 Kimlik önerisi) | İlk yüklemeden sonra değiştirilemez |
| 2 | **Projeyi bir git deposuna koy** (GitHub/GitLab/Bitbucket) ve Codemagic'e bağla | CI için gerekli; şu an sürüm kontrolü de yok |
| 3 | **Android yükleme anahtarı oluştur** (`keytool`, bkz. `android/key.properties.example`) ve Codemagic'e `marti_upload_keystore` olarak yükle; **anahtarı ve şifreleri güvenli yedekle** | İmzalı AAB |
| 4 | **Google Play Console** geliştirici hesabı; uygulamayı oluştur, Play App Signing'i aç | Yükleme |
| 5 | **Apple Developer Program** üyeliği; App Store Connect'te uygulama kaydı, App Store Connect API anahtarı (Codemagic `marti_asc`) | IPA ve TestFlight |
| 6 | **Gizlilik politikası ve destek sayfası URL'leri** (taslak hazır) | İki mağaza da istiyor |
| 7 | İçerik derecelendirmesi, veri güvenliği ve App Privacy formlarını hazırlıklara göre doldur | Mağaza zorunluluğu |
| 8 | **Gerçek cihaz testleri** (§8) | Hiçbiri yapılmadı |
| 9 | İstersen: bu makineye Android SDK kurulumu (indirme ve lisans kabulü senin onayınla) | Yerel APK/AAB |

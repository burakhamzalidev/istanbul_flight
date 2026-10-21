# Yayın kontrol listesi: Martı: Istanbul Flight 1.0.0 (1)

Her madde gerçek durumuna göre işaretlidir (Ekim 2026, Görev 8). Ayrıntılar: [docs/10_android_ios_release_readiness.md](docs/10_android_ios_release_readiness.md).

İşaretler:

- `[x]` yapıldı ve doğrulandı
- `[~]` hazırlandı ama doğrulanamadı (ortam yok)
- `[ ]` yapılmadı
- **(SEN)** kullanıcının yapması gereken

## Kod ve test

- [x] `flutter analyze`: sorun yok
- [x] `flutter test`: 96/96
- [x] `flutter build web --release`
- [x] Android geri tuşu davranışı (test ile)
- [x] Ses oturumu: iOS `ambient`, Android `game` / ses odağı yok (kod)
- [~] Ses oturumunun cihazda doğru davranması (sessiz mod, başka uygulamanın müziği)
- [x] Oyun arka plana gidince duraklama ve ses durması (kod + test)
- [x] Uzun oturumda nesne sayısının sınırlı kalması (10 dk simülasyon testi)

## Android

- [x] Görünen ad "Martı"
- [ ] **(SEN)** applicationId kesinleştir (öneri: `com.burakhamzali.martiistanbulflight`)
- [x] targetSdk 36 / compileSdk 36 / minSdk 24 (Play şartı: API 36, 31 Ağustos 2026'dan beri)
- [x] Release manifestinde izin yok
- [x] Dikey yön (manifest + kod); büyük ekranlarda yatay düzen bozulmuyor (web testi)
- [x] Adaptif ikon (ön plan, arka plan, tek renk) + klasik ikonlar
- [x] Açılış ekranı (Android 12+ SplashScreen API ve eski sürümler)
- [x] Güvenli imzalama yapılandırması (CI ortam değişkenleri / gitignore'daki key.properties)
- [ ] **(SEN)** Yükleme anahtarı oluştur, güvenli yedekle, Codemagic'e yükle
- [ ] Debug APK: **alınamadı** (Android SDK yok)
- [ ] Release APK: **alınamadı** (Android SDK yok)
- [ ] Release AAB: **alınamadı** (Android SDK yok)
- [~] `build.gradle.kts` değişiklikleri: yazıldı, derlenmedi

## iOS

- [x] Görünen ad "İstanbul Flight" (Görev 9; önceki "Martı")
- [x] Bundle ID kesinleşti: `com.burakhamzali.istanbulFlight`
- [x] iPhone yalnızca dikey; iPad dört yön (çoklu görev doğrulaması)
- [x] `ITSAppUsesNonExemptEncryption = false`
- [x] AppIcon (15 boyut, 1024 opak)
- [x] Açılış ekranı (koyu arka plan + Simit)
- [x] Dağıtım hedefi iOS 15 (Apple şartı ≥ 13)
- [ ] iOS derlemesi: **alınamadı** (macOS/Xcode yok; Windows'ta `flutter build ios` yok)
- [ ] **(SEN)** Apple Developer üyeliği, sertifika, provisioning profile
- [ ] İmzalı IPA: yok (hesap ve Mac/CI gerekiyor)
- [~] Gizlilik manifesti: eklentiler kendi manifestlerini taşıyor; audioplayers_darwin'de yok (ilk yüklemede kontrol et)

## CI/CD (Codemagic)

- [x] `codemagic.yaml`: 5 iş akışı (verify, android-release, ios-check, ios-ipa, ios-testflight); YAML ayrıştırması doğrulandı
- [x] Gizli bilgi depoda yok; mağazaya otomatik yükleme kapalı
- [ ] **(SEN)** Projeyi git deposuna koy ve Codemagic'e bağla
- [ ] **(SEN)** Codemagic: `marti_upload_keystore`, `marti_asc`, iOS imzalama
- [ ] İlk Codemagic çalıştırması (henüz hiç çalışmadı)

## Mağaza materyalleri

- [x] Ad, kısa ve uzun açıklama, alt başlık, anahtar kelimeler (TR/EN; karakter sınırları ölçüldü)
- [x] Play ikonu 512, App Store ikonu 1024, tanıtım görseli 1024×500
- [x] Ekran görüntüleri: Play telefon 6, Play tablet 6, iPhone 6,1" 6, iPhone 6,9" 6, iPad 13" 6 (24 bit PNG). **Web derlemesinden, cihazdan değil**
- [x] İçerik derecelendirmesi, veri güvenliği, App Privacy yanıt hazırlıkları
- [x] Gizlilik politikası taslağı (TR/EN)
- [ ] **(SEN)** Gizlilik politikası ve destek sayfasını herkese açık bir URL'de yayımla; ad ve e-postayı doldur
- [ ] **(SEN)** Play Console ve App Store Connect formlarını doldur

## Gerçek cihaz testleri (docs/10 §8)

- [ ] Android: 20 senaryo, hepsi **NOT RUN**
- [ ] iOS: 20 senaryo, hepsi **NOT RUN**
- [ ] FPS ve bellek ölçümü (profile modu)

## Yayın

- [ ] Dahili test (Play dahili kanal / TestFlight dahili)
- [ ] Kapalı test (gerekiyorsa Play'in kapalı test şartı)
- [ ] Üretim yayını: **yalnızca açık kullanıcı onayıyla**

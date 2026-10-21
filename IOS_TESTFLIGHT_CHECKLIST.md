# iOS TestFlight kontrol listesi: İstanbul Flight 1.0.0

Gerçek duruma göre işaretli (21 Ekim 2026, Görev 9). Ayrıntılar: [docs/11_ios_testflight_beta.md](docs/11_ios_testflight_beta.md).

İşaretler:

- `[x]` yapıldı ve doğrulandı
- `[~]` hazırlandı ama doğrulanamadı (Mac / hesap / cihaz yok)
- `[ ]` yapılmadı
- **(SEN)** senin yapman ya da onaylaman gereken

## 1. Hazır: kod ve yapılandırma

- [x] `flutter analyze`: sorun yok
- [x] `flutter test`: 98/98
- [x] Görünen ad "İstanbul Flight" (`CFBundleDisplayName`)
- [x] Bundle ID kesinleşti: `com.burakhamzali.istanbulFlight` (kullanıcı onayı, 21 Ekim 2026)
- [x] iPhone yalnızca dikey (plist + kod)
- [~] Safe Area / Dynamic Island: kodda `SafeArea`; cihazda görülmedi
- [x] Açılış ekranı (koyu arka plan + Simit)
- [x] AppIcon (15 boyut, 1024 opak)
- [x] Gereksiz izin yok; yalnızca "Resmi Kaydet" için `NSPhotoLibraryAddUsageDescription`
- [x] `ITSAppUsesNonExemptEncryption = false`
- [x] Dağıtım hedefi iOS 15
- [x] Yaşam döngüsü: inactive/hidden/paused → duraklat; kendiliğinden başlamaz (test)
- [x] Ses oturumu `ambient` (kod); [~] sessiz anahtar ve dış müzik cihazda doğrulanmadı
- [x] Titreşim ayarla kapatılabiliyor (test); [~] cihazda hissedilmedi
- [x] iPad paylaşım menüsü başlangıç noktası (kod + test)
- [~] Gizlilik manifesti: audioplayers_darwin'de yok (ilk yüklemede uyarıyı kontrol et)

## 2. Hazır: CI ve belgeler

- [x] `codemagic.yaml`: `ios-check`, `ios-ipa`, `ios-testflight` (YAML ayrıştırması doğrulandı)
- [x] Derleme numarası: TestFlight son + 1
- [x] Artifact: IPA, xcodebuild günlükleri, dSYM
- [x] `ios-testflight` yalnızca elle başlıyor; harici grup yok; App Store gönderimi kapalı
- [x] Depoda sertifika, anahtar ya da parola yok
- [x] Beta materyalleri: sürüm notları, What to Test (TR/EN), beta açıklaması, test rehberi, hata şablonu, bilinen sorunlar
- [x] 20 senaryoluk iPhone test planı

## 3. Apple ve Codemagic hesapları (SEN)

- [ ] **(SEN)** Apple Developer Program üyeliği
- [ ] **(SEN)** Bundle ID kaydı (Identifiers)
- [ ] **(SEN)** App Store Connect'te uygulama kaydı; Apple ID → `APP_STORE_APPLE_ID`
- [ ] **(SEN)** App Store Connect API anahtarı (App Manager) → Codemagic `marti_asc`
- [ ] **(SEN)** Apple Distribution sertifikası + App Store provisioning profile → Codemagic
- [ ] **(SEN)** Projeyi git deposuna koy ve Codemagic'e bağla; `marti_ios` grubu
- [ ] **(SEN)** Dahili test grubu (Internal Testing)

## 4. Gerçekten derlendi

- [ ] Yerel iOS derlemesi: **yok** (Windows; `flutter build ipa` yok)
- [ ] Codemagic `ios-check` (imzasız): **hiç çalıştırılmadı**
- [ ] Codemagic `ios-ipa` (imzalı IPA): **hiç çalıştırılmadı**. Dağıtılabilir IPA **yok**

## 5. TestFlight'a yüklendi

- [ ] **(SEN, onay)** `ios-testflight` çalıştırması: **yapılmadı**
- [ ] Derleme App Store Connect'te işlendi
- [ ] Dahili gruba dağıtıldı; What to Test girildi
- [ ] Harici test / herkese açık bağlantı: **bilinçli olarak yok**

## 6. Cihazda test edildi

- [ ] 20 senaryo (docs/11 §8): hepsi **NOT RUN**
- [ ] FPS ve bellek ölçümü: **ölçülmedi**
- [ ] Ana ekranda adın kesilip kesilmediği

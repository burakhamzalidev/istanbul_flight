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

## 3. Apple ve Codemagic hesapları (22 Ekim 2026, senin onayınla tarayıcıda yapıldı)

- [x] Apple Developer Program üyeliği (Individual, Team MF9WSY29TD; mevcuttu)
- [x] Bundle ID kaydı: `com.burakhamzali.istanbulFlight` (ek yetenek yok)
- [x] App Store Connect uygulama kaydı: "İstanbul Flight", Türkçe, SKU `istanbulflight001`, Apple ID `6825523571` (`codemagic.yaml` içinde)
- [x] App Store Connect API anahtarı: mevcut "Zar ASC Key" Codemagic'te bağlı; `codemagic.yaml` bunu kullanıyor
- [x] Apple Distribution sertifikası (mevcut; Codemagic'te `zar_dist`) + App Store profili `istanbulflight_appstore` (oluşturuldu, Codemagic'e çekildi)
- [x] Özel GitHub deposu `burakhamzalidev/istanbul_flight`; Codemagic GitHub uygulamasına erişim verildi; Codemagic'e Flutter uygulaması olarak eklendi
- [ ] **(SEN)** Dahili test grubu (TestFlight → Internal Testing); ilk derleme işlendikten sonra
- [ ] **(SEN)** App Privacy ve yaş derecelendirmesi formları (TestFlight dahili test için zorunlu değil)

## 4. Gerçekten derlendi

- [ ] Yerel iOS derlemesi: **yok** (Windows; `flutter build ipa` yok)
- [ ] Codemagic `ios-check` (imzasız): çalıştırılmadı (gerek kalmadı; `ios-ipa` imzalı derlemeyi yaptı)
- [x] Codemagic `ios-ipa` (imzalı IPA): **başarılı** (22 Ekim 2026, derleme #1, 3 dk 51 sn). `Istanbul_Flight.ipa` 23,2 MB, sürüm 1.0.0 (1), Xcode arşivi 177,8 MB, dSYM'ler alındı. Analiz ve testler Mac'te de geçti. Yükleme yapılmadı

## 5. TestFlight'a yüklendi

- [x] `ios-testflight` çalıştırması (kullanıcı onayıyla, 22 Ekim 2026, Codemagic derleme #2): IPA yüklendi (altool "UPLOAD SUCCEEDED", delivery 5be36caf…). Apple son durum çağrısında geçici **500** döndürdüğü için Codemagic derlemeyi "failed" gösteriyor; derleme yine de App Store Connect'e ulaştı
- [~] Derleme App Store Connect'te: **1.0.0 (1), "Processing"** (işleme tamamlanınca işaretlenecek)
- [ ] Dahili gruba dağıtıldı; What to Test girildi
- [ ] Harici test / herkese açık bağlantı: **bilinçli olarak yok**

## 6. Cihazda test edildi

- [ ] 20 senaryo (docs/11 §8): hepsi **NOT RUN**
- [ ] FPS ve bellek ölçümü: **ölçülmedi**
- [ ] Ana ekranda adın kesilip kesilmediği

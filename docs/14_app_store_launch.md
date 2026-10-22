# Phase 3: App Store yayını (İstanbul Flight)

> Not: `14_engeller_gercek_referans.md` ile aynı numara; dosya adı görevde istendiği gibi bırakıldı.
> Kontrol listesi: [../APP_STORE_RELEASE_CHECKLIST.md](../APP_STORE_RELEASE_CHECKLIST.md)

## Yayın aşamaları: gerçek durum (22 Ekim 2026)

| Aşama | Durum |
|---|---|
| **A. Release Candidate hazırlandı** | ✓ **1.2.0 (3)**: TestFlight'ta, "Ekip" grubunda |
| **B. TestFlight üzerinden gerçek cihaz testleri** | ◐ iPhone: kullanıcı bildirimiyle 17 PASS (bazıları kısmi), 3 NOT RUN (uçak modu, Instruments, iPad) (§4) |
| **C. Metadata ve gizlilik alanları** | ◐ App Store Connect'e girildi (§5a). Eksik: ekran görüntülerinin yüklenmesi, App Review iletişim bilgisi (sen), App Privacy'nin yayımlanması (onayınla) |
| **D. Yayın adayı build seçildi** | ✓ Sürüm 1.2.0, build 1.2.0 (3) eklendi, yayın **manuel** |
| **E. App Review'a gönderilmeye hazır** | ✗ B, C ve D bitmeden hayır |
| **F. App Review'a gönderildi** | ✗ Yalnızca açık onayınla |
| **G. Apple incelemesi tamamlandı** | ✗ |
| **H. Halka açık yayın** | ✗ Yalnızca açık onayınla; yayın tercihi **manuel** |

## 1. Güncel kod denetimi

| Konu | Bulgu |
|---|---|
| Son commit | `36e9009` (Phase 2.2 kodu `bba3e50`), `main`, çalışma ağacı temiz |
| Sürüm | `pubspec.yaml`: `1.2.0+3` |
| Flutter / Dart / Flame | 3.47.7 / 3.13.5 / 1.38.2 |
| Bundle ID | `com.burakhamzali.istanbulFlight` (Team MF9WSY29TD) |
| Deployment target | iOS 15.0 (Apple şartı ≥ 13) |
| Cihaz ailesi | iPhone + iPad (`TARGETED_DEVICE_FAMILY = "1,2"`); **kullanıcı kararı: değişmiyor** |
| Codemagic | `ios-testflight` elle başlıyor, derleme numarası = TestFlight son + 1, `submit_to_app_store: false`; `ios-ipa` (yüklemesiz) |
| App Store Connect build geçmişi | 1.0.0 (1), 1.1.0 (2), 1.2.0 (3): hepsi "Ready to Submit", hepsi yalnızca dahili test |
| Testler (yeniden çalıştırıldı, 22 Ekim) | `flutter pub get` ✓, `flutter analyze` **No issues found**, `flutter test` **166/166** |
| Kayıt uyumluluğu | `progress_v2` şeması 1.1.0'dan beri aynı; 1.0.0 `progress_v1` → v2 geçişi testli; `best_score_v1`, `settings_v1` değişmedi |
| Bağımlılıklar | flame, shared_preferences, audioplayers (darwin 6.5.0), share_plus 13.3.1, cupertino_icons. Dolaylı: path_provider_foundation 2.6.0 (yerel kod yok, FFI), objective_c 9.5.0 |
| İzinler / plist | `NSPhotoLibraryAddUsageDescription` (yalnızca paylaşım menüsündeki "Resmi Kaydet"), `ITSAppUsesNonExemptEncryption = false`, iPhone yalnızca dikey, `UIBackgroundModes` yok |
| Ağ | Uygulama kodunda ağ çağrısı yok |

## 2. Release Candidate

- **Önerilen ilk halka açık sürüm: 1.2.0 (3).** TestFlight'ta 1.2.0 (3) zaten var. Kod değişmediği için yeni bir derleme gerekmiyor.
- App Store sürüm kaydı şu an "1.0" (Prepare for Submission). Derlemenin sürümüyle (1.2.0) eşleşmesi için sürüm numarası **1.2.0** yapılmalı. Bu, onayınla App Store Connect'te yapılacak (kesinleştirilmedi).
- **Derleme numarası çakışması yok:** Kullanılanlar 1, 2, 3. Kod değişirse sıradaki derleme otomatik olarak 4 olur.
- **Sürüm notları:** İlk sürümde App Store "What's New" alanı yok. Bunun yerine Promotional Text kullanılacak (§5).

## 3. Test sonuçları (bu ortamda, 22 Ekim 2026)

| Komut | Sonuç |
|---|---|
| `flutter pub get` | ✓ |
| `flutter analyze` | ✓ No issues found |
| `flutter test` | ✓ **166/166** |
| `flutter build ipa --release` | Bu makinede yapılamaz (Windows; komut yok). iOS derlemeleri Codemagic'te: 1.2.0 (3), commit `bba3e50`, hatasız; IPA + 5 dSYM Codemagic'te saklanıyor |

## 4. Gerçek cihaz testleri

Kaynak: kullanıcının kendi iPhone'unda TestFlight 1.2.0 (3) ile yaptığı test. 22 Ekim 2026'da 15 maddelik kontrol listesinin tamamı için toplu olarak "geçti" bildirildi; madde madde ayrıntı ve iPhone modeli verilmedi. Kontrol listesinde sorulmayan alt maddeler aşağıda ayrıca belirtildi. Gerçek iPhone erişimim yok; aşağıdaki PASS'ler kullanıcı beyanıdır.

| # | Senaryo | Durum |
|---|---|---|
| 1 | TestFlight'tan ilk kurulum (temiz) | PASS (TestFlight kurulumu; temiz kurulum mu güncelleme mi belirtilmedi) |
| 2 | 1.0.0 / 1.1.0'dan silmeden güncelleme | PASS (önceki sürüm kuruluysa koşuluyla soruldu) |
| 3 | Kayıtların korunması (rekor, simit, ayarlar, XP, görevler, başarımlar) | PASS |
| 4 | İlk açılış (açılış ekranı, menü, çökme yok) | PASS |
| 5 | Beş bölge (Haliç → Rumeli Hisarı) | PASS |
| 6 | Uçuş fiziği ve çarpışmalar | PASS |
| 7 | Simit kazanma | PASS |
| 8 | Günlük görevler (ilerleme, ödül bir kez, gece yarısı yenilenme) | PASS (ilerleme ve tamamlama; gece yarısı yenilenme ayrıca sorulmadı) |
| 9 | XP ve seviye | PASS (seviyenin korunması; XP kazanımı ayrıca sorulmadı) |
| 10 | Başarımlar | PASS |
| 11 | Simit mağazası (onay, bakiye, tekrar satın alınamama) | PASS (satın alma ve seçme; tekrar satın alınamama ayrıca sorulmadı) |
| 12 | Satın alınan kozmetiklerin kalıcılığı (zorla kapat / aç) | PASS |
| 13 | Seçili kozmetiğin uçuşta ve kartpostalda görünmesi | PASS (uçuşta; kartpostal ayrıca sorulmadı) |
| 14 | Arka plan / ön plan (ana ekran, kilit, arama, Kontrol Merkezi) | PASS |
| 15 | Ses (sessiz anahtar, başka uygulamanın müziği) ve titreşim | PASS |
| 16 | Kartpostal ve iOS paylaşımı ("Resmi Kaydet" izni dahil) | PASS |
| 17 | İnternetsiz kullanım (uçak modu) | NOT RUN (kodda ağ erişimi yok) |
| 18 | Uzun süreli oyun (30 dk: ısınma, yavaşlama) | PASS (10–15 dk olarak soruldu) |
| 19 | Bellek ve performans (Xcode Instruments / profile derlemesi; ölçülmedi) | NOT RUN |
| 20 | iPad'de açılış ve temel akış (iPad desteği açık) | NOT RUN (risk: App Review iPad'de de deneyebilir) |

Otomatik testler bu akışların mantığını kapsıyor (166 test). Ama **cihaz testinin yerini tutmaz.**

## 5. App Store metadata

Kaynak: [store/app_store_metadata.json](store/app_store_metadata.json). Karakter ve bayt sınırları ölçüldü; resmî sınırlar Apple'ın "App information" ve "Platform version information" sayfalarından 22 Ekim 2026'da doğrulandı.

| Alan | TR | EN | Sınır |
|---|---|---|---|
| Ad | İstanbul Flight (15) | İstanbul Flight (15) | 30 |
| Alt başlık | İstanbul üzerinde pixel uçuş (28) | Pixel-art flight over Istanbul (30) | 30 |
| Promotional Text | 153 | 152 | 170 |
| Açıklama | 1406 | ~1500 | 4000 |
| Anahtar kelimeler | 96 bayt | 93 bayt | **100 bayt** (ad tekrarlanmadı, kelimeler > 2 karakter, marka adı yok) |
| Kategori | Games; alt kategoriler **Casual + Action** (App Store Connect'te "Arcade" alt kategorisi yok) | | |
| Destek URL | https://burakhamzalidev.github.io/istanbul_flight/support.html (✓ yayında) | | |
| Gizlilik URL | https://burakhamzalidev.github.io/istanbul_flight/privacy.html (✓ yayında) | | |
| Pazarlama URL | https://burakhamzalidev.github.io/istanbul_flight/ (isteğe bağlı) | | |
| Telif | 2026 Burak Hamzalı | | |
| Fiyat ve bölge | **Ücretsiz**, **Çin anakarası hariç** bütün ülkeler (orada oyunlar için ayrıca resmî onay numarası gerekiyor) | | |
| Yayın | **Manuel** (onay sonrası yayını sen başlatırsın) | | |
| App Review iletişim | **Senin girmen gerekiyor** (ad, telefon +90…, e-posta). Uydurulmadı | | |
| Demo hesabı | Gerekmiyor (giriş yok) | | |
| Review notu (öneri) | "Offline single-player game. No login, no IAP, no ads. Simits are an in-game virtual currency earned only by playing and used for cosmetic looks; they cannot be purchased. The UI is in Turkish." | | |

### Türkçe ve İngilizce metinler

Tam metinler: `docs/store/app_store_metadata.json` (`tr`, `en`: name, subtitle, promo, keywords, description).

- **Açıklamalar yalnızca oyunda olan özellikleri anlatıyor:**
  - beş bölge
  - simit ve kıl payı
  - XP, seviye, günlük görevler, dokuz başarım
  - Simit Mağazası ve beş görünüm
  - kartpostal paylaşımı
  - ayarlar
- **Açıkça belirtilenler:**
  - simitler gerçek parayla satılmıyor
  - görünümler yalnızca görsel
  - İngilizce metinde "arayüz Türkçe"

### Yayın notları (Promotional Text olarak)

- **TR:** "Simit adlı martıyla Haliç'ten Rumeli Hisarı'na uç! Günlük görevleri tamamla, simit biriktir, mağazadan yeni görünümler aç. Reklam yok, internet gerekmez."
- **EN:** "Fly Simit the seagull from the Golden Horn to Rumeli Fortress! Complete daily missions, collect simits and unlock new looks. No ads, no internet needed."

## 5a. App Store Connect'te girilenler (22 Ekim 2026, sayfadan doğrulandı)

| Alan | Durum |
|---|---|
| App Information TR/EN: ad, alt başlık | ✓ |
| Kategori | ✓ Games; Casual + Action |
| İçerik hakları | ✓ "Üçüncü taraf içerik yok" |
| Yaş derecelendirmesi | ✓ Yeni anket (7 adım), bütün yanıtlar "Yok" → **4+**. "Made for Kids" seçilmedi (geri alınamıyor) |
| Gizlilik politikası URL (TR/EN) | ✓ |
| App Privacy | ◐ "Data Not Collected" kaydedildi, **yayımlanmadı** (beyan onayın gerekiyor) |
| Sürüm 1.2.0 TR/EN: tanıtım metni, açıklama, anahtar kelimeler, destek ve pazarlama URL'si | ✓ |
| Telif | ✓ 2026 Burak Hamzalı |
| Build | ✓ 1.2.0 (3) |
| Yayın | ✓ **Manuel** |
| Giriş gerekli | ✓ İşaretsiz (giriş yok) |
| Review notu | ✓ |
| Fiyat | ✓ 0,00 USD (ücretsiz) |
| Bölgeler | ✓ 174 bölge, Çin anakarası hariç |
| DSA | ✓ Hesapta "trader değil" görünüyor (önceden beyan edilmiş) |
| Ekran görüntüleri | ✗ Yüklenmedi: "iPhone with Dynamic Island (medium display)" ve "iPad 13" display" alanlarına, TR ve EN için ayrı ayrı |
| App Review iletişim bilgisi | ✓ Girildi (kullanıcının verdiği bilgilerle) |
| Değiştirilmeyen varsayılanlar | Apple Silicon Mac'te ve Apple Vision Pro'da dağıtım işaretli (Apple varsayılanı); bu cihazlarda test edilmedi. Karar senin |

## 6. Mağaza görselleri

`docs/store/app_store/{iphone,ipad}/{tr,en}_01–06.png`: 24 görsel, alfasız 24 bit RGB PNG.

| Cihaz | Boyut | Apple şartı (22 Ekim 2026, resmî sayfa) |
|---|---|---|
| iPhone (Dynamic Island, orta ekran) | **1179×2556** | Zorunlu |
| iPad 13" | **2064×2752** | iPad desteklendiği için zorunlu |

Sıra (istenen düzen):
1. İstanbul semalarında uç (Haliç oynanışı)
2. Galata'nın çatıları arasından
3. Gün batımında Kız Kulesi
4. Günlük görevler ve XP
5. Simitlerle yeni görünümler (mağaza, Pilot görünümü)
6. Boğaz Köprüsü'nde gece

**Kaynak (açıkça):**
- Görüntüler oyunun **web derlemesinden** (aynı Flutter kodu) headless tarayıcıda, hedef piksel yoğunluğunda alındı. Uçuş sahneleri demo modunda (otomatik pilot, bölge başlangıç skoru).
- Gerçek iPhone ekran görüntüsü değiller. Oyunda olmayan bir şey göstermiyorlar.
- Başlık bandı tanıtım amaçlı eklendi.
- iPad görselleri oyunun iPad'deki gerçek düzenini (küçük arayüz) gösteriyor.
- **Öneri:** TestFlight testinde iPhone'dan birkaç gerçek ekran görüntüsü alırsan bunlar ham görüntülerin yerine konabilir.

## 7. Gizlilik değerlendirmesi

| Konu | Bulgu |
|---|---|
| Toplanan kullanıcı verisi | **Yok** |
| Yerel kayıtlar | `shared_preferences` (UserDefaults): `best_score_v1`, `settings_v1`, `progress_v2` (+ dokunulmayan `progress_v1`). Cihazdan çıkmaz |
| Üçüncü taraf SDK | Reklam, analitik, çökme raporu, giriş SDK'sı yok |
| Ağ erişimi | Yok |
| Paylaşım | Kullanıcı başlatıyor; iOS paylaşım menüsü. "Resmi Kaydet" → iOS'un "yalnızca ekleme" izni |
| İzinler | Yalnızca `NSPhotoLibraryAddUsageDescription` |
| Takip | Yok; ATT gerekmiyor |
| Privacy manifest | Flutter motoru, `shared_preferences_foundation` (UserDefaults) ve `share_plus` kendi `PrivacyInfo.xcprivacy` dosyalarını taşıyor. `audioplayers_darwin` 6.5.0'da manifest yok, ancak kaynağında gerekçe gerektiren API (UserDefaults, dosya zamanı, açılış süresi, disk alanı, klavye) **bulunmadı**. Uygulamanın Swift kodu bu API'leri kullanmıyor |
| Doğrulanacak | 3 yüklemeden sonra Apple'dan **ITMS-91053** e-postası geldiyse uygulama düzeyinde manifest eklenmeli (yeni derleme 1.2.0 (4)). E-postanı kontrol et |
| Sanal ekonomi | Simit yalnızca oyunda kazanılıyor; IAP, StoreKit ya da ödeme yok (koda göre doğrulandı) |

**App Privacy yanıtları:** "Data Not Collected". Tracking: No.

**Gizlilik politikası:** https://burakhamzalidev.github.io/istanbul_flight/privacy.html (TR/EN, 22 Ekim 2026; kaynak `gh-pages` dalı). İletişim: burakhamzali@gmail.com (onayınla herkese açık).

**AB DSA "trader" beyanı:** App Store Connect'te AB'de dağıtım için tüccar (trader) durumu beyanı gerekiyor. Gelir elde etmeyen ücretsiz bir uygulama için "trader değil" seçilebilir; trader seçilirse adres ve telefon herkese görünür. **Karar ve beyan senin; hukuki değerlendirme değildir.**

## 8. App Review uygunluk kontrolü (Guidelines)

| Konu | Değerlendirme |
|---|---|
| 2.1 Uygulama bütünlüğü | Otomatik testlerde çökme yok. **Gerçek cihazda doğrulanmadı.** Bütün düğmeler testlerle bağlı |
| 2.3 Doğru metadata | Metinler ve görseller yalnızca mevcut özellikleri gösteriyor; "arayüz Türkçe" belirtildi |
| 2.3.7 / 2.3.8 Ad ve ikon | Ad "İstanbul Flight"; oyun içindeki logo "MARTI · ISTANBUL FLIGHT". Aynı marka, tutarlı |
| 3.1.1 Uygulama içi satın alma | Yok. Simitler oyunda kazanılan, satın alınamayan puanlar; kozmetikler için gerçek para yok. **Uygun** |
| 4.2 Asgari işlevsellik | Tam oyun: beş bölge, ilerleme, görevler, başarımlar, mağaza |
| 5.1.1 Gizlilik | Politika URL'si yayında; veri toplanmıyor; tek izin gerekçeli |
| 5.1.2 Veri kullanımı | Veri yok |
| Yaş derecelendirmesi (öneri) | Şiddet: yok / çok hafif çizgi film (martı engele çarpınca sersemliyor; kan yok). Korku, cinsellik, küfür, madde, kumar, yarışma: yok. Kullanıcı içeriği, sohbet, sınırsız web erişimi, reklam: yok. **Beklenen: 4+** (kesin derece anket sonucunda) |
| Telif: görseller | Bütün pixel art depodaki üreticilerle **özgün** çizildi (`art/_source/pixel`). Gerçek yapılar fotoğraflardan **yalnızca referans** alındı (Wikimedia Commons CC0 / CC BY / CC BY-SA; kaynaklar docs/09–13); hiçbir fotoğraf pikseli uygulamada yok |
| Telif: sesler | 15 ses `art/_source/build_audio.js` ile **prosedürel sentezlendi** (özgün; Hicaz makamında müzik) |
| Telif: font | MartiPixel `art/_source/pixel/font.js` ile **özgün** üretildi |
| Üçüncü taraf markalar | Yok. Yer adları (Galata, Kız Kulesi, Boğaz Köprüsü vb.) coğrafi adlar |
| ⚠ Kesin hukuki değerlendirme yapılamayanlar | (1) Tarihî yapıların (Galata Kulesi, Kız Kulesi, Rumeli Hisarı, Süleymaniye; yüzyıllık yapılar) ve **Boğaz Köprüsü'nün** (1973) stilize çizimi. Türkiye'de FSEK m.40 kamuya açık yerlerdeki eserlerin resmedilmesine genel olarak izin veriyor; köprünün ticari kullanımına özel bir kısıt olup olmadığı **doğrulanmadı**. (2) docs klasöründeki karşılaştırma görsellerindeki CC BY / CC BY-SA kırpmaları (uygulamada yok, depoda atıflı). Gerekirse hukuki danışmanlık al |

## 9. iOS derleme bilgileri

| Konu | Değer |
|---|---|
| Yapılandırma | Release, `flutter build ipa --release --export-options-plist=/Users/builder/export_options.plist` (Codemagic) |
| İmzalama | Apple Distribution sertifikası (Codemagic `zar_dist`, 19 Ekim 2027'ye kadar) + App Store profili `istanbulflight_appstore` (19 Ekim 2027'ye kadar) |
| API anahtarı | Codemagic "Zar ASC Key" (depoda gizli bilgi yok) |
| Son imzalı derleme | **1.2.0 (3)**, Codemagic derlemesi `6ad94d5d…`, commit `bba3e50`, Mac mini M2, Xcode 26.x, iOS 26 SDK; IPA + dSYM (App, Flutter, Runner, objective_c) Codemagic çıktısında |
| Durum | App Store Connect: "Ready to Submit", yalnızca dahili test |
| Hata ayıklama sembolleri | dSYM'ler Codemagic çıktısında. App Store Connect çökme raporlarını sembolize etmek için gerekirse Codemagic'ten indirilip saklanabilir |

## 10. Yayın engelleri

1. ~~Gerçek iPhone testleri~~: kullanıcı bildirimiyle geçti (§4). iPad, uçak modu ve Instruments ölçümü NOT RUN.
2. **App Store Connect'te eksikler (§5a):** ekran görüntüleri yüklenmedi; App Privacy kaydedildi ama yayımlanmadı.
3. ~~App Review iletişim bilgisi~~: girildi.
4. ~~AB DSA trader beyanı~~: hesapta bu uygulama için zaten "trader değil" beyanı görünüyor.
5. **ITMS-91053 e-postası kontrolü** (gizlilik manifesti).
6. **iPad:** gerçek iPad'de denenmedi; arayüz küçük (bilinen; karar: olduğu gibi).

## 11. Senin tamamlaman gerekenler

2. 24 ekran görüntüsünü yükle (§5a; tarayıcı panelinde dosya yükleme aracım yok).
3. App Review iletişim bilgilerini (ad, +90 telefon, e-posta) gir.
4. App Privacy "Publish" onayı ver (beyan senin adına yapılıyor).
5. Mac (Apple Silicon) ve Apple Vision Pro dağıtımı için karar ver (§5a).
6. Apple'dan uyarı e-postası (ITMS-91053 vb.) geldiyse bana ilet.
7. Hepsi tamamlandığında **App Review'a gönderim için açık onay** ver (F). Onay sonrası **halka açık yayın için ayrıca onay** (H).

# App Store yayın kontrol listesi: İstanbul Flight 1.2.0 (3)

Gerçek duruma göre işaretli (22 Ekim 2026). Ayrıntı: [docs/14_app_store_launch.md](docs/14_app_store_launch.md).

İşaretler:

- `[x]` yapıldı ve doğrulandı
- `[~]` hazır ama hedefte uygulanmadı / doğrulanmadı
- `[ ]` yapılmadı
- **(SEN)** senin yapman ya da onaylaman gereken

## A. Release Candidate

- [x] Kod denetimi: `main` @ `36e9009`, çalışma ağacı temiz; `pubspec.yaml` 1.2.0+3
- [x] `flutter pub get`, `flutter analyze` (temiz), `flutter test` (166/166): 22 Ekim'de yeniden çalıştırıldı
- [x] İmzalı iOS derlemesi 1.2.0 (3), Codemagic, hatasız; IPA + dSYM saklanıyor
- [x] Derleme numarası çakışması yok (kullanılanlar: 1, 2, 3)
- [x] Bundle ID `com.burakhamzali.istanbulFlight`, iOS 15.0+, iPhone + iPad (değiştirilmedi)
- [~] Gizlilik manifesti: eklentiler kendi manifestlerini taşıyor; `audioplayers_darwin` manifestsiz ama gerekçe gerektiren API kullanmıyor. **(SEN)** ITMS-91053 e-postası geldi mi?

## B. Gerçek cihaz testleri (TestFlight)

- [x] iPhone senaryoları (docs/14 §4): kullanıcı bildirimiyle 17 PASS (bazıları kısmi kapsam), 3 NOT RUN
- [x] Güncelleme ve kayıtların korunması (kullanıcı bildirimi)
- [~] Uzun oturum 10–15 dk PASS; Instruments bellek ölçümü NOT RUN
- [ ] **(SEN)** iPad'de açılış ve temel akış

## C. Metadata ve gizlilik

- [x] TR/EN ad, alt başlık, tanıtım metni, açıklama, anahtar kelimeler (sınırlar ölçüldü: `docs/store/app_store_metadata.json`)
- [x] Mağaza görselleri: iPhone 1179×2556 ve iPad 2064×2752, TR/EN, 6'şar, alfasız (`docs/store/app_store/`). Web derlemesinden; gerçek cihaz görüntüsü değil
- [x] Gizlilik politikası yayında: https://burakhamzalidev.github.io/istanbul_flight/privacy.html
- [x] Destek sayfası yayında (iletişim e-postası ile): https://burakhamzalidev.github.io/istanbul_flight/support.html
- [x] App Privacy "Data Not Collected" yayımlandı (kullanıcı tarafından)
- [x] Yaş derecelendirmesi: 4+ (App Store Connect)
- [x] Kategori Games → Casual, Action
- [x] Fiyat ücretsiz; 174 bölge, Çin anakarası hariç
- [x] Mac / Apple Vision Pro dağıtımı: açık kalıyor (kullanıcı kararı; bu cihazlarda test yok)
- [x] Export compliance: `ITSAppUsesNonExemptEncryption = false` (plist)
- [x] TR/EN metinler, URL'ler, telif "2026 Burak Hamzalı" App Store Connect'e girildi
- [x] 24 ekran görüntüsü yüklendi (TR/EN, iPhone + iPad), sıra doğrulandı
- [x] App Review iletişim bilgileri girildi (kullanıcının verdiği bilgilerle)
- [x] AB DSA: hesapta "trader değil" görünüyor
- [x] Review notu girildi
- [x] Lisans denetimi: görseller, sesler ve font özgün; referans fotoğraflar yalnızca referans. ⚠ Boğaz Köprüsü tasviri için kesin hukuki görüş yok

## D. Build seçimi

- [x] App Store sürüm kaydı **1.2.0**
- [x] Build **1.2.0 (3)** sürüme eklendi
- [x] Yayın seçeneği **manuel**

## E–H. Gönderim ve yayın

- [x] E. App Review'a gönderilmeye hazır (bilinen risk: iPad'de denenmedi)
- [x] F. App Review'a gönderildi (22 Ekim 2026, açık onayla; Waiting for Review)
- [ ] G. Apple incelemesi tamamlandı
- [ ] H. **(SEN, açık onay)** Halka açık yayın (manuel)

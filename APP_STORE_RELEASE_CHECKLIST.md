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

- [ ] **(SEN)** 20 senaryo (docs/14 §4): hepsi **NOT RUN**. **Yayın engeli**
- [ ] **(SEN)** 1.0.0 / 1.1.0 → 1.2.0 silmeden güncelleme, kayıtların korunması
- [ ] **(SEN)** Bellek / performans / uzun oturum
- [ ] **(SEN)** iPad'de açılış ve temel akış

## C. Metadata ve gizlilik

- [x] TR/EN ad, alt başlık, tanıtım metni, açıklama, anahtar kelimeler (sınırlar ölçüldü: `docs/store/app_store_metadata.json`)
- [x] Mağaza görselleri: iPhone 1179×2556 ve iPad 2064×2752, TR/EN, 6'şar, alfasız (`docs/store/app_store/`). Web derlemesinden; gerçek cihaz görüntüsü değil
- [x] Gizlilik politikası yayında: https://burakhamzalidev.github.io/istanbul_flight/privacy.html
- [x] Destek sayfası yayında (iletişim e-postası ile): https://burakhamzalidev.github.io/istanbul_flight/support.html
- [~] App Privacy yanıtı hazır: "Data Not Collected", takip yok. App Store Connect'e girilmedi
- [~] Yaş derecelendirmesi yanıtları hazır (beklenen 4+). Girilmedi
- [~] Kategori Games → Arcade, Casual. Girilmedi
- [~] Fiyat: ücretsiz; bölge: Çin anakarası hariç bütün ülkeler (kullanıcı kararı). Girilmedi
- [x] Export compliance: `ITSAppUsesNonExemptEncryption = false` (plist)
- [~] Telif "2026 Burak Hamzalı". Girilmedi
- [ ] **(SEN)** App Review iletişim bilgileri (ad, telefon, e-posta)
- [ ] **(SEN)** AB DSA trader beyanı
- [~] Review notu hazır (docs/14 §5)
- [x] Lisans denetimi: görseller, sesler ve font özgün; referans fotoğraflar yalnızca referans. ⚠ Boğaz Köprüsü tasviri için kesin hukuki görüş yok

## D. Build seçimi

- [ ] App Store sürüm kaydı "1.0" → **1.2.0** (onayınla)
- [ ] Build **1.2.0 (3)** sürüme eklendi
- [ ] Yayın seçeneği **manuel**

## E–H. Gönderim ve yayın

- [ ] E. App Review'a gönderilmeye hazır (A–D tamamlanınca)
- [ ] F. **(SEN, açık onay)** App Review'a gönderildi
- [ ] G. Apple incelemesi tamamlandı
- [ ] H. **(SEN, açık onay)** Halka açık yayın (manuel)

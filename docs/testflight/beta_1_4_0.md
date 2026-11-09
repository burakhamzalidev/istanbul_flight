# TestFlight beta: İstanbul Flight 1.4.0 (Phase 2.4, Game Center)

> **Durum: TestFlight'a YÜKLENDİ (23 Ekim 2026, onayınla).** 1.4.0 (5): Codemagic `ios-testflight` hatasız (dal `feature/phase2-4-game-center`); App Store Connect işledi.
> - Codemagic'in harici beta incelemesine gönderme denemesi test bilgileri eksik olduğu için reddedildi: harici dağıtım yok.
> - Dahili "Ekip" grubu + harici "Test Kullanıcıları" grubu (23 Ekim 2026, kullanıcı isteğiyle).
> - "What to Test" (TR) girildi (23 Ekim 2026).
> - Beyza İnce: kullanıcı isteğiyle ekip üyeliği kaldırıldı; yalnızca **harici test kullanıcısı** olarak "Test Kullanıcıları" grubunda. 1.4.0 (5) bu grup için TestFlight beta incelemesine gönderildi ("Waiting for Review"); onaylanınca Beyza'ya TestFlight daveti gider.
> - TestFlight test bilgileri dolduruldu: beta açıklaması, geri bildirim e-postası, pazarlama ve gizlilik URL'leri, beta inceleme iletişimi (kullanıcının App Review için verdiği bilgiler), giriş gerekmez, inceleme notu.
>
> - **23 Ekim 2026 22:25 (İstanbul):** hesaptaki TÜM uygulamaların TÜM TestFlight derlemeleri Apple tarafında aynı anda "Expired" oldu. Sertifika, profiller ve üyelik geçerli; neden bilinmiyor.
> - **1.4.0 (6) (24 Ekim 2026, onayınla):** aynı daldan (`2b4bfe8`) yeniden derlendi; dahili grupta test ediliyor ve "Test Kullanıcıları" grubuna eklendi. Harici beta incelemesine gönderim API'de "Please try again later" (422) hatası veriyor, tekrar denenecek.
> - **App Store:** 1.2.0 sürüm kaydı 1.4.0'a çevrildi; derleme 6 bağlandı, Game Center işaretlendi, notlar güncellendi ([../store/app_review_reply_1_4_0.md](../store/app_review_reply_1_4_0.md)). Yayın türü: elle.
>
> App Store incelemesindeki 1.2.0 (3) bundan etkilenmez. Game Center tabloları ve başarımları App Store Connect'te "Prepare for Submission" durumunda; TestFlight derlemeleri Game Center'ın test (sandbox) ortamını kullanır.
> Ayrıntı: [../16_phase2_4_game_center.md](../16_phase2_4_game_center.md)

## What to Test (TR)

```
1.3.0'dan GÜNCELLEYİN (silmeyin), sonra:

1. Açılışta Game Center "Hoş geldin" bildirimi çıkıyor mu? Oyun beklemeden açılıyor mu?
2. Menü → kupa (Sıralama): rekorun ve "Game Center: <adın>" görünüyor mu?
3. Bir uçuş yapıp rekor kırın: Sıralama'da ve Game Center'da skor görünüyor mu?
4. Haftalık sekmesi: bitiş tarihi görünüyor mu? (İlk hafta 26 Ekim Pazartesi başlar.)
5. Arkadaşlar sekmesi: izin penceresi çıkıyor mu? İzin vermezseniz açıklama var mı?
6. "Başarımlar" düğmesi: açtığınız başarımlar Game Center'da %100 mü?
7. Uçak modunda bir rekor kırın, sonra interneti açıp uygulamayı öne getirin: skor gidiyor mu?
8. Game Center'dan çıkış yapınca (Ayarlar) oyun aynen oynanıyor mu?
9. Önceki rekorunuz (1.3.0'dan) tüm zamanlar tablosunda görünüyor mu?
```

## Bilinen sorunlar (beta 5)

1. Game Center gerçek cihazda ilk kez deneniyor; hata görürseniz ekran görüntüsüyle bildirin.
2. Haftalık tablo 26 Ekim 2026 00:00'dan (İstanbul) önce skor kabul etmez.
3. Arayüz yalnızca Türkçe; iPad'de arayüz küçük.

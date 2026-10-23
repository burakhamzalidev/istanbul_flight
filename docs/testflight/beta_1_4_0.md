# TestFlight beta: İstanbul Flight 1.4.0 (Phase 2.4, Game Center)

> **Durum: TestFlight'a YÜKLENDİ (23 Ekim 2026, onayınla).** 1.4.0 (5): Codemagic `ios-testflight` hatasız (dal `feature/phase2-4-game-center`); App Store Connect işledi.
> - Codemagic'in harici beta incelemesine gönderme denemesi test bilgileri eksik olduğu için reddedildi: harici dağıtım yok.
> - Yalnızca dahili "Ekip" grubu.
> - "What to Test" (TR) girildi (23 Ekim 2026).
> - Dahili test kullanıcısı: Beyza İnce, App Store Connect ekibine davet edildi (Developer rolü, yalnızca İstanbul Flight); daveti kabul edince "Ekip" grubuna eklenecek.
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

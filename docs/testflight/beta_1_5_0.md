# TestFlight beta: İstanbul Flight 1.5.0 (Phase 2.5, Günün Uçuşu)

> **Durum: TestFlight'a YÜKLENDİ (24 Ekim 2026, onayınla).** 1.5.0 (7): Codemagic `ios-testflight` (dal `feature/phase2-5-daily-challenge`, commit `9005e6c`); analiz ve testler geçti; Apple işledi ("VALID", son kullanma 22 Ocak 2027). İşleme ~45 dk sürdü (önceki derlemeler ~5 dk).
> - "Ekip" (dahili) grubunda test edilebilir ("IN_BETA_TESTING").
> - "Test Kullanıcıları" (harici, Beyza) grubuna eklendi, ama TestFlight beta incelemesine gönderilemedi: App Store Connect "Please try again later" (422). 1.4.0 (6) ile aynı hesap sorunu (23 Ekim 22:25'te tüm derlemeler aynı anda "Expired" olmuştu). Beyza bu derlemeyi beta incelemesi onaylanana kadar göremez.
> - "What to Test" (TR) girildi.
> - App Store sürüm kaydı (1.4.0 (6) bağlı) değiştirilmedi; App Review'a gönderim yok.
> Ayrıntı: [../17_phase2_5_daily_challenge.md](../17_phase2_5_daily_challenge.md)

## What to Test (TR)

```
YENİ: Günün Uçuşu (menüde takvim simgesi)

Önceki sürüm kuruluysa SİLMEDEN güncelleyin, sonra:

1. Menüde "Günün Uçuşu 3/3" görünüyor mu? Ekranda tarih, geri sayım, ödüller doğru mu?
2. "Uçuşa başla" → dokun: kalan hak 2/3'e düşüyor mu? Oyun sonunda günlük panel, kalan hak ve "Yeniden dene" görünüyor mu?
3. Uçuş sırasında uygulamayı kapatıp açın: o hak geri gelmemeli.
4. Duraklat → Ana menü: hak harcanmalı, skor sayılmamalı.
5. 3 hak bitince "Antrenman yap" çıkıyor mu? Antrenman skoru sıralamaya gitmemeli.
6. Günlük ödüller (15/35/60 skor) bir kez mi veriliyor?
7. Klasik "Uçmaya başla" ve rekorunuz eskisi gibi mi?
8. Game Center açıksa: günlük sıralama görünüyor mu? Skor "12 puan" mı yoksa "12puan" mı yazıyor?
9. İki telefonda aynı gün ilk engeller aynı mı?
```

## Bilinen sorunlar (beta 7)

1. Günlük Game Center tablosu 27 Ekim 2026 00:00 UTC'de (İstanbul 03:00) başlar; o zamana kadar günlük skor kuyrukta bekler.
2. Günlük tablo ve 1.4.0 Game Center öğeleri Apple incelemesinden geçmediği için TestFlight'ta Game Center'ın test ortamı kullanılır.
3. Arayüz yalnızca Türkçe; iPad'de arayüz küçük.

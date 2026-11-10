# TestFlight beta: İstanbul Flight 1.7.0 (Phase 2.7 + 2.8)

> **Durum: TestFlight'a YÜKLENDİ (10 Kasım 2026, kullanıcı onayıyla: "Sürüm ilerletip yap").** 1.7.0 (10): Codemagic `ios-testflight` derleme #12, dal `main` (commit `fe79d4c`), 6 dk 9 sn. Analiz ve 461 test Codemagic'te geçti. IPA 12:30'da yüklendi, Apple 12:33'te işledi.
> - "Ekip" (dahili) ve "Test Kullanıcıları" (harici) gruplarına eklendi; 2 davet.
> - "What to Test" (TR, aşağıdaki metin, kullanıcı onayıyla) App Store Connect'te girildi ve kaydedildi.
> - Harici grup "Ready to Submit": Codemagic'in beta incelemesine gönderme isteği yine 422 "Please try again later" aldı. 1.4.0 (6)'dan beri aynı hesap sorunu (Apple talebi 103007198858); post-processing "failed" görünür.
> - Yanlışlıkla `main` dalında "Doğrulama" iş akışı da başlatıldı (Codemagic Doğrulama #2). Yükleme yapmayan bir iş akışı; makine türü planda olmadığı için hemen başarısız oldu, etkisi yok.
> - İlk deneme (Codemagic #11, commit `68731ea`) testlerde durdu, IPA üretilmedi, yükleme olmadı. Tek düşen test `tutorial_test.dart` → "Mod regresyonu". Sebep: Testin sahte Game Center kupa dönemi yerel saatle yazılmıştı. Codemagic UTC'de çalıştığı için bu tarih geçerli bir hafta başı sayıldı, etkinlik antrenmana düştü. İstanbul saatinde (UTC+3) geçersiz sayılıp yok sayıldığı için yerelde geçiyordu. Düzeltme yalnızca testte (dönem UTC hafta başına sabitlendi); uygulama kodu değişmedi.
> - 1.6.0 (9) Phase 2.6 dalından derlenmişti. Bu sürüm Phase 2.7'yi (haftalık kupa, etkinlikler, sezon) ve Phase 2.8'i (ilk uçuş eğitimi, menü, oyun sonu, erişilebilirlik) ilk kez TestFlight'a taşıyor.
> - Dahili "Ekip" grubu test eder. "Test Kullanıcıları" (harici) grubuna Codemagic ekler; yeni sürümün ilk derlemesi olduğu için beta incelemesi gerekir.
> - App Store sürüm kaydına dokunulmaz; App Review'a gönderim yok.
> - Ayrıntılar: [../20_phase2_7_weekly_events.md](../20_phase2_7_weekly_events.md), [../21_phase2_8_player_experience.md](../21_phase2_8_player_experience.md)

## What to Test (TR)

```
YENİ: Haftalık İstanbul Kupası, hafta sonu etkinlikleri ve sezon ödülleri. Yeni oyunculara kısa uçuş eğitimi; yenilenen menü ve oyun sonu ekranı.

Önceki sürüm kuruluysa SİLMEDEN güncelleyin, sonra:

1. Güncellemeden sonra rekor, simit, görünümler ve albüm yerinde mi? Eğitim kendiliğinden açılmamalı.
2. Ana menü: "Uçuşa başla" hemen göze çarpıyor mu? Profil, Mağaza, Keşif ve Sıralama kolay bulunuyor mu?
3. Nasıl oynanır → "Eğitimi oyna": üç aşama (uçmak, engel geçmek, simit toplamak) anlaşılır mı? Çarpınca aynı aşamadan devam ediyor mu? "Eğitimi atla" çalışıyor mu?
4. Oyun sonunda "Tekrar uç" kaydırmadan görünüyor mu? "Ayrıntılar" açılıyor mu?
5. Menü → Etkinlikler: Kupa, Etkinlik ve Sezon sekmeleri açılıyor mu, süreler akıyor mu?
6. Kupa uçuşu: oyun sonunda kupa puanı, en iyi skor ve sezon puanı doğru mu?
7. Hafta sonu etkinliği (Cuma–Pazartesi): engeller net, kurallar anlaşılır mı?
8. iPhone ayarlarında Hareketi Azalt ve Büyük Metin açıkken menü ve oyun sonu düzgün mü? VoiceOver düğmeleri okuyor mu?
9. Sesi kapatın: simit toplayınca "+1" yazısı görünüyor mu?
10. Akıcılık 1.6.0 ile aynı mı? Küçük ekranda (iPhone SE) taşma var mı?
```

## Bilinen sorunlar

1. Game Center kupa tablosu ilk dönemini 16 Kasım 2026'da başlatıyor. Bu haftanın (9–16 Kasım) kupa skorları tabloya gitmez; uygulamadaki kupa ve ödüller çalışır.
2. Kupa tablosu ve günlük Game Center tablosu Apple incelemesinden geçmedi; TestFlight'ta Game Center'ın test ortamı kullanılır.
3. Büyük Metin 1,3 katına kadar uygulanır; daha büyük erişilebilirlik boyutlarında yazılar bu sınırda kalır.
4. Arayüz yalnızca Türkçe; iPad'de arayüz küçük.
5. Codemagic'in son adımı önceki derlemelerde hesap sorunu yüzünden başarısız oluyordu (Apple talebi 103007198858). Harici grubun beta incelemesi bu yüzden takılabilir.

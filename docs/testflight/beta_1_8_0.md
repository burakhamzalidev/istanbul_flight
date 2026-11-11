# TestFlight beta: İstanbul Flight 1.8.0 (Phase 2.9, performans ve pil)

> **Durum: TestFlight'a YÜKLENDİ (11 Kasım 2026, kullanıcı onayıyla).** 1.8.0 (11): Codemagic `ios-testflight` derleme #14, dal `main` (commit `4dad793`). Analiz ve 489 test Codemagic'te geçti. Apple 09:44'te işledi; "Ekip" ve "Test Kullanıcıları" gruplarına eklendi, 2 davet. "What to Test" (aşağıdaki metin, kullanıcı onayıyla) App Store Connect'te girildi ve kaydedildi.
> - Harici beta incelemesine gönderim yine 422 "Please try again later" aldı (hesap sorunu, Apple talebi 103007198858). Post-processing "failed" görünür.
> - Codemagic `ios-testflight`, dal `main`.
> - Derleme numarası Codemagic'te TestFlight'taki son numara + 1 olarak verilir (beklenen: 11).
> - **İçerik:** Phase 2.9. Yeni özellik yok; boşta uyku (pil), rüzgâr ve sis efektlerinde çizim çağrısı birleştirme, daha az disk yazma.
> - İlk deneme (Codemagic #13, commit `0b7a810`) testlerde durdu, yüklenmedi: engel parçalarını tek atlas çağrısıyla çizme Mac çizicisinde 292–892 piksel fark verdi. Bu birleştirme kapatıldı (görüntü aynı kalsın).
> - App Store sürüm kaydına dokunulmadı; App Review'a gönderim yok.
> - Ayrıntılar: [../22_phase2_9_performance_optimization.md](../22_phase2_9_performance_optimization.md)

## What to Test (TR)

```
YENİ: Performans ve pil sürümü. Oyun aynı; menüde, mağazada ve kartpostalda beklerken telefon daha az çalışmalı.

Önceki sürüm kuruluysa SİLMEDEN güncelleyin, sonra:

1. Rekor, simit, görünümler ve albüm yerinde mi?
2. Menüde 30 saniye dokunmadan bekleyin: arka plan durur. Ekrana dokununca hemen devam ediyor mu? O dokunuş düğmeye de basıyor mu?
3. Mağaza, albüm ya da etkinlikler açıkken arka plan duruyor; kapatınca akmaya devam ediyor mu?
4. Oyun sonunda kartpostal göründükten sonra "Tekrar uç" tek dokunuşla çalışıyor mu?
5. Rüzgârlı, sisli ve yağmurlu havada oyun 1.7.0'a göre daha akıcı mı? Görüntüde bir bozulma var mı?
6. 20 dakika kadar oynayın: telefon önceki sürüme göre daha az ısınıyor mu, pil daha yavaş mı düşüyor?
7. Oyun sırasında ana ekrana çıkıp dönün: oyun duraklamış olmalı, "Devam" ile sürmeli.
8. Günün Uçuşu ve İstanbul Kupası eskisi gibi mi?
```

## Bilinen sorunlar

1. Apple hesap sorunu (talep 103007198858) sürüyorsa TestFlight kurulumu "uygulama kullanılamıyor" hatası verebilir. Harici gruba beta incelemesi gönderilemeyebilir.
2. Uykudayken arka plandaki şehir donuk görünür; ilk dokunuşta akmaya devam eder (bilerek).
3. Game Center kupa ve günlük tabloları Apple incelemesinden geçmedi; TestFlight'ta Game Center'ın test ortamı kullanılır.

# TestFlight beta: İstanbul Flight 1.2.0 (Phase 2.2)

> **Durum: hazır, YÜKLENMEDİ.** Yükleme için onayın gerekiyor.
> Derleme numarası: App Store Connect'te son derleme **1.1.0 (2)**; Codemagic `ios-testflight` sıradakini otomatik olarak **3** yapar (`pubspec.yaml`: `1.2.0+3`, tutarlı).
> Bundle ID ve Codemagic iş akışları değişmedi. Ayrıntı: [../13_phase2_cosmetics_shop.md](../13_phase2_cosmetics_shop.md)

## Sürüm notları

**TR:**

```
İstanbul Flight 1.2.0 (beta 3): Simit Mağazası

• Simit Mağazası: uçuşlarda ve görevlerde kazandığın simitlerle Simit'e yeni görünümler al
• 5 yeni görünüm: Denizci Simit, Pilot Simit, Gece Martısı, Altın Kanat, İstanbul Kaşifi
• Martı Görünümü ekranı: sahip olduğun görünümler arasında geçiş yap, istediğinde klasiğe dön
• Seçtiğin görünüm uçuşta, menüde ve paylaştığın kartpostalda görünür
• Görünümler yalnızca görseldir: uçuşu, çarpışmayı ve skoru etkilemez
• Gerçek para, reklam veya abonelik yok
```

**EN:**

```
İstanbul Flight 1.2.0 (beta 3): Simit Shop

• Simit Shop: spend the simits you earn in flights and missions on new looks for Simit
• 5 new looks: Sailor, Pilot, Night Gull, Golden Wing, Istanbul Explorer
• Gull Looks screen: switch between owned looks or go back to classic anytime
• Your look appears in flight, in the menu and on the shared postcard
• Looks are cosmetic only: no effect on flight, collisions or score
• No real money, ads or subscriptions
```

## What to Test (TR)

```
1.1.0'dan GÜNCELLEYİN (silmeyin), sonra:

1. Veri: Rekor, seviye, XP, görevler, başarımlar ve simit bakiyesi aynı mı?
2. Menüdeki simit rozetine dokunun: Mağaza açılıyor mu, bakiye doğru mu?
3. Bir görünüm satın alın: Onay soruluyor mu? Simit bir kez mi düşüyor?
4. "Kullan" deyip uçun: Yeni görünüm uçuşta ve kartpostalda görünüyor mu?
5. Görünüm küçük ekranda tanınabiliyor mu? Gece bölgelerinde kayboluyor mu?
6. Uygulamayı tamamen kapatıp açın: Satın alımlar ve seçiminiz duruyor mu?
7. Profil → Martı görünümü → Klasik görünüme dön çalışıyor mu?
8. Simit yetmediğinde ne olduğu anlaşılıyor mu?
9. Fiyatlar size makul geldi mi? İlk görünüme kaç uçuşta ulaştınız?
```

## Bilinen sorunlar (beta 3)

1. Görünümler gerçek iPhone'da henüz görülmedi; renk ve okunurluk geri bildirimi bekleniyor.
2. Fiyatlar tahmini bir ekonomiye göre; ayarlanabilir.
3. Satın alınan simitler (harcanan) geri alınamaz; bu bir iade sistemi değil.
4. Arayüz yalnızca Türkçe; iPad'de arayüz küçük (1.0.0'dan).

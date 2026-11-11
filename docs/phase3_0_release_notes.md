# Phase 3.0 sürüm notları

## İlk halka açık sürüm önerisi

| | |
|---|---|
| Önerilen App Store sürümü | **1.8.0** |
| Önerilen derleme | **1.8.0 (11)**: TestFlight'ta. Codemagic #14, commit `4dad793`, 489 test geçti |
| Gerekçe | Uygulama hiçbir ülkede yayında değil (Apple arama servisi, 11 Kasım 2026: 0 sonuç). Son App Review gönderimi 1.2.0 (3), 23 Ekim'de "Information Needed" (2.1) ile döndü. App Store Connect'teki sürüm kaydı 1.4.0'dı ("Prepare for Submission"). Phase 3.0'ın kod değişikliği yalnızca tanıtım derlemesinde çalışan bir parametre; normal derlemeyi değiştirmiyor. Bu yüzden yeni derleme gerekmiyor |
| Neden 3.0.0 değil | Sürüm numarası faz adından değil, derlemeden gelir. TestFlight'taki son sürüm 1.8.0; yeniden numaralandırma testçiler için karışıklık yaratır |
| Gerçek cihaz testinde hata çıkarsa | Düzeltme 1.8.1 (12) olarak derlenir |

**App Store Connect'te yapılacaklar** (senin onayınla):
1. Sürüm kaydı 1.4.0 → 1.8.0.
2. Derleme 1.8.0 (11) seçilir.
3. Yeni metinler ve görüntüler yüklenir.
4. App Review notu ve ekran kaydı eklenir.
5. Yayın tercihi: **manuel**.

## What's New (ilk sürümde mağazada görünmez; ileride kullanmak için)

**TR:** İstanbul Flight'ın ilk sürümü: dokuz İstanbul bölgesi, Günün Uçuşu, haftalık İstanbul Kupası ve sezon, Simit Mağazası, İstanbul'u Keşfet albümü, Game Center sıralamaları ve ilk uçuş eğitimi.

**EN:** The first release of İstanbul Flight: nine Istanbul districts, the Daily Flight, the weekly Istanbul Cup and seasons, the Simit Shop, the Discover Istanbul album, Game Center leaderboards and a first-flight tutorial.

## 1.8.0 içeriği (önceki fazların özeti)

| Faz | İçerik |
|---|---|
| 1.x–2.2 | Tek dokunuşla uçuş, 5 bölge, premium pixel art, XP ve seviye, günlük görevler, başarımlar, Simit Mağazası |
| 2.3 | İstanbul'u Keşfet albümü, kartpostallar |
| 2.4 | Game Center: sıralamalar, başarımlar, çevrimdışı kuyruk |
| 2.5 | Günün Uçuşu (herkes aynı parkur, 3 dereceli hak) |
| 2.6 | Emirgan, Ortaköy, Dolmabahçe, Üsküdar; martı sürüleri, rüzgâr, yağmur, sis |
| 2.7 | Haftalık İstanbul Kupası, hafta sonu etkinlikleri, 4 haftalık sezon |
| 2.8 | İlk uçuş eğitimi, menü düzeni, oyun sonu, erişilebilirlik |
| 2.9 | Boşta uyku (pil), daha az çizim çağrısı (rüzgâr ve sis), daha az disk yazma |

## App Review notu (taslak, EN; 1.4.0 cevabının güncellemesi)

```
Hello App Review Team,

This submission (1.8.0) answers the earlier "Information Needed" request (Guideline 2.1). A screen recording made on a physical iPhone, starting from app launch, is attached.

İstanbul Flight is a one-tap pixel-art arcade game (rated 4+). There is no login, account, user-generated content, advertising or in-app purchase. The interface is in Turkish.

- Launch: new players see a short three-step tutorial (it can be skipped with "Eğitimi atla").
- Main menu: "UÇUŞA BAŞLA" starts a flight; tap anywhere to flap.
- "Günün Uçuşu" (Daily Flight): everyone flies the same course, three ranked attempts per day.
- "Etkinlikler" (Events): the weekly Istanbul Cup, weekend events and a four-week season.
- "Mağaza" (Shop): looks bought with in-game simits only; no real money.
- "Keşif" (Discover): postcard album of the nine districts.
- "Sıralama" (Leaderboards): optional Apple Game Center (leaderboards and achievements). The whole game is playable without Game Center.

External services: Apple Game Center only. No own servers, analytics, advertising or third-party SDKs. Progress is stored on the device.

Best regards,
Burak Hamzalı
```

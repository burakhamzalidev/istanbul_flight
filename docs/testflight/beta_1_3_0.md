# TestFlight beta: İstanbul Flight 1.3.0 (Phase 2.3)

> **Durum: TestFlight'a YÜKLENDİ (23 Ekim 2026, onayınla).** 1.3.0 (4): Codemagic `ios-testflight` (commit 8d022ee) hatasız; App Store Connect işledi ("Ready to Submit"); yalnızca dahili "Ekip" grubunda; What to Test (TR) girildi. Codemagic'in harici beta incelemesine gönderme denemesi test bilgileri eksik olduğu için reddedildi: harici dağıtım yok.
> Kaynak dal: `feature/phase2-3-istanbul-discovery`. App Store incelemesindeki sürüm **1.2.0 (3)** (etiket `v1.2.0+3`, commit `bba3e50`) bu daldan etkilenmez.
> Derleme numarası: TestFlight'taki son derleme **3**; Codemagic `ios-testflight` sıradakini otomatik olarak **4** yapar (`pubspec.yaml`: `1.3.0+4`, tutarlı).
> Ayrıntı: [../15_phase2_3_istanbul_discovery.md](../15_phase2_3_istanbul_discovery.md)

## Yükleme öncesi (onay sonrası yapılacak)

1. Codemagic `ios-testflight` iş akışını **bu daldan** elle başlat (iş akışının otomatik tetikleyicisi yok).
2. Not: `ios-ipa` ve `android-release` iş akışları `v*` etiketleriyle tetikleniyor; ikisi de hiçbir yere yükleme yapmıyor.
3. 1.2.0 incelemedeyken 1.3.0 derlemesini TestFlight'a yüklemek incelemeyi etkilemez; ama **1.3.0 derlemesini 1.2.0 sürüm kaydına ekleme**.

## Sürüm notları

**TR:**

```
İstanbul Flight 1.3.0 (beta 4): İstanbul'u Keşfet

• Yeni İstanbul keşif haritası: beş bölge gerçek yerlerinde
• Kartpostal albümü: her bölgeye ulaşınca kartı açılır, ilk keşif tarihi kaydedilir
• Her bölgede üç keşif hedefi: simit ödülleri, tamamlayınca bölge rozeti
• Kartpostalların arkasında İstanbul notları: Galata Kulesi, Kız Kulesi, Rumeli Hisarı...
• Beş rozeti topla, satılmayan "İznik Martısı" görünümünü aç
• Önceki ilerlemen korunur; keşfettiğin bölgeler albüme eklenir
```

**EN:**

```
İstanbul Flight 1.3.0 (beta 4): Discover Istanbul

• New Istanbul discovery map: five districts at their real locations
• Postcard album: reach a district to unlock its card; first discovery date is saved
• Three discovery goals per district: simit rewards and a district badge
• Istanbul notes on every postcard: Galata Tower, Maiden's Tower, Rumeli Fortress...
• Collect all five badges to unlock the "Iznik Gull" look (not sold in the shop)
• Your progress is kept; districts you already reached join the album
```

## What to Test (TR)

```
1.2.0'dan GÜNCELLEYİN (silmeyin), sonra:

1. Veri: Rekor, seviye, XP, simit, görünümler, görevler ve başarımlar aynı mı?
2. Ana menü → "İstanbul'u Keşfet": daha önce ulaştığınız bölgeler albümde açık mı?
   (Eski bölgelerde "Önceki bir sürümde keşfedildi" yazmalı; tarih uydurulmamalı.)
3. Haritada işaretler doğru yerlerde mi? Dokununca bölge detayı açılıyor mu?
4. Bir uçuş yapın: oyun sonunda yeni kartpostal ve keşif hedefleri yazıyor mu?
5. Bir hedefi tamamlayın: simit bir kez mi ekleniyor? Uygulamayı kapatıp açınca duruyor mu?
6. Kartpostal arkasındaki notlar kısa ve ilgi çekici mi? Hata görürseniz yazın.
7. Küçük ekranda harita ve albüm okunuyor mu, kaydırma rahat mı?
8. Mağazada "İznik Martısı" satılmıyor, "Albüm ödülü" olarak görünüyor mu?
```

## Bilinen sorunlar (beta 4)

1. Keşif ekranları gerçek iPhone'da henüz denenmedi (web derlemesi ve otomatik testlerle doğrulandı).
2. 1.2.0'da tutulmayan bölge bazlı istatistikler (bölgede toplanan simit vb.) sıfırdan başlar.
3. Harita kıyı çizgisi stilize edilmiştir (±100 m); bölge işaretleri gerçek koordinatlardadır.
4. Arayüz yalnızca Türkçe; iPad'de arayüz küçük (1.0.0'dan).

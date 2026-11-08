# TestFlight beta: İstanbul Flight 1.6.0 (Phase 2.6, Genişleyen İstanbul)

> **Durum: HAZIRLANDI, henüz yüklenmedi.** Kullanıcı 1.6.0 sürümünü ve TestFlight yüklemesini onayladı (9 Kasım 2026). Codemagic `ios-testflight`, dal `feature/phase2-6-expanded-istanbul`. Derleme numarasını Codemagic verir (TestFlight'taki son numara + 1).
> - Dahili "Ekip" grubu test eder.
> - "Test Kullanıcıları" (harici) grubuna eklenir; yeni sürümün ilk derlemesi olduğu için beta incelemesi gerekir. Hesap sorunu (Apple talebi 103007198858) sürerse 422 ile takılabilir.
> - App Store sürüm kaydına dokunulmaz; App Review'a gönderim yok.
> Ayrıntılar: [../19_phase2_6_expanded_istanbul.md](../19_phase2_6_expanded_istanbul.md)

## What to Test (TR)

```
YENİ: İstanbul büyüdü! 120 puandan sonra rota Emirgan, Ortaköy, Dolmabahçe ve Üsküdar'a uzanıyor.

Önceki sürüm kuruluysa SİLMEDEN güncelleyin, sonra:

1. Rumeli Hisarı'ndan sonra yeni bölgelere geçiş yumuşak mı? Üstteki rota çubuğunda 9 durak var mı?
2. Yeni engeller (Emirgan, Ortaköy, Dolmabahçe, Üsküdar) net görünüyor mu? "Çarpmadım ama öldüm" anı oldu mu?
3. 120 puandan sonra sağdan size doğru uçan koyu sırtlı martılar çıkıyor. Tehlike olduğu anlaşılıyor mu? Kanat ucuna sürtünce ölmemeli.
4. Kavisli rüzgâr şeritleri olan aralıklarda kuş hafifçe yukarı/aşağı itiliyor. Fark ediliyor mu, adil mi?
5. Bazen yağmur, sis ya da rüzgârlı hava geliyor. Engeller her zaman net mi? Göz yoruyor mu?
6. İstanbul'u Keşfet: 4 yeni kart, harita ve hedefler doğru mu? Eski rozetler, kartpostallar ve İznik görünümü duruyor mu? (Albüm yüzdesi yeni kartlar yüzünden düşebilir; bu normal.)
7. Günün Uçuşu eskisi gibi mi? Orada martı sürüsü, rüzgâr ve hava efekti olmamalı.
8. Oyun akıcı mı? Uzun oynayınca yavaşlama, ısınma ya da kapanma oldu mu?
9. Sesi açın: yağmurda yağmur sesi, martı sürüsü gelince bir çığlık duyuluyor mu? Sessiz modda hiç ses çıkmamalı.
10. Küçük ekranda (iPhone SE) menü, kartpostal ve harita taşıyor mu?
```

## Bilinen sorunlar

1. Günlük Game Center tablosu ve 1.4.0 Game Center öğeleri Apple incelemesinden geçmediği için TestFlight'ta Game Center'ın test ortamı kullanılır.
2. Yeni bölgeler için Game Center başarımı yok.
3. Arayüz yalnızca Türkçe; iPad'de arayüz küçük.

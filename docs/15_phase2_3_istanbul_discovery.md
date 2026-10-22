# Phase 2.3: İstanbul Keşif Albümü ve Koleksiyon Sistemi

> Dal: `feature/phase2-3-istanbul-discovery` · Sürüm: **1.3.0+4** (hazır, **yüklenmedi**) · Tarih: 23 Ekim 2026
> TestFlight hazırlık notu: [testflight/beta_1_3_0.md](testflight/beta_1_3_0.md)

## 0. Sürüm ve dal güvenliği

| Konu | Durum |
|---|---|
| App Store incelemesindeki sürüm | **1.2.0 (3)**, Codemagic derlemesi commit `bba3e50`'den. App Store Connect'te "Waiting for Review". **Dokunulmadı, geri çekilmedi** |
| Koruma etiketi | `v1.2.0+3` → `bba3e50` (açıklamalı etiket, GitHub'a gönderildi) |
| Yayın dalı | `release/1.2.0` → `60485ae` (`main` ile aynı; `bba3e50`'den sonra yalnızca belge değişti) |
| Geliştirme dalı | `feature/phase2-3-istanbul-discovery`. `main`'e ve `release/1.2.0`'a geliştirme commit'i yok |
| App Store Connect | Hiçbir şey yüklenmedi, hiçbir alan değişmedi |
| Codemagic | `ios-testflight` otomatik tetiklenmez. Not: `ios-ipa` ve `android-release` `v*` etiketiyle tetiklenebilir; ikisi de yükleme yapmaz |

## 1. Güncel mimari analizi

| Sistem | Bulgu | Phase 2.3'te |
|---|---|---|
| `PlayerProgress` (`lib/services/progress.dart`) | Değişmez model, tek anahtar `progress_v2`, toleranslı `fromJson`, v1 → v2 geçişi | `discovery` alanı eklendi; şema sürümü 3 (aynı anahtar) |
| `ProgressController` (`lib/game/game_services.dart`) | `RunFinished` ile `settleRun`; sıralı kayıt; satın alma önce diske yazılır | Değişmedi; keşif `settleRun` içinde |
| XP / seviye (`progression_config.dart`) | Uçuş XP'si + ilk bölge keşfi 25 XP (Haliç hariç) | **Değişmedi.** Keşif albümü XP vermez |
| Günlük görevler, başarımlar | Uçuş özetinden ilerler; ödül defteri | Değişmedi |
| Simit ekonomisi | `simitBalance = totalSimits + bonusSimits - spentSimits` | Keşif ödülleri `bonusSimits`'e eklenir |
| Kozmetik mağazası (`cosmetics.dart`) | Katalog + `ShopConfig`; sahiplik `unlockedCosmetics` | `rewardOnly` görünüm (İznik Martısı); satın alma `notForSale` döner |
| Bölge geçişi (`day_cycle.dart`) | Skora bağlı 5 bölge (0/15/35/60/90) | Değişmedi; bölge sırası keşif kimliği olarak kullanılır |
| Oyun (`istanbul_flight_game.dart`) | Engel / simit / kıl payı sayaçları, tek `RunFinished` | Bölge bazlı sayaçlar (`zoneStats`). **Fizik, çarpışma ve skor değişmedi** |
| Pixel art | `art/_source/pixel/*.js` üreticileri | Yeni: harita (`map.js`), 4 ikon (sona eklendi), İznik görünümü. Mevcut görseller yeniden tasarlanmadı; mevcut 19 ikonun pikselleri birebir aynı (doğrulandı) |
| Menü / overlay | Flame overlay + `modal` adı; `ModalCard` | Tek pencere `Overlays.discovery`, içinde sekme ve geri gezinmesi |

## 2. Keşif sistemi

**Veri modeli** (`lib/progression/discovery.dart`, `DiscoveryState`):

| Alan | Anlamı |
|---|---|
| `firstSeen` | Bölge → ilk keşif zamanı (bu sürümden itibaren) |
| `legacyZones` | Albümden önce keşfedilmiş bölgeler: tarih bilinmiyor, **uydurulmaz** |
| `zoneRecords` | Bölge rekoru: tek uçuşta o bölgede geçilen en çok engel |
| `progress` | Hedef ilerlemesi (biriken ya da tek uçuşun en iyisi; hedefte durur) |
| `completed` | Tamamlanan hedef → zaman. **Ödül defteri**: buradaki hedefin ödülü bir daha verilmez |
| `badges` | Üç hedefi biten bölgelerin rozetleri |
| `albumCompletedAt` | Beş rozet tamamlanınca (albüm ödülü bir kez) |

**Akış:** Oyun her engeli, simidi ve kıl payını o anki bölgeye yazar. Engel, bölge değişmeden önce sayılır: 15. puan Haliç'e aittir.
- Uçuş sonunda `RunResult.zoneStats` gönderilir.
- `settleRun` sırası:
  1. bölge keşfi ve Phase 2.1 keşif XP'si (değişmedi),
  2. **`settleDiscovery`**,
  3. günlük görevler,
  4. başarımlar.
- **İdempotentlik:** aynı `runId` ikinci kez hesaplanmaz. Ayrıca her ödül `completed` defteriyle, rozet ve albüm ödülü de kayıtlı alanlarıyla tek seferliktir.
- **Kilit:** Bölge keşfinin tek kaynağı Phase 2.1'deki `discoveredZones`. Keşfedilmemiş bölgenin hedefleri ilerlemez; kilitli kart %0 görünür.

## 3. Harita tasarımı

- **Görsel:** `assets/images/pixel_art/ui/istanbul_map.png` (160×160), `art/_source/pixel/map.js` ile üretildi.
  - Kıyı çizgisi gerçek enlem/boylam noktalarından (±100 m) çizildi; kuzey yukarıda.
  - Kutu: boylam 28.925–29.085, enlem 40.990–41.110 (~13,4 × 13,3 km, 1 px ≈ 84 m).
  - Haritada Haliç, Boğaziçi, Marmara, tarihî yarımada, Beyoğlu, Üsküdar ve Kadıköy mahalle dokusu, Boğaziçi Köprüsü (Ortaköy–Beylerbeyi), Galata Köprüsü ve Kız Kulesi adacığı var.
- **İşaretler:** gerçek koordinatlarda, aynı izdüşümle (`MapProjection`):

| # | Bölge (oyun sırası) | Gerçek yer | Enlem, boylam |
|---|---|---|---|
| 1 | Haliç | Haliç, Unkapanı açıkları (Süleymaniye'nin altı) | 41.0315, 28.9555 |
| 2 | Galata | Galata Kulesi | 41.0256, 28.9742 |
| 3 | Kız Kulesi | Kız Kulesi adacığı | 41.0211, 29.0041 |
| 4 | Boğaz Köprüsü | Köprünün ortası | 41.0458, 29.0335 |
| 5 | Rumeli Hisarı | Rumeli Hisarı | 41.0847, 29.0564 |

- **Oyun sırası ile coğrafya ayrı:**
  - İşaretin içindeki numara uçuş sırasını, konumu gerçek yeri gösterir; harita altında bu açıklama yazılı.
  - Kesikli rota oyun sırasıyla bağlar: ulaşılan kısım altın, kalanı soluk.
- **İşaret durumları:**
  - kilitli: gri, kilit ikonu
  - keşfedildi: lacivert, numaralı
  - rozet: altın
- **Dokunma ve ölçek:**
  - Her işaretin dokunma alanı 44 pt.
  - Ölçek cihaz pikselinde tam sayıya yuvarlanır, pixel art keskin kalır (320 pt'de 1,5×, 390 pt'de ~2×).
- **Harita altı:** beş bölge satırı (ad ya da "???", tamamlanma çubuğu, hedef sayısı ya da rozet).

## 4. Bölge hedefleri

Hedef türleri ve sayım:
- **Biriken:** bölgede toplanan simit, bölgede kıl payı. Uçuşlar boyunca toplanır.
- **Tek uçuşluk:** bölgede geçilen engel, uçuş puanı. O ana kadarki en iyi değer tutulur.
- **Puan hedefleri** bölgenin puan aralığında tutuldu; tek uçuşluk engel hedefi de bölgeye sığıyor (testle doğrulandı).

| Bölge | Hedef 1 | Hedef 2 | Hedef 3 |
|---|---|---|---|
| Haliç (0–14) | Haliç'e ulaş · +5 | Haliç'te 5 simit topla · +10 | Tek uçuşta Haliç'te 10 engel geç · +10 |
| Galata (15–34) | Galata'ya ulaş · +10 | Galata'da 3 kıl payı geçiş · +10 | Tek uçuşta 25 puana ulaş · +15 |
| Kız Kulesi (35–59) | Kız Kulesi'ne ulaş · +10 | Bölgede 10 simit topla · +15 | Tek uçuşta bölgede 15 engel geç · +15 |
| Boğaz Köprüsü (60–89) | Köprü'ye ulaş · +15 | Köprü'de 5 kıl payı geçiş · +15 | Tek uçuşta 75 puana ulaş · +20 |
| Rumeli Hisarı (90+) | Rumeli Hisarı'na ulaş · +15 | Bölgede 8 simit topla · +20 | Tek uçuşta 100 puana ulaş · +25 |

Tamamlanma yüzdesi: üç hedef eşit ağırlıkta, kısmi ilerleme sayılır. Albüm yüzdesi beş bölgenin ortalamasıdır. Aynı olay iki kez sayılmaz; bunu oyun tarafında tek `RunFinished`, hesapta `runId` ve hedefte ödül defteri birlikte sağlıyor.

## 5. Kartpostal koleksiyonu

- **Görsel:** Phase 2.1 kartpostalıyla aynı çizici (`ZonePostcardPainter`). Oyunun zaten belleğe yüklenmiş pixel art katmanları kullanılıyor: gök, güneş/ay, bulut, silüet, simge, kıyı, su. Yeni ve düşük kaliteli görsel üretilmedi; ek bellek yok.
- **Kart içeriği:**
  - bölge adı ve gerçek yer
  - kısa açıklama (≤ 90 karakter)
  - ilk keşif tarihi; eski kayıtta "Önceki bir sürümde keşfedildi (tarih kaydı yok)"
  - bölge rekoru
  - tamamlanma yüzdesi, rozet
  - üç hedef (ilerleme ve simit ödülü)
  - dört İstanbul notu: Tarih, Mimari, İstanbul için, Az bilinen
- **Kilitli kart:**
  - Görsel gri ve soluk, kilit ikonu; ad "???".
  - "N puanda açılır" bilgisi gösteriliyor.
  - Notlar keşfedilince açılıyor (merak unsuru).
- **Kalıcılık:** Açılan kartlar `discoveredZones` ve `firstSeen`/`legacyZones` ile kalıcı.

## 6. Tarihî bilgiler ve kaynaklar

Her bölgede dört kısa bilgi var (≤ 160 karakter, testle sınırlandı). Yalnızca birden fazla kaynakta tutarlı bulunan ya da güvenilir tek kaynağı olan bilgiler kullanıldı.

| Bölge | Kullanılan bilgi | Kaynak |
|---|---|---|
| Haliç | ~7,5 km'lik haliç, adı "nehir ağzı"; Bizans zinciri; 1453'te gemilerin karadan yürütülmesi | [Wikipedia: Golden Horn](https://en.wikipedia.org/wiki/Golden_Horn) |
| Haliç (Süleymaniye) | Mimar Sinan, Kanuni için; temel 1550, açılış 1557 | [Wikipedia: Süleymaniye Mosque](https://en.wikipedia.org/wiki/S%C3%BCleymaniye_Mosque) (açılış yazıtına dayanıyor) |
| Galata | 1348, Cenevizliler; ilk adı "Kutsal Haç Kulesi"; 18. yy'dan itibaren yangın gözetleme; 6 Ekim 2020'de müze olarak yeniden açılış | [Wikipedia: Galata Tower](https://en.wikipedia.org/wiki/Galata_Tower), [Archnet: Galata Kulesi](https://www.archnet.org/sites/8254) (1348) |
| Kız Kulesi | 1110 I. Aleksios Komnenos; Üsküdar'a ~200 m; 1721 yangını sonrası fener; 2021–2023 restorasyonu, ortalama 25 m derinlikte 201 kazık | [Wikipedia: Maiden's Tower](https://en.wikipedia.org/wiki/Maiden%27s_Tower), [GZT: Kız Kulesi açılıyor](https://www.gzt.com/gundem/kiz-kulesi-iki-yil-aradan-sonra-bugun-ziyarete-aciliyor-2037369) (Bakanlık açıklaması) |
| Boğaz Köprüsü | 30 Ekim 1973; 2016'dan beri 15 Temmuz Şehitler Köprüsü; ana açıklık 1.074 m, kuleler 165 m; Ortaköy–Beylerbeyi; 2007'den beri LED aydınlatma | [Wikipedia: Bosphorus Bridge](https://en.wikipedia.org/wiki/Bosphorus_Bridge) |
| Rumeli Hisarı | 1452, II. Mehmed; Halil, Zağanos, Sarıca Paşa kuleleri; en dar yer (~660 m), Anadolu Hisarı karşısı; "Boğazkesen"; 1960'tan beri müze | [Wikipedia: Rumelihisarı](https://en.wikipedia.org/wiki/Rumelihisar%C4%B1), [Türkiye Müzeleri](https://turkishmuseums.com/museum/detail/2077-istanbul-rumeli-hisari-fortress-museum/2077/4) |

**Bilinçli olarak kullanılmayanlar:**
- **Hezârfen Ahmed Çelebi'nin uçuşu:** Kaynaklarda doğrulanmış bir anlatım bulunamadı; efsane niteliğinde.
- **Galata Kulesi'nin kesin yüksekliği:** Kaynaklar farklı (62,59 m çatı ucu / 66,90 m tepe süsü dahil).
- **Rumeli Hisarı'nın kesin yapım süresi:** Kaynaklar 4 ile 4,5 ay arasında ve başlangıç tarihleri farklı. Metinde "birkaç ay içinde" denildi.
- **Kız Kulesi'nin 1763'te taştan yeniden yapımı:** Tek kaynakta bulundu.
- **Britannica:** Erişim engellendi (HTTP 403); kaynak olarak kullanılmadı.

## 7. Ödül dengesi

| Ödül | Değer | Gerekçe |
|---|---|---|
| İlk bölge keşfi | **25 XP** (Phase 2.1, değişmedi) | Tekrar verilmez; albüm XP eklemez |
| 15 hedef | Toplam **210 simit** (5–25 arası, bölge ilerledikçe artar) | Mağaza toplamı 900 simit; albüm ~%23 katkı. Ekonomiyi bozmadan ilk görünüme hız katar |
| Bölge rozeti | Rozet (görsel) | Simit hedeflerde verildiği için rozette ek ödül yok (çift ödül yok) |
| Beş rozet | **İznik Martısı** (çini mavisi kanatlar, başında kırmızı lale) | `rewardOnly`: mağazada "Albüm ödülü" diye görünür, satın alınamaz. Mağazadaki 6 görünümle çakışmaz. Sahiplik Phase 2.2 kümesine eklenir; seçim oyuncunun |

## 8. Arayüz

- **Ana menü:**
  - "Uçmaya başla"nın hemen üstünde tek giriş noktası: "İstanbul'u Keşfet %N".
  - 320 pt'de etiket "Keşfet" oluyor.
  - Menü kalabalıklaşmadı: başka düğme eklenmedi.
  - 667 ve 568 pt yüksekliklerde menü boşlukları biraz daraltıldı.
- **Keşif penceresi:**
  - Albüm özeti: yüzde, rozet n/5, kartpostal ve hedef sayısı.
  - Sekmeler: **Harita** / **Albüm**.
  - Bölge detayında belirgin bir geri düğmesi var. Sistem geri tuşu pencereyi kapatıyor.
- **Oyun sonu özeti:** "Albüme yeni kartpostal: …", "Keşif: … (+N)", "Rozet: …", "Albüm tamam! İznik Martısı açıldı."
  - Paylaşılan kartpostal görseli değişmedi.
- **Ölçü ve erişilebilirlik:**
  - Pixel stil korundu: `pixelBox`, MartiPixel fontu, 5'in katı boyutlar, `PixelIcon` atlası.
  - Dokunma hedefleri ≥ 44 pt.
  - Semantik etiketler eklendi.
  - Safe Area `ModalCard` ile sağlanıyor.

## 9. Kalıcı kayıt ve geçiş

- **Şema:** Anahtar aynı (`progress_v2`), şema sürümü `v: 3`, yeni alan `discovery`. Bütün eski alanlar aynen okunur ve yazılır.
- **v2'den (1.1.0 / 1.2.0) geçiş:** `discovery` yoksa bir kez `migrateDiscovery` çalışır ve sonuç kaydedilir.
  - Keşfedilmiş bölgeler `legacyZones` olarak albüme girer (tarih yok).
  - Bu bölgelerin "ulaş" hedefleri tamamlanır ve simit ödülleri bir kez verilir (bu hedefler gerçekten başarılmış). XP verilmez.
  - Bölge bazlı istatistik eski sürümlerde tutulmadığı için diğer hedefler 0'dan başlar; uydurulmaz.
- **v1'den (1.0.0) geçiş:** Önce mevcut v1 → v2 geçişi (rekordan bölgeler), ardından albüm geçişi.
- **Korunanlar (testle):**
  - rekor (`best_score_v1`, ayrı anahtar), XP, seviye, simitler, harcanan simit
  - satın alınmış ve seçili görünümler
  - günlük görevler ve ödül defteri, başarımlar, hesaplanmış uçuşlar
  - eski `progress_v1` silinmez
- **Sürüm düşürmeye karşı yedek:**
  - Her kayıtta keşif durumu ayrıca `discovery_backup_v1` anahtarına yazılır.
  - Risk: App Store'daki 1.2.0, TestFlight 1.3.0'ın üzerine kurulursa `discovery` alanını tanımadığı için kaydederken düşürür.
  - Yeniden yükseltmede albüm yedekten gelir ve ödüller ikinci kez verilmez. Arada keşfedilen bölgeler de albüme eklenir (`reconcileDiscovery`).
- **Bozuk kayıt:**
  - Her alan ayrı okunur: geçersiz bölge, negatif sayı, bozuk tarih atlanır.
  - `discovery` Map değilse geçiş yeniden kurar, diğer alanlar korunur.
  - Ana kayıt tamamen bozuksa Phase 2.1'deki yedekleme (`progress_v2_corrupt`) geçerli.

## 10. Performans

- **Harita görseli** (160×160, ~5 KB) yalnızca keşif penceresi açılınca `Image.asset` ile yüklenir. Açılış süresini etkilemez.
- **Kartpostallar** zaten yüklü oyun katmanlarını çizer: yeni doku yok, ek bellek yok.
- **İznik Martısı sheet'i** (288×84) diğer görünümler gibi açılışta yüklenir: ~100 KB bellek, ihmal edilebilir.
- **Uçuş içi maliyet:** Olay başına bir sayaç artışı (bölge haritasında). Çizim ya da fizik maliyeti yok. FPS'yi etkilemesi beklenmez; gerçek cihazda ölçülmedi.
- **Keskinlik:** Bütün pixel art `FilterQuality.none` ve tam sayı cihaz pikseli ölçeğiyle çiziliyor.

## 11. Test sonuçları (23 Ekim 2026)

| Kontrol | Sonuç |
|---|---|
| `flutter analyze` | **Temiz** |
| `flutter test` | **203 / 203 geçti**: önceki 166 + 27 keşif mantığı (`test/discovery_test.dart`) + 10 arayüz (`test/discovery_ui_test.dart`) |
| Değiştirilen eski testler | 3 beklenti yeni ödüller nedeniyle güncellendi, amaçları korundu: (1) fiyat tablosu yalnızca satılık görünümler; (2) ilk uçuş bonusu artık +5 Haliç keşfi içerir; (3) 1.0.0 kaydının bakiyesi Haliç + Galata "ulaş" ödüllerini içerir |
| Web derlemesi (görsel kontrol, 390×844 ve 320×568) | Menü, harita, bölge detayı, notlar, albüm, kilitli kartlar: taşma yok, pixel art keskin |
| Gerçek iPhone | **NOT RUN** (TestFlight'a yüklenmedi) |

Keşif testlerinin kapsadıkları:
- bölge keşfi ve ilk keşif tarihi
- bölge rekoru
- biriken ve tek uçuşluk hedefler, bölgeler arası ayrım
- tek seferlik ödüller ve keşif XP'sinin verilmemesi
- aynı uçuşun iki kez hesaplanmaması (`settleRun` ve `ProgressController`)
- albüm ödülü ve sahiplik korunması, İznik'in satılmaması
- JSON gidiş-dönüş ve SharedPreferences kalıcılığı
- v2 ve v1 geçişi, sürüm düşürme yedeği, uzlaştırma
- bozuk kayıt
- gerçek oyun akışında bölge sayaçları (Haliç 15 / Galata 2 engel, toplamlar tutarlı)
- harita koordinatlarının coğrafi sırası
- içerik sınırları ve ödül dengesi

Arayüz testlerinin kapsadıkları:
- menü giriş noktası, harita ve 5 işaret, bölge detayı ve geri dönüş
- eski bölgede uydurulmamış tarih, kilitli bölgede gizli bilgiler
- albüm sekmesi, geri tuşu, oyun sonu özeti
- 320×568 / 375×667 / 430×932'de taşma olmaması

## 12. Ekran görüntüleri (web derlemesi, örnek kayıtla)

Örnek kayıt: Haliç (eski sürümden, rozetli), Galata ve Kız Kulesi keşfedilmiş.

| Dosya | İçerik |
|---|---|
| [01_menu_390.jpg](screenshots/phase2_3/01_menu_390.jpg) | Ana menü, "İstanbul'u Keşfet %50" |
| [02_harita_390.jpg](screenshots/phase2_3/02_harita_390.jpg) | Keşif haritası, rota ve bölge satırları |
| [03_bolge_detay_390.jpg](screenshots/phase2_3/03_bolge_detay_390.jpg) | Galata: kartpostal, ilk keşif, rekor, hedefler |
| [04_bolge_notlari_390.jpg](screenshots/phase2_3/04_bolge_notlari_390.jpg) | Galata: İstanbul notları |
| [05_album_390.jpg](screenshots/phase2_3/05_album_390.jpg) | Albüm: Haliç (rozet), Galata |
| [06_kilitli_kartlar_390.jpg](screenshots/phase2_3/06_kilitli_kartlar_390.jpg) | Kız Kulesi ve kilitli 4–5. kartlar |
| [07_menu_320.jpg](screenshots/phase2_3/07_menu_320.jpg) | 320×568 ana menü ("Keşfet") |
| [08_harita_320.jpg](screenshots/phase2_3/08_harita_320.jpg) | 320×568 harita |

Not: Ekran görüntüleri web derlemesinden alındı; gerçek iPhone görüntüsü değil. 03–06 numaralı görüntüler geri düğmesi stili düzeltilmeden önce alındı; düğme artık belirgin.

## 13. Bilinen eksikler

1. **Gerçek cihaz testi yok:** iPhone'da FPS, bellek ve dokunma hissi doğrulanmadı.
2. **Harita kıyı çizgisi stilize:** ±100 m; adalar ve küçük koylar yok. Bölge işaretleri gerçek koordinatta.
3. **İngilizce yok:** Tarihî notlar ve arayüz yalnızca Türkçe.
4. **Eski bölgelerin geçmişi yok:** Önceden keşfedilen bölgelerin ilk keşif tarihi ve bölge istatistikleri yok (bilinçli: uydurulmadı).
5. **Rozet ekranı ayrı değil:** Rozetler harita satırında, kartta ve özette gösteriliyor.
6. **İznik ödülü sessiz geliyor:** Albüm tamamlanınca İznik Martısı açılıyor ama otomatik seçilmiyor. Bu bilinçli bir tercih: oyuncunun seçimi korunur.

## 14. Sonraki faz önerileri

1. **Gerçek cihaz turu:** TestFlight 1.3.0 (4) ile güncelleme, geçiş ve kalıcılık kontrolü.
2. **İngilizce yerelleştirme:** Notlar ve arayüz; App Store'daki İngilizce metinle uyum.
3. **Ses ipucu:** Bölge kartı açılınca kısa bir "posta damgası" sesi ve animasyonu (Animasyonları azalt ayarına bağlı).
4. **Yeni bölgeler:** Örneğin Ortaköy Camii, Dolmabahçe, Kadıköy. Her biri harita + kartpostal + 3 hedef olarak, aynı veri yapısıyla eklenebilir.
5. **Notlara kaynak bağlantısı:** "Daha fazla bilgi" ile yalnızca kaynak adı gösterilebilir (uygulama internete bağlanmadığı için bağlantı açmak yerine).

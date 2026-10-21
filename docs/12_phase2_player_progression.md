# Phase 2.1: Oyuncu ilerlemesi, günlük görevler ve başarımlar

> Not: `12_kopru_gercek_referans.md` ile aynı numara; dosya adı görevde istendiği gibi bırakıldı.
> Sürüm: **1.1.0 (2)**. TestFlight'a **yüklenmedi** (onay bekliyor). Beta materyalleri: [testflight/beta_1_1_0.md](testflight/beta_1_1_0.md)

## Özet

| Konu | Durum |
|---|---|
| Profil, XP ve seviye | ✓ |
| Günlük görevler (3 adet, yerel güne göre) | ✓ |
| Başarımlar (9 adet, veri odaklı) | ✓ |
| Oyun olayları katmanı | ✓ |
| Kayıt sürüm 2 + 1.0.0'dan geçiş | ✓ |
| Yeni ekranlar (profil, görevler, başarımlar, oyun sonu özeti) | ✓ |
| `flutter analyze` | Temiz |
| `flutter test` | **136/136** (98 eski + 38 yeni) |
| iOS derlemesi / TestFlight | Yapılmadı (onayın gerekiyor) |
| Gerçek cihaz testi | Yapılmadı |

Temel arcade döngüsü değişmedi. XP fiziği, hızı ya da geçitleri etkilemiyor. Uçuş sırasında açılır pencere yok; ilerleme yalnızca uçuş bitince hesaplanıyor.

## 1. İncelenen mevcut kod

| Dosya | Bulgu | Phase 2.1'de |
|---|---|---|
| `lib/game/istanbul_flight_game.dart` | Sabit adımlı simülasyon. Sayaçlar `ValueNotifier`: `score`, `runSimits`, `nearMisses`, `zoneIndex`. `_crash()` içinde `progress.addRun(simits)` vardı ve simitsiz uçuşları hiç kaydetmiyordu | 7 küçük ek: olay çağrıları, uçuş kimliği, uçuş süresi, geçilen engel sayacı. `addRun` çağrısı tek bir `RunFinished` olayıyla değiştirildi |
| `lib/game/game_services.dart` | `ProgressController` (`ValueNotifier<PlayerProgress>`), servis paketi | Controller genişletildi: olay dinleyici, idempotent hesap, sıralı kayıt, `lastRun` özeti. `GameServices.emit` eklendi |
| `lib/services/progress.dart` | `PlayerProgress` v1 (`progress_v1`): toplam simit, en iyi tur simidi, kozmetik yer tutucular. Bozuk kayıtta sıfırdan başlıyordu | Aynı sınıf v2'ye genişletildi; v1 alanları ve `addRun` korundu |
| `lib/data/score_repository.dart` | Rekor `best_score_v1` (int) | **Değişmedi.** Profildeki en yüksek skor buradan okunuyor, tekrar saklanmıyor |
| `lib/services/settings.dart` | `settings_v1` | Değişmedi |
| `lib/game/day_cycle.dart` | 5 bölge, `zoneIndexForScore` | Okunuyor: keşif, görev başlıkları, geçiş |
| `lib/game/config.dart` | Fizik ve oyun ayarları | Değişmedi. XP ayarları ayrı dosyada |
| `lib/ui/overlays/*` | Overlay + modal sistemi (`openModal`), pixel bileşenler | `_ModalCard` → `ModalCard` (public). Menüye ilerleme şeridi, kartpostal altına özet paneli |
| `lib/main.dart` | Servis kurulumu, overlay haritası | 3 yeni overlay, açılışta `refreshDay()` |
| `test/` | 98 test, sahte servisler (`fakes.dart`) | Hepsi değişmeden geçiyor. +38 test |
| `codemagic.yaml`, iOS yapılandırması | — | Değişmedi |

## 2. Yeniden kullanılan servisler

- **`ProgressController` / `ProgressRepository`:** yeni bir cüzdan ya da ilerleme servisi açılmadı. Mevcut sınıf genişletildi.
- **`ScoreRepository`:** profilin "en yüksek skor" alanı için.
- **`GameServices` bağımlılık paketi:** yeni servis yok, yalnızca `emit` ve `listeners` eklendi.
- **Arayüz:**
  - Overlay ve modal sistemi (`openModal`, `closeModal`, geri tuşu).
  - `ModalCard`, `MartiButton`, `Pressable` (düğme sesi ve titreşim).
  - `pixelBox`, `PixelIcon` atlası (yıldız, gün batımı, uçuş ikonları), `SimitIcon`, MartiPixel fontu.
- **Görsel:** **Yeni görsel eklenmedi.** Rozetler ve ikonlar mevcut pixel atlasından; geçici ya da düşük kaliteli çizim yok.

## 3. Veri modeli (`PlayerProgress` v2)

Tek JSON, tek anahtar: `progress_v2`.

| Alan | Anlam | Kaynak |
|---|---|---|
| `totalSimits`, `bestRunSimits`, `unlockedCosmetics`, `selectedCosmetic` | v1 alanları (aynen) | v1'den taşınır |
| `xp` | Toplam XP. Seviye bundan **türetilir**, saklanmaz | yeni |
| `flights`, `totalScore`, `totalObstacles`, `totalNearMisses` | Uçuş istatistikleri | yeni (1.0.0'da tutulmuyordu, 0'dan başlar) |
| `bonusSimits` | Görev ve başarım ödülü simitler | yeni |
| `spentSimits` | Harcanan simit (Phase 2.2 için, şu an 0) | yeni |
| `discoveredZones` | Ulaşılan bölgeler (0–4) | yeni; geçişte rekordan türetilir |
| `longestFlightMs` | En uzun uçuş (simülasyon süresi, duraklatma hariç) | yeni |
| `missionsCompleted` | Tamamlanan görev sayısı | yeni |
| `daily` | Bugünün görevleri ve ilerlemesi | yeni |
| `rewardedMissions` | Ödül defteri `"gün:görev"` (son 60) | yeni |
| `achievements` | `id → açılma zamanı (UTC ISO)` | yeni |
| `settledRuns` | Hesabı yapılmış son 50 uçuş kimliği | yeni |

**Türetilen değerler (saklanmaz):**
- seviye, seviye içi XP, kalan XP: `xp`'den
- simit bakiyesi = `max(0, totalSimits + bonusSimits − spentSimits)`
- en ileri bölge: `discoveredZones`'tan
- en yüksek skor: `best_score_v1`'den

## 4. Oyun olayları

Dosya: `lib/progression/game_events.dart`

- **Olaylar:** `RunStarted(runId)`, `ObstaclePassed(score)`, `SimitCollected(runTotal)`, `NearMissAchieved(runTotal)`, `ZoneReached(zoneIndex)`, `RunFinished(RunResult)`.
- **İletim:** Olay veriyolu ya da yeni kütüphane yok. Oyun `services.emit(e)` çağırıyor; `GameServices` olayı `ProgressController`'a ve `listeners` listesindeki ek dinleyicilere sırayla iletiyor. Bir dinleyicideki hata yakalanıyor, oyun durmuyor.
- **Hesap verisi:** Uçuşun hesabı `RunFinished` içindeki `RunResult` ile yapılıyor (skor, geçilen engel, simit, kıl payı, en ileri bölge, süre). Bu değerler oyunun ekranda gösterdiği sayaçlarla aynı kaynaktan geliyor.
- **Diğer olaylar:** Uçuş sırasındaki olaylar şimdilik ilerlemeyi değiştirmiyor (oyun akışı bölünmesin diye). Ama aynı katmandan dinlenebiliyorlar; testler olay sırasını doğruluyor.
- **Demo modu:** `debugStartScore` atlaması `RunStarted`'dan önce yapılıyor; atlanan puanlar XP vermiyor (XP geçilen engelden hesaplanıyor).

## 5. XP ve seviye

Değerler `lib/progression/progression_config.dart` dosyasında.

| Kaynak | XP |
|---|---|
| Geçilen engel | 2 |
| Toplanan simit | 3 |
| Kıl payı | 5 |
| Yeni bölge (ilk keşif; Haliç başlangıç olduğu için sayılmaz) | 25 |
| Günlük görev | Kademeye göre 30 / 50 / 75 (+5 / 10 / 15 simit) |
| Başarım | 10–150 (+5–50 simit) |

- **Seviye eğrisi:** `n → n+1` için `40 + 20n` XP: 60, 80, 100, … Toplamda 3. seviye 140 XP, 10. seviye 1260 XP. En üst seviye 50; fazla XP birikmeye devam ediyor, çubuk dolu görünüyor.
- **Örnek uçuş:** 10 puan, 4 simit, 2 kıl payı ≈ 42 XP. Yeni oyuncu 1–2 uçuşta 2. seviyeye çıkıyor.
- **Sınırlar:**
  - Tek uçuş XP'si en fazla 2000 (görev ve başarım hariç).
  - Toplam XP en fazla 100 milyon (taşma koruması).
  - Negatif ya da bozuk uçuş değerleri 0'a düşüyor.
- **Gösterim:** XP uçuş bitiminde, kartpostalın altındaki tek panelde gösteriliyor.

## 6. Günlük görevler

Dosya: `lib/progression/missions.dart`

- **Türler ve hedefler (kolay / orta / zor):**
  - simit topla 5 / 12 / 25
  - kıl payı 2 / 5 / 10
  - uçuş tamamla 3 / 5 / 8
  - tek uçuşta puan 10 / 25 / 45
  - bölgeye ulaş Galata / Kız Kulesi / Boğaz Köprüsü
  - toplam puan 30 / 100 / 200
- **Seçim:** Günde 3 farklı tür. Seçim, gün anahtarından türetilen sabit bir tohumla yapılıyor; uygulamayı yeniden açmak görevleri değiştirmiyor.
- **Kademe:** Seviye 1–2 kolay (yeni oyuncu, bölge görevi yok), 3–7 orta, 8+ zor. Kademe, görev üretildiği anda sabitleniyor; gün içinde seviye atlamak hedefleri değiştirmiyor.
- **İlerleme:** Uçuş sonunda kendiliğinden. Ödül, görev tamamlanır tamamlanmaz otomatik veriliyor; ayrıca "al" düğmesi yok, yani ekstra dokunma ya da açılır pencere yok.
- **Yenilenme:** Yerel takvim günü (`yyyy-aa-gg`), açılışta ve görev ekranında kontrol ediliyor. Görev ekranı kalan süreyi gösteriyor.
- **Saat dilimi ve cihaz tarihi:** Gün anahtarı değişirse o günün görevleri üretiliyor. Aynı ödül iki kez verilmiyor: ödül defteri `"gün:görev"` kaydı tutuyor, cihaz tarihi geri alınıp aynı güne dönülse bile ödül tekrarlanmıyor (test var).
- **Zorunlu giriş baskısı yok:** Seri (streak) yok, kaçırılan gün cezası yok.

## 7. Başarımlar

Dosya: `lib/progression/achievements.dart`. Her başarımda kimlik, başlık, açıklama, ölçüt ve hedef var; ilerleme ve kilit durumu bunlardan türetiliyor; kazanılma tarihi ve ödül de tutuluyor.

| Kimlik | Başlık | Koşul | Ödül |
|---|---|---|---|
| `first_flap` | İlk Kanat Çırpışı | 1 uçuş | 10 XP, 5 simit |
| `galata_explorer` | Galata Kaşifi | Galata'ya ulaş | 25 XP, 10 simit |
| `simit_hunter` | Simit Avcısı | Toplam 100 simit | 50 XP, 20 simit |
| `loyal_gull` | Sadık Martı | 25 uçuş | 40 XP, 15 simit |
| `bosphorus_traveler` | Boğaz Yolcusu | Boğaz Köprüsü'ne ulaş | 50 XP, 20 simit |
| `near_miss_master` | Kıl Payı Ustası | Toplam 50 kıl payı | 60 XP, 25 simit |
| `daily_wanderer` | Günlük Gezgin | 10 günlük görev | 50 XP, 20 simit |
| `night_flight` | Gece Uçuşu | Rumeli Hisarı'na (gece) ulaş | 75 XP, 30 simit |
| `istanbul_conqueror` | İstanbul Fatihi | Tüm uçuşlarda toplam **1453** puan | 150 XP, 50 simit |

- **Kademeli açılma:** Liste kolaydan zora sıralı; ilki ilk uçuşta açılıyor.
- **Tek seferlik ödül:** Kayıtta `achievements` anahtarı varsa başarım bir daha açılmıyor (test var).
- **Yeni başarım eklemek:** listeye bir satır eklemek yeterli.

## 8. Yeni ekranlar

Ekran görüntüleri `docs/screenshots/phase2_1/`: web derlemesi, 393×852 @3x (iPhone 15/16 boyutu). **Gerçek cihaz değil.**

| Ekran | İçerik |
|---|---|
| Ana menü (`menu.png`, `small_menu.png`) | Rekor ve bakiye rozetinin altında üç düğmelik şerit: **SV n + XP çubuğu** (profil), **Görev x/3**, **★ x/9**. 320 pt genişlikte kısa etiketlerle tek satır. Dokunma hedefleri ≥ 44 pt |
| Profil (`profile.png`) | Seviye rozeti, XP çubuğu ve kalan XP, simit bakiyesi, 8 istatistik, bölge izi (keşfedilmeyenler "???"), Başarımlar düğmesi |
| Günlük görevler (`missions.png`) | 3 görev: ilerleme çubuğu, x/y, ödül, tamamlanma (yıldız + "TAMAM"). Yeni görevlere kalan süre |
| Başarımlar (`achievements.png`) | x/9 sayaç. Açık rozetler hardal zeminde yıldız + kazanılma tarihi. Kilitliler soluk, ilerleme yüzdesi ve x/y |
| Oyun sonu (`gameover.png`) | Kartpostalın **altında, paylaşılan görselin dışında** tek panel: +XP, seviye (atladıysa "Seviye 2 → 3!"), kazanılan simit, XP çubuğu, varsa yeni bölge / tamamlanan görev / açılan başarım satırları. Kartpostal kompozisyonu aynı (test: paylaşılan `Postcard` içinde özet yok) |

- **Safe Area:** Bütün yeni ekranlar mevcut `ModalCard` (SafeArea) içinde.
- **Taşma testleri:** 320×568, 375×667 ve 430×932'de büyük değerlerle (seviye 50, 999999 skor) taşma yok. Mevcut 320/360/390/412/768/1024 testleri de geçiyor.

## 9. Kayıt ve geçiş stratejisi

**Açılış akışı:** `progress_v2` okunuyor.
1. Okunabiliyorsa onu kullan.
2. Bozuksa ham metni `progress_v2_corrupt` anahtarına yedekle ve 3. adıma geç.
3. `progress_v1` + `best_score_v1` → `migrateFromV1` → `progress_v2`'ye yaz.

**Geçişte (1.0.0 → 1.1.0):**
- Simitler, en iyi tur simidi ve kozmetik alanları aynen taşınıyor.
- Rekordan ulaşılmış bölgeler türetiliyor (ör. rekor 40 → Haliç, Galata, Kız Kulesi). İlk keşif XP'si veriliyor (2 bölge = 50 XP); TestFlight oyuncuları gördükleri bölgeler için geride kalmıyor.
- Uçuş sayısı ve toplam skor 1.0.0'da tutulmadığı için 0'dan başlıyor (bilinçli; uydurma değer yazılmıyor).
- Uçuş ve skor eşiğine bağlı başarımlar ilk yeni uçuşta, ulaşılan bölgeye bağlı olanlar (ör. Galata Kaşifi) hemen o uçuşun hesabında açılıyor.

**Silinmeyen ve değişmeyen anahtarlar:** `progress_v1`, `best_score_v1`, `settings_v1`. Eski sürüme dönülürse 1.0.0 kendi `progress_v1` kaydını okumaya devam eder.

**Güvenilirlik:**

| Durum | Önlem | Test |
|---|---|---|
| Aynı uçuşun iki kez kaydı | `runId` + `settledRuns`; ikinci hesap null ve kayıt yazılmıyor. Oyun bir uçuşta tek `RunFinished` gönderiyor (eski `_crash` içindeki kayıt artık tek nokta) | ✓ (saf, controller, oyun) |
| Kayıt sırasında kapanma | Tek anahtar, tek `setString` (tam JSON): ya eski ya yeni kayıt kalıyor. Kayıtlar sırayla yazılıyor; eski bir yazma yenisinin üstüne geçmiyor | ✓ (yazma hatası sonrası sonraki kayıt güncel durumu yazıyor) |
| Hatalı JSON / eksik alan | Alan alan okunuyor; bozuk alan varsayılana düşüyor, diğerleri korunuyor. Tanınmayan görev atlanıyor. Bozuk v2 yedekleniyor, v1'den kurtarılıyor | ✓ |
| Eski sürüm verisi | Geçiş + v1 dokunulmadan kalıyor | ✓ |
| Negatif simit bakiyesi | Bakiye türetilip 0'da sınırlanıyor; `trySpend` yetersizde reddediyor | ✓ |
| Aynı görevin tekrar ödülü | Ödül defteri `gün:görev` | ✓ (tarih geri alma dahil) |
| Aynı başarımın tekrar ödülü | `achievements` anahtarı | ✓ |

## 10. Test sonuçları (22 Ekim 2026, Windows, Flutter 3.47.7)

- `flutter analyze`: **No issues found**
- `flutter test`: **136/136**
  - `test/progression_test.dart`, 30 test:
    - seviye sınırları ve taşma
    - XP dağılımı, demo skoru, uçuş üst sınırı, negatif değerler
    - XP'nin fiziği etkilememesi
    - istatistikler ve bölge keşfi
    - idempotent hesap (saf, controller, gerçek oyun döngüsünde olay sırası)
    - görev üretimi, kademe, ilerleme türleri, tek seferlik ödül ve tarih geri alma, gün anahtarı, `refreshDay`
    - başarım açılışı, tek ödül, kademe
    - bakiye
    - v1→v2 geçişi, yeni kurulum, bozuk v2 kurtarma, bozuk alanlar, bozuk görev, JSON gidiş-dönüş
    - yazma hatası
  - `test/progression_ui_test.dart`, 8 test:
    - menü şeridi ve bakiye
    - profil (seviye, XP, istatistik, başarımlara geçiş)
    - görevler (3 görev, yenilenme süresi, geri tuşu)
    - başarımlar (açık / kilitli, tarih)
    - oyun sonu özeti (kartpostal dışında; yeni uçuşta gizlenir)
    - 3 iPhone boyutunda taşma
  - Eski 98 testin hepsi değişmeden geçiyor.
- **Web release derlemesi** alındı; yeni ekranlar headless Edge'de 393×852 @3x ve 320×568'de görsel olarak kontrol edildi.
- **Yapılmayanlar:**
  - iOS derlemesi (Codemagic) çalıştırılmadı.
  - Gerçek iPhone'da test edilmedi.
  - FPS ölçülmedi.

## 11. Bilinen riskler

1. **Cihaz tarihini ileri almak** yeni günün görevlerini açar. Çevrimdışı oyunda sunucu saati olmadan bu tamamen engellenemez. Etki sınırlı: ödüller küçük, reklam ya da satın alma yok.
2. **1.0.0 istatistikleri eksik:** uçuş sayısı ve toplam skor 1.0.0'da kaydedilmiyordu, 0'dan başlıyor. Simit, rekor ve bölgeler korunuyor.
3. **Yarıda bırakılan uçuş** (duraklat → ana menü / yeniden başlat) eskiden olduğu gibi sayılmıyor; topladığı simitler de eklenmiyor. 1.0.0 davranışı korundu. Sayılması istenirse tek satırlık değişiklik (Phase 2.2'de karar).
4. **Ödül ekonomisi:** Bonus simitler bakiyeye ekleniyor ama harcanacak yer henüz yok. Mağaza fiyatları Phase 2.2'de bu akışa göre ayarlanmalı.
5. **Rozet görselleri:** mevcut yıldız ikonu. Başarıma özel pixel rozetler istenirse ayrı bir görsel iş.
6. **Kayıt boyutu:** Defter (60) ve uçuş listesi (50) sınırlı; kayıt birkaç KB'ı geçmez.
7. **Gerçek cihazda doğrulanmadı:** iOS'ta `shared_preferences` (NSUserDefaults) yazma davranışı ve yeni ekranların Dynamic Island / Safe Area görünümü TestFlight 1.1.0 ile doğrulanmalı (plan: [testflight/beta_1_1_0.md](testflight/beta_1_1_0.md)).

## 12. Phase 2.2 teknik önerisi: simit mağazası ve kozmetik özelleştirme

Bu görevde mağaza kodu yok. Hazır olan zemin:
- `PlayerProgress.simitBalance`, `trySpend` (negatife düşmez, testli)
- `spentSimits`, `unlockedCosmetics`, `selectedCosmetic`

**Öneri:**

1. **Katalog (veri odaklı):** `lib/progression/cosmetics.dart` dosyasında `CosmeticDef(id, ad, tür: şapka/atkı/iz efekti, fiyat, açılma koşulu: simit | başarım | seviye)`. Başarım ödülü olarak açılan kozmetikler mağaza dışı kalır.
2. **Satın alma:** `ProgressController.purchase(id)`, tek bir saf fonksiyonla:
   - bakiye ve sahiplik kontrolü
   - `trySpend` + `unlockedCosmetics.add`
   - tek kayıtta atomik
   - idempotent: zaten sahipse no-op
3. **Kayıt:** Şema v3 gerekmez; mevcut alanlar yeterli. Yeni alan gerekirse `fromJson` toleransı aynı şekilde.
4. **Görsel:** Kozmetikler Simit sprite sayfasına katman olarak (`SimitAnimator` kareleriyle hizalı ayrı sheet). `SimitBird` ve kartpostal (`SimitFrameView`) aynı katmanı çizer; kartpostal paylaşımında da görünür. Çizimler mevcut pixel art kalitesinde, gerçek kaynaklı üretilmeli.
5. **Arayüz:** Menüdeki şeride dördüncü düğme yerine profil ekranından "Görünüm" sekmesi (320 pt sınırı). Önizleme Simit'in menüdeki süzülme animasyonunda.
6. **Ekonomi dengesi:** Ortalama uçuş 3–5 simit, günlük görevler 15–45 simit. İlk kozmetik ~150 simit (2–3 gün normal oyun). Pay-to-win yok: kozmetiklerin hitbox ya da fiziğe etkisi yok (test ile kilitlenmeli).
7. **Testler:** yetersiz bakiye, çift satın alma, sahip olunmayan kozmetiği seçme (zaten `fromJson`'da korunuyor), geçişte sahipliklerin korunması.

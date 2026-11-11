# 22 · Phase 2.9: Performans, pil ve kararlılık

> **Dosya adı:** İstekte `docs/21_phase2_9_performance_optimization.md` geçiyordu; 21 numara Phase 2.8'de kullanıldığı için 22.
> **Dal:** `feature/phase2-9-performance`, `main` (`76aa7a7`, Phase 2.8 + 1.7.0 dahil) üzerine.
> **Sürüm:** pubspec değişmedi (1.7.0+10). **Öneri: 1.8.0.**
> **Yapılmayanlar:** TestFlight, App Review ve yayın yapılmadı. Gerçek iPhone ölçümü **yapılmadı** (§13).
> **Ölçüm ortamı:** Bütün sayılar Windows masaüstünde, `flutter test` ortamında (debug, JIT) alındı. Gerçek iPhone FPS'i, GPU süresi, pil ve ısınma bu ortamda ölçülemez. Ham çıktılar: [perf/phase2_9/](perf/phase2_9/).

## 1. İncelenen durum

| Konu | Durum |
|---|---|
| Commit | `76aa7a7` (`main`; Phase 2.8 ve 1.7.0 TestFlight belgeleri) |
| Flutter / Flame | 3.47.7 / 1.38.2 |
| iOS hedefi | 15.0 |
| Önceki fazlar | Hepsi depoda ve `main`'de: bölgeler ve parallax, dinamik engeller, hava, ilerleme ve mağaza, keşif albümü, Game Center, Günün Uçuşu, haftalık etkinlikler ve sezon, eğitim |
| Var olan ölçüm | `MARTI_STATS` (FPS, bileşen, engel, efekt). `tool/perf_bench_test.dart`: kare başına güncelleme ve çizim kaydı süresi. `tool/hud_rebuild_bench_test.dart`: HUD yeniden kurulumu |
| CI | Codemagic. `verify` push ve PR'da çalışır; `ios-testflight` elle başlatılır. Değiştirilmedi |

**Oyun döngüsü, değişiklik öncesi:**
- **Fizik:** Sabit adımlı (1/120 s), birikimli.
- **Duraklatma:** Flame motorunu durdurur.
- **Arka plan:** Uçuş sırasında arka plana alınınca oyun duraklar. Menüdeyken Flame kendi motorunu durdurur, dönüşte sürdürür.
- **Nesne havuzları:** Efekt parçacıkları (24) ve simgeler zaten havuzdan.
- **Ses:** Efektler `AudioPool` ile, ses başına sınırlı sayıda oynatıcıyla çalınıyor.
- **Kayıt:** Uçuş sırasında diske yazılmıyor; uçuş sonunda tek, sıralı bir kayıt yapılıyor.

## 2. Ölçüm araçları (yeni)

| Araç | Ölçtüğü |
|---|---|
| `tool/render_load_bench_test.dart` | Gerçek görsellerle, 1170×2532 ekranda kare başına çizim çağrısı, overdraw (boyanan alan / ekran) ve bileşen bazında döküm. Aynı sahneyi eski ve yeni yoldan yan yana ölçer |
| `tool/leak_bench_test.dart` | `flutter test --enable-vmservice` ile tam uygulamada 110 uçuş (klasik, Günün Uçuşu, etkinlik). Her 5 uçuşta 10 ekran açılıp kapanır. Çöp toplama sonrası sınıf bazında canlı nesne sayısı ve heap |
| `tool/idle_probe_test.dart` | Her durumda Flame motorunun çalışıp çalışmadığı ve Flutter'ın yeni kare isteyip istemediği |
| `tool/startup_bench_test.dart` | Oyunun yüklenmesi (109 görsel) ve ilk kare |
| `tool/perf_bench_test.dart` (genişletildi) | Kare başına güncelleme ve çizim kaydı süresi; eski ve yeni yol dönüşümlü |
| `MARTI_STATS` (genişletildi) | Yarım saniyelik pencerede FPS'e ek olarak **en uzun kare** (ms): telefonda takılmayı görmek için |

## 3. Darboğazlar (ölçüme göre)

| Öncelik | Bulgu | Ölçüm |
|---|---|---|
| **1 (pil)** | Oyun dışında kimse bakmıyorken sahne hiç durmuyor: menü, modal ekranlar, "uçmak için dokun" ve oyun sonu sürekli saniyede 60–120 kare çiziliyor | §6: 60 sn dokunulmayan menüde ve 30 sn bekleyen oyun sonunda motor çalışıyor, kare isteniyor |
| **2 (çizim)** | Aynı renkteki küçük dikdörtgenler (rüzgâr, sis) ve aynı görselden gelen parçalar tek tek çiziliyor | §4: rüzgârda 146, siste 171 çağrı/kare. WeatherLayer tek başına 60–69, engeller 29, yansıma bantları 18–26 |
| 3 (disk) | Her uçuş sonunda ana kayıt ve 3 yedek yazılıyor; yedekler çoğu uçuşta değişmiyor | §8: 4 yazma / uçuş |
| — (bellek) | 110 uçuşta Flame tarafında birikme yok. Tek gerçek birikme Flutter'ın `Slider`'ında (Ayarlar), boyutu ihmal edilebilir | §5 |
| — (CPU) | Güncelleme ve çizim kaydı masaüstünde kare başına 0,1–0,2 ms; CPU tarafı darboğaz değil | §4 |

## 4. Flame çizim yükü

**Yapılan:** Görüntüyü değiştirmeden çağrıları birleştirmek (`lib/game/visual/atlas_batch.dart`).
- **Engel parçaları ve simge su yansıması (yazıldı, varsayılan kapalı):** Atlas görselinden tek `drawRawAtlas` çağrısıyla çizme hazır (`AtlasBatch`), ama `RenderTuning.batchAtlas = false`.
  - Windows test çizicisinde eski yolla birebir aynıydı.
  - Codemagic'in Mac çizicisinde engel bulunan sahnelerde 292–892 piksel fark verdi (Codemagic #13, 1.8.0'ın ilk derlemesi; testlerde durdu, hiçbir şey yüklenmedi).
  - iPhone da Metal kullandığı için görüntü değişmesin diye engeller ve yansımalar eski yoldan çiziliyor.
- **Rüzgâr:** Yapraklar renk başına iki yolda (gövde ve uç), rüzgâr çizgileri tek yolda.
- **Sisli hava:** Bant başına iki yol (gövde ve kenar). Parçalar birbirine değmiyor; görüntü aynı.
- **Tamponlar:** Yeniden kullanılıyor, kare başına yeni liste oluşmuyor.

**Kalıcı test:** `test/render_batching_test.dart`, 12 sahneyi gerçek görsellerle eski ve yeni yoldan resme döküp karşılaştırır.
- **Sahneler:** 9 bölge, açık / rüzgârlı / sisli / yağmurlu hava, menü ve oyun sonu.
- **Sonuç:** Hepsinde **0 piksel fark**. Test hem yerelde hem Codemagic'teki Mac derlemesinde çalışıyor; atlas birleştirmesinin kapatılması bu testin Mac sonucuna dayanıyor.

**Bilerek birleştirilmeyenler:**
- **Haliç sabah sisi ve sudaki güneş/ay sütunu:** Bu ikisi kenar yumuşatmalı (anti-alias) boyanıyor. Tek yolda birleştirilince kenar piksellerinde 1–11/255 fark çıktı (Galata, Köprü, Rumeli). Pixel art aynı kalsın diye eski yoldan çiziliyorlar.

**Kare başına çizim çağrısı ve overdraw** (`render_load_final.txt`; atlas kapalı, yalnızca yol birleştirmesi):

| Sahne | Çağrı önce | Çağrı sonra | Overdraw (değişmedi) |
|---|---|---|---|
| Menü | 38 | 38 | 2,4× |
| Haliç, açık | 63 | 63 | 2,7× |
| Ortaköy, açık + tehlike | 86 | 86 | 3,5× |
| Ortaköy, rüzgârlı | 146 | **102** | 3,5× |
| Üsküdar, yağmur | 88 | 88 | 4,3× |
| Rumeli, sis | 171 | **119** | 3,7–3,9× |
| Oyun sonu | 52 | 52 | 2,6× |

- **Atlas açık olsaydı:** `render_load.txt` (Haliç 45, Ortaköy 43, rüzgâr 59, yağmur 47, sis 84, oyun sonu 43) ve aşağıdaki CPU tablosu atlas birleştirmesi açıkken ölçüldü. Bugünkü kazanç yalnızca rüzgâr ve sis satırlarında geçerli.

- **Overdraw:** Boyanan alan değişmedi; aynı pikseller daha az çağrıyla çiziliyor. Birleşik yolların gerçek boyanan alanı sayaçta görünmediği için yollar alana katılmadı. Bu yüzden sisteki küçük fark ölçüm kaynaklı.
- **Kalan overdraw:** 2,4–4,3× değeri gökyüzü, uzak plan, kıyı ve su katmanlarının tam ekran üst üste binmesinden geliyor. Azaltmak katmanların opak bölgelerini bilmeyi gerektiriyor; görüntü riskine karşılık ölçülmüş bir kazanç olmadığı için yapılmadı.

**CPU: kare başına çizim kaydı** (`frame_cpu.txt`; 1170×2532, 1800 kare, ortalama ms). Aynı koşuda dönüşümlü, iki tur:

| Sahne | Tur 1 önce → sonra | Tur 2 önce → sonra |
|---|---|---|
| Haliç | 0,073 → 0,061 | 0,104 → 0,078 |
| Ortaköy + tehlike | 0,104 → 0,070 | 0,142 → 0,103 |
| Ortaköy rüzgârlı | 0,138 → 0,097 | 0,195 → 0,143 |
| Üsküdar yağmur | 0,138 → 0,113 | 0,192 → 0,161 |
| Rumeli sis | 0,139 → 0,107 | 0,196 → 0,163 |

- **Sonuç:** Her koşuda %15–30 daha az. Mutlak süreler koşudan koşuya değişiyor; karşılaştırma aynı koşu içinde yapıldı.
- **Güncelleme süresi:** Değişmedi (0,01 ms).
- **Asıl kazanç:** GPU tarafında, çağrı sayısında. Bunu ancak gerçek cihaz ölçebilir (§13).

## 5. Bellek ve uzun seans

**110 uçuş** (`leak_bench_before.txt`, `leak_bench_after.txt`; klasik + Günün Uçuşu antrenmanı + etkinlik; her 5 uçuşta 10 ekran aç/kapa):

| Uçuş | Heap önce | Heap sonra | Dünya bileşeni | Engel / tehlike / efekt (uçuş arası) | Kayıt |
|---|---|---|---|---|---|
| 10 | 156,1 MB | 160,1 MB | 14 | 0 / 0 / 0 | 1,7 KB |
| 60 | 160,7 MB | 163,0 MB | 14 | 0 / 0 / 0 | 2,8 KB |
| 110 | 163,7 MB | 163,8 MB | 14 | 0 / 0 / 0 | 2,9 KB |

- **Flame:** Bileşen, engel, tehlike görünümü ve parçacık birikmiyor. Oyun olayı dinleyici sayısı sabit.
- **Kayıt boyutu:** Günlük ve etkinlik kayıtlarıyla yavaşça büyüyor, 2,9 KB'ta yatay; sınırsız liste yok.
- **İki aralıkta da büyüyen sınıflar:**
  - **VM sınıfları** (`Code`, `ICData`, `Instructions` vb.): Debug modda yeni kod yollarının derlenmesi. Artış hızı azalıyor.
  - **`_Uint8List`:** Aynı ekran 125 kez açıldı; 25 açılışlık artışlar giderek küçüldü (+4400, +3000, +1400, +1200, +800). Heap 146–154 MB'ta yatay. Önbellek ısınması, sızıntı değil.
  - **`_OverlayEntryLocation` +2, `_Mint` +2:** Yalnızca **Ayarlar** ekranı her açılışta bırakıyor. Kaynak Material `Slider`'ın her zaman kurduğu `OverlayPortal` (Flutter çerçevesi). `_StackTrace` artışı aynı kodun yalnızca debug'da çalışan `assert` bloğundan. Ayarlar 1000 kez açılsa ~100 KB; düzeltilmedi.
- **Uzun uçuş (test):** 10.000 kare ve 20 dakikalık (72.000 kare) kesintisiz uçuşta sınırlar korunuyor (`test/perf_regression_test.dart`):
  - dünya bileşeni ≤ 30
  - engel ≤ 6
  - tehlike ≤ 3
  - efekt ≤ 24

## 6. Pil: boşta uyku

**Yapılan** (`IstanbulFlightGame`: `sceneAsleep`, `deepIdle`, `noteActivity`):
- **Modal ekran açıkken:** Mağaza, profil, albüm, sıralama, etkinlikler, görevler, başarımlar, ayarlar, nasıl oynanır. Arkadaki sahne donar (Flame motoru durur). Ekranın kendi animasyonları (mağazadaki martı önizlemesi) sürer.
- **Oyun sonu yerleşince:** Kuş suya düşmüş, kart görünmüş, "Tekrar uç" açık, efektler bitmiş, sarsıntı bitmişse sahne donar.
- **30 saniye dokunulmazsa:** Oyun dışındaki her durumda (menü, "uçmak için dokun", oyun sonu, modal) sahne donar. Ayrıca `TickerMode` kapanır ve arayüzdeki tekrarlı animasyonlar (logo, "dokun" ipucu) durur.
- **Uyanma:** Kök `Listener`'daki ilk dokunuş her şeyi sürdürür; o dokunuş normal işini de yapar (ör. "Uçuşa başla").
- **Uçuş (PLAYING) hiç etkilenmez.** Fizik, parkurlar, kare hızı limiti yok.
- **Arka plan:** Uykudayken arka plana alınıp dönülürse uykuda kalır; dokununca uyanır. Uçarken arka plana alınırsa eskisi gibi duraklar ve "Devam" bekler.

**Ölçüm** (`idle_before.txt` → `idle_after.txt`):

| Durum | Önce: motor / kare isteği | Sonra: motor / kare isteği |
|---|---|---|
| Menü, 60 sn dokunulmadan | çalışıyor / var | **durdu / yok** |
| Modal ekran açık | çalışıyor / var | **durdu** / var* |
| "Uçmak için dokun", 35 sn | çalışıyor / var | **durdu / yok** |
| Oyun sonu (kart yerleşti) | çalışıyor / var | **durdu / yok** |
| Oyun sonu, 30 sn | çalışıyor / var | **durdu / yok** |
| Duraklatma | durdu / yok | durdu / yok |

\* Modal açıkken arkadaki menü logosunun animasyonu ve modalın kendi animasyonları sürer. Bunlar yalnızca hafif arayüz kareleri; sahne yeniden çizilmez. 30 saniye dokunulmazsa onlar da durur.

**Pil yüzdesi iddiası yok.** Hangi durumda ne kadar işin ortadan kalktığı yukarıda ölçüldü; telefondaki pil ve ısınma karşılığı §13'teki planla ölçülmeli.

**Kalan:** Menüde ve uçuşta müzik çalmaya devam ediyor; bu, oyunun beklenen davranışı.

## 7. Açılış ve paket boyutu

**Açılış** (`startup.txt`, masaüstü):
- **Oyunun yüklenmesi:** 109 görselin çözülmesi ve dünya bileşenleri ilk soğuk açılışta 293 ms (debug JIT derlemesi dahil), tekrarlarda 11–15 ms.
- **İlk kare:** Soğuk 30 ms, sonra yaklaşık 1 ms.
- **Açılışı zaten bekletmeyenler:** Ses havuzları, Game Center, Günün Uçuşu ve etkinlik parkurlarının hazırlanması arka planda yapılıyor.
- **Görseller:** Hepsi açılışta yükleniyor (çözülmüş 13,9 MB). Uçuş sırasında doku yükleme takılması bu yüzden olmuyor.
- **Değişiklik yok:** Ölçülmüş bir sorun olmadan tembel yüklemeye geçmek, bölge geçişinde takılma riski getirirdi. Sahte açılış ekranı eklenmedi.

**Paket içeriği:**

| Klasör | Boyut | Not |
|---|---|---|
| `assets/images` | 611 KB (110 PNG) | Hepsi kodda kullanılıyor; silinebilecek görsel yok |
| `assets/audio` | 3,3 MB | Hepsi kullanılıyor. Sıkıştırılmamış WAV; menü müziği tek başına 1 MB |
| `assets/fonts` | 16 KB | |

- **IPA boyutu ölçülemedi:** Bu bilgisayarda iOS derlemesi yok ve App Store Connect oturumu kapalıydı. İndirme ve cihazda kaplanan boyut, App Store Connect → TestFlight → 1.7.0 (10) → Build Metadata → "App Store File Sizes" altında cihaz başına görülür.
- **Öneri (uygulanmadı):** Müzikleri AAC'ye çevirmek paketi yaklaşık 3 MB küçültür. Ancak bu kayıplı bir ses değişikliği ve onayın gerekiyor. Efektler, gecikme olmasın diye WAV kalmalı.

## 8. Disk

- **Yapılan:** Kayıt deposu (`SharedPrefsProgressRepository`) her anahtar için diske **başarıyla** yazdığı son değeri tutuyor; değişmeyen değeri yeniden yazmıyor. Sıradan bir uçuş sonu artık 4 yerine **1 yazma**: yalnızca ana kayıt; keşif, Günün Uçuşu ve etkinlik yedekleri değişmediyse yazılmıyor.
- **Veri güvenliği:**
  - Ana kayıt her uçuşta yazılmaya devam ediyor.
  - Bir yazma başarısız olursa son değer güncellenmiyor; bir sonraki kayıtta yeniden deneniyor.
  - Satın alma "önce diske, sonra ekrana" kuralıyla değişmeden çalışıyor.
  - Günlük hak, uçuş başlar başlamaz yazılmaya devam ediyor.
- **Testler:** `test/disk_writes_test.dart` (5):
  - ilk kayıtta 4 yazma
  - sıradan uçuş sonunda 1 yazma
  - albüm değişince 2 yazma
  - aynı kaydı ikinci kez yazmama
  - geri okuma
  - yeni süreçte diskteki değerle karşılaştırma

## 9. Ses ve Flutter arayüzü

- **Ses:** Efektler önceden yüklenen havuzlardan çalıyor ve her efektin aynı anda çalabilen ses sayısı sınırlı; üst üste binme sınırı zaten var. Arka plana geçişte ses duruyor, duraklatılmış oyunda ses "Devam"la geri geliyor. Değişiklik gerekmedi.
- **HUD:** Uçuşta kare başına 1'in altında widget yeniden kuruluyor (Phase 2.8 ölçümü; `hud_rebuild.txt`). Değişiklik gerekmedi.

## 10. Test sonuçları

| Komut | Sonuç |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` | **489 / 489** (28 yeni) |

**Yeni testler:**
- **`test/idle_sleep_test.dart` (7):**
  - modal ekranda uyku ve uyanma
  - oyun sonunda uyku ve "Tekrar uç"
  - 30 sn derin uyku ve ilk dokunuş
  - uçuşta asla uyumama
  - uykudayken arka plan
  - uçarken arka plan
  - uykunun Günün Uçuşu parkurunu değiştirmemesi
- **`test/render_batching_test.dart` (13):** 12 sahnede eski ve yeni yol arasında 0 piksel fark (yerelde ve Codemagic Mac derlemesinde çalışır).
- **`test/perf_regression_test.dart` (3):**
  - 10.000 kare uçuş
  - 20 dakika uçuş
  - **Kare hızından bağımsızlık:** Aynı Günün Uçuşu 30 / 60 / 120 Hz'de aynı engel dizisini ve aynı skoru veriyor.
- **`test/disk_writes_test.dart` (5).**

## 11. Regresyon değerlendirmesi

- **Değişmeyenler:**
  - fizik, engel açıklıkları, hitbox ve skor
  - XP, simit ekonomisi, satın alma, keşif
  - Game Center, Günün Uçuşu, kupa, sezon, eğitim, kartpostal
- **Dayanak:** Mevcut 461 testin hepsi değişmeden geçiyor.
- **Kare hızı:** Oyun kare hızına bağlı değil (yeni test).
- **Uyku ve parkur:** Uyku parkuru değiştirmiyor (yeni test).
- **Görüntü:** Çizim değişiklikleri piksel düzeyinde aynı (yeni test).
- **Oynanışı değiştiren optimizasyon:** Yok.

## 12. Bilinen sorunlar ve sınırlar

- **Gerçek cihaz:** FPS, kare süresi, GPU, pil, ısınma, bellek ve IPA boyutu gerçek iPhone'da ölçülmedi. Bu bilgisayarda Mac, Xcode ya da Instruments yok.
- **Overdraw:** 2,4–4,3× düzeyinde kaldı (§4).
- **Ayarlar ekranı:** Material `Slider` açılış başına iki küçük nesne bırakıyor (Flutter çerçevesi; §5).
- **Uyku sırasında görüntü:** Uykudayken sahne donuk görünür (bulutlar ve su durur). İlk dokunuşta sürer.

## 13. Gerçek cihaz test planı (hepsi NOT RUN)

**Ön koşul:**
- Ölçüm için TestFlight derlemesinde `--dart-define=MARTI_STATS=true` gerekir. Bu, FPS ve en uzun kare göstergesini açar; ayrı bir derleme ve senin onayın gerekir.
- Instruments ölçümleri (Time Profiler, Allocations, Energy Log) Mac ve Xcode ister.

| # | Senaryo | Ölçülecek |
|---|---|---|
| 1 | Aynı iPhone'da 1.7.0 ve 1.8.0 adayı, aynı sahneler (Ortaköy rüzgârlı, Rumeli sis) | FPS, en uzun kare |
| 2 | Menüde 5 dakika dokunmadan bekleme (1.7.0 ve yeni) | Ayarlar → Pil'de uygulamanın payı, cihazın ısınması |
| 3 | Mağazada ve kartpostalda 5 dakika bekleme | Aynı |
| 4 | 20 dakika kesintisiz oyun, düşük güç modu açık ve kapalı | FPS, ısınma, pil düşüşü |
| 5 | 60 Hz cihaz (ör. iPhone SE / 11) ve 120 Hz cihaz (Pro) | FPS, en uzun kare |
| 6 | 50 uçuş art arda, arada mağaza ve albüm | Akıcılık ve kapanma olmaması |
| 7 | Uçuş, menü ve modal ekranda arka plana alıp dönme | Doğru yerden devam, günlük hakkın tekrar verilmemesi |
| 8 | İnternetsiz oyun | Game Center kuyruğu, akıcılık |

## 14. TestFlight hazırlığı

- **Kod:** Derlemeye hazır. Analiz temiz, 489 test geçiyor.
- **Sürüm önerisi:** 1.8.0+11.
- **Yükleme:** Senin onayın olmadan yapılmayacak.
- **1.7.0'daki hesap sorunu:** Kurulum ve harici beta incelemesi sorunu (Apple talebi 103007198858) çözülmeden telefonda test edilemiyor.

# Phase 2.2: Simit Mağazası ve Martı Görünümleri

> Not: `13_rumeli_gercek_referans.md` ile aynı numara; dosya adı görevde istendiği gibi bırakıldı.
> Sürüm: **1.2.0 (3)**. TestFlight'a **yüklenmedi** (onay bekliyor). Beta notları: [testflight/beta_1_2_0.md](testflight/beta_1_2_0.md)

## Özet

| Konu | Durum |
|---|---|
| Kozmetik katalog (merkezi, veri odaklı) | ✓ 6 görünüm |
| Gerçek pixel art görünüm sheet'leri | ✓ 5 yeni sheet, klasik ile aynı anatomi, kare, pivot |
| Simit Mağazası | ✓ önizleme, onay, satın alındı damgası, yetersiz simit, seviye kilidi |
| Martı Görünümü ekranı | ✓ animasyonlu önizleme, sahip olunanlar, klasik görünüme dönüş |
| Oyun içi kullanım | ✓ uçuşta, menüde, kartpostalda |
| Satın alma güvenilirliği | ✓ tek işlem, yazma başarısızsa geri alınır, çift dokunma koruması |
| Kayıt | Yeni şema **gerekmedi** (`progress_v2` alanları yeterli) |
| `flutter analyze` | Temiz |
| `flutter test` | **166/166** (136 eski + 30 yeni) |
| TestFlight / gerçek iPhone | Yüklenmedi / test edilmedi |

Reklam, abonelik ya da uygulama içi ödeme yok. Simit yalnızca oyunda kazanılıyor. Görünümler yalnızca görsel.

## 1. Mevcut mimari analizi

| Bileşen | Bulgu | Phase 2.2'de |
|---|---|---|
| `PlayerProgress` (`progress_v2`) | `unlockedCosmetics` (en az `classic`), `selectedCosmetic` (sahip olunmayan → `classic`), `spentSimits` ve `trySpend` zaten var | Aynen kullanıldı; alan eklenmedi |
| Simit bakiyesi | `max(0, totalSimits + bonusSimits − spentSimits)`. Uçuş simitleri ve görev/başarım ödülleri birlikte harcanabilir | Tek bakiye; yeni cüzdan yok |
| `ProgressController` | Sıralı kayıt kuyruğu (`_saving`), idempotent uçuş hesabı | `purchase` (yazmadan sonra uygulanan işlem) ve `equip` eklendi |
| Karakter | `art/_source/pixel/characters.js`: 48×42 kare, 12 kare (kanat döngüsü, süzülme, yükselme, düşüş, çarpışma, göz kırpma, oyun sonu), pivot (22,22). `SimitBird` sheet'ten kare çiziyor; `SimitAnimator` kare seçimi saf mantık | Üretici görünüm parametresi aldı. `SimitBird`, `game.birdSheet`'i çiziyor; animatör değişmedi |
| Sprite yükleme | `GameArt.load` (Flame `Images` önbelleği; her görsel isteğe bağlı) | `skins` haritası ve `sheetFor(id)` (yoksa klasik) |
| `IstanbulFlightGame` / `GameServices` | Durum `ValueNotifier`'larla, servisler paket hâlinde | `cosmetic` notifier'ı ve `birdSheet` getter'ı; görünüm yalnızca READY'de ve yeni turda uygulanıyor |
| Overlay'ler | `ModalCard`, `MartiButton`, `Pressable`, `pixelBox`, `PixelIcon`, `SimitFrameView` | Yeniden kullanıldı. Menüdeki bakiye rozeti mağaza girişi oldu |
| iOS / Codemagic | Bundle ID `com.burakhamzali.istanbulFlight`, `ios-testflight` elle başlıyor, derleme numarası = TestFlight son + 1 | Değişmedi. App Store Connect'te son derleme 1.1.0 (2) → sıradaki **3** |

## 2. Kozmetik katalog modeli

Dosya: `lib/progression/cosmetics.dart`

- **`CosmeticDef`:**
  - `id`: kalıcı kimlik
  - `name`, `description`
  - `category`: Klasik / Kıyafet / Tüy
  - `sheetAsset`: sprite sheet yolu; `null` = klasik
  - `previewFrame`: kartlardaki sabit kare
  - `price`, `minLevel`: `ShopConfig`'ten okunuyor
- **`ShopConfig`:** fiyatlar ve seviye kilitleri tek bir haritada, kolayca ayarlanabilir.
- **Türetilen durumlar (saklanmıyor):**
  - Kart durumu `cosmeticStatus`: kullanılıyor / sende / kilitli / alınabilir / pahalı
  - `ownsCosmetic`
  - `effectiveCosmetic`: bilinmeyen ya da sahip olunmayan seçim → klasik
- **Yeni görünüm eklemek:** `characters.js` → `SKINS`'e bir girdi (palet ve aksesuar), `cosmeticCatalog`'a bir satır, `ShopConfig.prices`'a fiyat. `node art/_source/pixel/build_all.js assets/images/pixel_art` ile sheet üretiliyor.

| Kimlik | Ad | Kategori | Fiyat | Kilit |
|---|---|---|---:|---|
| `classic` | Klasik Simit | Klasik | Ücretsiz | — |
| `denizci` | Denizci Simit | Kıyafet | 50 | — |
| `pilot` | Pilot Simit | Kıyafet | 100 | — |
| `gece` | Gece Martısı | Tüy | 150 | Seviye 3 |
| `altin` | Altın Kanat | Tüy | 250 | Seviye 5 |
| `kasif` | İstanbul Kaşifi | Kıyafet | 350 | Seviye 8 |

## 3. Pixel art (sprite entegrasyonu)

Görseller, oyunun mevcut karakter üreticisiyle (`art/_source/pixel/characters.js`) üretildi. Geçici bir çizim ya da SVG değil; Simit'in kendi piksel fonksiyonları kullanıldı.

- **Aynı anatomi:** Gövde, baş, gaga, kuyruk, göğüsteki simit ve kanat çizimi aynı fonksiyonlardan geliyor. Görünüm = **palet** (tüy tonları) + **aksesuar katmanları**.
- **Aynı sheet:** 288×84 px, 12 kare, kare 48×42, pivot (22,22). Kanat döngüsü ve özel kareler birebir aynı (test: bütün sheet'ler klasik ile aynı boyutta).
- **Kontur:** Aksesuarlar dış kontürden önce çiziliyor, böylece karakterle aynı koyu dış çizgiyi alıyor.
- **Canlılık:** Denizci kurdelesi, fes püskülü ve pilot atkısı kanat açısıyla salınıyor; kare kare hareket var.
- **Oyun sonu karesi:** Simit şapkalı görünümlerde şapkanın tepesine konuyor; ifade aynı.
- **Klasik sheet:** **bayt bayt aynı** (MD5 `aa030e98…` değişmedi).
- **Hitbox:** sheet'ten bağımsız (`birdHitRadius`); görünüm onu değiştirmiyor (test).

| Görünüm | Ayrıntı |
|---|---|
| Denizci Simit | Beyaz denizci şapkası, 2 px lacivert bant, altın toka, arkaya uçuşan iki kurdele; gaganın altında lacivert fular |
| Pilot Simit | Kahverengi deri başlık (göz açık), kulaklık kayışı, kehribar camlı yuvarlak gözlük; boyunda kırmızı ipek atkı, ucu rüzgârda |
| Gece Martısı | Ay ışığında lavanta-gri tüyler, lacivert kanatlar, kanatta yıldız pırıltıları, buz mavisi iris |
| Altın Kanat | Altın kanat ve sırt tüyleri, bronz kanat ucu, kanatta pırıltı |
| İstanbul Kaşifi | Kırmızı fes, siyah püskül; göğüste nazar boncuğu |

**Önizleme:** `docs/screenshots/phase2_2/skins_sheet_preview.png` (5 kare × 6 görünüm, 5× büyütme).

**Uçuşta okunurluk** (web derlemesi, 393 pt): Galata'da gündüz ve Rumeli Hisarı'nda gece pilot görünümü dalış eğiminde de seçiliyor. Bkz. `flight_pilot_galata.png`, `flight_pilot_rumeli.png`.

**Değerlendirme:**
- Sprite'lar kendi gözden geçirmemde oyunun pixel diliyle tutarlı.
- **Bir tasarımcının ve gerçek iPhone ekranının değerlendirmesi henüz yok.**
- Denizci fuları küçük boyutta ince kalıyor; şapka ana tanıma öğesi.

## 4. Mağaza tasarımı

`lib/ui/overlays/shop_overlays.dart` → `ShopOverlay`.

- **Giriş:** Menüdeki simit rozeti ("150 · Mağaza"; 320 pt'de yalnızca sayı).
- **Üst kısım:** bakiye, büyük animasyonlu önizleme (3×, kanat çırpar ve süzülür; "animasyonları azalt" açıkken sabit kare), ad, kategori ve açıklama.
- **Liste:** 6 kart: 2× önizleme, ad, durum metni (fiyat / "30 eksik" / "5. seviyede açılır" / "Sende" / "Kullanılıyor") ve tek bir işlem düğmesi.
- **Satın alma akışı:**
  1. "Satın al" (yetersiz simitte kapalı)
  2. Onay paneli (fiyat ve kalan bakiye, Vazgeç / Satın al). Panel görünür alana kayıyor; aşağıdaki kartlarda da görünüyor.
  3. Kayıt
  4. "SATIN ALINDI!" damgası: 3 sabit ölçek adımı, bulanıklık yok. Rekor sesi ve orta titreşimle birlikte.
  5. "Hemen kullan" düğmesi
- **Hata mesajları:**
  - Yetersiz simit
  - Seviye kilidi
  - "Satın alma kaydedilemedi; simit düşülmedi"
- **Koruma:** Çift dokunmaya karşı arayüzde `_busy`, controller'da ürün başına kilit. Satın alınmış ürün tekrar satın alınamıyor (düğme "Kullan"a dönüyor).
- **Erişilebilirlik:**
  - Kartlarda "ad, durum" VoiceOver etiketi, önizlemede görsel etiketi.
  - Düğmeler ≥ 44 pt.
  - Uzun Türkçe adlar sarılıyor; 320 / 375 / 430 pt'de taşma yok (test).

## 5. Martı Görünümü (özelleştirme)

`WardrobeOverlay`; profildeki "Martı görünümü" düğmesinden açılıyor.

- Seçili görünümün animasyonlu önizlemesi ve adı.
- Yalnızca sahip olunan görünümler (dokun → kullan; seçili olan çerçeveli, "KULLANILIYOR").
- "Klasik görünüme dön" (klasikteyken kapalı).
- "Mağaza · n yeni".
- **Seçimin uygulanması:** Menüde hemen (READY), uçuş sırasında yapılırsa bir sonraki turda. Uçuş içinde görünüm değişmiyor (test).
- **Kalıcılık:** Seçim `selectedCosmetic` olarak kaydediliyor; uygulama yeniden açılınca korunuyor (test).

## 6. Ekonomi dengesi

> Aşağıdaki sayılar oyun ayarlarından yapılmış **tahmindir**; gerçek oyuncu verisi yok (analitik bilinçli olarak eklenmedi).

- **Uçuş başına simit:**
  - Her engel çiftinde %45 olasılıkla simit var; ilk engelde yok.
  - Toplama oranını ~%70 varsayınca, skor `s` için ≈ `0,3·s` simit.
  - Yeni oyuncu (skor 5–10): **2–3**. Ortalama (15–25): **5–7**. İyi oyuncu (40+): **12+**.
- **Günlük görevler:** Kademeye göre günde 15 / 30 / 45 simit (3 görev).
- **Başarımlar:** Toplam 195 simit (tek seferlik). İlk ikisi (İlk Kanat Çırpışı, Galata Kaşifi) ilk günlerde 15 simit getiriyor.

| Profil | Günlük tahmini kazanç | İlk görünüm (50) | Hepsi (900) |
|---|---|---|---|
| Yeni oyuncu, günde ~10 uçuş | 25–30 uçuştan + 15 görev ≈ 40–45 | **1. gün** | — |
| Düzenli oyuncu, günde ~15 uçuş, skor ~20 | ~90 + 30 ≈ 120 (+ başarımlar) | 1. gün | **~7 gün** |
| Ara sıra oynayan, günde ~5 uçuş | ~25 + 15–30 ≈ 45 | 1–2. gün | ~3 hafta |

**Değerlendirme:**
- İlk görünüm ilk oturumda geliyor (erken ödül).
- Pahalı görünümler 1–3 haftalık bir hedef.
- Seviye kilitleri hafif: seviye 8 yaklaşık 20 uçuş. Gece, Altın ve Kaşif görünümleri satın alınmadan önce oyunun biraz tanınmasını istiyor.
- Günlük giriş zorunluluğu, seri cezası ya da süreli teklif yok.
- **Fiyatlar** istenen tablodaki gibi bırakıldı. TestFlight geri bildirimine göre `ShopConfig`'ten tek satırla değiştirilebilir.

## 7. Veri ve geçiş

- **Şema değişmedi:** `progress_v2` (v: 2) içindeki `unlockedCosmetics`, `selectedCosmetic` ve `spentSimits` 1.1.0'da zaten vardı. 1.0.0 → 1.1.0 geçişi aynen geçerli; 1.1.0 → 1.2.0 için geçiş gerekmiyor.
- **Bilinmeyen kimlik** (ör. ileri bir sürümden `kaptan_sapkasi`): sahiplik listesinde korunuyor, silinmiyor. Seçiliyse oyunda klasik kullanılıyor.
- **Bozuk alanlar** (liste değil, negatif harcama vb.) varsayılana düşüyor. `classic` her zaman sahip olunan.
- **Satın alma işlemi** `ProgressController.purchase`:
  1. Kayıt kuyruğunda sıra bekliyor.
  2. Güncel profilden hesaplıyor: bakiye, sahiplik, kilit.
  3. **Önce diske yazıyor**, yazma başarılıysa ekrana uyguluyor.
  4. Yazma başarısızsa hiçbir şey değişmiyor (`saveFailed`, simit düşülmez).
- **Uygulama kapanırsa:** Tek anahtara tek `setString` yazılıyor; ya önceki ya yeni profil kalıyor, yarım kayıt olmuyor.

## 8. Test sonuçları (22 Ekim 2026, Windows, Flutter 3.47.7)

- `flutter analyze`: **No issues found**
- `flutter test`: **166/166**
  - `test/cosmetics_test.dart`, 20 test:
    - katalog: kimlikler, ücretsiz klasik, fiyat tablosu, sheet'lerin varlığı ve boyutu
    - yeterli / yetersiz bakiye, sınır değer, ödül simitiyle satın alma, negatif bakiye koruması
    - tekrar satın alma, seviye kilidi, bilinmeyen ürün, kart durumları
    - seçim kuralları, bilinmeyen kayıtlı görünüm, bozuk alanlar, 1.0.0 ve 1.1.0 kayıtları
    - kalıcılık (satın alma, seçim, klasik görünüme dönüş)
    - çift istek, kayıt hatasında geri alma
    - eksik sprite → klasik
    - uçuş içinde görünüm değişmemesi
    - 6 görünümle aynı simülasyon sonucu (skor, simit, konum, hitbox)
    - JSON gidiş-dönüş
  - `test/shop_ui_test.dart`, 10 test:
    - menü → mağaza, durumlar
    - onay → satın alma → damga → kullan, tekrar alınamaz
    - çift dokunma tek ücret
    - aşağıdaki üründe onayın görünür olması
    - yetersiz simit
    - profil → görünüm, klasik görünüme dönüş, mağaza
    - kartpostal boyutu görünümden bağımsız
    - 3 iPhone boyutunda taşma
  - Eski 136 test değişmeden geçiyor.
- **Web release derlemesi** (demo bayraklı) headless Edge'de 393×852 @3x görsel kontrol: `docs/screenshots/phase2_2/`. **Bunlar web görüntüsüdür, iPhone ekran görüntüsü değildir.**
- **Not:** Web derlemesinde yeni asset klasörü eklendikten sonra artımlı derleme eski asset'leri çıktıya kopyalamadı; `build/web` silinip temiz derlemeyle düzeldi. Codemagic her derlemeyi temiz kopyadan yaptığı için iOS'u etkilemez.

## 9. iOS test senaryoları (gerçek iPhone)

| # | Senaryo | Beklenen | Durum |
|---|---|---|---|
| 1 | 1.1.0 → 1.2.0 güncelleme | Rekor, XP, seviye, görevler, başarımlar ve simit bakiyesi aynı | NOT RUN |
| 2 | Menü: simit rozetine dokun | Mağaza açılır; bakiye doğru | NOT RUN |
| 3 | Yetersiz simit | Satın al kapalı, "x eksik" görünür | NOT RUN |
| 4 | Satın alma | Onay → damga, ses, titreşim → bakiye düşer; kart "Kullan" | NOT RUN |
| 5 | Çift dokunma | Tek ücret | NOT RUN |
| 6 | Kullan → uçuş | Yeni görünüm uçuşta, kartpostalda ve paylaşılan görselde | NOT RUN |
| 7 | Uygulamayı zorla kapat / aç | Satın alımlar ve seçim korunur | NOT RUN |
| 8 | Satın aldıktan hemen sonra uygulamayı kapat | Açılınca ya satın alım tam ya hiç; simit kaybı yok | NOT RUN |
| 9 | Klasik görünüme dön | Menüde hemen klasik | NOT RUN |
| 10 | Görünümler × bölgeler | Beş bölgede ve gece/gündüzde görünüm okunur, titreme yok | NOT RUN |
| 11 | Seviye kilidi | Gece (3), Altın (5), Kaşif (8): kilitliyken "x. seviyede açılır" | NOT RUN |
| 12 | VoiceOver | Kartlar "ad, durum" olarak okunur; düğmeler etiketli | NOT RUN |
| 13 | iPhone SE / Pro Max | Mağaza ve görünüm ekranı taşmaz; menü rozeti tek satır | NOT RUN |
| 14 | Animasyonları azalt | Önizlemeler sabit kare, damga animasyonsuz | NOT RUN |

## 10. Bilinen eksikler

1. **Gerçek cihazda görülmedi:** Sprite'ların iPhone ekranında okunurluğu ve renkleri (özellikle Denizci fuları) cihazda değerlendirilmeli.
2. **Tasarımcı incelemesi yok:** Görünümler, mevcut üreticiyle ve aynı kurallarla yapıldı; bağımsız bir sanat incelemesi yapılmadı.
3. **Ekonomi tahmini ölçüme dayanmıyor:** TestFlight oyuncularından kaç uçuşta ilk görünüme ulaştıkları sorulmalı.
4. **Mağaza ekranı tek liste:** Kategori filtresi yok (6 ürün için gerekmedi).
5. **Uçuşta tam animasyon yalnızca sprite'ta:** Aksesuarlar ayrı katman değil, her görünüm tam bir sheet (her biri ~3 KB). Avantajı karışık katmanlama hatası olmaması; dezavantajı yeni karakter karesi eklenirse bütün görünümlerin yeniden üretilmesi (üretici bunu tek komutla yapıyor).
6. **1.1.0 (2)'nin gerçek cihaz sonuçları henüz gelmedi;** 1.2.0 ondan sonra yüklenmeli.

## 11. Phase 2.3 önerileri

1. **Başarım ödülü görünümler:** Ör. "İstanbul Fatihi" (1453 puan) → mağazada satılmayan "Fatih Kaftanı". Katalogda `unlockBy: achievement` alanı.
2. **Görünüm efekti** (yalnızca görsel): Altın Kanat'ta kanat çırpışında 1–2 piksellik pırıltı, Gece'de iz yıldızları. `FxLayer` havuzu yeniden kullanılır; fizik dokunulmaz.
3. **Kartpostal çerçeveleri:** Paylaşılan kartpostal için kozmetik çerçeve ya da pul (paylaşım odaklı, ücretsiz kazanılan).
4. **Haftalık görev** (isteğe bağlı, cezasız): Büyük hedefler, görünüm odaklı simit ödülü.
5. **Ekonomi ayarı:** TestFlight geri bildirimine göre `ShopConfig` fiyatları; gerekirse yeni oyuncu için ilk görünüme %50 indirim (tek seferlik).
6. **Yerel istatistik ekranı:** Hangi görünümle kaç uçuş yapıldı (yalnızca cihazda, analitik değil).

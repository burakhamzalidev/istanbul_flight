# Phase 3.0 mağaza paketi

Durum: **hazır, App Store Connect'e yüklenmedi.** Yükleme ve metin girişi yalnızca kullanıcı onayıyla yapılır.

## 1. Ekran görüntüleri (`screenshots/`)

| Dosya | Boyut | Apple sınıfı |
|---|---|---|
| `tr_iphone_01–06.png`, `en_iphone_01–06.png` | 1206 × 2622, PNG, 24 bit RGB (alfa yok) | iPhone, Dynamic Island orta ekran: **zorunlu** sınıf |
| `tr_ipad_01–06.png`, `en_ipad_01–06.png` | 2048 × 2732, PNG, 24 bit RGB (alfa yok) | iPad 13 inç: uygulama iPad'de çalıştığı için **zorunlu** |

Apple'ın kuralları 11 Kasım 2026'da resmî sayfadan okundu: developer.apple.com/help/app-store-connect/reference/screenshot-specifications.
- **Dynamic Island orta ekran:** 1179×2556 ya da 1206×2622.
- **iPad 13 inç:** 2048×2732 ya da 2064×2752.
- **Biçim:** JPEG ya da PNG, alfa kanalı yok.
- **Sayı:** Boyut başına 1–10 görüntü.

**Sıra ve başlıklar** (`metadata.json` → `screenshot_captions`):

| # | TR | EN | Görüntü |
|---|---|---|---|
| 1 | İstanbul Üzerinde Uç | Fly Over Istanbul | Galata, uçuş (skor 31) |
| 2 | Dokuz Bölgeyi Keşfet | Explore Nine Districts | Ortaköy Camii ve Boğaz Köprüsü, "KIL PAYI! +5 XP" (iPhone 179, iPad 158) |
| 3 | Her Uçuşta Yeni Heyecan | A Thrill Every Flight | Boğaz Köprüsü, gece (iPhone 68, iPad 65) |
| 4 | Martını Özelleştir | Customize Your Seagull | Simit Mağazası |
| 5 | Haftalık Kupada Yarış | Race the Weekly Cup | Etkinlikler → İstanbul Kupası (Boğaz Maratonu) |
| 6 | Her Gün Yeni Parkur | A New Course Every Day | Günün Uçuşu |

**Nasıl üretildi (dürüst kayıt):**
- **Kaynak:** Gerçek oyun, Flutter **web** derlemesi (`--dart-define=MARTI_DEMO=true`), başsız Microsoft Edge ve Chrome DevTools Protocol. **Gerçek bir iPhone ya da iPad'den alınmış ekran görüntüsü değildir.** Çizim aynı Flutter/Flame kodundan, aynı görsellerle yapılıyor; yazı tipi ve renkler aynı.
- **Uçuş görüntüleri:** Otomatik pilot gerçekten uçtu: 0'dan başlayan tek bir uçuş Haliç'ten Üsküdar'a kadar 7 dakika sürdü; her 25 saniyede bir görüntü alındı.
  - Görüntülerdeki skor ve simit sayıları o uçuşta **gerçekten ulaşılan** değerler; başlangıç skoru verilmedi.
  - Otomatik pilot çarpışmaya karşı korumalıydı. Görüntüde bunun bir izi yok, ama skorlar bir insan oyuncunun skoru değil.
- **Ekranlar:** Mağaza, Etkinlikler ve Günün Uçuşu yeni bir profilde açıldı (bakiye 0, haklar 3/3).
  - Tarih ve kalan süreler o anki gerçek değerler.
  - Yalnızca tanıtım derlemesinde çalışan `&modal=` parametresiyle açıldı (`lib/main.dart`; normal derlemede yok).
- **Sahte veri yok:** Sahte skor, uydurma oyuncu adı ya da sahte sıralama yok. Game Center sıralaması gösterilmedi: web derlemesinde Game Center çalışmıyor; gerçek veriyle görüntü ancak iPhone'dan alınabilir.
- **Ölçekleme yok:** Görüntüler hiç ölçeklenmedi.
  - Oyun doğal çözünürlükte, kısaltılmış bir görüş alanında çizildi: iPhone 402×734 nokta @3x, iPad 1024×1166 @2x.
  - Üstteki başlık şeridiyle birleşince tam mağaza ölçüsü çıkıyor. Pixel art bulanık değil.
- **iPad'deki yan şeritler:** Oyun görüş alanını dikey orana sabitler. iPad'de yanlardaki koyu şeritler oyunun iPad'deki gerçek görünümüdür.
- **İngilizce görüntüler:** Oyunun arayüzü Türkçe; İngilizce görüntülerde yalnızca başlıklar İngilizce. Bu, açıklamada da belirtiliyor.

**Yeniden üretme:** Oturumun geçici klasöründeki `cap.js` (CDP yakalama) ve `compose.js` (başlık şeridi) betikleri kullanıldı. Ayrıntılı adımlar [../../23_phase3_0_premium_release.md](../../23_phase3_0_premium_release.md) §5'te.

**Gerçek cihaz görüntüsü önerisi:** Apple web derlemesi görüntülerini reddetmez, ama en güvenli yol aynı 6 sahneyi gerçek bir iPhone 16 Pro'dan (1206×2622) ve 13 inç iPad'den almaktır. 1. ve 2. görüntü gerçek bir oyuncu uçuşuyla tekrarlanabilir.

## 2. Mağaza metinleri (`metadata.json`)

- **Diller:** TR ve EN için ad, alt başlık, tanıtım metni, anahtar kelimeler, açıklama, yenilikler ve görüntü başlıkları.
- **Sınır denetimi:** `node tool/store_check.js`. Ad ve alt başlık ≤ 30, tanıtım ≤ 170, açıklama ≤ 4000 karakter; anahtar kelimeler ≤ 100 **bayt** (UTF-8, Türkçe harfler 2 bayt).
- **Son sonuç:** Bütün sınırlar uygun (TR anahtar kelimeler 89 bayt, EN 93 bayt).
- **Neden yenilendi:** 1.2.0 metinleri 5 bölge anlatıyordu ve Günün Uçuşu, kupa, sezon ve Game Center'dan söz etmiyordu.
  - Yeni metinler yalnızca oyunda olan özellikleri anlatıyor: 9 bölge, 8 görünüm, 9 başarım, 3 dereceli günlük hak, haftalık kupa, 4 haftalık sezon.
  - İngilizce açıklamada "arayüz Türkçe" uyarısı var.
- **Anahtar kelimeler:** Rakip ya da marka adı yok.

## 3. Uygulama simgesi

`../app_store_icon_1024.png` incelendi. `icon_small_sizes.png`, simgeyi iOS boyutlarında (180, 120, 87, 80, 60, 40 px) ve yuvarlak köşe maskesiyle, açık ve koyu zeminde gösteriyor.
- **Martı:** Beyaz martı her boyutta tanınıyor.
- **Galata Kulesi:** Silueti 60 piksele kadar okunuyor.
- **Kalabalık değil:** Tek karakter, tek simge yapı, gün batımı şeritleri.
- **Uyum:** Oyunun renkleriyle aynı.
- **Karar: Değişiklik önerilmiyor.** Simge değiştirilmedi.
- **İsteğe bağlı küçük iyileştirme:** 40 pikselde gaga ve simit küçülüyor; martıyı %10 büyütmek denenebilir. Bu, senin onayın ve yeni bir pixel art çizimi gerektirir.

## 4. App Preview (tanıtım videosu): yalnızca senaryo

**Video üretilmedi.** Bu bilgisayarda video kodlayıcı (ffmpeg) yok. Apple da tanıtım videosunun uygulamadan kaydedilmesini bekliyor; en doğru kaynak iPhone'un ekran kaydı.

**Apple kuralları** (resmî sayfa, 11 Kasım 2026): 15–30 sn, en fazla 30 fps, H.264 ya da ProRes 422 HQ, en fazla 500 MB, dil ve boyut başına en fazla 3 video.

| Cihaz | Çözünürlük (dikey) |
|---|---|
| iPhone 6.9" / 6.5" | 886 × 1920 |
| iPad 13" | 1200 × 1600 |

| Süre | Sahne | Kayıt talimatı |
|---|---|---|
| 0–3 sn | Haliç'te açılış: logo ve menüdeki Simit | Uygulama açılışı, ana menü (dokunmadan 2 sn) |
| 3–8 sn | Uçuş ve engel geçişleri | "Uçuşa başla", 4–5 engel geçişi, bir simit toplama |
| 8–13 sn | Bölge geçişleri | Aynı uçuşta Galata → Kız Kulesi geçişi (bölge damgası görünür). Daha uzak bölgeler için ayrı bir uçuştan kesit |
| 13–18 sn | Simit Mağazası | Menü → Mağaza, görünüm önizlemesi, bir görünüm seç |
| 18–23 sn | Günün Uçuşu ve İstanbul Kupası | Menü → Günün Uçuşu ekranı, sonra Etkinlikler → Kupa |
| 23–30 sn | Kapanış | Oyun sonu kartpostalı ve ana menüde "UÇUŞA BAŞLA" |

**Kurgu notları:**
- Kayıt iPhone'un ekran kaydıyla alınır, sonra 886×1920'ye (9:19,5) kırpılır ve ölçeklenir. Pixel art için en yakın komşu ölçekleme kullanılmalı.
- Ses: oyunun kendi müziği ve efektleri; yalnızca stereo AAC 256 kbps.
- Metin bindirilecekse kısa ve görüntü başlıklarıyla aynı olmalı.
- Sahte skor ya da oyunda olmayan bir sahne eklenmemeli.

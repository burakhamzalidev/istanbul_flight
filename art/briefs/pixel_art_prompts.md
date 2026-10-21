# Pixel art: final illüstrasyon için görsel üretim promptları

> Güncelleme: Beş bölgenin kamera açıları, kompozisyonları ve mimari ayrıntıları gerçek fotoğraf referanslarıyla belirlendi (docs/09–13). Final çizimde aşağıdaki promptlar yerine **o belgelerdeki kamera ve öğe tabloları** esas alınmalı. Aşağıdaki boyutlar güncel dosyalarla aynıdır.

Bu oturumda görsel üretim aracı yoktu. Oyundaki pixel art seti `art/_source/pixel/*.js` ile **piksel piksel programatik** üretildi (docs/08). Set oynanabilir ve tutarlı, ama elle çizilmiş "premium" kalitede değil. Aşağıdaki promptlar, bir pixel artist veya görsel üretim aracıyla final setin hazırlanması içindir.

**Üretilen her görsel, oyuna girmeden önce bir pixel artist tarafından temizlenmeli.** Bu iş için şu kurallar geçerli: tek piksel ızgarası, kontrollü palet, yarı saydam kenar olmaması, döşenebilir kenarlar. Yapay zekâ çıktıları genelde sahte piksel (karışık ölçek, bulanık kenar) üretir; bu hâliyle kullanılamaz.

## Ortak teknik kurallar (her prompta eklenecek)

```
True pixel art on a strict 1:1 pixel grid, no anti-aliasing, no sub-pixel blur,
hard 1px dark outline only where needed, limited palette (max 32 colors per zone),
ordered (Bayer) dithering for gradients, consistent pixel density across the whole image,
transparent background (PNG) unless stated, no text, no logos, no watermark.
Style: high-detail, semi-realistic, handcrafted pixel art with cinematic lighting and
authentic Istanbul architecture.
```

Oyun ölçeği: 1 piksel = 4 dünya birimi. Oyun 480 piksel yükseklikte bir sahne; ufuk çizgisi 298. pikselde. Teslim edilen boyutlar aşağıdaki tablodaki boyutlarla **birebir** aynı olmalı. Böylece kod değişmeden dosya değiştirilebilir.

| Dosya | Boyut (px) | Not |
|---|---|---|
| backgrounds/<bölge>/sky.png | 160×298 | yatay döşenir |
| backgrounds/<bölge>/sun.png | 96×96 | güneş/ay + hale, saydam |
| backgrounds/<bölge>/clouds.png | 256×48 | 3 bulut: x 0–113, 114–195, 196–255 |
| backgrounds/<bölge>/distant.png | 400 × (110–190) | alt kenar = ufuk, döşenir; yükseklik bölgeye göre (docs/09–13) |
| backgrounds/<bölge>/midground.png | 400 × (80–180) | alt kenar = ufuk, döşenir; yükseklik bölgeye göre |
| backgrounds/<bölge>/waterfront.png | 400×28 | 12. satır = ufuk, döşenir |
| backgrounds/<bölge>/water.png, water_hi.png | 128×182 | döşenir; _hi sadece parıltılar |
| backgrounds/<bölge>/ferry.png | 96×30 | sola bakan Şehir Hatları vapuru (baca x=55) |
| landmarks/*.png | galata 176×200 (kule + tepe kümesi), suleymaniye 208×124 (cami + sırt), kiz_kulesi 172×132 (kule + adacık), bridge 480×200 (köprü + Ortaköy Camii), rumeli_hisari 380×132 | saydam; yerleşim `LandmarkLayer.layout` |
| characters/simit_sheet.png | 288×84 | 6×2 kare, kare 48×42, pivot (22,22), gövde her karede aynı yerde |
| obstacles/kit_<bölge>.png | 372×160 | parça yerleşimi: `lib/game/visual/obstacle_kit_layout.g.dart` (×0,25) |
| effects/fx.png | 256×64 | yerleşim: `lib/game/game_art.dart` |
| ui/icons.png | 304×16 | 19 ikon, 16×16 hücre, beyaz maske |

## 1. Haliç (şafak)

```
Pixel art parallax layers of the Golden Horn at dawn, Istanbul. Distant layer: the historic
peninsula skyline with the Süleymaniye Mosque silhouette (four minarets, cascading domes) in
lavender haze. Midground: Ottoman wooden houses with tiled roofs, cumba bay windows, chimneys,
some windows warmly lit. Waterfront: wooden piers, small rowing boats, a timber jetty.
Soft pink-orange sunrise low on the horizon, layered morning fog over the water, golden light
on wet water ripples. Palette: lavender, dusty pink, peach, warm ochre roofs, slate blue water.
```

## 2. Galata (gün ortası)

```
Pixel art parallax layers of Galata and Beyoğlu at bright midday, Istanbul. Landmark: the
Galata Tower — cylindrical stone body with coursed masonry, arched windows, the gallery balcony
with railing and the conical lead roof — recognisable, accurate proportions. Midground:
19th-century Beyoğlu apartment blocks, wrought-iron balconies, striped awnings, shuttered windows,
flower pots. Waterfront: Karaköy quay with a white-and-navy Istanbul city ferry (vapur) with
funnel. Clear blue sky, crisp cumulus clouds, sparkling blue Bosphorus water.
```

## 3. Kız Kulesi (gün batımı)

```
Pixel art parallax layers of the Maiden's Tower (Kız Kulesi) at sunset, Istanbul. The tower on its
small rocky islet: square stone tower, gallery, octagonal lantern with lead cap and a small red
flag, the low side building — strongly backlit, rim-lit in orange. Background: Üsküdar hills with
small mosques and houses, warm window lights. Large low sun on the horizon, golden reflection
column on the water, a ferry trailing soft smoke. Palette: magenta, coral, deep plum silhouettes,
gold highlights.
```

## 4. Boğaz Köprüsü (akşam)

```
Pixel art parallax layers of the Bosphorus Bridge at dusk, Istanbul. Realistic suspension bridge:
two steel portal towers with cross beams, catenary main cables, evenly spaced vertical hangers,
deck with a string of warm lights, the famous colour-changing blue LED lighting on the towers.
Midground: waterfront yalı mansions (wooden Ottoman seaside villas) with lit windows, Ortaköy
skyline. Deep blue twilight sky, first stars, a thin crescent moon, light reflections on dark water.
Bridge must stay geometrically correct and readable at small size.
```

## 5. Rumeli Hisarı (gece)

```
Pixel art parallax layers of Rumeli Hisarı fortress at night, Istanbul. Three large round towers
(Halil Paşa near the shore, Saruca Paşa on the hilltop, Zağanos Paşa) and two small towers,
crenellated curtain walls climbing the wooded hillside, arrow slits, warm floodlights from below
on the stone. Dense dark trees with moonlit edges, a few lit houses on the slope, rocky shore.
Night sky with stars and a bright moon, calm black-blue water with long light reflections.
Composition must be clearly different from the bridge zone: a hillside fortress, not a span.
```

## 6. Simit (karakter sprite sheet)

```
Pixel art sprite sheet of "Simit", a chubby Istanbul seagull mascot, side view facing right,
white body, grey wings with black tips, yellow beak with red spot, wearing a sesame bagel (simit)
like a ring around the neck. 48x42 px per frame, 12 frames on a 6x2 grid, body locked in the same
place on every frame (no jitter): row 1 = 6-frame wing flap cycle (up → down → recovery);
row 2 = glide, rise (focused eyes), fall (surprised eyes), hit (X eyes, stars, simit flying),
blink, game over (dizzy, simit on head). Transparent background, 1px dark outline.
```

## 7. Engel kitleri (bölge başına 1)

Engeller tarihi ya da dini yapı **olamaz**. Sadece sıradan yapılar ve nesneler kullanılır: apartman, ahşap ev, vapur bacası, köprü ayağı/kafes, taş iskele duvarı.

```
Pixel art obstacle kit for a vertical-scrolling-pipe game, Istanbul <ZONE> theme, 1/4 scale
atlas 372x160: two bottom body tiles 49x48 (seamless vertical tiling), two top body tiles,
bottom cap and top cap 56x32 (cap overhangs body by 3-4 px each side), bottom base 56x80
(meets the water). <ZONE-specific: wooden Ottoman house / Beyoğlu apartment with balconies /
ferry funnel and hull with life rings / bridge pier with steel lattice and lights / mossy
stone pier with ivy and lanterns>. Edges of the collision area must be crisp and fully opaque —
no transparent padding inside the body width.
```

## 8. Arayüz

```
Pixel art UI kit, Istanbul postcard theme: 9-slice panel (cream paper, 2px navy border,
stepped pixel corners, hard drop shadow), primary button (brick-orange), secondary button
(cream), 16x16 white mask icons (pause, play, replay, home, share, sound on/off, settings, help,
music, sfx, vibrate, touch, star, flight, pillars, bolt, sunset, back), collectible simit 20x20
4-frame spin, sparkles, gold ring burst 32x32 4 frames.
```

Font: oyundaki **Marti Pixel** (`assets/fonts/MartiPixel.ttf`) özgün olarak üretildi; Türkçe karakterleri içerir. Final için lisansı doğrulanmış bir pixel font (OFL) seçilirse `ç ğ ı İ ö ş ü Ç Ğ Ö Ş Ü` glifleri mutlaka kontrol edilmeli.

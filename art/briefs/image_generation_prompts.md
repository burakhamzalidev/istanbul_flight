# Görsel Üretim Brief'leri ve Promptlar

> Martı: Istanbul Flight · Aşama 2 · 21 Ekim 2026

Bu dosya, konsept görsellerin **bir AI görsel aracında** (Midjourney, Imagen, DALL·E, Firefly, Stable Diffusion/Flux vb.) ya da **bir illüstratörle** yeniden ve daha yüksek kalitede üretilmesi için hazırlandı.

**Durum:** Bu promptlar henüz hiçbir araçta çalıştırılmadı. Projedeki PNG'ler elle çizilmiş vektör referanslar, bu promptların çıktısı değil.

## Kullanım ipuçları

1. **Promptlar İngilizce.** Görsel modellerin çoğu İngilizcede daha tutarlı sonuç veriyor.
2. **Referans görsel kullanın.** `art/concepts/*.png` kompozisyon/görsel referansı (image prompt, img2img ya da ControlNet), `art/character/simit_character_sheet.png` karakter referansı olarak verilmeli. AI araçları İstanbul mimarisini ve karakter tutarlılığını kendi başına sık sık bozuyor.
3. **Metin ürettirmeyin.** HUD, skor ve etiketler sonradan eklenir. Modeller Türkçe karakterleri bozuyor.
4. **Tutarlılık:** Önce karakter sayfasını üretip onaylayın, sonra onu her sahnede karakter referansı (character reference / IP-Adapter) olarak kullanın.
5. **En boy oranı:** Sahneler için 9:16 (`--ar 9:16`), karakter sayfası için 3:2.

---

## Ortak stil bloğu (her promptun sonuna eklenir)

```
mid-century travel poster illustration, 1950s-1960s Turkish tourism poster style, flat vector shapes,
clean hard edges, limited color palette, posterized banded sky gradient (no smooth gradients),
subtle screen-print grain texture, strong simple silhouettes, atmospheric perspective by layers,
orthographic side view, horizon line at 62% of image height, mobile game concept art, high readability
```

## Ortak negatif prompt

```
photorealistic, 3D render, CGI, glossy, lens flare, bloom, smooth gradients, heavy detail, noise clutter,
anime eyes, text, letters, watermark, logo, signature, distorted architecture, extra minarets,
mosque as obstacle, flying carpet, fez, orientalist costume, cyberpunk city, generic neon city
```

---

## Konsept A — Şafak / Haliç

```
Vertical 9:16 mobile game scene at dawn over the Golden Horn in Istanbul. Soft warm sunrise:
the sun is a pale cream disc half-risen on the horizon with concentric halo rings, sky in horizontal
posterized bands from deep indigo (#3E4A7A) through dusty violet and rose pink (#F4A9A0) to peach (#FCD9B8).
Background: low-contrast lavender silhouette of the historic peninsula on the left with a large Ottoman
imperial mosque in the style of Süleymaniye (one big central dome, semi-domes, four slender pencil minarets),
respectful and distant. Right middle ground: the Galata Tower on the Beyoğlu hill as the single hero landmark,
cylindrical stone tower with an arched-window gallery and a pointed conical roof, rim-lit by peach light,
small lit windows. Calm water in muted periwinkle bands (#5C6E9A) with broken horizontal stripes of
sunlight reflection. A small white Istanbul commuter ferry (vapur) far in the water.
Gameplay layer in front: one pair of vertical obstacles at the center-right — the bottom one is a tall
dark wooden Ottoman house with tiled hip roof and chimney rising from the bottom edge, the top one is
a dark overhanging bay-window (cumba) house facade hanging from the top edge with a laundry line of
small colorful clothes under it; both dark plum-navy with a thin peach rim light on the right edge.
A chubby white gull character with a sesame bagel (simit) around its neck flies on the left third.
A floating simit collectible with a soft glow. Leave empty space at the top for UI.
[ORTAK STİL BLOĞU]
```

## Konsept B — Gün batımı / Kız Kulesi

```
Vertical 9:16 mobile game scene at golden-hour sunset on the Bosphorus, Istanbul. A large warm sun disc
sinking on the horizon at left-center, sky in posterized bands from deep purple (#5B3A6E) to coral (#E3684A),
orange and mustard yellow (#F7C35F). Beneath the sun a poster-style reflection column of broken horizontal
golden stripes on mauve water (#7A4A63). Hero landmark on the right: the Maiden's Tower (Kız Kulesi) on its
small rocky islet — low stone platform walls, a small side building with a hip roof, a square tower with
a gallery and a lantern topped by a pointed lead cupola and a tiny beacon light; dark aubergine silhouette
(#3A2340) with orange rim light and warm lit windows. Far left: faint distant skyline of the historic
peninsula with domes and minarets, low contrast. Small ferry silhouette on the left.
Gameplay layer: one pair of vertical obstacles in the center — bottom: a tall ferry funnel column, dark top
band, muted cream body with a simple anchor emblem, a lit cabin row and a dark hull with a red stripe,
soft smoke puffs drifting back; top: a dark wooden pier pile hanging from the top with ropes and
red-and-white life rings, ending in a lantern bracket with a thin orange edge.
The chubby white gull character with a simit around its neck flies on the left against the purple-coral
band, clearly separated from the background. A glowing simit collectible on the right. Space at top for UI.
[ORTAK STİL BLOĞU]
```

## Konsept C — Gece / Boğaz Köprüsü

```
Vertical 9:16 mobile game scene at night on the Bosphorus, Istanbul. Deep navy and midnight blue
posterized sky bands (#0E1433 to #26305E), small cream stars and a crescent moon. Hero landmark: the
Bosphorus suspension bridge seen broadside — two slender towers framing the scene, the main cable sagging
in a catenary across the middle, thin vertical hanger cables, a dark deck line. Lights only as small
details: warm sodium-yellow (#FFC857) light beads along the cable and the deck, with only a few accent
beads in neon pink (#FF3E7F) and cyan (#00E5FF); red aviation lights on tower tops. Dark hills on both
shores with scattered warm windows, and a very faint, respectful silhouette of the Ortaköy mosque at the
left shore. Dark water with short broken reflections of the lights.
Gameplay layer: one pair of vertical obstacles at center-right — top: a near-black hanger-cable column
with lit beads ending in a clamp block with a sharp yellow edge; bottom: a fishing boat mast column
topped by a glowing lantern box with a soft halo, dark rigging lines.
The chubby white gull character with a simit around its neck flies on the left, with a warm sodium rim
light on its upper right edge so it stays readable. A glowing simit collectible on the right.
Controlled, calm night atmosphere, no bloom haze, grain texture consistent with print. Space at top for UI.
[ORTAK STİL BLOĞU]
```

## Simit — Karakter tasarım sayfası

```
Professional character design sheet, 3:2, warm cream paper background (#F2E6D0), for a mobile arcade game.
Character "Simit": a chubby, round, egg-shaped Istanbul yellow-legged gull (Larus michahellis), cute but
not generic — heavy-lidded, confident, slightly cocky expression, pale yellow iris with a thin red eye-ring,
flat grey-blue brow stroke. Long yellow hooked beak with a red spot on the lower mandible. White head and
body, grey-blue back mantle and wings (#9AACBF), black wingtips with a small white mirror spot, short white
tail with dark tips, yellow legs and webbed feet. Wears a sesame-covered Turkish bagel (simit) around its
neck like a medal, drawn in 3/4 so the hole is visible. Single dark outline color (#2B2B3A), flat colors,
one flat shadow tone, no gradients.
Sheet contents arranged in labeled panels: front view; side view perched; gliding flight pose;
4-frame wing flap cycle (up, down-stroke, mid, down); rising pose tilted up 20°; falling pose nose-down
28° with wings up; expressions: default confident, happy (closed ^ eyes), surprised (big eye, open beak),
crash (X eye, feathers, stars, simit flying off); a panel showing how the simit ring swings in each pose;
silhouette test at 128, 64, 40 and 28 px; color palette swatches.
mid-century travel poster illustration style, flat vector, clean edges, subtle print grain
--no 3D, photorealism, anime eyes, eyelashes, blush cheeks, clothing, text distortion
```

## Palet kartı (gerekirse)

```
Color script card for a mobile game, four horizontal rows of flat swatches labeled Dawn, Noon, Sunset, Night,
mid-century poster style, cream paper background, subtle print grain.
```
(Gerçek değerler `art/palette/palette_sheet.png` içinde. Bu kartın AI ile üretilmesine gerek yok.)

---

## İllüstratör brief'i (kısa)

- **Teslim:** 3 stil karesi (1080×1920, katmanlı PSD/AI/Figma, katmanlar L0–L7), 1 karakter sayfası (vektör).
- **Referanslar:** `art/concepts/*.svg`, `art/character/simit_character_sheet.svg`, `art/palette/palette_sheet.png`, `docs/01–03`.
- **Serbest olan:** Işık, doku ve mimari detayın zenginleştirilmesi, kompozisyonun ince ayarı.
- **Sabit olan:** Palet, ufuk çizgisi (%62), engel genişliği (≈%18) ve dikdörtgen hitbox, Simit'in anatomisi ve 5 kimlik işareti, kutsal yapıların sadece arka planda kalması.

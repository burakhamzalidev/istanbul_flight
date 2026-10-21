// L6 engel kitleri (pixel art). Yerleşim dünya birimiyle aynıdır (ObstaclePiecePlan değişmez),
// atlas 1/4 çözünürlüktedir: 1 px = 4 dünya birimi. Satır 0 renkli parçalar, satır 1 ışık maskesi (boş bırakılır;
// pixel art'ta ışıklar renge işlenmiştir).
// Kurallar: gövde = hitbox genişliği (49 px), başlıklar en fazla 3,5 px (14 birim) taşar, başlık sınırının
// altında görünmez boşluk bırakılmaz, tarihi/dini yapı engel olarak kullanılmaz.
'use strict';
const fs = require('fs');
const path = require('path');
const { Canvas, mix, rng, bayer } = require('./lib');

const S = 4; // dünya birimi / px
const BW = 196, CW = 224, OV = 14, TH = 192, CAPH = 128, BASEH = 320, KIT_H = 320;
const SLOT = { bottomBodyA: 0, bottomBodyB: 200, topBodyA: 400, topBodyB: 600, bottomCap: 800, topCap: 1032, bottomBase: 1264 };
const KIT_W = 1264 + CW; // 1488
const px = v => v / S;
const bw = px(BW), cw = px(CW), ov = px(OV), th = px(TH), caph = px(CAPH), baseh = px(BASEH); // 49, 56, 3.5, 48, 32, 80

// ---------------- doku yardımcıları ----------------
function siding(c, x, y, w, h, base, dark) { c.rect(x, y, w, h, base); for (let j = y + 2; j < y + h; j += 3) for (let i = x; i < x + w; i++) if ((i * 7 + j) % 11) c.set(i, j, dark); }
function ashlar(c, x, y, w, h, base, joint, hi) {
  c.rect(x, y, w, h, base);
  for (let j = y; j < y + h; j++) {
    const row = Math.floor((j - y) / 4);
    if ((j - y) % 4 === 3) { c.hline(x, x + w - 1, j, joint); continue; }
    for (let i = x; i < x + w; i++) { if ((i - x + (row % 2) * 4) % 8 === 0) c.set(i, j, joint); else if ((j - y) % 4 === 0 && bayer(i, j) < 0.3) c.set(i, j, hi); }
  }
}
function brick(c, x, y, w, h, base, joint) {
  c.rect(x, y, w, h, base);
  for (let j = y; j < y + h; j++) { const row = Math.floor((j - y) / 2); if ((j - y) % 2 === 1) { c.hline(x, x + w - 1, j, joint); continue; } for (let i = x; i < x + w; i++) if ((i - x + (row % 2) * 2) % 4 === 0) c.set(i, j, joint); }
}
function win(c, x, y, w, h, { frame, glass, lit, shutter, arch } = {}) {
  c.rect(x - 1, y - 1, w + 2, h + 2, frame);
  c.rect(x, y, w, h, lit || glass);
  if (!lit) c.set(x + w - 1, y, mix(glass, '#a8c8f0', 0.55));
  else c.set(x, y, mix(lit, '#ffffff', 0.5));
  c.vline(x + Math.floor(w / 2), y, y + h - 1, frame);
  if (arch) { c.set(x - 1, y - 1, null); c.set(x + w, y - 1, null); c.hline(x, x + w - 1, y - 2, frame); }
  if (shutter) { c.rect(x - 3, y - 1, 2, h + 2, shutter); c.rect(x + w + 1, y - 1, 2, h + 2, shutter); }
}
function edges(c, x, y, w, h, shade, light) { c.vline(x, y, y + h - 1, shade); c.vline(x + w - 1, y, y + h - 1, light); }
function roofTiles(c, x0, x1, top, bot, base, dark, hi, flatTopX0, flatTopX1) {
  // üst kenar düz ve tam gövde genişliğinde (hitbox sınırı), aşağı doğru saçağa genişler
  for (let y = top; y < bot; y++) {
    const t = (y - top) / Math.max(1, bot - top - 1);
    const l = Math.round(flatTopX0 + (x0 - flatTopX0) * t), r = Math.round(flatTopX1 + (x1 - flatTopX1) * t);
    for (let x = l; x <= r; x++) {
      const row = Math.floor((y - top) / 3);
      let col = (y - top) % 3 === 2 ? dark : base;
      if ((y - top) % 3 !== 2 && (x + row * 2) % 4 === 0) col = mix(base, dark, 0.5);
      if (x > (l + r) / 2 && (y - top) % 3 === 0) col = mix(col, hi, 0.35);
      c.set(x, y, col);
    }
  }
}

/** Betonarme apartman cephesi (Haliç yamacı): 12 px'lik katlar, döşeme bandı, 3 alüminyum pencere, klima,
 *  isteğe bağlı kapalı cam balkon. Işık soldan (doğu, şafak). 48 px yükseklikte dikişsiz döşenir. */
function concreteRows(c, x0, w, y0, y1, wall, seed, { glazed = false } = {}) {
  const r = rng(71 + seed);
  c.rect(x0, y0, w, y1 - y0, wall);
  for (let y = y0; y < y1; y++) for (let x = x0; x < x0 + w; x++) if (bayer(x, y) < 0.06) c.set(x, y, mix(wall, '#5c5a86', 0.12)); // sıva dokusu
  for (let fy = y0 - ((y0 % 12) + 12) % 12; fy < y1; fy += 12) {
    const row = (y, col) => { if (y >= y0 && y < y1) c.hline(x0, x0 + w - 1, y, col); };
    row(fy, mix(wall, '#ffffff', 0.35)); row(fy + 1, mix(wall, '#5c5a86', 0.35)); // döşeme bandı + gölgesi
    const wins = glazed ? [x0 + 4] : [x0 + 4, x0 + Math.round(w / 2) - 4, x0 + w - 13];
    for (const wx of wins) for (let y = fy + 3; y < fy + 9; y++) if (y >= y0 && y < y1) {
      c.hline(wx, wx + 8, y, '#c8ccd2'); if (y > fy + 3 && y < fy + 8) c.hline(wx + 1, wx + 7, y, '#4a4e62');
      if (y === fy + 4) c.set(wx + 2, y, '#a8c0d8'); c.set(wx + 4, y, '#c8ccd2');
    }
    if (glazed) for (let y = fy + 2; y < fy + 11; y++) if (y >= y0 && y < y1) { // kapalı cam balkon
      const bx = x0 + Math.round(w / 2) - 2;
      c.hline(bx, x0 + w - 3, y, y === fy + 2 ? '#e8ecf0' : y > fy + 8 ? mix(wall, '#5c5a86', 0.2) : '#6a7a92');
      if (y > fy + 2 && y <= fy + 8) for (let x = bx; x < x0 + w - 2; x += 5) c.set(x, y, '#d0d6de');
    }
    const ac = x0 + 6 + Math.floor(r() * (w - 14)); if (fy + 9 >= y0 && fy + 11 < y1) { c.rect(ac, fy + 9, 4, 2, '#eef0f2'); c.set(ac + 3, fy + 10, '#9aa0a8'); } // klima
  }
  c.vline(x0 + 1, y0, y1 - 1, mix(wall, '#ffffff', 0.4)); c.rect(x0 + w - 3, y0, 2, y1 - y0, mix(wall, '#5c5a86', 0.45)); // ışık soldan
  c.vline(x0, y0, y1 - 1, '#3e3848'); c.vline(x0 + w - 1, y0, y1 - 1, '#3e3848'); // kontur: gökten ayrışsın
}
function concrete(c, wall, seed, opts) { concreteRows(c, 0, 49, 0, 48, wall, seed, opts); }

/** Boğaz Köprüsü kule ayağı: düz çelik kutu kesit, dikey takviyeler, 24 px'de bir panel eki, sol kenarda mavi LED.
 *  Akşam ışığında mavi-mor. 48 px'de dikişsiz döşenir. */
function steelLegRows(c, x0, W, y0, y1) {
  c.rect(x0, y0, W, y1 - y0, '#55609c');
  for (let y = y0; y < y1; y++) {
    for (const x of [x0 + 12, x0 + 24, x0 + 36]) c.set(x, y, '#434c84'); // takviyeler
    if (y % 24 === 0) c.hline(x0, x0 + W - 1, y, '#56609a'); // panel eki
    if (y % 24 === 1) c.hline(x0, x0 + W - 1, y, '#2a2f5a');
    if (y % 3 === 0) { c.set(x0 + 1, y, '#a8c0ff'); c.set(x0 + W - 3, y, '#8aa8ff'); } // LED şeritler (iki kenarda)
    c.set(x0, y, '#9fb0e8'); c.set(x0 + W - 1, y, '#141830'); c.set(x0 + W - 2, y, '#2e3560');
  }
}
function steelLeg(c) { steelLegRows(c, 0, 49, 0, 48); }

// ---------------- kitler ----------------
// Her parça fonksiyonu yerel tuvale çizer. Koordinatlar px (parça boyutları: gövde 49×48, başlık 56×32, taban 56×80).
const KITS = {
  // Haliç (şafak): Unkapanı–Küçükpazar yamacının betonarme apartmanları (docs/11). Kat döşemeleri, alüminyum
  // pencereler, klimalar, kapalı cam balkonlar; düz çatıda su deposu ve çanak anten; zemin katta dükkân.
  halic: {
    boundary: 28, // dünya birimi (7 px): üstünde sadece su deposu, anten (çarpışmasız süs)
    lit: '#ffd9a0',
    // Renkler yamaçtaki sıva tonlarından, gökten ayrışacak kadar doygun (oynanışta okunurluk)
    bottomBodyA(c) { concrete(c, '#c9a27a', 0); },
    bottomBodyB(c) { concrete(c, '#c48474', 1, { glazed: true }); },
    topBodyA(c) { concrete(c, '#98a0b0', 2); },
    topBodyB(c) { concrete(c, '#d2b88c', 3, { glazed: true }); },
    bottomCap(c) { // sınır y=7: düz çatı parapeti
      c.rect(32, 1, 8, 6, '#a9a4b0'); c.hline(32, 39, 1, '#d4d0d8'); c.vline(39, 1, 6, '#7c7888'); c.rect(34, 0, 4, 1, '#8c8898'); // su deposu
      c.set(12, 3, '#f2f2f0'); c.set(13, 4, '#f2f2f0'); c.set(12, 5, '#d8d8dc'); c.vline(13, 5, 6, '#6a6878'); // çanak anten
      c.vline(22, 0, 6, '#5a5868'); c.hline(20, 24, 2, '#5a5868'); // anten
      c.rect(1, 7, 54, 3, '#ece4dc'); c.hline(1, 54, 9, '#9a948e'); // parapet / korniş
      concreteRows(c, 3, 50, 10, 32, '#c9a27a', 4);
    },
    topCap(c) { // alt kenar = sınır: zemin kat dükkânı (tabela, vitrin, kepenk)
      concreteRows(c, 3, 50, 0, 12, '#98a0b0', 5);
      c.rect(0, 12, 56, 4, '#2f5f8a'); for (let x = 6; x < 50; x += 3) c.set(x, 13, '#f2f2f0'); c.hline(0, 55, 12, '#4c80aa'); // tabela
      c.rect(3, 16, 50, 12, '#3a3c48'); c.rect(5, 17, 22, 10, '#5a7088'); c.set(6, 18, '#a8c8f0'); c.set(15, 20, '#ffd9a0');
      for (let y = 17; y < 27; y += 2) c.hline(29, 51, y, '#8a8c96'); // yarı inik kepenk
      c.rect(0, 28, 56, 4, '#7a7684'); c.hline(0, 55, 28, '#a09ca8'); c.hline(0, 55, 31, '#3a3844'); // saçak
    },
    bottomBase(c) { // zemin kat dükkânları ve taş rıhtım
      c.rect(3, 0, 50, 6, '#c8473a'); for (let x = 7; x < 50; x += 3) c.set(x, 2, '#fff0e0'); c.hline(3, 52, 0, '#e8705c');
      c.rect(3, 6, 50, 30, '#3a3c48'); c.rect(6, 8, 18, 26, '#5a7088'); c.set(7, 9, '#a8c8f0'); c.rect(9, 20, 5, 6, '#ffd9a0');
      for (let y = 8; y < 34; y += 2) c.hline(28, 50, y, '#8a8c96');
      ashlar(c, 0, 36, 56, 26, '#8c857f', '#5e5852', '#b0a8a0'); c.hline(0, 55, 36, '#b0a8a0');
      c.dither(0, 62, 56, 18, '#4f6b5a', '#6e8a76', 0.4, (x, y) => (bayer(x, y) < 0.7));
    },
  },
  // Galata (gündüz): Beyoğlu apartmanı, çatı + iki baca / ferforje balkon, tente
  galata: {
    boundary: 32,
    bottomBodyA(c) { ashlar(c, 0, 0, 49, 48, '#e6d6bd', '#c9b596', '#f6ead6'); for (const fy of [0, 24]) { c.rect(0, fy, 49, 2, '#c9b596'); for (const x of [9, 31]) { win(c, x, fy + 8, 8, 11, { frame: '#c9b596', glass: '#1e2a3a', arch: true }); c.hline(x - 3, x + 10, fy + 20, '#1b1f2a'); for (let b = x - 3; b <= x + 10; b += 2) c.set(b, fy + 19, '#1b1f2a'); } } edges(c, 0, 0, 49, 48, '#a8977a', '#ffffff'); },
    // Beyoğlu apartmanı: ortada her katta cumba (çıkma), yanlarda pencereler (docs/09 §2)
    bottomBodyB(c) {
      ashlar(c, 0, 0, 49, 48, '#d9a391', '#b98370', '#ecc2b2');
      for (const fy of [0, 24]) {
        c.rect(0, fy, 49, 2, '#b98370');
        for (const x of [3, 41]) win(c, x, fy + 8, 5, 12, { frame: '#f3e6cf', glass: '#1e2a3a', arch: true });
        c.rect(12, fy + 3, 25, 19, '#ecc2b2'); c.vline(12, fy + 3, fy + 21, '#fff0e6'); c.rect(35, fy + 3, 2, 19, '#a87060'); // cumba gövdesi
        c.hline(11, 37, fy + 2, '#fff0e6'); c.hline(12, 36, fy + 22, '#8a5a4a'); c.hline(13, 35, fy + 23, mix('#8a5a4a', '#000000', 0.2)); // saçak ve alt gölgesi
        for (const x of [15, 22, 29]) win(c, x, fy + 7, 4, 10, { frame: '#f3e6cf', glass: '#1e2a3a' });
      }
      edges(c, 0, 0, 49, 48, '#8a5a4a', '#fff0e6');
    },
    topBodyA(c) { ashlar(c, 0, 0, 49, 48, '#a9c3d0', '#89a3b1', '#cfe2ea'); for (const fy of [0, 24]) { c.rect(0, fy, 49, 2, '#7d98a6'); for (const x of [9, 31]) win(c, x, fy + 6, 8, 12, { frame: '#f3e6cf', glass: '#1e2a3a' }); c.hline(3, 45, fy + 20, '#1b1f2a'); for (let b = 3; b <= 45; b += 2) c.vline(b, fy + 17, fy + 19, '#1b1f2a'); } edges(c, 0, 0, 49, 48, '#5e7684', '#ffffff'); },
    topBodyB(c) { ashlar(c, 0, 0, 49, 48, '#e0b56c', '#c09450', '#f2d494'); for (const fy of [0, 24]) { c.rect(0, fy, 49, 2, '#a07a3c'); for (const x of [6, 21, 36]) win(c, x, fy + 7, 6, 12, { frame: '#f3e6cf', glass: '#1e2a3a', arch: true }); } edges(c, 0, 0, 49, 48, '#8a6630', '#ffffff'); },
    bottomCap(c) { // sınır y=8
      for (const x of [10, 40]) { brick(c, x, 1, 6, 8, '#a04a34', '#743222'); c.hline(x - 1, x + 6, 1, '#1b1f2a'); }
      roofTiles(c, 0, 55, 8, 24, '#c0563a', '#8a3c28', '#ffd0a8', 3.5, 52.5);
      c.rect(22, 12, 12, 10, '#e6d6bd'); c.poly([[20, 13], [28, 8], [36, 13]], '#8a3c28'); win(c, 25, 15, 6, 6, { frame: '#c9b596', glass: '#1e2a3a' });
      c.rect(0, 24, 56, 3, '#c9b596'); for (let x = 1; x < 56; x += 3) c.set(x, 27, '#a8977a'); c.rect(3, 28, 50, 4, '#ddcbb0');
    },
    topCap(c) {
      ashlar(c, 4, 0, 48, 10, '#8faab8', '#7d98a6', '#b0c8d4');
      c.rect(0, 10, 56, 2, '#5a5f66');
      for (const x of [6, 14, 42, 50]) { c.rect(x - 2, 6, 4, 3, '#b5523b'); c.ellipse(x, 5, 3, 2, '#4f7a4a'); }
      c.rect(4, 12, 48, 8, '#8faab8'); // korkuluk arkası duvar (boşluk yok)
      c.hline(1, 54, 12, '#1b1f2a'); for (let b = 1; b < 55; b += 2) c.vline(b, 13, 19, '#1b1f2a'); c.hline(1, 54, 19, '#1b1f2a');
      for (let i = 0; i < 14; i++) { c.rect(i * 4, 20, 4, 9, i % 2 ? '#f3e6cf' : '#c8473a'); c.rect(i * 4 + 1, 29, 2, 2, i % 2 ? '#f3e6cf' : '#c8473a'); }
      c.hline(0, 55, 20, '#7a2e25');
    },
    bottomBase(c) { ashlar(c, 0, 0, 56, 80, '#ddcbb0', '#b9a888', '#f2e6d0'); for (const x of [4, 30]) { c.rect(x, 10, 22, 30, '#1b1f2a'); c.rect(x + 2, 12, 18, 26, '#3a5068'); c.set(x + 3, 13, '#a8c8f0'); c.rect(x - 1, 7, 24, 3, '#2e8b99'); } ashlar(c, 0, 46, 56, 34, '#8c857f', '#5e5852', '#b0a8a0'); c.dither(0, 66, 56, 14, '#4f6b5a', '#6e8a76', 0.4); },
  },
  // Kız Kulesi (gün batımı): vapur bacası + vapur / iskele kazığı, can simidi, fener
  kizkulesi: {
    boundary: 12,
    // Şehir Hatları vapur bacası (docs/12 kaynak 8): beyaz gövde, hardal-turuncu bant, siyah ağız. Amblem çizilmez.
    bottomBodyA(c) { c.rect(0, 0, 49, 48, '#f3e8dc'); c.rect(0, 0, 10, 48, '#cfb8b0'); c.rect(43, 0, 6, 48, '#fff4e6'); for (const x of [18, 34]) { c.vline(x, 0, 47, '#ddcabc'); for (let y = 4; y < 48; y += 12) c.set(x + 1, y, '#c4ae9e'); } },
    bottomBodyB(c) { KITS.kizkulesi.bottomBodyA(c); c.rect(0, 18, 49, 9, '#d39a2e'); c.rect(0, 18, 10, 9, '#a87420'); c.hline(0, 48, 18, '#f0be5a'); },
    topBodyA(c) { c.rect(0, 0, 49, 48, '#5a3a2c'); for (let x = 10; x < 49; x += 10) c.vline(x, 0, 47, '#43281e'); for (let y = 0; y < 48; y++) for (let x = 0; x < 49; x++) if (bayer(x, y) < 0.08) c.set(x, y, '#6e4a38'); for (const y of [10, 34]) for (let x = 0; x < 49; x++) c.set(x, y + Math.round(4 * Math.sin((x / 48) * Math.PI)), '#a88060'); edges(c, 0, 0, 49, 48, '#2e1c16', '#ff9a55'); },
    topBodyB(c) { KITS.kizkulesi.topBodyA(c); c.ellipse(24, 24, 9, 9, '#f3e6cf'); c.ellipse(24, 24, 4, 4, '#5a3a2c'); for (const [x, y] of [[24, 16], [24, 32], [16, 24], [32, 24]]) c.rect(x - 1, y - 1, 3, 3, '#c8473a'); c.rect(23, 12, 2, 3, '#1e1e28'); },
    bottomCap(c) { // sınır y=3: bacanın siyah ağzı, altında hardal-turuncu bant, beyaz gövde
      c.rect(3, 3, 50, 5, '#23232b'); c.hline(3, 52, 3, '#4a4a58'); c.rect(10, 5, 14, 1, '#3a3a46');
      c.rect(3, 8, 50, 9, '#d39a2e'); c.rect(3, 8, 10, 9, '#a87420'); c.hline(3, 52, 8, '#f0be5a');
      c.rect(3, 17, 50, 15, '#f3e8dc'); c.rect(3, 17, 10, 15, '#cfb8b0'); c.rect(47, 17, 6, 15, '#fff4e6');
    },
    topCap(c) {
      c.rect(4, 0, 48, 10, '#5a3a2c'); c.rect(0, 10, 56, 22, '#4a2e22'); for (let x = 0; x < 56; x += 8) c.vline(x, 10, 31, '#38221a');
      for (const x of [4, 51]) c.ellipse(x, 15, 1.5, 1.5, '#1e1e28');
      c.rect(23, 14, 10, 14, '#1e1e28'); c.rect(25, 16, 6, 10, '#ffd27a'); c.set(26, 17, '#fff4d0');
      for (let x = 2; x < 22; x++) c.set(x, 23 + Math.round(3 * Math.sin(((x - 2) / 20) * Math.PI)), '#a88060');
      for (let x = 34; x < 54; x++) c.set(x, 23 + Math.round(3 * Math.sin(((x - 34) / 20) * Math.PI)), '#a88060');
      c.hline(0, 55, 31, '#2e1c16'); c.hline(0, 55, 10, '#ff9a55');
    },
    // vapurun üst yapısı (beyaz, pencere dizileri, turuncu can simitleri) ve koyu alt gövdesi
    bottomBase(c) {
      c.rect(0, 0, 56, 36, '#f6ece2'); c.hline(0, 55, 0, '#d8cabc');
      for (const wy of [6, 20]) for (let x = 3; x < 53; x += 5) { c.rect(x, wy, 3, 4, '#2c3a4e'); c.set(x, wy, '#ffc46b'); }
      c.hline(0, 55, 15, '#d8cabc'); for (let x = 2; x < 56; x += 2) c.set(x, 14, '#8a8f98'); // güverte korkuluğu
      for (const x of [10, 30, 48]) { c.ellipse(x, 30, 2.5, 2.5, '#e8742c'); c.set(x, 30, '#f6ece2'); } // can simitleri
      c.rect(0, 36, 56, 44, '#1d2027'); c.hline(0, 55, 36, '#3a3f4a'); c.hline(0, 55, 37, '#f6ece2');
      for (let y = 44; y < 80; y += 9) c.hline(0, 55, y, '#262a33');
    },
  },
  // Boğaz Köprüsü (akşam, docs/12): kule ayakları gerçekte düz çelik kutu kesit (kafes değil). Panel ekleri,
  // takviye çizgileri, kenarlarda mavi LED şerit; kapaklarda enine kiriş ve uçak ikaz ışığı; tabanda beton temel.
  kopru: {
    boundary: 8,
    bottomBodyA(c) { steelLeg(c); },
    bottomBodyB(c) { steelLeg(c); c.rect(19, 18, 11, 14, '#262c4e'); c.rect(20, 19, 9, 12, '#323a64'); c.vline(28, 19, 30, '#1a1e38'); c.set(21, 25, '#8a93b6'); }, // bakım kapağı
    topBodyA(c) { steelLeg(c); },
    topBodyB(c) { steelLeg(c); for (let x = 2; x < 46; x += 2) c.set(x, 24, '#7f9cff'); c.hline(1, 46, 25, '#1a1e38'); }, // yatay LED bandı
    bottomCap(c) { // sınır y=2: uçak ikaz ışıkları; altında enine kiriş
      for (const x of [10, 45]) { c.rect(x, 0, 2, 2, '#ff4a4a'); c.set(x, 0, '#ffb0b0'); }
      c.rect(0, 2, 56, 12, '#3a4274'); c.hline(0, 55, 2, '#7f8cc8'); c.hline(0, 55, 13, '#1a1e38');
      for (let x = 3; x < 54; x += 6) c.vline(x, 4, 11, '#2e3456');
      for (let x = 1; x < 56; x += 3) c.set(x, 8, '#7f9cff');
      steelLegRows(c, 3, 50, 14, 32);
    },
    topCap(c) { // alt kenar = sınır: ayak, altında enine kiriş ve ikaz ışığı
      steelLegRows(c, 3, 50, 0, 18);
      c.rect(0, 18, 56, 14, '#3a4274'); c.hline(0, 55, 18, '#7f8cc8'); c.hline(0, 55, 31, '#1a1e38');
      for (let x = 3; x < 54; x += 6) c.vline(x, 20, 29, '#2e3456');
      for (let x = 1; x < 56; x += 3) c.set(x, 24, '#7f9cff');
      c.rect(26, 26, 4, 3, '#ff4a4a'); c.set(27, 26, '#ffb0b0');
    },
    bottomBase(c) { // beton temel kaidesi ve kıyı kayaları
      steelLegRows(c, 3, 50, 0, 14);
      c.rect(0, 14, 56, 46, '#8a8ca4'); c.hline(0, 55, 14, '#b4b6cc'); c.rect(0, 14, 6, 46, '#6e7090');
      for (let y = 22; y < 60; y += 10) c.hline(0, 55, y, '#7a7c94');
      for (let x = 0; x < 56; x += 7) c.set(x, 59, '#ffd27a');
      c.dither(0, 62, 56, 18, '#3e5a6a', '#5a7a8a', 0.45);
    },
  },
  // Rumeli (gece): sahil taş duvarı + fener direği / çay bahçesi çardağı, asma, fenerler
  rumeli: {
    boundary: 12,
    bottomBodyA(c) { ashlar(c, 0, 0, 49, 48, '#5a4a52', '#3e3240', '#7a6670'); const r = rng(29); for (let i = 0; i < 9; i++) { const x = Math.floor(r() * 6) * 8 + 1, y = Math.floor(r() * 12) * 4; c.rect(x, y, 7, 3, mix('#5a4a52', '#e8a050', 0.25 + r() * 0.2)); } for (let y = 0; y < 48; y++) c.set(48 - (y % 2), y, mix('#5a4a52', '#f0a048', 0.5)); edges(c, 0, 0, 49, 48, '#2a2030', '#f0a048'); },
    bottomBodyB(c) { KITS.rumeli.bottomBodyA(c); const r = rng(41); for (let i = 0; i < 34; i++) { const x = 30 + r() * 19 - (i % 3) * 4, y = r() * 48; c.ellipse(x, y, 2 + r() * 2, 1.6, r() < 0.5 ? '#1e3a2a' : '#2a4e36'); } for (let y = 0; y < 48; y += 3) c.set(34 + Math.round(3 * Math.sin(y * 0.3)), y, '#14261a'); },
    topBodyA(c) { c.rect(0, 0, 49, 48, '#162418'); c.rect(20, 0, 9, 48, '#5a4232'); c.vline(20, 0, 47, '#7a5a42'); const r = rng(51); for (let i = 0; i < 40; i++) c.ellipse(r() * 49, r() * 48, 2 + r() * 3, 2 + r() * 2, r() < 0.5 ? '#244a2e' : '#1a3622'); for (let x = 0; x < 49; x++) c.set(x, 14 + Math.round(5 * Math.sin((x / 48) * Math.PI)), '#2a2a3a'); for (let x = 3; x < 49; x += 8) { const y = 15 + Math.round(5 * Math.sin((x / 48) * Math.PI)); c.rect(x, y, 2, 2, '#ffd27a'); } edges(c, 0, 0, 49, 48, '#0a140c', '#3a5a40'); },
    topBodyB(c) { KITS.rumeli.topBodyA(c); for (const [x, y] of [[10, 30], [38, 36]]) { c.vline(x + 2, y - 6, y - 1, '#1e1e28'); c.rect(x, y, 5, 7, '#c8473a'); c.rect(x + 1, y + 1, 3, 5, '#ffb050'); } },
    bottomCap(c) { // sınır y=3: duvar kapağı taşı
      c.rect(3, 3, 50, 4, '#8a7a82'); c.hline(3, 52, 3, '#b8a8ae'); ashlar(c, 3, 7, 50, 25, '#5a4a52', '#3e3240', '#7a6670');
      for (const x of [14, 40]) { c.vline(x, -2, 6, '#1e1e28'); }
      for (const x of [12, 38]) { c.rect(x, 8, 5, 8, '#1e1e28'); c.rect(x + 1, 9, 3, 6, '#ffd27a'); c.set(x + 1, 9, '#fff4d0'); }
    },
    topCap(c) { c.rect(4, 0, 48, 14, '#162418'); c.rect(20, 0, 9, 14, '#5a4232'); c.rect(0, 14, 56, 18, '#5a4232'); c.hline(0, 55, 14, '#7a5a42'); c.hline(0, 55, 30, '#3a2a1e'); for (const x of [8, 26, 44]) { c.rect(x, 20, 5, 8, '#c8473a'); c.rect(x + 1, 21, 3, 6, '#ffb050'); c.vline(x + 2, 17, 19, '#1e1e28'); } c.hline(0, 55, 31, '#1a120c'); },
    bottomBase(c) { ashlar(c, 0, 0, 56, 50, '#4a3c44', '#2e2430', '#6a5a62'); for (let x = 0; x < 56; x++) c.vline(x, 50 - Math.round(3 * Math.abs(Math.sin(x * 0.5))), 79, x % 9 < 5 ? '#141418' : '#1e1e26'); c.dither(0, 66, 56, 14, '#0a1a3a', '#1a2a5a', 0.4); },
  },
};

function atlas(name) {
  const k = KITS[name], c = new Canvas(px(KIT_W), px(KIT_H) * 2);
  const sizes = { bottomBodyA: [bw, th], bottomBodyB: [bw, th], topBodyA: [bw, th], topBodyB: [bw, th], bottomCap: [cw, caph], topCap: [cw, caph], bottomBase: [cw, baseh] };
  for (const [piece, [w, h]] of Object.entries(sizes)) {
    const p = new Canvas(w, h); k[piece](p);
    c.blit(p, px(SLOT[piece]), 0);
  }
  return c;
}

function writeLayout(dartFile) {
  const rect = (x, y, w, h) => `Rect.fromLTWH(${x}, ${y}, ${w}, ${h})`;
  const sizes = { bottomBodyA: [BW, TH], bottomBodyB: [BW, TH], topBodyA: [BW, TH], topBodyB: [BW, TH], bottomCap: [CW, CAPH], topCap: [CW, CAPH], bottomBase: [CW, BASEH] };
  let d = `// ÜRETİLDİ — elle düzenlemeyin. Kaynak: art/_source/pixel/obstacles.js\n// ignore_for_file: constant_identifier_names\nimport 'dart:ui';\n\n`;
  d += `/// Engel kiti yerleşimi (dünya birimi). Atlas pixel art olarak [atlasScale] çözünürlüktedir:\n/// kaynak dikdörtgen = yerleşim × atlasScale. Renkli parçalar satır 0'da, ışık maskesi +lightsOffsetY.\n`;
  d += `abstract final class ObstacleKitLayout {\n  static const atlasScale = 0.25;\n  static const bodyWidth = ${BW}.0;\n  static const capWidth = ${CW}.0;\n  static const overhang = ${OV}.0;\n  static const tileHeight = ${TH}.0;\n  static const capHeight = ${CAPH}.0;\n  static const baseHeight = ${BASEH}.0;\n  static const lightsOffsetY = ${KIT_H}.0;\n`;
  for (const [piece, [w, h]] of Object.entries(sizes)) d += `  static const ${piece} = ${rect(SLOT[piece], 0, w, h)};\n`;
  d += `\n  /// Alt başlıkta hitbox üst kenarının görsel içindeki y konumu (üstünde kalan baca vb. çarpışmasız süs).\n  static const bottomCapBoundary = <String, double>{\n`;
  for (const [name, k] of Object.entries(KITS)) d += `    '${name}': ${k.boundary}.0,\n`;
  d += `  };\n}\n`;
  fs.writeFileSync(dartFile, d, 'utf8');
}

function build(outDir) {
  const files = Object.keys(KITS).map(n => atlas(n).save(`${outDir}/obstacles/kit_${n}.png`));
  const dart = path.resolve(__dirname, '../../../lib/game/visual/obstacle_kit_layout.g.dart');
  writeLayout(dart);
  return [...files, dart];
}

module.exports = { build, atlas, KITS, SLOT, px };

// Kız Kulesi bölgesi: gerçek referanslara dayalı yeniden çizim (docs/10).
//
// Kamera: Avrupa yakasından kalkan vapurdan, kulenin güneybatısından kuzeydoğuya bakış.
// Önde Kız Kulesi ve adacığı; arkada Salacak–Üsküdar yamacı ve tepedeki koru.
// Saat: gün batımı. Güneş kameranın arkasında (batıda); Üsküdar cepheleri ve pencereleri
// altın rengi ışık alır, doğu göğü pembe-mor. Güneş diski bu açıdan görünmez.
//
// Kule biçimi 2021–2023 restorasyonu sonrası hâline göre:
// kaba yontma taş kare gövde → beyaz, çok köşeli, aşağı daralan konsollu galeri → ferforje korkuluklu
// balkon → uzun pencereli beyaz sekizgen köşk → kurşun kaplı şişkin kubbe (yuvarlak çatı penceresi) →
// küçük korkuluklu fener → bayrak direği.
// Adacık: kayalık uç ve kırmızı-beyaz fener işareti, mazgallı taş burç, kiremit çatılı küçük beyaz yapı,
// beyaz korkuluklu rıhtım. Kaynaklar ve lisanslar: docs/10_kiz_kulesi_gercek_referans.md
'use strict';
const { Canvas, mix, rng } = require('./lib');
const BG = require('./backgrounds');
const { ZONES } = require('./zones');
const G = require('./galata');

const hash = (x, y, s = 0) => { let h = (x * 374761393 + y * 668265263 + s * 2147483647) >>> 0; h = ((h ^ (h >>> 13)) * 1274126177) >>> 0; return ((h ^ (h >>> 16)) >>> 0) / 4294967296; };

// Gün batımı ışığı: sıcak altın (güneş arkada, alçakta), gölgeler mor
const SUNLIT = '#ffc98a';
const SHADOW = '#5a4a86';
const HAZE = '#c7a7c4';
const INK = '#2a2236';

// Bölge paleti (zones.js'teki kizkulesi kaydının yerini alır: doğu göğü, gün batımı ışığı arkadan)
const Z = {
  ...ZONES.kizkulesi,
  sky: [[0, '#34407e'], [0.18, '#4d5596'], [0.38, '#7466aa'], [0.56, '#a476b2'], [0.72, '#d08aac'], [0.86, '#eea6a2'], [1, '#f7c3a2']],
  clouds: { light: '#ffd8b8', mid: '#f2a9a8', shade: '#b886ae', deep: '#8a6aa0' },
  water: [[0, '#e8b49c'], [0.04, '#b893b0'], [0.16, '#7a74aa'], [0.4, '#4d5592'], [0.7, '#33407a'], [1, '#222c5e']],
  waterHi: ['#ffd9a8', '#fff3dc'],
  ink: INK, lit: null,
};

// ======================= Kız Kulesi + adacık (172×132) =======================
// Kule gövdesi 24 px. Gerçek yükseklik için güvenilir yazılı kaynak bulunamadı; oranlar 2023 fotoğraflarından.
function landmark() {
  const W = 172, H = 132, c = new Canvas(W, H);
  const stone = ['#8b7a72', '#a8927f', '#c4a98d', '#dbbf98', '#ecd2a8', '#f6e2bc']; // gün batımında sıcak taş
  const white = ['#9a88a6', '#c7b6c0', '#ecdcd2', '#fff1e2'];
  const lead = ['#3d3a4c', '#524d60', '#6a6274', '#857a88', '#a6969e'];
  const pick = (r, t) => r[Math.max(0, Math.min(r.length - 1, Math.floor(t * r.length)))];
  const masonry = (x, y, seed, k0) => {
    const sx = Math.floor((x + (Math.floor(y / 2) % 2) * 1.5) / 3), sy = Math.floor(y / 2);
    let k = k0 + (hash(sx, sy, seed) - 0.5) * 0.28;
    if (y % 2 === 0 && hash(x, y, seed + 1) < 0.35) k -= 0.13;
    return k;
  };
  const water = H - 6, deck = water - 6; // su çizgisi; rıhtım döşemesi

  // --- kayalık taban, sivri kayalık uç (solda) ---
  for (let x = 2; x < W - 2; x++) for (let y = water - 2; y < H; y++) c.set(x, y, hash(x, y, 2) < 0.5 ? '#3c3446' : '#4d4256');
  c.poly([[0, water + 2], [34, water - 5], [38, water + 2]], '#4a3f55');
  for (let x = 6; x < 34; x += 3) c.set(x, water - 2 - Math.floor(x / 12), '#6d5f78');
  // kırmızı-beyaz fener işareti: konik beyaz gövde, kırmızı bant, üstte fener
  const bx = 18;
  for (let y = 0; y < 18; y++) { const hw = 2 + Math.floor(y / 6); for (let x = bx - hw; x <= bx + hw; x++) c.set(x, water - 22 + y, y >= 8 && y <= 10 ? '#c8463c' : x > bx ? white[1] : white[3]); }
  c.rect(bx - 2, water - 25, 5, 3, white[2]); c.hline(bx - 2, bx + 2, water - 26, '#5b5568'); c.set(bx, water - 27, '#5b5568');
  // platform: beyaz taş kaplama, sağda korkuluklu rıhtım ve iskele merdiveni
  c.rect(34, deck, W - 38, 6, white[2]); c.hline(34, W - 5, deck, white[3]); c.hline(34, W - 5, water - 1, '#7e6f88');
  for (let x = 120; x < W - 5; x += 3) c.vline(x, deck - 5, deck - 1, '#5b5568');
  c.hline(120, W - 5, deck - 5, '#7a7286');
  for (let i = 0; i < 6; i++) c.hline(110 + i, 118, deck - 6 + i, i % 2 ? '#5e5a6a' : '#3c3a48');

  // --- mazgallı taş burç (kulenin solunda), kemerli açıklıklar ---
  const bL = 40, bR = 74, bTop = deck - 26;
  for (let y = bTop; y < deck; y++) for (let x = bL; x < bR; x++) c.set(x, y, pick(stone, masonry(x, y, 5, 0.62) - (x < bL + 2 ? 0.3 : 0)));
  for (let x = bL; x < bR; x += 5) for (let y = bTop - 4; y < bTop; y++) for (let i = 0; i < 3; i++) c.set(x + i, y, pick(stone, 0.72 - (i === 0 ? 0.25 : 0)));
  for (const ax of [47, 59]) { c.rect(ax, deck - 9, 4, 9, '#3a2f3e'); c.hline(ax + 1, ax + 2, deck - 10, '#3a2f3e'); }

  // --- kule gövdesi: kaba yontma taş, sağ yan yüz gölgede ---
  const tx = 74, tw = 24, bodyTop = deck - 40;
  for (let y = bodyTop; y < deck; y++) for (let x = tx; x < tx + tw; x++) {
    const nx = (x - tx) / tw;
    c.set(x, y, pick(stone, masonry(x, y, 9, 0.7) - (nx > 0.72 ? 0.32 : 0)));
  }
  c.vline(tx + 17, bodyTop, deck - 1, pick(stone, 0.35)); // köşe ayrıtı
  c.rect(tx + 7, deck - 11, 4, 11, '#3a2f3e'); c.hline(tx + 8, tx + 9, deck - 12, '#3a2f3e'); // kapı
  for (const [wx, wy] of [[tx + 4, bodyTop + 7], [tx + 12, bodyTop + 7], [tx + 8, bodyTop + 19]]) {
    c.rect(wx, wy, 2, 4, '#2e2a3a'); c.hline(wx, wx + 1, wy - 1, pick(stone, 0.4));
  }

  // --- beyaz konsollu galeri: aşağı doğru daralan çok köşeli çıkma ---
  const gTop = bodyTop - 9;
  for (let i = 0; i < 9; i++) {
    const y = gTop + i, ext = 6 - Math.round((i / 8) * 6);
    for (let x = tx - ext; x < tx + tw + ext; x++) {
      const nx = (x - (tx - ext)) / (tw + ext * 2);
      c.set(x, y, white[nx < 0.16 ? 1 : nx > 0.84 ? 1 : nx > 0.64 ? 2 : 3]);
    }
    c.set(tx - ext, y, white[0]);
  }
  // balkon döşemesi ve ferforje korkuluk
  c.hline(tx - 7, tx + tw + 6, gTop - 1, white[2]);
  c.hline(tx - 7, tx + tw + 6, gTop - 5, INK);
  for (let x = tx - 7; x <= tx + tw + 6; x++) { if (x % 2) c.set(x, gTop - 4, INK); if (x % 3 === 0) c.set(x, gTop - 3, INK); if (x % 2 === 0) c.set(x, gTop - 2, INK); }

  // --- sekizgen beyaz köşk: uzun pencereler (kahverengi doğrama), ince koyu saçak ---
  const kTop = gTop - 17, kL = tx + 1, kR = tx + tw - 1;
  for (let y = kTop; y < gTop - 5; y++) for (let x = kL; x < kR; x++) { const nx = (x - kL) / (kR - kL); c.set(x, y, white[nx < 0.14 ? 1 : nx > 0.76 ? 2 : 3]); }
  for (const wx of [kL + 3, kL + 9, kL + 15]) { c.rect(wx, kTop + 3, 3, 8, '#3c3550'); c.vline(wx - 1, kTop + 3, kTop + 10, '#8a5a3a'); c.set(wx + 1, kTop + 4, '#ffd28a'); }
  c.hline(kL - 2, kR + 1, kTop - 1, lead[1]); c.hline(kL - 1, kR, kTop, white[1]);

  // --- kurşun kubbe: şişkin profil, yuvarlak çatı penceresi ---
  const dBase = kTop - 1, dH = 15, cx = tx + tw / 2;
  for (let i = 0; i < dH; i++) {
    const t = i / (dH - 1);
    const hw = Math.max(1, Math.round(12.5 * Math.sin((1 - t) * Math.PI * 0.6 + 0.3) - t * 4));
    const y = dBase - 1 - i;
    for (let x = Math.round(cx - hw); x < Math.round(cx + hw); x++) {
      const nx = (x - (cx - hw)) / (hw * 2);
      c.set(x, y, pick(lead, 0.9 - nx * 0.8 + (i % 4 === 0 ? -0.06 : 0)));
    }
  }
  c.rect(cx - 2, dBase - 8, 4, 4, white[2]); c.rect(cx - 1, dBase - 7, 2, 2, '#3c3550');
  // --- fener (korkuluklu küçük tepe) ve bayrak direği ---
  const lY = dBase - dH;
  c.rect(cx - 4, lY - 4, 8, 4, lead[2]); c.hline(cx - 5, cx + 4, lY - 5, INK);
  for (let x = cx - 5; x <= cx + 4; x += 2) c.set(x, lY - 4, INK);
  c.rect(cx - 3, lY - 8, 6, 3, lead[1]); c.hline(cx - 3, cx + 2, lY - 9, lead[3]);
  c.vline(cx - 1, lY - 44, lY - 10, '#4a4656'); c.set(cx - 1, lY - 45, '#e8c050');
  // Türk bayrağı: kırmızı zemin, beyaz ay-yıldız
  const fx = cx, fy = lY - 43;
  c.rect(fx, fy, 10, 7, '#d42a2a'); c.rect(fx + 2, fy + 2, 3, 3, '#ffffff'); c.rect(fx + 3, fy + 2, 2, 3, '#d42a2a'); c.set(fx + 6, fy + 3, '#ffffff');
  c.hline(fx + 1, fx + 9, fy + 7, '#b01f22');

  // --- kiremit çatılı küçük beyaz yapı (kulenin sağında) ---
  const hx = 100, hw2 = 20, hTop = deck - 14;
  c.rect(hx, hTop, hw2, 14, white[3]); c.vline(hx + hw2 - 1, hTop, deck - 1, white[1]);
  c.rect(hx + 5, hTop + 4, 3, 6, '#3c3550'); c.rect(hx + 12, hTop + 4, 3, 6, '#3c3550');
  for (let i = 0; i < 5; i++) c.hline(hx - 2 + i, hx + hw2 + 1 - i, hTop - 1 - i, i % 2 ? '#b8553c' : '#d06a48');

  c.outline(mix(INK, '#6a5a80', 0.3));
  return c;
}

// ======================= Üsküdar evi (gün batımında aydınlık) =======================
const WALLS = ['#f2e4d4', '#ead2b8', '#f4dccb', '#e7b9a2', '#f1d39e', '#e2c4b8', '#f6eee4', '#d9b7a8', '#e9cfa6'];
function house(c, x, base, w, h, r, { haze = 0, fh = 7 } = {}) {
  const hz = col => mix(col, HAZE, haze);
  const wall = WALLS[Math.floor(r() * WALLS.length)];
  const lit = mix(wall, SUNLIT, 0.28), side = mix(wall, SHADOW, 0.45);
  const top = base - h;
  c.rect(x, top, w, h, hz(lit));
  const sw = Math.max(1, Math.round(w * 0.14));
  c.rect(x + w - sw, top, sw, h, hz(side)); // güneş batıda (kameranın arkasında): sağa bakan yan yüz gölgede
  const cols = Math.max(1, Math.floor((w - sw - 2) / 4)), gx = (w - sw - cols * 2) / (cols + 1);
  for (let fy = top + 3; fy + 3 < base - 1; fy += fh) for (let k = 0; k < cols; k++) {
    const wx = Math.round(x + gx + k * (2 + gx)), n = hash(wx, fy, 13);
    // pencerelerin bir kısmı batan güneşi yansıtıp altın rengi parlar
    const col = n < 0.22 ? '#ffd27a' : n < 0.3 ? '#fff0c8' : '#5a4e6e';
    c.rect(wx, fy, 2, Math.max(2, fh - 4), hz(col));
  }
  // kiremit kırma çatı (Üsküdar yamacında baskın), bazen düz çatı
  if (r() < 0.78) {
    const tiles = ['#a8463a', '#c25a42', '#d87250'];
    let y = top - 1;
    for (let inset = 0; inset < w / 2 && y > top - 5; inset += 2, y--) for (let i = x + inset - 1; i < x + w - inset + 1; i++) c.set(i, y, hz(tiles[i > x + w * 0.6 ? 0 : (i + y) % 4 === 0 ? 2 : 1]));
  } else {
    c.hline(x, x + w - 1, top - 1, hz(mix(wall, SHADOW, 0.2)));
    if (r() < 0.5) { const tx = x + 1 + Math.floor(r() * (w - 4)); c.rect(tx, top - 3, 3, 2, hz('#b7a9b4')); }
  }
}

// ======================= orta plan: Salacak–Üsküdar yamacı (400×84) =======================
// Fotoğraflardaki gibi: 3–6 katlı, geniş, çoğu kiremit kırma çatılı evler; aralarda ağaç kümeleri.
function midground() {
  const W = 400, H = 84, c = new Canvas(W, H);
  const treeD = '#46505a', treeL = '#7c8a5c', treeSun = '#c2ac62';
  const trees = (o, x, base, n, r) => {
    for (let i = 0; i < n; i++) {
      const rr = 3 + Math.floor(r() * 3), xx = x + i * 4 + Math.floor(r() * 2);
      c.ellipse(o + xx, base - rr, rr, rr + 1, (nx, ny) => (ny < -0.45 ? treeSun : nx > 0.35 ? treeD : treeL));
    }
  };
  c.wrap(o => {
    // arka sıra: yamacın üstü, puslu
    let r = rng(401), x = 0;
    while (x < W) {
      if (r() < 0.25) { trees(o, x, H - 40, 3, r); x += 12; continue; }
      const w = 12 + Math.floor(r() * 12), h = 12 + Math.floor(r() * 10) + Math.round(5 * Math.sin((x / W) * Math.PI * 2));
      house(c, o + x, H - 38, w, h, r, { haze: 0.4, fh: 5 }); x += w;
    }
    // orta sıra
    r = rng(402); x = -3;
    while (x < W) {
      if (r() < 0.2) { trees(o, x, H - 22, 3, r); x += 12; continue; }
      const w = 14 + Math.floor(r() * 12), h = 16 + Math.floor(r() * 10);
      house(c, o + x, H - 20, w, h, r, { haze: 0.2, fh: 6 }); x += w;
    }
    // ön sıra (sahile yakın)
    r = rng(403); x = -6;
    while (x < W) { const w = 16 + Math.floor(r() * 14), h = 14 + Math.floor(r() * 10); house(c, o + x, H - 8, w, h, r, { haze: 0.05, fh: 7 }); x += w; }
    // sahil yolu ağaç dizisi
    r = rng(404);
    for (let x2 = 0; x2 < W; x2 += 6) trees(o, x2, H - 5, 1, r);
    c.rect(o, H - 5, W, 5, '#6c6280'); // sahil yolu (gölgede)
  });
  return c;
}

// ======================= kıyı: Salacak rıhtımı (400×28, satır 12 = ufuk) =======================
function waterfront() {
  const W = 400, c = new Canvas(W, 28), Y = 12;
  c.wrap(o => {
    c.rect(o, Y - 6, W, 6, '#d9b8a4'); // taş rıhtım duvarı, gün batımında sıcak
    for (let x = 0; x < W; x += 7) c.vline(o + x, Y - 6, Y - 1, '#b8968e');
    c.hline(o, o + W - 1, Y - 6, '#f6d8b8');
    c.hline(o, o + W - 1, Y - 9, '#4a4260'); // demir korkuluk
    for (let x = 0; x < W; x += 3) c.vline(o + x, Y - 8, Y - 7, '#4a4260');
    for (let x = 16; x < W; x += 44) { c.vline(o + x, Y - 15, Y - 10, '#3e3850'); c.rect(o + x - 1, Y - 16, 3, 1, '#fff0c8'); } // sahil lambaları
    c.rect(o, Y, W, 1, '#3c3450');
    for (let y = Y + 1; y < 28; y++) for (let x = 0; x < W; x++) if (hash(x, y, 43) < 0.1 - (y - Y) * 0.005) c.set(o + x, y, '#ffcf9a', 150); // altın yansıma kırıntıları
  });
  return c;
}

// ======================= uzak plan: tepedeki koru ve yamacın üst evleri (400×150) =======================
function distant() {
  const W = 400, H = 150, c = new Canvas(W, H);
  c.wrap(o => {
    // ağaç taçlarından oluşan koru: yuvarlak taç kümeleri, gün batımı ışığı tepelerde
    const canopy = ['#4f4f74', '#5c5b80', '#6a688c', '#7f7896', '#b58f9c'];
    const ridge = x => 96 + Math.round(16 * Math.sin((x / W) * Math.PI * 2 + 0.7) + 6 * Math.sin((x / W) * Math.PI * 8));
    for (let x = 0; x < W; x++) for (let y = H - ridge(x) + 4; y < H; y++) c.set(o + x, y, canopy[hash(x, y, 47) < 0.4 ? 1 : 0]);
    const rt = rng(406);
    for (let k = 0; k < 260; k++) {
      const x = Math.floor(rt() * W), top = H - ridge(x), y = top + 3 + Math.floor(Math.pow(rt(), 1.6) * 70), rr = 3 + Math.floor(rt() * 3);
      c.ellipse(o + x, y, rr, rr - 1, (nx, ny) => (ny < -0.55 && y < top + 12 ? canopy[4] : ny < -0.3 ? canopy[3] : nx > 0.4 ? canopy[0] : canopy[2]));
    }
    // yamacın üst kısmında seyrek, puslu evler (kiremit çatı izi)
    const r = rng(405);
    for (let k = 0; k < 26; k++) {
      const x = Math.floor(r() * W), y = H - 30 - Math.floor(r() * 40), w = 4 + Math.floor(r() * 4);
      c.rect(o + x, y, w, 3, '#c6a2b0'); c.hline(o + x, o + x + w - 1, y - 1, '#a87888');
    }
  });
  return c;
}

function sun() { return new Canvas(96, 96); } // güneş kameranın arkasında: gökte disk yok

function build(outDir) {
  const d = `${outDir}/backgrounds/kizkulesi`;
  return [
    landmark().save(`${outDir}/landmarks/kiz_kulesi.png`),
    BG.sky(Z).save(`${d}/sky.png`),
    sun().save(`${d}/sun.png`),
    BG.clouds(Z).save(`${d}/clouds.png`),
    distant().save(`${d}/distant.png`),
    midground().save(`${d}/midground.png`),
    waterfront().save(`${d}/waterfront.png`),
    BG.water('kizkulesi', Z).save(`${d}/water.png`),
    BG.waterHi('kizkulesi', Z).save(`${d}/water_hi.png`),
    G.ferry({ white: '#fbe8d6', whiteS: '#c9a8b0' }).save(`${d}/ferry.png`),
  ];
}

module.exports = { build, landmark, midground, waterfront, distant, Z };

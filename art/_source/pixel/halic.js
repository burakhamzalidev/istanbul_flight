// Haliç bölgesi: gerçek referanslara dayalı yeniden çizim (docs/11).
//
// Kamera: Haliç'in kuzey (Galata–Azapkapı) kıyısından güneybatıya, suyun karşısındaki Üçüncü Tepe'ye bakış.
// Önden arkaya: Haliç kıyısındaki park şeridi, sahil yolu ve bağlı gezi tekneleri → Unkapanı–Küçükpazar
// yamacındaki betonarme apartmanlar ve ağaçlar → tepede Süleymaniye Camii (ana kubbe, yarım kubbeler, kademeli
// küçük kubbeler, payanda kuleleri, iki katlı revaklar; avlunun köşelerinde dört minare) ve sağdaki koru →
// arkada puslu tarihi yarımada sırtı.
// Saat: şafak. Güneş doğuda, kameranın sol arkasında; caminin kuzeydoğu cephesi pembe-altın ışık alır,
// güneybatı göğü pastel. Güneş diski bu açıdan görünmez.
//
// Ölçü (Wikipedia): ana kubbe ≈ 53 m yükseklik, ≈ 26,5 m çap; uzun minareler 76 m (külahla), 3 şerefe;
// kısa minareler 2 şerefe; harim ≈ 58,5 × 57,5 m. Ölçek ≈ 1 m/px.
// Kaynaklar ve lisanslar: docs/11_halic_gercek_referans.md
'use strict';
const { Canvas, mix, rng } = require('./lib');
const BG = require('./backgrounds');
const { ZONES } = require('./zones');
const G = require('./galata');

const hash = (x, y, s = 0) => { let h = (x * 374761393 + y * 668265263 + s * 2147483647) >>> 0; h = ((h ^ (h >>> 13)) * 1274126177) >>> 0; return ((h ^ (h >>> 16)) >>> 0) / 4294967296; };

const DAWN = '#ffd2b8'; // şafak ışığı
const SHADOW = '#5c5a86';
const HAZE = '#c3b4cc';
const INK = '#2c2838';

const Z = {
  ...ZONES.halic,
  // güneybatı göğü (güneşin karşısı): üstte pastel mavi, ufka doğru pembe-şeftali
  sky: [[0, '#4d6aa6'], [0.2, '#6680b4'], [0.42, '#8e93c0'], [0.6, '#b4a2c6'], [0.76, '#d9b0c2'], [0.9, '#f0c4bc'], [1, '#f8d8c4']],
  clouds: { light: '#ffe2d0', mid: '#f0bcbc', shade: '#ab98bc', deep: '#857ca8' },
  water: [[0, '#e6c6c4'], [0.05, '#a9a4c2'], [0.2, '#7c86b2'], [0.45, '#5a6a9c'], [0.75, '#3f5082'], [1, '#2c3a68']],
  waterHi: ['#ffe0cc', '#fff4ea'],
  ink: INK, lit: null,
};

const pick = (r, t) => r[Math.max(0, Math.min(r.length - 1, Math.floor(t * r.length)))];
const STONE = ['#7f7a8c', '#9c95a4', '#b9afb6', '#d4c6c4', '#ead8cf', '#f6e6da'];
const LEAD = ['#454b64', '#5a6180', '#727a98', '#8f96b0', '#b2b5c8'];
const TREE = ['#2f4440', '#3e584c', '#567054', '#8c9468', '#d8b49a'];

/** Kurşun kubbe: (cx, by) taban merkezi, r yarıçap, h yükseklik. Işık soldan (doğu). */
function dome(c, cx, by, r, h, { finial = false } = {}) {
  for (let y = 0; y < h; y++) {
    const t = y / h, hw = r * Math.sqrt(Math.max(0, 1 - t * t));
    for (let x = Math.round(cx - hw); x < Math.round(cx + hw); x++) {
      const nx = (x + 0.5 - cx) / r;
      let k = 0.62 - nx * 0.45 + (1 - t) * -0.05;
      if (r > 8 && Math.round((x - cx) * 1.0) % 4 === 0 && y < h - 2) k -= 0.08; // kurşun levha çizgileri
      c.set(x, by - y, pick(LEAD, k));
    }
  }
  if (finial) { c.vline(cx, by - h - 4, by - h, '#c9a24a'); c.set(cx - 1, by - h - 4, '#e7c463'); c.set(cx + 1, by - h - 5, '#e7c463'); }
}

/** Minare: ince gövde, şerefeler, kurşun külah. */
function minaret(c, x, base, top, balconies) {
  for (let y = top + 9; y < base; y++) { c.set(x - 1, y, pick(STONE, 0.85)); c.set(x, y, pick(STONE, 0.6)); c.set(x + 1, y, pick(STONE, 0.3)); }
  for (const by of balconies) { c.hline(x - 2, x + 2, by, pick(STONE, 0.75)); c.hline(x - 2, x + 2, by + 1, INK); c.set(x - 2, by - 1, INK); c.set(x + 2, by - 1, INK); }
  for (let i = 0; i < 9; i++) { const y = top + i, hw = i < 3 ? 0 : 1; for (let dx = -hw; dx <= hw; dx++) c.set(x + dx, y, pick(LEAD, dx < 0 ? 0.8 : 0.4)); }
  c.set(x, top - 1, '#c9a24a'); c.set(x, top - 2, '#e7c463');
}

// ======================= Süleymaniye + Üçüncü Tepe'nin sırtı (208×124) =======================
function landmark() {
  const W = 208, H = 124, c = new Canvas(W, H);
  const base = 104; // terasın taban satırı
  const L = 18, R = 92; // harim cephesi (≈ 58 m)

  // külliyenin soldaki küçük kubbeleri (medreseler)
  for (let i = 0; i < 4; i++) { const cx = 4 + i * 5; c.rect(cx - 3, base - 6, 6, 6, pick(STONE, 0.55)); dome(c, cx, base - 6, 3, 3); }

  // harim: alt revak katı, üst pencere katı, kurşun saçaklar
  for (let y = base - 22; y < base; y++) for (let x = L; x < R; x++) c.set(x, y, pick(STONE, 0.75 - (x - L) / (R - L) * 0.3 + (hash(x >> 1, y >> 1, 3) - 0.5) * 0.08));
  for (let x = L + 3; x < R - 3; x += 5) { c.rect(x, base - 8, 3, 7, '#3e3a4e'); c.set(x + 1, base - 9, '#3e3a4e'); } // alt revak kemerleri
  c.hline(L - 2, R + 1, base - 11, pick(LEAD, 0.5)); c.hline(L - 2, R + 1, base - 10, INK); // saçak
  for (let x = L + 4; x < R - 3; x += 4) c.rect(x, base - 18, 2, 4, '#4a4560'); // üst kat pencereleri
  c.hline(L - 2, R + 1, base - 22, pick(LEAD, 0.55)); c.hline(L - 2, R + 1, base - 21, INK);

  // kemer alınlığı (timpan): payandalar arasında içeri çekik büyük kemer, gölgede; içinde pencere sıraları
  const tL = L + 9, tR = R - 9, tTop = base - 44, tBot = base - 22, tcx = (tL + tR) / 2, tr = (tR - tL) / 2;
  const archY = y => tTop + tr * 0.55;
  for (let y = tTop; y < tBot; y++) for (let x = tL; x < tR; x++) {
    const e = ((x + 0.5 - tcx) / tr) ** 2 + ((y - archY(y)) / (tr * 0.55)) ** 2;
    if (y < archY(y) && e > 1) continue;
    const ring = y < archY(y) ? e > 0.72 : (x < tL + 2 || x >= tR - 2);
    c.set(x, y, ring ? pick(STONE, 0.78) : mix(pick(STONE, 0.5), SHADOW, 0.35));
  }
  for (let y = tTop + 9; y < tBot - 2; y += 4) for (let x = tL + 4; x < tR - 3; x += 3) { const e = ((x + 0.5 - tcx) / tr) ** 2 + ((y - archY(y)) / (tr * 0.55)) ** 2; if (y > archY(y) || e < 0.6) c.rect(x, y, 1, 2, '#3c3850'); }
  // payanda kuleleri (köşelerde, küçük kubbeli)
  for (const px of [L, R - 7]) { for (let y = base - 44; y < base - 22; y++) for (let x = px; x < px + 7; x++) c.set(x, y, pick(STONE, x - px < 3 ? 0.8 : 0.45)); dome(c, px + 3.5, base - 44, 4, 4); }
  // kademeli küçük kubbeler ve yarım kubbeler
  for (const [cx, r] of [[L + 10, 5], [R - 10, 5], [L + 20, 6], [R - 20, 6]]) dome(c, cx, base - 40, r, Math.round(r * 0.8));
  dome(c, tcx - 17, base - 44, 11, 9); dome(c, tcx + 17, base - 44, 11, 9); // yarım kubbeler
  // ana kubbe kasnağı: pencere dizisi
  const dcx = (L + R) / 2;
  for (let y = base - 52; y < base - 44; y++) for (let x = dcx - 17; x < dcx + 17; x++) c.set(x, y, pick(STONE, 0.7 - (x - dcx + 17) / 34 * 0.35));
  for (let x = dcx - 15; x < dcx + 15; x += 3) c.rect(x, base - 50, 1, 3, '#4a4560');
  for (const px of [dcx - 18, dcx + 16]) c.rect(px, base - 54, 2, 10, pick(STONE, 0.55)); // kasnak payandaları
  // ana kubbe (≈ 26,5 m çap)
  dome(c, dcx, base - 52, 18, 16, { finial: true });

  // ağaçlar: avlu ve sağdaki koru (minarelerin altını örter), selviler
  const r = rng(501);
  for (let k = 0; k < 140; k++) {
    const x = R + Math.floor(r() * (W - R)), crest = base - 6 - Math.round(16 * Math.sin(((x - R) / (W - R)) * Math.PI) ** 0.5);
    const y = crest + Math.floor(r() * (H - crest)), rr = 3 + Math.floor(r() * 4);
    c.ellipse(x, y, rr, rr, (nx, ny) => (ny < -0.5 ? (nx < 0 ? TREE[4] : TREE[3]) : nx > 0.4 ? TREE[0] : ny < 0 ? TREE[2] : TREE[1]));
  }
  for (let k = 0; k < 60; k++) { const x = R - 6 + Math.floor(r() * (W - R + 6)), y = base + 2 + Math.floor(r() * (H - base)), rr = 3 + Math.floor(r() * 3); c.ellipse(x, y, rr, rr, (nx, ny) => (ny < -0.5 ? TREE[3] : nx > 0.4 ? TREE[0] : TREE[1])); }
  for (const sx of [104, 132, 141, 176]) for (let y = base - 22; y < base; y++) { const hw = y < base - 18 ? 0 : 1; for (let dx = -hw; dx <= hw; dx++) c.set(sx + dx, y, dx < 0 ? TREE[2] : TREE[0]); } // selviler

  // teras alt yapısı (eğimli arazi için yapılmış büyük istinat duvarı) ve altında yamacın üst evleri
  for (let y = base; y < base + 5; y++) for (let x = L - 6; x < R + 4; x++) c.set(x, y, pick(STONE, 0.5 + (hash(x >> 1, y, 61) - 0.5) * 0.1));
  for (let x = L - 4; x < R + 2; x += 6) c.rect(x, base + 1, 3, 4, '#5a5470');
  const rb = rng(502);
  for (let x = 0; x < R + 6;) { const w = 9 + Math.floor(rb() * 8), h = 8 + Math.floor(rb() * 8); block(c, x, H, w, Math.min(h + (H - base - 5), H - base - 3), rb, { haze: 0.3, fh: 5 }); x += w; }

  // minareler: harime bitişik iki uzun (3 şerefe), avlunun uzak köşesinde iki kısa (2 şerefe)
  minaret(c, 98, base - 2, 22, [48, 62, 76]);
  minaret(c, 106, base - 2, 24, [50, 64, 78]);
  minaret(c, 150, base - 8, 40, [62, 76]);
  minaret(c, 158, base - 8, 42, [64, 78]);
  return c;
}

// ======================= yamaç binaları (Unkapanı–Küçükpazar, şafak ışığında) =======================
const WALLS = ['#d6cbc6', '#e2d4ca', '#c9bebe', '#e8cdbc', '#d5b0a4', '#c6c4ca', '#ddd0bc', '#efe2d6'];
function block(c, x, base, w, h, r, { haze = 0, fh = 6 } = {}) {
  const hz = col => mix(col, HAZE, haze);
  const wall = WALLS[Math.floor(r() * WALLS.length)];
  const lit = mix(wall, DAWN, 0.22), side = mix(wall, SHADOW, 0.45), top = base - h;
  c.rect(x, top, w, h, hz(lit));
  const sw = Math.max(1, Math.round(w * 0.12));
  c.rect(x + w - sw, top, sw, h, hz(side)); // güneş sol arkada: sağa bakan yüz gölgede
  const cols = Math.max(1, Math.floor((w - sw - 2) / 4)), gx = (w - sw - cols * 2) / (cols + 1);
  for (let fy = top + 3; fy + 2 < base - 1; fy += fh) for (let k = 0; k < cols; k++) {
    const wx = Math.round(x + gx + k * (2 + gx)), n = hash(wx, fy, 23);
    c.rect(wx, fy, 2, Math.max(2, fh - 3), hz(n < 0.08 ? '#ffe0b0' : '#5a5470'));
  }
  c.hline(x, x + w - 1, top, hz(mix(wall, '#ffffff', 0.25)));
  if (r() < 0.3) { // kiremit çatı (yamaçta azınlık)
    let y = top - 1;
    for (let inset = 0; inset < w / 2 && y > top - 4; inset += 2, y--) for (let i = x + inset; i < x + w - inset; i++) c.set(i, y, hz(i > x + w * 0.6 ? '#9a4a3c' : '#c0624a'));
  } else if (r() < 0.5) { const tx = x + 1 + Math.floor(r() * Math.max(1, w - 4)); c.rect(tx, top - 2, 3, 2, hz('#a9a4b0')); }
}

// ======================= orta plan (400×96) =======================
function midground() {
  const W = 400, H = 96, c = new Canvas(W, H);
  const trees = (o, x, baseY, n, r) => { for (let i = 0; i < n; i++) { const rr = 3 + Math.floor(r() * 3), xx = x + i * 4; c.ellipse(o + xx, baseY - rr, rr, rr + 1, (nx, ny) => (ny < -0.45 ? TREE[4] : nx > 0.35 ? TREE[0] : TREE[2])); } };
  c.wrap(o => {
    let r = rng(511), x = 0;
    while (x < W) { if (r() < 0.3) { trees(o, x, H - 44, 3, r); x += 12; continue; } const w = 10 + Math.floor(r() * 12), h = 8 + Math.floor(r() * 12); block(c, o + x, H - 40, w, h, r, { haze: 0.4, fh: 5 }); x += w; }
    r = rng(512); x = -4;
    while (x < W) { if (r() < 0.22) { trees(o, x, H - 22, 4, r); x += 16; continue; } const w = 14 + Math.floor(r() * 14), h = 16 + Math.floor(r() * 12); block(c, o + x, H - 20, w, h, r, { haze: 0.2, fh: 6 }); x += w; }
    r = rng(513); x = -6;
    while (x < W) { const w = 16 + Math.floor(r() * 18), h = 12 + Math.floor(r() * 10); block(c, o + x, H, w, h, r, { haze: 0.05, fh: 7 }); x += w; }
  });
  return c;
}

// ======================= kıyı: Haliç parkı, sahil yolu, bağlı gezi tekneleri (400×28) =======================
function waterfront() {
  const W = 400, c = new Canvas(W, 28), Y = 12;
  c.wrap(o => {
    c.rect(o, Y - 5, W, 3, '#7e8c66'); c.hline(o, o + W - 1, Y - 5, '#a8aa7a'); // park çimi
    c.rect(o, Y - 2, W, 2, '#8a8698'); // sahil yolu
    c.hline(o, o + W - 1, Y, '#4e4a5e'); // rıhtım kenarı
    const r = rng(514);
    for (let x = 4; x < W; x += 9 + Math.floor(r() * 8)) { const rr = 3 + Math.floor(r() * 2); c.ellipse(o + x, Y - 5 - rr, rr, rr, (nx, ny) => (ny < -0.4 ? TREE[3] : nx > 0.3 ? TREE[0] : TREE[2])); }
    // bağlı gezi tekneleri: iki katlı beyaz üst yapı, koyu gövde
    for (let x = 30; x < W; x += 70 + Math.floor(r() * 30)) {
      c.rect(o + x, Y + 1, 20, 3, '#2f3446'); c.rect(o + x + 1, Y - 3, 18, 4, '#f2ece8'); c.rect(o + x + 3, Y - 6, 13, 3, '#e6dede');
      for (let i = x + 2; i < x + 18; i += 2) c.set(o + i, Y - 2, '#5a6278');
      c.hline(o + x + 3, o + x + 15, Y - 7, '#c8473a');
    }
    for (let y = Y + 4; y < 28; y++) for (let x = 0; x < W; x++) if (hash(x, y, 53) < 0.08 - (y - Y) * 0.004) c.set(o + x, y, '#ffe6d6', 150);
  });
  return c;
}

// ======================= uzak plan: puslu tarihi yarımada sırtı (400×140) =======================
function distant() {
  const W = 400, H = 140, c = new Canvas(W, H);
  c.wrap(o => {
    for (let x = 0; x < W; x++) {
      const h = 70 + Math.round(10 * Math.sin((x / W) * Math.PI * 2 + 2) + 4 * Math.sin((x / W) * Math.PI * 10));
      for (let y = H - h; y < H; y++) c.set(o + x, y, y < H - h + 2 ? '#d8bcc8' : hash(x, y, 57) < 0.25 ? '#a698b8' : '#9c8fb2');
    }
    const r = rng(515);
    for (let k = 0; k < 40; k++) { const x = Math.floor(r() * W), w = 4 + Math.floor(r() * 6), y = H - 72 + Math.floor(r() * 30); c.rect(o + x, y, w, 4, '#b4a6c4'); c.hline(o + x, o + x + w - 1, y, '#c8b8d0'); }
  });
  return c;
}

function sun() { return new Canvas(96, 96); } // güneş doğuda, kameranın arkasında

function build(outDir) {
  const d = `${outDir}/backgrounds/halic`;
  return [
    landmark().save(`${outDir}/landmarks/suleymaniye.png`),
    BG.sky(Z).save(`${d}/sky.png`),
    sun().save(`${d}/sun.png`),
    BG.clouds(Z).save(`${d}/clouds.png`),
    distant().save(`${d}/distant.png`),
    midground().save(`${d}/midground.png`),
    waterfront().save(`${d}/waterfront.png`),
    BG.water('halic', Z).save(`${d}/water.png`),
    BG.waterHi('halic', Z).save(`${d}/water_hi.png`),
    G.ferry({ white: '#fbeee8', whiteS: '#c4b6c4' }).save(`${d}/ferry.png`),
  ];
}

module.exports = { build, landmark, midground, waterfront, distant, Z };

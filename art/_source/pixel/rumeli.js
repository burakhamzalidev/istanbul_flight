// Rumeli Hisarı bölgesi: gerçek referanslara dayalı yeniden çizim (docs/13).
//
// Kamera: Boğaz'dan (vapurdan), kalenin doğusundan batıya, cepheden bakış.
// Soldan sağa (güneyden kuzeye): kıyıdaki küçük kule → yamaca tırmanan sur → tepede Zağanos Paşa Kulesi (güney) →
// aşağı inen sur → kıyıda on iki köşeli Halil Paşa Kulesi (orta) → orta yamaçta gözetleme kuleli uzun sur →
// en yüksekte Sarıca Paşa Kulesi (kuzey). Kıyıda alçak deniz suru ve sahil yolu, içeride ağaçlar, sırtta evler.
// Saat: gece; surlar projektörle aydınlatılmış.
//
// Ölçü (Wikipedia): Sarıca Paşa silindir, 28 m yükseklik, 23,30 m çap; Halil Paşa on iki köşeli prizma, 22 m,
// 23,30 m; Zağanos Paşa silindir, 21 m, 26,70 m. Kale K–G 250 m. Konumlar Jorge Láscar'ın fotoğrafından
// (CC BY 2.0) ölçüldü: ölçek ≈ 1,4 px/m. Kaynaklar: docs/13_rumeli_gercek_referans.md
'use strict';
const { Canvas, mix, rng } = require('./lib');
const G = require('./galata');

const hash = (x, y, s = 0) => { let h = (x * 374761393 + y * 668265263 + s * 2147483647) >>> 0; h = ((h ^ (h >>> 13)) * 1274126177) >>> 0; return ((h ^ (h >>> 16)) >>> 0) / 4294967296; };
const pick = (r, t) => r[Math.max(0, Math.min(r.length - 1, Math.floor(t * r.length)))];

const STONE = ['#3e2c26', '#5c3e2e', '#7c5638', '#a3713f', '#cf9450', '#efbb6c']; // projektör ışığında taş
const TREE = ['#0b1414', '#10201e', '#173029', '#22423a', '#36594a'];
const SLIT = '#1a0e0a';

function landmark() {
  const W = 380, H = 132, c = new Canvas(W, H);
  const water = H - 4; // su çizgisi
  const Y = h => water - h; // "sudan yükseklik" → satır

  // --- sırt çizgisi ve yamaç (ağaçlar) ---
  // uçlarda yamaç kıyıya iner (simge kenarında kesik görünmesin)
  const crestPts = [[0, 6], [20, 40], [44, 70], [80, 95], [140, 100], [200, 100], [260, 102], [330, 108], [352, 104], [380, 8]];
  const crest = x => { for (let i = 1; i < crestPts.length; i++) { const [x0, h0] = crestPts[i - 1], [x1, h1] = crestPts[i]; if (x <= x1) { const t = (x - x0) / (x1 - x0); return h0 + (h1 - h0) * (t * t * (3 - 2 * t)); } } return 110; };
  for (let x = 0; x < W; x++) for (let y = Y(crest(x)); y < water; y++) c.set(x, y, TREE[hash(x, y, 91) < 0.35 ? 1 : 0]);
  // sırttaki evler (Rumelihisarı mahallesi): kırmızı/beyaz çatılar, yanan pencereler
  const rh = rng(901);
  for (let k = 0; k < 18; k++) {
    const x = 120 + Math.floor(rh() * 220), top = Y(crest(x)) - 2 - Math.floor(rh() * 4), w = 5 + Math.floor(rh() * 6);
    c.rect(x, top, w, 4, '#5a4a5e'); c.hline(x - 1, x + w, top - 1, rh() < 0.6 ? '#7a3a34' : '#8a8494');
    if (rh() < 0.7) c.set(x + 1, top + 1, '#ffd27a'); if (rh() < 0.4) c.set(x + w - 2, top + 1, '#ffe8b0');
  }
  // ağaç taçları (ay ışığında kenar)
  for (let k = 0; k < 420; k++) {
    const x = Math.floor(rh() * W), top = Y(crest(x)), y = top + Math.floor(rh() * (water - top)), r = 2 + Math.floor(rh() * 4);
    c.ellipse(x, y, r, r, (nx, ny) => (ny < -0.55 ? TREE[3] : nx > 0.4 ? TREE[0] : TREE[2]));
  }

  // --- yardımcılar: taş yüzey, mazgal dişleri, mazgal pencereleri ---
  const stoneAt = (x, y, top, bot, k0 = 0) => { const t = (y - top) / Math.max(1, bot - top); return pick(STONE, 0.25 + t * 0.65 + k0 + (hash(x >> 1, y >> 1, 93) - 0.5) * 0.18); }; // alttan aydınlatma
  const merlons = (x0, x1, top) => { for (let x = x0; x <= x1; x++) if (Math.floor((x - x0) / 2) % 2 === 0) { c.set(x, top - 1, STONE[3]); c.set(x, top - 2, STONE[3]); } };
  // sur: (xa,ha) → (xb,hb) boyunca 7 px yüksek, mazgallı üst kenar
  const wall = (xa, ha, xb, hb) => {
    for (let x = Math.min(xa, xb); x <= Math.max(xa, xb); x++) {
      const t = (x - xa) / (xb - xa || 1), top = Y(ha + (hb - ha) * t);
      for (let y = top; y < top + 7; y++) c.set(x, y, stoneAt(x, y, top, top + 7, -0.05));
      if (Math.floor(x / 2) % 2 === 0) { c.set(x, top - 1, STONE[3]); c.set(x, top - 2, STONE[3]); }
      if (x % 13 === 0) c.set(x, top + 3, SLIT);
    }
  };
  // silindirik kule: merkez x, taban ve tepe yüksekliği, genişlik
  const roundTower = (cx, hBase, hTop, w) => {
    const top = Y(hTop), bot = Y(hBase) + 6;
    for (let y = top; y < bot; y++) for (let x = Math.round(cx - w / 2); x < Math.round(cx + w / 2); x++) {
      const nx = (x + 0.5 - cx) / (w / 2);
      // silindir gölgesi: ışık önden-soldan; kenarlara doğru belirgin kararma
      const k = 0.08 - nx * 0.12 - nx * nx * 0.42;
      c.set(x, y, Math.abs(nx) > 0.88 ? mix(stoneAt(x, y, top, bot, k), '#140f14', 0.45) : stoneAt(x, y, top, bot, k));
    }
    c.hline(Math.round(cx - w / 2) - 1, Math.round(cx + w / 2), top, STONE[4]); c.hline(Math.round(cx - w / 2), Math.round(cx + w / 2) - 1, top + 2, STONE[1]); // taç silmesi
    merlons(Math.round(cx - w / 2) - 1, Math.round(cx + w / 2), top);
    for (let y = top + 6; y < bot - 6; y += 9) for (const dx of [-w * 0.25, w * 0.15]) c.rect(Math.round(cx + dx), y, 1, 3, SLIT);
  };
  // on iki köşeli prizma (Halil Paşa): dikey yüz bantları
  const polyTower = (cx, hBase, hTop, w) => {
    const top = Y(hTop), bot = Y(hBase);
    const facets = [0.1, 0.24, 0.42, 0.6, 0.76, 0.9];
    for (let y = top; y < bot; y++) for (let x = Math.round(cx - w / 2); x < Math.round(cx + w / 2); x++) {
      const nx = (x + 0.5 - (cx - w / 2)) / w, f = facets.findIndex(v => nx < v);
      const shade = [-0.3, -0.1, 0.05, 0.05, -0.1, -0.25, -0.35][f < 0 ? 6 : f];
      c.set(x, y, stoneAt(x, y, top, bot, shade));
    }
    for (const v of facets) c.vline(Math.round(cx - w / 2 + v * w), top + 2, bot - 1, STONE[1]);
    c.hline(Math.round(cx - w / 2) - 1, Math.round(cx + w / 2), top, STONE[4]);
    merlons(Math.round(cx - w / 2) - 1, Math.round(cx + w / 2), top);
    for (let y = top + 6; y < bot - 4; y += 8) c.rect(Math.round(cx - 3), y, 1, 3, SLIT), c.rect(Math.round(cx + 5), y + 3, 1, 3, SLIT);
  };
  const smallTower = (cx, hBase, hTop, w) => roundTower(cx, hBase, hTop, w);

  // --- surlar (arkadan öne) ---
  wall(97, 72, 124, 66);   // Zağanos'tan sağa
  wall(124, 66, 168, 48);  // Halil'in arkasına inen sur
  wall(168, 48, 293, 56);  // orta yamaçtaki uzun sur
  wall(293, 56, 316, 68);  // Sarıca'ya tırmanan sur
  wall(17, 30, 66, 74);    // kıyıdaki kuleden Zağanos'a tırmanan güney suru
  // --- kuleler ---
  roundTower(81, 71, 101, 30);   // Zağanos Paşa (güney, tepede; 26,7 m çap)
  smallTower(118, 64, 72, 9);    // küçük kule
  smallTower(199, 46, 52, 8);    // gözetleme kuleleri
  smallTower(293, 54, 62, 8);
  roundTower(332, 66, 116, 33);  // Sarıca Paşa (kuzey, en yüksek; 28 m)
  // kıyıdaki alçak deniz suru ve küçük kuleler
  wall(87, 22, 203, 22);
  smallTower(178, 6, 30, 16);
  smallTower(9, 4, 32, 17);      // güneydeki kıyı kulesi
  polyTower(136, 4, 51, 33);     // Halil Paşa (orta, kıyıda; on iki köşe; 23,3 m çap)
  // bayrak (fotoğrafta Halil Paşa Kulesi'nin yanında)
  c.vline(146, Y(64), Y(51) - 3, '#3a3036'); c.rect(147, Y(64), 6, 4, '#d42a2a'); c.set(149, Y(63), '#ffffff');

  // --- sahil yolu ve rıhtım ---
  c.rect(0, water - 3, W, 3, '#4a3e48'); c.hline(0, W - 1, water - 3, '#7a6a70');
  for (let x = 6; x < W; x += 26) { c.vline(x, water - 9, water - 4, '#2a2430'); c.set(x, water - 10, '#ffe2a0'); } // sahil lambaları
  c.rect(0, water, W, 4, '#0a0c14');
  return c;
}

function build(outDir) {
  return [
    landmark().save(`${outDir}/landmarks/rumeli_hisari.png`),
    G.ferry({ white: '#8e8aa4', whiteS: '#5a5878', glass: '#ffd27a' }).save(`${outDir}/backgrounds/rumeli/ferry.png`),
  ];
}

module.exports = { build, landmark };

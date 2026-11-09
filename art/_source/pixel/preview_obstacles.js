// Engel önizlemesi: bölge arka planı üzerinde oyundaki parça yerleşimiyle (ObstaclePiecePlan) engel çiftleri.
// Kullanım: node preview_obstacles.js <pixel_art klasörü> <çıktı.png> [eski atlas klasörü]
// Çıktı dünya/2 çözünürlükte (540×960 / bölge); eski atlas verilirse her bölge için eski | yeni yan yana.
'use strict';
const fs = require('fs');
const { Canvas } = require('./lib');
const { readPNG, scene, LANDMARKS } = require('./preview');
const { ZONES } = require('./zones');

const L = { bodyW: 196, capW: 224, ov: 14, tileH: 192, capH: 128, baseH: 320 };
// atlas yerleşimleri: v2 (tek satır, 1/4) ve v3 (iki satır, 1/2)
const SLOTS = {
  0.25: { bottomBodyA: [0, 0], bottomBodyB: [200, 0], topBodyA: [400, 0], topBodyB: [600, 0], bottomCap: [800, 0], topCap: [1032, 0], bottomBase: [1264, 0] },
  0.5: require('./obstacles').SLOT,
};
const BOUNDARY = { halic: 28, galata: 32, kizkulesi: 12, kopru: 8, rumeli: 12, ortakoy: 32, emirgan: 28, dolmabahce: 20, uskudar: 28 };
const WORLD_H = 1920, OUT = 0.5; // çıktı pikseli = 2 dünya birimi

function drawPiece(dst, atlas, scale, src, dx, dy, dw, dh) { // en yakın komşu
  const sx0 = src.x * scale, sy0 = src.y * scale, sw = src.w * scale, sh = src.h * scale;
  const X0 = Math.round(dx * OUT), Y0 = Math.round(dy * OUT), W = Math.round(dw * OUT), H = Math.round(dh * OUT);
  for (let j = 0; j < H; j++) for (let i = 0; i < W; i++) {
    const p = atlas.get(Math.floor(sx0 + (i + 0.5) / W * sw), Math.floor(sy0 + (j + 0.5) / H * sh));
    if (p && p[3]) dst.set(X0 + i, Y0 + j, [p[0], p[1], p[2]], p[3]);
  }
}

function pair(dst, atlas, scale, kit, x, gapTop, gapBottom, variant) {
  const slot = SLOTS[scale];
  const R = (piece, y = 0, h) => ({ x: slot[piece][0], y: slot[piece][1] + y, w: piece.endsWith('Cap') || piece === 'bottomBase' ? L.capW : L.bodyW, h: h ?? (piece.endsWith('Cap') ? L.capH : piece === 'bottomBase' ? L.baseH : L.tileH) });
  const boundary = BOUNDARY[kit];
  const bodyB = variant % 2 ? 'bottomBodyB' : 'bottomBodyA';
  const capTopB = gapBottom - boundary, bodyStart = capTopB + L.capH - 2, baseTop = WORLD_H - L.baseH;
  const hasBase = baseTop > bodyStart + 40, bodyEnd = hasBase ? baseTop + 2 : WORLD_H;
  for (let y = bodyStart; y < bodyEnd; y += L.tileH) { const h = Math.min(L.tileH, bodyEnd - y); drawPiece(dst, atlas, scale, R(bodyB, 0, h), x, y, L.bodyW, h); }
  if (hasBase) drawPiece(dst, atlas, scale, R('bottomBase'), x - L.ov, baseTop, L.capW, L.baseH);
  drawPiece(dst, atlas, scale, R('bottomCap'), x - L.ov, capTopB, L.capW, L.capH);
  const bodyT = Math.floor(variant / 2) % 2 ? 'topBodyB' : 'topBodyA';
  const capTopT = gapTop - L.capH;
  let idx = 0;
  for (let y = capTopT + 2; y > 0; y -= L.tileH) {
    const h = Math.min(L.tileH, y);
    const piece = kit === 'kizkulesi' && idx++ > 0 ? 'topBodyA' : bodyT;
    drawPiece(dst, atlas, scale, { x: slot[piece][0], y: slot[piece][1] + L.tileH - h, w: L.bodyW, h }, x, y - h, L.bodyW, h);
  }
  drawPiece(dst, atlas, scale, R('topCap'), x - L.ov, capTopT, L.capW, L.capH);
}

function zoneShot(dir, atlasDir, scale, key, { landmark = false } = {}) {
  // landmark: true → bölge simgesi de çizilir (oyun içi görünüme yakın tam sahne)
  const lm = landmark && LANDMARKS[key] && fs.existsSync(`${dir}/landmarks/${LANDMARKS[key][0]}.png`)
    ? [{ layer: LANDMARKS[key][1], img: readPNG(`${dir}/landmarks/${LANDMARKS[key][0]}.png`), x: LANDMARKS[key][2], base: LANDMARKS[key][3] }] : [];
  const bg = scene(dir, key, { extras: lm }).scaled(2); // 270×480 (1 px = 4 birim) → 540×960
  const atlas = readPNG(`${atlasDir}/kit_${key}.png`);
  const gaps = [[620, 960], [440, 770], [780, 1100]];
  [140, 700, 1260].forEach((x, i) => { const [t, b] = gaps[i]; pair(bg, atlas, scale, key, x, t, b, i + (key.length % 2)); });
  // kuş hitbox'ı (çap 68) ölçeği için kırmızı çerçeve: ilk geçidin ortasında
  const cx = Math.round((140 + 98) * OUT), cy = Math.round(790 * OUT), r = Math.round(34 * OUT);
  for (let a = 0; a < 360; a += 2) bg.set(cx + Math.round(r * Math.cos(a * Math.PI / 180)), cy + Math.round(r * Math.sin(a * Math.PI / 180)), '#ff2a2a');
  return bg;
}

module.exports = { zoneShot, pair };

if (require.main === module) {
  const [dir, out, oldDir] = process.argv.slice(2);
  const keys = Object.keys(ZONES);
  const cols = oldDir ? 2 : 1, W = 540, H = 960, G = 8;
  const sheet = new Canvas(keys.length * (cols * W + (cols - 1) * 4) + (keys.length - 1) * G, H);
  keys.forEach((k, i) => {
    const x0 = i * (cols * W + (cols - 1) * 4 + G);
    if (oldDir) sheet.blit(zoneShot(dir, oldDir, 0.25, k), x0, 0);
    sheet.blit(zoneShot(dir, `${dir}/obstacles`, 0.5, k), x0 + (cols - 1) * (W + 4), 0);
  });
  sheet.save(out);
  console.log(out);
}

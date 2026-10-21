// Simit — pixel art sprite sheet. Kare 48×42 px (oyunda 192×168 dünya birimi = 1 px : 4 birim).
// 12 kare (6 sütun × 2 satır): 0–5 kanat döngüsü · 6 süzülme · 7 yükselme · 8 düşüş · 9 çarpışma · 10 göz kırpma · 11 oyun sonu.
// Gövde, kuyruk, simit ve gaga her karede aynı piksellere çizilir; sadece kanat ve yüz değişir → titreme yok.
'use strict';
const { Canvas, mix } = require('./lib');

const FW = 48, FH = 42, PIV = [22, 22];
const C = {
  ink: '#22202c',
  w: ['#ffffff', '#f3f0ea', '#dcd8d6', '#b4b4c8'], // tüy beyazı: ışık → gölge
  g: ['#c3cddb', '#9aaabf', '#76869f', '#55627c'],   // sırt/kanat grisi
  tip: '#1e1e28', mirror: '#ffffff',
  beak: ['#ffe066', '#f5c235', '#d99a1c'], spot: '#d9483a',
  iris: '#f5dc6a', ring: '#d9483a',
  simit: ['#f0b46a', '#c8803a', '#8e5524'], sesame: '#fbf2d0',
  leg: '#f2a93b',
};

function rot([x, y], a) { const c = Math.cos(a), s = Math.sin(a); return [x * c - y * s, x * s + y * c]; }

/** Kanat: omuz (19,20) etrafında döner. angle > 0 → uç yukarı. far: arkadaki kanat (koyu). */
function wing(cv, angleDeg, far = false) {
  const a = (angleDeg * Math.PI) / 180; // pozitif açı: uç yukarı (ekranda y aşağı, kanat geriye bakıyor)
  const S = [19, 20];
  const shape = [[3, -1], [-3, -4], [-10, -5], [-17, -4], [-22, -1], [-17, 2], [-9, 3], [-2, 3]];
  const pts = shape.map(p => { const [x, y] = rot(p, a); return [S[0] + x, S[1] + y]; });
  cv.poly(pts, (x, y) => {
    const [lx, ly] = rot([x + 0.5 - S[0], y + 0.5 - S[1]], -a); // kanadın yerel koordinatı
    if (lx < -15) return lx < -19 && Math.abs(ly + 1) < 1 && !far ? C.mirror : C.tip;
    if (far) return C.g[3];
    if (ly < -2.5) return C.g[0];
    if (ly > 1.5) return C.g[2];
    if (Math.round(lx) % 4 === 0 && ly > 0) return C.g[2]; // tüy çizgileri
    return C.g[1];
  });
}

function body(cv) {
  // kuyruk (arkada, beyaz, siyah uçlu)
  cv.poly([[11, 20], [2, 17], [3, 22], [1, 27], [11, 27]], (x) => (x < 5 ? C.tip : C.w[2]));
  // gövde: yumurta biçimi, üstten ışık; göğüs gölgesi
  cv.ellipse(21, 25, 13.5, 11.5, (nx, ny) => {
    const l = -nx * 0.35 - ny * 0.8;
    return l > 0.55 ? C.w[0] : l > -0.1 ? C.w[1] : l > -0.6 ? C.w[2] : C.w[3];
  });
  // baş (gövdeyle kaynaşık), sırt pelerini
  cv.ellipse(29, 16, 8.5, 8, (nx, ny) => (nx * 0.3 + ny * 0.9 < -0.55 ? C.w[0] : ny > 0.6 ? C.w[2] : C.w[1]));
  cv.poly([[10, 22], [12, 15], [18, 11], [24, 10], [18, 16], [14, 22]], (x, y) => (y < 14 ? C.g[0] : C.g[1]));
  // ayaklar (uçarken toplu)
  cv.rect(15, 35, 4, 2, C.leg); cv.set(14, 36, C.leg);
}

function beak(cv, open = 0) {
  // üst gaga: uzun, kancalı uç
  cv.poly([[35, 15], [44, 16], [46, 18], [44, 19], [35, 19]], (x, y) => (y <= 16 ? C.beak[0] : C.beak[1]));
  cv.set(46, 19, C.beak[2]);
  // alt gaga + kırmızı benek
  const dy = open;
  cv.poly([[35, 19 + dy * 0.3], [43, 19 + dy], [41, 21 + dy], [35, 21]], C.beak[2]);
  cv.set(41, 20 + dy, C.spot); cv.set(41, 21 + dy, C.spot);
}

function simitRing(cv, cx, cy, flat = false) {
  const rx = 6.5, ry = flat ? 2.5 : 4.5;
  for (let y = Math.floor(cy - ry - 2); y <= cy + ry + 2; y++) for (let x = Math.floor(cx - rx - 2); x <= cx + rx + 2; x++) {
    const nx = (x + 0.5 - cx) / rx, ny = (y + 0.5 - cy) / ry, d = nx * nx + ny * ny;
    const inner = (x + 0.5 - cx) ** 2 / (rx * 0.42) ** 2 + (y + 0.5 - cy) ** 2 / (ry * 0.42) ** 2;
    if (d <= 1 && inner > 1) cv.set(x, y, ny < -0.2 ? C.simit[0] : ny > 0.45 ? C.simit[2] : C.simit[1]);
  }
  for (const [dx, dy] of [[-4, -2], [0, -3], [4, -2], [5, 1], [-5, 1]]) cv.set(Math.round(cx + dx), Math.round(cy + dy * (flat ? 0.5 : 1)), C.sesame);
}

function eye(cv, kind) {
  const ex = 32, ey = 13;
  if (kind === 'blink') { cv.hline(ex - 1, ex + 2, ey + 1, C.ink); cv.hline(ex - 2, ex + 2, ey - 2, C.g[2]); return; }
  if (kind === 'crash') { cv.set(ex - 1, ey - 1, C.ink); cv.set(ex + 1, ey + 1, C.ink); cv.set(ex + 1, ey - 1, C.ink); cv.set(ex - 1, ey + 1, C.ink); cv.set(ex, ey, C.ink); return; }
  if (kind === 'dazed') { cv.set(ex, ey, C.ink); cv.set(ex + 1, ey, C.ink); cv.set(ex + 1, ey + 1, C.ink); cv.set(ex - 1, ey + 1, C.ink); cv.set(ex - 1, ey - 1, C.ink); cv.set(ex + 1, ey - 1, C.ink); return; }
  // kırmızı göz halkası + sarı iris + göz bebeği
  cv.rect(ex - 1, ey - 1, 4, 4, C.ring);
  cv.rect(ex, ey, 2, 2, C.iris);
  cv.set(ex + 1, ey, C.ink); cv.set(ex + 1, ey + 1, C.ink);
  if (kind === 'surprised') { cv.rect(ex - 1, ey - 2, 4, 1, C.ring); cv.hline(ex - 2, ex + 2, ey - 4, C.g[2]); return; }
  // ağır göz kapağı (kendinden emin / küstah) + düz kaş
  cv.hline(ex - 1, ex + 2, ey - 1, C.w[1]);
  cv.hline(ex - 1, ex + 2, ey, kind === 'focus' ? C.ring : C.ink);
  if (kind === 'focus') cv.set(ex + 1, ey, C.ink);
  cv.hline(ex - 2, ex + 3, ey - 3, C.g[2]);
}

function frame(spec) {
  const cv = new Canvas(FW, FH);
  if (spec.wing > 25) wing(cv, spec.wing + 12, true); // arka kanat yukarıdayken görünür
  body(cv);
  if (spec.ring === 'chest') simitRing(cv, 27, 28);
  beak(cv, spec.open || 0);
  eye(cv, spec.eye || 'smug');
  wing(cv, spec.wing);
  if (spec.ring === 'head') simitRing(cv, 28, 6, true);
  cv.outline(C.ink);
  if (spec.ring === 'loose') { simitRing(cv, 42, 34); }
  if (spec.stars) for (const [x, y] of [[8, 4], [40, 3], [24, 1]]) { cv.set(x, y, '#ffd23f'); cv.set(x - 1, y, '#ffd23f'); cv.set(x + 1, y, '#ffd23f'); cv.set(x, y - 1, '#ffd23f'); cv.set(x, y + 1, '#ffd23f'); }
  return cv;
}

const FRAMES = [
  { wing: 62, ring: 'chest' }, { wing: 36, ring: 'chest' }, { wing: 10, ring: 'chest' },
  { wing: -20, ring: 'chest' }, { wing: -42, ring: 'chest' }, { wing: 16, ring: 'chest' },
  { wing: 14, ring: 'chest' }, // süzülme
  { wing: -32, ring: 'chest', eye: 'focus' }, // yükselme
  { wing: 58, ring: 'chest', eye: 'surprised', open: 2 }, // düşüş
  { wing: 70, ring: 'loose', eye: 'crash', open: 3, stars: true }, // çarpışma
  { wing: 10, ring: 'chest', eye: 'blink' }, // göz kırpma (kanat kare 2 ile aynı)
  { wing: -12, ring: 'head', eye: 'dazed' }, // oyun sonu: simit başında
];

function sheet() {
  const s = new Canvas(FW * 6, FH * 2);
  FRAMES.forEach((f, i) => s.blit(frame(f), (i % 6) * FW, Math.floor(i / 6) * FH));
  return s;
}

function build(outDir) {
  return [sheet().save(`${outDir}/characters/simit_sheet.png`)];
}

module.exports = { build, sheet, FW, FH, PIV };

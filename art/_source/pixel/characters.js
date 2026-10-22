// Simit — pixel art sprite sheet. Kare 48×42 px (oyunda 192×168 dünya birimi = 1 px : 4 birim).
// 12 kare (6 sütun × 2 satır): 0–5 kanat döngüsü · 6 süzülme · 7 yükselme · 8 düşüş · 9 çarpışma · 10 göz kırpma · 11 oyun sonu.
// Gövde, kuyruk, simit ve gaga her karede aynı piksellere çizilir; sadece kanat ve yüz değişir → titreme yok.
//
// Kozmetik görünümler (Phase 2.2, docs/13): aynı anatomi, aynı kareler, aynı pivot. Bir görünüm = palet
// (tüy tonları) + aksesuar katmanları. Aksesuarlar konturdan ÖNCE çizilir → karakterle aynı koyu
// dış çizgiyi alır. Kurdele, püskül ve atkı ucu kanat açısıyla birlikte salınır (kare kare canlı).
'use strict';
const { Canvas } = require('./lib');

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
function wing(cv, P, angleDeg, far = false) {
  const a = (angleDeg * Math.PI) / 180; // pozitif açı: uç yukarı (ekranda y aşağı, kanat geriye bakıyor)
  const S = [19, 20];
  const shape = [[3, -1], [-3, -4], [-10, -5], [-17, -4], [-22, -1], [-17, 2], [-9, 3], [-2, 3]];
  const pts = shape.map(p => { const [x, y] = rot(p, a); return [S[0] + x, S[1] + y]; });
  cv.poly(pts, (x, y) => {
    const [lx, ly] = rot([x + 0.5 - S[0], y + 0.5 - S[1]], -a); // kanadın yerel koordinatı
    if (lx < -15) return lx < -19 && Math.abs(ly + 1) < 1 && !far ? P.mirror : P.tip;
    if (far) return P.g[3];
    if (ly < -2.5) return P.g[0];
    if (ly > 1.5) return P.g[2];
    if (Math.round(lx) % 4 === 0 && ly > 0) return P.g[2]; // tüy çizgileri
    // görünüme özgü parıltı (ör. Altın Kanat, Gece Martısı): kanat üstünde sabit yerel noktalar
    if (P.glint && P.glint.some(([gx, gy]) => Math.round(lx) === gx && Math.round(ly) === gy)) return P.glintColor;
    return P.g[1];
  });
}

function body(cv, P) {
  // kuyruk (arkada, beyaz, siyah uçlu)
  cv.poly([[11, 20], [2, 17], [3, 22], [1, 27], [11, 27]], (x) => (x < 5 ? P.tip : P.w[2]));
  // gövde: yumurta biçimi, üstten ışık; göğüs gölgesi
  cv.ellipse(21, 25, 13.5, 11.5, (nx, ny) => {
    const l = -nx * 0.35 - ny * 0.8;
    return l > 0.55 ? P.w[0] : l > -0.1 ? P.w[1] : l > -0.6 ? P.w[2] : P.w[3];
  });
  // baş (gövdeyle kaynaşık), sırt pelerini
  cv.ellipse(29, 16, 8.5, 8, (nx, ny) => (nx * 0.3 + ny * 0.9 < -0.55 ? P.w[0] : ny > 0.6 ? P.w[2] : P.w[1]));
  cv.poly([[10, 22], [12, 15], [18, 11], [24, 10], [18, 16], [14, 22]], (x, y) => (y < 14 ? P.g[0] : P.g[1]));
  // ayaklar (uçarken toplu)
  cv.rect(15, 35, 4, 2, P.leg); cv.set(14, 36, P.leg);
}

function beak(cv, P, open = 0) {
  // üst gaga: uzun, kancalı uç
  cv.poly([[35, 15], [44, 16], [46, 18], [44, 19], [35, 19]], (x, y) => (y <= 16 ? P.beak[0] : P.beak[1]));
  cv.set(46, 19, P.beak[2]);
  // alt gaga + kırmızı benek
  const dy = open;
  cv.poly([[35, 19 + dy * 0.3], [43, 19 + dy], [41, 21 + dy], [35, 21]], P.beak[2]);
  cv.set(41, 20 + dy, P.spot); cv.set(41, 21 + dy, P.spot);
}

function simitRing(cv, P, cx, cy, flat = false) {
  const rx = 6.5, ry = flat ? 2.5 : 4.5;
  for (let y = Math.floor(cy - ry - 2); y <= cy + ry + 2; y++) for (let x = Math.floor(cx - rx - 2); x <= cx + rx + 2; x++) {
    const nx = (x + 0.5 - cx) / rx, ny = (y + 0.5 - cy) / ry, d = nx * nx + ny * ny;
    const inner = (x + 0.5 - cx) ** 2 / (rx * 0.42) ** 2 + (y + 0.5 - cy) ** 2 / (ry * 0.42) ** 2;
    if (d <= 1 && inner > 1) cv.set(x, y, ny < -0.2 ? P.simit[0] : ny > 0.45 ? P.simit[2] : P.simit[1]);
  }
  for (const [dx, dy] of [[-4, -2], [0, -3], [4, -2], [5, 1], [-5, 1]]) cv.set(Math.round(cx + dx), Math.round(cy + dy * (flat ? 0.5 : 1)), P.sesame);
}

function eye(cv, P, kind) {
  const ex = 32, ey = 13;
  if (kind === 'blink') { cv.hline(ex - 1, ex + 2, ey + 1, P.ink); cv.hline(ex - 2, ex + 2, ey - 2, P.g[2]); return; }
  if (kind === 'crash') { cv.set(ex - 1, ey - 1, P.ink); cv.set(ex + 1, ey + 1, P.ink); cv.set(ex + 1, ey - 1, P.ink); cv.set(ex - 1, ey + 1, P.ink); cv.set(ex, ey, P.ink); return; }
  if (kind === 'dazed') { cv.set(ex, ey, P.ink); cv.set(ex + 1, ey, P.ink); cv.set(ex + 1, ey + 1, P.ink); cv.set(ex - 1, ey + 1, P.ink); cv.set(ex - 1, ey - 1, P.ink); cv.set(ex + 1, ey - 1, P.ink); return; }
  // kırmızı göz halkası + sarı iris + göz bebeği
  cv.rect(ex - 1, ey - 1, 4, 4, P.ring);
  cv.rect(ex, ey, 2, 2, P.iris);
  cv.set(ex + 1, ey, P.ink); cv.set(ex + 1, ey + 1, P.ink);
  if (kind === 'surprised') { cv.rect(ex - 1, ey - 2, 4, 1, P.ring); cv.hline(ex - 2, ex + 2, ey - 4, P.g[2]); return; }
  // ağır göz kapağı (kendinden emin / küstah) + düz kaş
  cv.hline(ex - 1, ex + 2, ey - 1, P.w[1]);
  cv.hline(ex - 1, ex + 2, ey, kind === 'focus' ? P.ring : P.ink);
  if (kind === 'focus') cv.set(ex + 1, ey, P.ink);
  cv.hline(ex - 2, ex + 3, ey - 3, P.g[2]);
}

// ============================ Aksesuarlar ============================
// Hepsi başın (merkez 29,16) ve boynun sabit piksellerine oturur; kanat ve göz bölgesine girmez.
// sway: kanat açısından türeyen -1..1 salınım (kurdele/püskül/atkı ucu).

/** Denizci: beyaz denizci şapkası (lacivert bant, arkaya uçuşan iki kurdele) + lacivert denizci yakası. */
const sailor = {
  chest(cv) {
    // denizci fuları: gaganın altında lacivert üçgen, beyaz şerit, öne düşen düğüm ucu
    cv.poly([[27, 20], [37, 20], [36, 23], [33, 27], [29, 23]], (x, y) => (y === 21 ? '#f3f0ea' : x > 34 ? '#1b2340' : '#2b3a68'));
    cv.set(33, 26, '#1b2340'); cv.set(32, 27, '#2b3a68'); cv.set(34, 27, '#2b3a68');
  },
  head(cv, sway) {
    // kurdeleler (önce: şapkanın arkasında), uçları kanatla savrulur
    const k = Math.round(sway * 2);
    cv.line(24, 8, 18, 10 + k, '#1b2340'); cv.line(24, 9, 19, 12 + k, '#2b3a68');
    cv.line(18, 10 + k, 17, 11 + k, '#1b2340'); cv.set(18, 13 + k, '#2b3a68');
    // şapka tepesi: yassı beyaz kubbe, üstten ışık, alt kısmı gri gölge (baştan ayrılır)
    cv.ellipse(29.5, 5.5, 6.5, 3.4, (nx, ny) => (ny < -0.3 && nx < 0.4 ? '#ffffff' : ny > 0.35 ? '#c9c6d0' : '#eceaf0'));
    // lacivert bant (2 px) + altın toka + kıvrık kenar
    cv.rect(23, 7, 14, 2, '#2b3a68'); cv.hline(24, 35, 7, '#3a4f86');
    cv.set(29, 8, '#f5c235'); cv.set(30, 8, '#d99a1c');
    cv.hline(23, 36, 9, '#b4b2c0');
  },
};

/** Pilot: kahverengi deri pilot başlığı, alnında yuvarlak gözlük, boynunda uçuşan beyaz atkı. */
const pilot = {
  neck(cv, sway) {
    // atkının uçuşan ucu: boyundan sırtın üstünden geriye, kanatla dalgalanır
    const k = sway * 2.2;
    cv.poly([[22, 18], [14, 17 + k], [6, 19 + k * 1.4], [3, 18 + k * 1.6], [5, 21 + k * 1.4], [13, 21 + k], [22, 22]], (x, y) => (y > 19.5 + k * (22 - x) / 19 ? '#9c2f2a' : '#c8423a'));
    cv.set(4, 20 + Math.round(k * 1.5), '#7a221f');
    // atkı boyun sargısı
    cv.poly([[21, 18], [30, 21], [30, 24], [21, 22]], (x, y) => (y < 20 + (x - 21) * 0.3 ? '#d9564b' : '#9c2f2a'));
    cv.set(26, 22, '#7a221f');
  },
  head(cv) {
    // deri başlık: başın üst-arka yarısını örter, gözü açık bırakır
    // null renk = piksel atlanır (Canvas.set): göz ve yanak açık kalır
    cv.ellipse(28.5, 12.5, 8.3, 6.6, (nx, ny, x, y) => {
      if (y > 10 && x > 29) return null;
      return ny < -0.45 ? '#b77a4a' : ny > 0.35 ? '#6e4426' : '#94603a';
    });
    // kulaklık / çene kayışı
    cv.rect(24, 13, 3, 6, '#7d4f2e'); cv.set(25, 19, '#5c391f'); cv.vline(24, 13, 18, '#5c391f');
    // dikiş çizgisi
    cv.line(23, 9, 30, 6, '#6e4426');
    // gözlük: iki yuvarlak cam (kehribar), metal çerçeve, kayış
    cv.hline(22, 37, 9, '#3a3240');
    for (const gx of [29, 34]) {
      cv.rect(gx - 1, 7, 4, 4, '#3a3240');
      cv.rect(gx, 8, 2, 2, '#f2b84b');
      cv.set(gx, 8, '#fff0b8');
    }
  },
};

/** İstanbul Kaşifi: kırmızı fes (siyah püsküllü) + göğüste nazar boncuğu. */
const explorer = {
  head(cv, sway) {
    // püskül: tepenin ortasından arkaya sarkar, kanatla salınır
    const k = Math.round(sway * 1.5);
    cv.line(29, 2, 25, 5 + k, '#1b1a22'); cv.line(25, 5 + k, 24, 8 + k, '#1b1a22');
    cv.set(23, 8 + k, '#1b1a22'); cv.set(24, 9 + k, '#1b1a22'); cv.set(25, 9 + k, '#1b1a22');
    // fes: kesik koni, soldan ışık, sağ kenar gölge
    cv.poly([[24, 10], [26, 2], [33, 2], [35, 10]], (x, y) => (x < 27 ? '#e5584c' : x > 32 ? '#8f1f2a' : '#c42f36'));
    cv.hline(26, 33, 2, '#a32530'); // tepe
    cv.hline(24, 35, 10, '#8f1f2a'); // alt kenar
    cv.set(29, 2, '#1b1a22'); // püskül düğmesi
  },
  chest(cv) {
    // nazar boncuğu: lacivert → beyaz → açık mavi → siyah göz; kısa ip
    cv.line(31, 21, 33, 22, '#3a3240');
    const cx = 34, cy = 24;
    cv.ellipse(cx, cy, 2.6, 2.6, '#1d4fa8');
    cv.ellipse(cx, cy, 1.7, 1.7, '#fbf7ee');
    cv.rect(cx - 1, cy - 1, 2, 2, '#6fb6ef');
    cv.set(cx, cy, '#14141c');
  },
};

/** İznik Martısı (Phase 2.3 keşif ödülü): başın arkasına iliştirilmiş kırmızı lale. */
const tulip = {
  head(cv, sway) {
    // sap ve yaprak: başın arkasından yukarı, kanatla hafifçe salınır
    const k = Math.round(sway);
    cv.line(25, 9, 23 + k, 3, '#2f7a46'); cv.set(24, 7, '#4fa35e'); cv.set(25, 6, '#4fa35e'); cv.set(26, 6, '#2f7a46');
    // lale çanağı: üç taç yaprak, soldan ışık
    const tx = 23 + k, ty = 2;
    cv.poly([[tx - 3, ty - 3], [tx - 2, ty + 1], [tx + 2, ty + 1], [tx + 3, ty - 3], [tx + 1, ty - 1], [tx, ty - 4], [tx - 1, ty - 1]], (x) => (x < tx - 1 ? '#f0645a' : x > tx + 1 ? '#9c1f2c' : '#d0343c'));
    cv.set(tx, ty, '#7a1622');
  },
};

const SKINS = {
  classic: { palette: C },
  denizci: { palette: C, acc: sailor },
  pilot: { palette: C, acc: pilot },
  gece: {
    // Gece Martısı: ay ışığında lavanta-gri tüyler, lacivert kanatlar, kanatta yıldız pırıltısı
    palette: {
      ...C,
      w: ['#e6e9f7', '#c3c9e3', '#959fca', '#6a73a4'],
      g: ['#55608f', '#3d4675', '#2c3358', '#1c2142'],
      tip: '#0d0f1f', mirror: '#e8ecff',
      iris: '#9ff0ff', ring: '#6a5acd',
      glint: [[-6, 0], [-11, -2], [-3, -1]], glintColor: '#fff4c2',
    },
  },
  altin: {
    // Altın Kanat: altın tüylü kanat ve sırt, bronz kanat ucu, kanatta parıltı
    palette: {
      ...C,
      g: ['#ffe39a', '#f0bd48', '#c98f26', '#8f5f16'],
      tip: '#6b4513', mirror: '#fff7d6',
      glint: [[-5, -1], [-12, -2], [-8, 1]], glintColor: '#fffbe6',
    },
  },
  kasif: { palette: C, acc: explorer },
  iznik: {
    // İznik Martısı: çini mavisi kanatlar, firuze uçlar, kanatta beyaz çini çiçekleri + lale
    palette: {
      ...C,
      g: ['#7fd3d6', '#2f8fb0', '#1d5f9e', '#163f73'],
      tip: '#0f2a52', mirror: '#e9fbff',
      glint: [[-6, 0], [-11, -2], [-3, -1]], glintColor: '#fbf7ee',
    },
    acc: tulip,
  },
};

function frame(spec, skin = SKINS.classic) {
  const P = skin.palette, acc = skin.acc || {};
  const sway = Math.max(-1, Math.min(1, spec.wing / 60)); // kanat yukarı → kurdele yukarı savrulur
  const hatRing = spec.ring === 'head' && acc.head; // şapkalı görünümde simit şapkanın tepesine konar
  const cv = new Canvas(FW, FH);
  if (spec.wing > 25) wing(cv, P, spec.wing + 12, true); // arka kanat yukarıdayken görünür
  if (acc.back) acc.back(cv, sway);
  body(cv, P);
  if (acc.neck) acc.neck(cv, sway);
  if (spec.ring === 'chest') simitRing(cv, P, 27, 28);
  if (acc.chest) acc.chest(cv, sway);
  beak(cv, P, spec.open || 0);
  eye(cv, P, spec.eye || 'smug');
  wing(cv, P, spec.wing);
  if (acc.head) acc.head(cv, sway);
  if (spec.ring === 'head') simitRing(cv, P, 28, hatRing ? 2 : 6, true);
  cv.outline(P.ink);
  if (spec.ring === 'loose') { simitRing(cv, P, 42, 34); }
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

function sheet(skinId = 'classic') {
  const skin = SKINS[skinId];
  const s = new Canvas(FW * 6, FH * 2);
  FRAMES.forEach((f, i) => s.blit(frame(f, skin), (i % 6) * FW, Math.floor(i / 6) * FH));
  return s;
}

function build(outDir) {
  const files = [sheet().save(`${outDir}/characters/simit_sheet.png`)];
  for (const id of Object.keys(SKINS)) {
    if (id === 'classic') continue; // klasik görünüm = simit_sheet.png
    files.push(sheet(id).save(`${outDir}/characters/skins/${id}.png`));
  }
  return files;
}

module.exports = { build, sheet, frame, FRAMES, SKINS, FW, FH, PIV };

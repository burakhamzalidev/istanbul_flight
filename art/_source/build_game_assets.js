// Oyun içi asset üreticisi (v2). Elle yazılmış vektör çizimler → SVG → (render_game_assets.sh) şeffaf PNG.
// AI üretimi değildir. Konsept sayfalarıyla aynı çizim fonksiyonlarını kullanır (build.js).
//
// Çıktılar (OUT altında):
//   simit/simit_sheet.svg            12 kare (6×2): uçuş, durumlar, ifadeler
//   background/far_*.svg             L2 uzak silüet şeritleri (yatay döşenebilir maske)
//   background/shore_*.svg           L4 kıyı şeritleri: 3 satır = şekil, ışık A, ışık B (maske)
//   landmarks/*.svg                  L3 simgeler: 2 satır = şekil, ışıklar (maske)
//   obstacles/kit_*.svg              L6 engel kitleri: 2 satır = renkli parçalar, ışık maskesi
// Ayrıca DART_OUT'a kit yerleşimini yazar (lib/game/visual/obstacle_kit_layout.g.dart).
const fs = require('fs');
const path = require('path');
const { simit, galata, kizKulesi, suleymaniye, peninsulaFar, minaret, dome } = require('./build.js');

const OUT = process.argv[2];
const DART_OUT = process.argv[3];
const svg = (w, h, body) => `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">${body}</svg>`;
const M = '#FFFFFF';
const files = {};
const renderList = []; // [svgPath, w, h]
function emit(p, w, h, body) { files[p] = svg(w, h, body); renderList.push([p, w, h]); }

let seed = 1;
const rnd = () => ((seed = (seed * 16807) % 2147483647) / 2147483647);
const r1 = n => Math.round(n * 10) / 10;

// =============== SİMİT: 12 kare (6 sütun × 2 satır) ===============
// Kare 360×315 px, pivot (165,165). Satır 1: kanat döngüsü. Satır 2: durumlar.
const FS = 1.5, FW = 360, FH = 315, OX = 165, OY = 165;
const simitFrames = [
  { wing: 62, ring: [24, 20, -26] },                       // 0 kanat yukarı
  { wing: 36, ring: [23, 22, -23] },                       // 1 iniş başı
  { wing: 10, ring: [22, 25, -19] },                       // 2 orta
  { wing: -20, ring: [22, 28, -15] },                      // 3 itiş
  { wing: -40, ring: [21, 30, -12] },                      // 4 tam aşağı
  { wing: 18, ring: [22, 27, -16] },                       // 5 toparlanma
  { wing: 18, ring: [22, 26, -18] },                       // 6 süzülme
  { wing: -34, ring: [10, 32, 2], expr: 'focus' },         // 7 yükselme
  { wing: 58, ring: [32, 14, -36], expr: 'surprised' },    // 8 düşüş
  { wing: 70, ring: 'loose', expr: 'crash' },              // 9 çarpışma
  { wing: 10, ring: [22, 25, -19], expr: 'blink' },        // 10 menü: göz kırpma (kare 2 ile aynı kanat)
  { wing: -14, ring: [2, -60, -6], expr: 'dazed', legs: false }, // 11 oyun sonu: simit başına geçmiş
];
emit('simit/simit_sheet.svg', FW * 6, FH * 2,
  simitFrames.map((f, i) => simit({ x: (i % 6) * FW + OX, y: Math.floor(i / 6) * FH + OY, s: FS, ...f })).join(''));

// =============== Döşenebilir şerit yardımcıları ===============
// Her öğe x, x−W ve x+W konumlarında çizilir → kenarlar dikişsiz birleşir.
function tile(W, items) { return [-W, 0, W].map(o => `<g transform="translate(${o} 0)">${items}</g>`).join(''); }

// =============== L2 UZAK SİLÜETLER (maske, 2160×420) ===============
const FAR_W = 2160, FAR_H = 420, FB = 404;
function farPeninsula() {
  seed = 3;
  let g = `<rect x="-2200" y="${FB}" width="6600" height="${FAR_H - FB}" fill="${M}"/>`;
  for (let x = 0; x < FAR_W; ) { const w = 40 + rnd() * 70, h = 16 + rnd() * 44; g += `<rect x="${r1(x)}" y="${r1(FB - h)}" width="${r1(w + 1)}" height="${r1(h + 2)}" fill="${M}"/>`; x += w; }
  g += peninsulaFar(520, FB, 0.85, M) + peninsulaFar(1640, FB, 0.7, M);
  g += dome(1100, FB - 16, 26, 22, M) + minaret(1062, FB, 110, M, 6);
  return tile(FAR_W, g);
}
function farUskudar() {
  seed = 11;
  let g = `<rect x="-2200" y="${FB}" width="6600" height="${FAR_H - FB}" fill="${M}"/>`;
  // Anadolu yakası tepeleri (Çamlıca dahil) + ev dokusu
  g += `<path d="M0,${FB} C200,330 420,300 640,338 C820,370 980,300 1180,262 C1360,232 1500,300 1700,330 C1880,356 2020,340 ${FAR_W},${FB} Z" fill="${M}"/>`;
  for (let x = 0; x < FAR_W; ) { const w = 22 + rnd() * 36, h = 10 + rnd() * 30; const by = FB - 40 - 50 * Math.sin(x / FAR_W * Math.PI * 2) ** 2; g += `<rect x="${r1(x)}" y="${r1(by - h)}" width="${r1(w)}" height="${r1(h + 60)}" fill="${M}"/>`; x += w + 4 + rnd() * 10; }
  g += `<rect x="1176" y="150" width="8" height="114" fill="${M}"/><rect x="1166" y="200" width="28" height="10" fill="${M}"/>`; // Çamlıca'da verici kulesi
  g += dome(380, FB - 30, 22, 20, M) + minaret(344, FB - 30, 70, M, 5);
  return tile(FAR_W, g);
}
function farHills() {
  seed = 17;
  let g = `<rect x="-2200" y="${FB}" width="6600" height="${FAR_H - FB}" fill="${M}"/>`;
  g += `<path d="M0,${FB} C240,300 520,280 760,320 C980,350 1180,250 1440,240 C1700,232 1900,320 ${FAR_W},${FB} Z" fill="${M}"/>`;
  // ağaç dokusu: tepe çizgisi boyunca yuvarlak tepecikler
  for (let x = 0; x < FAR_W; x += 26) {
    const t = x / FAR_W; const top = FB - (90 + 70 * Math.sin(t * Math.PI * 2 + 0.6) ** 2);
    g += `<circle cx="${x}" cy="${r1(top + 10 * rnd())}" r="${r1(16 + 10 * rnd())}" fill="${M}"/>`;
  }
  return tile(FAR_W, g);
}
emit('background/far_peninsula.svg', FAR_W, FAR_H, farPeninsula());
emit('background/far_uskudar.svg', FAR_W, FAR_H, farUskudar());
emit('background/far_hills.svg', FAR_W, FAR_H, farHills());

// =============== L4 KIYI ŞERİTLERİ (maske, 2160×3·200) ===============
// Satır 0: şekil (y 0..200, taban y=200 = ufuk). Satır 1–2: ışık A/B (titreşim için dönüşümlü).
const SH_W = 2160, SH_H = 200;
function shore(builder, s) {
  seed = s;
  const shape = [], la = [], lb = [];
  const ctx = {
    rect: (x, y, w, h) => shape.push(`<rect x="${r1(x)}" y="${r1(y)}" width="${r1(w)}" height="${r1(h)}" fill="${M}"/>`),
    path: d => shape.push(`<path d="${d}" fill="${M}"/>`),
    circle: (x, y, r) => shape.push(`<circle cx="${r1(x)}" cy="${r1(y)}" r="${r1(r)}" fill="${M}"/>`),
    win: (x, y, w, h, p = 0.35) => { const r = rnd(); if (r < p) (r < p / 2 ? la : lb).push(`<rect x="${r1(x)}" y="${r1(y)}" width="${r1(w)}" height="${r1(h)}" rx="1" fill="${M}"/>`); },
  };
  builder(ctx);
  const body = (arr, dy) => `<g transform="translate(0 ${dy})">${tile(SH_W, arr.join(''))}</g>`;
  return body(shape, 0) + body(la, SH_H) + body(lb, SH_H * 2);
}
const B = SH_H; // ufuk (şerit tabanı)
const shoreBuilders = {
  // Haliç: Fener/Balat ahşap evleri, cumbalar, servi ağaçları
  halic: c => {
    c.rect(0, B - 8, SH_W, 8);
    for (let x = 0; x < SH_W; ) {
      const w = 54 + rnd() * 50, h = 50 + rnd() * 70;
      if (rnd() < 0.18) { c.path(`M${x + 10},${B} C${x + 2},${B - 60} ${x + 10},${B - 130} ${x + 16},${B - 150} C${x + 22},${B - 130} ${x + 30},${B - 60} ${x + 22},${B} Z`); x += 32; continue; }
      c.rect(x, B - h, w, h);
      c.path(`M${x - 4},${B - h} L${x + w / 2},${B - h - 18 - rnd() * 10} L${x + w + 4},${B - h} Z`);
      if (rnd() < 0.5) c.rect(x + w * 0.2, B - h + 12, w * 0.6, 26); // cumba
      for (let yy = B - h + 16; yy < B - 22; yy += 30) for (let xx = x + 8; xx < x + w - 14; xx += 18) c.win(xx, yy, 8, 12, 0.3);
      x += w + 2;
    }
  },
  // Galata/Karaköy: sık, yüksek bloklar, çatı katları, bacalar, su depoları
  galata: c => {
    c.rect(0, B - 10, SH_W, 10);
    for (let x = 0; x < SH_W; ) {
      const w = 60 + rnd() * 70, h = 80 + rnd() * 90;
      c.rect(x, B - h, w, h);
      c.path(`M${x},${B - h} L${x + 8},${B - h - 16} L${x + w - 8},${B - h - 16} L${x + w},${B - h} Z`);
      for (let k = 0; k < 2; k++) if (rnd() < 0.7) c.rect(x + 10 + rnd() * (w - 26), B - h - 34, 8, 22);
      if (rnd() < 0.25) { c.rect(x + w / 2 - 12, B - h - 40, 24, 16); c.rect(x + w / 2 - 2, B - h - 52, 3, 14); }
      for (let yy = B - h + 14; yy < B - 22; yy += 24) for (let xx = x + 8; xx < x + w - 12; xx += 16) c.win(xx, yy, 7, 11, 0.22);
      x += w + 1;
    }
  },
  // Üsküdar kıyısı: alçak evler, ağaçlar, iskele binası
  uskudar: c => {
    c.rect(0, B - 6, SH_W, 6);
    for (let x = 0; x < SH_W; ) {
      if (rnd() < 0.3) { const r = 18 + rnd() * 16; c.circle(x + r, B - 20 - r * 0.6, r); c.circle(x + r * 1.8, B - 14 - r * 0.4, r * 0.8); x += r * 2.6; continue; }
      const w = 40 + rnd() * 50, h = 30 + rnd() * 55;
      c.rect(x, B - h, w, h);
      c.path(`M${x - 3},${B - h} L${x + w / 2},${B - h - 14} L${x + w + 3},${B - h} Z`);
      for (let yy = B - h + 12; yy < B - 14; yy += 22) for (let xx = x + 6; xx < x + w - 10; xx += 15) c.win(xx, yy, 6, 9, 0.4);
      x += w + 6;
    }
    // iskele binası (suya uzanan, sivri çatılı)
    c.rect(900, B - 70, 160, 70); c.path(`M890,${B - 70} L980,${B - 112} L1070,${B - 70} Z`); c.rect(975, B - 140, 10, 30);
    for (let xx = 912; xx < 1050; xx += 22) c.win(xx, B - 54, 12, 18, 0.8);
  },
  // Ortaköy/Arnavutköy: geniş saçaklı yalılar, aralarda ağaçlar
  ortakoy: c => {
    c.rect(0, B - 6, SH_W, 6);
    for (let x = 0; x < SH_W; ) {
      if (rnd() < 0.35) { const r = 22 + rnd() * 18; c.circle(x + r, B - 26 - r * 0.5, r); c.circle(x + r * 2, B - 18 - r * 0.5, r * 0.85); x += r * 2.9; continue; }
      const w = 110 + rnd() * 90, h = 60 + rnd() * 40;
      c.rect(x, B - h, w, h);
      c.rect(x - 10, B - h - 8, w + 20, 10); // geniş saçak
      c.path(`M${x - 10},${B - h - 8} L${x + w / 2},${B - h - 30} L${x + w + 10},${B - h - 8} Z`);
      for (let yy = B - h + 12; yy < B - 18; yy += 26) for (let xx = x + 10; xx < x + w - 16; xx += 20) c.win(xx, yy, 10, 14, 0.5);
      x += w + 18;
    }
  },
  // Rumeli kıyısı: koyu korular, seyrek yalılar, sahil fenerleri
  rumeli: c => {
    c.rect(0, B - 6, SH_W, 6);
    for (let x = 0; x < SH_W; ) {
      if (rnd() < 0.7) { const r = 24 + rnd() * 26; c.circle(x + r, B - 30 - r * 0.5, r); c.circle(x + r * 1.7, B - 20 - r * 0.3, r * 0.9); c.circle(x + r * 0.6, B - 14, r * 0.7); x += r * 2.4; continue; }
      const w = 90 + rnd() * 60, h = 50 + rnd() * 30;
      c.rect(x, B - h, w, h); c.rect(x - 8, B - h - 6, w + 16, 8);
      for (let yy = B - h + 12; yy < B - 16; yy += 24) for (let xx = x + 10; xx < x + w - 14; xx += 20) c.win(xx, yy, 9, 13, 0.35);
      x += w + 10;
    }
    for (let x = 60; x < SH_W; x += 240) { c.rect(x, B - 46, 3, 40); c.win(x - 4, B - 52, 11, 8, 1); }
  },
};
for (const [k, fn] of Object.entries(shoreBuilders)) emit(`background/shore_${k}.svg`, SH_W, SH_H * 3, shore(fn, 100 + k.length * 7));

// =============== L3 SİMGELER (maske: satır 0 şekil, satır 1 ışıklar) ===============
function landmark(name, w, h, shapeSvg, lightsSvg) { emit(`landmarks/${name}.svg`, w, h * 2, `${shapeSvg}<g transform="translate(0 ${h})">${lightsSvg}</g>`); }
const N = 'none';
// Süleymaniye (Haliç bölgesinin kahramanı; sadece arka plan, saygın silüet)
landmark('suleymaniye', 760, 460,
  `<path d="M0,460 L0,410 C160,396 600,396 760,410 L760,460 Z" fill="${M}"/>${suleymaniye(380, 420, 1.45, M)}`,
  [-150, -110, -70, 70, 110, 150].map(x => `<rect x="${380 + x * 1.45 - 4}" y="${420 - 50}" width="8" height="14" rx="4" fill="${M}"/>`).join(''));
landmark('galata', 240, 560,
  `<path d="M0,560 L0,520 C40,500 80,494 120,492 C160,494 200,500 240,520 L240,560 Z" fill="${M}"/>${galata(120, 500, 1.05, M, M, M)}`,
  galata(120, 500, 1.05, N, N, M));
landmark('kiz_kulesi', 420, 440, kizKulesi(220, 420, 1.0, M, M, M, M), kizKulesi(220, 420, 1.0, N, N, N, M));
// Boğaz Köprüsü
(function () {
  const W = 1500, H = 760, TT = 60, DECK = 600, T1 = 180, T2 = 1320;
  const cy = t => (1 - t) ** 2 * (TT + 14) + 2 * t * (1 - t) * 900 + t * t * (TT + 14);
  let g = '', l = '';
  for (let x = T1 + 30; x < T2; x += 34) { const t = (x - T1) / (T2 - T1); g += `<rect x="${x - 1.5}" y="${r1(cy(t))}" width="3" height="${r1(DECK - cy(t))}" fill="${M}"/>`; }
  g += `<path d="M${T1},${TT + 14} Q${(T1 + T2) / 2},900 ${T2},${TT + 14}" fill="none" stroke="${M}" stroke-width="8"/>`;
  g += `<path d="M${T1},${TT + 14} Q90,400 0,560" fill="none" stroke="${M}" stroke-width="7"/><path d="M${T2},${TT + 14} Q${W - 90},400 ${W},560" fill="none" stroke="${M}" stroke-width="7"/>`;
  for (const x of [T1, T2]) g += `<path d="M${x - 24},${H} L${x + 24},${H} L${x + 16},${TT} L${x - 16},${TT} Z" fill="${M}"/><rect x="${x - 26}" y="${TT + 160}" width="52" height="14" fill="${M}"/><rect x="${x - 26}" y="${TT + 360}" width="52" height="14" fill="${M}"/><rect x="${x - 20}" y="${TT - 16}" width="40" height="18" fill="${M}"/>`;
  g += `<rect x="0" y="${DECK}" width="${W}" height="30" fill="${M}"/>`;
  for (let i = 0; i <= 44; i++) { const t = i / 44, x = T1 + (T2 - T1) * t; l += `<circle cx="${r1(x)}" cy="${r1(cy(t))}" r="5" fill="${M}"/>`; }
  for (let x = 10; x < W; x += 26) l += `<circle cx="${x}" cy="${DECK + 6}" r="3.5" fill="${M}"/>`;
  for (const x of [T1, T2]) l += `<circle cx="${x}" cy="${TT - 22}" r="7" fill="${M}"/>`;
  landmark('bridge', W, H, g, l);
})();
// Rumeli Hisarı: yamaca tırmanan mazgallı surlar + üç büyük kule (Halil, Saruca, Zağanos Paşa) + küçük kuleler
(function () {
  const W = 1180, H = 600, G = 590;
  let g = '', l = '';
  // yamaç
  g += `<path d="M0,${G} L0,${G - 20} C220,${G - 40} 420,${G - 150} 640,${G - 250} C820,${G - 330} 980,${G - 300} ${W},${G - 260} L${W},${H} L0,${H} Z" fill="${M}"/>`;
  // sur hattı (mazgallı) — yamaç boyunca kademeli
  const wall = [[40, G - 30, 300, G - 110], [300, G - 110, 560, G - 220], [560, G - 220, 820, G - 300], [820, G - 300, 1120, G - 270]];
  for (const [x1, y1, x2, y2] of wall) {
    const steps = Math.round((x2 - x1) / 20);
    for (let i = 0; i < steps; i++) {
      const x = x1 + i * 20, y = y1 + (y2 - y1) * i / steps;
      g += `<rect x="${x}" y="${r1(y - 46)}" width="21" height="${r1(G - y + 46)}" fill="${M}"/>`;
      if (i % 2 === 0) g += `<rect x="${x + 3}" y="${r1(y - 58)}" width="12" height="13" fill="${M}"/>`;
    }
  }
  // büyük kule: silindir + konik çatı
  const tower = (cx, base, w, h, roofH) => {
    let s = `<rect x="${cx - w / 2}" y="${base - h}" width="${w}" height="${h}" fill="${M}"/>`;
    s += `<rect x="${cx - w / 2 - 6}" y="${base - h - 6}" width="${w + 12}" height="10" fill="${M}"/>`;
    for (let x = cx - w / 2 - 6; x < cx + w / 2 + 2; x += 16) s += `<rect x="${x}" y="${base - h - 18}" width="9" height="13" fill="${M}"/>`;
    s += `<path d="M${cx - w / 2 + 4},${base - h - 6} L${cx},${base - h - 6 - roofH} L${cx + w / 2 - 4},${base - h - 6} Z" fill="${M}"/>`;
    s += `<rect x="${cx - 1.5}" y="${base - h - roofH - 26}" width="3" height="22" fill="${M}"/>`;
    return s;
  };
  g += tower(150, G - 20, 120, 210, 120);   // Halil Paşa (kıyıda)
  g += tower(700, G - 250, 104, 230, 110);  // Saruca Paşa (tepede, en yüksek görünen)
  g += tower(1040, G - 270, 96, 170, 96);   // Zağanos Paşa
  g += tower(430, G - 150, 46, 80, 50) + tower(880, G - 290, 40, 70, 44); // küçük kuleler
  // ışıklar: kule pencereleri ve sur projektörleri (seyrek, zarif)
  for (const [x, y] of [[130, G - 170], [170, G - 120], [690, G - 400], [712, G - 340], [1030, G - 380], [1052, G - 330]]) l += `<rect x="${x}" y="${y}" width="9" height="18" rx="4.5" fill="${M}"/>`;
  for (let x = 80; x < 1100; x += 120) { const y = x < 300 ? G - 50 : x < 560 ? G - 140 : x < 820 ? G - 250 : G - 300; l += `<circle cx="${x}" cy="${y}" r="4" fill="${M}"/>`; }
  landmark('rumeli_hisari', W, H, g, l);
})();

// =============== L6 ENGEL KİTLERİ ===============
// Parça yerleşimi (atlas, 1500×(2·320)): satır 0 renkli, satır 1 ışık maskesi (aynı koordinatlar).
// Gövde genişliği = hitbox genişliği (196). Başlık/taban 224 (her yandan 14 taşar, oyuncu lehine).
const BW = 196, CW = 224, OV = 14, TH = 192, CAPH = 128, BASEH = 320, KIT_H = 320;
const SLOT = { bottomBodyA: 0, bottomBodyB: 200, topBodyA: 400, topBodyB: 600, bottomCap: 800, topCap: 1030, bottomBase: 1260 };
const KIT_W = 1500;
const kits = {};
function kit(name, def) { kits[name] = def; }

// Küçük çizim yardımcıları (her biri {c: renkli, l: ışık} parçalarına yazar)
function P() { return { c: [], l: [] }; }
const R = (p, x, y, w, h, fill, extra = '') => p.c.push(`<rect x="${r1(x)}" y="${r1(y)}" width="${r1(w)}" height="${r1(h)}" fill="${fill}" ${extra}/>`);
const PATH = (p, d, fill, extra = '') => p.c.push(`<path d="${d}" fill="${fill}" ${extra}/>`);
const LIT = (p, x, y, w, h, rx = 2) => p.l.push(`<rect x="${r1(x)}" y="${r1(y)}" width="${r1(w)}" height="${r1(h)}" rx="${rx}" fill="${M}"/>`);
function windowBox(p, x, y, w, h, frame, glass, lit, arch = false) {
  if (arch) {
    PATH(p, `M${x - 4},${y + h + 4} L${x - 4},${y + w / 2} A${w / 2 + 4} ${w / 2 + 4} 0 0 1 ${x + w + 4},${y + w / 2} L${x + w + 4},${y + h + 4} Z`, frame);
    PATH(p, `M${x},${y + h} L${x},${y + w / 2} A${w / 2} ${w / 2} 0 0 1 ${x + w},${y + w / 2} L${x + w},${y + h} Z`, glass);
    if (lit) p.l.push(`<path d="M${x},${y + h} L${x},${y + w / 2} A${w / 2} ${w / 2} 0 0 1 ${x + w},${y + w / 2} L${x + w},${y + h} Z" fill="${M}"/>`);
  } else {
    R(p, x - 4, y - 4, w + 8, h + 8, frame); R(p, x, y, w, h, glass);
    if (lit) LIT(p, x, y, w, h, 1);
  }
  R(p, x + w / 2 - 1.5, y + (arch ? w / 2 : 0), 3, h - (arch ? w / 2 : 0), frame);
}
const edges = (p, w, h, c = '#3A2B2E') => { R(p, 0, 0, 4, h, c); R(p, w - 4, 0, 4, h, c); };

// ---- Haliç: ahşap ev (alt) + cumbalı cephe ve çamaşır (üst) ----
kit('halic', {
  bottomCapBoundary: 26,
  bottomBodyA: () => { const p = P(); seed = 21; R(p, 0, 0, BW, TH, '#C98D4E'); for (let y = 6; y < TH; y += 12) R(p, 0, y, BW, 2, '#B07A40'); for (const fy of [0, 96]) { R(p, 0, fy, BW, 6, '#8E5A33'); for (const x of [30, 112]) windowBox(p, x, fy + 20, 54, 60, '#F2E6D0', '#2C3550', rnd() < 0.45); } edges(p, BW, TH); return p; },
  bottomBodyB: () => { const p = P(); seed = 22; R(p, 0, 0, BW, TH, '#B4543F'); for (let y = 6; y < TH; y += 12) R(p, 0, y, BW, 2, '#98432F'); for (const fy of [0, 96]) { R(p, 0, fy, BW, 6, '#6E2E22'); for (const x of [22, 82, 142]) windowBox(p, x, fy + 20, 34, 58, '#F2E6D0', '#2C3550', rnd() < 0.4); } edges(p, BW, TH); return p; },
  topBodyA: () => { const p = P(); seed = 23; R(p, 0, 0, BW, TH, '#6F86A3'); for (let y = 6; y < TH; y += 12) R(p, 0, y, BW, 2, '#5E7491'); for (const fy of [0, 96]) { R(p, 0, fy, BW, 6, '#3E4E66'); for (const x of [30, 112]) windowBox(p, x, fy + 20, 54, 60, '#F2E6D0', '#2C3550', rnd() < 0.45); } edges(p, BW, TH); return p; },
  topBodyB: () => { const p = P(); seed = 24; R(p, 0, 0, BW, TH, '#6F9A84'); for (let y = 6; y < TH; y += 12) R(p, 0, y, BW, 2, '#5C8470'); for (const fy of [0, 96]) { R(p, 0, fy, BW, 6, '#3E5A4C'); for (const x of [22, 82, 142]) windowBox(p, x, fy + 20, 34, 58, '#F2E6D0', '#2C3550', rnd() < 0.4); } edges(p, BW, TH); return p; },
  bottomCap: () => { const p = P(); // sınır y=26: çatı mahyası düz, baca yukarı taşar
    R(p, 150, 4, 18, 26, '#7A3B2C'); R(p, 146, 0, 26, 7, '#3B2A2E');
    PATH(p, `M${OV},26 L${OV + BW},26 L${CW},96 L0,96 Z`, '#B5523B');
    for (const y of [40, 54, 68, 82]) R(p, (96 - y) / 70 * OV, y, CW - (96 - y) / 70 * OV * 2, 3, '#8E3B2A');
    R(p, OV, 26, BW, 4, '#8E3B2A'); R(p, 0, 96, CW, 10, '#3B2A2E'); R(p, OV, 106, BW, 22, '#5B3A2E');
    windowBox(p, 98, 108, 28, 14, '#5B3A2E', '#2C3550', true); return p; },
  topCap: () => { const p = P();
    R(p, OV, 0, BW, 20, '#4E5F78'); R(p, 0, 20, CW, 76, '#5E7491'); R(p, 0, 20, CW, 6, '#3E4E66');
    for (const x of [16, 84, 152]) windowBox(p, x, 34, 56, 44, '#F2E6D0', '#2C3550', x === 84);
    for (const x of [20, 104, 188]) PATH(p, `M${x},96 L${x + 16},96 L${x + 8},110 Z`, '#3E4E66');
    R(p, OV, 96, BW, 32, '#4E5F78'); // çamaşır bandı arkası: hitbox içinde boşluk kalmasın
    R(p, 0, 96, CW, 4, '#3E4E66'); R(p, 4, 104, CW - 8, 2, '#3B2A2E');
    const cl = ['#D9643A', '#2E8B99', '#F2E6D0', '#E8B04B', '#7FA38A', '#D9643A'];
    for (let i = 0; i < 6; i++) { const x = 10 + i * 35; PATH(p, `M${x},105 h28 v4 h-5 v15 h-18 v-15 h-5 Z`, cl[i]); }
    return p; },
  bottomBase: () => { const p = P(); seed = 25; R(p, 0, 0, CW, BASEH, '#8C857F'); for (let y = 0; y < BASEH; y += 32) { R(p, 0, y, CW, 3, '#6E6862'); for (let x = (y / 32) % 2 ? 0 : 28; x < CW; x += 56) R(p, x, y, 3, 32, '#6E6862'); }
    PATH(p, `M80,${BASEH - 40} L80,140 A32 32 0 0 1 144,140 L144,${BASEH - 40} Z`, '#3B2A2E'); LIT(p, 92, 150, 40, 50, 6);
    R(p, 0, BASEH - 60, CW, 60, '#4F6B5A', 'opacity="0.55"'); edges(p, CW, BASEH, '#4E4843'); return p; },
});

// ---- Galata: taş apartman + çatı ve bacalar (alt) / balkon, tente (üst) ----
kit('galata', {
  bottomCapBoundary: 30,
  bottomBodyA: () => { const p = P(); seed = 31; R(p, 0, 0, BW, TH, '#E2D2B6'); for (const fy of [0, 96]) { R(p, 0, fy, BW, 8, '#C8B596'); R(p, 0, fy + 8, BW, 2, '#A8977A'); for (const x of [32, 112]) { windowBox(p, x, fy + 22, 52, 58, '#C8B596', '#2C3550', rnd() < 0.3, true); R(p, x - 8, fy + 82, 68, 6, '#2B2B3A'); for (let b = x - 6; b < x + 60; b += 8) R(p, b, fy + 74, 2, 8, '#2B2B3A'); } } edges(p, BW, TH, '#5A4B42'); return p; },
  bottomBodyB: () => { const p = P(); seed = 32; R(p, 0, 0, BW, TH, '#D7A391'); for (const fy of [0, 96]) { R(p, 0, fy, BW, 8, '#B9806E'); for (const x of [24, 84, 144]) windowBox(p, x, fy + 22, 30, 58, '#F2E6D0', '#2C3550', rnd() < 0.3, true); } edges(p, BW, TH, '#6A4438'); return p; },
  topBodyA: () => { const p = P(); seed = 33; R(p, 0, 0, BW, TH, '#A8C2CF'); for (const fy of [0, 96]) { R(p, 0, fy, BW, 6, '#87A3B1'); for (const x of [30, 112]) windowBox(p, x, fy + 16, 54, 58, '#F2E6D0', '#2C3550', rnd() < 0.3); R(p, 10, fy + 80, BW - 20, 5, '#2B2B3A'); for (let b = 12; b < BW - 10; b += 9) R(p, b, fy + 66, 2, 14, '#2B2B3A'); } edges(p, BW, TH, '#4E6573'); return p; },
  topBodyB: () => { const p = P(); seed = 34; R(p, 0, 0, BW, TH, '#D9B26A'); for (const fy of [0, 96]) { R(p, 0, fy, BW, 6, '#B9944F'); for (const x of [24, 84, 144]) windowBox(p, x, fy + 18, 30, 56, '#F2E6D0', '#2C3550', rnd() < 0.3, true); } edges(p, BW, TH, '#7A5E2E'); return p; },
  bottomCap: () => { const p = P();
    for (const x of [40, 160]) { R(p, x, 6, 20, 28, '#8E3B2A'); R(p, x - 4, 2, 28, 7, '#3B2A2E'); }
    PATH(p, `M${OV},30 L${OV + BW},30 L${CW},92 L0,92 Z`, '#B85A3E');
    for (const y of [44, 58, 72, 86]) R(p, (92 - y) / 62 * OV, y, CW - (92 - y) / 62 * OV * 2, 3, '#94452E');
    R(p, 90, 46, 44, 40, '#E2D2B6'); PATH(p, 'M84,48 L112,30 L140,48 Z', '#94452E'); windowBox(p, 100, 54, 24, 28, '#C8B596', '#2C3550', true);
    R(p, OV, 30, BW, 4, '#94452E'); R(p, 0, 92, CW, 14, '#C8B596'); for (let x = 4; x < CW; x += 12) R(p, x, 106, 6, 6, '#A8977A'); R(p, OV, 112, BW, 16, '#D9C9AD'); return p; },
  topCap: () => { const p = P();
    R(p, OV, 0, BW, 40, '#8FAAB8'); R(p, 0, 40, CW, 8, '#5A5F66'); R(p, OV, 48, BW, 36, '#7E98A6'); // korkuluk arkası duvar: hitbox içinde boşluk kalmasın
    for (const x of [24, 60, 168, 196]) { PATH(p, `M${x - 8},40 a8 8 0 0 1 16,0 Z`, '#4F7A4A'); R(p, x - 5, 34, 10, 6, '#B5523B'); }
    R(p, 4, 48, CW - 8, 4, '#2B2B3A'); for (let b = 6; b < CW - 4; b += 10) R(p, b, 52, 2, 26, '#2B2B3A'); R(p, 4, 78, CW - 8, 4, '#2B2B3A');
    for (let i = 0; i < 14; i++) R(p, i * 16, 84, 16, 34, i % 2 ? '#F2E6D0' : '#C8473A');
    for (let i = 0; i < 14; i++) PATH(p, `M${i * 16},118 a8 8 0 0 0 16,0 Z`, i % 2 ? '#F2E6D0' : '#C8473A');
    R(p, 0, 82, CW, 4, '#7A2E25'); return p; },
  bottomBase: () => { const p = P(); R(p, 0, 0, CW, BASEH, '#D9C9AD'); R(p, 0, 0, CW, 12, '#A8977A');
    for (const x of [16, 120]) { R(p, x, 40, 88, 120, '#2B2B3A'); LIT(p, x + 6, 46, 76, 108, 2); R(p, x - 6, 30, 100, 12, '#2E8B99'); }
    R(p, 0, 180, CW, BASEH - 180, '#8C857F'); for (let y = 180; y < BASEH; y += 28) R(p, 0, y, CW, 3, '#6E6862'); R(p, 0, BASEH - 50, CW, 50, '#4F6B5A', 'opacity="0.5"'); edges(p, CW, BASEH, '#5A4B42'); return p; },
});

// ---- Kız Kulesi: vapur bacası ve vapur (alt) / iskele kazığı (üst) ----
kit('kizkulesi', {
  bottomCapBoundary: 10,
  bottomBodyA: () => { const p = P(); R(p, 0, 0, BW, TH, '#E8D8C0'); R(p, 0, 0, 40, TH, '#CDBBA2'); for (const x of [72, 140]) R(p, x, 0, 3, TH, '#C9B79C'); for (let y = 24; y < TH; y += 48) for (const x of [70, 138]) R(p, x - 2, y, 7, 7, '#B7A58C', 'rx="3.5"'); R(p, BW - 10, 0, 10, TH, '#F4E8D6'); return p; },
  bottomBodyB: () => { const p = P(); R(p, 0, 0, BW, TH, '#E8D8C0'); R(p, 0, 0, 40, TH, '#CDBBA2'); R(p, 0, 70, BW, 34, '#C8473A'); R(p, 0, 70, 40, 34, '#A83A2F'); R(p, BW - 10, 0, 10, TH, '#F4E8D6'); return p; },
  topBodyA: () => { const p = P(); R(p, 0, 0, BW, TH, '#5B3D2E'); for (let x = 39; x < BW; x += 39) R(p, x, 0, 3, TH, '#4A3226'); for (const y of [40, 136]) PATH(p, `M0,${y} Q${BW / 2},${y + 34} ${BW},${y}`, 'none', 'stroke="#9C7A5A" stroke-width="6"'); R(p, 0, 0, 5, TH, '#3A281F'); R(p, BW - 5, 0, 5, TH, '#3A281F'); return p; },
  topBodyB: () => { const p = P(); R(p, 0, 0, BW, TH, '#5B3D2E'); for (let x = 39; x < BW; x += 39) R(p, x, 0, 3, TH, '#4A3226');
    p.c.push(`<circle cx="98" cy="96" r="34" fill="none" stroke="#2A1A1A" stroke-width="24"/><circle cx="98" cy="96" r="34" fill="none" stroke="#F2E6D0" stroke-width="16"/><circle cx="98" cy="96" r="34" fill="none" stroke="#C8473A" stroke-width="16" stroke-dasharray="26.7 26.7"/>`);
    R(p, 94, 50, 8, 14, '#2B2B3A'); R(p, 0, 0, 5, TH, '#3A281F'); R(p, BW - 5, 0, 5, TH, '#3A281F'); return p; },
  bottomCap: () => { const p = P(); // sınır y=10: bacanın siyah başlığı
    R(p, OV, 10, BW, 44, '#23232B'); R(p, OV, 10, BW, 5, '#3A3A46'); R(p, OV + 30, 18, 60, 4, '#3A3A46');
    R(p, OV, 54, BW, 74, '#E8D8C0'); R(p, OV, 54, 40, 74, '#CDBBA2'); R(p, OV + BW - 10, 54, 10, 74, '#F4E8D6');
    p.c.push(`<g transform="translate(${OV + 104} 92)" fill="none" stroke="#23232B" stroke-width="6" stroke-linecap="round"><circle r="30"/><circle cy="-15" r="5"/><path d="M0,-10 L0,18 M-11,-2 L11,-2 M-17,8 Q-14,20 0,20 Q14,20 17,8"/></g>`);
    return p; },
  topCap: () => { const p = P(); // iskele kenarı: kalın kiriş + lamba (sınır y=128)
    R(p, OV, 0, BW, 40, '#5B3D2E'); R(p, 0, 40, CW, 88, '#4A3226'); for (let x = 0; x < CW; x += 32) R(p, x, 40, 3, 88, '#3A281F');
    for (const x of [20, 196]) p.c.push(`<circle cx="${x}" cy="60" r="6" fill="#2B2B3A"/>`);
    R(p, 92, 60, 40, 54, '#2B2B3A', 'rx="4"'); R(p, 98, 66, 28, 40, '#FFE29A'); LIT(p, 98, 66, 28, 40, 3);
    PATH(p, `M10,96 Q50,120 90,96`, 'none', 'stroke="#9C7A5A" stroke-width="6"'); PATH(p, `M134,96 Q174,120 214,96`, 'none', 'stroke="#9C7A5A" stroke-width="6"');
    R(p, 0, 122, CW, 6, '#3A281F'); return p; },
  bottomBase: () => { const p = P(); // vapur: kabin + gövde
    R(p, 0, 0, CW, 150, '#F4EFE6'); R(p, 0, 0, CW, 10, '#C9C2B5'); for (let i = 0; i < 6; i++) { R(p, 12 + i * 35, 40, 24, 34, '#2C3550', 'rx="4"'); LIT(p, 12 + i * 35, 40, 24, 34, 4); }
    R(p, 0, 100, CW, 6, '#C9C2B5'); R(p, 0, 150, CW, 170, '#22324F'); R(p, 0, 158, CW, 12, '#C8473A'); R(p, 0, 150, CW, 6, '#F4EFE6');
    p.c.push(`<circle cx="176" cy="226" r="18" fill="none" stroke="#F2E6D0" stroke-width="8"/><circle cx="176" cy="226" r="18" fill="none" stroke="#C8473A" stroke-width="8" stroke-dasharray="14.1 14.1"/>`);
    return p; },
});

// ---- Boğaz Köprüsü (akşam): askı kablosu demeti (üst) / sahil fener direği (alt) ----
kit('kopru', {
  bottomCapBoundary: 6,
  topBodyA: () => { const p = P(); R(p, 0, 0, BW, TH, '#3E465A'); for (let y = 0; y < TH; y += 64) { PATH(p, `M0,${y} L${BW},${y + 64}`, 'none', 'stroke="#555E74" stroke-width="5"'); PATH(p, `M${BW},${y} L0,${y + 64}`, 'none', 'stroke="#555E74" stroke-width="5"'); }
    for (const x of [58, 138]) { R(p, x - 6, 0, 12, TH, '#8A93A6'); R(p, x - 6, 0, 4, TH, '#A9B1C2'); for (let y = 24; y < TH; y += 48) { p.c.push(`<circle cx="${x}" cy="${y}" r="6" fill="#FFE29A"/>`); p.l.push(`<circle cx="${x}" cy="${y}" r="7" fill="${M}"/>`); } }
    edges(p, BW, TH, '#262C3A'); return p; },
  topBodyB: () => { const p = P(); R(p, 0, 0, BW, TH, '#3E465A'); for (const x of [58, 138]) { R(p, x - 6, 0, 12, TH, '#8A93A6'); for (let y = 24; y < TH; y += 48) { p.c.push(`<circle cx="${x}" cy="${y}" r="6" fill="#FFE29A"/>`); p.l.push(`<circle cx="${x}" cy="${y}" r="7" fill="${M}"/>`); } }
    for (let y = 8; y < TH; y += 24) R(p, 84, y, 28, 5, '#6F7A8C'); R(p, 82, 0, 4, TH, '#6F7A8C'); R(p, 110, 0, 4, TH, '#6F7A8C'); edges(p, BW, TH, '#262C3A'); return p; },
  bottomBodyA: () => { const p = P(); R(p, 0, 0, BW, TH, '#8D8F9A'); for (let y = 0; y < TH; y += 48) { R(p, 0, y, BW, 3, '#707280'); for (let x = (y / 48) % 2 ? 0 : 49; x < BW; x += 98) R(p, x, y, 3, 48, '#707280'); } R(p, 0, 0, 30, TH, '#7E808C'); edges(p, BW, TH, '#4E505C'); return p; },
  bottomBodyB: () => { const p = P(); R(p, 0, 0, BW, TH, '#8D8F9A'); R(p, 0, 0, 30, TH, '#7E808C'); R(p, 0, 80, BW, 16, '#A2A4AE'); R(p, 0, 96, BW, 4, '#707280'); R(p, 70, 120, 56, 40, '#B08D57', 'rx="4"'); R(p, 76, 126, 44, 28, '#8E6E3E', 'rx="3"'); edges(p, BW, TH, '#4E505C'); return p; },
  bottomCap: () => { const p = P(); // sınır y=6: lamba başlığının demir kolu
    R(p, OV, 6, BW, 14, '#2B2B3A'); R(p, OV, 20, BW, 56, '#3A3F4E'); // lamba paneli: fener aralıkları dolu
    for (const x of [34, 98, 162]) { PATH(p, `M${x},20 L${x + 28},20 L${x + 24},76 L${x + 4},76 Z`, '#2B2B3A'); R(p, x + 6, 26, 16, 44, '#FFE29A'); LIT(p, x + 6, 26, 16, 44, 2); PATH(p, `M${x - 2},20 L${x + 14},8 L${x + 30},20 Z`, '#2B2B3A'); }
    R(p, OV, 76, BW, 8, '#2B2B3A'); R(p, 0, 84, CW, 18, '#A2A4AE'); R(p, OV, 102, BW, 26, '#9A9CA6'); R(p, 0, 100, CW, 4, '#707280'); return p; },
  topCap: () => { const p = P(); // kelepçe/eyer bloğu
    R(p, OV, 0, BW, 40, '#3E465A'); R(p, 0, 40, CW, 88, '#4E576D'); R(p, 0, 40, CW, 8, '#5E687E');
    for (const x of [24, 74, 150, 200]) for (const y of [70, 104]) p.c.push(`<circle cx="${x}" cy="${y}" r="7" fill="#2B3040"/>`);
    R(p, 96, 64, 32, 16, '#C8473A', 'rx="3"'); LIT(p, 96, 64, 32, 16, 3); R(p, 0, 120, CW, 8, '#2B3040'); return p; },
  bottomBase: () => { const p = P(); R(p, 0, 0, CW, BASEH, '#7E808C'); for (let y = 0; y < BASEH; y += 40) R(p, 0, y, CW, 4, '#62646F'); R(p, 0, 0, CW, 20, '#9A9CA6'); R(p, 0, BASEH - 70, CW, 70, '#4F6B5A', 'opacity="0.5"'); edges(p, CW, BASEH, '#4E505C'); return p; },
});

// ---- Rumeli (gece): balıkçı teknesi direği ve ağ (alt) / çay bahçesi çardağı ve fenerler (üst) ----
kit('rumeli', {
  bottomCapBoundary: 10,
  bottomBodyA: () => { const p = P(); R(p, 0, 0, BW, TH, '#3A3330'); for (let i = -TH; i < BW; i += 22) { PATH(p, `M${i},0 L${i + TH},${TH}`, 'none', 'stroke="#6E6052" stroke-width="2"'); PATH(p, `M${i + TH},0 L${i},${TH}`, 'none', 'stroke="#6E6052" stroke-width="2"'); }
    R(p, BW / 2 - 13, 0, 26, TH, '#5A4232'); R(p, BW / 2 - 13, 0, 8, TH, '#6E5240'); for (const y of [40, 132]) p.c.push(`<circle cx="40" cy="${y}" r="9" fill="#E07A3A"/><circle cx="156" cy="${y + 40}" r="9" fill="#E07A3A"/>`); edges(p, BW, TH, '#221E1C'); return p; },
  bottomBodyB: () => { const p = P(); R(p, 0, 0, BW, TH, '#3A3330'); for (let i = -TH; i < BW; i += 22) PATH(p, `M${i},0 L${i + TH},${TH}`, 'none', 'stroke="#6E6052" stroke-width="2"');
    R(p, BW / 2 - 13, 0, 26, TH, '#5A4232'); PATH(p, `M0,30 L${BW / 2},4 L${BW},30`, 'none', 'stroke="#9C8A74" stroke-width="3"'); PATH(p, `M0,126 L${BW / 2},100 L${BW},126`, 'none', 'stroke="#9C8A74" stroke-width="3"'); edges(p, BW, TH, '#221E1C'); return p; },
  topBodyA: () => { const p = P(); seed = 51; R(p, 0, 0, BW, TH, '#2F3A2C'); R(p, BW / 2 - 20, 0, 40, TH, '#5A4232'); for (let i = 0; i < 26; i++) p.c.push(`<circle cx="${r1(rnd() * BW)}" cy="${r1(rnd() * TH)}" r="${r1(10 + rnd() * 12)}" fill="${rnd() < 0.5 ? '#4F7A4A' : '#3E6340'}"/>`);
    PATH(p, `M0,60 Q${BW / 2},96 ${BW},60`, 'none', 'stroke="#2B2B3A" stroke-width="2"'); for (let i = 0; i < 6; i++) { const x = 16 + i * 33, y = 60 + 36 * Math.sin(Math.PI * (x / BW)) * 0.9; p.c.push(`<circle cx="${x}" cy="${r1(y)}" r="5" fill="#FFE29A"/>`); p.l.push(`<circle cx="${x}" cy="${r1(y)}" r="6" fill="${M}"/>`); }
    edges(p, BW, TH, '#1E261C'); return p; },
  topBodyB: () => { const p = P(); seed = 52; R(p, 0, 0, BW, TH, '#2F3A2C'); R(p, BW / 2 - 20, 0, 40, TH, '#5A4232'); for (let i = 0; i < 18; i++) p.c.push(`<circle cx="${r1(rnd() * BW)}" cy="${r1(rnd() * TH)}" r="${r1(10 + rnd() * 12)}" fill="${rnd() < 0.5 ? '#4F7A4A' : '#3E6340'}"/>`);
    for (const [x, y] of [[44, 70], [152, 140]]) { R(p, x - 1, y - 30, 2, 20, '#2B2B3A'); R(p, x - 14, y - 10, 28, 36, '#C8473A', 'rx="12"'); LIT(p, x - 8, y - 4, 16, 24, 8); } edges(p, BW, TH, '#1E261C'); return p; },
  bottomCap: () => { const p = P(); // sınır y=10: seren (yatay direk) ve iki fener
    R(p, OV, 26, BW, 62, '#3A3330'); for (let i = -60; i < BW; i += 22) PATH(p, `M${OV + i},26 L${OV + i + 62},88`, 'none', 'stroke="#6E6052" stroke-width="2"'); // ağ zemini
    R(p, OV, 10, BW, 16, '#5A4232'); R(p, OV, 10, BW, 4, '#6E5240');
    for (const x of [46, 150]) { R(p, x - 1, 26, 3, 12, '#2B2B3A'); PATH(p, `M${x - 16},38 L${x + 18},38 L${x + 14},84 L${x - 12},84 Z`, '#2B2B3A'); R(p, x - 8, 44, 18, 34, '#FFE29A'); LIT(p, x - 8, 44, 18, 34, 2); PATH(p, `M${x - 18},38 L${x + 1},26 L${x + 20},38 Z`, '#2B2B3A'); }
    R(p, BW / 2 - 13 + OV, 26, 26, 102, '#5A4232'); R(p, OV, 88, BW, 40, '#3A3330'); R(p, BW / 2 - 13 + OV, 88, 26, 40, '#5A4232'); return p; },
  topCap: () => { const p = P(); // çardak kirişi + asılı fener sırası
    R(p, OV, 0, BW, 56, '#2F3A2C'); R(p, BW / 2 - 20 + OV, 0, 40, 56, '#5A4232'); R(p, 0, 56, CW, 72, '#5A4232'); R(p, 0, 56, CW, 8, '#6E5240'); R(p, 0, 120, CW, 8, '#3E2E22');
    for (const x of [36, 112, 188]) { R(p, x - 1, 68, 2, 12, '#2B2B3A'); R(p, x - 12, 80, 24, 34, '#C8473A', 'rx="10"'); R(p, x - 8, 86, 16, 22, '#FFE29A', 'rx="7"'); LIT(p, x - 8, 86, 16, 22, 7); }
    return p; },
  bottomBase: () => { const p = P(); // balıkçı kayığı
    R(p, 0, 0, CW, 70, '#F2E6D0'); R(p, 20, 12, 70, 40, '#2C3550', 'rx="4"'); LIT(p, 20, 12, 70, 40, 4); R(p, 0, 64, CW, 6, '#C9C2B5');
    R(p, 0, 70, CW, BASEH - 70, '#2E5C8A'); R(p, 0, 92, CW, 14, '#F2E6D0'); R(p, 0, 120, CW, 6, '#C8473A');
    for (const x of [40, 120, 196]) p.c.push(`<circle cx="${x}" cy="150" r="13" fill="#1E1E24"/>`); return p; },
});

// Atlas'ı oluştur
const pieceSizes = { bottomBodyA: [BW, TH], bottomBodyB: [BW, TH], topBodyA: [BW, TH], topBodyB: [BW, TH], bottomCap: [CW, CAPH], topCap: [CW, CAPH], bottomBase: [CW, BASEH] };
for (const [name, def] of Object.entries(kits)) {
  let col = '', lit = '';
  for (const [piece, [w, h]] of Object.entries(pieceSizes)) {
    const p = def[piece]();
    const x = SLOT[piece];
    col += `<svg x="${x}" y="0" width="${w}" height="${h}" overflow="hidden">${p.c.join('')}</svg>`;
    lit += `<svg x="${x}" y="${KIT_H}" width="${w}" height="${h}" overflow="hidden">${p.l.join('')}</svg>`;
  }
  emit(`obstacles/kit_${name}.svg`, KIT_W, KIT_H * 2, col + lit);
}

// Dart yerleşim dosyası
if (DART_OUT) {
  const rect = (x, y, w, h) => `Rect.fromLTWH(${x}, ${y}, ${w}, ${h})`;
  let d = `// ÜRETİLDİ — elle düzenlemeyin. Kaynak: art/_source/build_game_assets.js\n// ignore_for_file: constant_identifier_names\nimport 'dart:ui';\n\n`;
  d += `/// Engel kiti atlas yerleşimi. Renkli parçalar satır 0'da, ışık maskesi aynı konumda +lightsOffsetY.\n`;
  d += `abstract final class ObstacleKitLayout {\n  static const bodyWidth = ${BW}.0;\n  static const capWidth = ${CW}.0;\n  static const overhang = ${OV}.0;\n  static const tileHeight = ${TH}.0;\n  static const capHeight = ${CAPH}.0;\n  static const baseHeight = ${BASEH}.0;\n  static const lightsOffsetY = ${KIT_H}.0;\n`;
  for (const [piece, [w, h]] of Object.entries(pieceSizes)) d += `  static const ${piece} = ${rect(SLOT[piece], 0, w, h)};\n`;
  d += `\n  /// Alt başlıkta hitbox üst kenarının görsel içindeki y konumu (üstünde kalan baca vb. çarpışmasız süs).\n  static const bottomCapBoundary = <String, double>{\n`;
  for (const [name, def] of Object.entries(kits)) d += `    '${name}': ${def.bottomCapBoundary}.0,\n`;
  d += `  };\n}\n`;
  fs.mkdirSync(path.dirname(DART_OUT), { recursive: true });
  fs.writeFileSync(DART_OUT, d, 'utf8');
}

for (const [p, s] of Object.entries(files)) {
  const fp = path.join(OUT, p);
  fs.mkdirSync(path.dirname(fp), { recursive: true });
  fs.writeFileSync(fp, s, 'utf8');
}
fs.writeFileSync(path.join(OUT, 'render_list.txt'), renderList.map(([p, w, h]) => `${p} ${w} ${h}`).join('\n') + '\n');
console.log(renderList.length + ' svg yazıldı');

// Emirgan bölgesi (Phase 2.6.2, docs/19): bahar sabahı, erguvan ve lale mevsimi.
//
// Kamera: Emirgan sahilinin önünde, sudan batıya (Avrupa yakasına) bakış. Önde kıyı duvarı ve lale tarhları; yamaçta
// Emirgan Korusu'nun ağaçları, açmış erguvanlar (Nisan) ve Sarı Köşk. Arkada korunun tepesi; karşı kıyı uzak planda.
//
// Kaynaklar (en.wikipedia.org/wiki/Emirgan, /wiki/Emirgan_Park): Korudaki üç köşk (Sarı, Pembe, Beyaz) Mısır Hidivi
// İsmail Paşa döneminde (1870'ler) yapıldı; Sarı Köşk'ü Sarkis Balyan tasarladı. Koru Nisan'da İstanbul Lale
// Festivali'ne ev sahipliği yapar. Köşk ahşap, iki katlı, geniş saçaklı ve oymalı (dağ evi üslubunda) çizildi.
//
// Ölçek: 1 px = 4 dünya birimi.
'use strict';
const { Canvas, mix, rng } = require('./lib');
const G = require('./galata');

const hash = (x, y, s = 0) => { let h = (x * 374761393 + y * 668265263 + s * 2147483647) >>> 0; h = ((h ^ (h >>> 13)) * 1274126177) >>> 0; return ((h ^ (h >>> 16)) >>> 0) / 4294967296; };
const GREEN = ['#2c5634', '#3a6e3e', '#4e8648', '#6aa05a', '#8cba6a'];
const ERGUVAN = ['#8a3a6a', '#b04a84', '#d8689a', '#ee98bc'];
const YELLOW = ['#9a7a2a', '#c8a03a', '#e8c25a', '#f8de8a'];
const TULIPS = ['#e8323a', '#f2c23a', '#d8689a', '#8a4ac8', '#f6f0e8', '#f07a2a'];

function tree(c, x, y, r, pal) { // tepeden ışık alan yuvarlak ağaç kümesi
  c.ellipse(x, y, r, r * 0.8, (nx, ny) => ny < -0.35 ? pal[pal.length - 1] : ny < 0.25 ? pal[pal.length - 2] : pal[Math.max(0, pal.length - 3)]);
}
function pine(c, x, y, w) { // fıstık çamı: ince gövde, şemsiye taç
  c.vline(x, y, y + w * 0.9, '#5a4234'); c.vline(x + 1, y, y + w * 0.9, '#7a5a44');
  c.ellipse(x, y, w, w * 0.32, (nx, ny) => ny < -0.2 ? GREEN[3] : ny < 0.4 ? GREEN[1] : GREEN[0]);
}

// ======================= Sarı Köşk =======================
function kosk(c, x0, base) {
  const W = 64, H = 30, top = base - H;
  for (let y = top; y < base; y++) for (let x = x0; x < x0 + W; x++) { // ahşap kaplama (yatay), soldan ışık
    const k = (y - top) % 3;
    let col = k === 2 ? YELLOW[1] : (x - x0) < 4 ? YELLOW[3] : YELLOW[2];
    if ((x - x0) > W - 6) col = mix(col, YELLOW[0], 0.35);
    c.set(x, y, col);
  }
  c.hline(x0, x0 + W - 1, top + 14, '#fbf6ea'); c.hline(x0, x0 + W - 1, top + 15, YELLOW[0]); // kat kuşağı
  for (const fy of [top + 3, top + 18]) for (let x = x0 + 4; x < x0 + W - 4; x += 7) { // uzun pencereler, beyaz söveler
    c.rect(x - 1, fy - 1, 5, 11, '#fbf6ea'); c.rect(x, fy, 3, 9, '#2a3a48'); c.set(x, fy, '#8fb4dc'); c.hline(x - 1, x + 3, fy + 10, '#c8b898');
  }
  // orta çıkma ve beşik çatı alınlığı (oymalı)
  const cx = x0 + W / 2;
  c.rect(cx - 12, top - 4, 24, H + 4, YELLOW[2]); c.vline(cx - 12, top - 4, base - 1, YELLOW[3]); c.vline(cx + 11, top - 4, base - 1, YELLOW[1]);
  for (let i = 0; i < 12; i++) { c.hline(cx - 13 + i, cx + 12 - i, top - 5 - i, i === 0 ? '#fbf6ea' : '#8a5a3a'); }
  for (let i = 0; i < 12; i++) { c.set(cx - 13 + i, top - 5 - i, '#fbf6ea'); c.set(cx + 12 - i, top - 5 - i, '#fbf6ea'); } // alın tahtası
  c.ellipse(cx, top - 10, 2.5, 2.5, '#fbf6ea'); c.set(cx, top - 10, '#2a3a48');
  // kırma çatı ve geniş saçak, saçak altı oyma sarkıtlar
  for (let i = 0; i < 9; i++) c.hline(x0 - 4 + i, x0 + W + 3 - i, top - 1 - i, i === 0 ? '#5e3a2a' : i % 2 ? '#8a5a3a' : '#a06a44');
  for (let x = x0 - 3; x < x0 + W + 3; x += 3) { c.set(x, top, '#fbf6ea'); c.set(x, top + 1, '#e8dcc0'); }
  c.rect(x0 + 18, top - 15, 3, 7, '#9a4a36'); c.rect(x0 + 44, top - 14, 3, 6, '#9a4a36'); // bacalar
  // giriş merdiveni ve taraça
  c.rect(x0 - 4, base, W + 8, 2, '#d8ccb8'); c.rect(cx - 6, base - 6, 12, 6, '#2a3a48'); c.hline(cx - 7, cx + 6, base - 7, '#fbf6ea');
}

// ======================= simge: koru, erguvanlar, Sarı Köşk, lale tarhları (320×140) =======================
function landmark() {
  const W = 320, H = 140, c = new Canvas(W, H);
  const shore = H - 6;
  // yamaç: soldan sağa yükselen koru
  for (let x = 0; x < W; x++) {
    const top = 34 + Math.round(26 * (1 - x / W) + 8 * Math.sin(x * 0.05) + 4 * Math.sin(x * 0.17));
    for (let y = top; y < shore; y++) c.set(x, y, GREEN[hash(x >> 1, y >> 1, 3) < 0.35 ? 1 : 0]);
  }
  const r = rng(905);
  for (let k = 0; k < 90; k++) { // koru ağaçları
    const x = r() * W, y = 40 + r() * 70; tree(c, x, y + (1 - x / W) * 20, 5 + r() * 6, GREEN);
  }
  for (let k = 0; k < 9; k++) pine(c, 10 + k * 35 + r() * 10, 36 + r() * 18 + (k < 4 ? 20 : 0), 9 + r() * 4);
  for (let k = 0; k < 34; k++) { // açmış erguvanlar
    const x = r() * W, y = 56 + r() * 60; tree(c, x, y, 4 + r() * 5, ERGUVAN);
  }
  kosk(c, 186, 92);
  // çimen yamaç ve lale tarhları (önde, dalgalı şeritler)
  for (let y = 100; y < shore - 4; y++) for (let x = 0; x < W; x++) if (y > 104 + Math.sin(x * 0.04) * 4) c.set(x, y, hash(x, y, 7) < 0.2 ? GREEN[4] : GREEN[3]);
  for (let band = 0; band < 4; band++) {
    const col0 = band * 3;
    for (let x = 4; x < W - 4; x += 2) {
      const y = 108 + band * 6 + Math.round(Math.sin(x * 0.045 + band) * 3);
      const col = TULIPS[(Math.floor(x / 24) + col0) % TULIPS.length];
      c.set(x, y, col); c.set(x, y + 1, mix(col, '#000000', 0.2)); c.set(x, y + 2, '#3e6a2e');
    }
  }
  // sahil duvarı ve yol
  c.rect(0, shore - 4, W, 4, '#d8ccb8'); c.hline(0, W - 1, shore - 4, '#f2e8d8'); for (let x = 0; x < W; x += 8) c.vline(x, shore - 3, shore - 1, '#b8ac98');
  c.rect(0, shore, W, 2, '#8a8070');
  for (let x = 20; x < W; x += 40) { c.vline(x, shore - 14, shore - 5, '#2a3028'); c.rect(x - 1, shore - 16, 3, 2, '#f2f0e0'); }
  return c;
}

// ======================= orta plan: Emirgan–İstinye kıyısının yalıları ve korulu sırtlar (400×110) =======================
function midground() {
  const W = 400, H = 110, c = new Canvas(W, H);
  const yali = ['#8a3a2c', '#ece4d4', '#e8dcc0', '#b8c8a8', '#f2e2c8', '#9a5a3a'];
  c.wrap(o => {
    for (let x = 0; x < W; x++) {
      const top = H - 64 - Math.round(12 * Math.sin((x / W) * Math.PI * 2 + 1.7) + 5 * Math.sin((x / W) * Math.PI * 8));
      for (let y = top; y < H; y++) c.set(o + x, y, GREEN[hash(x >> 1, y >> 1, 11) < 0.3 ? 1 : 0]);
    }
    const r = rng(906);
    for (let k = 0; k < 70; k++) tree(c, o + r() * W, H - 30 - r() * 30, 3 + r() * 4, GREEN);
    for (let k = 0; k < 18; k++) tree(c, o + r() * W, H - 26 - r() * 26, 2.5 + r() * 3, ERGUVAN);
    for (let k = 0; k < 40; k++) { const x = r() * W, y = H - 34 - r() * 22; c.rect(o + x, y, 3, 2, r() < 0.5 ? '#f2ece0' : '#e8c890'); c.hline(o + x, o + x + 2, y - 1, '#a4503a'); }
    // su kenarında yalı sırası: geniş saçak, çıkma, kayıkhane
    for (let x = 0; x < W;) {
      const w = 18 + Math.floor(r() * 16), h = 12 + Math.floor(r() * 8), col = yali[Math.floor(r() * yali.length)];
      c.rect(o + x, H - h, w, h, col); for (let i = x; i < x + w; i += 2) c.vline(o + i, H - h, H - 5, mix(col, '#000000', 0.12));
      c.rect(o + x - 2, H - h - 2, w + 4, 2, '#7a3a2c'); c.hline(o + x - 2, o + x + w + 1, H - h - 3, '#a4503a');
      for (let i = x + 2; i < x + w - 2; i += 4) c.rect(o + i, H - h + 3, 2, 3, '#2a3a48');
      c.rect(o + x + 3, H - 4, w - 6, 4, '#3a2a22');
      x += w + 3 + Math.floor(r() * 5);
    }
  });
  return c;
}

// ======================= uzak plan: karşı kıyının pus içindeki tepeleri (400×110) =======================
function distant() {
  const W = 400, H = 110, c = new Canvas(W, H);
  c.wrap(o => {
    for (let x = 0; x < W; x++) {
      const h = 46 + Math.round(16 * Math.sin((x / W) * Math.PI * 2 + 0.3) + 6 * Math.sin((x / W) * Math.PI * 6));
      for (let y = H - h; y < H; y++) c.set(o + x, y, y < H - h + 1 ? '#d8e4dc' : y < H - h + 8 ? '#a8c4b8' : '#94b4a8');
    }
    const r = rng(907);
    for (let k = 0; k < 60; k++) { const x = Math.floor(r() * W), y = H - 4 - Math.floor(r() * 24); c.rect(o + x, y, 2, 2, r() < 0.5 ? '#e4ece4' : '#c4d4cc'); }
  });
  return c;
}

// ======================= kıyı: sahil yolu, banklar, oltacılar, fenerler (400×28) =======================
function waterfront() {
  const W = 400, c = new Canvas(W, 28), Y = 12;
  c.wrap(o => {
    c.rect(o, Y - 3, W, 4, '#d8ccb8'); c.hline(o, o + W - 1, Y - 4, '#f2e8d8');
    const r = rng(908);
    for (let x = 14; x < W; x += 40) { c.vline(o + x, Y - 12, Y - 4, '#2a3028'); c.rect(o + x - 1, Y - 14, 3, 2, '#f2f0e0'); }
    for (let x = 30; x < W; x += 50 + Math.floor(r() * 30)) { c.vline(o + x, Y - 9, Y - 4, '#3a3a40'); c.line(o + x, Y - 9, o + x + 8, Y - 14, '#6a6a70'); c.line(o + x + 8, Y - 14, o + x + 9, Y + 6, '#c8c8d0'); } // oltacılar
    for (let x = 60; x < W - 20; x += 90 + Math.floor(r() * 40)) { const bc = ['#f2f0e0', '#2f8f8a', '#e8574a'][Math.floor(r() * 3)]; c.rect(o + x, Y + 3, 10, 2, bc); c.rect(o + x + 1, Y + 5, 8, 1, mix(bc, '#1c2620', 0.5)); }
  });
  return c;
}

function build(outDir) {
  const d = `${outDir}/backgrounds/emirgan`;
  return [
    landmark().save(`${outDir}/landmarks/emirgan.png`),
    distant().save(`${d}/distant.png`),
    midground().save(`${d}/midground.png`),
    waterfront().save(`${d}/waterfront.png`),
    G.ferry({ white: '#f6f4ee', whiteS: '#c8ccd4', glass: '#2a3a48' }).save(`${d}/ferry.png`),
  ];
}

if (require.main === module) console.log(build(process.argv[2] || require('path').resolve(__dirname, '../../../assets/images/pixel_art')).join('\n'));

module.exports = { build, landmark, midground, waterfront, distant };

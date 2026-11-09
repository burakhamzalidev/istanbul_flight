// Üsküdar bölgesi (Phase 2.6.2, docs/19): akşamüstü, yumuşak ışık, Boğaz trafiği.
//
// Kamera: sudan doğuya, iskele meydanına bakış (Kız Kulesi bölgesinden farklı olarak meydanın kendisi). Önde vapur
// iskelesi ve rıhtım; yükseltilmiş sette Mihrimah Sultan (İskele) Camii: geniş çift revak (dış revakta geniş, eğimli
// saçak), tek kubbe ve yanlarda yarım kubbeler, iki minare. Arkada Üsküdar'ın yamaçtaki evleri, servi ağaçları ve
// tepede Çamlıca. Batan güneş kameranın arkasında: cepheler sıcak pembe-altın.
//
// Kaynaklar (en.wikipedia.org/wiki/Mihrimah_Sultan_Mosque,_Üsküdar; uskudar.bel.tr): Mimar Sinan, Kanuni'nin kızı
// Mihrimah Sultan için; 1543–44 ile 1548 arası. "Tek kubbeli baldaken, üç yarım kubbe", "geniş çift revak",
// "yükseltilmiş set", iki minare. Şerefe sayısı kaynaklarda doğrulanamadı: minareler tek şerefeyle çizildi.
//
// Ölçek: 1 px = 4 dünya birimi.
'use strict';
const { Canvas, mix, rng } = require('./lib');
const G = require('./galata');

const hash = (x, y, s = 0) => { let h = (x * 374761393 + y * 668265263 + s * 2147483647) >>> 0; h = ((h ^ (h >>> 13)) * 1274126177) >>> 0; return ((h ^ (h >>> 16)) >>> 0) / 4294967296; };
// akşamüstü: taş sıcak krem-pembe, gölgeler leylak, kurşun mavi-gri
const STONE = ['#7a6a84', '#9a8698', '#c4aaa8', '#e2c4b4', '#f2d8c0', '#fbe8d0'];
const LEAD = ['#4a4a64', '#5e5e7a', '#76768e', '#9494a8', '#b4b0c0'];
const GLASS = '#2a2440', GLASS_LIT = '#ffd090', GOLD = '#e8c06a';
const pick = (r, t) => r[Math.max(0, Math.min(r.length - 1, Math.floor(t * r.length)))];

function stone(c, x0, y0, w, h, l = 0.6) {
  for (let y = y0; y < y0 + h; y++) for (let x = x0; x < x0 + w; x++) {
    let col = pick(STONE, l - (x - x0) / Math.max(1, w) * 0.14 - (y - y0) / Math.max(1, h) * 0.08 + (hash(x >> 1, y >> 1, 4) - 0.5) * 0.06);
    if ((y - y0) % 5 === 4 && hash(x, y, 2) < 0.4) col = mix(col, STONE[1], 0.3); // derz
    c.set(x, y, col);
  }
}
function dome(c, cx, by, R, squash = 0.9) {
  for (let i = 0; i <= R; i++) {
    const hw = Math.round(Math.sqrt(R * R - i * i));
    for (let x = cx - hw; x <= cx + hw; x++) { const t = 0.75 - (x - cx + hw) / (2 * hw + 1) * 0.6 + (i / R) * 0.1; c.set(x, by - Math.round(i * squash), pick(LEAD, t)); }
  }
}
function minaret(c, mx, top, base) {
  for (let y = top + 16; y < base; y++) { c.set(mx - 2, y, STONE[5]); c.set(mx - 1, y, STONE[4]); c.set(mx, y, STONE[3]); c.set(mx + 1, y, STONE[2]); c.set(mx + 2, y, STONE[1]); }
  for (let y = top + 22; y < base; y += 10) c.hline(mx - 2, mx + 2, y, STONE[2]);
  const sh = top + 30;
  c.hline(mx - 4, mx + 4, sh, STONE[5]); c.hline(mx - 4, mx + 4, sh + 1, STONE[1]); for (let x = mx - 4; x <= mx + 4; x += 2) c.set(x, sh - 1, STONE[4]); c.hline(mx - 4, mx + 4, sh - 2, STONE[5]);
  c.hline(mx - 3, mx + 3, sh + 2, STONE[2]); c.hline(mx - 2, mx + 2, sh + 3, STONE[1]);
  for (let y = top + 8; y < top + 16; y++) { c.set(mx - 1, y, STONE[4]); c.set(mx, y, STONE[3]); c.set(mx + 1, y, STONE[2]); }
  for (let i = 0; i < 10; i++) { const hw = i < 3 ? 0 : i < 7 ? 1 : 2; for (let dx = -hw; dx <= hw; dx++) c.set(mx + dx, top + i - 2, pick(LEAD, 0.7 - (dx + 2) * 0.12)); }
  c.vline(mx, top - 6, top - 3, GOLD);
}

// ======================= Mihrimah Sultan (İskele) Camii =======================
function mosque(c, x0, base) {
  // set (yükseltilmiş platform) ve önündeki merdiven
  stone(c, x0 - 10, base - 10, 150, 10, 0.5);
  c.hline(x0 - 10, x0 + 139, base - 10, STONE[5]);
  for (let i = 0; i < 5; i++) c.hline(x0 + 54 - i * 2, x0 + 76 + i * 2, base - 9 + i * 2, i % 2 ? STONE[2] : STONE[4]);
  const floor = base - 10;
  // harim gövdesi ve kubbe sistemi: merkezi kubbe, iki yanda yarım kubbeler (basamaklı), köşe ağırlık kuleleri
  const hL = x0 + 20, hR = x0 + 110, hTop = floor - 62;
  stone(c, hL, hTop, hR - hL, floor - hTop, 0.62);
  for (const wy of [hTop + 8, hTop + 22]) for (let x = hL + 6; x < hR - 6; x += 10) { c.rect(x, wy, 4, 8, GLASS); c.hline(x + 1, x + 2, wy - 1, GLASS); if (hash(x, wy, 1) < 0.3) c.set(x + 1, wy + 3, GLASS_LIT); }
  for (const tx of [hL, hR - 6]) { stone(c, tx, hTop - 8, 6, 8, 0.7); for (let i = 0; i < 4; i++) c.hline(tx + 1 + (i >> 1), tx + 4 - (i >> 1), hTop - 9 - i, LEAD[2]); c.set(tx + 3, hTop - 13, GOLD); }
  const dcx = Math.round((hL + hR) / 2);
  dome(c, dcx - 30, hTop - 1, 13, 0.75); dome(c, dcx + 30, hTop - 1, 13, 0.75); // yan yarım kubbeler
  stone(c, dcx - 24, hTop - 12, 48, 12, 0.66); // kasnak
  for (let x = dcx - 21; x < dcx + 20; x += 6) { c.rect(x, hTop - 9, 3, 6, GLASS); c.set(x + 1, hTop - 10, GLASS); }
  dome(c, dcx, hTop - 13, 24, 0.85);
  c.vline(dcx, hTop - 40, hTop - 34, GOLD); c.set(dcx - 1, hTop - 38, GOLD); c.set(dcx + 1, hTop - 38, GOLD);
  // geniş çift revak: iç revak küçük kubbeli kemerler, dış revak geniş eğimli saçak ve ince sütunlar
  const pL = x0 + 6, pR = x0 + 124, pTop = floor - 30;
  stone(c, pL + 8, pTop, pR - pL - 16, 30, 0.55);
  for (let x = pL + 12; x < pR - 12; x += 13) { // iç revak kemerleri
    for (let j = 0; j < 5; j++) { const hw = Math.round(Math.sqrt(1 - ((5 - j) / 5) ** 2) * 5); c.hline(x + 5 - hw, x + 5 + hw, pTop + 8 + j, '#3a2e44'); }
    c.rect(x, pTop + 13, 11, 17, '#3a2e44'); c.rect(x + 2, pTop + 16, 7, 12, '#5a4a6a');
  }
  for (let x = pL + 14; x < pR - 10; x += 13) dome(c, x + 4, pTop, 5, 0.6); // iç revak kubbecikleri
  for (let i = 0; i < 8; i++) c.hline(pL - i, pR + i, pTop + 6 + i, i === 0 ? LEAD[4] : i < 6 ? pick(LEAD, 0.75 - i * 0.07) : LEAD[0]); // dış revak saçağı
  for (let x = pL - 4; x <= pR + 4; x += 9) { c.vline(x, pTop + 14, floor - 1, STONE[5]); c.vline(x + 1, pTop + 14, floor - 1, STONE[2]); c.set(x, pTop + 14, STONE[1]); } // dış revak sütunları
  c.rect(dcx - 6, floor - 8, 12, 6, '#d8e0e8'); c.hline(dcx - 7, dcx + 6, floor - 9, STONE[5]); // şadırvan (revak altında)
  // iki minare, revakın iki ucunda
  minaret(c, pL + 2, floor - 120, floor);
  minaret(c, pR - 2, floor - 120, floor);
}

// ======================= simge: iskele meydanı ve cami (320×180) =======================
function landmark() {
  const W = 320, H = 180, c = new Canvas(W, H);
  const quay = H - 6;
  // meydan zemini ve rıhtım
  c.rect(0, quay - 6, W, 6, '#d8c4b0'); c.hline(0, W - 1, quay - 6, '#f2e2d0'); for (let x = 0; x < W; x += 9) c.vline(x, quay - 5, quay - 1, '#b8a494');
  c.rect(0, quay, W, 2, '#8a7a74');
  // solda vapur iskelesi: kazıklar, saçaklı bekleme yeri
  c.rect(4, quay - 26, 54, 20, '#e8d8c8'); for (let x = 8; x < 54; x += 8) { c.rect(x, quay - 22, 5, 9, GLASS); c.set(x + 1, quay - 20, GLASS_LIT); }
  for (let i = 0; i < 6; i++) c.hline(2 - i, 60 + i, quay - 27 - i, i ? '#a8584a' : '#6e3a3e');
  for (let x = 6; x < 58; x += 6) c.vline(x, quay, quay + 4, '#3a2a30');
  // sağda çınarlar
  for (const [tx, s] of [[268, 1], [300, 0.8]]) { c.vline(tx, quay - 34 * s, quay - 7, '#6a5444'); for (let k = 0; k < 14; k++) c.ellipse(tx + (hash(k, tx, 1) - 0.5) * 22, quay - 34 * s - 4 + hash(k, tx, 2) * 14, 5, 3.5, (nx, ny) => nx < -0.2 && ny < 0 ? '#c8b070' : ny < 0.3 ? '#6a7a4a' : '#4a5a3a'); }
  mosque(c, 112, quay - 6);
  // suda yansıma
  for (let y = quay + 2; y < H; y++) for (let x = 100; x < 250; x++) if (hash(x >> 1, y, 6) < 0.35 && (x + y) % 3) c.set(x, y, mix('#f8d8b8', '#62709a', 0.4), 150);
  return c;
}

// ======================= orta plan: Üsküdar yamacı, serviler (400×110) =======================
function midground() {
  const W = 400, H = 110, c = new Canvas(W, H);
  const walls = ['#e8b0a0', '#f2d2a8', '#c8a8c0', '#e8c8b8', '#f6e2d0', '#d8b8a8'];
  c.wrap(o => {
    for (let x = 0; x < W; x++) { const top = H - 74 - Math.round(12 * Math.sin((x / W) * Math.PI * 2 + 2.4) + 5 * Math.sin((x / W) * Math.PI * 6)); for (let y = top; y < H; y++) c.set(o + x, y, hash(x >> 1, y >> 1, 31) < 0.3 ? '#6a6a5e' : '#5a5a54'); }
    const r = rng(926);
    for (let k = 0; k < 180; k++) { // sık yamaç evleri, pencerelerde akşam ışığı
      const x = Math.floor(r() * W), y = H - 2 - Math.floor(Math.pow(r(), 0.75) * 64), w = 4 + Math.floor(r() * 6), h = 3 + Math.floor(r() * 6), col = walls[Math.floor(r() * walls.length)];
      c.rect(o + x, y - h, w, h, col); c.vline(o + x, y - h, y - 1, mix(col, '#fff0d8', 0.35)); c.vline(o + x + w - 1, y - h, y - 1, mix(col, '#5a4a64', 0.3));
      c.hline(o + x - 1, o + x + w, y - h - 1, '#a8584a');
      for (let i = x + 1; i < x + w - 1; i += 2) c.set(o + i, y - h + 1, r() < 0.2 ? '#ffd090' : '#3a2e48');
    }
    for (let k = 0; k < 26; k++) { const x = Math.floor(r() * W), y = H - 20 - Math.floor(r() * 40), h = 8 + Math.floor(r() * 8); for (let j = 0; j < h; j++) { const hw = j < 2 ? 0 : j < h - 2 ? 1 : 0; c.hline(o + x - hw, o + x + hw, y - j, j % 3 ? '#2e3e30' : '#3e5040'); } } // serviler
  });
  return c;
}

// ======================= uzak plan: Çamlıca tepesi ve kulesi (400×110) =======================
function distant() {
  const W = 400, H = 110, c = new Canvas(W, H);
  c.wrap(o => {
    for (let x = 0; x < W; x++) { const h = 50 + Math.round(26 * Math.exp(-(((x - 200) / 90) ** 2)) + 4 * Math.sin((x / W) * Math.PI * 8)); for (let y = H - h; y < H; y++) c.set(o + x, y, y < H - h + 1 ? '#f2c8b0' : '#9a88a4'); }
    const r = rng(927);
    for (let k = 0; k < 60; k++) { const x = Math.floor(r() * W), y = H - 3 - Math.floor(r() * 30); c.rect(o + x, y, 2, 2, r() < 0.3 ? '#ffd8a8' : '#b4a0b4'); }
    c.rect(o + 198, H - 108, 5, 34, '#b8a4b8'); c.rect(o + 196, H - 92, 9, 6, '#c8b4c8'); c.vline(o + 200, H - 110, H - 108, '#c8b4c8'); // Çamlıca kulesi
  });
  return c;
}

// ======================= kıyı: rıhtım, yanaşan vapurlar, martılar (400×28) =======================
function waterfront() {
  const W = 400, c = new Canvas(W, 28), Y = 12;
  c.wrap(o => {
    c.rect(o, Y - 3, W, 4, '#d8c4b0'); c.hline(o, o + W - 1, Y - 4, '#f2e2d0');
    const r = rng(928);
    for (let x = 10; x < W; x += 36) { c.vline(o + x, Y - 12, Y - 4, '#3a2e40'); c.rect(o + x - 1, Y - 14, 3, 2, '#ffd090'); }
    for (let x = 40; x < W - 20; x += 120 + Math.floor(r() * 40)) { c.rect(o + x, Y - 1, 18, 3, '#3a2a30'); for (let p = 0; p < 5; p++) c.vline(o + x + p * 4, Y + 2, Y + 7, '#3a2a30'); } // küçük iskeleler
    for (let k = 0; k < 6; k++) { const x = Math.floor(r() * W), y = 1 + Math.floor(r() * 5); c.set(o + x, y, '#f6f0f0'); c.set(o + x - 1, y - 1, '#f6f0f0'); c.set(o + x + 1, y - 1, '#f6f0f0'); } // martılar
    for (let x = 6; x < W; x += 36) for (let y = Y + 1; y < 28; y += 2) if (hash(x, y, 9) < 0.65 - (y - Y) * 0.03) c.set(o + x + (y % 4 ? 0 : 1), y, '#ffd8a8', 160);
  });
  return c;
}

function build(outDir) {
  const d = `${outDir}/backgrounds/uskudar`;
  return [
    landmark().save(`${outDir}/landmarks/uskudar.png`),
    distant().save(`${d}/distant.png`),
    midground().save(`${d}/midground.png`),
    waterfront().save(`${d}/waterfront.png`),
    G.ferry({ white: '#f8e8d8', whiteS: '#c8b0b0', glass: '#ffd090' }).save(`${d}/ferry.png`),
  ];
}

if (require.main === module) console.log(build(process.argv[2] || require('path').resolve(__dirname, '../../../assets/images/pixel_art')).join('\n'));

module.exports = { build, landmark, midground, waterfront, distant };

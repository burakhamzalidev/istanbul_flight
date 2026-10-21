// Boğaz Köprüsü (15 Temmuz Şehitler Köprüsü) bölgesi: gerçek referanslara dayalı yeniden çizim (docs/12).
//
// Kamera: Ortaköy'ün güneyinde, Avrupa kıyısına yakın sudan kuzeye bakış.
// Önde Ortaköy (Büyük Mecidiye) Camii kıyıdaki platformunda; arkasında Avrupa kulesi ve kareyi neredeyse yatay geçen
// tabliye; ana kablo uzaktaki Anadolu kulesine doğru sarkar; arkada Beylerbeyi–Çengelköy yamaçları.
// Saat: akşam. Kuleler ve kablolar LED ile aydınlatılmış (2007'den beri renk değiştiren sistem; burada mavi-mor),
// tabliyede sıcak ışık dizisi, cami projektörle sıcak sarı.
//
// Ölçü (Wikipedia): kule 165 m, orta açıklık 1.074 m, toplam 1.560 m, tabliye denizden 64 m (kulenin ≈ %39'u),
// çelik kuleler, EĞİK askılar (zikzak), 1973.
// Ortaköy Camii: Garabet ve Nikoğos Balyan, 1850'ler; tek kubbe, iki ince minare (tek şerefe), önünde iki katlı
// hünkâr dairesi. Kaynaklar ve lisanslar: docs/12_kopru_gercek_referans.md
'use strict';
const { Canvas, mix, rng } = require('./lib');
const G = require('./galata');

const hash = (x, y, s = 0) => { let h = (x * 374761393 + y * 668265263 + s * 2147483647) >>> 0; h = ((h ^ (h >>> 13)) * 1274126177) >>> 0; return ((h ^ (h >>> 16)) >>> 0) / 4294967296; };
const pick = (r, t) => r[Math.max(0, Math.min(r.length - 1, Math.floor(t * r.length)))];

const INK = '#100e22';
const STEEL = ['#2a2f5a', '#3a4274', '#56609a', '#7f8cc8', '#a9b8f0']; // LED ışığında çelik (mavi-mor)
const LED = '#7f9cff', LED2 = '#b48cff', BEAD = '#ffd27a';
const MOSQUE = ['#6a4a3a', '#8e6a4e', '#b98c5e', '#d9ab6e', '#f0c886', '#ffe2a8']; // projektörle aydınlatılmış taş
const MLEAD = ['#2a2c48', '#3c3e5e', '#54567a', '#6e7096'];

// ======================= Ortaköy Camii (simgenin içinde, önde) =======================
function mosque(c, x0, water) {
  // (taban: Ortaköy meydanının kara çıkıntısı, landmark() içinde çizilir; `water` burada meydan zemininin 4 px altı)
  // hünkâr dairesi: iki katlı, önde, pencere sıraları
  const pL = x0, pR = x0 + 26, pTop = water - 30;
  for (let y = pTop; y < water - 4; y++) for (let x = pL; x < pR; x++) c.set(x, y, pick(MOSQUE, 0.62 - (x - pL) / 26 * 0.2 + (y < pTop + 2 ? 0.15 : 0)));
  for (const wy of [pTop + 6, pTop + 16]) for (let x = pL + 3; x < pR - 2; x += 4) { c.rect(x, wy, 2, 5, '#2b2440'); c.set(x, wy + 1, '#ffcf80'); }
  c.hline(pL - 1, pR, pTop, MOSQUE[5]); c.hline(pL, pR - 1, pTop + 13, MOSQUE[2]);
  // harim: yüksek kemerli pencereler, köşe kuleleri, kasnak ve kubbe
  const hL = x0 + 26, hR = x0 + 70, hTop = water - 50;
  for (let y = hTop; y < water - 4; y++) for (let x = hL; x < hR; x++) c.set(x, y, pick(MOSQUE, 0.78 - (x - hL) / 44 * 0.35 + (hash(x >> 1, y >> 1, 7) - 0.5) * 0.06));
  for (const ax of [hL + 7, hL + 17, hL + 27, hL + 35]) { c.rect(ax, hTop + 10, 4, 18, '#2b2440'); c.hline(ax + 1, ax + 2, hTop + 9, '#2b2440'); c.rect(ax + 1, hTop + 12, 2, 14, '#5a4a7a'); c.set(ax + 1, hTop + 14, '#ffcf80'); }
  c.rect(hL + 6, water - 14, 32, 2, MOSQUE[2]); // alt silme
  for (const tx of [hL, hR - 5]) { for (let y = hTop - 10; y < hTop; y++) for (let x = tx; x < tx + 5; x++) c.set(x, y, pick(MOSQUE, 0.7)); for (let i = 0; i < 4; i++) c.hline(tx + 1 + (i >> 1), tx + 3 - (i >> 1), hTop - 11 - i, MLEAD[2]); }
  c.hline(hL - 1, hR, hTop - 1, MOSQUE[5]);
  // kasnak (büyük pencereli) ve kubbe
  const dcx = (hL + hR) / 2;
  for (let y = hTop - 9; y < hTop; y++) for (let x = dcx - 15; x < dcx + 15; x++) c.set(x, y, pick(MOSQUE, 0.72 - (x - dcx + 15) / 30 * 0.3));
  for (let x = dcx - 12; x < dcx + 12; x += 5) c.rect(x, hTop - 7, 2, 5, '#2b2440');
  for (let i = 0; i < 13; i++) { const hw = Math.round(14 * Math.sqrt(1 - (i / 13) ** 2)); for (let x = dcx - hw; x < dcx + hw; x++) c.set(x, hTop - 10 - i, pick(MLEAD, 0.85 - (x - dcx + hw) / (2 * hw) * 0.7)); }
  c.vline(dcx, hTop - 27, hTop - 23, '#e7c463');
  // iki ince minare (solda, harimin arkasında), tek şerefe, kurşun külah
  for (const mx of [x0 + 18, x0 + 26]) {
    for (let y = water - 118; y < hTop + 2; y++) { c.set(mx - 1, y, MOSQUE[4]); c.set(mx, y, MOSQUE[3]); c.set(mx + 1, y, MOSQUE[1]); }
    c.hline(mx - 2, mx + 2, water - 96, MOSQUE[5]); c.hline(mx - 2, mx + 2, water - 95, INK); // şerefe
    for (let i = 0; i < 10; i++) { const hw = i < 4 ? 0 : 1; for (let dx = -hw; dx <= hw; dx++) c.set(mx + dx, water - 128 + i, MLEAD[dx < 0 ? 3 : 1]); }
    c.set(mx, water - 129, '#e7c463');
  }
}

// ======================= köprü + cami (480×200) =======================
function landmark() {
  const W = 480, H = 200, c = new Canvas(W, H);
  const water = H - 6;
  // yakın (Avrupa) kule x=44, 176 px; uzak (Anadolu) kule x=446, 112 px (perspektif)
  const nX = 44, nTop = water - 176, nDeck = water - 68;
  const fX = 446, fTop = water - 112, fDeck = water - 44;
  const deckY = x => Math.round(nDeck + (fDeck - nDeck) * ((x - nX) / (fX - nX)));

  // --- kule: yandan bakışta iki ayak üst üste, enine kirişler; LED ışık şeritleri ---
  const tower = (tx, top, deck, w) => {
    for (let y = top; y < water; y++) for (let x = tx - w; x <= tx + w; x++) c.set(x, y, pick(STEEL, x === tx - w ? 0.85 : x === tx + w ? 0.15 : 0.45));
    const h = water - top;
    for (const f of [0, 0.22, 0.48, 0.7]) { const y = Math.round(top + f * h); c.hline(tx - w - 1, tx + w + 1, y, STEEL[3]); c.hline(tx - w - 1, tx + w + 1, y + 1, STEEL[1]); }
    for (let y = top + 2; y < water; y += 3) c.set(tx - w, y, LED); // LED şerit
    c.set(tx, top - 1, '#ff4a4a'); // uçak ikaz ışığı
  };

  // --- ana kablo: yakın kule tepesinden uzak kule tepesine sarkan eğri (orta noktada tabliyeye yaklaşır) ---
  const cableY = x => {
    const t = (x - nX) / (fX - nX);
    const straight = nTop + 2 + (fTop + 2 - nTop - 2) * t;
    const sag = 4 * t * (1 - t) * ((deckY(nX + (fX - nX) * 0.5) - 4) - (nTop + fTop) / 2);
    return Math.round(straight + sag);
  };
  // eğik askılar (zikzak): kablodan tabliyeye, yönü her askıda değişir
  for (let x = nX + 3, k = 0; x < fX - 2; x += 4, k++) {
    const cy = cableY(x), dy = deckY(x), dx = k % 2 ? 2 : -2;
    if (dy - cy > 3) c.line(x, cy + 1, x + dx, dy - 1, mix(STEEL[2], '#000000', 0.25));
  }
  // yan açıklık kablosu: yakın kuleden sola, ankraja doğru iner
  for (let x = 0; x < nX; x++) { const y = Math.round(nTop + 2 + (nDeck - 6 - nTop - 2) * Math.pow((nX - x) / nX, 0.8)); c.set(x, y, STEEL[3]); if (x % 4 === 0 && y + 2 < nDeck) c.line(x, y + 1, x + 2, nDeck - 1, mix(STEEL[2], '#000000', 0.3)); }
  for (let x = nX; x < fX; x++) { const y = cableY(x); c.set(x, y, STEEL[4]); c.set(x, y + 1, STEEL[2]); if ((x - nX) % 9 === 0) c.set(x, y, LED2); }
  // tabliye (kutu kesitli, aerodinamik): koyu kiriş + ışık dizisi; yaklaşım viyadüğü solda
  for (let x = 0; x < W; x++) {
    const y = x < nX ? nDeck : x > fX ? fDeck : deckY(x), th = x < fX ? 4 : 3;
    c.vline(x, y, y + th - 1, '#1c1f3e'); c.set(x, y, STEEL[3]);
    if (x % 5 === 0) c.set(x, y + 1, BEAD);
    c.set(x, y + th, mix(LED, '#000000', 0.45));
  }
  for (let x = 6; x < nX - 4; x += 16) c.rect(x, nDeck + 4, 3, water - nDeck - 4, '#22243e'); // viyadük ayakları (Ortaköy tarafı)
  tower(nX, nTop, nDeck, 2);
  tower(fX, fTop, fDeck, 1);
  for (let x = fX; x < W; x++) { const y = Math.round(fTop + 2 + (fDeck - 4 - fTop - 2) * Math.pow((x - fX) / (W - fX), 0.8)); c.set(x, y, STEEL[3]); }

  // --- Ortaköy meydanının denize uzanan kara çıkıntısı (Avrupa kıyısı): cami bunun ucunda, karada durur ---
  const plaza = water - 9; // meydan zemini
  const groundTop = x => (x < 12 ? Math.round(water - 3 - (x / 12) * 6) : plaza);
  const tipX = 110; // çıkıntının denize bakan ucu (rıhtım duvarı)
  for (let x = 0; x < tipX; x++) {
    const top = groundTop(x);
    for (let y = top; y < water + 2; y++) c.set(x, y, y < top + 2 ? '#5a5068' : hash(x, y, 81) < 0.4 ? '#2c2840' : '#342e48'); // taş rıhtım ve dolgu
    if (x % 6 === 0) c.vline(x, top + 2, water, '#262238');
  }
  c.hline(12, tipX - 1, plaza, '#8a7c88'); // meydan kenar taşı (ışık alır)
  for (let y = plaza; y < water + 2; y++) { c.set(tipX - 1, y, '#6a5e70'); c.set(tipX, y, '#1e1a30'); } // uç duvarı
  // meydanda ağaçlar ve Ortaköy'ün alçak evleri (solda, caminin arkasında kalan kısım)
  for (const [hx, hw, hh] of [[0, 9, 14], [8, 8, 18]]) {
    c.rect(hx, plaza - hh, hw, hh, '#4a4470'); c.hline(hx, hx + hw - 1, plaza - hh - 1, '#2c2648');
    for (let i = hx + 2; i < hx + hw - 1; i += 3) for (let y = plaza - hh + 3; y < plaza - 2; y += 5) c.set(i, y, hash(i, y, 82) < 0.7 ? '#ffd27a' : '#2a2a4a');
  }
  for (const tx of [4, 16]) c.ellipse(tx, plaza - 4, 4, 4, (nx, ny) => (ny < -0.4 ? '#3a5040' : '#1c2a26'));
  for (let x = 30; x < tipX; x += 14) { c.vline(x, plaza - 6, plaza - 1, '#3a3658'); c.set(x, plaza - 7, '#ffe2a0'); } // meydan lambaları

  // --- Ortaköy Camii: çıkıntının ucunda, Avrupa kulesinin önünde ---
  mosque(c, 32, plaza + 4); // minareler kulenin hemen sağında (kaynak 1)
  return c;
}

// ======================= orta plan: Anadolu yakası yamaçları (Beylerbeyi–Çengelköy), akşam (400×80) =======================
function midground() {
  const W = 400, H = 80, c = new Canvas(W, H);
  const wood = ['#141c34', '#1a2440', '#22304e', '#30405e'];
  c.wrap(o => {
    for (let x = 0; x < W; x++) {
      const top = H - 52 - Math.round(10 * Math.sin((x / W) * Math.PI * 2 + 0.4) + 4 * Math.sin((x / W) * Math.PI * 6));
      for (let y = top; y < H; y++) c.set(o + x, y, wood[hash(x, y, 71) < 0.3 ? 1 : 0]);
      if (hash(x, 2, 72) < 0.4) c.set(o + x, top - 1, wood[2]);
    }
    const r = rng(701);
    // yamaçta evler ve yanan pencereler (akşam)
    for (let k = 0; k < 120; k++) {
      const x = Math.floor(r() * W), y = H - 8 - Math.floor(Math.pow(r(), 0.8) * 44), w = 3 + Math.floor(r() * 5);
      c.rect(o + x, y, w, 3, '#3a3a60'); c.hline(o + x, o + x + w - 1, y - 1, '#4a3560');
      if (r() < 0.7) c.set(o + x + 1, y + 1, '#ffd27a');
      if (r() < 0.3) c.set(o + x + w - 2, y + 1, '#ffe8b0');
    }
    // kıyıdaki yalı sırası
    for (let x = 0; x < W; x += 0) {
      const w = 10 + Math.floor(r() * 10), h = 6 + Math.floor(r() * 5);
      c.rect(o + x, H - h, w, h, '#4a4a78'); c.hline(o + x - 1, o + x + w, H - h - 1, '#2c2648');
      for (let i = x + 2; i < x + w - 1; i += 3) c.set(o + i, H - h + 2, r() < 0.65 ? '#ffd27a' : '#2a2a4a');
      x += w + 2 + Math.floor(r() * 6);
    }
  });
  return c;
}

// ======================= kıyı: Anadolu yakası sahil yolu (400×28) =======================
function waterfront() {
  const W = 400, c = new Canvas(W, 28), Y = 12;
  c.wrap(o => {
    c.rect(o, Y - 2, W, 2, '#2a2848');
    for (let x = 8; x < W; x += 22) { c.vline(o + x, Y - 7, Y - 3, '#3a3658'); c.set(o + x, Y - 8, '#ffe2a0'); }
    // ışıkların suda dikey, kesik yansımaları
    for (let x = 8; x < W; x += 22) for (let y = Y + 1; y < 28; y += 2) if (hash(x, y, 73) < 0.7 - (y - Y) * 0.03) c.set(o + x + (y % 4 === 0 ? 1 : 0), y, '#ffcf7a', 170);
  });
  return c;
}

// ======================= uzak plan: Anadolu yakasının arka tepeleri (400×110) =======================
function distant() {
  const W = 400, H = 110, c = new Canvas(W, H);
  c.wrap(o => {
    for (let x = 0; x < W; x++) {
      const h = 66 + Math.round(12 * Math.sin((x / W) * Math.PI * 2 + 2.2) + 5 * Math.sin((x / W) * Math.PI * 8));
      for (let y = H - h; y < H; y++) c.set(o + x, y, y < H - h + 1 ? '#5a4f86' : '#2c2b58');
    }
    const r = rng(702);
    for (let k = 0; k < 50; k++) c.set(o + Math.floor(r() * W), H - 6 - Math.floor(r() * 50), r() < 0.5 ? '#ffcf7a' : '#c8a870');
  });
  return c;
}

function build(outDir) {
  const d = `${outDir}/backgrounds/kopru`;
  return [
    landmark().save(`${outDir}/landmarks/bridge.png`),
    distant().save(`${d}/distant.png`),
    midground().save(`${d}/midground.png`),
    waterfront().save(`${d}/waterfront.png`),
    G.ferry({ white: '#8f8cae', whiteS: '#5c5a80', glass: '#ffd27a' }).save(`${d}/ferry.png`),
  ];
}

module.exports = { build, landmark, midground, waterfront, distant };

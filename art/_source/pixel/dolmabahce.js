// Dolmabahçe bölgesi (Phase 2.6.2, docs/19): öğleden sonra güneşi, saray cephesi, su yansımaları.
//
// Kamera: sudan batıya, sarayın deniz cephesine bakış. Uzun, simetrik, beyaz mermer cephe: güneyde Mabeyn (selamlık),
// ortada yüksek Muayede (Tören) Salonu ve kubbesi, kuzeyde Harem. Önde mermer rıhtım, ferforje korkuluk ve kapılar;
// cephenin güney ucunda Dolmabahçe Saat Kulesi. Arkada saray bahçelerinin ağaçları ve Beşiktaş–Maçka sırtları.
//
// Kaynaklar (en.wikipedia.org/wiki/Dolmabahçe_Palace, kulturenvanteri.com, ktb.gov.tr): Abdülmecid I yaptırdı;
// Garabet Balyan, oğlu Nigoğayos Balyan ve Evanis Kalfa; 1843–1853 (kaynaklarda 1856 da geçer). Tören Salonu'nun
// kubbesi 36 m yüksekliktedir. Saat Kulesi'ni Abdülhamid II yaptırdı, Sarkis Balyan tasarladı (1890–1895).
// Cephe tek tek kopyalanmadı: oranlar ve bölümler korunarak sadeleştirildi.
//
// Ölçek: 1 px = 4 dünya birimi.
'use strict';
const { Canvas, mix, rng } = require('./lib');
const G = require('./galata');

const hash = (x, y, s = 0) => { let h = (x * 374761393 + y * 668265263 + s * 2147483647) >>> 0; h = ((h ^ (h >>> 13)) * 1274126177) >>> 0; return ((h ^ (h >>> 16)) >>> 0) / 4294967296; };
// öğleden sonra ışığı sağdan (güneybatı); mermer sıcak beyaz, gölgeler soğuk leylak
const M = ['#8a8498', '#aaa4b4', '#cfc8cc', '#ece4dc', '#f8f0e4', '#fff8ec'];
const GOLD = '#d8a83a', GOLD_HI = '#fff0b0', GLASS = '#2a3048', GLASS_HI = '#9ab8d8', LEAD = ['#5a5e70', '#767a8c', '#9498a8'];

function marbleRect(c, x0, y0, w, h, light = 0.62) {
  for (let y = y0; y < y0 + h; y++) for (let x = x0; x < x0 + w; x++) {
    const t = light + (x - x0) / Math.max(1, w) * 0.12 - (y - y0) / Math.max(1, h) * 0.08 + (hash(x >> 1, y >> 1, 5) - 0.5) * 0.04;
    c.set(x, y, M[Math.max(0, Math.min(M.length - 1, Math.floor(t * M.length)))]);
  }
}
/** Bir cephe bölmesi: kemerli pencere, iki yanında sütun, üstte alınlık ya da kartuş. */
function bay(c, x, y, h, { pediment = false, tall = false }) {
  const wh = tall ? h - 10 : h - 8, ww = 6;
  c.rect(x, y + 4, ww, wh, GLASS); c.set(x, y + 4, GLASS_HI); c.set(x + 1, y + 5, GLASS_HI);
  c.hline(x + 1, x + ww - 2, y + 3, GLASS); c.vline(x + 3, y + 4, y + 3 + wh, mix(GLASS, M[4], 0.4));
  for (let j = 0; j < 3; j++) c.set(x + 2 + j, y + 2, M[5]); c.hline(x - 1, x + ww, y + 4 + wh, M[5]);
  for (const sx of [x - 3, x + ww + 1]) { c.vline(sx, y, y + h - 1, M[5]); c.vline(sx + 1, y, y + h - 1, M[1]); c.set(sx, y, GOLD); } // sütunlar, yaldız başlık
  if (pediment) { for (let i = 0; i < 4; i++) c.hline(x - 2 + i, x + ww + 1 - i, y - 1 - i, i === 0 ? M[1] : M[5]); }
}
function facade(c, x0, x1, base, h, { tallMid = false } = {}) {
  marbleRect(c, x0, base - h, x1 - x0, h);
  const floorH = Math.floor(h / 2);
  for (let fl = 0; fl < 2; fl++) {
    const y = base - h + fl * floorH + 2;
    for (let x = x0 + 6, k = 0; x < x1 - 8; x += 12, k++) bay(c, x, y, floorH - 3, { pediment: fl === 0 && k % 3 === 1, tall: tallMid });
    c.hline(x0, x1 - 1, base - h + (fl + 1) * floorH, M[5]); c.hline(x0, x1 - 1, base - h + (fl + 1) * floorH + 1, M[1]); // kat silmesi
  }
  // saçak: korniş, dişler, balüstrat ve vazolar
  c.hline(x0 - 2, x1 + 1, base - h - 1, M[5]); c.hline(x0 - 2, x1 + 1, base - h, M[1]);
  for (let x = x0; x < x1; x += 2) c.set(x, base - h + 1, M[2]);
  for (let x = x0; x < x1; x += 3) { c.vline(x, base - h - 5, base - h - 2, M[4]); c.set(x + 1, base - h - 3, M[2]); }
  c.hline(x0 - 1, x1, base - h - 6, M[5]);
  for (let x = x0 + 4; x < x1; x += 24) { c.rect(x, base - h - 10, 3, 4, M[4]); c.set(x + 1, base - h - 11, GOLD); }
}

// ======================= simge: saray cephesi + Saat Kulesi (400×140) =======================
function landmark() {
  const W = 400, H = 140, c = new Canvas(W, H);
  const quay = H - 8, base = quay - 4;
  // arka: saray bahçelerinin ağaçları ve Beşiktaş sırtı
  for (let x = 0; x < W; x++) { const top = 34 + Math.round(10 * Math.sin(x * 0.02 + 1) + 4 * Math.sin(x * 0.09)); for (let y = top; y < base; y++) c.set(x, y, hash(x >> 1, y >> 1, 9) < 0.3 ? '#4a6e3a' : '#3a5a32'); }
  const r = rng(915);
  for (let k = 0; k < 70; k++) { const x = r() * W, y = 36 + r() * 30; c.ellipse(x, y, 5 + r() * 6, 4, (nx, ny) => nx > 0.3 && ny < 0 ? '#c8c86a' : ny < 0 ? '#6a9a44' : '#3e6a34'); }
  // Saat Kulesi (güney ucu, solda): dört kat, saat kadranları, fener biçimli tepe
  const tx = 18, tw = 14;
  marbleRect(c, tx, base - 74, tw, 74, 0.66);
  for (const y of [base - 54, base - 34, base - 14]) { c.hline(tx - 1, tx + tw, y, M[5]); c.hline(tx - 1, tx + tw, y + 1, M[1]); }
  c.ellipse(tx + tw / 2, base - 62, 4.5, 4.5, '#fbf6ee'); c.ellipse(tx + tw / 2, base - 62, 3.5, 3.5, '#fffaf0'); c.vline(tx + 7, base - 65, base - 62, '#1e1c28'); c.hline(tx + 7, tx + 9, base - 62, '#1e1c28');
  for (let i = 0; i < 4; i++) c.set(tx + 7 + Math.round(4 * Math.cos(i * 1.57)), base - 62 + Math.round(4 * Math.sin(i * 1.57)), GOLD);
  for (const y of [base - 46, base - 26]) { c.rect(tx + 4, y, 6, 9, GLASS); c.set(tx + 4, y, GLASS_HI); }
  c.rect(tx + 2, base - 80, tw - 4, 6, M[4]); for (let i = 0; i < 6; i++) c.hline(tx + 3 + (i >> 1), tx + tw - 4 - (i >> 1), base - 81 - i, LEAD[1]); c.vline(tx + 7, base - 91, base - 87, GOLD);
  // Mabeyn (güney kanadı), Muayede Salonu (orta, yüksek), Harem (kuzey kanadı)
  facade(c, 44, 170, base, 40);
  facade(c, 230, 380, base, 40);
  facade(c, 170, 230, base, 58, { tallMid: true });
  // Tören salonunun kubbesi (arkada, alçak ve geniş; kurşun) ve tepe alemi
  const dcx = 200;
  for (let i = 0; i <= 14; i++) { const hw = Math.round(Math.sqrt(1 - (i / 14) ** 2) * 26); for (let x = dcx - hw; x <= dcx + hw; x++) c.set(x, base - 66 - i, LEAD[Math.min(2, Math.floor(((x - dcx + hw) / (2 * hw + 1)) * 2.4 + 0.4))]); }
  c.vline(dcx, base - 85, base - 81, GOLD); c.set(dcx, base - 86, GOLD_HI);
  // orta kısımda alınlık ve yaldızlı arma kartuşu (sembolsüz)
  for (let i = 0; i < 8; i++) c.hline(186 + i, 213 - i, base - 59 - i, i === 0 ? M[1] : M[5]);
  c.ellipse(200, base - 62, 3, 2.5, GOLD); c.set(200, base - 62, GOLD_HI);
  // rıhtım: mermer, ferforje korkuluk, kapılar (yaldızlı ayaklar)
  c.rect(0, base, W, 4, M[4]); c.hline(0, W - 1, base, M[5]);
  for (let x = 0; x < W; x++) { c.set(x, quay, M[2]); c.set(x, quay + 1, M[1]); }
  for (let x = 30; x < W; x += 2) c.vline(x, base - 5, base - 1, '#1e2230'); c.hline(30, W - 1, base - 6, '#1e2230');
  for (let x = 60; x < W; x += 60) { // deniz kapıları: iki mermer ayak, yaldızlı tepelikler, ferforje kanat
    c.rect(x - 1, base - 12, 3, 12, M[4]); c.rect(x + 13, base - 12, 3, 12, M[4]); c.set(x, base - 13, GOLD); c.set(x + 14, base - 13, GOLD);
    for (let k = x + 2; k < x + 13; k += 2) c.vline(k, base - 10, base - 1, '#1e2230');
    for (let i = 0; i < 6; i++) c.set(x + 2 + i, base - 10 - Math.round(Math.sin(i / 5 * Math.PI) * 2), GOLD), c.set(x + 12 - i, base - 10 - Math.round(Math.sin(i / 5 * Math.PI) * 2), GOLD);
  }
  // su yansıması: cephenin kırık, sıcak ışıklı izi
  for (let y = quay + 2; y < H; y++) for (let x = 44; x < 380; x++) if (hash(x >> 1, y, 3) < 0.4 && (x + y) % 3) c.set(x, y, mix('#f6e2c0', '#2a7698', 0.35), 160);
  return c;
}

// ======================= orta plan: Beşiktaş–Maçka sırtları ve apartmanları (400×110) =======================
function midground() {
  const W = 400, H = 110, c = new Canvas(W, H);
  const walls = ['#f2e2c8', '#e8d0b0', '#d8c8c0', '#f6ead8', '#c8b8a8', '#e8c8a8'];
  c.wrap(o => {
    for (let x = 0; x < W; x++) { const top = H - 70 - Math.round(10 * Math.sin((x / W) * Math.PI * 2 + 0.4)); for (let y = top; y < H; y++) c.set(o + x, y, hash(x >> 1, y >> 1, 21) < 0.3 ? '#5a7a48' : '#4a6a3e'); }
    const r = rng(916);
    for (let k = 0; k < 130; k++) {
      const x = Math.floor(r() * W), y = H - 4 - Math.floor(Math.pow(r(), 0.8) * 56), w = 4 + Math.floor(r() * 7), h = 4 + Math.floor(r() * 8), col = walls[Math.floor(r() * walls.length)];
      c.rect(o + x, y - h, w, h, col); c.vline(o + x + w - 1, y - h, y - 1, mix(col, '#ffe6b0', 0.3)); c.vline(o + x, y - h, y - 1, mix(col, '#5a5468', 0.3));
      for (let i = x + 1; i < x + w - 1; i += 2) for (let j = y - h + 1; j < y - 1; j += 2) c.set(o + i, j, '#3a3e58');
    }
    for (let k = 0; k < 40; k++) c.ellipse(o + r() * W, H - 8 - r() * 40, 3 + r() * 3, 2.5, (nx, ny) => nx > 0.3 ? '#a8b860' : '#4a7a3a');
  });
  return c;
}

// ======================= uzak plan: karşı kıyı (Üsküdar–Kuzguncuk) ve Çamlıca, pus (400×110) =======================
function distant() {
  const W = 400, H = 110, c = new Canvas(W, H);
  c.wrap(o => {
    for (let x = 0; x < W; x++) { const h = 40 + Math.round(18 * Math.sin((x / W) * Math.PI * 2 + 2.0) + 4 * Math.sin((x / W) * Math.PI * 10)); for (let y = H - h; y < H; y++) c.set(o + x, y, y < H - h + 1 ? '#e8dcd0' : '#b0a4ac'); }
    const r = rng(917);
    for (let k = 0; k < 80; k++) { const x = Math.floor(r() * W), y = H - 3 - Math.floor(r() * 26); c.rect(o + x, y, 2, 2, r() < 0.5 ? '#d8ccc8' : '#c0b4b8'); }
    c.vline(o + 120, H - 96, H - 56, '#b8acb4'); c.rect(o + 118, H - 80, 5, 6, '#c8bcc4'); // Çamlıca kulesi (uzak)
  });
  return c;
}

// ======================= kıyı: mermer rıhtım, ferforje korkuluk (400×28) =======================
function waterfront() {
  const W = 400, c = new Canvas(W, 28), Y = 12;
  c.wrap(o => {
    c.rect(o, Y - 3, W, 4, '#f2ece2'); c.hline(o, o + W - 1, Y - 4, '#ffffff');
    for (let x = 0; x < W; x += 2) c.vline(o + x, Y - 9, Y - 5, '#1e2230'); c.hline(o, o + W - 1, Y - 10, '#1e2230');
    for (let x = 0; x < W; x += 25) { c.rect(o + x, Y - 12, 3, 8, '#f2ece2'); c.set(o + x + 1, Y - 13, GOLD); }
    for (let x = 12; x < W; x += 50) for (let y = Y + 1; y < 28; y += 2) if (hash(x, y, 2) < 0.7 - (y - Y) * 0.04) c.set(o + x + (y % 4 ? 0 : 1), y, '#ffe6a8', 170); // güneş parıltıları
  });
  return c;
}

function build(outDir) {
  const d = `${outDir}/backgrounds/dolmabahce`;
  return [
    landmark().save(`${outDir}/landmarks/dolmabahce.png`),
    distant().save(`${d}/distant.png`),
    midground().save(`${d}/midground.png`),
    waterfront().save(`${d}/waterfront.png`),
    G.ferry({ white: '#fbf2e2', whiteS: '#d0c4b8', glass: '#2a3048' }).save(`${d}/ferry.png`),
  ];
}

if (require.main === module) console.log(build(process.argv[2] || require('path').resolve(__dirname, '../../../assets/images/pixel_art')).join('\n'));

module.exports = { build, landmark, midground, waterfront, distant };

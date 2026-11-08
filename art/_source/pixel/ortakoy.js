// Ortaköy bölgesi (Phase 2.6, docs/19 §3): açık öğle, canlı deniz.
//
// Kamera: Ortaköy meydanının güneyinde, sudan kuzeybatıya bakış (Boğaz Köprüsü bölgesinden farklı olarak yakın plan
// ve gündüz). Önde Büyük Mecidiye (Ortaköy) Camii meydanın denize uzanan çıkıntısında; solda hünkâr kasrı ve iki ince
// minare; arkada köprünün Avrupa kulesi ve kareyi geçen tabliye; geride Ortaköy–Kuruçeşme yamacı ve Yıldız korusu,
// karşıda pus içinde Beylerbeyi–Çengelköy tepeleri.
//
// Cami (kaynaklar: en.wikipedia.org/wiki/Ortaköy_Mosque, kulturenvanteri.com, archnet.org): Sultan Abdülmecid için
// Garabet ve Nigoğos Balyan, 1850'ler; Neo-Barok; tek kubbe kasnak üstünde, iki katlı büyük kemerli pencereler, köşe
// payeleri, hünkâr kasrı, iki ince tek şerefeli minare. Beyaz kesme taş, kurşun kubbe. Köprü: 1973, çelik kuleler,
// tabliye denizden 64 m (docs/12).
//
// Ölçek: 1 px = 4 dünya birimi (diğer arka plan katmanlarıyla aynı).
'use strict';
const { Canvas, mix, rng, bayer } = require('./lib');
const G = require('./galata');

const hash = (x, y, s = 0) => { let h = (x * 374761393 + y * 668265263 + s * 2147483647) >>> 0; h = ((h ^ (h >>> 13)) * 1274126177) >>> 0; return ((h ^ (h >>> 16)) >>> 0) / 4294967296; };
const pick = (r, t) => r[Math.max(0, Math.min(r.length - 1, Math.floor(t * r.length)))];

// öğle ışığı sağ üstten (güneş x 0.62): gölgeler soğuk mavi, ışıklar sıcak beyaz
const STONE = ['#6e7c94', '#8e9cb2', '#b4bfcc', '#d6dce2', '#eceee9', '#fbf8ef', '#ffffff'];
const LEAD = ['#46506a', '#5c6884', '#76829c', '#97a2b8', '#b8c2d2'];
const GLASS = '#2a3a58', GLASS_HI = '#8fb4dc', GOLD = '#e7c463', INK = '#1a2030';
const STEEL = ['#8e98ac', '#a8b2c4', '#c4ccd8', '#dde3ea']; // köprü gündüz: açık gri çelik

// ======================= Büyük Mecidiye Camii =======================
/** Kemerli pencere (çerçeveli, iki kanat, üstte yarım daire). */
function archWin(c, x, y, w, h, frame = STONE[6]) {
  const r = Math.floor(w / 2), cx = x + (w - 1) / 2;
  for (let j = 0; j <= r; j++) for (let i = -r - 1; i <= r + 1; i++) {
    const d = Math.hypot(i, j);
    if (d <= r + 1.2) c.set(Math.round(cx + i), y - j, d > r - 0.2 ? frame : (i + j < 0 ? GLASS_HI : GLASS));
  }
  c.rect(x - 1, y, w + 2, h, frame);
  c.rect(x, y, w, h - 1, GLASS);
  for (let j = 0; j < h - 1; j += 4) c.hline(x, x + w - 1, y + j, mix(GLASS, frame, 0.35)); // kayıtlar
  c.vline(Math.round(cx), y - r + 1, y + h - 2, mix(GLASS, frame, 0.5));
  c.set(x, y, GLASS_HI); c.set(x + 1, y + 1, GLASS_HI);
}
/** Taş yüzey: üstten alta hafif koyulaşan, sağdan (güneş) aydınlanan, ince derz dokulu. */
function stoneFace(c, x0, y0, w, h, light = 0.7) {
  for (let y = y0; y < y0 + h; y++) for (let x = x0; x < x0 + w; x++) {
    const t = light + (x - x0) / w * 0.18 - (y - y0) / h * 0.12 + (hash(x >> 1, y >> 1, 9) - 0.5) * 0.06;
    let col = pick(STONE, t);
    if ((y - y0) % 6 === 5 && bayer(x, y) < 0.35) col = mix(col, STONE[1], 0.25); // derz izi
    c.set(x, y, col);
  }
}
function mosque(c, base) {
  // ---- hünkâr kasrı: iki katlı, düz damlı, iki sıra pencere (solda, karaya bakan taraf) ----
  const kL = 96, kR = 152, kTop = base - 46;
  stoneFace(c, kL, kTop, kR - kL, base - kTop, 0.55);
  c.hline(kL - 2, kR + 1, kTop - 1, STONE[6]); c.hline(kL - 2, kR + 1, kTop, STONE[4]); c.hline(kL - 1, kR, kTop + 1, STONE[1]); // saçak silmesi
  c.hline(kL - 1, kR, kTop + 22, STONE[5]); c.hline(kL, kR - 1, kTop + 23, STONE[2]); // kat silmesi
  for (const wy of [kTop + 6, kTop + 28]) for (let x = kL + 5; x < kR - 6; x += 9) { c.rect(x - 1, wy - 1, 7, 12, STONE[6]); c.rect(x, wy, 5, 10, GLASS); c.vline(x + 2, wy, wy + 9, mix(GLASS, STONE[5], 0.5)); c.set(x, wy, GLASS_HI); c.hline(x - 2, x + 6, wy + 11, STONE[5]); }
  // ---- iki ince minare (kasrın kara tarafı köşelerinde), tek şerefe, kurşun külah ----
  for (const [mx, top] of [[104, 40], [118, 46]]) { // uçları tabliyenin altında (kaynak fotoğraflarla tutarlı)
    for (let y = top + 18; y < kTop + 2; y++) { c.set(mx - 2, y, STONE[2]); c.set(mx - 1, y, STONE[4]); c.set(mx, y, STONE[5]); c.set(mx + 1, y, STONE[6]); c.set(mx + 2, y, STONE[3]); }
    for (let y = top + 18; y < kTop; y += 9) c.hline(mx - 2, mx + 2, y, STONE[3]); // gövde bilezikleri
    const sh = top + 34; // şerefe: dışa taşan balkon, korkuluk, altında mukarnas
    c.hline(mx - 4, mx + 4, sh, STONE[6]); c.hline(mx - 4, mx + 4, sh + 1, STONE[2]);
    for (let x = mx - 4; x <= mx + 4; x += 2) c.set(x, sh - 1, STONE[5]); c.hline(mx - 4, mx + 4, sh - 2, STONE[6]);
    c.hline(mx - 3, mx + 3, sh + 2, STONE[3]); c.hline(mx - 2, mx + 2, sh + 3, STONE[2]);
    for (let y = top + 8; y < top + 18; y++) { c.set(mx - 1, y, STONE[4]); c.set(mx, y, STONE[5]); c.set(mx + 1, y, STONE[6]); } // petek
    for (let i = 0; i < 9; i++) { const hw = i < 3 ? 0 : i < 6 ? 1 : 2; for (let dx = -hw; dx <= hw; dx++) c.set(mx + dx, top + i, pick(LEAD, 0.5 + dx * 0.2)); } // külah
    c.vline(mx, top - 4, top - 1, GOLD); c.set(mx, top - 5, '#fff1b0'); // alem
  }
  // ---- harim: kare gövde, iki kat büyük kemerli pencere, köşe payeleri ----
  const hL = 150, hR = 238, hTop = base - 72;
  stoneFace(c, hL, hTop, hR - hL, base - hTop, 0.6);
  // gölgeli sol yüz (kasra bakan) ve aydınlık sağ yüz ayrımı: ön cephe düz, köşe payeleri öne çıkar
  for (const [px, lit] of [[hL, 0.5], [hR - 9, 0.9]]) {
    for (let y = hTop - 6; y < base; y++) for (let x = px; x < px + 9; x++) c.set(x, y, pick(STONE, lit + (x - px) / 9 * 0.15 - (y - hTop) / 140));
    c.vline(px, hTop - 6, base - 1, STONE[1]); c.vline(px + 8, hTop - 6, base - 1, STONE[6]);
    // paye tepesindeki fener biçimli taç (Barok), kurşun külahçık
    c.rect(px - 1, hTop - 8, 11, 2, STONE[6]); c.rect(px + 1, hTop - 14, 7, 6, STONE[4]); c.rect(px + 2, hTop - 13, 2, 4, GLASS); c.rect(px + 5, hTop - 13, 2, 4, GLASS);
    for (let i = 0; i < 4; i++) c.hline(px + 1 + i, px + 7 - i, hTop - 15 - i, pick(LEAD, 0.6)); c.set(px + 4, hTop - 20, GOLD);
  }
  // ara pilastrlar (çift), silmeler
  for (const px of [hL + 37, hL + 50]) { c.rect(px, hTop, 3, base - hTop, STONE[5]); c.vline(px + 2, hTop, base - 1, STONE[2]); }
  c.hline(hL - 2, hR + 1, hTop - 1, STONE[6]); c.hline(hL - 2, hR + 1, hTop, STONE[3]); c.hline(hL - 1, hR, hTop + 1, STONE[1]); // ana korniş
  for (let x = hL; x < hR; x += 3) c.set(x, hTop + 2, STONE[2]); // dişler
  const mid = hTop + 34;
  c.hline(hL, hR - 1, mid, STONE[6]); c.hline(hL, hR - 1, mid + 1, STONE[2]); // kat silmesi
  // üst kat: büyük kemerli pencereler (bölümlemeli); alt kat: daha alçak kemerliler
  for (const bx of [hL + 13, hL + 58]) { archWin(c, bx, hTop + 16, 17, 16); c.rect(bx + 4, hTop + 4, 9, 3, STONE[6]); } // üstte kartuş
  archWin(c, hL + 41, hTop + 18, 6, 14);
  for (const bx of [hL + 14, hL + 59]) { archWin(c, bx, mid + 12, 7, 20); archWin(c, bx + 9, mid + 12, 7, 20); }
  archWin(c, hL + 41, mid + 14, 6, 18);
  // ---- kasnak (pencereli) ve kubbe ----
  const dcx = Math.round((hL + hR) / 2), drumTop = hTop - 16;
  stoneFace(c, dcx - 30, drumTop, 60, 16, 0.62);
  c.hline(dcx - 31, dcx + 30, drumTop - 1, STONE[6]); c.hline(dcx - 31, dcx + 30, drumTop, STONE[3]);
  for (let x = dcx - 26; x < dcx + 24; x += 7) archWin(c, x, drumTop + 6, 4, 8);
  const R = 30;
  for (let i = 0; i <= R; i++) {
    const hw = Math.round(Math.sqrt(R * R - i * i) * (0.98));
    for (let x = dcx - hw; x <= dcx + hw; x++) {
      const nx = (x - dcx) / R, ny = -i / R, l = 0.5 + 0.45 * (nx * 0.7 - ny * 0.5);
      let col = pick(LEAD, l);
      if (Math.abs(x - dcx) % 6 === 0 && i < R - 3) col = mix(col, LEAD[0], 0.3); // kurşun levha dikişleri
      c.set(x, drumTop - 2 - Math.round(i * 0.92), col);
    }
  }
  c.vline(dcx, drumTop - 36, drumTop - 30, GOLD); c.set(dcx - 1, drumTop - 34, GOLD); c.set(dcx + 1, drumTop - 34, GOLD); c.set(dcx, drumTop - 37, '#fff1b0'); // alem
  // ---- kaide / rıhtım üstündeki subasman ----
  c.rect(kL - 4, base, hR - kL + 8, 3, STONE[5]); c.hline(kL - 4, hR + 3, base + 2, STONE[1]);
}

// ======================= simge: cami + köprü (320×200) =======================
function landmark() {
  const W = 320, H = 200, c = new Canvas(W, H);
  const water = H - 6; // meydan zemini su çizgisinin 4 px üstünde
  // ---- köprünün Avrupa kulesi (caminin solunda, arkada) ve tabliye ----
  const tL = 40, tR = 72;
  for (const lx of [tL, tR - 7]) for (let y = 0; y < water - 8; y++) for (let x = lx; x < lx + 7; x++) c.set(x, y, pick(STEEL, 0.25 + (x - lx) / 7 * 0.7));
  for (const by of [6, 64, 120]) { c.rect(tL, by, tR - tL, 5, STEEL[1]); c.hline(tL, tR - 1, by, STEEL[3]); c.hline(tL, tR - 1, by + 4, STEEL[0]); } // portal kirişleri
  const deckY = 28;
  for (let x = 0; x < W; x++) { // tabliye: kutu kiriş, alt yüz gölgede, korkuluk çizgisi
    const y = deckY + Math.round((x / W) * 3);
    c.hline(x, x, y, STEEL[3]); c.vline(x, y + 1, y + 5, STEEL[1]); c.vline(x, y + 6, y + 7, STEEL[0]);
    if (x % 4 === 0) c.set(x, y - 1, STEEL[2]);
  }
  // ana kablo: kule tepesinden (kadrajın üstü) sağa doğru tabliyeye yaklaşarak sarkar; askılar kablodan tabliyeye
  // eğik iner ve zikzak çizer (Boğaz Köprüsü'nün eğik askıları, docs/12)
  const cableY = x => { const t = Math.max(0, (x - tR) / (W - tR)); return Math.round(-6 + 26 * Math.pow(t, 0.55)); };
  for (let x = tR; x < W; x++) { const y = cableY(x); c.set(x, y, STEEL[0]); c.set(x, y + 1, STEEL[2]); }
  for (let x = tR + 8, k = 0; x < W - 2; x += 8, k++) {
    const yTop = cableY(x) + 2, yDeck = deckY + Math.round((x / W) * 3) - 1, lean = k % 2 ? 3 : -3;
    if (yDeck - yTop < 3) continue;
    for (let y = yTop; y < yDeck; y++) { const xx = Math.round(x + lean * (y - yTop) / (yDeck - yTop)); c.set(xx, y, STEEL[1], 200); }
  }
  // ---- meydan ve denize uzanan çıkıntı (taş rıhtım, korkuluk) ----
  const plaza = water - 4;
  c.rect(0, plaza, 268, 4, '#d8d0c2'); c.hline(0, 267, plaza, '#f4ece0');
  for (let x = 0; x < 268; x++) { c.set(x, plaza + 4, '#8a8478'); c.set(x, plaza + 5, x % 7 ? '#6e7066' : '#565a54'); }
  for (let x = 2; x < 266; x += 3) c.set(x, plaza - 2, '#4a4e58'); c.hline(0, 266, plaza - 3, '#4a4e58'); // korkuluk
  // meydanda çınarlar ve fenerler (solda)
  for (const [tx, th] of [[14, 30], [30, 24], [80, 26]]) {
    c.vline(tx, plaza - th + 8, plaza - 1, '#5a4636'); c.vline(tx + 1, plaza - th + 8, plaza - 1, '#7a6048');
    for (let k = 0; k < 14; k++) { const ex = tx + (hash(k, tx, 3) - 0.5) * 16, ey = plaza - th + (hash(k, tx, 4)) * 12; c.ellipse(ex, ey, 4 + hash(k, 2, tx) * 3, 3, (nx, ny) => ny < -0.3 ? '#7ab45a' : ny < 0.4 ? '#4e8a44' : '#356a36'); }
  }
  for (const lx of [50, 88, 260]) { c.vline(lx, plaza - 12, plaza - 1, '#2a2e38'); c.rect(lx - 1, plaza - 15, 3, 3, '#f2f0e0'); c.set(lx, plaza - 16, '#2a2e38'); }
  mosque(c, plaza);
  // ---- suda yansıma (kırık şeritler) ----
  for (let y = water + 1; y < H; y++) for (let x = 96; x < 242; x++) if (hash(x >> 1, y, 5) < 0.35 && (x + y) % 3) c.set(x, y, mix('#eef2f4', '#2a92c8', 0.45), 150);
  return c;
}

// ======================= orta plan: Ortaköy–Kuruçeşme yamacı, Yıldız korusu (400×110) =======================
function midground() {
  const W = 400, H = 110, c = new Canvas(W, H);
  const green = ['#2f5e3a', '#3e7444', '#558a4e', '#73a45c'];
  const walls = ['#efdcb8', '#e8b48a', '#f2e6d2', '#c9806a', '#a6cbbb', '#f0c896', '#d9d4cc', '#b8c8d8'];
  c.wrap(o => {
    for (let x = 0; x < W; x++) { // yamaç ve koru
      const top = H - 70 - Math.round(14 * Math.sin((x / W) * Math.PI * 2 + 0.9) + 6 * Math.sin((x / W) * Math.PI * 6 + 0.3));
      for (let y = top; y < H; y++) c.set(o + x, y, green[hash(x >> 1, y >> 1, 81) < 0.3 ? 1 : 0]);
      for (let k = 0; k < 2; k++) if (hash(x, k, 82) < 0.5) c.set(o + x, top - k, green[2 + k]);
    }
    const r = rng(803);
    for (let k = 0; k < 46; k++) { // ağaç kümeleri (koru)
      const x = Math.floor(r() * W), y = H - 40 - Math.floor(r() * 30);
      c.ellipse(o + x, y, 4 + r() * 4, 3 + r() * 2, (nx, ny) => ny < -0.3 ? green[3] : ny < 0.3 ? green[2] : green[1]);
    }
    // yamaçtaki evler: kiremit damlı, cepheleri güneşte; kıyıya yaklaştıkça büyük ve sık
    for (let k = 0; k < 150; k++) {
      const depth = Math.pow(r(), 0.7), y = H - 6 - Math.floor((1 - depth) * 52), w = 4 + Math.floor(depth * 6), h = 3 + Math.floor(depth * 5);
      const x = Math.floor(r() * W), col = walls[Math.floor(r() * walls.length)];
      c.rect(o + x, y - h, w, h, col); c.vline(o + x + w - 1, y - h, y - 1, mix(col, '#5a6478', 0.3));
      c.hline(o + x - 1, o + x + w, y - h - 1, '#b9573c'); c.hline(o + x, o + x + w - 1, y - h - 2, '#d0704c');
      for (let i = x + 1; i < x + w - 1; i += 2) for (let j = y - h + 1; j < y - 1; j += 2) c.set(o + i, j, '#3a4a64');
    }
    // kıyı şeridi: 4–5 katlı apartmanlar ve tarihi kagir yapılar
    for (let x = 0; x < W;) {
      const w = 14 + Math.floor(r() * 14), h = 16 + Math.floor(r() * 18), col = walls[Math.floor(r() * walls.length)];
      c.rect(o + x, H - h, w, h, col); c.vline(o + x, H - h, H - 1, mix(col, '#ffffff', 0.35)); c.vline(o + x + w - 1, H - h, H - 1, mix(col, '#5a6478', 0.35));
      c.hline(o + x - 1, o + x + w, H - h - 1, r() < 0.6 ? '#b9573c' : '#8a8a96');
      for (let fy = H - h + 3; fy < H - 3; fy += 5) for (let fx = x + 2; fx < x + w - 2; fx += 4) { c.rect(o + fx, fy, 2, 3, '#2a3a58'); c.set(o + fx, fy, '#8fb4dc'); }
      x += w + 1 + Math.floor(r() * 3);
    }
  });
  return c;
}

// ======================= uzak plan: karşı kıyı, Beylerbeyi–Çengelköy tepeleri (pus) (400×110) =======================
function distant() {
  const W = 400, H = 110, c = new Canvas(W, H);
  c.wrap(o => {
    for (let x = 0; x < W; x++) {
      const h = 52 + Math.round(14 * Math.sin((x / W) * Math.PI * 2 + 2.6) + 5 * Math.sin((x / W) * Math.PI * 8));
      for (let y = H - h; y < H; y++) c.set(o + x, y, y < H - h + 1 ? '#c4d4e4' : y < H - h + 10 ? '#9db6cf' : '#8eaac4');
    }
    const r = rng(804);
    for (let k = 0; k < 90; k++) { const x = Math.floor(r() * W), y = H - 4 - Math.floor(r() * 26); c.rect(o + x, y, 2 + Math.floor(r() * 2), 2, r() < 0.5 ? '#d4dce6' : '#b6c4d4'); }
    c.vline(o + 300, H - 92, H - 60, '#a8bcd2'); c.hline(o + 297, o + 303, H - 82, '#a8bcd2'); c.set(o + 300, H - 93, '#c4d4e4'); // Çamlıca kulesi (uzak)
  });
  return c;
}

// ======================= kıyı: taş rıhtım, kafe şemsiyeleri, fenerler, kayıklar (400×28, satır 12 = ufuk) =======================
function waterfront() {
  const W = 400, c = new Canvas(W, 28), Y = 12;
  c.wrap(o => {
    c.rect(o, Y - 3, W, 4, '#d8d0c2'); c.hline(o, o + W - 1, Y - 4, '#f4ece0'); for (let x = 0; x < W; x += 6) c.vline(o + x, Y - 3, Y, '#b8b0a2');
    const r = rng(805), umb = ['#e8574a', '#f2f0e0', '#2f8f8a', '#f2c24a'];
    for (let x = 6; x < W - 8; x += 9 + Math.floor(r() * 10)) { // kafe şemsiyeleri
      const col = umb[Math.floor(r() * umb.length)];
      c.hline(o + x - 3, o + x + 3, Y - 9, col); c.hline(o + x - 2, o + x + 2, Y - 10, col); c.vline(o + x, Y - 8, Y - 4, '#4a4e58');
    }
    for (let x = 18; x < W; x += 44) { c.vline(o + x, Y - 12, Y - 4, '#2a2e38'); c.rect(o + x - 1, Y - 14, 3, 2, '#f2f0e0'); }
    for (let x = 30; x < W - 20; x += 70 + Math.floor(r() * 50)) { // sandal ve kayıklar
      const bc = ['#f2f0e0', '#2f8f8a', '#e8574a', '#f2c24a'][Math.floor(r() * 4)];
      c.rect(o + x, Y + 3, 10, 2, bc); c.rect(o + x + 1, Y + 5, 8, 1, mix(bc, '#1a2030', 0.5)); c.vline(o + x + 5, Y - 1, Y + 2, '#1a2030');
    }
  });
  return c;
}

function build(outDir) {
  const d = `${outDir}/backgrounds/ortakoy`;
  return [
    landmark().save(`${outDir}/landmarks/ortakoy.png`),
    distant().save(`${d}/distant.png`),
    midground().save(`${d}/midground.png`),
    waterfront().save(`${d}/waterfront.png`),
    G.ferry({ white: '#f6f4ee', whiteS: '#c8ccd4', glass: '#2a3a58' }).save(`${d}/ferry.png`),
  ];
}

if (require.main === module) console.log(build(process.argv[2] || require('path').resolve(__dirname, '../../../assets/images/pixel_art')).join('\n'));

module.exports = { build, landmark, midground, waterfront, distant };

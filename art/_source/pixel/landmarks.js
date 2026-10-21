// L3 kahraman simgeler (pixel art, bölge ışığında boyalı). Mimari oranlar gerçek yapılardan sadeleştirildi.
// Tarihi ve dini yapılar sadece arka plan simgesidir, asla engel değildir.
'use strict';
const { Canvas, hex, mix, rng, bayer } = require('./lib');
const { ZONES } = require('./zones');

/** Silindirik gölgeleme: nx ∈ [-1,1], ışık yönü L (−1 sol, +1 sağ) → ramp indeksi */
function cyl(nx, L, n) { const lit = 0.5 + 0.5 * (nx * L) * 0.9 + 0.15; return Math.max(0, Math.min(n - 1, Math.floor(lit * n))); }
function shadeRamp(base, dark, light, n = 5) { const out = []; for (let i = 0; i < n; i++) { const t = i / (n - 1); out.push(t < 0.5 ? mix(dark, base, t * 2) : mix(base, light, (t - 0.5) * 2)); } return out; }

// ---------------- Galata Kulesi (gündüz, ışık soldan) ----------------
function galata() {
  const W = 56, H = 160, c = new Canvas(W, H), cx = 28, L = -1;
  const stone = shadeRamp('#cdb79a', '#7d6a5e', '#f3e6cf', 6);
  const slate = shadeRamp('#4e596f', '#262c3c', '#8d9ab4', 5);
  const ink = '#2a2430';
  const bodyTop = 52, bodyBot = 152, r0 = 12, r1 = 11; // hafif daralan gövde
  // gövde: taş örgü sıraları
  for (let y = bodyTop; y < bodyBot; y++) {
    const t = (y - bodyTop) / (bodyBot - bodyTop), r = r1 + (r0 - r1) * t;
    for (let x = Math.round(cx - r); x < Math.round(cx + r); x++) {
      const nx = (x + 0.5 - cx) / r; let k = cyl(nx, L, stone.length);
      const row = Math.floor((y - bodyTop) / 3);
      if ((y - bodyTop) % 3 === 2) k = Math.max(0, k - 2); // derz
      else if ((x + row * 3) % 6 === 0) k = Math.max(0, k - 1);
      c.set(x, y, stone[k]);
    }
  }
  // kemerli pencereler (4 seviye, gövdede yükselen dizilim)
  for (const [wx, wy] of [[24, 70], [31, 88], [26, 108], [32, 128], [22, 140]]) {
    c.rect(wx, wy, 3, 6, ink); c.set(wx + 1, wy - 1, ink); c.set(wx + 2, wy + 1, mix(ink, '#6a7aa0', 0.5));
  }
  // galeri (balkon): biraz geniş bant + korkuluk + alt gölge
  c.rect(cx - 15, 46, 30, 6, stone[2]); c.hline(cx - 15, cx + 14, 46, stone[5]); c.hline(cx - 14, cx + 13, 52, stone[0]); c.hline(cx - 12, cx + 11, 53, mix(stone[0], ink, 0.4));
  c.hline(cx - 16, cx + 15, 40, ink); for (let x = cx - 16; x <= cx + 15; x += 2) c.vline(x, 41, 45, ink);
  // üst kasnak: kemerli pencereler halkası
  for (let y = 26; y < 40; y++) for (let x = cx - 11; x < cx + 11; x++) c.set(x, y, stone[cyl((x + 0.5 - cx) / 11, L, stone.length)]);
  for (let x = cx - 9; x < cx + 9; x += 4) { c.rect(x, 29, 2, 8, ink); c.set(x, 28, mix(ink, stone[2], 0.4)); c.set(x + 1, 28, ink); }
  c.hline(cx - 12, cx + 11, 25, stone[1]); c.hline(cx - 12, cx + 11, 40, stone[1]);
  // kurşun külah: koni, kiremit hissi için sıra çizgileri
  for (let y = 0; y < 25; y++) {
    const t = y / 24, r = 1 + t * 12;
    for (let x = Math.round(cx - r); x < Math.round(cx + r); x++) {
      let k = cyl((x + 0.5 - cx) / r, L, slate.length); if (y % 3 === 2) k = Math.max(0, k - 1);
      c.set(x, y + 2, slate[k]);
    }
  }
  c.vline(cx, 0, 3, ink); c.set(cx, 0, '#d8b04a');
  // taban: yamaçtaki taş duvar ve kapı
  c.rect(cx - 16, 150, 32, 10, stone[1]); c.hline(cx - 16, cx + 15, 150, stone[4]);
  c.rect(cx - 2, 146, 4, 8, ink); c.set(cx - 1, 145, ink); c.set(cx, 145, ink);
  c.outline(mix(ink, '#3a4a6a', 0.3));
  return c;
}

// ---------------- Süleymaniye (şafak, ışık sağdan; sadece arka plan) ----------------
function suleymaniye() {
  const W = 180, H = 112, c = new Canvas(W, H), cx = 90, base = 110, L = 1;
  const haze = '#a99ab4';
  const stone = shadeRamp(mix('#c9a9a4', haze, 0.3), mix('#6c5f80', haze, 0.2), '#f6cfac', 5);
  const lead = shadeRamp(mix('#7a7fa2', haze, 0.25), '#4c4e72', '#d8c8d8', 5);
  const ink = '#4a4060';
  const dome = (x, y, rx, ry) => { for (let j = 0; j <= ry; j++) for (let i = -rx; i <= rx; i++) { const nx = i / rx, ny = j / ry; if (nx * nx + ny * ny > 1) continue; let k = cyl(nx, L, lead.length); if (ny > 0.75) k = Math.min(lead.length - 1, k + 1); c.set(x + i, y - j, lead[k]); } c.vline(x, y - ry - 4, y - ry - 1, ink); c.set(x, y - ry - 5, '#e8c070'); };
  const wall = (x, y, w, h) => { for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) c.set(x + i, y + j, stone[cyl((i + 0.5) / w * 2 - 1, L, stone.length) > 2 ? 3 : 2]); };
  // avlu ve gövde
  wall(cx - 62, base - 22, 124, 22);
  for (let x = cx - 58; x < cx + 58; x += 6) { c.rect(x, base - 16, 2, 5, ink); c.set(x, base - 17, mix(ink, stone[2], 0.5)); }
  for (let x = cx - 60; x < cx + 60; x += 9) dome(x + 4, base - 22, 4, 3); // avlu kubbecikleri
  wall(cx - 40, base - 40, 80, 18);
  for (let x = cx - 36; x < cx + 36; x += 5) c.rect(x, base - 34, 2, 6, ink);
  // payandalar ve yarım kubbeler
  dome(cx - 26, base - 40, 13, 9); dome(cx + 26, base - 40, 13, 9);
  wall(cx - 24, base - 50, 48, 10);
  for (let x = cx - 21; x < cx + 21; x += 4) c.rect(x, base - 48, 2, 5, ink); // kasnak pencereleri
  dome(cx, base - 50, 24, 20);
  for (const s of [-1, 1]) { c.rect(cx + s * 24 - 2, base - 56, 4, 16, stone[s > 0 ? 3 : 1]); dome(cx + s * 24, base - 56, 2, 3); }
  // dört minare (iki uzun üç şerefeli, iki kısa iki şerefeli)
  const minaret = (x, h, balconies) => {
    for (let y = base - h; y < base - 20; y++) { c.set(x - 1, y, stone[1]); c.set(x, y, stone[3]); c.set(x + 1, y, stone[2]); }
    for (let b = 1; b <= balconies; b++) { const y = base - 20 - Math.round((h - 26) * b / (balconies + 0.6)); c.hline(x - 2, x + 2, y, stone[4]); c.hline(x - 2, x + 2, y + 1, ink); }
    for (let k = 0; k < 9; k++) { const w = Math.max(0, Math.round(1.6 * (1 - k / 9))); c.hline(x - w, x + w, base - h - k, lead[k < 3 ? 2 : 1]); }
    c.vline(x, base - h - 12, base - h - 10, '#e8c070');
  };
  minaret(cx - 56, 98, 3); minaret(cx + 56, 98, 3); minaret(cx - 72, 80, 2); minaret(cx + 72, 80, 2);
  // yamaç ve evler (silüeti oturtur)
  for (let x = 0; x < W; x++) { const h = 2 + Math.round(3 * Math.abs(Math.sin(x * 0.3))); c.vline(x, base - h, H - 1, mix(stone[0], ink, 0.3)); }
  return c;
}

// ---------------- Kız Kulesi (gün batımı, ters ışık; güneş solda) ----------------
function kizKulesi() {
  const W = 120, H = 118, c = new Canvas(W, H), z = ZONES.kizkulesi;
  const body = '#4a2440', bodyD = '#351a32', rim = '#ff9a55', rim2 = '#ffd08a', lit = '#ffc46b', ink = '#1e0e1c', rock = '#2a1428';
  // kayalık ada
  for (let x = 4; x < W - 4; x++) { const h = 5 + Math.round(3 * Math.abs(Math.sin(x * 0.21)) + 2 * Math.sin(x * 0.07)); c.vline(x, H - h, H - 1, x % 7 < 3 ? rock : mix(rock, ink, 0.4)); }
  // platform duvarı
  c.rect(10, H - 22, 100, 14, body); c.hline(10, 109, H - 22, rim); c.vline(10, H - 22, H - 9, rim);
  for (let x = 14; x < 106; x += 7) c.rect(x, H - 18, 2, 4, bodyD);
  for (const x of [20, 34, 76, 92]) { c.rect(x, H - 18, 2, 4, lit); }
  // yan bina (kırma çatı)
  c.rect(16, H - 42, 36, 20, body); c.vline(16, H - 42, H - 23, rim);
  c.poly([[13, H - 42], [34, H - 54], [55, H - 42]], bodyD); c.line(13, H - 42, 34, H - 54, rim);
  for (const x of [21, 29, 37, 45]) { c.rect(x, H - 37, 3, 5, lit); c.set(x + 1, H - 38, lit); }
  // kule gövdesi (taş, kare)
  const tx = 58, tw = 22;
  c.rect(tx, H - 78, tw, 56, body); c.rect(tx + tw - 5, H - 78, 5, 56, bodyD); c.vline(tx, H - 78, H - 23, rim);
  for (let y = H - 74; y < H - 24; y += 4) c.hline(tx + 1, tx + tw - 6, y, mix(body, bodyD, 0.5));
  for (const [x, y] of [[tx + 5, H - 70], [tx + 12, H - 70], [tx + 5, H - 54], [tx + 12, H - 54], [tx + 8, H - 38]]) { c.rect(x, y, 3, 6, lit); c.set(x + 1, y - 1, lit); }
  // galeri
  c.rect(tx - 4, H - 82, tw + 8, 4, bodyD); c.hline(tx - 4, tx + tw + 3, H - 83, rim);
  for (let x = tx - 4; x < tx + tw + 4; x += 2) c.vline(x, H - 87, H - 84, ink);
  c.hline(tx - 4, tx + tw + 3, H - 88, ink);
  // fener (sekizgen kasnak) + kurşun külah + bayrak direği
  c.rect(tx + 4, H - 100, 14, 13, body); c.rect(tx + 14, H - 100, 4, 13, bodyD); c.vline(tx + 4, H - 100, H - 88, rim);
  for (let x = tx + 6; x < tx + 15; x += 3) c.rect(x, H - 97, 2, 7, lit);
  for (let y = 0; y < 14; y++) { const r = 1 + y * 0.55; c.hline(Math.round(tx + 11 - r), Math.round(tx + 11 + r), H - 114 + y, y < 3 ? bodyD : body); c.set(Math.round(tx + 11 - r), H - 114 + y, rim); }
  c.vline(tx + 11, H - 118, H - 114, ink);
  // bayrak (kırmızı, küçük, rüzgârda)
  c.rect(tx + 12, H - 118, 6, 4, '#d23a3a'); c.set(tx + 14, H - 116, '#ffffff');
  // fener ışığı
  c.set(tx + 11, H - 95, '#fff0c0'); for (const [dx, dy] of [[-1, 0], [1, 0], [0, -1], [0, 1]]) c.set(tx + 11 + dx, H - 95 + dy, rim2);
  return c;
}

// ---------------- Boğaz Köprüsü (akşam, ışıklı) ----------------
function bridge() {
  const W = 400, H = 196, c = new Canvas(W, H);
  const steel = '#2a2f5e', steelL = '#3d4580', ink = '#11132e', blue = '#6f9cff', blueGlow = '#3c5cc0', bead = '#ffd27a', deckY = 150;
  const T1 = 70, T2 = 330, top = 16;
  // yan açıklıklar ve ana kablo (zincir eğrisi)
  const cy = t => (1 - t) ** 2 * (top + 4) + 2 * t * (1 - t) * (deckY + 18) + t * t * (top + 4);
  for (let x = T1; x <= T2; x++) {
    const y = Math.round(cy((x - T1) / (T2 - T1)));
    c.set(x, y, steelL); c.set(x, y + 1, steel);
    if ((x - T1) % 4 === 0 && y + 2 < deckY) c.vline(x, y + 2, deckY - 1, mix(steel, '#000000', 0.15)); // askılar
    if ((x - T1) % 8 === 0) c.set(x, y, bead);
  }
  for (const [x0, x1, s] of [[T1, 0, -1], [T2, W - 1, 1]]) for (let x = x0; s > 0 ? x <= x1 : x >= x1; x += s) {
    const t = Math.abs(x - x0) / Math.abs(x1 - x0), y = Math.round(top + 4 + (deckY + 6 - top - 4) * Math.pow(t, 0.85));
    c.set(x, y, steelL); if (Math.abs(x - x0) % 8 === 0) c.set(x, y, bead);
    if (Math.abs(x - x0) % 4 === 0 && y + 1 < deckY) c.vline(x, y + 1, deckY - 1, mix(steel, '#000000', 0.15));
  }
  // portal kuleler (iki ayak + kirişler), mavi aydınlatma
  for (const tx of [T1, T2]) {
    for (const lx of [tx - 6, tx + 4]) for (let y = top; y < H; y++) {
      const w = 3; for (let i = 0; i < w; i++) c.set(lx + i, y, i === 0 ? steelL : steel);
      if (y % 2 === 0) c.set(lx + 2, y, blueGlow);
    }
    for (const by of [top, top + 40, top + 86, deckY - 10]) { c.rect(tx - 6, by, 13, 3, steel); c.hline(tx - 6, tx + 6, by, steelL); }
    c.set(tx - 1, top - 2, '#ff4040'); c.set(tx, top - 2, '#ff4040'); // uçak ikaz ışığı
    for (let y = top + 2; y < H; y += 6) { c.set(tx - 7, y, blue, 120); c.set(tx + 7, y, blue, 120); } // mavi ışık huzmeleri
  }
  // tabliye + ışık dizisi
  c.rect(0, deckY, W, 6, ink); c.hline(0, W - 1, deckY, steelL);
  for (let x = 2; x < W; x += 5) c.set(x, deckY + 2, bead);
  c.hline(0, W - 1, deckY + 6, blueGlow);
  return c;
}

// ---------------- Rumeli Hisarı (gece, projektörle aydınlatılmış) ----------------
function rumeliHisari() {
  const W = 240, H = 150, c = new Canvas(W, H);
  const stone = ['#3a2620', '#5a3424', '#7a4a30', '#a5653a', '#d88a44', '#f2b060'];
  const dark = '#140f14', treeD = '#0d1a1a', treeL = '#173029', slit = '#1a0e0a';
  const ground = x => H - 8 - Math.round(70 * Math.pow(Math.max(0, Math.min(1, (x - 20) / 170)), 1.15)); // yamaç
  // yamaç
  // ağaçlık yamaç: ay ışığında dokulu taç örtüsü (düz siyah leke yerine)
  const canopy = ['#0b1517', '#10211f', '#173029', '#22423a', '#2f5a4c'];
  const rg = rng(31);
  const bumps = Array.from({ length: W }, (_, x) => Math.round(2 * Math.sin(x * 0.55) + 2 * Math.sin(x * 0.23 + 1)));
  for (let x = 0; x < W; x++) {
    const top = Math.max(ground(x), 72) - 3 + bumps[x];
    for (let y = top; y < H; y++) {
      const d = y - top, n = bayer(x, y) + (rg() - 0.5) * 0.3;
      let k = d < 2 ? 3 : d < 6 ? 2 : d < 16 ? 1 : 0;
      if (n > 0.72 && k < 4) k++;
      if (n < 0.18 && k > 0) k--;
      c.set(x, y, canopy[k]);
    }
    if (bumps[x] <= -2) c.set(x, top, canopy[4]); // ay ışığı tepe vurgusu
  }
  // yamaçtaki birkaç yalı/ev ışığı
  for (const [x, y] of [[30, 140], [62, 136], [88, 128], [120, 122], [196, 104], [226, 98]]) { c.rect(x, y, 2, 2, '#ffc96b'); c.set(x, y + 2, '#a8783a'); }
  // projektör ışığında taş: alttan aydınlık, yukarı karardıkça
  const stoneAt = (x, y, top, bot, edge) => { const t = (y - top) / Math.max(1, bot - top); let k = Math.min(5, Math.floor(1 + t * 4.2 + (bayer(x, y) - 0.5) * 0.9)); if (edge) k = Math.max(0, k - 2); return stone[k]; };
  // sur hattı: yamaca tırmanan mazgallı duvar
  const wallTop = x => ground(x) - 14;
  for (let x = 14; x < 226; x++) {
    const top = wallTop(x), bot = ground(x) + 2;
    for (let y = top; y < bot; y++) c.set(x, y, stoneAt(x, y, top, bot, false));
    if (Math.floor(x / 3) % 2 === 0) for (let y = top - 3; y < top; y++) c.set(x, y, stoneAt(x, y, top - 3, bot, false)); // mazgal dişleri
    if (x % 19 === 0) c.rect(x, top + 5, 1, 3, slit);
  }
  // büyük yuvarlak kuleler: mazgallı taç, mazgal pencereleri
  const tower = (cx, r, h) => {
    const bot = ground(cx) + 2, top = bot - h;
    for (let y = top; y < bot; y++) for (let x = cx - r; x < cx + r; x++) {
      const nx = (x + 0.5 - cx) / r; const edge = Math.abs(nx) > 0.82;
      let col = stoneAt(x, y, top, bot, edge);
      if (nx < -0.55) col = mix(col, dark, 0.35);
      c.set(x, y, col);
    }
    for (let x = cx - r - 1; x < cx + r + 1; x++) { c.set(x, top, stone[3]); if (Math.floor((x - cx) / 2) % 2 === 0) { c.set(x, top - 1, stone[2]); c.set(x, top - 2, stone[2]); } }
    c.hline(cx - r - 1, cx + r, top + 2, stone[1]);
    for (let y = top + 8; y < bot - 6; y += 9) for (const dx of [-r * 0.4, r * 0.25]) c.rect(Math.round(cx + dx), y, 1, 3, slit);
  };
  tower(44, 15, 62);   // Halil Paşa (kıyıda)
  tower(150, 13, 70);  // Saruca Paşa (tepede)
  tower(206, 11, 54);  // Zağanos Paşa
  tower(100, 6, 30); tower(178, 5, 26); // küçük kuleler
  // önde ağaçlar (koyu, ay ışığında ince kenar)
  const r = rng(77);
  for (let x = 0; x < W; x += 6 + Math.floor(r() * 6)) {
    const by = Math.min(H - 2, ground(x) + 10 + Math.floor(r() * 8)), rr = 5 + r() * 6;
    c.ellipse(x, by - rr, rr, rr * 1.1, (nx, ny, X, Y) => (ny < -0.5 && bayer(X, Y) < 0.4 ? treeL : treeD));
  }
  // kıyı kayaları
  for (let x = 0; x < 70; x++) c.vline(x, H - 4 - Math.round(2 * Math.abs(Math.sin(x * 0.4))), H - 1, '#0a0c14');
  return c;
}

function build(outDir) {
  const d = `${outDir}/landmarks`;
  return [
    suleymaniye().save(`${d}/suleymaniye.png`),
    galata().save(`${d}/galata.png`),
    kizKulesi().save(`${d}/kiz_kulesi.png`),
    bridge().save(`${d}/bridge.png`),
    rumeliHisari().save(`${d}/rumeli_hisari.png`),
  ];
}

module.exports = { build, galata, suleymaniye, kizKulesi, bridge, rumeliHisari };

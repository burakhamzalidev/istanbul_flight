// Galata bölgesi: gerçek referanslara dayalı yeniden çizim (docs/09).
//
// Kamera: Eminönü kıyısından (Galata Köprüsü güney ucu) kuzeydoğuya, Haliç ağzının karşısındaki
// Karaköy–Galata yamacına bakış. Bu açıdan gerçekten görülen katmanlar, önden arkaya:
//   Galata Köprüsü (iki katlı: üstte yol + lambalar, altta lokantalar) → Karaköy kıyısındaki
//   19. yy ticari yapıları → yamaca basamak basamak tırmanan 5–8 katlı sıvalı apartmanlar →
//   sırtta Galata Kulesi (gövdesinin alt yarısı binaların arkasında) → pusta uzak yüksek yapılar.
//
// Ölçek: kule gövdesi 16,45 m ≈ 40 px → ≈ 0,41 m/px. Kule 62,59 m + alem ≈ 168 px.
// Seyir terası 51,65 m (yüksekliğin %82'si); konik çatı tabanı gövdenin ≈ %70'i.
// Referans fotoğraflar ve lisansları: docs/09_galata_gercek_referans.md
'use strict';
const { Canvas, mix, rng, bayer } = require('./lib');

// Sabit tohumlu konum gürültüsü (doku için; her çalıştırmada aynı sonuç)
const hash = (x, y, s = 0) => { let h = (x * 374761393 + y * 668265263 + s * 2147483647) >>> 0; h = ((h ^ (h >>> 13)) * 1274126177) >>> 0; return ((h ^ (h >>> 16)) >>> 0) / 4294967296; };

// Gün ortası, güneş sağ arkada (güney): kameraya bakan cepheler aydınlık, sola bakan yan yüzler gölgede.
const HAZE = '#b9c9dc';
const COOL = '#56637e';
const INK = '#23252e';

// ======================= Galata Kulesi (48×168) =======================
function tower() {
  const W = 48, H = 168, c = new Canvas(W, H), cx = 24;
  const L = 1; // ışık sağdan
  // silindir üzerinde aydınlatma: nx ∈ [-1,1]
  const lit = nx => Math.max(0, Math.min(1, 0.52 + 0.42 * nx * L + 0.12 * (1 - nx * nx)));
  const pick = (ramp, t) => ramp[Math.max(0, Math.min(ramp.length - 1, Math.floor(t * ramp.length)))];
  const span = (y, r, fn) => { for (let x = Math.round(cx - r); x < Math.round(cx + r); x++) fn(x, (x + 0.5 - cx) / r); };

  const lead = ['#3c474e', '#4f5d64', '#65767b', '#7f9192', '#9cadab', '#bccac5'];
  const cream = ['#8c8172', '#a99d8a', '#c2b6a0', '#d6cbb5', '#e6dcc8', '#f2ead9'];
  const stone = ['#5e534b', '#76695d', '#8f8170', '#a69683', '#bcac97', '#d0c1ab'];
  const brick = ['#6e3326', '#8d4231', '#a8543c', '#bf6a4c'];
  const iron = '#2a2b31', glass = ['#1f2c3c', '#2f4a63', '#4d7290'];

  // --- alem (bakır, yaldızlı) ---
  c.vline(cx, 0, 3, '#f0cf6a'); c.vline(cx - 1, 2, 3, '#b88a2c');
  c.rect(cx - 1, 4, 2, 2, '#e7bd4f'); c.set(cx - 1, 4, '#fff0b0');
  c.vline(cx, 6, 9, '#9a7426'); c.vline(cx - 1, 6, 9, '#7a5a1e');

  // --- konik çatı (kurşun): dik koni. Fotoğraflarda koni tabanı gövde çapının ≈ %45'i,
  // üst kat tamburu ≈ %70'i (Galata_Kulesi_(07052023).jpg ölçümü) ---
  const coneTop = 10, coneBot = 35; // 26 satır, taban genişliği 18
  for (let y = coneTop; y <= coneBot; y++) {
    const t = (y - coneTop) / (coneBot - coneTop), r = 1 + t * 8;
    span(y, r, (x, nx) => {
      let k = lit(nx);
      const seam = Math.floor((Math.asin(Math.max(-1, Math.min(1, nx))) + Math.PI / 2) / (Math.PI / 9));
      const seamPrev = Math.floor((Math.asin(Math.max(-1, Math.min(1, (x - 0.5 - cx) / r))) + Math.PI / 2) / (Math.PI / 9));
      if (seam !== seamPrev && r > 4) k -= 0.18; // dikiş
      if ((y - coneTop) % 5 === 4 && r > 3) k -= 0.06; // levha sıraları
      c.set(x, y, pick(lead, k));
    });
  }
  // çatı penceresi (fotoğraflarda konide görülen küçük çıkma)
  c.rect(cx + 1, 28, 3, 3, '#3a4247'); c.set(cx + 2, 29, '#9cc0d8'); c.hline(cx, cx + 4, 27, lead[1]);
  // saçak: koninin hafifçe genişleyen ayağı, tamburun düz terası
  span(36, 10, (x, nx) => c.set(x, 36, pick(lead, lit(nx) - 0.25)));

  // --- üst kat (taş tambur) + seyir terası korkuluğu ---
  span(37, 15, (x, nx) => c.set(x, 37, pick(cream, lit(nx) + 0.1)));
  for (let y = 38; y <= 41; y++) span(y, 14, (x, nx) => c.set(x, y, pick(cream, lit(nx) - (y === 38 ? 0.25 : 0))));
  for (const nx of [-0.62, -0.2, 0.22, 0.64]) c.rect(Math.round(cx + nx * 14), 39, 1, 2, glass[0]);
  // korkuluk: koyu demir, 2 px'te bir dikme
  span(42, 20, (x) => c.set(x, 42, iron));
  span(43, 20, (x, nx) => c.set(x, 43, x % 2 ? iron : pick(cream, lit(nx) - 0.35)));
  span(44, 21, (x, nx) => c.set(x, 44, pick(cream, lit(nx) + 0.05))); // teras döşemesi (taşkın)
  // konsollu silme (dişli), altında gölge
  span(45, 21, (x, nx) => c.set(x, 45, pick(cream, lit(nx) - 0.1)));
  span(46, 20, (x, nx) => c.set(x, 46, x % 2 ? pick(cream, lit(nx) - 0.45) : pick(cream, lit(nx) - 0.15)));
  span(47, 20, (x, nx) => c.set(x, 47, pick(cream, lit(nx) - 0.55)));

  // --- kemerli galeri katı: yarım daire başlıklı, tuğla kemer halkalı, içeri çekik koyu açıklıklar ---
  const bay = Math.PI / 6.5, half = 0.27;
  for (let y = 48; y <= 60; y++) {
    span(y, 21, (x, nx) => {
      const th = Math.asin(Math.max(-1, Math.min(1, nx))) + Math.PI / 2, f = (th / bay) % 1, d = Math.abs(f - 0.5);
      const row = y - 48; // 0..12
      // açıklığın yarı genişliği: 1–4. satırlarda yarım daire, altta sabit
      const open = row < 1 ? -1 : row < 5 ? half * Math.sqrt(Math.max(0, 1 - ((5 - row) / 4.2) ** 2)) : half;
      const ring = row < 6 && d < open + 0.11 && d >= open; // tuğla kemer halkası
      let col;
      if (Math.abs(nx) > 0.92) col = pick(cream, lit(nx) - 0.1);
      else if (row >= 11) col = pick(cream, lit(nx) - (row === 11 ? 0.05 : 0.3)); // denizlik
      else if (d < open) {
        const inner = d < open - 0.09 && row >= 4 && row <= 10;
        col = inner ? pick(glass, lit(nx) + 0.15 - (row < 6 ? 0.2 : 0)) : '#262830';
      } else if (ring) col = pick(brick, lit(nx) - (d > open + 0.06 ? 0.2 : 0));
      else col = pick(cream, lit(nx) - (row === 0 ? 0.2 : 0));
      c.set(x, y, col);
    });
  }
  // --- alt silme ---
  span(61, 21, (x, nx) => c.set(x, 61, pick(cream, lit(nx) + 0.05)));
  span(62, 20, (x, nx) => c.set(x, 62, pick(cream, lit(nx) - 0.12)));
  span(63, 19, (x, nx) => c.set(x, 63, pick(cream, lit(nx) - 0.5)));

  // --- gövde: hafif daralan, moloz taş örgü, silik tuğla hatıllar, kemerli küçük pencereler ---
  const bodyTop = 64, bodyBot = H - 1;
  for (let y = bodyTop; y <= bodyBot; y++) {
    const t = (y - bodyTop) / (bodyBot - bodyTop), r = 17.5 + t * 3; // aşağı doğru belirgin genişler
    span(y, r, (x, nx) => {
      // düzensiz taşlar: 3×2'lik hücreler, her taşın kendi tonu, ara harç
      const sx = Math.floor((x + (Math.floor(y / 2) % 2) * 1.5) / 3), sy = Math.floor(y / 2);
      let k = lit(nx) + (hash(sx, sy, 3) - 0.5) * 0.32;
      if (y % 2 === 0 && hash(x, y, 7) < 0.45) k -= 0.16; // harç izi
      if (y === 116 || y === 146) k -= 0.1; // silik hatıl
      let col = pick(stone, k);
      if ((y === 116 || y === 146) && hash(x, y, 9) < 0.6) col = mix(col, '#8e5a46', 0.45);
      if (Math.abs(nx) > 0.93) col = mix(col, COOL, 0.25);
      c.set(x, y, col);
    });
  }
  // pencereler (fotoğraflardaki dizilim: üst gövdede iki büyük kemerli pencere, altta küçükler, mazgallar)
  const win = (nx, y, w, h) => {
    const r = 18 + ((y - bodyTop) / (bodyBot - bodyTop)) * 2, x = Math.round(cx + nx * r - w / 2);
    c.rect(x, y + 1, w, h - 1, glass[1]); c.hline(x + 1, x + w - 2, y, glass[1]);
    c.vline(x, y + 1, y + h - 1, glass[0]); if (w > 2) c.set(x + w - 1, y + 1, glass[2]);
    c.hline(x, x + w - 1, y + h, pick(stone, lit(nx) + 0.2)); // denizlik
  };
  win(-0.3, 70, 3, 6); win(0.38, 70, 3, 6);
  win(0.05, 82, 2, 4); win(-0.62, 84, 2, 3); win(0.7, 84, 2, 3);
  win(-0.15, 98, 2, 4); win(0.45, 104, 2, 3);
  for (const [nx, y] of [[-0.45, 112], [0.2, 122], [0.62, 130], [-0.1, 138], [0.35, 152], [-0.55, 158]]) {
    const r = 19, x = Math.round(cx + nx * r); c.rect(x, y, 1, 2, '#2a2830');
  }
  c.outline(mix(INK, '#6a7a90', 0.35));
  return c;
}

// ======================= bina üretici =======================
const WALLS = ['#ece3d3', '#e6dac5', '#efe9df', '#dccaa9', '#d9b27a', '#e6d29a', '#d8ab99', '#c4bfb6', '#cf9677', '#b9c2b0', '#e2cfb6', '#f1e3c4'];
const WALL_W = [5, 5, 4, 4, 2, 2, 1, 2, 1, 1, 3, 2];
function pickWall(r) { const tot = WALL_W.reduce((a, b) => a + b, 0); let v = r() * tot; for (let i = 0; i < WALLS.length; i++) { v -= WALL_W[i]; if (v < 0) return WALLS[i]; } return WALLS[0]; }

/** Beyoğlu/Karaköy apartmanı. haze: hava perspektifi (0 yakın … 0,45 uzak), fh: kat yüksekliği (px). */
function apartment(c, x, base, w, h, r, { haze = 0, fh = 8, front = false } = {}) {
  const hz = col => mix(col, HAZE, haze);
  const wall = pickWall(r);
  const top = base - h, light = mix(wall, '#fff6e0', 0.25), shade = mix(wall, COOL, 0.42);
  c.rect(x, top, w, h, hz(wall));
  // sıva dokusu ve lekeler (eski İstanbul cepheleri tek renk değil)
  for (let y = top; y < base; y++) for (let i = x; i < x + w; i++) {
    const n = hash(i, y, 11);
    if (n < 0.06) c.set(i, y, hz(mix(wall, COOL, 0.16)));
    else if (n > 0.97) c.set(i, y, hz(mix(wall, '#fff6e0', 0.2)));
  }
  // sola bakan yan yüz (gölge) ve sağ kenar ışığı
  const side = Math.max(1, Math.round(w * 0.12));
  c.rect(x, top, side, h, hz(shade));
  c.vline(x + w - 1, top, base - 1, hz(light));
  // katlar
  const winW = fh >= 9 ? 2 : fh >= 7 ? 2 : 1, winH = Math.max(2, fh - 4);
  const cols = Math.max(1, Math.floor((w - side - 2) / (winW + 2)));
  const gx = (w - side - cols * winW) / (cols + 1);
  const hasCumba = !front && w >= 14 && h > fh * 3 && r() < 0.45;
  const cumbaCols = [Math.floor(cols / 2) - 1, Math.floor(cols / 2), Math.floor(cols / 2) + 1];
  const balconyFloor = r() < 0.5;
  let fl = 0;
  for (let fy = base - fh - (front ? fh : 2); fy > top + 2; fy -= fh, fl++) {
    c.hline(x + side, x + w - 2, fy + fh - 1, hz(mix(wall, COOL, 0.22))); // kat silmesi
    for (let k = 0; k < cols; k++) {
      const wx = Math.round(x + side + gx + k * (winW + gx));
      const shut = hash(wx, fy, 5);
      const glassC = shut < 0.12 ? mix(wall, '#7a5a3a', 0.5) : shut < 0.2 ? '#4f6b86' : '#36404f';
      c.rect(wx, fy + 1, winW, winH, hz(glassC));
      c.set(wx, fy, hz(mix(wall, '#ffffff', 0.3)));
      if (fh >= 8 && hash(wx, fy, 6) < 0.2) c.set(wx + winW, fy + 2, hz('#d8dde2')); // klima
    }
    if (balconyFloor && fl % 2 === 1 && fh >= 7) { // ferforje balkon şeridi
      c.hline(x + side + 1, x + w - 3, fy + fh - 2, hz(INK));
      for (let b = x + side + 1; b < x + w - 2; b += 2) c.set(b, fy + fh - 3, hz(mix(INK, wall, 0.4)));
    }
  }
  // cumba: üst katlarda ortada çıkma, altında gölge
  if (hasCumba) {
    const cw = Math.min(w - side - 4, Math.max(7, Math.round(w * 0.42))), cx0 = x + side + Math.round((w - side - cw) / 2);
    const cTop = top + fh, cBot = Math.min(base - fh * 2, top + fh * 4);
    c.rect(cx0, cTop, cw, cBot - cTop, hz(mix(wall, '#fff6e0', 0.12)));
    c.vline(cx0, cTop, cBot - 1, hz(mix(wall, COOL, 0.35)));
    c.hline(cx0, cx0 + cw - 1, cBot, hz(mix(wall, COOL, 0.6)));
    for (let fy = cTop + 2; fy < cBot - 2; fy += fh) for (let i = cx0 + 2; i < cx0 + cw - 1; i += 3) c.rect(i, fy, 2, winH, hz('#3a4556'));
  }
  // korniş ve çatı
  c.hline(x, x + w - 1, top, hz(light)); c.hline(x, x + w - 1, top + 1, hz(mix(wall, COOL, 0.3)));
  const roofKind = r();
  if (roofKind < 0.42) {
    // kırma kiremit çatı (Beyoğlu'nda yaygın): her satırda 2 px içe
    const tiles = ['#9a4330', '#b5543b', '#c8684a'];
    let y = top - 1;
    for (let inset = 1; inset < w / 2 - 1 && y > top - 6; inset += 2, y--) for (let i = x + inset; i < x + w - inset; i++) c.set(i, y, hz(tiles[(i + y) % 5 === 0 ? 0 : i > x + w * 0.55 ? 2 : 1]));
    if (r() < 0.5) { const bx = x + 2 + Math.floor(r() * (w - 6)); c.rect(bx, top - 6, 2, 4, hz('#8c7a6a')); }
  } else {
    // düz çatı: parapet, su deposu, çatı katı, çanak anten (gerçek İstanbul çatı silüeti)
    c.hline(x, x + w - 1, top - 1, hz(mix(wall, COOL, 0.15)));
    if (r() < 0.55 && w > 10) { const pw = Math.round(w * (0.35 + r() * 0.3)), px = x + Math.floor(r() * (w - pw)); c.rect(px, top - 4, pw, 3, hz(mix('#d9d4cc', COOL, 0.1))); c.hline(px, px + pw - 1, top - 4, hz('#efece6')); for (let i = px + 1; i < px + pw - 1; i += 3) c.set(i, top - 3, hz('#5a6474')); }
    if (r() < 0.6) { const tx = x + 1 + Math.floor(r() * (w - 4)); c.rect(tx, top - 3, 3, 2, hz('#9aa0a8')); c.hline(tx, tx + 2, top - 3, hz('#c3c8ce')); }
    if (r() < 0.5) { const dx = x + 1 + Math.floor(r() * (w - 3)); c.set(dx, top - 2, hz('#f2f2f0')); c.set(dx + 1, top - 3, hz('#f2f2f0')); }
    if (r() < 0.35) { const ax = x + Math.floor(r() * w); c.vline(ax, top - 6, top - 1, hz('#4a4f58')); }
  }
}

/** Karaköy kıyısındaki büyük ticari yapılar (19. yy sonu – 20. yy başı han ve banka binaları, modern ofis). */
function karakoyBlock(c, x, base, w, h, r, type) {
  const top = base - h;
  if (type === 'arches') {
    // krem taş cephe, ikili sivri kemerli pencere dizileri (neo-klasik / I. Ulusal Mimarlık üslubu)
    const wall = '#e8dcc0', sh = mix(wall, COOL, 0.4);
    c.rect(x, top, w, h, wall); c.rect(x, top, 3, h, sh);
    for (let fy = top + 6; fy < base - 10; fy += 10) {
      c.hline(x + 3, x + w - 1, fy - 2, mix(wall, COOL, 0.25));
      for (let wx = x + 6; wx + 3 < x + w - 2; wx += 6) {
        c.rect(wx, fy + 1, 3, 6, '#3c4658'); c.set(wx + 1, fy, '#3c4658'); c.set(wx, fy + 1, mix(wall, COOL, 0.5));
        c.set(wx + 1, fy - 1, mix(wall, '#a07a52', 0.5));
      }
    }
    c.rect(x - 1, top - 2, w + 2, 2, '#f6eedc'); c.hline(x - 1, x + w, top, mix(wall, COOL, 0.3));
    // köşede küçük kubbeli kule
    c.rect(x + w - 8, top - 8, 6, 6, wall); c.rect(x + w - 8, top - 8, 1, 6, sh);
    for (let i = 0; i < 4; i++) c.hline(x + w - 8 + i, x + w - 3 - i, top - 9 - i, i < 2 ? '#7f9192' : '#65767b');
    c.vline(x + w - 5, top - 15, top - 13, '#c9a24a');
  } else if (type === 'oculus') {
    // beyaz han, çatı katında üç yuvarlak pencere
    const wall = '#f0ece4', sh = mix(wall, COOL, 0.38);
    c.rect(x, top, w, h, wall); c.rect(x, top, 3, h, sh);
    for (let fy = top + 12; fy < base - 8; fy += 9) for (let wx = x + 5; wx + 2 < x + w - 2; wx += 5) c.rect(wx, fy, 2, 5, '#3a4454');
    c.rect(x + 2, top - 9, w - 4, 9, wall); c.rect(x + 2, top - 9, 2, 9, sh);
    const n = 3, step = (w - 4) / (n + 1);
    for (let k = 1; k <= n; k++) { const ox = Math.round(x + 2 + k * step) - 2; c.rect(ox, top - 7, 4, 4, '#3a4454'); c.set(ox, top - 7, wall); c.set(ox + 3, top - 7, wall); c.set(ox, top - 4, wall); c.set(ox + 3, top - 4, wall); }
    c.hline(x + 1, x + w - 2, top - 10, '#ffffff'); c.hline(x, x + w - 1, top, mix(wall, COOL, 0.25));
  } else if (type === 'glass') {
    // modern cam ofis bloğu (fotoğraflarda kıyıda görülen koyu cam cephe)
    c.rect(x, top, w, h, '#40586f'); c.rect(x, top, 3, h, '#2f4050');
    for (let y = top + 2; y < base; y += 4) c.hline(x + 3, x + w - 1, y, '#5c7a94');
    for (let i = x + 6; i < x + w; i += 6) c.vline(i, top, base - 1, '#33475a');
    for (let y = top + 1; y < base; y++) for (let i = x + 3; i < x + w; i++) if (hash(i, y, 21) < 0.04) c.set(i, y, '#9fc0dc');
    c.hline(x, x + w - 1, top, '#c9d4de');
  } else {
    // 1950–70 betonarme iş hanı: yatay bantlı cephe
    const wall = '#d7d3cb', sh = mix(wall, COOL, 0.4);
    c.rect(x, top, w, h, wall); c.rect(x, top, 3, h, sh);
    for (let fy = top + 3; fy < base - 4; fy += 7) { c.rect(x + 3, fy, w - 4, 3, '#3d4756'); for (let i = x + 6; i < x + w - 1; i += 5) c.vline(i, fy, fy + 2, '#9aa3ad'); }
    c.hline(x, x + w - 1, top, '#efede8');
    if (r() < 0.6) { c.rect(x + 3, top - 6, Math.min(16, w - 6), 5, '#eeeae2'); c.rect(x + 4, top - 5, Math.min(14, w - 8), 3, '#b8473a'); } // çatı reklam panosu
  }
}

// ======================= simge: kule + Galata tepesindeki bina kümesi (176×200) =======================
// Gerçekte çatı çizgisi kuleye doğru yükselir (kule sırtın en yüksek noktasında). Bu küme kuleyle
// birlikte hareket eder; böylece kule hangi konumda olursa olsun tepenin üstünde durur.
function landmark() {
  const W = 176, H = 200, c = new Canvas(W, H), cx = 88;
  c.blit(tower(), cx - 24, 0);
  const r = rng(311);
  const topAt = x => Math.round(104 + 86 * Math.pow(Math.min(1, Math.abs(x - cx) / cx), 1.5));
  // arka sıra (kuleye yakın, kulenin alt gövdesini örter)
  let x = 0;
  while (x < W) { const w = 9 + Math.floor(r() * 9), mid = x + w / 2; const top = topAt(mid) + Math.floor(r() * 6); apartment(c, x, H - 14, w, Math.max(4, H - 14 - top), r, { haze: 0.38, fh: 5 }); x += w; }
  // ön sıra (biraz daha aşağıda)
  x = -3;
  while (x < W) { const w = 11 + Math.floor(r() * 10), mid = x + w / 2; const top = topAt(mid) + 14 + Math.floor(r() * 6); if (top < H - 4) apartment(c, x, H, w, H - top, r, { haze: 0.3, fh: 5 }); x += w; }
  return c;
}

// ======================= orta plan: Karaköy kıyısı + Galata yamacı (400×180) =======================
function midground() {
  const W = 400, H = 180, c = new Canvas(W, H);
  c.wrap(o => {
    // satır 3: sırt (Galata–Pera sırtı), en uzak, küçük ve puslu; kule tepesinden alçak
    let r = rng(301), x = 0;
    while (x < W) { const w = 10 + Math.floor(r() * 12), h = 20 + Math.floor(r() * 16); apartment(c, o + x, H - 80, w, h + Math.round(5 * Math.sin((x / W) * Math.PI * 2)), r, { haze: 0.42, fh: 5 }); x += w; }
    // satır 2: orta yamaç
    r = rng(302); x = -4;
    while (x < W) { const w = 14 + Math.floor(r() * 12), h = 30 + Math.floor(r() * 16); apartment(c, o + x, H - 50, w, h, r, { haze: 0.25, fh: 6 }); x += w; }
    // satır 1: alt yamaç (Galata'nın dik sokaklarındaki yüksek apartmanlar)
    r = rng(303); x = -9;
    while (x < W) { const w = 14 + Math.floor(r() * 14), h = 38 + Math.floor(r() * 22); apartment(c, o + x, H - 18, w, h, r, { haze: 0.1, fh: 7 }); x += w; }
    // satır 0: Karaköy kıyısı (alt kısmı köprünün arkasında kalır)
    r = rng(304); x = 0;
    const seq = ['arches', 'plain', 'glass', 'oculus', 'plain', 'arches', 'apt', 'plain', 'oculus', 'glass', 'apt'];
    let i = 0;
    while (x < W) {
      const type = seq[i++ % seq.length];
      const w = type === 'apt' ? 18 + Math.floor(r() * 8) : 26 + Math.floor(r() * 18), h = 44 + Math.floor(r() * 16);
      const ww = Math.min(w, W - x);
      if (type === 'apt') apartment(c, o + x, H, ww, h, r, { fh: 9, front: true });
      else karakoyBlock(c, o + x, H, ww, h, r, type);
      x += ww;
    }
  });
  return c;
}

// ======================= kıyı: Galata Köprüsü (400×28, satır 12 = ufuk) =======================
function waterfront() {
  const W = 400, c = new Canvas(W, 28), Y = 12;
  const deckD = '#4d5a6b', deckL = '#8b98a8', rail = '#c9ced5', glassD = '#1f3a48';
  c.wrap(o => {
    // alt kat: lokantalar (cam cephe, beyaz tenteler, ışıklı tabelalar)
    c.rect(o, Y - 6, W, 6, '#d9dde1');
    for (let x = 0; x < W; x += 10) {
      c.rect(o + x + 1, Y - 5, 8, 4, glassD); c.hline(o + x + 1, o + x + 8, Y - 5, '#2f5566');
      if (hash(x, 1, 31) < 0.5) c.set(o + x + 3, Y - 3, '#ffd98a'); // içerideki lamba
      c.vline(o + x, Y - 6, Y - 1, '#eef0f2');
    }
    for (let x = 0; x < W; x++) c.set(o + x, Y - 6, (Math.floor(x / 3) % 2) ? '#f4f4f1' : '#c3ccd4'); // tente kenarı
    // ponton / ayak hattı ve su seviyesi
    c.rect(o, Y - 1, W, 2, '#30363f');
    for (let x = 6; x < W; x += 40) c.rect(o + x, Y + 1, 6, 3, '#262b33');
    // üst güverte kirişi (mavi-gri çelik) ve korkuluk
    c.rect(o, Y - 9, W, 3, deckD); c.hline(o, o + W - 1, Y - 9, deckL); c.hline(o, o + W - 1, Y - 7, '#3a4553');
    c.hline(o, o + W - 1, Y - 11, rail);
    for (let x = 0; x < W; x += 2) c.set(o + x, Y - 10, '#9aa3ad');
    // lamba direkleri (eşit aralık) ve flamalar
    for (let x = 4; x < W; x += 25) {
      c.vline(o + x, 0, Y - 11, '#5a6270'); c.set(o + x - 1, 0, '#e9eef2'); c.set(o + x + 1, 0, '#e9eef2');
      if ((x / 25) % 2 === 1) { c.rect(o + x + 1, 2, 2, 3, '#2e5fa8'); c.set(o + x + 1, 4, '#ffffff'); }
    }
    // olta atan balıkçılar (köprünün simgesi): korkulukta küçük figürler ve ince misina
    for (let x = 13; x < W; x += 37) { c.set(o + x, Y - 12, '#3a3f48'); c.set(o + x, Y - 13, '#c79a7a'); c.line(o + x + 1, Y - 13, o + x + 6, Y - 1, '#7c8794'); }
    // suda yansıma
    for (let y = Y + 2; y < 28; y++) for (let x = 0; x < W; x++) if (hash(x, y, 41) < 0.08 - (y - Y) * 0.004) c.set(o + x, y, '#a9bccd', 140);
  });
  return c;
}

// ======================= uzak plan (400×190): pusta kalan uzak yüksek yapılar ve tepeler =======================
function distant() {
  const W = 400, H = 190, c = new Canvas(W, H);
  const far = '#c6d3e2', near = '#b4c4d8';
  c.wrap(o => {
    for (let x = 0; x < W; x++) { const h = 70 + Math.round(10 * Math.sin((x / W) * Math.PI * 2 + 1) + 4 * Math.sin((x / W) * Math.PI * 6)); c.vline(o + x, H - h, H - 1, far); }
    const r = rng(305);
    // Levent–Maslak yönünde, pusta seçilen ince yüksek yapılar (sırtın arkasında, seyrek)
    for (let k = 0; k < 4; k++) {
      const x = 40 + k * 95 + Math.floor(r() * 30), w = 7 + Math.floor(r() * 6), h = 96 + Math.floor(r() * 34);
      c.rect(o + x, H - h, w, h, near); c.vline(o + x + w - 1, H - h, H - 1, '#d3dde9'); c.hline(o + x, o + x + w - 1, H - h, '#d3dde9');
      for (let y = H - h + 3; y < H; y += 3) c.hline(o + x + 1, o + x + w - 2, y, '#bccbdd');
    }
  });
  return c;
}

// ======================= Şehir Hatları vapuru (96×30), sola bakar =======================
function ferry({ white = '#f3f1ec', whiteS = '#c9ccd2', glass = '#2c3a4e' } = {}) {
  const W = 96, H = 30, c = new Canvas(W, H);
  const hull = '#1d2027', ochre = '#d39a2e';
  // gövde: koyu alt gövde, sivri baş (solda), yuvarlak kıç (sağda)
  c.poly([[1, 21], [94, 21], [92, 27], [8, 27]], hull);
  c.hline(2, 93, 21, '#3a3f4a');
  // ana güverte (beyaz gövde bandı + pencere dizisi)
  c.poly([[1, 21], [4, 15], [94, 15], [94, 21]], white);
  c.hline(4, 93, 15, '#ffffff'); c.hline(2, 93, 20, whiteS);
  for (let x = 8; x < 90; x += 3) c.rect(x, 17, 2, 2, glass);
  for (let x = 10; x < 90; x += 9) c.set(x, 19, '#e8742c'); // can simitleri
  // üst güverte (biraz daha kısa), açık kıç güvertesi korkuluğu
  c.rect(10, 9, 70, 6, white); c.hline(10, 79, 9, '#ffffff'); c.hline(10, 79, 14, whiteS);
  for (let x = 13; x < 78; x += 3) c.rect(x, 11, 2, 2, glass);
  for (let x = 80; x < 93; x += 2) c.set(x, 14, '#8a8f98'); c.hline(80, 92, 13, '#8a8f98');
  // köprü üstü (kaptan köşkü) önde
  c.rect(14, 5, 14, 4, white); c.hline(14, 27, 5, '#ffffff'); for (let x = 15; x < 27; x += 2) c.set(x, 7, glass);
  // baca: beyaz gövde, turuncu-hardal bant, siyah ağız
  c.rect(52, 1, 7, 8, white); c.rect(52, 1, 7, 2, ochre); c.hline(52, 58, 0, hull); c.vline(52, 1, 8, whiteS);
  // direkler (hardal)
  c.vline(9, 0, 9, ochre); c.vline(86, 2, 9, ochre); c.hline(8, 10, 2, ochre);
  return c;
}

function build(outDir) {
  const d = `${outDir}/backgrounds/galata`;
  return [
    landmark().save(`${outDir}/landmarks/galata.png`),
    midground().save(`${d}/midground.png`),
    waterfront().save(`${d}/waterfront.png`),
    distant().save(`${d}/distant.png`),
    ferry().save(`${d}/ferry.png`),
  ];
}

module.exports = { build, tower, landmark, midground, waterfront, distant, ferry };

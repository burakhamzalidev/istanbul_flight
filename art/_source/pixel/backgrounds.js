// Bölge arka plan katmanları (pixel art). Her bölge için:
//   sky.png (160×298, yatay döşenir) · sun.png (96×96) · clouds.png (256×48 atlas)
//   distant.png (400×110) · midground.png (400×140) · waterfront.png (400×28, satır 12 = ufuk)
//   water.png (128×182) · water_hi.png (128×182, parıltı) · ferry.png (72×28)
'use strict';
const { Canvas, hex, mix, rng, bayer } = require('./lib');
const { ZONES, HORIZON, SCREEN_H } = require('./zones');

const W = 400; // döşenebilir şerit genişliği (1600 dünya birimi)
const WATER_H = SCREEN_H - HORIZON; // 182

// ---------------- gökyüzü ----------------
function sky(z) {
  const c = new Canvas(160, HORIZON);
  c.gradientV(0, 0, 160, HORIZON, z.sky);
  return c;
}

// ---------------- güneş / ay ----------------
function sun(z) {
  const s = z.sun, c = new Canvas(96, 96), cx = 48, cy = 48;
  // dithered hale halkaları
  for (let y = 0; y < 96; y++) for (let x = 0; x < 96; x++) {
    const d = Math.hypot(x + 0.5 - cx, y + 0.5 - cy);
    if (d > 46) continue;
    const t = 1 - (d - s.r) / (46 - s.r);
    if (d > s.r && t > 0) {
      const level = Math.pow(t, s.kind === 'moon' ? 2.4 : 1.6);
      if (level * 0.9 > bayer(x, y)) c.set(x, y, s.halo, s.kind === 'moon' ? 70 : 120);
    }
  }
  if (s.kind === 'sun') {
    c.ellipse(cx, cy, s.r, s.r, (nx, ny) => (nx * nx + ny * ny < 0.45 ? s.core : s.mid));
  } else {
    // hilal: disk − kaydırılmış disk, birkaç krater, ince ışık kenarı
    c.ellipse(cx, cy, s.r, s.r, s.core);
    c.ellipse(cx + s.r * 0.55, cy - s.r * 0.3, s.r * 0.9, s.r * 0.9, null);
    for (let y = 0; y < 96; y++) for (let x = 0; x < 96; x++) {
      const inA = Math.hypot(x + 0.5 - cx, y + 0.5 - cy) <= s.r;
      const inB = Math.hypot(x + 0.5 - (cx + s.r * 0.55), y + 0.5 - (cy - s.r * 0.3)) <= s.r * 0.9;
      if (inA && inB) c.clear(x, y);
      else if (inA && Math.hypot(x + 0.5 - (cx + s.r * 0.55), y + 0.5 - (cy - s.r * 0.3)) <= s.r * 1.08) c.set(x, y, s.mid);
    }
    c.set(cx - 6, cy + 2, s.mid); c.set(cx - 5, cy + 5, s.mid); c.set(cx - 8, cy - 3, s.mid);
  }
  return c;
}

// ---------------- bulutlar ----------------
function cloudSprite(z, w, h, seed) {
  const r = rng(seed), c = new Canvas(w, h), col = z.clouds;
  const blobs = [];
  const n = Math.round(w / 12);
  for (let i = 0; i < n; i++) {
    const t = i / (n - 1);
    const bx = 6 + t * (w - 12), by = h - 8 - Math.sin(t * Math.PI) * (h * 0.45) * (0.6 + r() * 0.5);
    blobs.push([bx, by, 5 + r() * 6 + Math.sin(t * Math.PI) * 6]);
  }
  const inCloud = (x, y) => y < h - 3 && blobs.some(([bx, by, br]) => Math.hypot(x - bx, (y - by) * 1.3) < br);
  const litFromBelow = z === ZONES.kizkulesi || z === ZONES.halic;
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    if (!inCloud(x + 0.5, y + 0.5)) continue;
    // üstten (gündüz) ya da alttan (şafak/gün batımı) aydınlatma, dithered geçiş
    const above = inCloud(x + 0.5, y - 2.5), below = inCloud(x + 0.5, y + 3.5);
    const vt = y / h;
    let tone = litFromBelow ? vt : 1 - vt;
    if (!above && !litFromBelow) tone += 0.35;
    if (!below && litFromBelow) tone += 0.35;
    const cc = tone + (bayer(x, y) - 0.5) * 0.3;
    c.set(x, y, cc > 0.85 ? col.light : cc > 0.55 ? col.mid : cc > 0.3 ? col.shade : col.deep);
  }
  return c;
}
function clouds(z) {
  const c = new Canvas(256, 48);
  c.blit(cloudSprite(z, 112, 44, 3), 0, 2);
  c.blit(cloudSprite(z, 80, 34, 7), 114, 12);
  c.blit(cloudSprite(z, 60, 26, 11), 196, 20);
  return c;
}

// ---------------- mimari yardımcılar ----------------
function tileRoof(c, z, x0, x1, top, base, opts = {}) {
  // kırma çatı: alt kenar geniş, üst kenar dar; kiremit sıraları (2 px), ışık yönüne göre ton
  const h = base - top;
  for (let y = top; y < base; y++) {
    const t = (y - top) / Math.max(1, h);
    const inset = Math.round((1 - t) * (opts.pitch ?? 3));
    for (let x = x0 + inset; x <= x1 - inset; x++) {
      const row = (y - top) % 3;
      let col = row === 2 ? z.roofShade : z.roof;
      if (row !== 2 && ((x + Math.floor((y - top) / 3) * 2) % 4 === 0)) col = mix(z.roof, z.roofShade, 0.45);
      const side = z.sunSide > 0 ? x > (x0 + x1) / 2 : x < (x0 + x1) / 2;
      if (side && row !== 2) col = mix(col, '#ffe0b0', 0.18);
      c.set(x, y, col);
    }
  }
  c.hline(x0 + (opts.pitch ?? 3), x1 - (opts.pitch ?? 3), top - 1, mix(z.roof, '#ffffff', 0.15));
}
function windowAt(c, z, x, y, w, h, r, opts = {}) {
  const lit = z.lit && r() < z.litChance;
  c.rect(x - 1, y - 1, w + 2, h + 2, opts.frame || mix(z.ink, '#ffffff', 0.55));
  c.rect(x, y, w, h, lit ? z.lit : z.glass);
  if (lit) { c.set(x, y, mix(z.lit, '#ffffff', 0.5)); }
  else if (!z.lit) c.set(x + w - 1, y, mix(z.glass, '#a0c4e8', 0.6)); // gündüz cam yansıması
  if (opts.arch) c.hline(x, x + w - 1, y - 1, z.glass);
  if (w >= 3 && !opts.noMullion) c.vline(x + Math.floor(w / 2), y, y + h - 1, opts.frame || mix(z.ink, '#ffffff', 0.4));
}

/** Tarihi ahşap ev / apartman / yalı. base = alt kenar (y), kind: 'wood'|'apartment'|'yali'|'silhouette' */
function building(c, z, x, base, w, h, r, kind) {
  const wall = z.walls[Math.floor(r() * z.walls.length)];
  const dark = mix(wall, z.shade, 0.45), light = mix(wall, '#fff2d0', 0.18);
  const top = base - h;
  c.rect(x, top, w, h, wall);
  // malzeme dokusu
  if (kind === 'wood') for (let y = top + 2; y < base; y += 3) for (let i = x; i < x + w; i++) if ((i + y) % 7) c.set(i, y, mix(wall, z.shade, 0.18));
  if (kind === 'apartment') for (let y = top + 1; y < base; y += 2) for (let i = x; i < x + w; i++) if (bayer(i, y) < 0.12) c.set(i, y, mix(wall, z.shade, 0.15));
  // gölge ve ışık kenarları
  const shadeX = z.sunSide > 0 ? x : x + w - 2, lightX = z.sunSide > 0 ? x + w - 1 : x;
  c.rect(shadeX, top, 2, h, dark);
  c.vline(lightX, top, base - 1, z.rimLight || light);
  // katlar ve pencereler
  const floorH = kind === 'apartment' ? 13 : 12;
  for (let fy = top + 4, fl = 0; fy + 8 < base - 2; fy += floorH, fl++) {
    if (kind !== 'silhouette') c.hline(x, x + w - 1, fy - 2, mix(wall, z.shade, 0.3)); // kat silmesi
    const cols = Math.max(1, Math.floor((w - 4) / 7));
    const gap = (w - cols * 4) / (cols + 1);
    for (let k = 0; k < cols; k++) {
      const wx = Math.round(x + gap + k * (4 + gap));
      windowAt(c, z, wx, fy, kind === 'apartment' ? 3 : 4, kind === 'apartment' ? 7 : 6, r, { arch: kind === 'apartment' });
      if (kind === 'apartment' && fl > 0 && r() < 0.55) { // ferforje balkon
        c.hline(wx - 2, wx + 4, fy + 8, z.ink); for (let b = wx - 2; b <= wx + 4; b += 2) c.set(b, fy + 7, z.ink);
      }
    }
    // cumba (ahşap evlerde üst katlarda çıkma)
    if (kind === 'wood' && fl === 1 && w >= 14 && r() < 0.7) {
      const cw = Math.max(8, Math.floor(w * 0.55)), cx0 = x + Math.floor((w - cw) / 2);
      c.rect(cx0 - 1, fy - 3, cw + 2, 11, mix(wall, '#fff2d0', 0.08));
      c.hline(cx0 - 1, cx0 + cw, fy + 8, z.shade);
      c.hline(cx0 - 1, cx0 + cw, fy + 9, mix(z.shade, z.ink, 0.4));
      for (let k = 0; k < Math.floor(cw / 5); k++) windowAt(c, z, cx0 + 1 + k * 5, fy - 1, 3, 6, r, { noMullion: true });
    }
    if (kind === 'yali' && fl === 0) { // yalı: geniş saçak ve iskele kapısı
      c.rect(x + Math.floor(w / 2) - 2, base - 7, 5, 7, z.glass);
    }
  }
  // çatı
  if (kind === 'apartment') {
    c.rect(x - 1, top - 2, w + 2, 2, light); // korniş
    tileRoof(c, z, x, x + w - 1, top - 7, top - 2, { pitch: 2 });
    if (r() < 0.6) { const bx = x + 2 + Math.floor(r() * (w - 6)); c.rect(bx, top - 12, 3, 6, '#8a4a3a'); c.hline(bx - 1, bx + 3, top - 12, z.ink); }
  } else if (kind === 'yali') {
    c.rect(x - 3, top - 2, w + 6, 2, mix(z.roof, z.ink, 0.3)); // geniş saçak
    tileRoof(c, z, x - 2, x + w + 1, top - 7, top - 2, { pitch: 4 });
  } else {
    tileRoof(c, z, x - 2, x + w + 1, top - 8, top, { pitch: 4 });
    if (r() < 0.65) { const bx = x + 2 + Math.floor(r() * (w - 5)); c.rect(bx, top - 13, 3, 7, '#7a4636'); c.set(bx, top - 13, '#5a3226'); c.hline(bx - 1, bx + 3, top - 14, z.ink); }
  }
}

function tree(c, z, x, base, h, r) {
  const [d, l] = z.trees;
  c.rect(x, base - 4, 2, 4, mix(d, z.ink, 0.4));
  const rad = h / 2;
  c.ellipse(x + 1, base - 4 - rad, rad * 0.9, rad, (nx, ny, X, Y) => (ny < -0.2 && nx * z.sunSide > -0.2 && bayer(X, Y) < 0.55 ? l : d));
}

// küçük (uzak plan) cami silüeti: sadece arka plan, saygın ve sade
function farMosque(c, x, base, s, col, rim, sunSide) {
  c.rect(x - 9 * s, base - 5 * s, 18 * s, 5 * s, col);
  c.ellipse(x, base - 5 * s, 6 * s, 5 * s, col);
  c.ellipse(x - 6 * s, base - 5 * s, 3 * s, 2.5 * s, col);
  c.ellipse(x + 6 * s, base - 5 * s, 3 * s, 2.5 * s, col);
  for (const mx of [-11 * s, 11 * s]) {
    const h = 22 * s;
    c.rect(x + mx, base - h, Math.max(1, s), h, col);
    c.set(x + mx - 1, base - h * 0.7, col); c.set(x + mx + 1, base - h * 0.7, col);
    c.vline(x + mx, base - h - 3 * s, base - h, col);
    if (rim) c.vline(x + mx + (sunSide > 0 ? Math.max(1, s) - 0 : -1), base - h, base - 1, rim);
  }
  if (rim) for (let y = 0; y < 5 * s; y++) c.set(x + Math.round(Math.sqrt(Math.max(0, 1 - (y / (5 * s)) ** 2)) * 6 * s) * sunSide, base - 5 * s - y, rim);
}

// ---------------- uzak şehir ----------------
function distant(key, z) {
  const c = new Canvas(W, 110), r = rng(key.length * 97 + 5), B = 110;
  const { far, near, rim, lit } = z.distant;
  c.wrap(o => {
    const rr = rng(13);
    if (key === 'halic' || key === 'galata') {
      // tarihi yarımada: ev dokusu + cami silüetleri (uzak, saygın)
      const hill = x => (key === 'galata' ? 46 : 30) + (key === 'galata' ? 22 : 12) * Math.sin((x / W) * Math.PI * 2 + 0.8) + 6 * Math.sin((x / W) * Math.PI * 6);
      for (let x = 0; x < W; ) { const w = 4 + Math.floor(rr() * 6), h = 4 + Math.floor(rr() * 10); const hh = hill(x); c.rect(o + x, B - hh - h, w, hh + h, far); if (rr() < 0.7) c.set(o + x + 1 + Math.floor(rr() * (w - 2)), B - hh - h + 2 + Math.floor(rr() * 3), mix(far, z.ink, 0.25)); x += w; }
      if (key === 'halic') { farMosque(c, o + 70, B - hill(70) + 2, 2, far, null, z.sunSide); farMosque(c, o + 330, B - hill(330) + 2, 2, far, null, z.sunSide); }
      else farMosque(c, o + 250, B - hill(250) + 2, 1, far, null, z.sunSide);
      for (let x = 0; x < W; ) { const w = 5 + Math.floor(rr() * 8), h = 4 + Math.floor(rr() * 10); const hh = hill(x) * 0.55; c.rect(o + x, B - hh - h, w, hh + h, near); for (let k = 0; k < w - 2; k += 3) if (rr() < 0.5) c.set(o + x + 1 + k, B - hh - h + 3, mix(near, z.ink, 0.3)); x += w + Math.floor(rr() * 2); }
    } else if (key === 'kizkulesi') {
      // Üsküdar tepeleri + yamaçta evler + küçük cami silüeti
      for (let x = 0; x < W; x++) { const hh = 34 + 16 * Math.sin((x / W) * Math.PI * 2 + 0.5) + 8 * Math.sin((x / W) * Math.PI * 6); c.vline(o + x, B - hh, B - 1, far); }
      for (let x = 0; x < W; x += 3) { const hh = 14 + 8 * Math.sin((x / W) * Math.PI * 4 + 1); const h = 3 + Math.floor(rr() * 6); c.rect(o + x, B - hh - h, 3, hh + h, near); if (lit && rr() < 0.3) c.set(o + x + 1, B - hh - h + 2, lit); }
      farMosque(c, o + 150, B - 26, 1, near, rim, z.sunSide);
      farMosque(c, o + 310, B - 22, 1, near, rim, z.sunSide);
      c.vline(o + 214, B - 76, B - 46, far); c.hline(o + 211, o + 217, B - 66, far); // Çamlıca kulesi
    } else {
      // ağaçlı tepeler (Boğaz kuzeyi), yamaçta seyrek ışıklar
      for (let x = 0; x < W; x++) { const hh = 40 + 18 * Math.sin((x / W) * Math.PI * 2 + 1.3) + 6 * Math.sin((x / W) * Math.PI * 10); c.vline(o + x, B - hh, B - 1, far); }
      for (let x = 0; x < W; x += 4) { const hh = 34 + 18 * Math.sin((x / W) * Math.PI * 2 + 1.3); c.ellipse(o + x + 2, B - hh, 3 + rr() * 2, 3, near); }
      for (let x = 0; x < W; x += 4) { const hh = 16 + 6 * Math.sin((x / W) * Math.PI * 4); for (let k = 0; k < 4; k++) c.vline(o + x + k, B - hh, B - 1, near); }
      if (lit) for (let i = 0; i < 70; i++) { const x = Math.floor(rr() * W), y = B - 4 - Math.floor(rr() * 30); if (c.get(((o + x) % W + W) % W, y)?.[3]) c.set(o + x, y, lit); }
    }
  });
  // güneş tarafında ince kenar ışığı
  if (rim) for (let x = 0; x < W; x++) for (let y = 1; y < B; y++) if (c.alpha(x, y) && !c.alpha(x, y - 1)) { c.set(x, y, rim); break; }
  return c;
}

// ---------------- orta plan binalar ----------------
function midground(key, z) {
  const H = 140, c = new Canvas(W, H), B = H; // alt kenar = ufuk
  const kind = { halic: 'wood', galata: 'apartment', kizkulesi: 'wood', kopru: 'yali', rumeli: 'yali' }[key];
  c.wrap(o => {
    const r = rng(key.length * 131 + 17);
    let x = 0;
    while (x < W - 4) {
      const roll = r();
      if ((key === 'rumeli' && roll < 0.6) || ((key === 'kopru' || key === 'halic') && roll < 0.18) || (key === 'kizkulesi' && roll < 0.3)) {
        const h = 12 + r() * (key === 'rumeli' ? 20 : 14);
        tree(c, z, o + x + 4, B, h, r); if (key === 'rumeli' || key === 'kopru') tree(c, z, o + x + 9, B, h * 0.8, r);
        x += key === 'rumeli' ? 12 : 9; continue;
      }
      const w = kind === 'yali' ? 22 + Math.floor(r() * 16) : kind === 'apartment' ? 16 + Math.floor(r() * 10) : 13 + Math.floor(r() * 9);
      const h = kind === 'apartment' ? 34 + Math.floor(r() * 24) : kind === 'yali' ? 20 + Math.floor(r() * 10) : key === 'kizkulesi' ? 15 + Math.floor(r() * 12) : 18 + Math.floor(r() * 16);
      building(c, z, o + x, B - (key === 'kizkulesi' ? Math.floor(r() * 10) : 0), w, h, r, kind);
      x += w + (kind === 'yali' ? 4 + Math.floor(r() * 4) : 1);
    }
  });
  // gün batımında ön plan siluetleşir (ters ışık), kenar ışığı zaten binalarda
  return c;
}

// ---------------- kıyı şeridi (satır 12 = ufuk) ----------------
function waterfront(key, z) {
  const c = new Canvas(W, 28), Y = 12;
  c.wrap(o => {
    const r = rng(key.length * 7 + 3);
    if (key === 'kizkulesi' || key === 'rumeli') {
      // kayalık kıyı
      for (let x = 0; x < W; x++) { const h = 3 + Math.floor(3 * Math.abs(Math.sin(x * 0.37)) + 2 * Math.abs(Math.sin(x * 0.11))); c.vline(o + x, Y - h, Y + 2, x % 9 < 5 ? mix(z.shade, z.ink, 0.3) : z.shade); }
      for (let x = 0; x < W; x += 17) c.set(o + x, Y - 3, z.rimLight || mix(z.shade, '#ffffff', 0.25));
    } else {
      // taş rıhtım + babalar
      c.rect(o, Y - 3, W, 4, mix(z.shade, '#c8c0b8', 0.35));
      for (let x = 0; x < W; x += 6) c.vline(o + x, Y - 3, Y, mix(z.shade, z.ink, 0.2));
      c.hline(o, o + W - 1, Y - 4, mix(z.shade, '#ffffff', 0.4));
      for (let x = 10; x < W; x += 37) { c.rect(o + x, Y - 6, 2, 3, z.ink); }
    }
    // iskeleler ve küçük tekneler
    for (let x = 30 + Math.floor(r() * 40); x < W - 20; x += 90 + Math.floor(r() * 60)) {
      for (let p = 0; p < 4; p++) c.vline(o + x + p * 4, Y - 1, Y + 8, mix(z.roofShade, z.ink, 0.3));
      c.rect(o + x - 1, Y - 2, 15, 2, mix(z.roof, '#8a6a50', 0.5));
      const bx = o + x + 18, bc = ['#d9e6f0', '#c8473a', '#2e8b99', '#e8b04b'][Math.floor(r() * 4)];
      c.rect(bx, Y + 3, 9, 2, bc); c.rect(bx + 1, Y + 5, 7, 1, mix(bc, z.ink, 0.5)); c.vline(bx + 4, Y - 2, Y + 2, z.ink);
    }
    if (key === 'rumeli' || key === 'kopru') for (let x = 20; x < W; x += 48) { // sahil fenerleri
      c.vline(o + x, Y - 12, Y - 3, z.ink); c.rect(o + x - 1, Y - 14, 3, 2, z.lit || '#ffd27a'); c.set(o + x, Y - 15, z.ink);
    }
  });
  return c;
}

// ---------------- su ----------------
function water(key, z) {
  const c = new Canvas(128, WATER_H);
  c.gradientV(0, 0, 128, WATER_H, z.water);
  const r = rng(key.length * 3 + 1);
  // dalga sırtları: ufka yakın sık ve ince, aşağıda seyrek ve uzun
  for (let y = 3; y < WATER_H; y += 2 + Math.floor(y / 26)) {
    const depth = y / WATER_H, len = 2 + Math.floor(depth * 8), count = Math.max(2, Math.floor(10 - depth * 6));
    for (let k = 0; k < count; k++) {
      const x0 = Math.floor(r() * 128);
      const base = c.get(x0, y);
      const crest = mix([base[0], base[1], base[2]], z.waterHi[0], 0.22 + 0.15 * (1 - depth));
      for (let i = 0; i < len; i++) c.set((x0 + i) % 128, y, crest);
      for (let i = 1; i < len - 1; i++) c.set((x0 + i) % 128, y + 1, mix([base[0], base[1], base[2]], z.ink, 0.18)); // dalga gölgesi
    }
  }
  // gece/akşam: kıyı ışıklarının dikey, kesik yansımaları
  if (z.lit) for (let k = 0; k < 9; k++) {
    const x = Math.floor(r() * 128); let y = 1;
    while (y < 40 + r() * 30) { const l = 1 + Math.floor(r() * 3); for (let i = 0; i < l; i++) c.set(x + (y % 4 === 0 ? 1 : 0), y + i, z.reflect, 150); y += l + 1 + Math.floor(y / 12); }
  }
  return c;
}
function waterHi(key, z) {
  const c = new Canvas(128, WATER_H), r = rng(key.length * 11 + 9);
  for (let i = 0; i < 34; i++) {
    const y = Math.floor(Math.pow(r(), 1.4) * WATER_H), x = Math.floor(r() * 128), l = 1 + Math.floor((y / WATER_H) * 4);
    for (let j = 0; j < l; j++) c.set((x + j) % 128, y, z.waterHi[1], 200);
  }
  return c;
}

// ---------------- vapur (ön plan, kendi hızıyla geçer) ----------------
function ferry(key, z) {
  const c = new Canvas(72, 28), night = !!z.lit && key !== 'halic';
  const white = night ? mix('#e8e4dc', z.shade, 0.45) : key === 'kizkulesi' ? '#f6d6b8' : '#f2f0ea';
  const hull = '#1f2a44', red = '#c8473a';
  c.poly([[2, 18], [70, 18], [64, 25], [7, 25]], hull);
  c.hline(4, 67, 18, red);
  c.rect(8, 11, 56, 7, white); c.rect(16, 6, 38, 5, white);
  c.hline(8, 63, 10, mix(white, z.shade, 0.3)); c.hline(16, 53, 5, mix(white, z.shade, 0.3));
  for (let x = 10; x < 62; x += 4) c.rect(x, 13, 2, 2, night ? z.lit : '#2c3a50');
  for (let x = 18; x < 52; x += 4) c.rect(x, 7, 2, 2, night ? z.lit : '#2c3a50');
  c.rect(33, 0, 5, 6, '#efe4cf'); c.rect(33, 0, 5, 2, '#1b1b22'); // baca
  c.vline(12, 2, 10, '#1b1b22'); c.vline(60, 3, 10, '#1b1b22'); // direkler
  if (night) { c.set(12, 2, '#ff5050'); c.set(60, 3, '#ffffff'); }
  return c;
}

function build(outDir) {
  const files = [];
  for (const [key, z] of Object.entries(ZONES)) {
    const d = `${outDir}/backgrounds/${key}`;
    files.push(sky(z).save(`${d}/sky.png`));
    files.push(sun(z).save(`${d}/sun.png`));
    files.push(clouds(z).save(`${d}/clouds.png`));
    files.push(distant(key, z).save(`${d}/distant.png`));
    files.push(midground(key, z).save(`${d}/midground.png`));
    files.push(waterfront(key, z).save(`${d}/waterfront.png`));
    files.push(water(key, z).save(`${d}/water.png`));
    files.push(waterHi(key, z).save(`${d}/water_hi.png`));
    files.push(ferry(key, z).save(`${d}/ferry.png`));
  }
  return files;
}

module.exports = { build, sky, distant, midground, waterfront, water, waterHi, ferry, sun, clouds };

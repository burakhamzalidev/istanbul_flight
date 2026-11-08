// L6 engel kitleri (pixel art, v3 · docs/18). Parça boyutları dünya birimiyle aynıdır (ObstaclePiecePlan değişmez),
// atlas 1/2 çözünürlüktedir: 1 px = 2 dünya birimi (v2'de 4). Parçalar iki satıra dizilir (üstte dört gövde
// karosu, altta başlıklar ve taban): atlas 400×260 px. v2'deki boş ışık maskesi satırı kaldırıldı (ışıklar renge
// işlenmiştir).
// Kurallar: gövde = hitbox genişliği (98 px) ve tamamen opak; başlıklar en fazla 7 px (14 birim) taşar; başlık
// sınırının altında, gövde sütunlarında şeffaf piksel bırakılmaz (görselsiz hitbox yok); sınırın üstünde
// yalnızca çarpışmasız süs (baca, ikaz ışığı); tarihi/dini yapı engel olarak kullanılmaz.
// Gövde karoları 96 px'de dikişsiz döşenir: kat yüksekliği 24 px (48 birim).
'use strict';
const fs = require('fs');
const path = require('path');
const { Canvas, mix, rng, bayer } = require('./lib');

const S = 2; // dünya birimi / px
const BW = 196, CW = 224, OV = 14, TH = 192, CAPH = 128, BASEH = 320;
const SLOT = { bottomBodyA: [0, 0], bottomBodyB: [200, 0], topBodyA: [400, 0], topBodyB: [600, 0], bottomCap: [0, 200], topCap: [232, 200], bottomBase: [464, 200] };
const KIT_W = 800, KIT_H = 200 + BASEH; // dünya birimi: 800 × 520
const px = v => v / S;
const bw = px(BW), cw = px(CW), ov = px(OV), th = px(TH), caph = px(CAPH), baseh = px(BASEH); // 98, 112, 7, 96, 64, 160
const BX0 = ov, BX1 = ov + bw - 1; // başlıklarda gövde (hitbox) sütunları: 7..104

// ---------------- renk ----------------
const SHADOW = '#231b38', LIGHT = '#fff2d6';
const dk = (c, t = 0.3) => mix(c, SHADOW, t);
const lt = (c, t = 0.3) => mix(c, LIGHT, t);
/** Karo içinde tekrarlanabilir sözde rastgele (aynı girdi → aynı değer). */
const h2 = (a, b, s = 0) => { let v = (a * 374761393 + b * 668265263 + s * 2147483647) >>> 0; v = Math.imul(v ^ (v >>> 13), 1274126177) >>> 0; return ((v ^ (v >>> 16)) >>> 0) / 4294967296; };

// ---------------- doku yardımcıları ----------------
/** Sıva: hafif benekli, karo boyunca tekrarlanır. */
function plaster(c, x, y, w, h, base, seed = 0, amt = 0.07) {
  c.rect(x, y, w, h, base);
  for (let j = y; j < y + h; j++) for (let i = x; i < x + w; i++) {
    const v = h2(i, j % 96, seed);
    if (v < amt) c.set(i, j, dk(base, 0.1)); else if (v > 1 - amt * 0.6) c.set(i, j, lt(base, 0.1));
  }
}
/** Ahşap bağdadi kaplama: 3 px tahtalar, üstte ışık, altta gölge çizgisi, ara ara ek yeri. */
function clapboard(c, x, y, w, h, base, seed = 0) {
  for (let j = y; j < y + h; j++) {
    const k = ((j % 3) + 3) % 3, board = Math.floor(j / 3);
    const col = k === 0 ? lt(base, 0.16) : k === 2 ? dk(base, 0.3) : base;
    c.hline(x, x + w - 1, j, col);
    if (k === 1) for (let i = x; i < x + w; i++) if (h2(i, board % 32, seed) < 0.035) c.set(i, j, dk(base, 0.22));
  }
  for (let b = Math.floor(y / 3); b * 3 < y + h; b++) { // tahta ekleri
    const jx = x + 4 + Math.floor(h2(b % 32, 7, seed) * (w - 8));
    for (let j = b * 3; j < b * 3 + 3; j++) if (j >= y && j < y + h) c.set(jx, j, dk(base, 0.4));
  }
}
/** Kesme taş (ashlar): sıralar kaydırmalı, her blok kendi tonunda; blok üstü ışık, altı gölge. */
function stones(c, x, y, w, h, base, seed = 0, { bh = 6, bl = 12, joint, vary = 0.08, warm = null, irregular = false } = {}) {
  joint = joint || dk(base, 0.42);
  const rowsPerTile = Math.round(96 / bh);
  const blocksOf = row => { // düzensiz örgü: blok boyları satıra göre değişir (karo boyunca tekrarlanır)
    const out = []; let p = -Math.floor(h2(row % rowsPerTile, 99, seed) * bl), n = 0;
    while (p < w) { const len = Math.round(bl * (0.55 + h2(row % rowsPerTile, n, seed + 7) * 0.9)); out.push([p, len, n]); p += len; n++; }
    return out;
  };
  for (let j = y; j < y + h; j++) {
    const row = Math.floor(j / bh), r = ((j % bh) + bh) % bh;
    const shift = (row % 2) * Math.floor(bl / 2);
    const blocks = irregular ? blocksOf(row) : null;
    for (let i = x; i < x + w; i++) {
      let col, cx;
      if (blocks) { const b = blocks.find(([p, len]) => i - x >= p && i - x < p + len); col = b[2]; cx = i - x - b[0]; }
      else { col = Math.floor((i - x + shift) / bl); cx = (i - x + shift) % bl; }
      const v = h2(col, row % Math.round(96 / bh), seed);
      let tone = v < 0.33 ? dk(base, vary) : v > 0.7 ? lt(base, vary) : base;
      if (warm && v > 0.85) tone = mix(base, warm, 0.22);
      let p = tone;
      if (r === bh - 1 || cx === 0) p = joint;
      else if (r === 0) p = lt(tone, 0.18);
      else if (r === bh - 2) p = dk(tone, 0.12);
      else if (bayer(i, j) < 0.06) p = dk(tone, 0.12);
      c.set(i, j, p);
    }
  }
}
/** Tuğla. */
function bricks(c, x, y, w, h, base) {
  for (let j = y; j < y + h; j++) {
    const row = Math.floor((j - y) / 3), r = (j - y) % 3;
    for (let i = x; i < x + w; i++) {
      const joint = r === 2 || (i - x + (row % 2) * 3) % 6 === 0;
      c.set(i, j, joint ? dk(base, 0.4) : r === 0 ? lt(base, 0.12) : base);
    }
  }
}
/** Pencere: çerçeve, iki tonlu cam (gök yansıması), kayıt ve kanat, denizlik; isteğe bağlı kemer, alınlık, panjur. */
function win(c, x, y, w, h, { frame = '#f2e8d6', glass = '#24324c', lit = null, shutter = null, arch = false, pediment = null, sill = true, keystone = null, curtain = null } = {}) {
  if (arch) { // yarım daire kemer (çerçeveli)
    const r = Math.floor((w + 2) / 2), cx = x + (w - 1) / 2;
    for (let j = 0; j <= r; j++) for (let i = -r; i <= r; i++) {
      const d = Math.sqrt((i) * (i) + (j) * (j));
      const X = Math.round(cx + i), Y = y - j;
      if (d <= r + 0.3) c.set(X, Y, d > r - 1.2 ? frame : glassAt(X - x, j, true));
    }
    if (keystone) c.rect(Math.round(cx) - 1, y - r - 1, 3, 3, keystone);
  }
  function glassAt(i, j, top) {
    if (lit) return (i + j) % 5 === 0 ? lt(lit, 0.4) : lit;
    if (top || i + j < 3) return mix(glass, '#8fb4dc', 0.45);
    if (j < h * 0.35 && bayer(x + i, y + j) < 0.3) return mix(glass, '#5d7ea6', 0.35);
    return glass;
  }
  c.rect(x - 1, y - 1, w + 2, h + 2, frame);
  for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) c.set(x + i, y + j, glassAt(i, j, false));
  if (curtain) { c.rect(x, y, 2, Math.ceil(h * 0.6), curtain); c.rect(x + w - 2, y, 2, Math.ceil(h * 0.6), curtain); }
  if (w >= 5) c.vline(x + Math.floor(w / 2), y, y + h - 1, frame);
  if (h >= 8) c.hline(x, x + w - 1, y + Math.floor(h * 0.34), frame);
  c.hline(x, x + w - 1, y, dk(glass, 0.3)); // üst gölge (pencere içe gömük)
  if (sill) { c.hline(x - 2, x + w + 1, y + h + 1, lt(frame, 0.25)); c.hline(x - 1, x + w, y + h + 2, dk(frame, 0.55)); }
  if (pediment) {
    for (let k = 0; k < 3; k++) c.hline(x - 2 + k, x + w + 1 - k, y - 2 - k, k === 0 ? dk(pediment, 0.35) : pediment);
    c.hline(x - 2, x + w + 1, y - 2, lt(pediment, 0.2));
  }
  if (shutter) for (const sx of [x - 4, x + w + 1]) {
    c.rect(sx, y - 1, 3, h + 2, shutter);
    for (let j = y; j < y + h; j += 2) c.hline(sx, sx + 2, j, dk(shutter, 0.35));
    c.vline(sx, y - 1, y + h, lt(shutter, 0.2));
  }
}
/** Ferforje balkon: döşeme, gölgesi, korkuluk (dikmeler + süs). y = döşeme üstü. */
function balcony(c, x0, x1, y, { slab = '#d8ccb8', iron = '#1d1f2a', pots = null } = {}) {
  c.hline(x0, x1, y, lt(slab, 0.25)); c.hline(x0, x1, y + 1, slab); c.hline(x0 + 1, x1 - 1, y + 2, dk(slab, 0.55));
  c.hline(x0, x1, y - 6, iron); c.hline(x0, x1, y - 1, iron);
  for (let x = x0; x <= x1; x += 2) c.vline(x, y - 5, y - 2, iron);
  for (let x = x0 + 3; x <= x1 - 2; x += 6) { c.set(x, y - 4, iron); c.set(x - 1, y - 3, iron); c.set(x + 1, y - 3, iron); }
  if (pots) for (let x = x0 + 4; x <= x1 - 4; x += 9) { c.rect(x, y - 9, 3, 3, pots); c.set(x + 1, y - 10, '#4f8a4a'); c.set(x, y - 11, '#3e7a3c'); c.set(x + 2, y - 11, '#6aa85a'); c.set(x + 1, y - 12, '#e8574a'); }
}
/** Cumba (çıkma): ışıklı ön yüz, gölgeli yan şerit, üstte saçak, altta konsollar ve gölge. */
function cumba(c, x, y, w, h, { face, trim, glass, lightLeft = true, wins = 3, winH = 10, cladding = null }) {
  if (cladding) cladding(c, x, y, w, h); else c.rect(x, y, w, h, face);
  const sideX = lightLeft ? x + w - 3 : x;
  c.rect(sideX, y, 3, h, dk(face, 0.3));
  c.vline(lightLeft ? x : x + w - 1, y, y + h - 1, lt(face, 0.35));
  c.hline(x - 1, x + w, y - 1, trim); c.hline(x - 2, x + w + 1, y - 2, lt(trim, 0.2)); c.hline(x - 1, x + w, y, dk(trim, 0.4));
  c.hline(x, x + w - 1, y + h, trim); c.hline(x + 1, x + w - 2, y + h + 1, dk(face, 0.55));
  for (const k of [x + 1, x + Math.floor(w / 2) - 1, x + w - 4]) { c.rect(k, y + h + 1, 3, 1, dk(trim, 0.3)); c.set(k + 1, y + h + 2, dk(trim, 0.45)); }
  const gap = Math.floor((w - 4) / wins);
  for (let n = 0; n < wins; n++) win(c, x + 3 + n * gap, y + 4, gap - 4, winH, { frame: trim, glass, sill: false });
}
/** Kiremit çatı: üst kenar düz ve tam gövde genişliğinde (hitbox sınırı), aşağı saçağa doğru genişler. */
function tileRoof(c, top, bot, base, { x0 = 0, x1 = cw - 1, fx0 = BX0, fx1 = BX1, hi = LIGHT, lightLeft = true } = {}) {
  for (let y = top; y < bot; y++) {
    const t = (y - top) / Math.max(1, bot - top - 1);
    const l = Math.round(fx0 + (x0 - fx0) * t), r = Math.round(fx1 + (x1 - fx1) * t);
    const course = Math.floor((y - top) / 3), k = (y - top) % 3;
    for (let x = l; x <= r; x++) {
      const tile = Math.floor((x + (course % 2) * 2) / 4), tx = (x + (course % 2) * 2) % 4;
      let col = k === 2 ? dk(base, 0.38) : base;
      if (k === 0 && tx !== 0) col = lt(base, 0.14);
      if (tx === 0 && k !== 0) col = dk(base, 0.24);
      if (h2(tile, course, 5) < 0.12 && k === 1) col = mix(base, '#7a6a4a', 0.25); // eski kiremit
      const sun = lightLeft ? x < (l + r) / 2 : x > (l + r) / 2;
      if (sun && k === 1) col = mix(col, hi, 0.12);
      c.set(x, y, col);
    }
  }
}
/** Tuğla baca, taş başlık, toprak külah. */
function chimney(c, x, y, w, h, base = '#a5513a') {
  bricks(c, x, y + 2, w, h - 2, base);
  c.rect(x - 1, y, w + 2, 2, '#cbbfb0'); c.hline(x - 1, x + w, y + 1, '#8a7e74');
  c.vline(x, y + 2, y + h - 1, lt(base, 0.2)); c.vline(x + w - 1, y + 2, y + h - 1, dk(base, 0.35));
}
/** Gövde kenarları: koyu kontur (göğe karşı okunurluk) + ışık / gölge şeridi. */
function edges(c, x, y, w, h, { light, shade, lightLeft = true, outline = '#2a2236' }) {
  c.vline(x, y, y + h - 1, outline); c.vline(x + w - 1, y, y + h - 1, outline);
  c.vline(lightLeft ? x + 1 : x + w - 2, y, y + h - 1, light);
  c.vline(lightLeft ? x + w - 2 : x + 1, y, y + h - 1, shade); c.vline(lightLeft ? x + w - 3 : x + 2, y, y + h - 1, mix(shade, '#000000', 0) );
}
/** Kat bandı (silme): iki satır, ışık + gölge. */
function floorBand(c, x, w, y, base) { c.hline(x, x + w - 1, y, lt(base, 0.3)); c.hline(x, x + w - 1, y + 1, base); c.hline(x, x + w - 1, y + 2, dk(base, 0.45)); }
/** Su kenarı: ıslak taş, yosun, dalga yansıması. */
function waterline(c, y, h, stone, water) {
  for (let j = y; j < y + h; j++) for (let i = 0; i < cw; i++) {
    const t = (j - y) / h;
    let col = t < 0.35 ? mix(stone, '#3e5a44', 0.45) : water;
    if (t < 0.35 && bayer(i, j) < 0.3) col = mix(stone, '#5a7a50', 0.5);
    if (t >= 0.35 && (i + j * 3) % 11 === 0) col = lt(water, 0.35);
    if (t >= 0.35 && bayer(i, j) < t * 0.5) col = dk(water, 0.25);
    c.set(i, j, col);
  }
}

// ---------------- Haliç ----------------
// Fener–Balat kıyısının renkli sıra evleri: ahşap bağdadi ve sıvalı cepheler, cumbalar, panjurlu pencereler,
// kiremit çatılar, tuğla bacalar. Şafak ışığı soldan. Renkler göğün pastel tonlarından ayrışacak kadar doygun.
const HALIC = {
  trim: '#f2e6d2', glass: '#2a3450', shutter: '#3f6c56', roof: '#c2583e', outline: '#2e2433',
};
function halicHouse(c, { wall, clad = 'board', withCumba = true, seed = 0, shutter = HALIC.shutter }) {
  if (clad === 'board') clapboard(c, 0, 0, bw, th, wall, seed); else plaster(c, 0, 0, bw, th, wall, seed);
  for (let fy = 0; fy < th; fy += 24) {
    floorBand(c, 0, bw, fy, clad === 'board' ? dk(wall, 0.25) : HALIC.trim);
    if (withCumba) {
      const cladFn = clad === 'board' ? (cc, x, y, w, h) => clapboard(cc, x, y, w, h, lt(wall, 0.1), seed + 3) : null;
      cumba(c, 31, fy + 5, 36, 15, { face: lt(wall, 0.12), trim: HALIC.trim, glass: HALIC.glass, cladding: cladFn, wins: 3, winH: 8 });
      win(c, 10, fy + 7, 7, 11, { frame: HALIC.trim, glass: HALIC.glass, shutter });
      win(c, 81, fy + 7, 7, 11, { frame: HALIC.trim, glass: HALIC.glass, shutter });
    } else {
      for (const x of [12, 45, 78]) win(c, x, fy + 7, 8, 11, { frame: HALIC.trim, glass: HALIC.glass, shutter, curtain: (fy / 24) % 2 ? '#e8d8b8' : null });
    }
  }
  edges(c, 0, 0, bw, th, { light: lt(wall, 0.35), shade: dk(wall, 0.4), outline: HALIC.outline });
}
const halic = {
  boundary: 28, // dünya birimi (14 px): üstünde yalnızca bacalar (çarpışmasız süs)
  bottomBodyA(c) { halicHouse(c, { wall: '#d49a3e', seed: 1 }); },
  bottomBodyB(c) { halicHouse(c, { wall: '#3f8f8a', clad: 'plaster', seed: 2, shutter: '#7a3a2e' }); },
  topBodyA(c) { halicHouse(c, { wall: '#a8473c', withCumba: false, seed: 3 }); },
  topBodyB(c) { halicHouse(c, { wall: '#7480b4', clad: 'plaster', seed: 4, shutter: '#4a3a6a' }); },
  bottomCap(c) { // sınır y=14: bacalar → kiremit çatı + çatı penceresi → ahşap saçak ve konsollar
    chimney(c, 20, 3, 7, 12); chimney(c, 86, 1, 6, 14, '#9a4a36');
    tileRoof(c, 14, 40, HALIC.roof, { hi: '#ffd2a8' });
    // çatı penceresi (beşik çatılı)
    c.poly([[47, 26], [56, 18], [65, 26]], dk(HALIC.roof, 0.2)); c.hline(48, 64, 26, dk(HALIC.roof, 0.5));
    c.rect(50, 26, 12, 12, HALIC.trim); win(c, 52, 28, 8, 8, { frame: HALIC.trim, glass: HALIC.glass, sill: false });
    for (let x = 51; x < 62; x++) c.set(x, 26 + ((x - 47) > 9 ? 0 : 0), dk(HALIC.roof, 0.45));
    // saçak: tahta alın, dişler, konsollar
    c.rect(0, 40, cw, 4, '#6e4a36'); c.hline(0, cw - 1, 40, '#9a6e50'); c.hline(0, cw - 1, 43, '#3e2a22');
    for (let x = 2; x < cw; x += 4) c.rect(x, 44, 2, 2, '#8a5e44');
    c.rect(BX0, 44, bw, 20, '#5a3e34'); c.hline(BX0, BX1, 46, '#3e2a24');
    for (let x = BX0 + 3; x < BX1; x += 10) { c.rect(x, 46, 3, 6, '#8a5e44'); c.rect(x, 52, 2, 2, '#6e4a36'); c.vline(x, 46, 51, '#a8785a'); }
    c.rect(BX0, 56, bw, 8, '#d8c8b0'); c.hline(BX0, BX1, 56, '#f2e6d2'); c.hline(BX0, BX1, 63, '#8a7a68');
    c.vline(BX0, 44, 63, HALIC.outline); c.vline(BX1, 44, 63, HALIC.outline);
  },
  topCap(c) { // alt kenar = sınır: zemin kat bakkal dükkânı (tabela, vitrin, kepenk), taş subasman, saçak
    plaster(c, BX0, 0, bw, 64, '#d9c4a4', 9);
    floorBand(c, BX0, bw, 0, '#b8a080');
    c.rect(BX0 + 2, 5, bw - 4, 8, '#2f5f8a'); c.hline(BX0 + 2, BX1 - 2, 5, '#5a8ab4'); c.hline(BX0 + 2, BX1 - 2, 12, '#1e3e5e');
    for (let x = BX0 + 10; x < BX1 - 10; x += 3) if (x % 9 !== 0) { c.set(x, 8, '#f2f2ea'); c.set(x, 9, '#f2f2ea'); } // tabela yazısı (okunmaz)
    // tente (çizgili)
    for (let x = 0; x < cw; x++) for (let y = 14; y < 22; y++) c.set(x, y, Math.floor(x / 6) % 2 ? '#f2e6d2' : '#c8473a');
    for (let x = 0; x < cw; x++) c.set(x, 22, Math.floor(x / 6) % 2 ? dk('#f2e6d2', 0.3) : dk('#c8473a', 0.3));
    c.hline(0, cw - 1, 14, '#ffffff');
    // vitrin (manav kasaları) + kapı + yarı inik kepenk
    c.rect(BX0 + 3, 23, 44, 27, '#3a3240'); c.rect(BX0 + 5, 25, 40, 21, '#5e7088'); c.set(BX0 + 6, 26, '#b0cce8');
    for (let x = BX0 + 6; x < BX0 + 44; x += 7) { c.rect(x, 41, 6, 5, '#a8784a'); c.rect(x + 1, 39, 4, 2, x % 2 ? '#e8742c' : '#d8423a'); }
    c.rect(BX0 + 50, 23, 14, 27, '#4a3428'); c.rect(BX0 + 52, 25, 10, 25, '#6a4a36'); c.set(BX0 + 60, 37, '#e8c870');
    c.rect(BX0 + 67, 23, 28, 27, '#8a8c96'); for (let y = 24; y < 50; y += 2) c.hline(BX0 + 67, BX0 + 94, y, '#6e707a');
    c.rect(BX0 + 67, 44, 28, 6, '#3a3240');
    // taş subasman ve en altta saçak
    stones(c, BX0, 50, bw, 10, '#9a8e84', 11, { bh: 5, bl: 10 });
    c.rect(0, 60, cw, 4, '#7a6a5e'); c.hline(0, cw - 1, 60, '#b0a294'); c.hline(0, cw - 1, 63, '#3e3430');
    c.vline(BX0, 0, 59, HALIC.outline); c.vline(BX1, 0, 59, HALIC.outline);
  },
  bottomBase(c) { // zemin kat dükkânları, taş rıhtım, su
    plaster(c, 0, 0, cw, 70, '#d9c4a4', 12);
    c.rect(2, 4, cw - 4, 8, '#8a3a2e'); for (let x = 12; x < cw - 12; x += 3) if (x % 8) { c.set(x, 7, '#fff0d8'); c.set(x, 8, '#fff0d8'); }
    c.hline(2, cw - 3, 4, '#b85a48');
    for (const [x, w] of [[6, 44], [62, 44]]) { c.rect(x, 16, w, 44, '#3a3240'); c.rect(x + 2, 18, w - 4, 38, '#5e7088'); c.set(x + 3, 19, '#b0cce8'); c.rect(x + 2, 46, w - 4, 10, '#a8784a'); for (let k = x + 4; k < x + w - 4; k += 6) c.rect(k, 43, 4, 3, k % 4 ? '#e8742c' : '#7aa84a'); }
    stones(c, 0, 60, cw, 10, '#a89a8c', 13, { bh: 5, bl: 10 });
    stones(c, 0, 70, cw, 60, '#8c857f', 14, { bh: 10, bl: 20 });
    c.hline(0, cw - 1, 70, '#c0b6aa');
    waterline(c, 130, 30, '#6e6a66', '#3a5a6a');
  },
};

// ---------------- Galata ----------------
// Beyoğlu taş apartmanları: kesme taş cepheler, alınlıklı ve kemerli pencereler, ferforje balkonlar, cumba,
// silmeler; çatıda kiremit, tuğla bacalar ve çatı penceresi. Gündüz ışığı sol üstten.
const GAL = { frame: '#f6ecda', glass: '#1e2a3c', iron: '#1b1f2a', outline: '#2a2832' };
const galata = {
  boundary: 32, // 16 px: üstünde iki baca
  bottomBodyA(c) { // krem taş apartman: alınlıklı pencereler, Fransız balkonu, orta plaster
    stones(c, 0, 0, bw, th, '#e4d4ba', 21, { bh: 6, bl: 14, vary: 0.05 });
    for (let fy = 0; fy < th; fy += 24) {
      floorBand(c, 0, bw, fy, '#cbb796');
      c.rect(46, fy + 3, 6, 21, '#efe2cc'); c.vline(51, fy + 3, fy + 23, '#c4b090');
      for (const x of [14, 70]) { win(c, x, fy + 8, 13, 11, { frame: GAL.frame, glass: GAL.glass, pediment: '#d8c6a6', sill: false }); balcony(c, x - 3, x + 15, fy + 20, { slab: '#d8c8ae', iron: GAL.iron }); }
    }
    edges(c, 0, 0, bw, th, { light: '#fffaf0', shade: '#a8977a', outline: GAL.outline });
  },
  bottomBodyB(c) { // gül rengi apartman: her katta ortada cumba, yanlarda kemerli pencereler (docs/09 §2)
    stones(c, 0, 0, bw, th, '#d6a08e', 22, { bh: 6, bl: 14, vary: 0.05 });
    for (let fy = 0; fy < th; fy += 24) {
      floorBand(c, 0, bw, fy, '#b8826e');
      for (const x of [7, 84]) win(c, x, fy + 10, 7, 10, { frame: GAL.frame, glass: GAL.glass, arch: true, keystone: '#f6ecda' });
      cumba(c, 26, fy + 5, 46, 15, { face: '#ecc4b2', trim: '#fff0e4', glass: GAL.glass, wins: 4, winH: 9 });
    }
    edges(c, 0, 0, bw, th, { light: '#fff0e6', shade: '#8a5a4a', outline: GAL.outline });
  },
  topBodyA(c) { // gri-mavi taş: boydan boya balkon, üç pencere
    stones(c, 0, 0, bw, th, '#a8c0cc', 23, { bh: 6, bl: 14, vary: 0.05 });
    for (let fy = 0; fy < th; fy += 24) {
      floorBand(c, 0, bw, fy, '#7e98a6');
      for (const x of [10, 44, 78]) win(c, x, fy + 6, 10, 13, { frame: GAL.frame, glass: GAL.glass, sill: false, curtain: x === 44 ? '#f0e0c8' : null });
      balcony(c, 3, bw - 4, fy + 21, { slab: '#c8d6dc', iron: GAL.iron, pots: (fy / 24) % 2 ? null : '#b5523b' });
    }
    edges(c, 0, 0, bw, th, { light: '#e8f4f8', shade: '#5e7684', outline: GAL.outline });
  },
  topBodyB(c) { // hardal taş: kemerli üç pencere, kilit taşı, pilastrlar
    stones(c, 0, 0, bw, th, '#dcb06a', 24, { bh: 6, bl: 14, vary: 0.05 });
    for (let fy = 0; fy < th; fy += 24) {
      floorBand(c, 0, bw, fy, '#a87a3c');
      for (const x of [30, 64]) { c.rect(x, fy + 3, 4, 21, '#ecc888'); c.vline(x + 3, fy + 3, fy + 23, '#b8883e'); }
      for (const x of [11, 43, 76]) win(c, x, fy + 11, 10, 9, { frame: GAL.frame, glass: GAL.glass, arch: true, keystone: '#fff4dc' });
    }
    edges(c, 0, 0, bw, th, { light: '#fff4dc', shade: '#8a6630', outline: GAL.outline });
  },
  bottomCap(c) { // sınır y=16: bacalar → kiremit çatı, çatı penceresi → dişli korniş, friz
    chimney(c, 18, 2, 8, 15); chimney(c, 84, 4, 8, 13);
    for (const x of [20, 22, 86, 88]) c.rect(x, 0, 2, 2, '#b8683e'); // toprak külahlar
    tileRoof(c, 16, 38, '#c0563a', { hi: '#ffd8b0' });
    c.poly([[45, 30], [56, 21], [67, 30]], '#8a3c28'); c.rect(48, 30, 16, 8, '#e4d4ba'); win(c, 52, 31, 8, 6, { frame: GAL.frame, glass: GAL.glass, sill: false });
    c.rect(0, 38, cw, 3, '#f2e6d0'); c.hline(0, cw - 1, 38, '#ffffff');
    c.rect(0, 41, cw, 2, '#8a7a62'); for (let x = 1; x < cw; x += 3) c.rect(x, 41, 2, 2, '#d8c6a6'); c.hline(0, cw - 1, 43, '#a8977a'); // dişler (arası gölge, boşluk değil)
    c.rect(2, 44, cw - 4, 3, '#e4d4ba'); c.hline(2, cw - 3, 46, '#b9a888');
    stones(c, BX0, 47, bw, 17, '#e4d4ba', 25, { bh: 6, bl: 14, vary: 0.05 });
    for (let x = BX0 + 6; x < BX1 - 4; x += 12) { c.rect(x, 50, 4, 8, '#f2e6d0'); c.hline(x, x + 3, 58, '#b9a888'); } // friz kartuşları
    c.vline(BX0, 44, 63, GAL.outline); c.vline(BX1, 44, 63, GAL.outline);
  },
  topCap(c) { // alt kenar = sınır: cephe → çiçekli balkon → çizgili tente → vitrin → taş subasman
    stones(c, BX0, 0, bw, 20, '#a8c0cc', 26, { bh: 6, bl: 14, vary: 0.05 });
    for (const x of [BX0 + 14, BX0 + 74]) win(c, x, 4, 10, 12, { frame: GAL.frame, glass: GAL.glass, sill: false });
    c.rect(BX0, 14, bw, 6, '#a8c0cc');
    balcony(c, 0, cw - 1, 21, { slab: '#c8d6dc', iron: GAL.iron, pots: '#b5523b' });
    c.rect(BX0, 24, bw, 34, '#3a3c48');
    for (let x = 0; x < cw; x++) for (let y = 24; y < 33; y++) c.set(x, y, Math.floor(x / 7) % 2 ? '#f6ecda' : '#c8473a');
    for (let x = 0; x < cw; x++) { const k = x % 7; if (k > 0 && k < 6) c.set(x, 33, Math.floor(x / 7) % 2 ? dk('#f6ecda', 0.2) : dk('#c8473a', 0.2)); }
    c.hline(0, cw - 1, 24, '#7a2e25');
    c.rect(BX0 + 4, 36, 40, 20, '#2a3a52'); c.rect(BX0 + 6, 38, 36, 16, '#4a6a8a'); c.set(BX0 + 7, 39, '#b8d4f0');
    for (let x = BX0 + 8; x < BX0 + 40; x += 6) c.rect(x, 48, 4, 6, x % 4 ? '#e8b86a' : '#c8473a');
    c.rect(BX0 + 50, 36, 14, 22, '#5a3a2a'); c.rect(BX0 + 52, 38, 10, 20, '#7a5238'); c.set(BX0 + 60, 47, '#f2d080');
    c.rect(BX0 + 68, 36, 26, 20, '#2a3a52'); c.rect(BX0 + 70, 38, 22, 16, '#4a6a8a');
    stones(c, BX0, 58, bw, 6, '#9a948c', 27, { bh: 3, bl: 10 });
    c.vline(BX0, 0, 63, GAL.outline); c.vline(BX1, 0, 63, GAL.outline);
  },
  bottomBase(c) { // cadde katı: kemerli dükkânlar, taş zemin
    stones(c, 0, 0, cw, 100, '#dccab0', 28, { bh: 6, bl: 14, vary: 0.05 });
    for (const x of [8, 62]) { c.rect(x - 2, 14, 46, 3, '#2e8b99'); c.hline(x - 2, x + 43, 14, '#5ab0bc'); win(c, x, 30, 42, 50, { frame: '#3a3c48', glass: '#3a5068', arch: false, sill: false }); c.rect(x, 66, 42, 14, '#a8784a'); }
    c.rect(0, 100, cw, 4, '#b9a888');
    stones(c, 0, 104, cw, 30, '#8c857f', 29, { bh: 6, bl: 16 });
    waterline(c, 134, 26, '#6e6a66', '#3a6a8a');
  },
};

// ---------------- Kız Kulesi / Üsküdar ----------------
// Şehir Hatları vapur bacası (silindir gölgeli: beyaz gövde, hardal-turuncu bant, isli siyah ağız; amblem yok),
// ahşap iskele kazıkları (yuvarlak kazıklar, çapraz kuşaklar, halat sargıları). Gün batımı ışığı sağdan.
const KZ = { white: '#f4ebe2', mustard: '#d69a2a', soot: '#1f1f27', wood: '#6a4532', outline: '#2c1e1e' };
/** Silindir gölgesi: sol gölge (mor), orta düz, sağda parlak bant ve turuncu kenar ışığı. */
function cylinder(c, x0, w, y0, y1, base) {
  for (let i = 0; i < w; i++) {
    const t = i / (w - 1);
    let col;
    if (t < 0.12) col = dk(base, 0.42 - t * 1.5);
    else if (t < 0.55) col = dk(base, Math.max(0, 0.16 - (t - 0.12) * 0.4));
    else if (t < 0.7) col = base;
    else if (t < 0.8) col = lt(base, 0.35);
    else if (t < 0.95) col = mix(base, '#ffb27a', 0.18);
    else col = mix(base, '#ff9a55', 0.5);
    for (let y = y0; y < y1; y++) c.set(x0 + i, y, col);
  }
}
function funnel(c, { band = false }) {
  cylinder(c, 0, bw, 0, th, KZ.white);
  if (band) cylinder(c, 0, bw, 30, 54, KZ.mustard);
  for (let y = 0; y < th; y += 24) { // levha ekleri ve perçinler
    for (let x = 1; x < bw - 1; x++) { const p = c.get(x, y); c.set(x, y, dk([p[0], p[1], p[2]], 0.18)); }
    for (let x = 4; x < bw - 3; x += 6) { const p = c.get(x, y + 2); c.set(x, y + 2, dk([p[0], p[1], p[2]], 0.25)); }
  }
  if (band) { for (let x = 0; x < bw; x++) { c.set(x, 30, lt(c.get(x, 31).slice(0, 3), 0.3)); c.set(x, 53, dk(c.get(x, 52).slice(0, 3), 0.3)); } }
  // buhar borusu (düdük hattı)
  for (let y = 0; y < th; y++) { c.set(14, y, '#9a8e90'); c.set(15, y, '#d8ccc8'); c.set(16, y, '#7a6e74'); }
  for (let y = 10; y < th; y += 32) c.rect(12, y, 7, 2, '#5a5058');
  c.vline(0, 0, th - 1, KZ.outline); c.vline(bw - 1, 0, th - 1, KZ.outline);
}
/** Üç yuvarlak ahşap kazık, aralarında koyu çapraz kuşaklar (opak), halat sargıları. */
function piles(c, y0, y1, { ring = false, ox = 0 } = {}) {
  c.rect(ox, y0, bw, y1 - y0, '#2e1e18');
  for (let y = y0; y < y1; y++) { // çapraz kuşaklar (X)
    const k = ((y % 48) + 48) % 48;
    for (const [a, b] of [[ox + 30, ox + 34], [ox + 63, ox + 67]]) { const off = Math.round((k / 47) * (b - a)); c.set(a + off, y, '#4a3226'); c.set(b - off, y, '#4a3226'); c.set(a + off + 1, y, '#5a3e2e'); }
  }
  for (const x0 of [ox + 1, ox + 35, ox + 68]) {
    const w = 29;
    for (let i = 0; i < w; i++) {
      const t = i / (w - 1);
      const base = KZ.wood;
      const col = t < 0.15 ? dk(base, 0.45) : t < 0.6 ? dk(base, 0.15) : t < 0.8 ? lt(base, 0.18) : t < 0.93 ? mix(base, '#ff9a55', 0.25) : dk(base, 0.3);
      for (let y = y0; y < y1; y++) {
        let p = col;
        if (h2(x0 + i, y % 96, 31) < 0.08) p = dk(col, 0.2); // lif
        if (i % 7 === 3 && h2(x0 + i, Math.floor(y / 5), 32) < 0.5) p = dk(col, 0.12);
        c.set(x0 + i, y, p);
      }
    }
    for (let y = y0 + 8; y < y1; y += 48) for (let r = 0; r < 4; r++) for (let i = 0; i < w; i++) c.set(x0 + i, y + r, (i + r) % 3 === 0 ? '#8a7a5a' : r % 2 ? '#c8b48a' : '#a8946a'); // halat
    c.vline(x0, y0, y1 - 1, KZ.outline); c.vline(x0 + w - 1, y0, y1 - 1, KZ.outline);
  }
  if (ring) { // can simidi + küçük fener
    c.ellipse(49, 60, 10, 10, (nx, ny) => { const a = Math.atan2(ny, nx); return Math.floor((a + Math.PI) / (Math.PI / 4)) % 2 ? '#f6ece2' : '#e8642c'; });
    c.ellipse(49, 60, 5, 5, KZ.wood); c.ellipse(49, 60, 4.2, 4.2, dk(KZ.wood, 0.15));
    c.rect(47, 24, 5, 8, KZ.soot); c.rect(48, 25, 3, 6, '#ffd27a'); c.set(48, 25, '#fff4d0'); c.vline(49, 20, 23, KZ.soot);
  }
}
const kizkulesi = {
  boundary: 12, // 6 px: üstünde buhar düdüğü (çarpışmasız süs)
  bottomBodyA(c) { funnel(c, {}); },
  bottomBodyB(c) { funnel(c, { band: true }); },
  topBodyA(c) { piles(c, 0, th); },
  topBodyB(c) { piles(c, 0, th, { ring: true }); },
  bottomCap(c) { // sınır y=6: düdük → isli siyah ağız (dudak) → hardal bant → beyaz gövde
    c.rect(28, 0, 3, 6, '#b8aeb0'); c.set(29, 0, '#e8e0e0'); c.rect(26, 4, 7, 2, '#8a8086');
    c.rect(3, 6, cw - 6, 3, '#3a3a46'); c.hline(3, cw - 4, 6, '#6a6a7a'); c.hline(3, cw - 4, 8, '#14141a');
    for (let y = 9; y < 20; y++) for (let x = BX0; x <= BX1; x++) { const t = (x - BX0) / (bw - 1); c.set(x, y, t < 0.15 ? '#121218' : t > 0.93 ? '#5a3a34' : t > 0.7 && t < 0.8 ? '#2c2a34' : KZ.soot); if (bayer(x, y) < (20 - y) / 40) c.set(x, y, '#34303c'); } // is
    cylinder(c, BX0, bw, 20, 36, KZ.mustard); for (let x = BX0; x <= BX1; x++) { c.set(x, 20, lt(c.get(x, 21).slice(0, 3), 0.3)); c.set(x, 35, dk(c.get(x, 34).slice(0, 3), 0.3)); }
    cylinder(c, BX0, bw, 36, 64, KZ.white);
    for (let x = BX0 + 4; x < BX1 - 3; x += 6) c.set(x, 48, dk(c.get(x, 48).slice(0, 3), 0.25));
    for (let y = 36; y < 64; y++) { c.set(BX0 + 14, y, '#9a8e90'); c.set(BX0 + 15, y, '#d8ccc8'); c.set(BX0 + 16, y, '#7a6e74'); }
    c.vline(BX0, 9, 63, KZ.outline); c.vline(BX1, 9, 63, KZ.outline);
  },
  topCap(c) { // alt kenar = sınır: kazıklar → iskele başlık kirişi (cıvatalı) → döşeme kenarı
    piles(c, 0, 40, { ox: BX0 });
    c.rect(0, 40, cw, 14, '#5a3a2a'); c.hline(0, cw - 1, 40, '#a8704a'); c.hline(0, cw - 1, 41, '#8a5a3e'); c.hline(0, cw - 1, 53, '#2e1e18');
    for (let x = 0; x < cw; x++) if (h2(x, 3, 33) < 0.12) c.vline(x, 43, 51, '#4a2e22');
    for (const x of [10, 44, 78, 101]) { c.rect(x, 45, 3, 3, '#2a2a30'); c.set(x, 45, '#8a8a98'); }
    c.rect(0, 54, cw, 10, '#3e2a20'); for (let x = 0; x < cw; x += 8) c.vline(x, 54, 63, '#2e1e18'); c.hline(0, cw - 1, 54, '#6a4a36'); c.hline(0, cw - 1, 63, '#1e1410');
    c.rect(52, 43, 8, 9, KZ.soot); c.rect(53, 44, 6, 7, '#ffd27a'); c.set(54, 45, '#fff4d0');
  },
  bottomBase(c) { // vapur: beyaz üst yapı (pencere dizileri, korkuluk, can simitleri), koyu alt gövde, su
    c.rect(0, 0, cw, 70, KZ.white); c.hline(0, cw - 1, 0, '#d8cabc');
    for (let x = 0; x < cw; x++) { if (x > cw * 0.72) for (let y = 1; y < 70; y++) if (bayer(x, y) < 0.18) c.set(x, y, mix(KZ.white, '#ffb27a', 0.25)); }
    for (const wy of [8, 36]) for (let x = 4; x < cw - 6; x += 9) { c.rect(x, wy, 6, 8, '#2c3a4e'); c.rect(x, wy, 6, 2, '#ffc46b'); c.set(x + 1, wy + 3, '#5a7a9a'); }
    c.hline(0, cw - 1, 26, '#d8cabc'); for (let x = 1; x < cw; x += 3) c.vline(x, 21, 25, '#8a8f98'); c.hline(0, cw - 1, 21, '#6a6e78');
    for (const x of [18, 56, 94]) { c.ellipse(x, 58, 5, 5, (nx, ny) => Math.floor((Math.atan2(ny, nx) + Math.PI) / (Math.PI / 4)) % 2 ? '#f6ece2' : '#e8642c'); c.ellipse(x, 58, 2, 2, KZ.white); }
    c.rect(0, 70, cw, 62, '#1d2027'); c.hline(0, cw - 1, 70, '#4a4f5a'); c.hline(0, cw - 1, 72, KZ.white);
    for (let y = 80; y < 132; y += 10) c.hline(0, cw - 1, y, '#262a33');
    for (let x = 6; x < cw; x += 14) c.ellipse(x, 90, 1.5, 1.5, '#3a3f4a');
    c.rect(0, 124, cw, 4, '#9a3a30');
    waterline(c, 128, 32, '#3a3f4a', '#5a3a5a');
  },
};

// ---------------- Boğaz Köprüsü ----------------
// Kule ayağı: düz çelik kutu kesit (kafes değil) — panel ekleri, perçin dizileri, dikey takviyeler, iki kenarda
// mavi LED şerit. Başlıklarda enine portal kirişi, ana kablo eyer yuvası ve uçak ikaz ışıkları. Akşam ışığı soldan.
const KP = { steel: '#5b66a6', dark: '#2a2f5a', led: '#9ab4ff', outline: '#141830' };
function steelRows(c, x0, W, y0, y1, { hatch = false, band = false } = {}) {
  for (let y = y0; y < y1; y++) for (let i = 0; i < W; i++) {
    const t = i / (W - 1);
    let col = t < 0.08 ? lt(KP.steel, 0.28) : t < 0.5 ? KP.steel : t < 0.9 ? dk(KP.steel, 0.12) : dk(KP.steel, 0.32);
    const panel = h2(Math.floor((i * 4) / W), Math.floor((((y % 96) + 96) % 96) / 48), 61); // panellerin ton farkı
    if (panel < 0.3) col = dk(col, 0.06); else if (panel > 0.75) col = lt(col, 0.05);
    if (bayer(x0 + i, y) < 0.05) col = dk(col, 0.1);
    c.set(x0 + i, y, col);
  }
  for (let y = y0; y < y1; y++) {
    const k = ((y % 48) + 48) % 48;
    for (const f of [0.25, 0.5, 0.75]) { const x = x0 + Math.round(W * f); c.set(x, y, dk(KP.steel, 0.3)); c.set(x + 1, y, lt(KP.steel, 0.15)); }
    if (k === 0) c.hline(x0, x0 + W - 1, y, dk(KP.steel, 0.4));
    if (k === 1) c.hline(x0, x0 + W - 1, y, lt(KP.steel, 0.25));
    if (k === 3 || k === 45) for (let x = x0 + 3; x < x0 + W - 3; x += 4) c.set(x, y, dk(KP.steel, 0.35)); // perçin
    if (y % 3 === 0) { c.set(x0 + 2, y, KP.led); c.set(x0 + W - 3, y, mix(KP.led, KP.steel, 0.3)); }
    else { c.set(x0 + 2, y, mix(KP.led, KP.steel, 0.6)); c.set(x0 + W - 3, y, mix(KP.led, KP.steel, 0.75)); }
    c.set(x0, y, KP.outline); c.set(x0 + 1, y, lt(KP.steel, 0.45)); c.set(x0 + W - 1, y, KP.outline); c.set(x0 + W - 2, y, KP.dark);
  }
  if (hatch) { // bakım kapağı ve merdiven basamakları
    const hx = x0 + 34, hy = y0 + 30;
    c.rect(hx, hy, 24, 34, KP.dark); c.rect(hx + 1, hy + 1, 22, 32, '#3e4680'); c.hline(hx + 1, hx + 22, hy + 1, '#6e78b8');
    for (let y = hy + 4; y < hy + 32; y += 6) c.hline(hx + 4, hx + 19, y, '#8a93c6');
    c.rect(hx + 19, hy + 16, 2, 4, '#c8ccec');
  }
  if (band) for (const by of [y0 + 22, y0 + 70]) { // yatay LED bantları ve bant kuşağı
    c.rect(x0 + 2, by - 2, W - 4, 6, '#3c4478'); c.hline(x0 + 2, x0 + W - 3, by - 2, '#8a96d0'); c.hline(x0 + 2, x0 + W - 3, by + 3, KP.outline);
    for (let x = x0 + 4; x < x0 + W - 4; x += 2) { c.set(x, by, KP.led); c.set(x + 1, by, mix(KP.led, KP.steel, 0.5)); c.set(x, by + 1, mix(KP.led, '#3c4478', 0.6)); }
  }
}
function portalBeam(c, y0, h) {
  c.rect(0, y0, cw, h, '#3c4478'); c.hline(0, cw - 1, y0, '#8a96d0'); c.hline(0, cw - 1, y0 + 1, '#5a64a0'); c.hline(0, cw - 1, y0 + h - 1, KP.outline); c.hline(0, cw - 1, y0 + h - 2, KP.dark);
  for (let x = 4; x < cw - 2; x += 12) { c.vline(x, y0 + 3, y0 + h - 4, '#2e3460'); c.vline(x + 1, y0 + 3, y0 + h - 4, '#5560a0'); }
  for (let x = 2; x < cw; x += 3) c.set(x, y0 + Math.floor(h / 2), x % 6 ? mix(KP.led, '#3c4478', 0.4) : KP.led);
  for (let x = 3; x < cw - 2; x += 6) { c.set(x, y0 + 3, '#262c54'); c.set(x, y0 + h - 4, '#262c54'); }
}
const kopru = {
  boundary: 8, // 4 px: üstünde uçak ikaz ışıkları
  bottomBodyA(c) { steelRows(c, 0, bw, 0, th); },
  bottomBodyB(c) { steelRows(c, 0, bw, 0, th, { hatch: true }); },
  topBodyA(c) { steelRows(c, 0, bw, 0, th); },
  topBodyB(c) { steelRows(c, 0, bw, 0, th, { band: true }); },
  bottomCap(c) { // sınır y=4: ikaz ışıkları → eyer yuvası ve portal kirişi → ayak
    for (const x of [16, 94]) { c.rect(x, 0, 3, 3, '#ff4a4a'); c.set(x + 1, 0, '#ffd0d0'); c.vline(x + 1, 3, 4, '#3a3a50'); }
    c.rect(BX0 + 30, 4, 38, 6, '#4a5290'); c.hline(BX0 + 30, BX0 + 67, 4, '#9aa6e0'); // eyer yuvası (ana kablo)
    for (let x = BX0 + 31; x < BX0 + 67; x += 3) c.set(x, 7, '#c8ccec');
    c.rect(BX0, 4, 30, 6, '#3c4478'); c.rect(BX0 + 68, 4, 30, 6, '#3c4478'); c.hline(BX0, BX1, 9, KP.dark);
    portalBeam(c, 10, 16);
    steelRows(c, BX0, bw, 26, 64);
  },
  topCap(c) { // alt kenar = sınır: ayak → portal kirişi → LED ray, ortada ikaz ışığı
    steelRows(c, BX0, bw, 0, 38);
    portalBeam(c, 38, 18);
    c.rect(BX0, 56, bw, 8, '#2a3060'); c.hline(BX0, BX1, 56, '#6e78b8'); for (let x = BX0 + 2; x < BX1; x += 2) c.set(x, 59, KP.led); c.hline(BX0, BX1, 63, KP.outline);
    c.rect(54, 58, 4, 4, '#ff4a4a'); c.set(55, 58, '#ffd0d0');
    c.vline(BX0, 56, 63, KP.outline); c.vline(BX1, 56, 63, KP.outline);
  },
  bottomBase(c) { // beton temel kaidesi (kalıp izleri), su hattı, kıyı kayaları
    steelRows(c, BX0, bw, 0, 24);
    c.rect(0, 24, cw, 104, '#8a8ca4'); c.hline(0, cw - 1, 24, '#c0c2d6'); c.hline(0, cw - 1, 25, '#a4a6bc');
    c.rect(0, 120, cw, 8, '#3e4458'); // kaya tabanı (kayalar arasında boşluk kalmaz)
    for (let x = 0; x < 8; x++) c.vline(x, 26, 119, mix('#8a8ca4', '#4a4c6a', 0.4 - x * 0.04));
    for (let y = 34; y < 120; y += 12) c.hline(8, cw - 1, y, '#7a7c94');
    for (let x = 20; x < cw; x += 24) c.vline(x, 26, 119, '#7e8098');
    for (let y = 26; y < 120; y++) for (let x = 8; x < cw; x++) if (bayer(x, y) < 0.05) c.set(x, y, '#9a9cb4');
    for (let x = 0; x < cw; x += 10) c.set(x + 5, 116, '#ffd27a');
    const r = rng(77); for (let k = 0; k < 14; k++) { const x = r() * cw, y = 118 + r() * 10; c.ellipse(x, y, 5 + r() * 6, 3 + r() * 2, k % 2 ? '#4a5268' : '#5e667e'); }
    waterline(c, 126, 34, '#4a5268', '#2e3a6a');
  },
};

// ---------------- Rumeli ----------------
// Sahil taş duvarı (kesme ve moloz taş, yosun, sarmaşık, fener ışığı) ve sahil yolunun çınar ağaçları
// (gövde, katmanlı yaprak kümeleri, ışık zinciri). Hisar engel değil: arka planda kalır. Gece, fener ışığı.
const RM = { stone: '#5c4c56', joint: '#30263a', warm: '#f0a048', leaf1: '#1a3424', leaf2: '#2a5034', leaf3: '#3e6a42', bark: '#5a4232', outline: '#160f1c' };
function rumeliWall(c, { ivy = false, seed = 0 }) {
  stones(c, 0, 0, bw, th, RM.stone, 41 + seed, { bh: 8, bl: 18, joint: RM.joint, vary: 0.14, warm: RM.warm, irregular: true });
  for (let y = 0; y < th; y++) for (let x = 0; x < bw; x++) { // sağdan fener ışığı + harçta yosun
    const p = c.get(x, y).slice(0, 3);
    if (x > bw - 14 && bayer(x, y) < (x - (bw - 14)) / 22) c.set(x, y, mix(p, RM.warm, 0.3));
    if ((y % 8 === 7) && h2(x, y, 43) < 0.18) c.set(x, y, '#2e4a32');
  }
  if (ivy) {
    for (let y = 0; y < th; y++) { const x = 66 + Math.round(5 * Math.sin((y / th) * Math.PI * 6)); c.set(x, y, '#14261a'); c.set(x + 1, y, '#1e3a26'); } // periyot karoya tam bölünür
    for (let k = 0; k < 150; k++) {
      const y = Math.round(h2(k, 1, 44) * th) + 0.5, x = 52 + h2(k, 2, 44) * 42;
      const col = h2(k, 3, 44) < 0.4 ? RM.leaf1 : h2(k, 3, 44) < 0.8 ? RM.leaf2 : RM.leaf3;
      for (const dy of [-th, 0, th]) { c.ellipse(x, y + dy, 2.2, 1.6, col); c.set(Math.round(x), Math.round(y + dy) - 1, lt(col, 0.2)); } // karo kenarında dikişsiz
    }
  }
  c.vline(0, 0, th - 1, RM.outline); c.vline(1, 0, th - 1, lt(RM.stone, 0.15)); c.vline(bw - 1, 0, th - 1, RM.outline); c.vline(bw - 2, 0, th - 1, mix(RM.stone, RM.warm, 0.55));
}
function plane(c, y0, y1, { lanterns = false, ox = 0 } = {}) { // çınar: koyu yaprak zemini (opak), gövde, kümeler, ışık zinciri
  c.rect(ox, y0, bw, y1 - y0, '#132418');
  for (let y = y0; y < y1; y++) for (let x = ox + 38; x < ox + 58; x++) {
    const t = (x - ox - 38) / 19;
    let col = t < 0.2 ? dk(RM.bark, 0.4) : t < 0.7 ? RM.bark : lt(RM.bark, 0.15);
    if (h2(x, Math.floor(y / 4) % 24, 51) < 0.22) col = mix(col, '#a89a7a', 0.35); // çınar kabuğu lekeleri
    c.set(x, y, col);
  }
  for (let k = 0; k < 90; k++) {
    const x = ox + h2(k, 1, 52) * bw, y = y0 + h2(k, 2, 52) * (y1 - y0), rx = 3 + h2(k, 3, 52) * 5, ry = 2 + h2(k, 4, 52) * 3;
    // gövde karosunda kümeler alt/üst kenardan taşınca karşı kenarda devam eder (dikişsiz döşeme)
    for (const dy of y0 === 0 && y1 === th ? [-th, 0, th] : [0]) {
      c.ellipse(x, y + dy, rx, ry, (nx, ny, X, Y) => X < ox || X >= ox + bw || Y < y0 || Y >= y1 ? null : ny < -0.35 ? RM.leaf3 : ny < 0.3 ? RM.leaf2 : RM.leaf1);
    }
  }
  for (const yb of [y0 + 14, y0 + 62]) {
    if (yb >= y1) continue;
    for (let x = 1; x < bw - 1; x++) c.set(ox + x, yb + Math.round(6 * Math.sin((x / (bw - 1)) * Math.PI)), '#2a2a3a');
    for (let x0 = 5; x0 < bw - 2; x0 += 9) { const x = ox + x0, y = yb + 1 + Math.round(6 * Math.sin((x0 / (bw - 1)) * Math.PI)); c.rect(x, y, 2, 2, '#ffd27a'); c.set(x, y, '#fff4d0'); for (const [dx, dy] of [[-1, 0], [2, 0], [0, 2], [1, 2]]) c.set(x + dx, y + dy, mix(c.get(x + dx, y + dy).slice(0, 3), '#ffd27a', 0.35)); }
  }
  if (lanterns) for (const [lx, y, col] of [[12, y0 + 28, '#c8473a'], [70, y0 + 22, '#d8a02a'], [26, y0 + 74, '#d8a02a'], [78, y0 + 70, '#c8473a']]) if (y + 14 < y1) {
    const x = ox + lx;
    for (let gy = -6; gy < 18; gy++) for (let gx = -7; gx < 16; gx++) { // fener ışığı yaprağa vurur
      const d = Math.hypot(gx - 4, (gy - 6) * 1.1);
      if (d > 6 && d < 12 && bayer(x + gx, y + gy) < 0.4 * (1 - d / 12)) { const p = c.get(x + gx, y + gy); if (p && p[3]) c.set(x + gx, y + gy, mix(p.slice(0, 3), '#ffb050', 0.4)); }
    }
    c.vline(x + 4, y - 8, y - 1, '#1e1e28'); c.poly([[x - 1, y + 1], [x + 4, y - 2], [x + 10, y + 1]], '#2a2230');
    c.rect(x, y + 1, 9, 12, '#1e1e28'); c.rect(x + 1, y + 2, 7, 10, col); c.rect(x + 2, y + 3, 5, 8, '#ffb050'); c.rect(x + 3, y + 4, 2, 3, '#fff0c0'); c.hline(x, x + 8, y + 13, '#3a2a2a');
  }
  c.vline(ox, y0, y1 - 1, RM.outline); c.vline(ox + bw - 1, y0, y1 - 1, RM.outline);
}
const rumeli = {
  boundary: 12, // 6 px: üstünde fener direklerinin tepeleri
  bottomBodyA(c) { rumeliWall(c, {}); },
  bottomBodyB(c) { rumeliWall(c, { ivy: true, seed: 1 }); },
  topBodyA(c) { plane(c, 0, th); },
  topBodyB(c) { plane(c, 0, th, { lanterns: true }); },
  bottomCap(c) { // sınır y=6: fener tepeleri → kapak taşları (taşkın) → duvar, iki duvar feneri
    for (const x of [24, 86]) { c.rect(x, 0, 3, 2, '#1e1e28'); c.vline(x + 1, 2, 6, '#1e1e28'); }
    for (let x = 0; x < cw; x++) for (let y = 6; y < 13; y++) {
      const blk = Math.floor(x / 14), k = x % 14;
      let col = h2(blk, 0, 45) < 0.5 ? '#8a7a82' : '#7a6c74';
      if (y === 6) col = '#b8a8ae'; else if (y === 12) col = '#3e3240'; else if (k === 0) col = '#4a3c48';
      c.set(x, y, col);
    }
    stones(c, BX0, 13, bw, 51, RM.stone, 46, { bh: 8, bl: 18, joint: RM.joint, vary: 0.14, warm: RM.warm, irregular: true });
    for (const x of [BX0 + 14, BX0 + 74]) {
      c.vline(x, 30, 34, '#1e1e28'); c.hline(x - 3, x + 3, 34, '#1e1e28'); // duvar kolu
      c.poly([[x - 6, 18], [x, 13], [x + 7, 18]], '#2a2230'); c.rect(x - 5, 18, 11, 12, '#1e1e28'); c.rect(x - 4, 19, 9, 10, '#ffd27a'); c.rect(x - 3, 20, 3, 4, '#fff4d0'); c.vline(x, 19, 28, '#c88a3a'); c.hline(x - 5, x + 5, 30, '#2a2230');
      for (let y = 15; y < 40; y++) for (let dx = -10; dx <= 10; dx++) { const d = Math.hypot(dx, (y - 22) * 0.8); if (d > 5 && d < 12 && bayer(x + dx, y) < 0.35 * (1 - d / 12)) { const p = c.get(x + dx, y); if (p && p[3]) c.set(x + dx, y, mix(p.slice(0, 3), RM.warm, 0.35)); } }
    }
    c.vline(BX0, 13, 63, RM.outline); c.vline(BX1, 13, 63, RM.outline);
  },
  topCap(c) { // alt kenar = sınır: yapraklar → çay bahçesi çardağı kirişi, fenerler → saçak
    plane(c, 0, 30, { ox: BX0 });
    c.rect(0, 30, cw, 22, '#5a4232'); c.hline(0, cw - 1, 30, '#8a6a4e'); c.hline(0, cw - 1, 31, '#6e5240'); c.hline(0, cw - 1, 51, '#2a1e16');
    for (let x = 0; x < cw; x++) if (h2(x, 5, 47) < 0.14) c.vline(x, 33, 49, '#4a3628');
    for (const x of [14, 52, 90]) { c.vline(x + 3, 33, 36, '#1e1e28'); c.rect(x, 36, 7, 12, '#1e1e28'); c.rect(x + 1, 37, 5, 10, '#c8473a'); c.rect(x + 2, 38, 3, 8, '#ffb050'); c.set(x + 2, 38, '#fff0c0'); }
    c.rect(0, 52, cw, 12, '#3a2c22'); for (let x = 0; x < cw; x += 6) c.vline(x, 52, 63, '#2a1e16'); c.hline(0, cw - 1, 52, '#5a4434'); c.hline(0, cw - 1, 63, '#140e0a');
    for (let x = 2; x < cw; x += 7) { c.set(x, 55, '#ffd27a'); c.set(x, 56, '#a8803a'); }
  },
  bottomBase(c) { // duvar tabanı, iri moloz taşlar, kayalar, gece suyu
    stones(c, 0, 0, cw, 96, '#4a3c46', 48, { bh: 12, bl: 24, joint: '#261e2c', vary: 0.16, warm: RM.warm, irregular: true });
    for (let x = 0; x < cw; x++) c.vline(x, 96 - Math.round(4 * Math.abs(Math.sin(x * 0.45))), 128, x % 11 < 6 ? '#141418' : '#1e1e26');
    const r = rng(49); for (let k = 0; k < 12; k++) c.ellipse(r() * cw, 112 + r() * 14, 6 + r() * 6, 4 + r() * 3, k % 2 ? '#2a2630' : '#383240');
    waterline(c, 128, 32, '#2a2630', '#0e1a3a');
  },
};

const KITS = { halic, galata, kizkulesi, kopru, rumeli };

function atlas(name) {
  const k = KITS[name], c = new Canvas(px(KIT_W), px(KIT_H));
  const sizes = { bottomBodyA: [bw, th], bottomBodyB: [bw, th], topBodyA: [bw, th], topBodyB: [bw, th], bottomCap: [cw, caph], topCap: [cw, caph], bottomBase: [cw, baseh] };
  for (const [piece, [w, h]] of Object.entries(sizes)) {
    const p = new Canvas(w, h); k[piece](p);
    c.blit(p, px(SLOT[piece][0]), px(SLOT[piece][1]));
  }
  return c;
}

function writeLayout(dartFile) {
  const rect = (x, y, w, h) => `Rect.fromLTWH(${x}, ${y}, ${w}, ${h})`;
  const sizes = { bottomBodyA: [BW, TH], bottomBodyB: [BW, TH], topBodyA: [BW, TH], topBodyB: [BW, TH], bottomCap: [CW, CAPH], topCap: [CW, CAPH], bottomBase: [CW, BASEH] };
  let d = `// ÜRETİLDİ — elle düzenlemeyin. Kaynak: art/_source/pixel/obstacles.js\n// ignore_for_file: constant_identifier_names\nimport 'dart:ui';\n\n`;
  d += `/// Engel kiti yerleşimi (dünya birimi). Atlas pixel art olarak [atlasScale] çözünürlüktedir:\n/// kaynak dikdörtgen = yerleşim × atlasScale. Işık maskesi yok: [lightsOffsetY] atlasın alt kenarıdır.\n`;
  d += `abstract final class ObstacleKitLayout {\n  static const atlasScale = ${1 / S};\n  static const bodyWidth = ${BW}.0;\n  static const capWidth = ${CW}.0;\n  static const overhang = ${OV}.0;\n  static const tileHeight = ${TH}.0;\n  static const capHeight = ${CAPH}.0;\n  static const baseHeight = ${BASEH}.0;\n  static const lightsOffsetY = ${KIT_H}.0;\n`;
  for (const [piece, [w, h]] of Object.entries(sizes)) d += `  static const ${piece} = ${rect(SLOT[piece][0], SLOT[piece][1], w, h)};\n`;
  d += `\n  /// Alt başlıkta hitbox üst kenarının görsel içindeki y konumu (üstünde kalan baca vb. çarpışmasız süs).\n  static const bottomCapBoundary = <String, double>{\n`;
  for (const [name, k] of Object.entries(KITS)) d += `    '${name}': ${k.boundary}.0,\n`;
  d += `  };\n}\n`;
  fs.writeFileSync(dartFile, d, 'utf8');
}

function build(outDir) {
  const files = Object.keys(KITS).map(n => atlas(n).save(`${outDir}/obstacles/kit_${n}.png`));
  const dart = path.resolve(__dirname, '../../../lib/game/visual/obstacle_kit_layout.g.dart');
  writeLayout(dart);
  return [...files, dart];
}

if (require.main === module) { console.log(build(process.argv[2] || path.resolve(__dirname, '../../../assets/images/pixel_art')).join('\n')); }

module.exports = { build, atlas, KITS, SLOT, px, S };

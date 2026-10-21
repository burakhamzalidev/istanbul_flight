// Pixel art çizim kütüphanesi (bağımlılıksız). Gerçek piksel düzeyinde çizer: kenar yumuşatma yok,
// sınırlı paletler, Bayer dithering, 1 px kontur. PNG kodlayıcı dahil.
'use strict';
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

// ---------------- renk ----------------
function hex(h) {
  if (Array.isArray(h)) return h;
  const s = h.replace('#', '');
  return [parseInt(s.slice(0, 2), 16), parseInt(s.slice(2, 4), 16), parseInt(s.slice(4, 6), 16)];
}
const toHex = c => '#' + c.map(v => Math.max(0, Math.min(255, Math.round(v))).toString(16).padStart(2, '0')).join('');
function mix(a, b, t) { a = hex(a); b = hex(b); return [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t].map(Math.round); }
/** Pixel art ton rampası: gölgeler mavi/mora, ışıklar sarıya kayar (hue shift). */
function ramp(base, steps = 5, { dark = 0.55, light = 0.35, coolShadow = '#2a2350', warmLight = '#fff1c8' } = {}) {
  base = hex(base);
  const out = [];
  const mid = Math.floor(steps / 2);
  for (let i = 0; i < steps; i++) {
    if (i < mid) out.push(mix(base, coolShadow, dark * (mid - i) / mid));
    else if (i === mid) out.push(base);
    else out.push(mix(base, warmLight, light * (i - mid) / (steps - 1 - mid)));
  }
  return out;
}

// 4×4 Bayer matrisi (0..15)
const BAYER = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5];
const bayer = (x, y) => (BAYER[(y & 3) * 4 + (x & 3)] + 0.5) / 16;

// deterministik rastgele
function rng(seed) { let s = seed >>> 0 || 1; return () => ((s = (s * 1664525 + 1013904223) >>> 0) / 4294967296); }

// ---------------- tuval ----------------
class Canvas {
  constructor(w, h) { this.w = w; this.h = h; this.d = new Uint8ClampedArray(w * h * 4); }
  inside(x, y) { return x >= 0 && y >= 0 && x < this.w && y < this.h; }
  set(x, y, c, a = 255) {
    x |= 0; y |= 0; if (!this.inside(x, y) || c == null) return;
    c = hex(c); const i = (y * this.w + x) * 4;
    if (a >= 255) { this.d[i] = c[0]; this.d[i + 1] = c[1]; this.d[i + 2] = c[2]; this.d[i + 3] = 255; return; }
    const t = a / 255, ia = this.d[i + 3] / 255, oa = t + ia * (1 - t);
    if (oa <= 0) return;
    for (let k = 0; k < 3; k++) this.d[i + k] = (c[k] * t + this.d[i + k] * ia * (1 - t)) / oa;
    this.d[i + 3] = oa * 255;
  }
  get(x, y) { if (!this.inside(x, y)) return null; const i = (y * this.w + x) * 4; return [this.d[i], this.d[i + 1], this.d[i + 2], this.d[i + 3]]; }
  alpha(x, y) { return this.inside(x, y) ? this.d[(y * this.w + x) * 4 + 3] : 0; }
  clear(x, y) { if (this.inside(x, y)) this.d.fill(0, (y * this.w + x) * 4, (y * this.w + x) * 4 + 4); }
  rect(x, y, w, h, c, a) { for (let j = Math.max(0, y | 0); j < Math.min(this.h, (y + h) | 0); j++) for (let i = Math.max(0, x | 0); i < Math.min(this.w, (x + w) | 0); i++) this.set(i, j, c, a); }
  hline(x0, x1, y, c) { for (let x = Math.min(x0, x1); x <= Math.max(x0, x1); x++) this.set(x, y, c); }
  vline(x, y0, y1, c) { for (let y = Math.min(y0, y1); y <= Math.max(y0, y1); y++) this.set(x, y, c); }
  line(x0, y0, x1, y1, c) {
    x0 |= 0; y0 |= 0; x1 |= 0; y1 |= 0;
    const dx = Math.abs(x1 - x0), sx = x0 < x1 ? 1 : -1, dy = -Math.abs(y1 - y0), sy = y0 < y1 ? 1 : -1;
    let e = dx + dy;
    for (;;) { this.set(x0, y0, c); if (x0 === x1 && y0 === y1) break; const e2 = 2 * e; if (e2 >= dy) { e += dy; x0 += sx; } if (e2 <= dx) { e += dx; y0 += sy; } }
  }
  /** Dolu elips; [shade] verilirse (dx,dy) → renk fonksiyonu ile tonlanır. */
  ellipse(cx, cy, rx, ry, c) {
    for (let y = Math.floor(cy - ry); y <= Math.ceil(cy + ry); y++) for (let x = Math.floor(cx - rx); x <= Math.ceil(cx + rx); x++) {
      const nx = (x + 0.5 - cx) / rx, ny = (y + 0.5 - cy) / ry;
      if (nx * nx + ny * ny <= 1) this.set(x, y, typeof c === 'function' ? c(nx, ny, x, y) : c);
    }
  }
  /** Çokgen (tek-çift kuralı). pts: [[x,y],...] */
  poly(pts, c) {
    let minY = Infinity, maxY = -Infinity;
    for (const [, y] of pts) { minY = Math.min(minY, y); maxY = Math.max(maxY, y); }
    for (let y = Math.floor(minY); y <= Math.ceil(maxY); y++) {
      const yc = y + 0.5, xs = [];
      for (let i = 0; i < pts.length; i++) {
        const [x0, y0] = pts[i], [x1, y1] = pts[(i + 1) % pts.length];
        if ((y0 <= yc && y1 > yc) || (y1 <= yc && y0 > yc)) xs.push(x0 + (yc - y0) / (y1 - y0) * (x1 - x0));
      }
      xs.sort((a, b) => a - b);
      for (let k = 0; k + 1 < xs.length; k += 2) for (let x = Math.round(xs[k]); x < Math.round(xs[k + 1]); x++) this.set(x, y, typeof c === 'function' ? c(x, y) : c);
    }
  }
  /** Dikey gradyan, renk durakları arasında Bayer dithering (bantlı pixel art geçişi). stops: [[t,color]] */
  gradientV(x, y, w, h, stops) {
    stops = stops.map(([t, c]) => [t, hex(c)]);
    for (let j = 0; j < h; j++) {
      const t = h <= 1 ? 0 : j / (h - 1);
      let k = 0; while (k < stops.length - 2 && t > stops[k + 1][0]) k++;
      const [t0, c0] = stops[k], [t1, c1] = stops[k + 1];
      const f = Math.max(0, Math.min(1, (t - t0) / (t1 - t0 || 1)));
      for (let i = 0; i < w; i++) this.set(x + i, y + j, f > bayer(x + i, y + j) ? c1 : c0);
    }
  }
  /** İki renk arasında dithered doku (level 0..1). */
  dither(x, y, w, h, c1, c2, level, mask) {
    for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) {
      const X = x + i, Y = y + j; if (mask && !mask(X, Y)) continue;
      this.set(X, Y, (typeof level === 'function' ? level(X, Y) : level) > bayer(X, Y) ? c2 : c1);
    }
  }
  /** Opak piksellerin çevresine (şeffaf komşulara) 1 px kontur. */
  outline(c, { diagonal = false } = {}) {
    const marks = [];
    for (let y = 0; y < this.h; y++) for (let x = 0; x < this.w; x++) {
      if (this.alpha(x, y) > 0) continue;
      const n = [[1, 0], [-1, 0], [0, 1], [0, -1]].concat(diagonal ? [[1, 1], [1, -1], [-1, 1], [-1, -1]] : []);
      if (n.some(([dx, dy]) => this.alpha(x + dx, y + dy) > 128)) marks.push([x, y]);
    }
    for (const [x, y] of marks) this.set(x, y, c);
    return this;
  }
  blit(src, x, y, { flipX = false, alpha = 255 } = {}) {
    for (let j = 0; j < src.h; j++) for (let i = 0; i < src.w; i++) {
      const p = src.get(flipX ? src.w - 1 - i : i, j); if (!p || p[3] === 0) continue;
      this.set(x + i, y + j, [p[0], p[1], p[2]], Math.round(p[3] * alpha / 255));
    }
  }
  /** Döşenebilirlik: x ve x±w konumlarında çizen yardımcı. */
  wrap(fn) { for (const o of [-this.w, 0, this.w]) fn(o); }
  scaled(k) { const o = new Canvas(this.w * k, this.h * k); for (let y = 0; y < o.h; y++) for (let x = 0; x < o.w; x++) { const p = this.get((x / k) | 0, (y / k) | 0); if (p[3]) o.set(x, y, [p[0], p[1], p[2]], p[3]); } return o; }
  save(file) {
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, encodePNG(this.w, this.h, this.d));
    return file;
  }
}

// ---------------- PNG ----------------
const CRC_T = (() => { const t = new Uint32Array(256); for (let n = 0; n < 256; n++) { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; t[n] = c >>> 0; } return t; })();
function crc32(buf) { let c = 0xffffffff; for (const b of buf) c = CRC_T[(c ^ b) & 255] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0; }
function chunk(type, data) {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
  const td = Buffer.concat([Buffer.from(type, 'ascii'), data]);
  const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(td));
  return Buffer.concat([len, td, crc]);
}
function encodePNG(w, h, rgba) {
  const raw = Buffer.alloc((w * 4 + 1) * h);
  for (let y = 0; y < h; y++) { raw[y * (w * 4 + 1)] = 0; Buffer.from(rgba.buffer, rgba.byteOffset + y * w * 4, w * 4).copy(raw, y * (w * 4 + 1) + 1); }
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4); ihdr[8] = 8; ihdr[9] = 6; ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw, { level: 9 })), chunk('IEND', Buffer.alloc(0))]);
}

module.exports = { Canvas, hex, toHex, mix, ramp, bayer, rng };

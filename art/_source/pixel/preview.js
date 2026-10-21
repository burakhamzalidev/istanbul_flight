// Önizleme: katmanları oyundaki gibi birleştirir (270×480 px, telefon oranı) ve ×2 büyütür.
// Kullanım: node preview.js <pixel_art klasörü> <çıktı klasörü> [simge/engel/karakter de eklenir varsa]
'use strict';
const fs = require('fs');
const zlib = require('zlib');
const { Canvas } = require('./lib');
const { ZONES, HORIZON } = require('./zones');

function readPNG(file) {
  const b = fs.readFileSync(file); const w = b.readUInt32BE(16), h = b.readUInt32BE(20);
  let i = 8; const idat = [];
  while (i < b.length) { const l = b.readUInt32BE(i), t = b.toString('ascii', i + 4, i + 8); if (t === 'IDAT') idat.push(b.slice(i + 8, i + 8 + l)); i += 12 + l; }
  const raw = zlib.inflateSync(Buffer.concat(idat)); const c = new Canvas(w, h); const st = w * 4;
  for (let y = 0; y < h; y++) {
    const f = raw[y * (st + 1)];
    for (let x = 0; x < st; x++) {
      const a = x >= 4 ? c.d[y * st + x - 4] : 0, up = y ? c.d[(y - 1) * st + x] : 0, cc = (y && x >= 4) ? c.d[(y - 1) * st + x - 4] : 0;
      let v = raw[y * (st + 1) + 1 + x];
      if (f === 1) v += a; else if (f === 2) v += up; else if (f === 3) v += (a + up) >> 1; else if (f === 4) { const p = a + up - cc, pa = Math.abs(p - a), pb = Math.abs(p - up), pc = Math.abs(p - cc); v += pa <= pb && pa <= pc ? a : pb <= pc ? up : cc; }
      c.d[y * st + x] = v & 255;
    }
  }
  return c;
}

function tileX(dst, src, y, offset) { for (let x = -((offset % src.w) + src.w) % src.w; x < dst.w; x += src.w) dst.blit(src, x, y); }

function scene(dir, key, { W = 270, scroll = 0, extras = [] } = {}) {
  const z = ZONES[key], d = `${dir}/backgrounds/${key}`, S = new Canvas(W, 480);
  tileX(S, readPNG(`${d}/sky.png`), 0, 0);
  const sun = readPNG(`${d}/sun.png`); S.blit(sun, Math.round(W * z.sun.x) - 48, z.sun.y - 48);
  const cl = readPNG(`${d}/clouds.png`);
  const sub = (c, x, y, w, h) => { const o = new Canvas(w, h); for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) { const p = c.get(x + i, y + j); if (p[3]) o.set(i, j, [p[0], p[1], p[2]], p[3]); } return o; };
  S.blit(sub(cl, 0, 0, 114, 48), 10 - (scroll * 0.03 | 0), 70); S.blit(sub(cl, 114, 0, 82, 48), 160, 130); S.blit(sub(cl, 196, 0, 60, 48), 60, 190);
  const dist = readPNG(`${d}/distant.png`); tileX(S, dist, HORIZON - dist.h, scroll * 0.06 | 0);
  for (const e of extras.filter(e => e.layer === 'land')) S.blit(e.img, e.x, HORIZON - e.img.h + (e.base || 0));
  const mid = readPNG(`${d}/midground.png`); tileX(S, mid, HORIZON - mid.h, scroll * 0.14 | 0);
  const wat = readPNG(`${d}/water.png`); tileX(S, wat, HORIZON, scroll * 0.5 | 0);
  const hi = readPNG(`${d}/water_hi.png`); tileX(S, hi, HORIZON, (scroll * 0.5 | 0) + 37);
  const wf = readPNG(`${d}/waterfront.png`); tileX(S, wf, HORIZON - 12, scroll * 0.3 | 0);
  for (const e of extras.filter(e => e.layer === 'water')) S.blit(e.img, e.x, HORIZON - e.img.h + (e.base || 0));
  S.blit(readPNG(`${d}/ferry.png`), 30, HORIZON + 6);
  for (const e of extras.filter(e => e.layer === 'top')) S.blit(e.img, e.x, e.y);
  return S;
}

if (require.main === module) {
  const [dir, out] = process.argv.slice(2);
  fs.mkdirSync(out, { recursive: true });
  const keys = Object.keys(ZONES);
  const sheet = new Canvas(270 * keys.length + 4 * (keys.length - 1), 480);
  const LM = { halic: ['suleymaniye', 'land', 70, 2], galata: ['galata', 'land', 160, 0], kizkulesi: ['kiz_kulesi', 'water', 130, 12], kopru: ['bridge', 'water', -110, 36], rumeli: ['rumeli_hisari', 'land', 30, 4] };
  keys.forEach((k, i) => { const [f, layer, x, base] = LM[k]; const extras = fs.existsSync(`${dir}/landmarks/${f}.png`) ? [{ layer, img: readPNG(`${dir}/landmarks/${f}.png`), x, base }] : []; sheet.blit(scene(dir, k, { extras }), i * 274, 0); });
  sheet.scaled(2).save(`${out}/zones_backgrounds_x2.png`);
  console.log('ok');
}

module.exports = { readPNG, scene };

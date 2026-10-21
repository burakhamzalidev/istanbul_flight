// PNG alfa istatistiği + ASCII önizleme (RGBA, 8 bit, filtreleri çözer)
const fs = require('fs'), zlib = require('zlib');
function decode(f) {
  const b = fs.readFileSync(f); const w = b.readUInt32BE(16), h = b.readUInt32BE(20);
  let i = 8, idat = []; while (i < b.length) { const l = b.readUInt32BE(i), t = b.toString('ascii', i + 4, i + 8); if (t === 'IDAT') idat.push(b.slice(i + 8, i + 8 + l)); i += 12 + l; }
  const raw = zlib.inflateSync(Buffer.concat(idat)), bpp = 4, stride = w * bpp, out = Buffer.alloc(h * stride);
  for (let y = 0; y < h; y++) {
    const ft = raw[y * (stride + 1)], src = raw.slice(y * (stride + 1) + 1, (y + 1) * (stride + 1));
    for (let x = 0; x < stride; x++) {
      const a = x >= bpp ? out[y * stride + x - bpp] : 0, up = y ? out[(y - 1) * stride + x] : 0, c = (y && x >= bpp) ? out[(y - 1) * stride + x - bpp] : 0;
      let v = src[x];
      if (ft === 1) v += a; else if (ft === 2) v += up; else if (ft === 3) v += (a + up) >> 1;
      else if (ft === 4) { const p = a + up - c, pa = Math.abs(p - a), pb = Math.abs(p - up), pc = Math.abs(p - c); v += (pa <= pb && pa <= pc) ? a : pb <= pc ? up : c; }
      out[y * stride + x] = v & 255;
    }
  }
  return { w, h, px: out };
}
for (const f of process.argv.slice(2)) {
  const { w, h, px } = decode(f); let n = 0;
  for (let k = 3; k < px.length; k += 4) if (px[k] > 0) n++;
  console.log(f, `${w}x${h}`, 'opak oran', (n / (w * h)).toFixed(3));
  const cols = 48, rows = Math.round(cols * h / w / 2);
  for (let r = 0; r < rows; r++) { let line = ''; for (let c = 0; c < cols; c++) { const x = Math.floor(c * w / cols), y = Math.floor(r * h / rows); line += px[(y * w + x) * 4 + 3] > 128 ? '#' : '.'; } console.log(line); }
}

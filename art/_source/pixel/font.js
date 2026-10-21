// "Marti Pixel" — Türkçe karakterli bitmap pixel font → gerçek TrueType (.ttf). Bağımlılıksız.
// Hücre: 2 aksan satırı + 7 gövde satırı (taban çizgisi gövde altı) + 2 alt uzantı satırı.
// 1 piksel = 100 font birimi, unitsPerEm = 1000 → fontSize 20'de 1 piksel = 2 mantıksal px (keskin).
// Lisans: bu projeye ait özgün tasarım.
'use strict';
const fs = require('fs');
const path = require('path');

const U = 100;
// gövde 7 satır; [gövde, aksan(2 satır)?, altUzantı(2 satır)?]
const G = {};
function g(ch, body, accent, desc) { G[ch] = { body, accent, desc }; }
const r = s => s.split(' ');
// ---- büyük harfler ----
g('A', r('.###. #...# #...# ##### #...# #...# #...#'));
g('B', r('####. #...# #...# ####. #...# #...# ####.'));
g('C', r('.###. #...# #.... #.... #.... #...# .###.'));
g('D', r('####. #...# #...# #...# #...# #...# ####.'));
g('E', r('##### #.... #.... ####. #.... #.... #####'));
g('F', r('##### #.... #.... ####. #.... #.... #....'));
g('G', r('.###. #...# #.... #.### #...# #...# .####'));
g('H', r('#...# #...# #...# ##### #...# #...# #...#'));
g('I', r('### .#. .#. .#. .#. .#. ###'));
g('J', r('..### ...#. ...#. ...#. #..#. #..#. .##..'));
g('K', r('#...# #..#. #.#.. ##... #.#.. #..#. #...#'));
g('L', r('#.... #.... #.... #.... #.... #.... #####'));
g('M', r('#...# ##.## #.#.# #.#.# #...# #...# #...#'));
g('N', r('#...# ##..# #.#.# #..## #...# #...# #...#'));
g('O', r('.###. #...# #...# #...# #...# #...# .###.'));
g('P', r('####. #...# #...# ####. #.... #.... #....'));
g('Q', r('.###. #...# #...# #...# #.#.# #..#. .##.#'));
g('R', r('####. #...# #...# ####. #.#.. #..#. #...#'));
g('S', r('.###. #...# #.... .###. ....# #...# .###.'));
g('T', r('##### ..#.. ..#.. ..#.. ..#.. ..#.. ..#..'));
g('U', r('#...# #...# #...# #...# #...# #...# .###.'));
g('V', r('#...# #...# #...# #...# #...# .#.#. ..#..'));
g('W', r('#...# #...# #...# #.#.# #.#.# ##.## #...#'));
g('X', r('#...# #...# .#.#. ..#.. .#.#. #...# #...#'));
g('Y', r('#...# #...# .#.#. ..#.. ..#.. ..#.. ..#..'));
g('Z', r('##### ....# ...#. ..#.. .#... #.... #####'));
const CED = r('..#.. .##..'), DIA = r('..... .#.#.'), BREVE = r('#...# .###.'), DOT = r('... .#.');
g('Ç', G.C.body, null, CED); g('Ş', G.S.body, null, CED); g('Ğ', G.G.body, BREVE); g('İ', G.I.body, DOT); g('Ö', G.O.body, DIA); g('Ü', G.U.body, DIA);
// ---- küçük harfler (x-yüksekliği 5 satır) ----
g('a', r('..... ..... .###. ....# .#### #...# .####'));
g('b', r('#.... #.... ####. #...# #...# #...# ####.'));
g('c', r('..... ..... .###. #.... #.... #...# .###.'));
g('d', r('....# ....# .#### #...# #...# #...# .####'));
g('e', r('..... ..... .###. #...# ##### #.... .###.'));
g('f', r('..## .#.. ###. .#.. .#.. .#.. .#..'));
g('g', r('..... ..... .#### #...# #...# #...# .####'), null, r('....# .###.'));
g('h', r('#.... #.... ####. #...# #...# #...# #...#'));
g('i', r('.#. ... ##. .#. .#. .#. ###'));
g('ı', r('... ... ##. .#. .#. .#. ###'));
g('j', r('..# ... .## ..# ..# ..# ..#'), null, r('#.# .#.'));
g('k', r('#... #... #..# #.#. ##.. #.#. #..#'));
g('l', r('##. .#. .#. .#. .#. .#. ###'));
g('m', r('..... ..... ##.#. #.#.# #.#.# #.#.# #.#.#'));
g('n', r('..... ..... ####. #...# #...# #...# #...#'));
g('o', r('..... ..... .###. #...# #...# #...# .###.'));
g('p', r('..... ..... ####. #...# #...# #...# ####.'), null, r('#.... #....'));
g('q', r('..... ..... .#### #...# #...# #...# .####'), null, r('....# ....#'));
g('r', r('.... .... #.## ##.. #... #... #...'));
g('s', r('..... ..... .#### #.... .###. ....# ####.'));
g('t', r('.#.. .#.. ###. .#.. .#.. .#.. ..##'));
g('u', r('..... ..... #...# #...# #...# #...# .####'));
g('v', r('..... ..... #...# #...# #...# .#.#. ..#..'));
g('w', r('..... ..... #...# #...# #.#.# #.#.# .#.#.'));
g('x', r('..... ..... #...# .#.#. ..#.. .#.#. #...#'));
g('y', r('..... ..... #...# #...# #...# #...# .####'), null, r('....# .###.'));
g('z', r('..... ..... ##### ...#. ..#.. .#... #####'));
g('ç', G.c.body, null, CED); g('ş', G.s.body, null, CED);
g('ğ', ['#...#', '.###.', ...G.g.body.slice(2)], null, G.g.desc);
g('ö', ['.....', '.#.#.', ...G.o.body.slice(2)]); g('ü', ['.....', '.#.#.', ...G.u.body.slice(2)]);
// ---- rakamlar ----
g('0', r('.###. #...# #..## #.#.# ##..# #...# .###.'));
g('1', r('..#.. .##.. ..#.. ..#.. ..#.. ..#.. .###.'));
g('2', r('.###. #...# ....# ...#. ..#.. .#... #####'));
g('3', r('####. ....# ....# .###. ....# ....# ####.'));
g('4', r('...#. ..##. .#.#. #..#. ##### ...#. ...#.'));
g('5', r('##### #.... ####. ....# ....# #...# .###.'));
g('6', r('.###. #.... #.... ####. #...# #...# .###.'));
g('7', r('##### ....# ...#. ..#.. .#... .#... .#...'));
g('8', r('.###. #...# #...# .###. #...# #...# .###.'));
g('9', r('.###. #...# #...# .#### ....# ....# .###.'));
// ---- noktalama ----
g('.', r('. . . . . . #'));
g(',', r('. . . . . . #'), null, r('# .'));
g(':', r('. # . . . # .'));
g(';', r('. # . . . # .'), null, r('# .'));
g('!', r('# # # # # . #'));
g('?', r('.###. #...# ....# ...#. ..#.. ..... ..#..'));
g("'", r('# # . . . . .'));
g('"', r('#.# #.# ... ... ... ... ...'));
g('-', r('... ... ... ### ... ... ...'));
g('+', r('... ... .#. ### .#. ... ...'));
g('·', r('. . . # . . .'));
g('/', r('....# ....# ...#. ..#.. .#... #.... #....'));
g('(', r('.# #. #. #. #. #. .#'));
g(')', r('#. .# .# .# .# .# #.'));
g('%', r('##..# ##.#. ...#. ..#.. .#... .#.## #..##'));
g('×', r('..... ..... #...# .#.#. ..#.. .#.#. #...#'));
g('–', r('.... .... .... #### .... .... ....'));
g('…', r('..... ..... ..... ..... ..... ..... #.#.#'));
g('_', r('..... ..... ..... ..... ..... ..... .....'), null, r('##### .....'));

// ---------------- TrueType üretimi ----------------
function glyphRects(gl) {
  // satır indeksleri: aksan 0..1, gövde 2..8, alt uzantı 9..10. Yatay koşuları dikdörtgene birleştir.
  const rows = [];
  (gl.accent || ['', '']).forEach((s, i) => rows.push([i, s]));
  gl.body.forEach((s, i) => rows.push([2 + i, s]));
  (gl.desc || []).forEach((s, i) => rows.push([9 + i, s]));
  const rects = []; let w = 0;
  for (const [row, s] of rows) {
    w = Math.max(w, s.length);
    let x = 0;
    while (x < s.length) { if (s[x] !== '#') { x++; continue; } let e = x; while (e < s.length && s[e] === '#') e++; rects.push([x, row, e - x]); x = e; }
  }
  // dikey birleştirme: aynı x ve genişlikteki ardışık satırları birleştir
  rects.sort((a, b) => a[0] - b[0] || a[2] - b[2] || a[1] - b[1]);
  const merged = [];
  for (const [x, row, len] of rects) {
    const last = merged[merged.length - 1];
    if (last && last.x === x && last.w === len && last.r1 === row - 1) last.r1 = row;
    else merged.push({ x, w: len, r0: row, r1: row });
  }
  return { w, rects: merged };
}

function buildTTF(familyName) {
  const chars = Object.keys(G).sort((a, b) => a.codePointAt(0) - b.codePointAt(0));
  const glyphs = [{ notdef: true }, { space: true, cp: 32 }, { space: true, cp: 0xa0 }, ...chars.map(ch => ({ cp: ch.codePointAt(0), ...glyphRects(G[ch]) }))];
  // glyf
  const glyfParts = [], loca = [0], hmtx = [];
  let maxPts = 0, maxCont = 0, xMinAll = 0, yMinAll = -200, xMaxAll = 0, yMaxAll = 900;
  for (const gl of glyphs) {
    let buf = Buffer.alloc(0), adv, lsb = 0;
    if (gl.space) { adv = 3 * U; }
    else {
      const rects = gl.notdef ? [{ x: 0, w: 4, r0: 2, r1: 2 }, { x: 0, w: 4, r0: 8, r1: 8 }, { x: 0, w: 1, r0: 3, r1: 7 }, { x: 3, w: 1, r0: 3, r1: 7 }] : gl.rects;
      const w = gl.notdef ? 4 : gl.w;
      adv = (w + 1) * U;
      const contours = rects.map(({ x, w: rw, r0, r1 }) => {
        const x0 = x * U, x1 = (x + rw) * U, yTop = (9 - r0) * U, yBot = (8 - r1) * U;
        return [[x0, yBot], [x0, yTop], [x1, yTop], [x1, yBot]]; // saat yönü (dış kontur)
      });
      const pts = contours.flat();
      const xs = pts.map(p => p[0]), ys = pts.map(p => p[1]);
      const xMin = Math.min(...xs), yMin = Math.min(...ys), xMax = Math.max(...xs), yMax = Math.max(...ys);
      lsb = xMin; xMaxAll = Math.max(xMaxAll, xMax); yMinAll = Math.min(yMinAll, yMin); yMaxAll = Math.max(yMaxAll, yMax);
      maxPts = Math.max(maxPts, pts.length); maxCont = Math.max(maxCont, contours.length);
      const parts = [];
      const h = Buffer.alloc(10); h.writeInt16BE(contours.length, 0); h.writeInt16BE(xMin, 2); h.writeInt16BE(yMin, 4); h.writeInt16BE(xMax, 6); h.writeInt16BE(yMax, 8); parts.push(h);
      const ends = Buffer.alloc(2 * contours.length); contours.forEach((_, i) => ends.writeUInt16BE(i * 4 + 3, i * 2)); parts.push(ends);
      parts.push(Buffer.from([0, 0])); // instructionLength
      parts.push(Buffer.alloc(pts.length, 0x01)); // on-curve, 16-bit deltalar
      const xb = Buffer.alloc(pts.length * 2), yb = Buffer.alloc(pts.length * 2);
      let px = 0, py = 0;
      pts.forEach(([x, y], i) => { xb.writeInt16BE(x - px, i * 2); yb.writeInt16BE(y - py, i * 2); px = x; py = y; });
      parts.push(xb, yb);
      buf = Buffer.concat(parts);
      if (buf.length % 4) buf = Buffer.concat([buf, Buffer.alloc(4 - (buf.length % 4))]);
    }
    glyfParts.push(buf); loca.push(loca[loca.length - 1] + buf.length); hmtx.push([adv, lsb]);
  }
  const glyf = Buffer.concat(glyfParts);
  const locaB = Buffer.alloc(loca.length * 4); loca.forEach((v, i) => locaB.writeUInt32BE(v, i * 4));
  const hmtxB = Buffer.alloc(hmtx.length * 4); hmtx.forEach(([a, l], i) => { hmtxB.writeUInt16BE(a, i * 4); hmtxB.writeInt16BE(l, i * 4 + 2); });
  // cmap format 4: her kod noktası için ayrı segment
  const map = glyphs.map((gl, gid) => [gl.cp, gid]).filter(([cp]) => cp != null).sort((a, b) => a[0] - b[0]);
  const segs = map.map(([cp, gid]) => ({ start: cp, end: cp, delta: (gid - cp + 65536) % 65536 })).concat([{ start: 0xffff, end: 0xffff, delta: 1 }]);
  const segX2 = segs.length * 2, searchRange = 2 * Math.pow(2, Math.floor(Math.log2(segs.length)));
  const sub = Buffer.alloc(16 + segs.length * 8);
  let o = 0;
  sub.writeUInt16BE(4, o); sub.writeUInt16BE(sub.length, o + 2); sub.writeUInt16BE(0, o + 4); sub.writeUInt16BE(segX2, o + 6);
  sub.writeUInt16BE(searchRange, o + 8); sub.writeUInt16BE(Math.log2(searchRange / 2), o + 10); sub.writeUInt16BE(segX2 - searchRange, o + 12); o = 14;
  segs.forEach((s, i) => sub.writeUInt16BE(s.end, o + i * 2)); o += segX2; sub.writeUInt16BE(0, o); o += 2;
  segs.forEach((s, i) => sub.writeUInt16BE(s.start, o + i * 2)); o += segX2;
  segs.forEach((s, i) => sub.writeUInt16BE(s.delta, o + i * 2)); o += segX2;
  segs.forEach((s, i) => sub.writeUInt16BE(0, o + i * 2));
  const cmapHead = Buffer.alloc(12); cmapHead.writeUInt16BE(0, 0); cmapHead.writeUInt16BE(1, 2); cmapHead.writeUInt16BE(3, 4); cmapHead.writeUInt16BE(1, 6); cmapHead.writeUInt32BE(12, 8);
  const cmap = Buffer.concat([cmapHead, sub]);
  // head
  const head = Buffer.alloc(54);
  head.writeUInt32BE(0x00010000, 0); head.writeUInt32BE(0x00010000, 4); head.writeUInt32BE(0, 8); head.writeUInt32BE(0x5f0f3cf5, 12);
  head.writeUInt16BE(0x000b, 16); head.writeUInt16BE(1000, 18); // unitsPerEm
  head.writeInt16BE(xMinAll, 36); head.writeInt16BE(yMinAll, 38); head.writeInt16BE(xMaxAll, 40); head.writeInt16BE(yMaxAll, 42);
  head.writeUInt16BE(0, 44); head.writeUInt16BE(8, 46); head.writeInt16BE(2, 48); head.writeInt16BE(1, 50); head.writeInt16BE(0, 52);
  // hhea
  const hhea = Buffer.alloc(36);
  hhea.writeUInt32BE(0x00010000, 0); hhea.writeInt16BE(900, 4); hhea.writeInt16BE(-200, 6); hhea.writeInt16BE(100, 8);
  hhea.writeUInt16BE(Math.max(...hmtx.map(h => h[0])), 10); hhea.writeInt16BE(0, 12); hhea.writeInt16BE(0, 14); hhea.writeInt16BE(xMaxAll, 16);
  hhea.writeInt16BE(1, 18); hhea.writeInt16BE(0, 20); hhea.writeInt16BE(0, 22); hhea.writeInt16BE(0, 34 - 0 > 32 ? 32 : 32); hhea.writeUInt16BE(glyphs.length, 34);
  // maxp
  const maxp = Buffer.alloc(32); maxp.writeUInt32BE(0x00010000, 0); maxp.writeUInt16BE(glyphs.length, 4); maxp.writeUInt16BE(maxPts, 6); maxp.writeUInt16BE(maxCont, 8); maxp.writeUInt16BE(2, 14);
  // OS/2 (sürüm 4)
  const os2 = Buffer.alloc(96);
  os2.writeUInt16BE(4, 0); os2.writeInt16BE(Math.round(hmtx.reduce((s, h) => s + h[0], 0) / hmtx.length), 2); os2.writeUInt16BE(400, 4); os2.writeUInt16BE(5, 6); os2.writeUInt16BE(0, 8);
  for (const [off, v] of [[10, 650], [12, 700], [14, 0], [16, 140], [18, 650], [20, 700], [22, 0], [24, 480], [26, 50], [28, 300]]) os2.writeInt16BE(v, off);
  os2.writeInt16BE(0, 30); // sFamilyClass
  os2.writeUInt32BE(0x00000003, 42); os2.writeUInt32BE(0, 46); // ulUnicodeRange1: Basic Latin + Latin-1
  os2.writeUInt32BE(0x00000000, 50); os2.writeUInt32BE(0, 54);
  os2.write('MRTI', 58, 'ascii'); os2.writeUInt16BE(0x0040, 62); // REGULAR
  os2.writeUInt16BE(32, 64); os2.writeUInt16BE(Math.min(0xffff, map[map.length - 1][0]), 66);
  os2.writeInt16BE(900, 68); os2.writeInt16BE(-200, 70); os2.writeInt16BE(100, 72); os2.writeUInt16BE(900, 74); os2.writeUInt16BE(200, 76);
  os2.writeUInt32BE(0x00000001, 78); os2.writeUInt32BE(0, 82); os2.writeInt16BE(500, 86); os2.writeInt16BE(700, 88); os2.writeUInt16BE(0, 90); os2.writeUInt16BE(32, 92); os2.writeUInt16BE(1, 94);
  // name
  const names = [[1, familyName], [2, 'Regular'], [3, familyName + ' Regular 1.0'], [4, familyName + ' Regular'], [5, 'Version 1.0'], [6, familyName.replace(/\s/g, '') + '-Regular']];
  const strs = names.map(([, s]) => Buffer.from(s, 'utf16le').swap16());
  const nameHead = Buffer.alloc(6 + names.length * 12); nameHead.writeUInt16BE(0, 0); nameHead.writeUInt16BE(names.length, 2); nameHead.writeUInt16BE(nameHead.length, 4);
  let so = 0;
  names.forEach(([id], i) => { const b = 6 + i * 12; nameHead.writeUInt16BE(3, b); nameHead.writeUInt16BE(1, b + 2); nameHead.writeUInt16BE(0x409, b + 4); nameHead.writeUInt16BE(id, b + 6); nameHead.writeUInt16BE(strs[i].length, b + 8); nameHead.writeUInt16BE(so, b + 10); so += strs[i].length; });
  const name = Buffer.concat([nameHead, ...strs]);
  // post (sürüm 3)
  const post = Buffer.alloc(32); post.writeUInt32BE(0x00030000, 0); post.writeInt16BE(-100, 8); post.writeInt16BE(100, 10);
  // tablo dizini
  const tables = { 'OS/2': os2, cmap, glyf, head, hhea, hmtx: hmtxB, loca: locaB, maxp, name, post };
  const tags = Object.keys(tables).sort();
  const pad = b => (b.length % 4 ? Buffer.concat([b, Buffer.alloc(4 - (b.length % 4))]) : b);
  const checksum = b => { const p = pad(b); let s = 0; for (let i = 0; i < p.length; i += 4) s = (s + p.readUInt32BE(i)) >>> 0; return s; };
  const n = tags.length, es = Math.floor(Math.log2(n)), sr = Math.pow(2, es) * 16;
  const dir = Buffer.alloc(12 + n * 16); dir.writeUInt32BE(0x00010000, 0); dir.writeUInt16BE(n, 4); dir.writeUInt16BE(sr, 6); dir.writeUInt16BE(es, 8); dir.writeUInt16BE(n * 16 - sr, 10);
  let off = dir.length; const body = [];
  tags.forEach((t, i) => { const b = tables[t]; const rb = 12 + i * 16; dir.write(t.padEnd(4, ' '), rb, 'ascii'); dir.writeUInt32BE(checksum(b), rb + 4); dir.writeUInt32BE(off, rb + 8); dir.writeUInt32BE(b.length, rb + 12); body.push(pad(b)); off += pad(b).length; });
  const font = Buffer.concat([dir, ...body]);
  // checkSumAdjustment
  const headOff = dir.readUInt32BE(12 + tags.indexOf('head') * 16 + 8);
  font.writeUInt32BE((0xb1b0afba - checksum(font)) >>> 0, headOff + 8);
  return { font, count: glyphs.length, chars: chars.join('') };
}

function build() {
  const out = path.resolve(__dirname, '../../../assets/fonts/MartiPixel.ttf');
  fs.mkdirSync(path.dirname(out), { recursive: true });
  const { font, count } = buildTTF('Marti Pixel');
  fs.writeFileSync(out, font);
  return [out + ` (${count} glif)`];
}

module.exports = { build, G, glyphRects, buildTTF };

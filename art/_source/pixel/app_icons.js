// Uygulama ikonları ve açılış ekranı görselleri (Görev 8). Kaynak: oyunun kendi pixel art'ı.
// Kullanım: node app_icons.js   (proje köküne göre yolları kendisi bulur)
//
// Ana çizim 64×64 piksel: Simit'in süzülme karesi (characters/simit_sheet.png, kare 6), arkasında gün batımı
// göğü, Galata Kulesi ve Süleymaniye silueti, deniz. 1024'e 16× en yakın komşu ile büyütülür; küçük boyutlar
// alan ortalamasıyla (kutu filtresi) küçültülür → küçük ikonlarda da okunur, büyükte keskin pikseller.
'use strict';
const path = require('path');
const fs = require('fs');
const { Canvas, mix } = require('./lib');
const { readPNG } = require('./preview');

const ROOT = path.resolve(__dirname, '../../..');
const SHEET = path.join(ROOT, 'assets/images/pixel_art/characters/simit_sheet.png');

function simitFrame() {
  const sheet = readPNG(SHEET), c = new Canvas(48, 42);
  for (let y = 0; y < 42; y++) for (let x = 0; x < 48; x++) { const p = sheet.get(x, 42 + y); if (p && p[3]) c.set(x, y, [p[0], p[1], p[2]], p[3]); }
  return c;
}

/** Manzara arka planı (64×64): düz renk bantlı gün batımı göğü (küçük boyutta kumlanmasın), Galata Kulesi
 *  silueti (sağda, Simit'in yanında tam görünür), ev sırası ve deniz. */
function scenery() {
  const c = new Canvas(64, 64);
  const bands = [[0, '#24306a'], [10, '#3a3a7c'], [18, '#5a4688'], [25, '#8a5590'], [31, '#c06c8c'], [36, '#e8888a'], [41, '#f6b48a']];
  for (let i = 0; i < bands.length; i++) c.rect(0, bands[i][0], 64, (bands[i + 1] ? bands[i + 1][0] : 46) - bands[i][0], bands[i][1]);
  c.ellipse(46, 41, 5, 5, '#ffd79a'); c.ellipse(46, 41, 3, 3, '#fff0c8'); // ufuktaki güneş
  const sil = '#2e2248';
  // Galata Kulesi (sağda): gövde, kemerli galeri, külah, alem
  c.rect(52, 31, 8, 15, sil); c.rect(51, 28, 10, 3, sil); c.hline(52, 59, 30, '#5a3a64');
  for (let i = 0; i < 9; i++) { const hw = 1 + (i >> 1); c.hline(56 - hw, 55 + hw, 19 + i, sil); }
  c.vline(55, 16, 18, sil);
  // ev sırası ve sırt
  for (const [x, h] of [[30, 3], [34, 4], [38, 3], [42, 5], [46, 4], [60, 3]]) c.rect(x, 46 - h, 4, h, sil);
  // deniz: düz bantlar ve ışık yansımaları
  c.rect(0, 46, 64, 2, '#c87a84'); c.rect(0, 48, 64, 6, '#4a4c8a'); c.rect(0, 54, 64, 10, '#2a3264');
  for (const [x, y, w] of [[44, 47, 5], [42, 50, 8], [45, 53, 4], [8, 57, 6], [26, 60, 8]]) c.hline(x, x + w, y, '#f6b48a');
  return c;
}

function master() {
  const c = scenery();
  c.blit(simitFrame(), 1, 17); // Simit solda, kule sağda görünür
  return c;
}

function foreground() { // adaptif ikon ön planı: 108 px ↔ 108 dp; Simit (48×42) ortadaki 66 px'lik güvenli alanda
  const c = new Canvas(108, 108);
  c.blit(simitFrame(), 30, 33);
  return c;
}
function background() { const s = scenery(), c = new Canvas(108, 108); for (let y = 0; y < 108; y++) for (let x = 0; x < 108; x++) { const p = s.get(Math.min(63, Math.floor(x * 64 / 108)), Math.min(63, Math.floor(y * 64 / 108))); c.set(x, y, [p[0], p[1], p[2]]); } return c; }
function monochrome() { const f = foreground(), c = new Canvas(108, 108); for (let y = 0; y < 108; y++) for (let x = 0; x < 108; x++) if (f.alpha(x, y) > 128) c.set(x, y, '#ffffff'); return c; }

/** Kutu filtresiyle küçültme (alan ortalaması); büyütmede en yakın komşu. */
function resize(src, size, { opaque = false } = {}) {
  const out = new Canvas(size, size), sx = src.w / size, sy = src.h / size;
  if (sx <= 1) { for (let y = 0; y < size; y++) for (let x = 0; x < size; x++) { const p = src.get(Math.floor(x * sx), Math.floor(y * sy)); if (p[3] || opaque) out.set(x, y, [p[0], p[1], p[2]], opaque ? 255 : p[3]); } return out; }
  for (let y = 0; y < size; y++) for (let x = 0; x < size; x++) {
    let r = 0, g = 0, b = 0, a = 0, n = 0;
    for (let yy = Math.floor(y * sy); yy < Math.floor((y + 1) * sy); yy++) for (let xx = Math.floor(x * sx); xx < Math.floor((x + 1) * sx); xx++) {
      const p = src.get(xx, yy); const w = p[3] / 255; r += p[0] * w; g += p[1] * w; b += p[2] * w; a += p[3]; n++;
    }
    const al = a / n; if (al > 0) out.set(x, y, [r / (al / 255 * n), g / (al / 255 * n), b / (al / 255 * n)].map(v => Math.round(v)), opaque ? 255 : Math.round(al));
  }
  return out;
}
const big = (c, k) => c.scaled(k);

function build() {
  const files = [];
  const m1024 = big(master(), 16);
  const save = (canvas, rel) => { const f = path.join(ROOT, rel); fs.mkdirSync(path.dirname(f), { recursive: true }); canvas.save(f); files.push(rel); };

  // ---- Android: klasik ikon, adaptif ikon katmanları, açılış görseli ----
  const dens = { mdpi: 1, hdpi: 1.5, xhdpi: 2, xxhdpi: 3, xxxhdpi: 4 };
  const fg432 = big(foreground(), 4), bg432 = big(background(), 4), mono432 = big(monochrome(), 4);
  for (const [d, k] of Object.entries(dens)) {
    save(resize(m1024, Math.round(48 * k), { opaque: true }), `android/app/src/main/res/mipmap-${d}/ic_launcher.png`);
    const a = Math.round(108 * k);
    save(resize(fg432, a), `android/app/src/main/res/mipmap-${d}/ic_launcher_foreground.png`);
    save(resize(bg432, a, { opaque: true }), `android/app/src/main/res/mipmap-${d}/ic_launcher_background.png`);
    save(resize(mono432, a), `android/app/src/main/res/mipmap-${d}/ic_launcher_monochrome.png`);
    save(big(simitFrame(), Math.max(1, Math.round(2 * k))), `android/app/src/main/res/drawable-${d}/splash_simit.png`);
  }

  // ---- iOS: AppIcon (opak, alfa yok) ve açılış görseli ----
  const ios = [['20x20@1x', 20], ['20x20@2x', 40], ['20x20@3x', 60], ['29x29@1x', 29], ['29x29@2x', 58], ['29x29@3x', 87], ['40x40@1x', 40], ['40x40@2x', 80], ['40x40@3x', 120], ['60x60@2x', 120], ['60x60@3x', 180], ['76x76@1x', 76], ['76x76@2x', 152], ['83.5x83.5@2x', 167], ['1024x1024@1x', 1024]];
  for (const [name, s] of ios) save(s === 1024 ? opaqueCopy(m1024) : resize(m1024, s, { opaque: true }), `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-${name}.png`);
  for (const [k, suf] of [[2, ''], [4, '@2x'], [6, '@3x']]) save(big(simitFrame(), k), `ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage${suf}.png`);

  // ---- Mağaza: Play 512 ikon, App Store 1024 (aynı master), web favicon / PWA ----
  save(resize(m1024, 512, { opaque: true }), 'docs/store/play_icon_512.png');
  save(opaqueCopy(m1024), 'docs/store/app_store_icon_1024.png');
  save(resize(m1024, 192, { opaque: true }), 'web/icons/Icon-192.png');
  save(resize(m1024, 512, { opaque: true }), 'web/icons/Icon-512.png');
  // maskelenebilir web ikonu tam dolu olmalı: Simit güvenli alanda, arkada manzara
  const maskable = new Canvas(108, 108); maskable.blit(background(), 0, 0); maskable.blit(foreground(), 0, 0);
  save(resize(big(maskable, 4), 192, { opaque: true }), 'web/icons/Icon-maskable-192.png');
  save(resize(big(maskable, 5), 512, { opaque: true }), 'web/icons/Icon-maskable-512.png');
  save(resize(m1024, 32, { opaque: true }), 'web/favicon.png');
  // önizleme
  save(big(master(), 4), 'art/pixel_preview/app_icon_master_x4.png');
  return files;
}
function opaqueCopy(c) { const o = new Canvas(c.w, c.h); for (let y = 0; y < c.h; y++) for (let x = 0; x < c.w; x++) { const p = c.get(x, y); o.set(x, y, [p[0], p[1], p[2]]); } return o; }

if (require.main === module) console.log(build().length + ' dosya');
module.exports = { build, master };

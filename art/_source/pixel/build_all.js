// Tüm pixel art asset'lerini üretir: node build_all.js <assets/images/pixel_art>
'use strict';
const out = process.argv[2];
const t0 = Date.now();
const files = [];
for (const m of ['./backgrounds', './landmarks', './galata', './kizkulesi', './halic', './kopru', './rumeli', './characters', './obstacles', './effects', './font', './map']) {
  try { files.push(...require(m).build(out)); } catch (e) { if (e.code === 'MODULE_NOT_FOUND' && e.message.includes(m.slice(2))) continue; throw e; }
}
console.log(files.length + ' dosya, ' + (Date.now() - t0) + ' ms');

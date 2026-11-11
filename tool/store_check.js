// App Store metin sınırlarını denetler (Phase 3.0). Çalıştırma: node tool/store_check.js
// Kaynak: developer.apple.com/help/app-store-connect/reference/app-information (11 Kasım 2026'da okundu).
const m = require('../docs/store/phase3_0/metadata.json');
const limits = { name: 30, subtitle: 30, promo: 170, description: 4000, whats_new: 4000 };
let ok = true;
for (const lang of ['tr', 'en']) {
  const d = m[lang];
  for (const [k, max] of Object.entries(limits)) {
    const n = [...d[k]].length;
    const pass = n <= max && n >= (k === 'name' ? 2 : 1);
    ok = ok && pass;
    console.log(`${pass ? 'OK  ' : 'HATA'} ${lang}.${k}: ${n}/${max} karakter`);
  }
  const bytes = Buffer.byteLength(d.keywords, 'utf8');
  const words = d.keywords.split(',');
  const short = words.filter((w) => [...w.trim()].length <= 2);
  const kwPass = bytes <= 100 && short.length === 0 && !d.keywords.includes(', ');
  ok = ok && kwPass;
  console.log(`${kwPass ? 'OK  ' : 'HATA'} ${lang}.keywords: ${bytes}/100 bayt, ${words.length} kelime${short.length ? ', 2 karakterden kısa: ' + short : ''}`);
  for (const c of d.screenshot_captions) {
    const n = [...c.title].length;
    if (n > 24) { ok = false; console.log(`HATA ${lang} başlık çok uzun (${n}): ${c.title}`); }
  }
}
console.log(ok ? 'Bütün sınırlar uygun.' : 'Sınır aşımı var.');
process.exit(ok ? 0 : 1);

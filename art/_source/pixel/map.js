// İstanbul keşif haritası (Phase 2.3, docs/15): ui/istanbul_map.png (160×160).
//
// Kıyı çizgisi gerçek coğrafyadan (enlem/boylam, ±100 m) elle seçilmiş noktalarla çizilir; kuzey yukarıdadır.
// Kutu: boylam 28.925–29.085, enlem 40.990–41.110 (~13,4 × 13,3 km, 1 px ≈ 84 m). Bölge işaretleri
// arayüzde aynı izdüşümle (lib/progression/discovery.dart → MapProjection) konur; görselde işaret yok.
'use strict';
const { Canvas, rng, bayer } = require('./lib');

const W = 160, H = 160;
const LON0 = 28.925, LON1 = 29.085, LAT0 = 40.990, LAT1 = 41.110;
const px = ([lon, lat]) => [(lon - LON0) / (LON1 - LON0) * W, (LAT1 - lat) / (LAT1 - LAT0) * H];

// ---- Avrupa yakası: kuzeybatı köşe → Boğaz kıyısı (kuzeyden güneye) → Haliç kuzey kıyısı → Haliç'in başı
//      → Haliç güney kıyısı → Sarayburnu → Marmara kıyısı (batıya) → batı kenarı ----
const EUROPE = [
  [28.925, 41.110], [29.057, 41.110],
  // Boğaz, Avrupa kıyısı: Emirgan → Baltalimanı → Rumeli Hisarı → Bebek → Arnavutköy → Kuruçeşme → Ortaköy → Beşiktaş → Kabataş → Karaköy
  [29.057, 41.106], [29.060, 41.098], [29.058, 41.092], [29.056, 41.085], [29.050, 41.082], [29.043, 41.078],
  [29.044, 41.073], [29.042, 41.066], [29.036, 41.059], [29.033, 41.054], [29.026, 41.0475], [29.016, 41.044],
  [29.008, 41.0415], [29.000, 41.0385], [28.994, 41.034], [28.986, 41.027], [28.980, 41.023], [28.977, 41.0215],
  // Haliç kuzey kıyısı: Karaköy → Kasımpaşa → Hasköy → Sütlüce
  [28.972, 41.026], [28.965, 41.033], [28.958, 41.038], [28.950, 41.045], [28.946, 41.052], [28.945, 41.058],
  // Haliç'in başı (Kağıthane ve Alibey dereleri)
  [28.941, 41.061], [28.936, 41.057],
  // Haliç güney kıyısı: Eyüp → Ayvansaray → Balat → Fener → Unkapanı → Eminönü
  [28.933, 41.052], [28.936, 41.047], [28.940, 41.042], [28.945, 41.0365], [28.950, 41.032], [28.955, 41.028],
  [28.965, 41.0215], [28.973, 41.018], [28.985, 41.018], [28.995, 41.0175],
  // Sarayburnu ve Marmara kıyısı: Ahırkapı → Kumkapı → Yenikapı → Samatya → Yedikule
  [29.001, 41.016], [29.002, 41.012], [28.995, 41.006], [28.985, 41.003], [28.975, 41.002], [28.965, 41.0005],
  [28.952, 41.001], [28.940, 40.999], [28.930, 40.996], [28.925, 40.9945],
];

// ---- Asya yakası: güneydoğu köşe → Kadıköy → Haydarpaşa → Harem → Salacak → Üsküdar → Kuzguncuk → Beylerbeyi
//      → Çengelköy → Vaniköy → Kandilli → Anadolu Hisarı → Kanlıca → kuzeydoğu köşe ----
const ASIA = [
  [29.085, 40.990], [29.021, 40.990], [29.020, 40.996], [29.016, 41.000], [29.011, 41.008], [29.008, 41.015],
  [29.0085, 41.021], [29.012, 41.027], [29.020, 41.031], [29.030, 41.037], [29.038, 41.042], [29.044, 41.046],
  [29.052, 41.053], [29.057, 41.060], [29.060, 41.066], [29.061, 41.073], [29.066, 41.080], [29.0665, 41.0845],
  [29.068, 41.091], [29.070, 41.098], [29.072, 41.104], [29.072, 41.110], [29.085, 41.110],
];

// Yeşil alanlar (yaklaşık): Topkapı Sarayı / Gülhane, Yıldız Parkı, Fethi Paşa Korusu, Validebağ, Rumeli Hisarı sırtları
const GREENS = [
  { at: [28.983, 41.012], r: 3.2 }, { at: [29.013, 41.049], r: 3 }, { at: [29.035, 41.034], r: 2.2 },
  { at: [29.040, 41.016], r: 2.6 }, { at: [29.050, 41.089], r: 2.4 }, { at: [29.070, 41.067], r: 2.2 },
];

// Mahalle kümeleri (yaklaşık merkez, yarıçap px, ev sayısı)
const DISTRICTS = [
  { at: [28.960, 41.012], r: 12, n: 320 }, // Fatih / Sultanahmet
  { at: [28.940, 41.030], r: 7, n: 120 }, // Fener-Balat
  { at: [28.976, 41.034], r: 9, n: 220 }, // Beyoğlu / Galata
  { at: [29.004, 41.045], r: 7, n: 140 }, // Beşiktaş
  { at: [29.030, 41.063], r: 6, n: 90 }, // Arnavutköy-Bebek
  { at: [29.025, 41.022], r: 9, n: 200 }, // Üsküdar
  { at: [29.035, 40.997], r: 10, n: 220 }, // Kadıköy
  { at: [29.050, 41.050], r: 5, n: 70 }, // Beylerbeyi-Çengelköy
  { at: [29.072, 41.086], r: 5, n: 60 }, // Anadolu Hisarı
  { at: [28.940, 41.050], r: 5, n: 70 }, // Eyüp
  { at: [28.958, 41.044], r: 6, n: 90 }, // Hasköy-Kasımpaşa
];

const C = {
  deep: '#2b5f8c', sea: '#3a77a3', shallow: '#5b9cc2', foam: '#bfe3ee', wave: '#8cc2dc',
  land: ['#efe2c4', '#e4d3ae', '#d6c094'], coast: '#8a6a44', roof: '#c4664a', roofDark: '#9c4a36',
  wall: '#cdb48a', green: ['#9cbf6a', '#7aa458', '#5d8a46'], road: '#f8f0dc', bridge: '#d8573d', bridgeDark: '#8f2f26',
};

function build(outDir) {
  const c = new Canvas(W, H);
  const land = new Uint8Array(W * H);
  const mark = (poly) => {
    const m = new Canvas(W, H);
    m.poly(poly.map(px), '#ffffff');
    for (let i = 0; i < W * H; i++) if (m.d[i * 4 + 3]) land[i] = 1;
  };
  mark(EUROPE); mark(ASIA);
  const isLand = (x, y) => x >= 0 && y >= 0 && x < W && y < H && land[y * W + x] === 1;

  // Kıyıya uzaklık (su pikselleri, 4 komşu BFS): sığ su açık, açık deniz koyu
  const dist = new Int16Array(W * H).fill(999);
  const q = [];
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) if (isLand(x, y)) { dist[y * W + x] = 0; q.push(x, y); }
  for (let h = 0; h < q.length; h += 2) {
    const x = q[h], y = q[h + 1], d = dist[y * W + x];
    for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
      const X = x + dx, Y = y + dy;
      if (X < 0 || Y < 0 || X >= W || Y >= H || dist[Y * W + X] <= d + 1) continue;
      dist[Y * W + X] = d + 1; q.push(X, Y);
    }
  }

  // Karadan kıyıya uzaklık (iç kesim tonu ve mahalle yoğunluğu için)
  const landDist = new Int16Array(W * H).fill(999);
  const lq = [];
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) if (!isLand(x, y)) { landDist[y * W + x] = 0; lq.push(x, y); }
  for (let h = 0; h < lq.length; h += 2) {
    const x = lq[h], y = lq[h + 1], d = landDist[y * W + x];
    for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
      const X = x + dx, Y = y + dy;
      if (X < 0 || Y < 0 || X >= W || Y >= H || landDist[Y * W + X] <= d + 1) continue;
      landDist[Y * W + X] = d + 1; lq.push(X, Y);
    }
  }

  const r = rng(1453);
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    if (isLand(x, y)) {
      // kara: sıcak kâğıt tonu, hafif dithered doku
      // kara: kıyıda açık kâğıt, içeride (sırtlar) seyrek dithered koyu ton
      const inland = Math.min(1, landDist[y * W + x] / 26);
      c.set(x, y, inland * 0.55 > bayer(x, y) ? C.land[1] : C.land[0]);
      continue;
    }
    const d = dist[y * W + x];
    const t = Math.min(1, d / 9);
    let col = t < 0.25 ? C.shallow : t > 0.75 + bayer(x, y) * 0.3 ? C.deep : (t > 0.4 + bayer(x, y) * 0.35 ? C.sea : C.shallow);
    if (d === 1) col = C.foam;
    c.set(x, y, col);
  }

  // yeşil alanlar
  for (const g of GREENS) {
    const [gx, gy] = px(g.at);
    c.ellipse(gx, gy, g.r, g.r * 0.8, (nx, ny, x, y) => (isLand(x, y) ? (ny < -0.3 ? C.green[0] : nx + ny > 0.6 ? C.green[2] : C.green[1]) : null));
  }

  // şehir dokusu: tarihî mahallelerin çevresinde kiremit çatı kümeleri (2×1 ev + alt gölge), arada sokak boşlukları
  for (const d of DISTRICTS) {
    const [dx0, dy0] = px(d.at);
    for (let i = 0; i < d.n * 1.6; i++) {
      const a = r() * Math.PI * 2, rad = Math.sqrt(r()) * d.r * 1.45;
      const x = Math.round(dx0 + Math.cos(a) * rad), y = Math.round(dy0 + Math.sin(a) * rad * 0.85);
      if ((x + y * 3) % 5 === 0 || y % 4 === 0) continue; // sokak ızgarası hissi
      if (!isLand(x, y) || !isLand(x + 1, y) || !isLand(x, y + 1)) continue;
      const p = c.get(x, y);
      if (p && p[1] > 170 && p[0] < 170) continue; // parkın üstüne ev koyma
      c.set(x, y, r() < 0.75 ? C.roof : C.wall);
      c.set(x + 1, y, r() < 0.55 ? C.roof : C.wall);
      c.set(x, y + 1, C.roofDark); c.set(x + 1, y + 1, C.roofDark);
    }
  }
  // mahalleler arası seyrek yapılaşma (kıyıya yakın daha sık)
  for (let i = 0; i < 900; i++) {
    const x = Math.floor(r() * W), y = Math.floor(r() * H);
    if (!isLand(x, y) || !isLand(x + 1, y) || landDist[y * W + x] > 22 || r() > 1 - landDist[y * W + x] / 24) continue;
    const p = c.get(x, y); if (p && (p[0] < 210 || (p[1] > 170 && p[0] < 170))) continue;
    c.set(x, y, r() < 0.6 ? C.roof : C.wall); c.set(x, y + 1, C.roofDark);
  }
  // kuzeydeki koruluklar: tek piksel ağaçlar
  for (let i = 0; i < 160; i++) {
    const x = Math.floor(r() * W), y = Math.floor(r() * H * 0.55);
    if (!isLand(x, y) || landDist[y * W + x] < 6) continue;
    const p = c.get(x, y); if (p && p[0] < 210) continue;
    c.set(x, y, C.green[1]); c.set(x, y + 1, C.green[2]);
  }

  // kıyı çizgisi: suya bakan kara pikselleri
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    if (!isLand(x, y)) continue;
    if ([[1, 0], [-1, 0], [0, 1], [0, -1]].some(([dx, dy]) => { const X = x + dx, Y = y + dy; return X >= 0 && Y >= 0 && X < W && Y < H && !isLand(X, Y); })) c.set(x, y, C.coast);
  }

  // dalgacıklar: açık suda seyrek kısa çizgiler
  for (let i = 0; i < 90; i++) {
    const x = Math.floor(r() * (W - 3)), y = Math.floor(r() * H);
    if ([0, 1, 2].every(k => !isLand(x + k, y) && dist[y * W + x + k] > 3)) { c.set(x, y, C.wave); c.set(x + 1, y, C.wave); }
  }

  // Boğaziçi (15 Temmuz Şehitler) Köprüsü: Ortaköy → Beylerbeyi, iki kule
  const bridge = (a, b, towers) => {
    const [x0, y0] = px(a), [x1, y1] = px(b);
    c.line(x0, y0 + 1, x1, y1 + 1, C.bridgeDark); c.line(x0, y0, x1, y1, C.bridge);
    for (const t of towers) { const [tx, ty] = px(t); c.set(tx, ty - 1, C.bridge); c.set(tx, ty - 2, C.bridgeDark); }
  };
  bridge([29.0255, 41.0485], [29.0405, 41.0435], [[29.0285, 41.0472], [29.0375, 41.0445]]);
  // Galata Köprüsü: Karaköy → Eminönü (alçak, açık renk)
  {
    const [x0, y0] = px([28.9755, 41.0222]), [x1, y1] = px([28.9725, 41.0178]);
    c.line(x0, y0, x1, y1, C.bridgeDark);
  }
  // Kız Kulesi adacığı (Salacak açıkları): 2×2 kaya + kule pikseli
  {
    const [kx, ky] = px([29.0041, 41.0211]);
    const X = Math.round(kx), Y = Math.round(ky);
    c.rect(X - 1, Y, 3, 2, C.coast); c.rect(X - 1, Y - 2, 2, 2, '#fbf7ee'); c.set(X - 1, Y - 3, C.roof);
  }
  return [c.save(`${outDir}/ui/istanbul_map.png`)];
}

module.exports = { build, px, EUROPE, ASIA, W, H, LON0, LON1, LAT0, LAT1 };

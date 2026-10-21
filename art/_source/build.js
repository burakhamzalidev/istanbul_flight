// Martı: Istanbul Flight — konsept görsel üreticisi (SVG). Çıktı: istanbul_flight/art/...
const fs = require('fs');
const path = require('path');
const OUT = process.argv[2];
const W = 1080, H = 1920, HZ = 1190;

// ---------- yardımcılar ----------
let seed = 7;
const rnd = () => ((seed = (seed * 16807) % 2147483647) / 2147483647);
const r1 = n => Math.round(n * 10) / 10;
const FONT_D = "'Segoe UI Black','Arial Black',sans-serif";
const FONT_B = "'Segoe UI','Segoe UI Variable',Arial,sans-serif";
const FONT_S = "'Segoe UI Semibold','Segoe UI',Arial,sans-serif";

function defs(extra = '') {
  return `<defs>
  <filter id="grain" x="0" y="0" width="100%" height="100%">
    <feTurbulence type="fractalNoise" baseFrequency="0.9" numOctaves="2" seed="11"/>
    <feColorMatrix type="matrix" values="0 0 0 0 0.1  0 0 0 0 0.08  0 0 0 0 0.12  0 0 0 1.6 -0.55"/>
  </filter>
  <radialGradient id="vig" cx="50%" cy="48%" r="75%">
    <stop offset="62%" stop-color="#000" stop-opacity="0"/><stop offset="100%" stop-color="#000" stop-opacity="0.28"/>
  </radialGradient>
  ${extra}</defs>`;
}
const grain = (w = W, h = H, op = 0.55) => `<g id="FX_grain"><rect width="${w}" height="${h}" filter="url(#grain)" opacity="${op}"/></g>`;
const vignette = () => `<rect width="${W}" height="${H}" fill="url(#vig)"/>`;

function bands(cols, ys, x = 0, w = W) {
  return cols.map((c, i) => `<rect x="${x}" y="${ys[i]}" width="${w}" height="${ys[i + 1] - ys[i] + 1}" fill="${c}"/>`).join('');
}
function cloud(x, y, s, c1, c2) {
  // düz, 2 tonlu kartpostal bulutu
  return `<g transform="translate(${x} ${y}) scale(${s})">
    <rect x="-150" y="0" width="300" height="34" rx="17" fill="${c1}"/>
    <rect x="-95" y="-26" width="170" height="40" rx="20" fill="${c1}"/>
    <rect x="-40" y="-50" width="90" height="44" rx="22" fill="${c1}"/>
    <rect x="-150" y="22" width="300" height="12" rx="6" fill="${c2}"/>
  </g>`;
}
function farGulls(list, c) {
  return list.map(([x, y, s]) => `<path d="M${x - 14 * s},${y} Q${x - 7 * s},${y - 8 * s} ${x},${y} Q${x + 7 * s},${y - 8 * s} ${x + 14 * s},${y}" fill="none" stroke="${c}" stroke-width="${3 * s}" stroke-linecap="round"/>`).join('');
}

// ---------- SİMİT (tek kaynak karakter) ----------
const CP = { ink: '#2B2B3A', body: '#F7F3EA', shade: '#E2D9C8', wing: '#9AACBF', wingDark: '#6E8299', tip: '#2B2B3A',
  beak: '#F2C23B', beakShade: '#D9A21E', spot: '#D9643A', iris: '#F5DC6A', ring: '#D9643A',
  simit: '#C8803A', simitDark: '#93582A', simitHi: '#E2A35C', sesame: '#FBF2D0', leg: '#F2B33B' };
const SIL = Object.fromEntries(Object.keys(CP).map(k => [k, '#2B2B3A']));

const BODY = 'M-58,8 C-60,-30 -30,-56 8,-56 C44,-56 62,-30 60,0 C58,34 30,54 -4,54 C-38,54 -56,36 -58,8 Z';
const WING = 'M8,-6 C-2,-28 -40,-32 -66,-20 L-90,-16 L-72,-2 C-50,12 -12,14 8,-6 Z';
const WTIP = 'M-66,-20 L-90,-16 L-72,-2 C-68,-8 -66,-14 -66,-20 Z';

function ringBack(P, x, y, rot, rx = 27, ry = 11) {
  return `<g transform="translate(${x} ${y}) rotate(${rot})">
    <ellipse rx="${rx}" ry="${ry}" fill="none" stroke="${P.ink}" stroke-width="16"/>
    <ellipse rx="${rx}" ry="${ry}" fill="none" stroke="${P.simitDark}" stroke-width="10"/></g>`;
}
function ringFront(P, x, y, rot, rx = 27, ry = 11) {
  const a = `M${-rx},0 A${rx} ${ry} 0 0 0 ${rx},0`;
  let ses = '';
  if (P !== SIL) for (const t of [25, 60, 95, 130, 160]) {
    const rad = t * Math.PI / 180, ex = r1(rx * Math.cos(rad)), ey = r1(ry * Math.sin(rad));
    ses += `<ellipse cx="${ex}" cy="${ey}" rx="2" ry="1.2" fill="${P.sesame}" transform="rotate(${(t * 7) % 90 - 45} ${ex} ${ey})"/>`;
  }
  return `<g transform="translate(${x} ${y}) rotate(${rot})">
    <path d="${a}" fill="none" stroke="${P.ink}" stroke-width="16" stroke-linecap="round"/>
    <path d="${a}" fill="none" stroke="${P.simit}" stroke-width="10" stroke-linecap="round"/>
    <path d="M${-rx + 6},${ry * 0.45} A${rx} ${ry} 0 0 0 ${rx - 8},${ry * 0.45}" fill="none" stroke="${P.simitHi}" stroke-width="2.5" stroke-linecap="round" opacity=".9"/>
    ${ses}</g>`;
}
function ringLoose(P, x, y, rot, rx = 22, ry = 22) {
  let ses = '';
  if (P !== SIL) for (let t = 0; t < 360; t += 45) {
    const rad = t * Math.PI / 180;
    ses += `<ellipse cx="${r1(rx * Math.cos(rad))}" cy="${r1(ry * Math.sin(rad))}" rx="2" ry="1.2" fill="${P.sesame}" transform="rotate(${t} ${r1(rx * Math.cos(rad))} ${r1(ry * Math.sin(rad))})"/>`;
  }
  return `<g transform="translate(${x} ${y}) rotate(${rot})">
    <ellipse rx="${rx}" ry="${ry}" fill="none" stroke="${P.ink}" stroke-width="16"/>
    <ellipse rx="${rx}" ry="${ry}" fill="none" stroke="${P.simit}" stroke-width="10"/>${ses}</g>`;
}

function eye(P, expr) {
  // Göz kırpma: kapak tamamen kapalı, kaş varsayılan konumda
  if (expr === 'blink') return `<path d="M20,-24 Q30,-19 40,-24" fill="none" stroke="${P.ink}" stroke-width="4" stroke-linecap="round"/>
    <path d="M16,-38 L42,-33" stroke="${P.wingDark}" stroke-width="5.5" stroke-linecap="round"/>`;
  // Oyun sonu tepkisi: sersem (spiral göz), kaş yamuk
  if (expr === 'dazed') return `<circle cx="30" cy="-24" r="9.5" fill="${P.body}" stroke="${P.ink}" stroke-width="2.5"/>
    <path d="M30,-24 m-1.5,0 a1.5,1.5 0 1,1 3,0 a3.5,3.5 0 1,1 -7,0 a5.5,5.5 0 1,1 11,0" fill="none" stroke="${P.ink}" stroke-width="2"/>
    <path d="M16,-40 Q28,-34 42,-39" fill="none" stroke="${P.wingDark}" stroke-width="5" stroke-linecap="round"/>`;
  if (expr === 'happy') return `<path d="M21,-22 Q30,-35 39,-22" fill="none" stroke="${P.ink}" stroke-width="4.5" stroke-linecap="round"/>
    <path d="M17,-41 Q30,-46 43,-40" fill="none" stroke="${P.wingDark}" stroke-width="5" stroke-linecap="round"/>`;
  if (expr === 'surprised') return `<circle cx="30" cy="-25" r="12" fill="${P.iris}" stroke="${P.ring}" stroke-width="3"/>
    <circle cx="31" cy="-25" r="3" fill="${P.ink}"/><circle cx="33" cy="-28" r="1.5" fill="#fff"/>
    <path d="M17,-46 Q30,-53 43,-45" fill="none" stroke="${P.wingDark}" stroke-width="5" stroke-linecap="round"/>`;
  if (expr === 'crash') return `<path d="M23,-32 L37,-17 M37,-32 L23,-17" stroke="${P.ink}" stroke-width="4.5" stroke-linecap="round"/>`;
  if (expr === 'focus') return `<circle cx="30" cy="-24" r="9.5" fill="${P.iris}" stroke="${P.ring}" stroke-width="3"/>
    <circle cx="34" cy="-23" r="4.4" fill="${P.ink}"/><circle cx="35.6" cy="-25.5" r="1.5" fill="#fff"/>
    <path d="M19.5,-27 A10.5 10.5 0 0 1 40.5,-27 Z" fill="${P.body}"/><path d="M19,-27 L41,-27" stroke="${P.ink}" stroke-width="3" stroke-linecap="round"/>
    <path d="M16,-35 L43,-30" stroke="${P.wingDark}" stroke-width="5.5" stroke-linecap="round"/>`;
  // smug (varsayılan): ağır göz kapağı + düz kaş = kendinden emin, hafif küstah
  return `<circle cx="30" cy="-24" r="9.5" fill="${P.iris}" stroke="${P.ring}" stroke-width="3"/>
    <circle cx="33" cy="-23" r="4.2" fill="${P.ink}"/><circle cx="34.6" cy="-25.2" r="1.5" fill="#fff"/>
    <path d="M19.5,-25 A10.5 10.5 0 0 1 40.5,-25 Z" fill="${P.body}"/><path d="M19,-25 L41,-25" stroke="${P.ink}" stroke-width="3" stroke-linecap="round"/>
    <path d="M16,-38 L42,-33" stroke="${P.wingDark}" stroke-width="5.5" stroke-linecap="round"/>`;
}
function beak(P, open) {
  const lower = `<g ${open ? `transform="rotate(${open} 52 -10)"` : ''}>
    <path d="M52,-10 L89,-9 C85,-3 70,0 54,-1 Z" fill="${P.beakShade}" stroke="${P.ink}" stroke-width="3.5" stroke-linejoin="round"/>
    <circle cx="78" cy="-5.5" r="3.4" fill="${P.spot}"/></g>`;
  return `${lower}<path d="M50,-24 C64,-26 84,-22 94,-16 C97,-13 96,-9 91,-9 L52,-10 Z" fill="${P.beak}" stroke="${P.ink}" stroke-width="3.5" stroke-linejoin="round"/>`;
}

/** Simit, sağa bakan. o: {x,y,s,tilt,wing,expr,ring:[x,y,rot]|'loose'|false,legs,fly,sil,rim,open} */
function simit(o) {
  const P = o.sil ? SIL : CP;
  const wing = o.wing ?? 0, sw = 4;
  const ring = o.ring === undefined ? [22, 26, -18] : o.ring;
  let g = '';
  // bacaklar / katlanmış ayaklar
  if (o.legs) {
    g += `<path d="M-6,44 L-8,72 M14,44 L14,72" stroke="${P.ink}" stroke-width="11" stroke-linecap="round"/>
      <path d="M-6,44 L-8,72 M14,44 L14,72" stroke="${P.leg}" stroke-width="6" stroke-linecap="round"/>
      <path d="M-24,76 L-8,69 L4,76 Q-10,80 -24,76 Z M-2,76 L14,69 L28,76 Q14,80 -2,76 Z" fill="${P.leg}" stroke="${P.ink}" stroke-width="3" stroke-linejoin="round"/>`;
  } else {
    g += `<path d="M-28,40 L-60,50 L-50,54 L-38,52 Z" fill="${P.leg}" stroke="${P.ink}" stroke-width="3" stroke-linejoin="round"/>`;
  }
  // arka kanat
  if (o.fly !== false) g += `<g transform="rotate(${wing + 10} 2 -4) translate(-6 -8)"><path d="${WING}" fill="${P.wingDark}" stroke="${P.ink}" stroke-width="${sw}" stroke-linejoin="round"/></g>`;
  // kuyruk
  g += `<path d="M-46,-4 L-82,-16 L-76,2 L-84,16 L-44,20 Z" fill="${P.body}" stroke="${P.ink}" stroke-width="${sw}" stroke-linejoin="round"/>
    <path d="M-70,-12 L-82,-16 L-76,2 L-84,16 L-72,14 L-68,2 Z" fill="${P.tip}" stroke="${P.ink}" stroke-width="2" stroke-linejoin="round"/>`;
  // simidin arka yarısı (gövdenin arkasında kalır → boyuna takılı görünür)
  // gövde
  g += `<path d="${BODY}" fill="${P.body}" stroke="${P.ink}" stroke-width="${sw}"/>`;
  if (!o.sil) {
    g += `<path d="M-55,4 C-54,-26 -32,-48 -2,-53 C-22,-38 -36,-18 -40,8 Z" fill="${P.wing}"/>`; // gri sırt (pelerin)
    g += `<path d="M-50,26 C-36,46 -6,54 22,49 C-8,47 -34,40 -50,26 Z" fill="${P.shade}"/>`;
    if (o.rim) g += `<path d="M36,-46 C55,-32 60,-8 54,18" fill="none" stroke="${o.rim}" stroke-width="5" stroke-linecap="round" opacity=".9"/>`;
  }
  // ön kanat
  g += `<g transform="rotate(${wing} 2 -4)"><path d="${WING}" fill="${P.wing}" stroke="${P.ink}" stroke-width="${sw}" stroke-linejoin="round"/>`;
  if (!o.sil) g += `<path d="M-14,6 C-28,-4 -44,-10 -62,-10" fill="none" stroke="${P.wingDark}" stroke-width="3" stroke-linecap="round"/>`;
  g += `<path d="${WTIP}" fill="${P.tip}" stroke="${P.ink}" stroke-width="3" stroke-linejoin="round"/>`;
  if (!o.sil) g += `<circle cx="-79" cy="-12" r="2.8" fill="${CP.body}"/>`;
  g += `</g>`;
  // yüz
  if (!o.sil) g += eye(P, o.expr || 'smug');
  g += beak(P, o.open || (o.expr === 'surprised' ? 16 : o.expr === 'crash' ? 22 : 0));
  // simidin ön yarısı
  // simit 3/4 açıyla, deliği görünür (yandan bakışta "simit" olarak okunması için bilinçli hile)
  if (Array.isArray(ring)) g += ringLoose(P, ring[0], ring[1], ring[2], 23, 16);
  if (ring === 'loose') g += ringLoose(P, 84, 40, 30);
  if (o.expr === 'crash' && !o.sil) {
    g += [[-40, -78, 30], [52, -84, -40], [-84, -40, 70]].map(([x, y, a]) =>
      `<g transform="translate(${x} ${y}) rotate(${a})"><path d="M0,-12 C7,-6 7,6 0,12 C-7,6 -7,-6 0,-12 Z" fill="${P.body}" stroke="${P.ink}" stroke-width="2.5"/><path d="M0,-10 L0,10" stroke="${P.wing}" stroke-width="2"/></g>`).join('');
    g += [[70, -60], [-6, -92], [86, -30]].map(([x, y]) =>
      `<path transform="translate(${x} ${y})" d="M0,-10 L3,-3 L10,0 L3,3 L0,10 L-3,3 L-10,0 L-3,-3 Z" fill="#E8B04B" stroke="${P.ink}" stroke-width="2"/>`).join('');
  }
  return `<g transform="translate(${o.x} ${o.y}) rotate(${o.tilt || 0}) scale(${o.s || 1})">${g}</g>`;
}

// önden görünüm
function simitFront(o) {
  const P = CP;
  let g = '';
  g += `<path d="M-14,44 L-14,74 M14,44 L14,74" stroke="${P.ink}" stroke-width="11" stroke-linecap="round"/>
    <path d="M-14,44 L-14,74 M14,44 L14,74" stroke="${P.leg}" stroke-width="6" stroke-linecap="round"/>
    <path d="M-30,80 L-14,72 L-2,80 Q-16,84 -30,80 Z M2,80 L14,72 L30,80 Q16,84 2,80 Z" fill="${P.leg}" stroke="${P.ink}" stroke-width="3" stroke-linejoin="round"/>`;
  const wingL = 'M-46,-24 C-74,-8 -76,30 -56,52 L-66,56 L-58,40 C-52,20 -46,0 -46,-24 Z';
  g += `<path d="${wingL}" fill="${P.wing}" stroke="${P.ink}" stroke-width="4" stroke-linejoin="round"/>
        <path d="${wingL}" transform="scale(-1 1)" fill="${P.wing}" stroke="${P.ink}" stroke-width="4" stroke-linejoin="round"/>`;
  g += `<g transform="translate(0 30)"><ellipse rx="36" ry="13" fill="none" stroke="${P.ink}" stroke-width="16"/><ellipse rx="36" ry="13" fill="none" stroke="${P.simitDark}" stroke-width="10"/></g>`;
  g += `<ellipse cx="0" cy="2" rx="54" ry="54" fill="${P.body}" stroke="${P.ink}" stroke-width="4"/>
        <path d="M-40,30 C-24,52 24,52 40,30 C22,44 -22,44 -40,30 Z" fill="${P.shade}"/>
        <path d="M-56,60 L-66,56 L-58,40 Z" fill="${P.tip}" stroke="${P.ink}" stroke-width="3" stroke-linejoin="round"/>
        <path d="M56,60 L66,56 L58,40 Z" fill="${P.tip}" stroke="${P.ink}" stroke-width="3" stroke-linejoin="round"/>`;
  for (const sx of [-1, 1]) {
    g += `<g transform="scale(${sx} 1)">
      <circle cx="22" cy="-18" r="9.5" fill="${P.iris}" stroke="${P.ring}" stroke-width="3"/>
      <circle cx="20" cy="-17" r="4.2" fill="${P.ink}"/><circle cx="${sx > 0 ? 21.5 : 18.5}" cy="-19.5" r="1.5" fill="#fff"/>
      <path d="M11.5,-19 A10.5 10.5 0 0 1 32.5,-19 Z" fill="${P.body}"/><path d="M11,-19 L33,-19" stroke="${P.ink}" stroke-width="3" stroke-linecap="round"/>
      <path d="M9,-29 L35,-34" stroke="${P.wingDark}" stroke-width="5.5" stroke-linecap="round"/></g>`;
  }
  g += `<path d="M-14,-6 Q0,-13 14,-6 Q8,6 0,20 Q-8,6 -14,-6 Z" fill="${P.beak}" stroke="${P.ink}" stroke-width="3.5" stroke-linejoin="round"/>
        <path d="M-9,4 Q0,8 9,4" fill="none" stroke="${P.ink}" stroke-width="2.5"/>
        <circle cx="0" cy="12" r="3" fill="${P.spot}"/>`;
  g += `<g transform="translate(0 30)"><path d="M-36,0 A36 13 0 0 0 36,0" fill="none" stroke="${P.ink}" stroke-width="16" stroke-linecap="round"/>
        <path d="M-36,0 A36 13 0 0 0 36,0" fill="none" stroke="${P.simit}" stroke-width="10" stroke-linecap="round"/>
        <path d="M-28,6 A36 13 0 0 0 28,6" fill="none" stroke="${P.simitHi}" stroke-width="2.5" opacity=".9"/>
        ${[-26, -13, 0, 13, 26].map((x, i) => `<ellipse cx="${x}" cy="${r1(13 * Math.sqrt(1 - (x / 36) ** 2))}" rx="2" ry="1.2" fill="${P.sesame}" transform="rotate(${i * 25 - 50} ${x} ${r1(13 * Math.sqrt(1 - (x / 36) ** 2))})"/>`).join('')}</g>`;
  return `<g transform="translate(${o.x} ${o.y}) scale(${o.s || 1})">${g}</g>`;
}

// ---------- mimari ----------
function minaret(x, base, h, c, w = 10) {
  const balc = [0.55, 0.78].map(t => `<rect x="${x - w}" y="${r1(base - h * t)}" width="${w * 2}" height="5" fill="${c}"/>`).join('');
  return `<rect x="${x - w / 2}" y="${base - h}" width="${w}" height="${h}" fill="${c}"/>${balc}
    <path d="M${x - w / 2 - 1},${base - h} L${x},${base - h - w * 3.6} L${x + w / 2 + 1},${base - h} Z" fill="${c}"/>
    <rect x="${x - 0.8}" y="${base - h - w * 3.6 - 10}" width="1.6" height="10" fill="${c}"/>`;
}
function dome(cx, y, rx, ry, c) {
  return `<path d="M${cx - rx},${y} A${rx} ${ry} 0 0 1 ${cx + rx},${y} Z" fill="${c}"/>`;
}
// Süleymaniye esinli külliye silüeti (saygın, sade, uzak plan)
function suleymaniye(cx, base, s, c) {
  let g = '';
  g += `<rect x="-140" y="-74" width="280" height="74" fill="${c}"/>`;
  g += `<rect x="-70" y="-92" width="140" height="20" fill="${c}"/>`;
  g += dome(0, -90, 66, 60, c) + `<rect x="-0.8" y="-170" width="1.6" height="22" fill="${c}"/><circle cx="0" cy="-172" r="2.4" fill="${c}"/>`;
  g += dome(-74, -72, 36, 30, c) + dome(74, -72, 36, 30, c);
  g += [-118, -100, 100, 118].map(x => dome(x, -74, 13, 12, c)).join('');
  g += [-160, -128, -96, 96, 128, 160].map(x => dome(x * 1.25, -30, 10, 9, c)).join('') + `<rect x="-215" y="-30" width="430" height="30" fill="${c}"/>`;
  g += minaret(-150, 0, 250, c) + minaret(150, 0, 250, c) + minaret(-222, 0, 190, c, 9) + minaret(222, 0, 190, c, 9);
  return `<g transform="translate(${cx} ${base}) scale(${s})">${g}</g>`;
}
// Sultanahmet/Ayasofya yönünde çok uzak yarımada silüeti
function peninsulaFar(cx, base, s, c) {
  let g = `<rect x="-260" y="-26" width="520" height="26" fill="${c}"/>`;
  g += dome(-120, -26, 48, 40, c) + dome(-170, -26, 24, 20, c) + dome(-70, -26, 24, 20, c);
  g += minaret(-210, 0, 150, c, 8) + minaret(-30, 0, 150, c, 8);
  g += dome(120, -26, 52, 46, c) + dome(70, -26, 22, 20, c) + dome(170, -26, 22, 20, c);
  g += [50, 90, 150, 190, 215, 25].map((x, i) => minaret(x, 0, i % 2 ? 160 : 140, c, 7)).join('');
  return `<g transform="translate(${cx} ${base}) scale(${s})">${g}</g>`;
}
function galata(cx, base, s, c, rim, lit) {
  let g = '';
  g += `<path d="M-36,0 L36,0 L31,-232 L-31,-232 Z" fill="${c}"/>`;
  g += `<rect x="-41" y="-254" width="82" height="22" fill="${c}"/><rect x="-44" y="-258" width="88" height="6" fill="${c}"/>`;
  g += `<rect x="-32" y="-306" width="64" height="52" fill="${c}"/>`;
  g += [-22, -8, 6, 20].map(x => `<rect x="${x - 3}" y="-298" width="8" height="30" rx="4" fill="${lit}"/>`).join('');
  g += `<path d="M-38,-304 L0,-410 L38,-304 Z" fill="${c}"/><rect x="-1.2" y="-436" width="2.4" height="28" fill="${c}"/><circle cx="0" cy="-438" r="4" fill="${c}"/>`;
  g += [[-14, -190], [10, -150], [-6, -96], [14, -60]].map(([x, y]) => `<rect x="${x}" y="${y}" width="6" height="16" rx="3" fill="${lit}" opacity=".85"/>`).join('');
  g += `<path d="M31,-232 L36,0 L27,0 L23,-232 Z" fill="${rim}" opacity=".75"/>
        <path d="M0,-410 L38,-304 L28,-304 Z" fill="${rim}" opacity=".75"/>
        <rect x="35" y="-254" width="6" height="22" fill="${rim}" opacity=".75"/>`;
  return `<g transform="translate(${cx} ${base}) scale(${s})">${g}</g>`;
}
function kizKulesi(cx, base, s, c, c2, rim, lit) {
  let g = '';
  g += `<ellipse cx="0" cy="6" rx="170" ry="16" fill="${c2}"/>`;
  g += `<rect x="-130" y="-48" width="250" height="52" fill="${c}"/>`;
  g += [-112, -86, -60, 66, 92].map(x => `<rect x="${x}" y="-36" width="9" height="15" rx="4" fill="${lit}" opacity=".8"/>`).join('');
  // yan bina (kırma çatı)
  g += `<rect x="-118" y="-104" width="96" height="58" fill="${c}"/><path d="M-128,-102 L-70,-136 L-12,-102 Z" fill="${c}"/>`;
  g += [-104, -82, -60].map(x => `<rect x="${x}" y="-90" width="9" height="18" rx="4" fill="${lit}"/>`).join('');
  // kule
  g += `<rect x="-20" y="-200" width="58" height="156" fill="${c}"/>`;
  g += `<rect x="-28" y="-216" width="74" height="18" fill="${c}"/>`;
  g += `<rect x="-11" y="-262" width="40" height="48" fill="${c}"/>`;
  g += [-4, 8, 20].map(x => `<rect x="${x - 2}" y="-254" width="5" height="22" rx="2.5" fill="${lit}"/>`).join('');
  g += `<path d="M-16,-260 C-6,-286 4,-300 9,-334 C14,-300 24,-286 34,-260 Z" fill="${c}"/>`;
  g += `<rect x="8" y="-362" width="2" height="30" fill="${c}"/><circle cx="9" cy="-338" r="7" fill="${lit}" opacity=".9"/>`;
  g += [[-6, -170], [14, -130], [-6, -100]].map(([x, y]) => `<rect x="${x}" y="${y}" width="8" height="20" rx="4" fill="${lit}" opacity=".9"/>`).join('');
  g += `<rect x="31" y="-200" width="7" height="156" fill="${rim}" opacity=".7"/><rect x="40" y="-216" width="6" height="18" fill="${rim}" opacity=".7"/>
        <path d="M9,-334 C14,-300 24,-286 34,-260 L26,-260 C20,-284 13,-300 9,-334 Z" fill="${rim}" opacity=".7"/>
        <rect x="114" y="-48" width="6" height="52" fill="${rim}" opacity=".6"/>`;
  return `<g transform="translate(${cx} ${base}) scale(${s})">${g}</g>`;
}
function vapur(x, y, s, hull, cabin, stripe, funnel, lit) {
  return `<g transform="translate(${x} ${y}) scale(${s})">
    <path d="M-120,0 L120,0 L104,26 L-110,26 Z" fill="${hull}"/>
    <rect x="-96" y="-22" width="190" height="22" fill="${cabin}"/><rect x="-70" y="-40" width="130" height="18" fill="${cabin}"/>
    ${Array.from({ length: 9 }, (_, i) => `<rect x="${-88 + i * 20}" y="-16" width="10" height="8" fill="${lit}"/>`).join('')}
    <rect x="-96" y="-2" width="190" height="4" fill="${stripe}"/>
    <rect x="-8" y="-72" width="22" height="34" fill="${funnel}"/><rect x="-8" y="-72" width="22" height="8" fill="${hull}"/>
  </g>`;
}

// ---------- HUD (oyun arayüzü taslağı) ----------
function hud(score, prog, shadow, simits) {
  const stops = [180, 360, 540, 720, 900];
  const px = 180 + prog * 720;
  return `<g id="L8_hud" font-family="${FONT_D}">
    <g opacity=".95"><rect x="48" y="44" width="13" height="42" rx="5" fill="#FBF7EE"/><rect x="70" y="44" width="13" height="42" rx="5" fill="#FBF7EE"/></g>
    <line x1="180" y1="64" x2="900" y2="64" stroke="#FBF7EE" stroke-opacity=".35" stroke-width="6" stroke-linecap="round"/>
    <line x1="180" y1="64" x2="${px}" y2="64" stroke="#E8B04B" stroke-width="6" stroke-linecap="round"/>
    ${stops.map(x => `<circle cx="${x}" cy="64" r="10" fill="${x <= px ? '#E8B04B' : '#FBF7EE'}" stroke="${shadow}" stroke-width="3"/>`).join('')}
    <circle cx="${px}" cy="64" r="15" fill="#F7F3EA" stroke="#2B2B3A" stroke-width="4"/><path d="M${px + 12},60 L${px + 22},63 L${px + 12},67 Z" fill="#F2C23B" stroke="#2B2B3A" stroke-width="2"/>
    <text x="540" y="252" text-anchor="middle" font-size="150" fill="${shadow}" opacity=".55">${score}</text>
    <text x="540" y="244" text-anchor="middle" font-size="150" fill="#FBF7EE">${score}</text>
    <g transform="translate(948 140)"><ellipse rx="17" ry="17" fill="none" stroke="#2B2B3A" stroke-width="12"/><ellipse rx="17" ry="17" fill="none" stroke="#C8803A" stroke-width="7"/></g>
    <text x="978" y="154" font-size="40" fill="#FBF7EE">${simits}</text>
  </g>`;
}
function stamp(t1, t2, ink, paper) {
  return `<g id="L9_concept_label" transform="translate(56 1772) rotate(-4)" font-family="${FONT_D}">
    <rect width="${Math.max(300, t1.length * 24 + 44)}" height="96" fill="${paper}" stroke="${ink}" stroke-width="3" stroke-dasharray="8 6"/>
    <text x="18" y="46" font-size="30" fill="${ink}" letter-spacing="2">${t1}</text>
    <text x="18" y="78" font-size="20" font-family="${FONT_S}" fill="${ink}" opacity=".75" letter-spacing="1">${t2}</text>
  </g>`;
}
function svgDoc(body, w = W, h = H, extraDefs = '') {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">${defs(extraDefs)}${body}</svg>`;
}
const simitPickup = (x, y, s = 1) => `<g transform="translate(${x} ${y}) scale(${s})">${ringLoose(CP, 0, 0, 0, 24, 24)}<circle r="40" fill="#FFE7A8" opacity=".18"/></g>`;

// ================= KONSEPT A — ŞAFAK / HALİÇ =================
function conceptA() {
  const L = [];
  L.push(`<g id="L0_sky">${bands(['#3E4A7A', '#57568A', '#7E6A96', '#B98299', '#E6A2A0', '#F7C3AA', '#FCD9B8'], [0, 300, 520, 700, 860, 990, 1100, HZ])}
    <circle cx="730" cy="${HZ}" r="290" fill="#FDD5B0" opacity=".35"/><circle cx="730" cy="${HZ}" r="210" fill="#FEDDB8" opacity=".55"/>
    <circle cx="730" cy="${HZ}" r="140" fill="#FFE9C8"/></g>`);
  L.push(`<g id="L1_clouds">${cloud(250, 420, 1.1, '#9C7A9A', '#7E6A96')}${cloud(860, 640, 0.9, '#C98F9C', '#A97A92')}${cloud(380, 930, 0.8, '#F2B7A6', '#DE9C9C')}
    ${farGulls([[620, 380, 1], [660, 360, .8], [700, 395, .9]], '#57568A')}</g>`);
  L.push(`<g id="L2_far_peninsula">${suleymaniye(250, HZ, 1, '#8C7192')}
    <path d="M0,${HZ} L0,1150 L40,1150 L40,1160 L560,1162 L560,${HZ} Z" fill="#8C7192"/></g>`);
  L.push(`<g id="L3_hero_galata">
    <path d="M520,${HZ} C600,1160 700,1124 1080,1112 L1080,${HZ} Z" fill="#5A4A72"/>
    ${[[600, 1150, 46, 40], [650, 1132, 50, 52], [710, 1120, 40, 60], [930, 1092, 54, 50], [990, 1080, 60, 62], [1040, 1096, 50, 40]].map(([x, y, w, h]) => `<rect x="${x}" y="${y}" width="${w}" height="${h + 40}" fill="#5A4A72"/><path d="M${x - 4},${y} L${x + w / 2},${y - 16} L${x + w + 4},${y} Z" fill="#5A4A72"/><rect x="${x + 10}" y="${y + 14}" width="7" height="10" fill="#FFD3A1" opacity=".7"/>`).join('')}
    ${galata(855, 1124, 1.05, '#4A3F63', '#FFD3A1', '#FFD3A1')}</g>`);
  L.push(`<g id="L5_water">${bands(['#8C8DB4', '#6F7BA6', '#5C6E9A', '#4E5F8C'], [HZ, 1214, 1290, 1520, H])}
    ${[[730, 1206, 300], [730, 1236, 230], [730, 1270, 170], [730, 1310, 120], [730, 1356, 80], [730, 1410, 50]].map(([x, y, w]) => `<rect x="${x - w / 2}" y="${y}" width="${w}" height="9" rx="4.5" fill="#FFE9C8" opacity=".85"/>`).join('')}
    ${[[120, 1260, 60], [300, 1330, 40], [520, 1450, 70], [900, 1500, 50]].map(([x, y, w]) => `<rect x="${x}" y="${y}" width="${w}" height="6" rx="3" fill="#B7B9D6" opacity=".7"/>`).join('')}</g>`);
  L.push(`<g id="L4_mid_vapur">${vapur(250, 1262, 0.7, '#3E3658', '#ECD9C6', '#D9643A', '#ECD9C6', '#FFD3A1')}
    <rect x="70" y="1236" width="260" height="6" rx="3" fill="#ECD9C6" opacity=".35"/></g>`);
  // oynanış: alt = ahşap ev + baca, üst = cumbalı ev + çamaşır ipi
  const ox = 600, ow = 196, top = 690, bot = 1080;
  const facade = (x, y, w, h, base, win, lit) => {
    let s = `<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="${base}"/>`;
    for (let yy = y + 30; yy < y + h - 40; yy += 96) for (const xx of [x + 26, x + w - 70]) s += `<rect x="${xx}" y="${yy}" width="44" height="58" rx="3" fill="${rnd() > .72 ? lit : win}"/><rect x="${xx}" y="${yy + 26}" width="44" height="4" fill="${base}"/>`;
    for (let yy = y + 10; yy < y + h; yy += 22) s += `<rect x="${x}" y="${yy}" width="${w}" height="2" fill="#000" opacity=".12"/>`;
    return s;
  };
  L.push(`<g id="L6_gameplay">
    <g id="obstacle_bottom_house">
      ${facade(ox, bot + 60, ow, H - bot - 60, '#3A2E48', '#4D4266', '#FFD3A1')}
      <rect x="${ox + ow - 7}" y="${bot + 60}" width="7" height="${H - bot - 60}" fill="#FFD3A1" opacity=".75"/>
      <path d="M${ox - 10},${bot + 62} L${ox + ow / 2},${bot + 6} L${ox + ow + 10},${bot + 62} Z" fill="#5A2E36"/>
      <path d="M${ox + ow / 2},${bot + 6} L${ox + ow + 10},${bot + 62} L${ox + ow - 6},${bot + 62} Z" fill="#FFD3A1" opacity=".55"/>
      <rect x="${ox + 120}" y="${bot}" width="30" height="40" fill="#5A2E36"/><rect x="${ox + 114}" y="${bot - 4}" width="42" height="10" fill="#2E2A40"/>
      <rect x="${ox - 10}" y="${bot + 58}" width="${ow + 20}" height="8" fill="#2E2A40"/>
    </g>
    <g id="obstacle_top_cumba">
      ${facade(ox, 0, ow, top - 110, '#33405A', '#4A5878', '#FFD3A1')}
      <rect x="${ox - 14}" y="${top - 112}" width="${ow + 28}" height="70" fill="#2F3A54"/>
      ${[0, 1, 2].map(i => `<rect x="${ox + 6 + i * 64}" y="${top - 100}" width="50" height="44" rx="3" fill="${i === 1 ? '#FFD3A1' : '#4A5878'}"/>`).join('')}
      <rect x="${ox - 14}" y="${top - 44}" width="${ow + 28}" height="8" fill="#22283C"/>
      <line x1="${ox - 6}" y1="${top - 34}" x2="${ox + ow + 6}" y2="${top - 28}" stroke="#2E2A40" stroke-width="3"/>
      <path d="M${ox + 10},${top - 33} h34 v30 h-34 Z" fill="#D9643A"/><path d="M${ox + 58},${top - 32} h24 l6 32 h-36 Z" fill="#2E8B99"/>
      <path d="M${ox + 104},${top - 31} h40 v22 h-40 Z" fill="#F2E6D0"/><path d="M${ox + 156},${top - 30} h24 v28 l-12 -6 l-12 6 Z" fill="#E8B04B"/>
      <rect x="${ox + ow + 7}" y="0" width="7" height="${top - 42}" fill="#FFD3A1" opacity=".7"/>
    </g>
    ${simitPickup(870, 560, 1)}
    ${simit({ x: 330, y: 880, s: 0.8, tilt: -12, wing: 45, rim: '#FFD3A1', ring: [20, 28, -12] })}
  </g>`);
  L.push(`<g id="L7_foreground">${farGulls([[80, 1500, 3.2]], '#3E4A7A')}</g>`);
  L.push(hud(7, 0.12, '#3E4A7A', 3));
  L.push(stamp('HALİÇ · ŞAFAK', 'Konsept A · 06:12', '#3E4A7A', '#FCEBD8'));
  L.push(grain() + vignette());
  return svgDoc(L.join('\n'));
}

// ================= KONSEPT B — GÜN BATIMI / KIZ KULESİ =================
function conceptB() {
  const L = [];
  L.push(`<g id="L0_sky">${bands(['#4C3263', '#5B3A6E', '#7A4170', '#A14E66', '#C95B57', '#E3684A', '#F08F4E', '#F7C35F'], [0, 260, 470, 650, 800, 920, 1030, 1120, HZ])}
    <circle cx="420" cy="${HZ}" r="300" fill="#F9B05C" opacity=".3"/><circle cx="420" cy="${HZ}" r="220" fill="#FBBF63" opacity=".5"/>
    <circle cx="420" cy="${HZ}" r="160" fill="#FFD98A"/></g>`);
  L.push(`<g id="L1_clouds">
    <rect x="-40" y="560" width="520" height="22" rx="11" fill="#8C4A6A"/><rect x="60" y="540" width="300" height="22" rx="11" fill="#8C4A6A"/>
    <rect x="640" y="440" width="480" height="20" rx="10" fill="#6C3A68"/><rect x="760" y="420" width="260" height="20" rx="10" fill="#6C3A68"/>
    <rect x="560" y="900" width="420" height="16" rx="8" fill="#F08F4E"/><rect x="40" y="980" width="300" height="14" rx="7" fill="#F7A85A"/>
    ${farGulls([[900, 760, .9], [940, 740, .7]], '#7A4170')}</g>`);
  L.push(`<g id="L2_far">${peninsulaFar(170, HZ, 0.62, '#B0636A')}
    <path d="M620,${HZ} C700,1170 820,1160 1080,1150 L1080,${HZ} Z" fill="#9E5468"/>
    ${dome(1000, 1150, 26, 22, '#9E5468')}${minaret(960, 1150, 70, '#9E5468', 5)}</g>`);
  L.push(`<g id="L5_water">${bands(['#B3666A', '#93586A', '#7A4A63', '#683E58'], [HZ, 1222, 1300, 1560, H])}
    ${Array.from({ length: 12 }, (_, i) => { const w = 300 - i * 22, y = 1204 + i * 30; return `<rect x="${420 - w / 2 + (i % 2 ? 14 : -10)}" y="${y}" width="${w}" height="${i < 4 ? 10 : 8}" rx="5" fill="${i % 3 === 2 ? '#FFB25B' : '#F7C35F'}" opacity="${0.95 - i * 0.05}"/>`; }).join('')}
    ${[[800, 1290, 70], [720, 1330, 40], [840, 1370, 50]].map(([x, y, w]) => `<rect x="${x}" y="${y}" width="${w}" height="7" rx="3.5" fill="#3A2340" opacity=".55"/>`).join('')}</g>`);
  L.push(`<g id="L3_hero_kizkulesi">${kizKulesi(820, 1232, 1.0, '#3A2340', '#2A1A2E', '#FFB25B', '#FFC46B')}</g>`);
  L.push(`<g id="L4_mid_vapur">${vapur(130, 1300, 0.55, '#3A2340', '#C99A88', '#E3684A', '#C99A88', '#FFC46B')}</g>`);
  // oynanış: alt = vapur bacası (vapur gövdesi kolonu), üst = martı sürüsü
  const ox = 470, ow = 196, top = 540, bot = 960;
  const buoy = (x, y) => `<g transform="translate(${x} ${y})"><circle r="26" fill="none" stroke="#2A1A2E" stroke-width="18"/><circle r="26" fill="none" stroke="#F2E6D0" stroke-width="12"/><circle r="26" fill="none" stroke="#D9643A" stroke-width="12" stroke-dasharray="20.4 20.4"/></g>`;
  L.push(`<g id="L6_gameplay">
    <g id="obstacle_top_iskele_kazigi">
      <rect x="${ox}" y="0" width="${ow}" height="${top - 44}" fill="#2A1A2E"/>
      ${[1, 2, 3, 4].map(i => `<rect x="${ox + i * 39}" y="0" width="3" height="${top - 44}" fill="#3E2847"/>`).join('')}
      ${[90, 250, 410].map(y => `<path d="M${ox + 10},${y - 40} Q${ox + ow / 2},${y + 30} ${ox + ow - 10},${y - 40}" fill="none" stroke="#8C6A5A" stroke-width="5"/>`).join('')}
      ${buoy(ox + 62, 150)}${buoy(ox + 134, 330)}
      <rect x="${ox - 14}" y="${top - 48}" width="${ow + 28}" height="48" rx="4" fill="#3A2340"/>
      <rect x="${ox - 14}" y="${top - 6}" width="${ow + 28}" height="6" fill="#FFB25B"/>
      <rect x="${ox + ow / 2 - 16}" y="${top - 40}" width="32" height="28" rx="4" fill="#FFC46B"/>
      <rect x="${ox + ow - 7}" y="0" width="7" height="${top - 48}" fill="#FFB25B" opacity=".7"/>
    </g>
    <g id="obstacle_bottom_vapur_funnel">
      <rect x="${ox}" y="${bot}" width="${ow}" height="46" fill="#2A1A2E"/>
      <rect x="${ox}" y="${bot + 46}" width="${ow}" height="${1500 - bot - 46}" fill="#C9957F"/>
      <rect x="${ox}" y="${bot + 46}" width="40" height="${1500 - bot - 46}" fill="#A87566"/>
      <g transform="translate(${ox + ow / 2 + 10} ${bot + 220})" fill="none" stroke="#2A1A2E" stroke-width="7" stroke-linecap="round">
        <circle r="46"/><circle cy="-26" r="7"/><path d="M0,-19 L0,28 M-16,-6 L16,-6 M-24,12 Q-20,30 0,30 Q20,30 24,12"/></g>
      <rect x="${ox}" y="1500" width="${ow}" height="200" fill="#EBD4C2"/>
      ${[0, 1, 2, 3].map(i => `<rect x="${ox + 18 + i * 44}" y="1540" width="28" height="36" rx="3" fill="#FFC46B"/>`).join('')}
      <rect x="${ox}" y="1690" width="${ow}" height="${H - 1690}" fill="#2A1A2E"/><rect x="${ox}" y="1700" width="${ow}" height="8" fill="#E3684A"/>
      <rect x="${ox + ow - 8}" y="${bot}" width="8" height="${H - bot}" fill="#FFB25B" opacity=".75"/>
      <rect x="${ox}" y="${bot}" width="${ow}" height="5" fill="#FFB25B" opacity=".8"/>
      <circle cx="${ox + 40}" cy="${bot - 40}" r="22" fill="#C98A8A" opacity=".55"/><circle cx="${ox + 8}" cy="${bot - 76}" r="16" fill="#C98A8A" opacity=".4"/><circle cx="${ox - 24}" cy="${bot - 104}" r="11" fill="#C98A8A" opacity=".3"/>
    </g>
    ${simitPickup(880, 640, 1)}
    ${simit({ x: 230, y: 740, s: 0.8, tilt: 8, wing: 0, rim: '#FFB25B', ring: [22, 26, -18], expr: 'focus' })}
  </g>`);
  L.push(hud(46, 0.56, '#4C3263', 18));
  L.push(stamp('KIZ KULESİ', 'Konsept B · 18:47', '#4C3263', '#FCE3C8'));
  L.push(grain() + vignette());
  return svgDoc(L.join('\n'));
}

// ================= KONSEPT C — GECE / BOĞAZ KÖPRÜSÜ =================
function conceptC() {
  seed = 99;
  const L = [];
  let stars = '';
  for (let i = 0; i < 90; i++) { const x = rnd() * W, y = rnd() * 820, r = rnd() * 1.8 + 0.6; stars += `<circle cx="${r1(x)}" cy="${r1(y)}" r="${r1(r)}" fill="#F2E6D0" opacity="${r1(0.35 + rnd() * 0.5)}"/>`; }
  for (const [x, y] of [[150, 380], [930, 610], [470, 170]]) stars += `<path transform="translate(${x} ${y})" d="M0,-10 L2,-2 L10,0 L2,2 L0,10 L-2,2 L-10,0 L-2,-2 Z" fill="#F2E6D0"/>`;
  L.push(`<g id="L0_sky">${bands(['#0B1030', '#0E1433', '#141B42', '#1A2350', '#26305E'], [0, 360, 700, 930, 1090, HZ])}${stars}
    <circle cx="830" cy="300" r="62" fill="#F2E6D0"/><circle cx="856" cy="284" r="56" fill="#0E1433"/><circle cx="830" cy="300" r="110" fill="#F2E6D0" opacity=".05"/></g>`);
  // uzak kıyılar + ışıklı pencereler
  let wins = '';
  seed = 5;
  for (let i = 0; i < 70; i++) { const x = rnd() * W, y = 1120 + rnd() * 66; wins += `<rect x="${r1(x)}" y="${r1(y)}" width="4" height="4" fill="#FFC857" opacity="${r1(0.4 + rnd() * 0.5)}"/>`; }
  L.push(`<g id="L2_far_shores">
    <path d="M0,${HZ} L0,1110 C120,1096 260,1104 380,1120 L380,${HZ} Z" fill="#0A0E24"/>
    <path d="M560,${HZ} L560,1130 C700,1100 880,1086 1080,1094 L1080,${HZ} Z" fill="#0A0E24"/>
    <g id="ortakoy_silhouette">${dome(300, 1150, 30, 30, '#0D1230')}<rect x="262" y="1150" width="76" height="40" fill="#0D1230"/>${minaret(250, 1190, 104, '#0D1230', 6)}${minaret(350, 1190, 104, '#0D1230', 6)}
      ${[278, 292, 306, 320].map(x => `<rect x="${x}" y="1160" width="6" height="14" rx="3" fill="#FFC857" opacity=".55"/>`).join('')}</g>
    ${wins}</g>`);
  // köprü
  const T1 = 170, T2 = 910, TT = 560, DECK = 1104;
  const cy = t => (1 - t) ** 2 * (TT + 14) + 2 * t * (1 - t) * 1250 + t * t * (TT + 14);
  let hang = '', beads = '';
  for (let x = T1 + 24; x < T2; x += 26) { const t = (x - T1) / (T2 - T1); hang += `<line x1="${x}" y1="${r1(cy(t))}" x2="${x}" y2="${DECK}" stroke="#2A3566" stroke-width="2"/>`; }
  for (let i = 0; i <= 40; i++) {
    const t = i / 40, x = T1 + (T2 - T1) * t, y = cy(t);
    const c = i % 7 === 3 ? '#FF3E7F' : i % 7 === 5 ? '#00E5FF' : '#FFC857';
    beads += `<circle cx="${r1(x)}" cy="${r1(y)}" r="9" fill="${c}" opacity=".18"/><circle cx="${r1(x)}" cy="${r1(y)}" r="3.6" fill="${c}"/>`;
  }
  const tower = x => `<path d="M${x - 20},${DECK + 90} L${x + 20},${DECK + 90} L${x + 14},${TT} L${x - 14},${TT} Z" fill="#0A0E24"/>
    <rect x="${x - 22}" y="${TT + 120}" width="44" height="12" fill="#0A0E24"/><rect x="${x - 22}" y="${TT + 300}" width="44" height="12" fill="#0A0E24"/>
    <rect x="${x - 18}" y="${TT - 14}" width="36" height="16" fill="#0A0E24"/><circle cx="${x}" cy="${TT - 18}" r="5" fill="#FF5A5A"/><circle cx="${x}" cy="${TT - 18}" r="14" fill="#FF5A5A" opacity=".2"/>
    <rect x="${x + 8}" y="${TT}" width="5" height="${DECK + 90 - TT}" fill="#FFC857" opacity=".35"/>`;
  L.push(`<g id="L3_hero_bridge">
    <path d="M${T1},${TT + 14} Q40,900 -40,1080" fill="none" stroke="#2A3566" stroke-width="5"/>
    <path d="M${T2},${TT + 14} Q1010,900 1120,1080" fill="none" stroke="#2A3566" stroke-width="5"/>
    ${hang}
    <path d="M${T1},${TT + 14} Q540,1250 ${T2},${TT + 14}" fill="none" stroke="#2A3566" stroke-width="6"/>
    ${beads}
    ${tower(T1)}${tower(T2)}
    <rect x="0" y="${DECK}" width="${W}" height="26" fill="#0A0E24"/>
    ${Array.from({ length: 46 }, (_, i) => `<circle cx="${i * 24 + 6}" cy="${DECK + 4}" r="2.4" fill="#FFC857"/>`).join('')}
    <rect x="0" y="${DECK + 26}" width="${W}" height="4" fill="#00E5FF" opacity=".35"/></g>`);
  let refl = '';
  seed = 21;
  for (let i = 0; i < 34; i++) { const x = rnd() * W, y = 1214 + rnd() * 420, c = rnd() > .8 ? (rnd() > .5 ? '#FF3E7F' : '#00E5FF') : '#FFC857'; refl += `<rect x="${r1(x)}" y="${r1(y)}" width="${r1(18 + rnd() * 40)}" height="5" rx="2.5" fill="${c}" opacity="${r1(0.25 + rnd() * 0.4)}"/>`; }
  L.push(`<g id="L5_water">${bands(['#1B2450', '#141C40', '#10173A', '#0C1230'], [HZ, 1224, 1320, 1600, H])}${refl}
    ${[T1, T2].map(x => [0, 1, 2, 3, 4].map(i => `<rect x="${x - 4}" y="${1210 + i * 30}" width="${16 - i * 2}" height="14" fill="#FFC857" opacity="${0.5 - i * 0.08}"/>`).join('')).join('')}</g>`);
  // oynanış: üst = askı kablosu kelepçesi, alt = balıkçı teknesi direği + fener
  const ox = 590, ow = 196, top = 640, bot = 1030;
  let cableBeads = '';
  for (let y = 30; y < top - 60; y += 46) for (const x of [ox + 60, ox + 136]) cableBeads += `<circle cx="${x}" cy="${y}" r="4" fill="#FFC857"/><circle cx="${x}" cy="${y}" r="10" fill="#FFC857" opacity=".15"/>`;
  L.push(`<g id="L6_gameplay">
    <g id="obstacle_top_hanger_cable">
      <rect x="${ox}" y="0" width="${ow}" height="${top - 50}" fill="#0A0D1F"/>
      <rect x="${ox + 56}" y="0" width="8" height="${top - 50}" fill="#1E2750"/><rect x="${ox + 132}" y="0" width="8" height="${top - 50}" fill="#1E2750"/>
      ${cableBeads}
      <rect x="${ox - 12}" y="${top - 56}" width="${ow + 24}" height="56" rx="6" fill="#151B3A"/>
      <rect x="${ox - 12}" y="${top - 6}" width="${ow + 24}" height="6" fill="#FFC857"/>
      ${[0, 1, 2, 3].map(i => `<circle cx="${ox + 22 + i * 50}" cy="${top - 30}" r="7" fill="#05070F"/>`).join('')}
      <rect x="${ox + ow - 7}" y="0" width="7" height="${top - 56}" fill="#00E5FF" opacity=".45"/>
    </g>
    <g id="obstacle_bottom_fishing_mast">
      <circle cx="${ox + ow / 2}" cy="${bot + 36}" r="120" fill="#FFC857" opacity=".1"/>
      <rect x="${ox}" y="${bot + 60}" width="${ow}" height="${1640 - bot - 60}" fill="#0A0D1F"/>
      ${Array.from({ length: 12 }, (_, i) => `<line x1="${ox}" y1="${bot + 100 + i * 46}" x2="${ox + ow}" y2="${bot + 130 + i * 46}" stroke="#1E2750" stroke-width="3"/>`).join('')}
      <rect x="${ox + ow / 2 - 12}" y="${bot + 60}" width="24" height="${1640 - bot - 60}" fill="#151B3A"/>
      <rect x="${ox - 10}" y="${bot}" width="${ow + 20}" height="66" rx="8" fill="#151B3A"/>
      <rect x="${ox + 22}" y="${bot + 12}" width="${ow - 44}" height="42" rx="6" fill="#FFC857"/>
      ${[0, 1, 2].map(i => `<rect x="${ox + 60 + i * 30}" y="${bot + 12}" width="5" height="42" fill="#151B3A"/>`).join('')}
      <rect x="${ox - 10}" y="${bot}" width="${ow + 20}" height="6" fill="#FFE29A"/>
      <path d="M${ox - 30},1640 L${ox + ow + 30},1640 L${ox + ow},${H} L${ox},${H} Z" fill="#0A0D1F"/>
      <rect x="${ox}" y="1600" width="${ow}" height="40" fill="#151B3A"/><rect x="${ox + 70}" y="1608" width="50" height="22" rx="3" fill="#FFC857"/>
      <rect x="${ox + ow - 7}" y="${bot + 66}" width="7" height="${1640 - bot - 66}" fill="#FFC857" opacity=".5"/>
    </g>
    ${simitPickup(880, 820, 1)}
    ${simit({ x: 300, y: 830, s: 0.8, tilt: -6, wing: -30, rim: '#FFC857', ring: [21, 28, -14] })}
    <path d="M240,780 C280,740 360,740 400,780" fill="none" stroke="#FFC857" stroke-width="0" />
  </g>`);
  L.push(hud(93, 1.0, '#05070F', 41));
  L.push(stamp('BOĞAZ KÖPRÜSÜ', 'Konsept C · 23:30', '#0E1433', '#E9E2D2'));
  L.push(grain(W, H, 0.5) + vignette());
  return svgDoc(L.join('\n'));
}

// ================= SİMİT KARAKTER SAYFASI =================
function sheet() {
  const SW = 2400, SH = 1640;
  const panel = (x, y, w, h, title, note) => `<g>
    <rect x="${x}" y="${y}" width="${w}" height="${h}" rx="14" fill="#FBF7EE" stroke="#D8CDB6" stroke-width="2"/>
    <text x="${x + 24}" y="${y + 40}" font-family="${FONT_S}" font-size="22" letter-spacing="2.5" fill="#D9643A">${title}</text>
    ${note ? `<text x="${x + 24}" y="${y + h - 22}" font-family="${FONT_B}" font-size="19" fill="#4C6280">${note}</text>` : ''}</g>`;
  const label = (x, y, t, size = 19, c = '#4C6280', anchor = 'middle') => `<text x="${x}" y="${y}" text-anchor="${anchor}" font-family="${FONT_B}" font-size="${size}" fill="${c}">${t}</text>`;
  const B = [];
  B.push(`<rect width="${SW}" height="${SH}" fill="#F2E6D0"/>`);
  B.push(`<text x="60" y="104" font-family="${FONT_D}" font-size="84" fill="#1F3A5F">SİMİT</text>
    <text x="350" y="76" font-family="${FONT_S}" font-size="26" fill="#1F3A5F">Karakter tasarım sayfası · v1</text>
    <text x="350" y="110" font-family="${FONT_B}" font-size="22" fill="#4C6280">Martı: Istanbul Flight · İstanbul'un sarı bacaklı martısı (Larus michahellis) temel alındı · Modern Kartpostal stili</text>`);
  // palet
  const pal = [['#F7F3EA', 'Tüy beyazı'], ['#9AACBF', 'Sırt grisi'], ['#6E8299', 'Gölge gri'], ['#2B2B3A', 'Kontur'], ['#F2C23B', 'Gaga'], ['#D9643A', 'Gaga beneği / göz halkası'], ['#F5DC6A', 'İris'], ['#F2B33B', 'Bacak'], ['#C8803A', 'Simit'], ['#FBF2D0', 'Susam']];
  B.push(pal.map(([c, n], i) => `<g transform="translate(${1500 + (i % 5) * 176} ${44 + Math.floor(i / 5) * 60})"><rect width="40" height="40" rx="6" fill="${c}" stroke="#2B2B3A" stroke-width="1.5"/>${label(50, 18, c, 15, '#1F3A5F', 'start')}${label(50, 37, n.length > 14 ? n.slice(0, 14) + '…' : n, 14, '#4C6280', 'start')}</g>`).join(''));

  // satır 1
  const y1 = 170;
  B.push(panel(60, y1, 420, 500, 'ÖNDEN', 'Simetrik, kaşlar içe eğik: kendinden emin'));
  B.push(simitFront({ x: 270, y: y1 + 250, s: 2.2 }));
  B.push(panel(500, y1, 470, 500, 'YANDAN · TÜNEMİŞ', 'Sarı gaga + kırmızı benek, sarı bacak'));
  B.push(simit({ x: 730, y: y1 + 240, s: 2.1, wing: 0, fly: false, legs: true }));
  B.push(panel(990, y1, 560, 500, 'UÇUŞ POZU · SÜZÜLME', 'Kesik çizgi: hitbox (gövdenin %80’i)'));
  B.push(simit({ x: 1270, y: y1 + 260, s: 2.2, wing: 18 }));
  B.push(`<circle cx="${1270 - 2 * 2.2}" cy="${y1 + 260}" r="${0.8 * 56 * 2.2}" fill="none" stroke="#D9643A" stroke-width="3" stroke-dasharray="10 8"/>`);
  // silüet testi
  B.push(panel(1570, y1, 770, 500, 'SİLÜET VE KÜÇÜK EKRAN TESTİ', 'Tombul gövde + uzun gaga silüeti 28 px’de bile okunuyor; simit renkle ayrışıyor'));
  const sizes = [[128, 0.68], [64, 0.34], [40, 0.213], [28, 0.149]];
  let sx = 1650;
  sizes.forEach(([px, s]) => { B.push(simit({ x: sx + 60 * s / 0.68, y: y1 + 170, s, wing: 18, sil: true })); B.push(label(sx + 60 * s / 0.68, y1 + 250, px + ' px', 17)); sx += px + 70; });
  B.push(`<rect x="1594" y="${y1 + 290}" width="360" height="150" rx="10" fill="#BFE3EC"/><rect x="1594" y="${y1 + 380}" width="360" height="60" fill="#2E8B99"/>`);
  B.push(`<rect x="1966" y="${y1 + 290}" width="350" height="150" rx="10" fill="#0E1433"/>`);
  sx = 1640;
  [[0.68], [0.34], [0.213]].forEach(([s], i) => { B.push(simit({ x: sx, y: y1 + 360, s, wing: 18 })); sx += [110, 80, 0][i]; });
  sx = 2020;
  [[0.68], [0.34], [0.213]].forEach(([s], i) => { B.push(simit({ x: sx, y: y1 + 360, s, wing: 18, rim: '#FFC857' })); sx += [110, 80, 0][i]; });
  B.push(label(1774, y1 + 284, 'Öğle', 15) + label(2141, y1 + 284, 'Gece (sıcak kenar ışığı)', 15));

  // satır 2: kanat çırpma
  const y2 = 700;
  B.push(panel(60, y2, 1250, 430, 'KANAT ÇIRPMA DÖNGÜSÜ · 4 ANA KARE', 'Oyunda 6 kareye çoğaltılır (ara kareler: 1→2 ve 3→4). Simit halkası her karede yarım vuruş geride kalır.'));
  const flap = [[62, [24, 20, -26], '1 · Yukarı'], [28, [23, 23, -22], '2 · İniş'], [0, [22, 26, -18], '3 · Orta'], [-38, [21, 30, -12], '4 · Aşağı (itiş)']];
  flap.forEach(([w, ring, t], i) => { const x = 220 + i * 290; B.push(simit({ x, y: y2 + 220, s: 1.45, wing: w, ring })); B.push(label(x, y2 + 370, t, 20, '#1F3A5F')); });
  B.push(panel(1330, y2, 500, 430, 'YÜKSELME', 'Gövde 20° yukarı, kanat itişte'));
  B.push(simit({ x: 1580, y: y2 + 230, s: 1.65, tilt: -20, wing: -36, ring: [10, 32, 2], expr: 'focus' }));
  B.push(`<path d="M1440,${y2 + 330} q-20,-50 0,-100" fill="none" stroke="#D9643A" stroke-width="4" stroke-linecap="round" stroke-dasharray="2 12"/>`);
  B.push(panel(1850, y2, 490, 430, 'DÜŞME', 'Burun 28° aşağı, kanatlar yukarıda'));
  B.push(simit({ x: 2095, y: y2 + 220, s: 1.65, tilt: 28, wing: 58, ring: [32, 14, -36], expr: 'surprised' }));

  // satır 3: ifadeler + simit konumu
  const y3 = 1160;
  B.push(panel(60, y3, 1250, 430, 'İFADELER', 'Ağır göz kapağı ve düz kaş: Simit'));
  B.push(label(370, y3 + 408, '', 1));
  const ex = [['smug', 'Varsayılan · kendinden emin'], ['happy', 'Mutlu · simit kaptı'], ['surprised', 'Şaşkın · kıl payı'], ['crash', 'Çarpışma']];
  ex.forEach(([e, t], i) => {
    const x = 210 + i * 300;
    B.push(simit({ x, y: y3 + 215, s: 1.45, wing: e === 'crash' ? 70 : e === 'happy' ? 40 : 10, expr: e, ring: e === 'crash' ? 'loose' : [22, 26, -18], tilt: e === 'crash' ? 18 : 0 }));
    B.push(label(x, y3 + 365, t, 20, '#1F3A5F'));
  });
  B.push(panel(1330, y3, 1010, 430, 'SİMİT HALKASININ HAREKETİ', 'Halka boyuna takılıdır; 3/4 açıyla çizilir, deliği her pozda görünür'));
  const rp = [[[22, 26, -18], 0, 0, 'Süzülme · göğüste'], [[10, 32, 2], -20, -36, 'Yükselme · geriye savrulur'], [[32, 14, -36], 28, 58, 'Düşme · çeneye kayar'], ['loose', 18, 70, 'Çarpışma · fırlar']];
  rp.forEach(([ring, tilt, wing, t], i) => { const x = 1460 + i * 248; B.push(simit({ x, y: y3 + 210, s: 1.05, tilt, wing, ring, expr: i === 3 ? 'crash' : i === 2 ? 'surprised' : 'smug' })); B.push(label(x + 4, y3 + 345, t, 18, '#1F3A5F')); });
  B.push(`<rect width="${SW}" height="${SH}" filter="url(#grain)" opacity=".35"/>`);
  return svgDoc(B.join('\n'), SW, SH);
}

// ================= PALET SAYFASI =================
function palette() {
  const PW = 1800, PH = 1180;
  const phases = [
    ['ŞAFAK · Haliç', [['#3E4A7A', 'Gök üst'], ['#F4A9A0', 'Gök orta'], ['#FCD9B8', 'Ufuk'], ['#5C6E9A', 'Su'], ['#8C7192', 'Uzak silüet'], ['#4A3F63', 'Simge'], ['#FFD3A1', 'Işık / kenar'], ['#3A2E48', 'Engel taban']]],
    ['ÖĞLE · Galata', [['#4FA3C7', 'Gök üst'], ['#BFE3EC', 'Ufuk'], ['#2E8B99', 'Su'], ['#6E8FA3', 'Uzak silüet'], ['#3B4F63', 'Simge'], ['#FFF6DA', 'Işık / kenar'], ['#3B2F2F', 'Engel taban']]],
    ['GÜN BATIMI · Kız Kulesi', [['#5B3A6E', 'Gök üst'], ['#E3684A', 'Gök orta'], ['#F7C35F', 'Ufuk'], ['#7A4A63', 'Su'], ['#B0636A', 'Uzak silüet'], ['#3A2340', 'Simge'], ['#FFB25B', 'Işık / kenar'], ['#2A1A2E', 'Engel taban']]],
    ['GECE · Boğaz Köprüsü', [['#0E1433', 'Gök üst'], ['#26305E', 'Ufuk'], ['#141C40', 'Su'], ['#0A0E24', 'Silüet'], ['#FFC857', 'Sodyum ışık'], ['#FF3E7F', 'Neon · sadece ışık'], ['#00E5FF', 'Neon · sadece ışık'], ['#0A0D1F', 'Engel taban']]],
    ['ARAYÜZ', [['#F2E6D0', 'Kartpostal kremi'], ['#1F3A5F', 'Boğaz laciverti'], ['#D9643A', 'Kiremit · aksiyon'], ['#E8B04B', 'Hardal · ödül'], ['#2E8B99', 'Turkuaz'], ['#FBF7EE', 'Skor rakamı']]],
    ['SİMİT', [['#F7F3EA', 'Tüy'], ['#9AACBF', 'Sırt'], ['#2B2B3A', 'Kontur'], ['#F2C23B', 'Gaga'], ['#D9643A', 'Benek'], ['#F2B33B', 'Bacak'], ['#C8803A', 'Simit'], ['#FBF2D0', 'Susam']]]];
  let g = `<rect width="${PW}" height="${PH}" fill="#F2E6D0"/><text x="60" y="96" font-family="${FONT_D}" font-size="60" fill="#1F3A5F">Renk senaryosu ve paletler</text>
    <text x="60" y="136" font-family="${FONT_B}" font-size="22" fill="#4C6280">Martı: Istanbul Flight · Modern Kartpostal · arka plan katmanları gri tonlamalı teslim edilir, bu renkler kodda uygulanır</text>`;
  phases.forEach(([t, cols], r) => {
    const y = 190 + r * 160;
    g += `<text x="60" y="${y + 24}" font-family="${FONT_S}" font-size="22" letter-spacing="2" fill="#D9643A">${t}</text>`;
    cols.forEach(([c, n], i) => {
      const x = 60 + i * 212;
      g += `<rect x="${x}" y="${y + 40}" width="196" height="70" rx="8" fill="${c}" stroke="#2B2B3A" stroke-opacity=".25"/>
        <text x="${x}" y="${y + 134}" font-family="${FONT_S}" font-size="17" fill="#1F3A5F">${c}</text>
        <text x="${x + 84}" y="${y + 134}" font-family="${FONT_B}" font-size="15" fill="#4C6280">${n}</text>`;
    });
  });
  g += `<rect width="${PW}" height="${PH}" filter="url(#grain)" opacity=".3"/>`;
  return svgDoc(g, PW, PH);
}

if (require.main === module) {
const files = {
  'concepts/concept_A_safak_halic.svg': conceptA(),
  'concepts/concept_B_gunbatimi_kizkulesi.svg': conceptB(),
  'concepts/concept_C_gece_bogaz_koprusu.svg': conceptC(),
  'character/simit_character_sheet.svg': sheet(),
  'palette/palette_sheet.svg': palette(),
};
for (const [p, s] of Object.entries(files)) {
  const fp = path.join(OUT, p);
  fs.mkdirSync(path.dirname(fp), { recursive: true });
  fs.writeFileSync(fp, s, 'utf8');
  console.log('yazıldı', fp, s.length);
}
}

module.exports = { simit, simitFront, galata, kizKulesi, suleymaniye, peninsulaFar, minaret, dome, CP, defs };

// Game Center başarım görselleri (Phase 2.4, docs/16): 1024×1024 PNG, saydamlıksız.
// Uygulamaya girmez; App Store Connect > Game Center > Achievements'a yüklenir.
//   node game_center.js <çıktı klasörü>   (varsayılan: docs/store/game_center/achievements)
// 64×64 pixel art madalyon, 16× en yakın komşu büyütme. Kuş, oyunun kendi sprite'ından (characters.js).
'use strict';
const path = require('path');
const { Canvas } = require('./lib');
const characters = require('./characters');

const C = {
  bg: '#1f3a5f', bgDark: '#162b47', rim: '#e8b04b', rimDark: '#a8742a', rimLight: '#ffe08a',
  paper: '#fbf7ee', ink: '#22202c',
};

// 12×12 bitmapler ('#' = piksel): effects.js ikonlarıyla aynı dil
const GLYPHS = {
  flight: ['............', '.........##.', '........###.', '.##....###..', '..###.###...', '...######...', '....####....', '...#####....', '..###..##...', '.##.........', '............', '############'],
  tower: ['.....##.....', '.....##.....', '....####....', '...######...', '...######...', '....#..#....', '....####....', '....#..#....', '....####....', '...######...', '...#.##.#...', '..########..'],
  bridge: ['.#........#.', '.#........#.', '###......###', '.##.....##..', '.#.#...#.#..', '.#..#.#..#..', '############', '.#........#.', '.#........#.', '.#........#.', '............', '~~~~~~~~~~~~'],
  fortress: ['#.#......#.#', '###......###', '###.#..#.###', '###.####.###', '############', '############', '###.####.###', '############', '#####..#####', '#####..#####', '############', '............'],
  bolt: ['......###...', '.....###....', '....###.....', '...###......', '..########..', '.########...', '.....###....', '....###.....', '...###......', '..##........', '.#..........', '............'],
  sunset: ['.....##.....', '.#...##...#.', '..#......#..', '....####....', '...######...', '.##########.', '............', '############', '............', '..########..', '............', '....####....'],
  trophy: ['############', '############', '.##########.', '#.########.#', '#.########.#', '.#.######.#.', '...######...', '....####....', '.....##.....', '.....##.....', '...######...', '..########..'],
};

const ACHIEVEMENTS = [
  { id: 'first_flap', glyph: 'flight', tint: '#7fd3d6' },
  { id: 'galata_explorer', glyph: 'tower', tint: '#f0c27a' },
  { id: 'simit_hunter', simit: true, tint: '#f4c07a' },
  { id: 'loyal_gull', bird: true, tint: '#fbf7ee' },
  { id: 'bosphorus_traveler', glyph: 'bridge', tint: '#f08a5d' },
  { id: 'near_miss_master', glyph: 'bolt', tint: '#ffe08a' },
  { id: 'daily_wanderer', glyph: 'sunset', tint: '#ffb07a' },
  { id: 'night_flight', glyph: 'fortress', tint: '#c3c9e3', night: true },
  { id: 'istanbul_conqueror', glyph: 'trophy', tint: '#ffe08a', gold: true },
];

function medal(a) {
  const c = new Canvas(64, 64);
  c.rect(0, 0, 64, 64, C.bgDark);
  // madalyon: altın kenar (ışık sol üstten), lacivert iç
  c.ellipse(32, 32, 29, 29, (nx, ny) => (nx + ny < -0.6 ? C.rimLight : nx + ny > 0.7 ? C.rimDark : C.rim));
  c.ellipse(32, 32, 25, 25, (nx, ny) => (ny > 0.55 ? C.bgDark : a.gold ? '#2b3a68' : C.bg));
  // kenarda 8 perçin
  for (let k = 0; k < 8; k++) {
    const t = (k / 8) * Math.PI * 2;
    c.set(Math.round(32 + Math.cos(t) * 27), Math.round(32 + Math.sin(t) * 27), C.paper);
  }
  if (a.night) for (const [x, y] of [[20, 15], [44, 18], [16, 26], [47, 28]]) c.set(x, y, '#fff4c2');
  if (a.night) c.ellipse(42, 17, 3, 3, '#fff4c2');
  if (a.bird) {
    const f = characters.frame(characters.FRAMES[6]);
    c.blit(f, 32 - 24, 32 - 22);
  } else if (a.simit) {
    const rx = 13, ry = 11;
    c.ellipse(32, 33, rx, ry, (nx, ny) => {
      const d = nx * nx + ny * ny, inner = d < 0.18;
      if (inner) return null;
      return ny < -0.3 ? '#f4c07a' : ny > 0.45 ? '#9a5c26' : '#d08a40';
    });
    for (const [dx, dy] of [[-8, -5], [0, -9], [8, -5], [10, 3], [-10, 3], [0, 8]]) c.set(32 + dx, 33 + dy, '#fff4d6');
  } else {
    const g = GLYPHS[a.glyph];
    const k = 3, ox = 32 - 18, oy = 32 - 18;
    g.forEach((row, y) => [...row].forEach((ch, x) => {
      if (ch === '#') c.rect(ox + x * k, oy + y * k, k, k, a.tint);
      if (ch === '~' && (x + y) % 2 === 0) c.rect(ox + x * k, oy + y * k + 1, k, 1, '#5b9cc2');
    }));
    // gölge: sağ alt 1 px koyu kenar
    g.forEach((row, y) => [...row].forEach((ch, x) => {
      if (ch === '#' && (row[x + 1] !== '#')) c.rect(ox + x * k + k, oy + y * k + 1, 1, k, C.ink, 120);
    }));
  }
  return c;
}

function build(outDir) {
  return ACHIEVEMENTS.map((a) => medal(a).scaled(16).save(path.join(outDir, `istanbul_flight_${a.id}.png`)));
}

if (require.main === module) {
  const out = process.argv[2] || path.join(__dirname, '../../../docs/store/game_center/achievements');
  console.log(build(out).length + ' görsel → ' + out);
}

module.exports = { build, medal, ACHIEVEMENTS };

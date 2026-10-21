// Bölge paletleri: art/_source/pixel/reference_palettes.json ölçümlerine dayanır.
// Ölçek: 1 piksel = 4 dünya birimi. Dünya 1920 → 480 px, ufuk 1190 → 297.5 px.
'use strict';
const HORIZON = 298; // ufuk (px) — su bu satırdan başlar
const SCREEN_H = 480;

const ZONES = {
  halic: {
    name: 'Haliç · Şafak',
    sky: [[0, '#2655ab'], [0.16, '#3c64b1'], [0.32, '#5d72b4'], [0.46, '#867cae'], [0.58, '#a483a6'], [0.7, '#c19290'], [0.82, '#e8a88b'], [0.92, '#f2bd90'], [1, '#fbca91']],
    sun: { kind: 'sun', x: 0.74, y: 238, core: '#fff2cc', mid: '#fbd59a', halo: '#f6b386', r: 14 },
    clouds: { light: '#fbcfb0', mid: '#e3a3a0', shade: '#9a86b0', deep: '#76709f' },
    distant: { far: '#9d8bb0', near: '#857699', rim: '#f6c39c', lit: null },
    walls: ['#c78360', '#d9a07a', '#b86a52', '#e6b382', '#c99a8a', '#a8755e', '#d8b494'],
    roof: '#a8483a', roofShade: '#6e3a3a', shade: '#565267', ink: '#2c2734', glass: '#3d3841', lit: '#ffd9a0', litChance: 0.22, sunSide: 1,
    trees: ['#3f4a4a', '#56605a'],
    water: [[0, '#8f8fb6'], [0.08, '#707599'], [0.3, '#5d6688'], [0.6, '#4c576e'], [1, '#38394f']],
    waterHi: ['#f2bd90', '#fbd7ad'], reflect: '#f6c39c', fog: '#e9c9c0',
  },
  galata: {
    name: 'Galata · Gündüz',
    sky: [[0, '#0264c9'], [0.2, '#1b70cc'], [0.42, '#3782ce'], [0.62, '#5796d6'], [0.78, '#7aa7d6'], [0.9, '#9fb8d6'], [1, '#bccbdc']],
    sun: { kind: 'sun', x: 0.82, y: 70, core: '#fffbe8', mid: '#fff1c0', halo: '#cfe2f6', r: 12 },
    clouds: { light: '#ffffff', mid: '#e8eef8', shade: '#bac6da', deep: '#90a7c8' },
    distant: { far: '#a7b6cc', near: '#8ea2bc', rim: '#dfe8f2', lit: null },
    walls: ['#e4d2c1', '#e3ab7a', '#c76139', '#efdcb8', '#d69a7c', '#b8b0a4', '#f0c896', '#9fb4c4'],
    roof: '#b9472c', roofShade: '#843c27', shade: '#5c5866', ink: '#1b1f2a', glass: '#1e2a3a', lit: null, litChance: 0, sunSide: -1,
    trees: ['#3e6a3c', '#5b8a4a'],
    water: [[0, '#5f97c7'], [0.06, '#2f75b0'], [0.3, '#1c6295'], [0.6, '#145287'], [1, '#093e6a']],
    waterHi: ['#cfe4f7', '#ffffff'], reflect: '#bcd4ea', fog: null,
  },
  kizkulesi: {
    name: 'Kız Kulesi · Gün batımı',
    sky: [[0, '#5a2a5a'], [0.14, '#8a3a64'], [0.3, '#b04b6a'], [0.46, '#d65962'], [0.6, '#ef6b56'], [0.74, '#f7834a'], [0.88, '#fb9a42'], [1, '#fcb352']],
    sun: { kind: 'sun', x: 0.3, y: 232, core: '#fff1c4', mid: '#ffd479', halo: '#fca24a', r: 18 },
    clouds: { light: '#ffb070', mid: '#f07a5a', shade: '#b04f6a', deep: '#7a3a62' },
    distant: { far: '#a34c66', near: '#83405b', rim: '#ff9a55', lit: '#ffc070' },
    walls: ['#6a3446', '#5e3044', '#73394a', '#552b40'],
    roof: '#4a2438', roofShade: '#3a1c30', shade: '#3a1f36', ink: '#1e0e1c', glass: '#2a1428', lit: '#ffc46b', litChance: 0.35, sunSide: -1, rimLight: '#ff8f52',
    trees: ['#3a1e34', '#4a2840'],
    water: [[0, '#d98a6a'], [0.06, '#ad6a55'], [0.28, '#8d564f'], [0.6, '#623040'], [1, '#3a2348']],
    waterHi: ['#ffc070', '#fff0c0'], reflect: '#ffb050', fog: null,
  },
  kopru: {
    name: 'Boğaz Köprüsü · Akşam',
    sky: [[0, '#00205f'], [0.22, '#042f78'], [0.42, '#133684'], [0.58, '#2b377d'], [0.72, '#4a3c72'], [0.86, '#6b4f78'], [1, '#8a5a72']],
    sun: { kind: 'moon', x: 0.8, y: 64, core: '#f4ead6', mid: '#d9cdb8', halo: '#4a5a9a', r: 10 },
    clouds: { light: '#6a5f96', mid: '#544a80', shade: '#3a3570', deep: '#2b2d62' },
    distant: { far: '#3a3a6e', near: '#2c2b58', rim: '#7d6a96', lit: '#ffcf7a' },
    walls: ['#7b7aa8', '#8d83a8', '#6f6c98', '#9a8fae', '#7f6f90'],
    roof: '#4a3560', roofShade: '#33264a', shade: '#2d2b52', ink: '#120f22', glass: '#1b1d3c', lit: '#ffd27a', litChance: 0.55, sunSide: 1,
    trees: ['#1c2440', '#26304e'],
    water: [[0, '#4a4f86'], [0.06, '#2b3a72'], [0.3, '#1b2a5a'], [0.6, '#10204a'], [1, '#04163b']],
    waterHi: ['#ffd27a', '#8fb4ff'], reflect: '#ffcf7a', fog: null,
  },
  rumeli: {
    name: 'Rumeli Hisarı · Gece',
    sky: [[0, '#000a2c'], [0.3, '#041440'], [0.55, '#0b1d4b'], [0.75, '#142553'], [0.9, '#1f2a50'], [1, '#2a2d4c']],
    sun: { kind: 'moon', x: 0.78, y: 58, core: '#fff3dc', mid: '#eed7bf', halo: '#24356e', r: 11 },
    clouds: { light: '#2c3a6a', mid: '#22305a', shade: '#18244a', deep: '#101a3c' },
    distant: { far: '#0f1c46', near: '#0a1438', rim: '#26386e', lit: '#e8a050' },
    walls: ['#4a3f50', '#3e3448', '#56485a'],
    roof: '#2a2234', roofShade: '#1c1626', shade: '#1a1626', ink: '#06060c', glass: '#120e1a', lit: '#f0a048', litChance: 0.45, sunSide: 1,
    trees: ['#0e1a1e', '#16262a', '#1e3230'],
    water: [[0, '#1a2a5a'], [0.06, '#0a2256'], [0.3, '#031a4a'], [0.6, '#020f32'], [1, '#020a20']],
    waterHi: ['#f0a048', '#fff0d0'], reflect: '#e88432', fog: '#24305e',
  },
};

module.exports = { ZONES, HORIZON, SCREEN_H };

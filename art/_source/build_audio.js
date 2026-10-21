// Martı: Istanbul Flight — prosedürel ses sentezi (özgün, telifsiz; dış kaynak kullanılmaz).
// Çıktı: 22.05 kHz, mono, 16-bit WAV. Kullanım: node build_audio.js <çıktı klasörü>
//
// Teknikler: ADSR zarfları, sinüs/testere osilatörleri, filtrelenmiş gürültü, Karplus-Strong telli çalgı
// (kanun/saz benzeri), basit geri beslemeli yankı. Müzik: Hicaz makamı (Re: Re Mi♭ Fa♯ Sol La Si♭ Do Re).
const fs = require('fs');
const path = require('path');
const OUT = process.argv[2];
const SR = 22050;

// ---------------- temel araçlar ----------------
let seed = 12345;
const rnd = () => ((seed = (seed * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff);
const noise = () => rnd() * 2 - 1;
const buf = sec => new Float32Array(Math.round(sec * SR));
const midi = n => 440 * Math.pow(2, (n - 69) / 12);

function env(i, n, a, d, s, r) { // a,d,r saniye; s seviye; n toplam örnek
  const t = i / SR, len = n / SR;
  if (t < a) return t / a;
  if (t < a + d) return 1 - (1 - s) * (t - a) / d;
  if (t > len - r) return Math.max(0, s * (len - t) / r);
  return s;
}
function lowpass(x, cutoffFn) { // tek kutuplu, kesim frekansı örnek başına değişebilir
  let y = 0;
  for (let i = 0; i < x.length; i++) {
    const fc = typeof cutoffFn === 'function' ? cutoffFn(i) : cutoffFn;
    const a = 1 - Math.exp(-2 * Math.PI * fc / SR);
    y += a * (x[i] - y); x[i] = y;
  }
  return x;
}
function highpass(x, fc) { const lp = Float32Array.from(x); lowpass(lp, fc); for (let i = 0; i < x.length; i++) x[i] -= lp[i]; return x; }
function mixInto(dst, src, at = 0, gain = 1, wrap = false) {
  for (let i = 0; i < src.length; i++) {
    let j = at + i;
    if (wrap) j %= dst.length; else if (j >= dst.length) break;
    dst[j] += src[i] * gain;
  }
}
function reverb(x, { delay = 0.11, fb = 0.45, mix = 0.3, wrap = false } = {}) {
  const out = Float32Array.from(x);
  const taps = [delay, delay * 1.37, delay * 1.71];
  for (const d of taps) {
    const D = Math.round(d * SR); const tmp = new Float32Array(x.length);
    for (let i = 0; i < x.length; i++) {
      const j = i - D; const prev = j >= 0 ? tmp[j] : (wrap ? tmp[x.length + j] || 0 : 0);
      tmp[i] = x[i] + prev * fb;
    }
    for (let i = 0; i < x.length; i++) out[i] += tmp[i] * mix / taps.length;
  }
  return out;
}
function normalize(x, peak = 0.89) { let m = 0; for (const v of x) m = Math.max(m, Math.abs(v)); if (m > 0) for (let i = 0; i < x.length; i++) x[i] *= peak / m; return x; }
function fadeEdges(x, ms = 5) { const n = Math.round(ms / 1000 * SR); for (let i = 0; i < n && i < x.length; i++) { x[i] *= i / n; x[x.length - 1 - i] *= i / n; } return x; }

// Karplus-Strong: telli çalgı (kanun/saz benzeri parlak, hızlı sönen)
function pluck(freq, sec, { bright = 0.5, decay = 0.996, gain = 1 } = {}) {
  const x = buf(sec); const N = Math.max(2, Math.round(SR / freq));
  const line = new Float32Array(N); for (let i = 0; i < N; i++) line[i] = noise();
  let idx = 0, last = 0;
  for (let i = 0; i < x.length; i++) {
    const cur = line[idx];
    const avg = (cur + last) * 0.5 * decay;
    line[idx] = bright * cur * decay + (1 - bright) * avg;
    last = cur; x[i] = cur * gain; idx = (idx + 1) % N;
  }
  return fadeEdges(x, 3);
}
function tone(freq, sec, { type = 'sine', a = 0.005, d = 0.08, s = 0.4, r = 0.1, vib = 0, vibRate = 5, glideTo = null, harm = [1] } = {}) {
  const x = buf(sec); let ph = 0;
  for (let i = 0; i < x.length; i++) {
    const t = i / x.length;
    let f = glideTo ? freq + (glideTo - freq) * t : freq;
    f *= 1 + vib * Math.sin(2 * Math.PI * vibRate * i / SR);
    ph += 2 * Math.PI * f / SR;
    let v = 0;
    if (type === 'saw') { for (let h = 1; h <= 12; h++) v += Math.sin(ph * h) / h; v *= 0.6; }
    else harm.forEach((g, h) => { v += Math.sin(ph * (h + 1)) * g; });
    x[i] = v * env(i, x.length, a, d, s, r);
  }
  return x;
}
function noiseBurst(sec, { a = 0.002, d = 0.05, s = 0.2, r = 0.05, lp = 4000, hp = 0 } = {}) {
  const x = buf(sec); for (let i = 0; i < x.length; i++) x[i] = noise() * env(i, x.length, a, d, s, r);
  if (typeof lp === 'function' || lp) lowpass(x, lp); if (hp) highpass(x, hp); return x;
}

// ---------------- WAV ----------------
function writeWav(name, x) {
  const n = x.length, data = Buffer.alloc(44 + n * 2);
  data.write('RIFF', 0); data.writeUInt32LE(36 + n * 2, 4); data.write('WAVE', 8); data.write('fmt ', 12);
  data.writeUInt32LE(16, 16); data.writeUInt16LE(1, 20); data.writeUInt16LE(1, 22); data.writeUInt32LE(SR, 24);
  data.writeUInt32LE(SR * 2, 28); data.writeUInt16LE(2, 32); data.writeUInt16LE(16, 34); data.write('data', 36); data.writeUInt32LE(n * 2, 40);
  let peak = 0, sum = 0, clip = 0;
  for (let i = 0; i < n; i++) {
    const v = Math.max(-1, Math.min(1, x[i])); if (Math.abs(x[i]) > 1) clip++;
    if (!Number.isFinite(x[i])) throw new Error(name + ': NaN');
    peak = Math.max(peak, Math.abs(v)); sum += v * v; data.writeInt16LE(Math.round(v * 32767), 44 + i * 2);
  }
  fs.mkdirSync(OUT, { recursive: true });
  fs.writeFileSync(path.join(OUT, name), data);
  return { name, sec: +(n / SR).toFixed(2), peak: +peak.toFixed(3), rms: +Math.sqrt(sum / n).toFixed(3), clip, kb: Math.round(data.length / 1024) };
}
const report = [];

// ================= OYUN SESLERİ =================
// Kanat: kısa, yumuşak "fıs" (yüksekten alçağa süpürülen filtreli gürültü)
{ const n = Math.round(0.13 * SR); const x = noiseBurst(0.13, { a: 0.01, d: 0.06, s: 0.25, r: 0.05, lp: i => 2600 - 1900 * i / n, hp: 300 });
  report.push(writeWav('sfx_flap.wav', normalize(x, 0.5))); }
// Simit toplama: parlak iki notalı çan (Mi6 → Si6) + ince parıltı
{ const x = buf(0.42);
  mixInto(x, tone(midi(88), 0.2, { a: 0.002, d: 0.08, s: 0.2, r: 0.1, harm: [1, 0, 0.3, 0, 0.12] }), 0, 0.8);
  mixInto(x, tone(midi(95), 0.32, { a: 0.002, d: 0.1, s: 0.2, r: 0.18, harm: [1, 0, 0.3, 0, 0.12] }), Math.round(0.07 * SR), 0.9);
  mixInto(x, noiseBurst(0.12, { lp: 9000, hp: 5000, d: 0.04, s: 0.1 }), Math.round(0.07 * SR), 0.15);
  report.push(writeWav('sfx_collect.wav', normalize(reverb(x, { delay: 0.06, fb: 0.3, mix: 0.25 }), 0.7))); }
// Kıl payı: yükselen rüzgâr + yüksek tel teli (La6)
{ const n = Math.round(0.5 * SR); const x = noiseBurst(0.5, { a: 0.18, d: 0.1, s: 0.6, r: 0.18, lp: i => 400 + 4200 * i / n, hp: 200 });
  mixInto(x, pluck(midi(93), 0.3, { bright: 0.7, decay: 0.995 }), Math.round(0.22 * SR), 0.9);
  report.push(writeWav('sfx_near_miss.wav', normalize(x, 0.7))); }
// Çarpışma: perde düşen tok darbe + boğuk gürültü
{ const x = tone(130, 0.45, { a: 0.001, d: 0.12, s: 0.2, r: 0.25, glideTo: 45, harm: [1, 0.4, 0.15] });
  mixInto(x, noiseBurst(0.25, { a: 0.001, d: 0.06, s: 0.15, r: 0.15, lp: 1400 }), 0, 0.8);
  report.push(writeWav('sfx_crash.wav', normalize(x, 0.85))); }
// Suya düşme: köpüklü sıçrama + birkaç kabarcık
{ const x = noiseBurst(0.6, { a: 0.003, d: 0.12, s: 0.25, r: 0.4, lp: i => 3000 * Math.exp(-i / SR * 4) + 300 });
  for (let k = 0; k < 4; k++) mixInto(x, tone(500 + k * 160, 0.06, { a: 0.002, d: 0.03, s: 0.1, r: 0.02, glideTo: 900 + k * 200 }), Math.round((0.12 + k * 0.07) * SR), 0.25);
  report.push(writeWav('sfx_splash.wav', normalize(x, 0.6))); }
// Buton: yumuşak tık
{ const x = tone(1100, 0.06, { a: 0.001, d: 0.02, s: 0.05, r: 0.03, harm: [1, 0.2] });
  mixInto(x, noiseBurst(0.02, { lp: 6000, d: 0.01, s: 0.05 }), 0, 0.3);
  report.push(writeWav('sfx_button.wav', normalize(x, 0.45))); }
// Bölgeye giriş: iki tel notası (Re5 → La5)
{ const x = buf(0.9); mixInto(x, pluck(midi(74), 0.6, { bright: 0.5 }), 0, 0.8); mixInto(x, pluck(midi(81), 0.7, { bright: 0.5 }), Math.round(0.14 * SR), 0.8);
  report.push(writeWav('sfx_zone.wav', normalize(reverb(x), 0.6))); }
// Yeni rekor: Hicaz arpeji (Re Mi♭ Fa♯ La Re) + parıltı
{ const notes = [62, 63, 66, 69, 74, 78]; const x = buf(1.6);
  notes.forEach((m, k) => mixInto(x, pluck(midi(m + 12), 0.9, { bright: 0.55, decay: 0.997 }), Math.round(k * 0.09 * SR), 0.7));
  mixInto(x, tone(midi(86), 0.9, { a: 0.01, d: 0.3, s: 0.3, r: 0.4, harm: [1, 0, 0.2] }), Math.round(0.5 * SR), 0.35);
  report.push(writeWav('sfx_record.wav', normalize(reverb(x, { mix: 0.35 }), 0.75))); }

// ================= ORTAM =================
// Dalgalar (8 sn, dikişsiz döngü): kabaran ve çekilen filtreli gürültü
function loopNoise(sec, shape) {
  const n = Math.round(sec * SR), x = new Float32Array(n);
  let y1 = 0, y2 = 0;
  // İki tur üret, ikinci turu al → filtre durumu döngü başında sürekli
  for (let pass = 0; pass < 2; pass++) for (let i = 0; i < n; i++) {
    const { gain, cut } = shape(i / n);
    const a = 1 - Math.exp(-2 * Math.PI * cut / SR);
    y1 += a * (noise() - y1); y2 += a * (y1 - y2);
    if (pass === 1) x[i] = y2 * gain;
  }
  // uçları yumuşak çapraz geçişle birleştir
  const xf = Math.round(0.25 * SR);
  for (let i = 0; i < xf; i++) { const t = i / xf; const a = x[i], b = x[n - xf + i]; x[i] = a * t + b * (1 - t); }
  return x.subarray(0, n - xf);
}
{ const x = loopNoise(8.25, t => { const sw = 0.5 - 0.5 * Math.cos(2 * Math.PI * t * 2); return { gain: 0.35 + 0.65 * sw, cut: 300 + 900 * sw }; });
  report.push(writeWav('amb_waves.wav', normalize(x, 0.5))); }
{ const x = loopNoise(8.25, t => { const g = 0.6 + 0.4 * Math.sin(2 * Math.PI * t * 3) * Math.sin(2 * Math.PI * t); return { gain: g, cut: 500 + 700 * (0.5 + 0.5 * Math.sin(2 * Math.PI * t * 2)) }; });
  highpass(x, 200); report.push(writeWav('amb_wind.wav', normalize(x, 0.4))); }
// Martı çığlığı (tek seferlik): perdesi kayan, titrek iki "kyow"
{ const x = buf(1.1);
  for (const [at, f0, f1] of [[0, 1650, 1050], [0.42, 1500, 980]]) {
    const c = tone(f0, 0.34, { a: 0.02, d: 0.05, s: 0.7, r: 0.15, glideTo: f1, vib: 0.03, vibRate: 28, harm: [1, 0.5, 0.25, 0.12] });
    const nz = noiseBurst(0.34, { a: 0.02, d: 0.1, s: 0.3, r: 0.15, lp: 5000, hp: 1500 });
    mixInto(c, nz, 0, 0.25); mixInto(x, c, Math.round(at * SR), 0.8);
  }
  report.push(writeWav('amb_gull.wav', normalize(reverb(x, { delay: 0.17, fb: 0.35, mix: 0.3 }), 0.55))); }
// Uzak vapur düdüğü: alçak testere akoru (La2 + Do♯3), yavaş atak, titreşim, uzak yankı
{ const x = buf(3.2);
  for (const m of [45, 49]) mixInto(x, tone(midi(m), 3.2, { type: 'saw', a: 0.35, d: 0.3, s: 0.8, r: 0.9, vib: 0.004, vibRate: 4.5 }), 0, 0.5);
  lowpass(x, 700); report.push(writeWav('amb_ferry_horn.wav', normalize(reverb(x, { delay: 0.23, fb: 0.5, mix: 0.45 }), 0.6))); }

// ================= MÜZİK (Hicaz) =================
// Dikişsiz döngü: iki tur üretilir, kuyruklar dolanır (wrap) → döngü başı ile sonu sürekli.
const HICAZ = [62, 63, 66, 67, 69, 70, 72, 74]; // Re4 Mi♭ Fa♯ Sol La Si♭ Do Re5
function percussion(x, bpm, pattern, gain) { // 'D' düm (tok), 'T' tek (parlak), '.' sus
  const step = 60 / bpm / 2; // sekizlik
  const total = Math.round(x.length / (step * SR));
  for (let s = 0; s < total; s++) {
    const c = pattern[s % pattern.length], at = Math.round(s * step * SR);
    if (c === 'D') mixInto(x, tone(95, 0.3, { a: 0.002, d: 0.08, s: 0.1, r: 0.15, glideTo: 60, harm: [1, 0.3] }), at, gain, true);
    if (c === 'T') { const t = noiseBurst(0.09, { a: 0.001, d: 0.03, s: 0.08, r: 0.04, lp: 7000, hp: 1800 }); mixInto(t, tone(620, 0.05, { a: 0.001, d: 0.02, s: 0.05, r: 0.02 }), 0, 0.4); mixInto(x, t, at, gain * 0.7, true); }
    if (c === 't') mixInto(x, noiseBurst(0.05, { a: 0.001, d: 0.02, s: 0.05, r: 0.02, lp: 8000, hp: 3000 }), at, gain * 0.35, true);
  }
}
function drone(x, notes, gain) { for (const m of notes) { const d = tone(midi(m), x.length / SR, { a: 0.5, d: 0.5, s: 0.9, r: 0.01, harm: [1, 0.3, 0.1], vib: 0.002, vibRate: 0.3 }); for (let i = 0; i < x.length; i++) x[i] += d[i] * gain; } }
function melody(x, bpm, line, gain, octave = 0) { // line: [derece|null, sekizlik süre]
  const step = 60 / bpm / 2; let t = 0;
  for (const [deg, len] of line) {
    if (deg !== null) {
      const m = HICAZ[((deg % 7) + 7) % 7] + 12 * Math.floor(deg / 7) + octave;
      mixInto(x, pluck(midi(m), Math.max(0.5, len * step + 0.4), { bright: 0.45, decay: 0.9975 }), Math.round(t * SR), gain, true);
      if (len >= 2) mixInto(x, pluck(midi(m), 0.4, { bright: 0.4, decay: 0.995 }), Math.round((t + step) * SR), gain * 0.45, true); // kanun tarzı tekrar
    }
    t += len * step;
  }
}
function song(name, bpm, bars, line, perc, { droneNotes = [38, 45], droneGain = 0.06, melGain = 0.5, percGain = 0.5, octave = 0 } = {}) {
  const sec = bars * 4 * 60 / bpm; const x = buf(sec);
  drone(x, droneNotes, droneGain);
  melody(x, bpm, line, melGain, octave);
  percussion(x, bpm, perc, percGain);
  const wet = reverb(x, { delay: 0.13, fb: 0.4, mix: 0.25, wrap: true });
  return report.push(writeWav(name, normalize(fadeEdges(wet, 2), 0.8)));
}
// Ana menü: sakin, 84 bpm, 8 ölçü — Hicaz seyri (Re'den La'ya çıkıp Re'ye dönüş)
song('music_menu.wav', 84, 8, [
  [0, 2], [1, 1], [2, 1], [3, 2], [4, 2], [4, 1], [5, 1], [4, 1], [3, 1], [2, 4],
  [4, 2], [5, 1], [6, 1], [7, 2], [6, 1], [5, 1], [4, 2], [3, 2], [2, 2], [1, 2],
  [2, 1], [3, 1], [4, 2], [3, 1], [2, 1], [1, 2], [0, 6], [null, 2],
], 'D..T..T.D.D.T...', { percGain: 0.32, melGain: 0.55 });
// Oyun içi: hafif, 112 bpm, 8 ölçü; melodi seyrek ve alçak → efektleri bastırmaz
song('music_game.wav', 112, 8, [
  [0, 2], [null, 2], [2, 1], [3, 1], [4, 2], [null, 4],
  [4, 1], [5, 1], [4, 1], [3, 1], [2, 2], [null, 2], [1, 2], [0, 2], [null, 4],
  [4, 2], [null, 2], [6, 1], [7, 1], [6, 2], [null, 4],
  [5, 1], [4, 1], [3, 1], [2, 1], [1, 2], [null, 2], [0, 4], [null, 4],
], 'D.tTD.T.D.tTD.Tt', { percGain: 0.42, melGain: 0.38, droneGain: 0.05, octave: -12 });
// Oyun sonu: kısa inen ezgi (tek seferlik)
{ const bpm = 92, step = 60 / bpm / 2; const x = buf(3.4);
  [[4, 0], [3, 1], [2, 2], [1, 3], [0, 4.5]].forEach(([deg, at]) => mixInto(x, pluck(midi(HICAZ[deg]), 1.6, { bright: 0.45, decay: 0.998 }), Math.round(at * step * SR), 0.7));
  drone(x, [38], 0.05); fadeEdges(x, 400);
  report.push(writeWav('music_gameover.wav', normalize(reverb(x, { mix: 0.35 }), 0.7))); }

console.table(report);
console.log('Toplam KB:', report.reduce((s, r) => s + r.kb, 0));

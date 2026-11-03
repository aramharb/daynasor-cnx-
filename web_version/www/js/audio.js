// Tiny synthesized sound effects (no audio files needed, works offline).
let ac = null;
let enabled = true;

function ctx() {
  if (!ac) {
    const AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return null;
    ac = new AC();
  }
  if (ac.state === 'suspended') ac.resume();
  return ac;
}

function tone({ f = 440, to = null, dur = 0.1, type = 'square', vol = 0.06, delay = 0 }) {
  const a = ctx();
  if (!a) return;
  const t0 = a.currentTime + delay;
  const o = a.createOscillator();
  const g = a.createGain();
  o.type = type;
  o.frequency.setValueAtTime(f, t0);
  if (to) o.frequency.exponentialRampToValueAtTime(to, t0 + dur);
  g.gain.setValueAtTime(vol, t0);
  g.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
  o.connect(g).connect(a.destination);
  o.start(t0);
  o.stop(t0 + dur + 0.02);
}

function noise(dur = 0.25, vol = 0.12) {
  const a = ctx();
  if (!a) return;
  const len = Math.floor(a.sampleRate * dur);
  const buf = a.createBuffer(1, len, a.sampleRate);
  const d = buf.getChannelData(0);
  for (let i = 0; i < len; i++) d[i] = (Math.random() * 2 - 1) * (1 - i / len);
  const src = a.createBufferSource();
  const g = a.createGain();
  g.gain.value = vol;
  src.buffer = buf;
  src.connect(g).connect(a.destination);
  src.start();
}

const SOUNDS = {
  // classic = plain beeps, colorful = juicier
  jump: (c) => c ? tone({ f: 380, to: 760, dur: 0.12, type: 'triangle', vol: 0.08 }) : tone({ f: 600, dur: 0.06 }),
  point: (c) => { tone({ f: 880, dur: 0.07, type: c ? 'triangle' : 'square' }); tone({ f: 1320, dur: 0.1, delay: 0.08, type: c ? 'triangle' : 'square' }); },
  hit: (c) => { tone({ f: 200, to: 60, dur: 0.3, type: 'sawtooth', vol: 0.08 }); if (c) noise(0.3, 0.1); },
  coin: () => { tone({ f: 988, dur: 0.05, type: 'square', vol: 0.04 }); tone({ f: 1319, dur: 0.12, delay: 0.05, type: 'square', vol: 0.04 }); },
  power: () => [523, 659, 784, 1047].forEach((f, i) => tone({ f, dur: 0.1, delay: i * 0.06, type: 'triangle', vol: 0.07 })),
  ability: () => { tone({ f: 220, to: 880, dur: 0.25, type: 'sawtooth', vol: 0.05 }); noise(0.2, 0.05); },
  smash: () => noise(0.18, 0.12),
  bonus: () => tone({ f: 700, to: 1400, dur: 0.15, type: 'square', vol: 0.05 }),
  egg: () => [392, 494, 587, 784, 988].forEach((f, i) => tone({ f, dur: 0.14, delay: i * 0.08, type: 'triangle', vol: 0.08 })),
  crack: () => noise(0.08, 0.15),
  super: () => {
    [262, 330, 392, 523, 659, 784, 1047].forEach((f, i) => tone({ f, dur: 0.16, delay: i * 0.05, type: 'sawtooth', vol: 0.05 }));
    tone({ f: 80, to: 40, dur: 0.6, type: 'sine', vol: 0.2 });
    noise(0.4, 0.08);
  },
  zap: () => { noise(0.12, 0.14); tone({ f: 1800, to: 200, dur: 0.15, type: 'sawtooth', vol: 0.04 }); },
  splash: () => { noise(0.2, 0.08); tone({ f: 500, to: 150, dur: 0.18, type: 'sine', vol: 0.06 }); },
  chomp: () => { tone({ f: 300, to: 120, dur: 0.08, type: 'square', vol: 0.06 }); tone({ f: 260, to: 100, dur: 0.08, delay: 0.09, type: 'square', vol: 0.06 }); },
  online: () => [262, 330, 392, 523, 659, 784].forEach((f, i) => tone({ f, dur: 0.12, delay: i * 0.05, type: 'triangle', vol: 0.06 })),
  offline: () => [523, 392, 262].forEach((f, i) => tone({ f, dur: 0.12, delay: i * 0.08, type: 'square', vol: 0.04 })),
};

export const sfx = {
  setEnabled(v) { enabled = !!v; },
  unlock() { ctx(); },
  play(name, colorful = false) {
    if (!enabled) return;
    try { SOUNDS[name]?.(colorful); } catch { /* audio not available */ }
  },
};

export function vibrate(ms) {
  try { navigator.vibrate?.(ms); } catch { /* ignore */ }
}

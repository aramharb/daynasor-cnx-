// Persistent player progress (localStorage, works offline).
const KEY = 'dinoDash.save.v1';

const defaults = () => ({
  hiClassic: 0,
  hiColor: 0,
  coins: 0,
  unlocked: ['rex'],
  selected: 'rex',
  eggs: 0,
  lastEggAt: 0,
  runs: 0,
  sound: true,
  forceClassic: false,
});

let state = load();

function load() {
  try {
    const raw = JSON.parse(localStorage.getItem(KEY) || '{}');
    const s = { ...defaults(), ...raw };
    if (!Array.isArray(s.unlocked) || !s.unlocked.includes('rex')) s.unlocked = ['rex', ...(s.unlocked || [])];
    // v1 had a made-up "Neon Rex"; it became the real Brachiosaurus
    s.unlocked = [...new Set(s.unlocked.map((id) => (id === 'neon' ? 'brachio' : id)))];
    if (s.selected === 'neon') s.selected = 'brachio';
    return s;
  } catch {
    return defaults();
  }
}

function save() {
  try { localStorage.setItem(KEY, JSON.stringify(state)); } catch { /* storage unavailable */ }
}

export const store = {
  get: (k) => state[k],
  set(k, v) { state[k] = v; save(); },
  update(fn) { fn(state); save(); },
  reset() { state = defaults(); save(); },
};

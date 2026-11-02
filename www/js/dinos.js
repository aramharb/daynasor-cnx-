// Dinosaur roster + procedural pixel-art sprites.
// Every dino shares one hand-made base body; species features (plates, horns,
// sails, wings...) are drawn on top as pixel overlays.

export const SCALE = 2; // screen px per sprite pixel

export const RARITY = {
  common:    { label: 'Common',    color: '#7bd88f', weight: 50 },
  rare:      { label: 'Rare',      color: '#4fc3f7', weight: 30 },
  epic:      { label: 'Epic',      color: '#c77dff', weight: 15 },
  legendary: { label: 'Legendary', color: '#ffd166', weight: 5 },
};

export const DINOS = [
  {
    id: 'rex', name: 'Rexy', rarity: 'common',
    colors: { body: '#4caf50', dark: '#2e7d32', belly: '#c5e1a5', accent: '#1b5e20' },
    ability: { id: 'roar', name: 'Roar', cd: 12, desc: 'A mighty roar blasts away every obstacle in front of you.' },
    blurb: 'The original runner. Always there for you.',
  },
  {
    id: 'raptor', name: 'Zip', rarity: 'common',
    colors: { body: '#ff8a3d', dark: '#c4561a', belly: '#ffe0b2', accent: '#6d2c00' },
    ability: { id: 'dash', name: 'Dash', cd: 10, desc: 'Burst forward, invincible, smashing through anything.' },
    blurb: 'Fast, sneaky, a little bit chaotic.',
  },
  {
    id: 'stego', name: 'Plato', rarity: 'common',
    colors: { body: '#26a69a', dark: '#00796b', belly: '#b2dfdb', accent: '#ff7043' },
    ability: { id: 'shield', name: 'Plate Armor', cd: 14, desc: 'Grows a shield that absorbs one hit.' },
    blurb: 'Slow to anger, impossible to hurt.',
  },
  {
    id: 'pachy', name: 'Bonk', rarity: 'common',
    colors: { body: '#a1887f', dark: '#6d4c41', belly: '#efebe9', accent: '#ffca28' },
    ability: { id: 'superjump', name: 'Super Jump', cd: 9, desc: 'Launches sky-high and is invincible while rising.' },
    jumpMul: 1.05,
    blurb: 'Thick skull, big bounce.',
  },
  {
    id: 'tricera', name: 'Trike', rarity: 'rare',
    colors: { body: '#5c6bc0', dark: '#3949ab', belly: '#c5cae9', accent: '#ffb74d', horn: '#fff8e1' },
    ability: { id: 'charge', name: 'Charge', cd: 12, desc: 'Lowers its horns and rams through ground obstacles for 3s.' },
    blurb: 'Three horns. Zero patience.',
  },
  {
    id: 'parasaur', name: 'Echo', rarity: 'rare',
    colors: { body: '#ec407a', dark: '#ad1457', belly: '#f8bbd0', accent: '#7e57c2' },
    ability: { id: 'echo', name: 'Echo Call', cd: 14, desc: 'Its crest hums: coin magnet + double coins for 8s.' },
    blurb: 'Sings to coins. They listen.',
  },
  {
    id: 'ankylo', name: 'Tank', rarity: 'rare',
    colors: { body: '#8d6e63', dark: '#5d4037', belly: '#d7ccc8', accent: '#546e7a' },
    ability: { id: 'quake', name: 'Quake', cd: 16, desc: 'Tail-slams the ground, shattering every ground obstacle on screen.' },
    blurb: 'Walking fortress with a hammer tail.',
  },
  {
    id: 'ptero', name: 'Skye', rarity: 'epic',
    colors: { body: '#29b6f6', dark: '#0277bd', belly: '#e1f5fe', accent: '#ab47bc' },
    ability: { id: 'soar', name: 'Soar', cd: 12, desc: 'Takes flight for 3s, gliding over everything.' },
    passive: 'doubleJump',
    blurb: 'Passive: double jump. Technically not a dinosaur. Shh.',
  },
  {
    id: 'spino', name: 'Sail', rarity: 'epic',
    colors: { body: '#ef5350', dark: '#b71c1c', belly: '#ffcdd2', accent: '#ffa726' },
    ability: { id: 'warp', name: 'Time Warp', cd: 15, desc: 'Slows down the whole world for 4s.' },
    blurb: 'Its sail bends time. Probably.',
  },
  {
    id: 'neon', name: 'Neon Rex', rarity: 'legendary',
    colors: { body: '#ff00aa', dark: '#7a00ff', belly: '#00e5ff', accent: '#ffee00' },
    rainbow: true,
    ability: { id: 'hyper', name: 'Hyper Mode', cd: 18, desc: '5s of invincibility, magnet and double coins.' },
    passive: 'doubleJump',
    blurb: 'Passive: double jump. Way too cool for this world.',
  },
];

export const getDino = (id) => DINOS.find((d) => d.id === id) || DINOS[0];

// ---- Base sprites ---------------------------------------------------------
// B body, L belly, D dark (arm), W eye white, K pupil, M mouth
const STAND = [
  '..........BBBBBBB...',
  '.........BBBBBBBBB..',
  '.........BBBWWBBBBB.',
  '.........BBBWKBBBBB.',
  '.........BBBBBBBBBBB',
  '.........BBBBBBBBBBB',
  '.........BBBBBBMMMMM',
  '.........BBBBBBBBB..',
  '........BBBBBBB.....',
  'B......BBBBBBBBB....',
  'B.....BBBBBBLLLBDD..',
  'BB...BBBBBBLLLLB..D.',
  'BBB.BBBBBBLLLLLB....',
  'BBBBBBBBBBLLLLB.....',
  '.BBBBBBBBBLLLBB.....',
  '..BBBBBBBBBBBB......',
  '....BBBBBBBB........',
];
const DUCK = [
  '..................BBBBBBB.',
  '................BBBBBBBBBB',
  'B...............BBBWWBBBBB',
  'BB.....BBBBBBBBBBBBWKBBBBB',
  'BBBBBBBBBBBBBBBBBBBBBBBBBB',
  '.BBBBBBBBBBBBBBBBBBBMMMMMM',
  '..BBBBBBBBLLLLLBBBBBBBBB..',
  '...BBBBBBLLLLLLBBDD.......',
  '.....BBBBBBBBBBB..........',
];

export const POSES = {
  stand: {
    grid: STAND, w: 20, h: 20, legY: 17, legs: [5, 9], head: [9, 0],
    spine: { x0: 3, x1: 9, y: (x) => Math.max(8, 13 - (x - 3)) },
    tail: [0, 9], stripes: [[7, 10], [9, 9], [11, 9]],
    hit: [[10, 1, 9, 7], [3, 8, 12, 11]],
  },
  duck: {
    grid: DUCK, w: 26, h: 12, legY: 9, legs: [6, 12], head: [16, 0],
    spine: { x0: 7, x1: 16, y: () => 3 },
    tail: [0, 2], stripes: [[8, 4], [10, 4], [12, 4]],
    hit: [[1, 1, 24, 10]],
  },
};

const PAD_L = 8, PAD_T = 8, PAD_R = 4;

// ---- Palette ---------------------------------------------------------------
function hsl(h, s, l) { return `hsl(${((h % 360) + 360) % 360},${s}%,${l}%)`; }

function makePalette(dino, opts) {
  const { classic, fg = '#535353', bg = '#f7f7f7', dead, hue = 0, locked } = opts;
  if (locked) {
    return { B: '#2b2b3a', L: '#2b2b3a', D: '#22222e', A: '#22222e', H: '#22222e', W: '#2b2b3a', K: '#2b2b3a', M: '#2b2b3a' };
  }
  if (classic) {
    return { B: fg, L: fg, D: fg, A: fg, H: fg, W: dead ? fg : bg, K: dead ? bg : fg, M: bg };
  }
  let c = dino.colors;
  if (dino.rainbow) {
    c = { body: hsl(hue, 95, 58), dark: hsl(hue + 50, 85, 42), belly: hsl(hue + 180, 95, 80), accent: hsl(hue + 120, 95, 60) };
  }
  return {
    B: c.body, L: c.belly, D: c.dark, A: c.accent, H: c.horn || c.belly,
    W: dead ? '#1a1a1a' : '#ffffff', K: dead ? '#ffffff' : '#1a1a1a', M: '#6b1d1d', S: '#111',
  };
}

// ---- Sprite rendering --------------------------------------------------------
const cache = new Map();

function legRects(pose, frame) {
  const P = POSES[pose];
  const [bx, fx] = P.legs; const y = P.legY;
  const down = (x) => [[x, y, 2, 3], [x + 2, y + 2, 1, 1]];
  const up = (x) => [[x, y, 2, 2], [x + 2, y + 1, 1, 1]];
  if (frame === 0) return [...down(bx), ...up(fx)];
  if (frame === 1) return [...up(bx), ...down(fx)];
  return [...down(bx), ...down(fx)]; // frame 2 = both down (stand / jump)
}

function drawFeatures(dino, pose, frame, layer, p) {
  const P = POSES[pose];
  const [hx, hy] = P.head;
  const hp = (x, y, w, h, c) => p(hx + x, hy + y, w, h, c);
  const { x0, x1, y: sy } = P.spine;
  switch (dino.id) {
    case 'stego':
      if (layer === 'back') {
        const n = 3;
        for (let i = 0; i < n; i++) {
          const x = Math.round(x0 + ((x1 - x0 - 2) * i) / (n - 1));
          const y = sy(x + 1);
          p(x, y - 1, 3, 1, 'A'); p(x, y - 2, 3, 1, 'A'); p(x + 1, y - 3, 1, 1, 'A');
          p(x, y - 2, 1, 1, 'D');
        }
      }
      break;
    case 'spino':
      if (layer === 'back') {
        const cols = x1 - x0 + 1;
        for (let i = 0; i < cols; i++) {
          const x = x0 + i;
          const arch = Math.round(Math.sin(((i + 0.5) / cols) * Math.PI) * 7) + 1;
          const y = sy(x);
          p(x, y - arch, 1, arch + 1, i % 2 ? 'A' : 'D');
        }
      }
      break;
    case 'ankylo':
      if (layer === 'back') {
        const [tx, ty] = P.tail;
        p(tx - 3, ty - 2, 4, 4, 'A'); p(tx - 2, ty - 3, 2, 1, 'A'); p(tx - 2, ty + 2, 2, 1, 'A');
      } else {
        for (let x = x0 + 1; x <= x1; x += 2) p(x, sy(x) - 1, 1, 1, 'A');
      }
      break;
    case 'tricera':
      if (layer === 'back') {
        hp(-3, -1, 3, 7, 'A'); hp(-4, 0, 1, 5, 'A'); hp(-2, -2, 2, 1, 'A');
      } else {
        hp(4, -2, 1, 2, 'H'); hp(5, -3, 1, 1, 'H');
        hp(7, -2, 1, 2, 'H'); hp(8, -3, 1, 1, 'H');
        hp(9, 0, 1, 2, 'H');
      }
      break;
    case 'pachy':
      if (layer === 'front') {
        hp(1, -1, 7, 2, 'A'); hp(2, -2, 5, 1, 'A');
        hp(0, 0, 1, 1, 'D'); hp(8, 0, 1, 1, 'D');
      }
      break;
    case 'parasaur':
      if (layer === 'back') {
        hp(3, -1, 3, 1, 'A'); hp(1, -2, 3, 1, 'A'); hp(-1, -3, 3, 1, 'A'); hp(-3, -4, 3, 1, 'A'); hp(-4, -5, 2, 1, 'A');
      }
      break;
    case 'raptor':
      if (layer === 'front') {
        hp(2, -1, 1, 1, 'A'); hp(4, -2, 1, 2, 'A'); hp(6, -1, 1, 1, 'A');
        for (const [x, y] of P.stripes) p(x, y, 1, 2, 'A');
      }
      break;
    case 'ptero':
      if (layer === 'back') {
        if (pose === 'duck') { p(7, 1, 9, 2, 'A'); p(9, 0, 5, 1, 'A'); break; }
        if (frame === 1) {
          p(6, 9, 5, 1, 'A'); p(3, 10, 5, 1, 'A'); p(0, 11, 4, 1, 'A'); p(-2, 12, 3, 1, 'A');
        } else {
          p(8, 8, 3, 1, 'A'); p(6, 7, 4, 1, 'A'); p(4, 6, 5, 1, 'A'); p(2, 5, 6, 1, 'A'); p(0, 4, 5, 1, 'A'); p(0, 3, 3, 1, 'A');
        }
      } else {
        hp(1, -1, 4, 1, 'A'); hp(-1, 0, 2, 1, 'A');
      }
      break;
    case 'neon':
      if (layer === 'front') {
        // cool shades
        hp(2, 2, 6, 2, 'S'); hp(1, 2, 1, 1, 'S');
        hp(3, 2, 1, 1, 'W');
      }
      break;
    default: break;
  }
}

/**
 * Returns an offscreen canvas with the sprite, plus offsets.
 * opts: { classic, fg, bg, dead, hue, locked }
 */
export function getSprite(dino, pose, frame, opts = {}) {
  const hue = dino.rainbow && !opts.classic ? Math.floor((opts.hue || 0) / 15) * 15 : 0;
  const key = `${dino.id}|${pose}|${frame}|${opts.classic ? 1 : 0}|${opts.fg}|${opts.bg}|${opts.dead ? 1 : 0}|${hue}|${opts.locked ? 1 : 0}`;
  let s = cache.get(key);
  if (s) return s;
  if (cache.size > 400) cache.clear();
  const P = POSES[pose];
  const S = SCALE;
  const cw = (P.w + PAD_L + PAD_R) * S, ch = (P.h + PAD_T) * S;
  const c = typeof OffscreenCanvas !== 'undefined' ? new OffscreenCanvas(cw, ch) : Object.assign(document.createElement('canvas'), { width: cw, height: ch });
  const g = c.getContext('2d');
  const pal = makePalette(dino, { ...opts, hue });
  const p = (x, y, w, h, col) => {
    g.fillStyle = pal[col] || col;
    g.fillRect((x + PAD_L) * S, (y + PAD_T) * S, w * S, h * S);
  };
  drawFeatures(dino, pose, frame, 'back', p);
  P.grid.forEach((row, y) => {
    for (let x = 0; x < row.length; x++) {
      const ch2 = row[x];
      if (ch2 !== '.') p(x, y, 1, 1, ch2);
    }
  });
  for (const r of legRects(pose, frame)) p(r[0], r[1], r[2], r[3], 'D');
  drawFeatures(dino, pose, frame, 'front', p);
  s = { canvas: c, ox: -PAD_L * S, oy: -PAD_T * S, w: P.w * S, h: P.h * S };
  cache.set(key, s);
  return s;
}

/** Draw dino with its feet at (x, footY). */
export function drawDino(ctx, dino, pose, frame, x, footY, opts) {
  const s = getSprite(dino, pose, frame, opts);
  const top = footY - s.h;
  ctx.drawImage(s.canvas, Math.round(x + s.ox), Math.round(top + s.oy));
}

export function dinoHitboxes(pose, x, footY) {
  const P = POSES[pose];
  const top = footY - P.h * SCALE;
  return P.hit.map(([hx, hy, w, h]) => ({ x: x + hx * SCALE, y: top + hy * SCALE, w: w * SCALE, h: h * SCALE }));
}

export function poseSize(pose) {
  const P = POSES[pose];
  return { w: P.w * SCALE, h: P.h * SCALE };
}

/** Draw a centered preview of a dino into a canvas element (collection cards). */
export function drawPreview(canvas, dino, { locked = false, hue = 0, classic = false, frame = 2 } = {}) {
  const g = canvas.getContext('2d');
  g.clearRect(0, 0, canvas.width, canvas.height);
  g.imageSmoothingEnabled = false;
  const s = getSprite(dino, 'stand', frame, { locked, hue, classic, fg: '#535353', bg: '#f7f7f7' });
  const scale = Math.floor(Math.min(canvas.width / (s.w + 24), canvas.height / (s.h + 20)));
  const k = Math.max(1, scale);
  const x = (canvas.width - s.w * k) / 2 + 4 * k;
  const y = (canvas.height - s.h * k) / 2 + 6 * k;
  g.drawImage(s.canvas, Math.round(x + s.ox * k), Math.round(y + s.oy * k), s.canvas.width * k, s.canvas.height * k);
}

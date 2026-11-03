// Real dinosaur roster + hand-made pixel-art sprites.
// Each species has its own body grid (no legs), leg layout and colors.
// Duck poses and hitboxes are generated automatically from the grid.
//
// Grid legend: B body · L belly · D dark markings · A accent (plates, sail, frill, wings, club)
//              H horn / teeth / claws / beak · R crest · W eye white · K pupil · M mouth

export const SCALE = 2; // screen px per sprite pixel

export const RARITY = {
  common:    { label: 'Common',    color: '#7bd88f', weight: 50 },
  rare:      { label: 'Rare',      color: '#4fc3f7', weight: 30 },
  epic:      { label: 'Epic',      color: '#c77dff', weight: 15 },
  legendary: { label: 'Legendary', color: '#ffd166', weight: 5 },
};

export const DINOS = [
  {
    id: 'rex', name: 'Tyrannosaurus rex', short: 'T. rex', rarity: 'common',
    era: 'Late Cretaceous · 68–66 million years ago · North America',
    fact: 'Up to 12 m long, with one of the strongest bites of any land animal ever.',
    colors: { body: '#6f7d3c', dark: '#454f22', belly: '#cfcc9c', accent: '#3d4420', horn: '#f5f0dc' },
    grid: [
      '..................BBBBBBB...',
      '.................BBBBBBBBBB.',
      '.................BBBBWKBBBBB',
      '.................BBBBBBBBBBB',
      '................BBBBBBBBBBBB',
      '................BBBBBBHMHMHM',
      '................BBBBBMMMMMM.',
      '...............BBBBBBHBHBH..',
      '..............BBBBBBBBBB....',
      'B............BBDBBDBBB......',
      'BBB........BBBBBBBBBBDD.....',
      '.BBBBDBBDBBBBBBBBBBBB..D....',
      '...BBBBBBBBBBBBBBLLLB.......',
      '......BBBBBBBBBBLLLLB.......',
      '.........BBBBBBBBLLB........',
      '...........BBBBBBBB.........',
    ],
    legs: [{ x: 11, w: 3, near: false, pair: 1 }, { x: 14, w: 3, near: true, pair: 0 }], legH: 6,
    ability: { id: 'roar', name: 'Roar', cd: 12, desc: 'A mighty roar blasts away every obstacle in front of you.' },
    super: { id: 'giant', name: 'King of the Dinos', dur: 6, desc: 'Grows GIANT, crushing everything under its feet while coins rain from the sky.' },
  },
  {
    id: 'raptor', name: 'Velociraptor', short: 'Raptor', rarity: 'common',
    era: 'Late Cretaceous · 75–71 million years ago · Mongolia',
    fact: 'Really only about 2 m long and covered in feathers, with a big sickle claw on each foot.',
    colors: { body: '#b0662a', dark: '#5e3512', belly: '#ecd2ac', accent: '#2f5c9e', horn: '#f3ead2' },
    grid: [
      '..................ABBBB.....',
      '..................BBBWKBB...',
      '..................BBBBBBBBBB',
      '...................BBMHMHMMM',
      '..................BBBBBBB...',
      '.................BBB........',
      '................BBBB........',
      'AA.............BBBBB........',
      '.AAAA........BDBDBBDD.......',
      '...AABBBBDBBDBBBBBBB.D......',
      '......BBBBBBBBBBBLLB........',
      '..........BBBBBBLLB.........',
      '............BBBBBB..........',
    ],
    legs: [{ x: 12, w: 2, near: false, pair: 1 }, { x: 14, w: 2, near: true, pair: 0 }], legH: 7, toe: 'H',
    ability: { id: 'dash', name: 'Dash', cd: 10, desc: 'Burst forward at full speed, invincible, smashing through anything.' },
    super: { id: 'pack', name: 'Raptor Pack', dur: 8, desc: 'Calls 3 raptor friends that run ahead and pounce on every obstacle before it reaches you.' },
  },
  {
    id: 'stego', name: 'Stegosaurus', short: 'Stego', rarity: 'rare',
    era: 'Late Jurassic · 155–145 million years ago · North America',
    fact: 'Its spiky tail is called a "thagomizer", and its brain was about the size of a lemon.',
    colors: { body: '#7c8c4e', dark: '#545f35', belly: '#d2d6a9', accent: '#c4552e', horn: '#efe6cc' },
    grid: [
      '..........A...A.............',
      '.......A.AAA.AAA.A..........',
      '......AAAAAAAAAAAAAA........',
      '....A.AAAAAAAAAAAAAAA.......',
      '...AAABBBBBBBBBBBBBBAA......',
      '.HAABBBBBBBBBBBBBBBBBBA.....',
      'H..BBBBBBBBBBBBBBBBBBBBB....',
      '.HBBBBBBBBBBBBBBBBBBBBBBB...',
      '...BBBBBBBBBBBBBBBBBBBBBBBBB',
      '.....BBBBBBBBBBBBBBBBBBBWKBB',
      '.......BBBLLLLLLLLLLLBB..BBM',
    ],
    legs: [
      { x: 7, w: 3, near: false, pair: 1 }, { x: 17, w: 2, near: false, pair: 0 },
      { x: 9, w: 3, near: true, pair: 0 }, { x: 19, w: 3, near: true, pair: 1 },
    ], legH: 6,
    ability: { id: 'shield', name: 'Plate Armor', cd: 14, desc: 'Grows a shield that absorbs one hit.' },
    super: { id: 'orbit', name: 'Plate Cyclone', dur: 8, desc: 'Its back plates break off and spin around it like saw blades, shredding everything nearby.' },
  },
  {
    id: 'pachy', name: 'Pachycephalosaurus', short: 'Pachy', rarity: 'common',
    era: 'Late Cretaceous · 70–66 million years ago · North America',
    fact: 'Its domed skull roof could be up to 25 cm thick, ringed with bony knobs.',
    colors: { body: '#9b7a52', dark: '#664c32', belly: '#e8d6b6', accent: '#dcc493', horn: '#f6eedb' },
    grid: [
      '..................AAAA....',
      '.................AAAAAA...',
      '................HAAAAAAH..',
      '................BBBBBBBBB.',
      '................BBBBBWKBB.',
      '................BBBBBBBBBB',
      '.................BBBBBBMM.',
      '................BBBBBBB...',
      '..............BBBBB.......',
      'B...........BBBBBBDD......',
      'BBBB.....BBBDBBDBB..D.....',
      '.BBBBBBBBBBBBBBLLB........',
      '....BBBBBBBBBBLLLB........',
      '.......BBBBBBBBBB.........',
    ],
    legs: [{ x: 10, w: 2, near: false, pair: 1 }, { x: 12, w: 2, near: true, pair: 0 }], legH: 7,
    ability: { id: 'superjump', name: 'Super Jump', cd: 9, desc: 'Launches sky-high and is invincible while rising.' },
    super: { id: 'ball', name: 'Boulder Roll', dur: 6, desc: 'Curls into a spinning, bouncing skull-ball and bowls over everything in its path.' },
  },
  {
    id: 'tricera', name: 'Triceratops', short: 'Trike', rarity: 'rare',
    era: 'Late Cretaceous · 68–66 million years ago · North America',
    fact: 'About 9 m long, with a huge bony frill and brow horns up to 1 m long.',
    colors: { body: '#8a6d4a', dark: '#5a462e', belly: '#dccaa8', accent: '#b4532f', horn: '#f3e8cb' },
    grid: [
      '....................AAA.........',
      '...................AAAAA........',
      '...................AAAAAA....H..',
      '..................AAAAAAA...HH..',
      '......BBBBBBBB....AAAAAABBBHH...',
      '...BBBBBBBBBBBBBBBAAAAABBBWKBBH.',
      '.BBBBBBBBBBBBBBBBBBAAABBBBBBBBB.',
      'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBD.',
      '.BBBBBBBBBBBBBBBBBBBBBBBBBBBM...',
      '...BBBBBLLLLLLLLLLLLBBBBB.......',
      '.....BBBLLLLLLLLLLLBBB..........',
    ],
    legs: [
      { x: 5, w: 3, near: false, pair: 1 }, { x: 17, w: 2, near: false, pair: 0 },
      { x: 7, w: 3, near: true, pair: 0 }, { x: 19, w: 3, near: true, pair: 1 },
    ], legH: 6,
    ability: { id: 'charge', name: 'Charge', cd: 12, desc: 'Lowers its horns and rams through ground obstacles for 3s.' },
    super: { id: 'stampede', name: 'Stampede', dur: 6, desc: 'A whole herd of Triceratops thunders across the screen and flattens everything.' },
  },
  {
    id: 'parasaur', name: 'Parasaurolophus', short: 'Parasaur', rarity: 'common',
    era: 'Late Cretaceous · 76–73 million years ago · North America',
    fact: 'Its long hollow crest probably worked like a trumpet to make deep calls.',
    colors: { body: '#4f806a', dark: '#2f5243', belly: '#d2e3c9', accent: '#d4782f', crest: '#d4782f', horn: '#e9d9a8' },
    grid: [
      '..............RRR...........',
      '................RRRR........',
      '..................RRRRB.....',
      '.....................BBBB...',
      '....................BBWKBB..',
      '....................BBBBBBB.',
      '...................BBBBBMDD.',
      '..................BBBBB.....',
      '.................BBBB.......',
      'B..............BBBBBDD......',
      'BBB.........BBBDBDBB..D.....',
      '.BBBBDBBDBBBBBBBBBBB........',
      '...BBBBBBBBBBBBLLLLB........',
      '......BBBBBBBBLLLLB.........',
      '..........BBBBBBBB..........',
    ],
    legs: [{ x: 10, w: 3, near: false, pair: 1 }, { x: 13, w: 3, near: true, pair: 0 }], legH: 6,
    ability: { id: 'echo', name: 'Echo Call', cd: 14, desc: 'Its crest hums: coin magnet + double coins for 8s.' },
    super: { id: 'midas', name: 'Golden Song', dur: 7, desc: 'A magical trumpet song turns every obstacle on screen into gold coins.' },
  },
  {
    id: 'ankylo', name: 'Ankylosaurus', short: 'Ankylo', rarity: 'epic',
    era: 'Late Cretaceous · 68–66 million years ago · North America',
    fact: 'Covered in bony armor plates, it could swing a heavy tail club strong enough to break bones.',
    colors: { body: '#7e705a', dark: '#4f4636', belly: '#cdc1a8', accent: '#5b544a', horn: '#ece2cb' },
    grid: [
      '........H.H.H.H.H.H.........',
      '.......DBDBDBDBDBDBDB.......',
      '.....HBBBBBBBBBBBBBBBBH.....',
      'AA..BBDBBDBBDBBDBBDBBBBBB...',
      'AAABBBBBBBBBBBBBBBBBBBBBBBB.',
      'AAA.BBBBBBBBBBBBBBBBBBBBWKBB',
      'AA...BBBBBBBBBBBBBBBBBBBBBBM',
      '.......BLLLLLLLLLLLLLLLBB...',
    ],
    legs: [
      { x: 7, w: 3, near: false, pair: 1 }, { x: 18, w: 2, near: false, pair: 0 },
      { x: 9, w: 3, near: true, pair: 0 }, { x: 20, w: 3, near: true, pair: 1 },
    ], legH: 5,
    ability: { id: 'quake', name: 'Quake', cd: 16, desc: 'Tail-slams the ground, shattering every ground obstacle on screen.' },
    super: { id: 'fortress', name: 'Iron Fortress', dur: 8, desc: 'Turns to living steel: obstacles bounce off it like pinballs and pay out coins.' },
  },
  {
    id: 'ptero', name: 'Pteranodon', short: 'Ptero', rarity: 'epic',
    era: 'Late Cretaceous · 86–84 million years ago · North America',
    fact: 'Not actually a dinosaur but a flying reptile (pterosaur), with wings up to 7 m across.',
    colors: { body: '#cbb99f', dark: '#8a7760', belly: '#f1e8d8', accent: '#9a6a4a', horn: '#e9c44c', crest: '#c0392b' },
    grid: [
      '............RRRR..........',
      '..............RRRBB.......',
      '................BBWKB.....',
      '................BBBBHHHHHH',
      '................BBBHHHHH..',
      '...............BBB........',
      '..AAAA.......BBBB.........',
      '...AAAAAAAABBBBBB.........',
      '....AAAAAAABBBBBBB........',
      '.....AAAAAABBBBLLB........',
      '.......AAAABBBBLLB........',
      '..........BBBBBBB.........',
      '...........BBBB...........',
    ],
    alt: [
      '............RRRR..........',
      '..AA..........RRRBB.......',
      '...AAA..........BBWKB.....',
      '....AAAA........BBBBHHHHHH',
      '.....AAAAA......BBBHHHHH..',
      '......AAAAAA...BBB........',
      '.......AAAAAAABBBB........',
      '.........AAAABBBBB........',
      '...........BBBBBBBB.......',
      '...........BBBBBLLB.......',
      '...........BBBBBLLB.......',
      '..........BBBBBBB.........',
      '...........BBBB...........',
    ],
    legs: [{ x: 11, w: 1, near: false, pair: 1 }, { x: 13, w: 1, near: true, pair: 0 }], legH: 6,
    ability: { id: 'soar', name: 'Soar', cd: 12, desc: 'Takes flight for 3s, gliding over everything.' },
    super: { id: 'storm', name: 'Thunder Wings', dur: 8, desc: 'Flies through a storm (tap to flap!) and calls lightning down on every obstacle.' },
    passive: 'doubleJump',
    passiveDesc: 'Double jump + hold to glide',
  },
  {
    id: 'spino', name: 'Spinosaurus', short: 'Spino', rarity: 'legendary',
    era: 'Mid Cretaceous · 99–93 million years ago · North Africa',
    fact: 'Possibly longer than T. rex, it spent much of its life in rivers hunting giant fish. Its fossils come from North Africa!',
    colors: { body: '#5c6a72', dark: '#3a444a', belly: '#cbcfc8', accent: '#c0392b', horn: '#f2ede0' },
    grid: [
      '..........AAADAA................',
      '........ADAAADAAAD..............',
      '.......AADAAADAAADA.............',
      '......AAADAAADAAADAA............',
      '......AAADAAADAAADAAA...........',
      '.....AAAADAAADAAADAAAA...BBBB...',
      '.....BBBBBBBBBBBBBBBBBBBBBWKBB..',
      'B...BBBBBBBBBBBBBBBBBBBBBBBBBBBB',
      'BBBBBBBBBBBBBBBBBBBBBBBBBBMHMHMH',
      '.BBBBBBBBBBBBBBBBBBBBBB..BBBBBB.',
      '......BBBBBBBBLLLLLBDD..........',
      '........BBBBBBLLLLB...D.........',
      '..........BBBBBBBB..............',
    ],
    legs: [{ x: 10, w: 3, near: false, pair: 1 }, { x: 13, w: 3, near: true, pair: 0 }], legH: 6,
    ability: { id: 'dive', name: 'River Dive', cd: 11, desc: 'Dives underground like into a river; only its sail shows, so everything passes over.' },
    super: { id: 'wave', name: 'Tsunami Surf', dur: 7, desc: 'Summons a giant wave and surfs it, washing away everything ahead.' },
  },
  {
    id: 'brachio', name: 'Brachiosaurus', short: 'Brachio', rarity: 'legendary',
    era: 'Late Jurassic · 154–150 million years ago · North America',
    fact: 'Its front legs were longer than its back legs, letting it lift its head about 9 m high.',
    colors: { body: '#7c8a72', dark: '#56614d', belly: '#d6dac6', accent: '#56614d', horn: '#eee8d6' },
    grid: [
      '...................BBB...',
      '..................BBBBB..',
      '..................BBBWKB.',
      '..................BBBBBBM',
      '..................BBB....',
      '.................BBB.....',
      '.................BBB.....',
      '................BBB......',
      '................BBB......',
      '...............BBBB......',
      '..............BBBBB......',
      '...........BBBBBBBB......',
      '......BBBBBBDBBBBBBB.....',
      '...BBBBBBDBBBBBDBBBB.....',
      'BBBBBBBBBBBBBBBBBBBB.....',
      '.....BBBLLLLLLLLLBBB.....',
      '.......BBLLLLLLLLBB......',
    ],
    legs: [
      { x: 7, w: 2, near: false, pair: 1 }, { x: 14, w: 2, near: false, pair: 0 },
      { x: 9, w: 3, near: true, pair: 0 }, { x: 16, w: 3, near: true, pair: 1 },
    ], legH: 6,
    ability: { id: 'sweep', name: 'Neck Sweep', cd: 12, desc: 'Swings its long neck to knock every flying enemy and meteor out of the sky.' },
    super: { id: 'meteors', name: 'Meteor Rain', dur: 6, desc: 'Calls down a meteor shower that blows up every obstacle ahead. (Ironic, right?)' },
  },
  {
    id: 'dilo', name: 'Dilophosaurus', short: 'Dilo', rarity: 'rare',
    era: 'Early Jurassic · about 193 million years ago · North America',
    fact: 'Had two thin crests on its head and was about 7 m long. The venom spit and neck frill come from the movies!',
    colors: { body: '#9aa33a', dark: '#5c6320', belly: '#e6e5b6', accent: '#d35400', crest: '#e67e22', horn: '#f5f0dc', frill: '#e74c3c' },
    grid: [
      '.................R.R.....',
      '................RRRRR....',
      '................BBBWKB...',
      '................BBBBBBBB.',
      '................BBBMHMHM.',
      '...............BBBBBB....',
      '..............BBBB.......',
      'B.............BBBB.......',
      'BBB.........BBBBBBDD.....',
      '.BBBBDBBDBBDBBBBB..D.....',
      '...BBBBBBBBBBBLLLB.......',
      '......BBBBBBBLLLB........',
      '.........BBBBBBB.........',
    ],
    legs: [{ x: 10, w: 2, near: false, pair: 1 }, { x: 12, w: 2, near: true, pair: 0 }], legH: 7,
    ability: { id: 'spit', name: 'Venom Spit', cd: 5, desc: 'Opens its frill and spits a venom glob that melts the first obstacle it hits.' },
    super: { id: 'toxic', name: 'Toxic Fog', dur: 7, desc: 'Breathes out a poison cloud ahead; every obstacle that enters it melts away.' },
  },
];

export const getDino = (id) => DINOS.find((d) => d.id === id) || DINOS[0];

// ---- composition -------------------------------------------------------------------
const PRIORITY = { '.': 0, B: 1, L: 2, D: 3, A: 3, R: 3, H: 4, M: 4, W: 5, K: 5 };
const composeCache = new Map();

function padRows(rows) {
  const w = Math.max(...rows.map((r) => r.length));
  return rows.map((r) => r.padEnd(w, '.').split(''));
}

// squash a tall body into `n` rows (keeps eyes/teeth) and lean it forward
function squash(rows, n) {
  if (rows.length <= n) return rows;
  const out = [];
  const w = rows[0].length + 2;
  for (let r = 0; r < n; r++) {
    const a = Math.floor((r * rows.length) / n), b = Math.max(a + 1, Math.floor(((r + 1) * rows.length) / n));
    const shift = Math.round((1 - r / (n - 1)) * 2);
    const row = new Array(w).fill('.');
    for (let c = 0; c < rows[0].length; c++) {
      let best = '.';
      for (let s = a; s < b; s++) if (PRIORITY[rows[s][c]] > PRIORITY[best]) best = rows[s][c];
      row[c + shift] = best;
    }
    out.push(row);
  }
  return out;
}

function compose(def, pose, frame) {
  const key = `${def.id}|${pose}|${frame}`;
  let c = composeCache.get(key);
  if (c) return c;
  let body = padRows(frame === 1 && def.alt ? def.alt : def.grid);
  let legH = def.legH;
  if (pose === 'duck') { body = squash(body, 9); legH = 4; }
  const top = body.length - 1;
  const legsMaxX = Math.max(...def.legs.map((l) => l.x + l.w + 2));
  const w = Math.max(body[0].length, legsMaxX);
  const h = top + legH;
  const cells = Array.from({ length: h }, () => new Array(w).fill('.'));
  const set = (x, y, ch, onlyEmpty) => {
    if (x < 0 || y < 0 || x >= w || y >= h) return;
    if (onlyEmpty && cells[y][x] !== '.') return;
    cells[y][x] = ch;
  };
  const drawLeg = (l, onlyEmpty) => {
    const down = frame === 2 || (frame === 0 ? l.pair === 0 : l.pair === 1);
    const col = l.near ? 'B' : 'D';
    const toe = def.toe || 'D';
    if (down) {
      for (let y = top; y < top + legH; y++) for (let x = l.x; x < l.x + l.w; x++) set(x, y, col, onlyEmpty);
      set(l.x + l.w, top + legH - 1, toe, onlyEmpty);
      if (l.near) set(l.x, top + legH - 1, 'D', false);
    } else {
      for (let y = top; y < top + legH - 2; y++) for (let x = l.x + 1; x < l.x + 1 + l.w; x++) set(x, y, col, onlyEmpty);
      set(l.x + l.w + 1, top + legH - 3, toe, onlyEmpty);
    }
  };
  // far legs behind the body
  for (const l of def.legs) if (!l.near) drawLeg(l, true);
  body.forEach((row, y) => row.forEach((ch, x) => { if (ch !== '.') cells[y][x] = ch; }));
  for (const l of def.legs) if (l.near) drawLeg(l, false);

  let eye = { x: w - 4, y: 2 };
  cells.forEach((row, y) => row.forEach((ch, x) => { if (ch === 'W') eye = { x, y }; }));
  c = { cells, w, h, eye };
  composeCache.set(key, c);
  return c;
}

// ---- hitboxes (auto from shape) ------------------------------------------------------
const hitCache = new Map();
function gridHitboxes(def, pose) {
  const key = `${def.id}|${pose}`;
  let hb = hitCache.get(key);
  if (hb) return hb;
  const { cells, w, h } = compose(def, pose, 2);
  hb = [];
  const slice = 5;
  for (let c0 = 0; c0 < w; c0 += slice) {
    let minX = 1e9, maxX = -1, minY = 1e9, maxY = -1, n = 0;
    for (let y = 0; y < h; y++) {
      for (let x = c0; x < Math.min(w, c0 + slice); x++) {
        if (cells[y][x] === '.') continue;
        n++;
        minX = Math.min(minX, x); maxX = Math.max(maxX, x);
        minY = Math.min(minY, y); maxY = Math.max(maxY, y);
      }
    }
    if (n < 5) continue;
    const r = { x: minX + 1, y: minY + 1, w: Math.max(1, maxX - minX - 1), h: Math.max(1, maxY - minY) };
    hb.push(r);
  }
  hitCache.set(key, hb);
  return hb;
}

export function dinoHitboxes(def, pose, x, footY, scale = 1) {
  const { h } = compose(def, pose, 2);
  return gridHitboxes(def, pose).map((r) => {
    const bx = x + r.x * SCALE, by = footY - (h - r.y) * SCALE;
    return {
      x: x + (bx - x) * scale,
      y: footY - (footY - by) * scale,
      w: r.w * SCALE * scale,
      h: r.h * SCALE * scale,
    };
  });
}

export function poseSize(def, pose) {
  const { w, h } = compose(def, pose, 2);
  return { w: w * SCALE, h: h * SCALE };
}

/** Eye position in px, relative to (x, footY). */
export function headAnchor(def, pose) {
  const { h, eye } = compose(def, pose, 2);
  return { x: eye.x * SCALE, y: -(h - eye.y) * SCALE };
}

// ---- palette & sprites -------------------------------------------------------------
const TINTS = {
  steel: { B: '#9fb3c8', L: '#e3ebf3', D: '#5d7186', A: '#7b8fa3', H: '#ffffff', R: '#7b8fa3' },
  gold: { B: '#f2c14e', L: '#fff1b8', D: '#b8860b', A: '#e0a526', H: '#fffbe6', R: '#e0a526' },
};

function makePalette(def, opts) {
  const { classic, fg = '#535353', bg = '#f7f7f7', dead, locked, tint } = opts;
  if (locked) {
    const c = '#2b2b3a';
    return { B: c, L: c, D: '#22222e', A: '#22222e', H: '#22222e', R: '#22222e', W: c, K: c, M: c };
  }
  if (classic) return { B: fg, L: fg, D: fg, A: fg, H: fg, R: fg, W: dead ? fg : bg, K: dead ? bg : fg, M: bg };
  const c = def.colors;
  const p = {
    B: c.body, L: c.belly, D: c.dark, A: c.accent, H: c.horn || c.belly, R: c.crest || c.accent,
    W: dead ? '#1a1a1a' : '#ffffff', K: dead ? '#ffffff' : '#1a1a1a', M: '#5a1a1a',
  };
  if (tint && TINTS[tint]) Object.assign(p, TINTS[tint]);
  return p;
}

const spriteCache = new Map();
export function getSprite(def, pose, frame, opts = {}) {
  const key = `${def.id}|${pose}|${frame}|${opts.classic ? 1 : 0}|${opts.fg}|${opts.bg}|${opts.dead ? 1 : 0}|${opts.locked ? 1 : 0}|${opts.tint || ''}`;
  let s = spriteCache.get(key);
  if (s) return s;
  if (spriteCache.size > 500) spriteCache.clear();
  const { cells, w, h } = compose(def, pose, frame);
  const S = SCALE;
  const cw = w * S, ch = h * S;
  const c = typeof OffscreenCanvas !== 'undefined' ? new OffscreenCanvas(cw, ch) : Object.assign(document.createElement('canvas'), { width: cw, height: ch });
  const g = c.getContext('2d');
  const pal = makePalette(def, opts);
  cells.forEach((row, y) => row.forEach((chr, x) => {
    if (chr === '.') return;
    g.fillStyle = pal[chr] || chr;
    g.fillRect(x * S, y * S, S, S);
  }));
  s = { canvas: c, ox: 0, oy: 0, w: cw, h: ch };
  spriteCache.set(key, s);
  return s;
}

/** Draw dino with its feet at (x, footY). */
export function drawDino(ctx, def, pose, frame, x, footY, opts) {
  const s = getSprite(def, pose, frame, opts);
  ctx.drawImage(s.canvas, Math.round(x), Math.round(footY - s.h));
}

/** Draw a centered preview of a dino into a canvas element (menus, cards). */
export function drawPreview(canvas, def, { locked = false, classic = false, frame = 2 } = {}) {
  const g = canvas.getContext('2d');
  g.clearRect(0, 0, canvas.width, canvas.height);
  g.imageSmoothingEnabled = false;
  const s = getSprite(def, 'stand', frame, { locked, classic, fg: '#535353', bg: '#f7f7f7' });
  const k = Math.max(1, Math.floor(Math.min((canvas.width - 8) / s.w, (canvas.height - 8) / s.h) * 2) / 2);
  const w = s.w * k, h = s.h * k;
  g.drawImage(s.canvas, Math.round((canvas.width - w) / 2), Math.round((canvas.height - h) / 2), w, h);
}

// Real dinosaur roster + hand-made pixel-art sprites.
//
// Each species has its own body grid (no legs), leg layout and colors. Duck
// poses and hitboxes are generated automatically from the grid.
//
// Grid legend:
//   B body · L belly · D dark markings · A accent (plates, sail, frill, wings, club)
//   H horn / teeth / claws / beak · R crest · W eye white · K pupil · M mouth
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

const double kScale = 2; // logical px per sprite pixel

class Rarity {
  const Rarity(this.label, this.color, this.weight);
  final String label;
  final Color color;
  final int weight;
}

const Map<String, Rarity> kRarity = {
  'common': Rarity('Common', Color(0xFF7BD88F), 50),
  'rare': Rarity('Rare', Color(0xFF4FC3F7), 30),
  'epic': Rarity('Epic', Color(0xFFC77DFF), 15),
  'legendary': Rarity('Legendary', Color(0xFFFFD166), 5),
};

class DinoColors {
  const DinoColors({
    required this.body,
    required this.dark,
    required this.belly,
    required this.accent,
    required this.horn,
    this.crest,
    this.frill,
  });
  final Color body, dark, belly, accent, horn;
  final Color? crest, frill;
}

class Leg {
  const Leg(this.x, this.w, {required this.near, required this.pair});
  final int x, w;
  final bool near;
  final int pair;
}

class Ability {
  const Ability(this.id, this.name, this.cd, this.desc);
  final String id, name, desc;
  final double cd;
}

class SuperPower {
  const SuperPower(this.id, this.name, this.dur, this.desc);
  final String id, name, desc;
  final double dur;
}

class DinoDef {
  const DinoDef({
    required this.id,
    required this.name,
    required this.rarity,
    required this.era,
    required this.fact,
    required this.colors,
    required this.grid,
    this.alt,
    required this.legs,
    required this.legH,
    this.toe = 'D',
    required this.ability,
    required this.superPower,
    this.passive,
    this.passiveDesc,
  });

  final String id, name, rarity, era, fact;
  final DinoColors colors;
  final List<String> grid;
  final List<String>? alt;
  final List<Leg> legs;
  final int legH;
  final String toe;
  final Ability ability;
  final SuperPower superPower;
  final String? passive, passiveDesc;

  Rarity get rar => kRarity[rarity]!;
}

// ---------------------------------------------------------------------------
// Roster
// ---------------------------------------------------------------------------
final List<DinoDef> kDinos = [
  DinoDef(
    id: 'rex',
    name: 'Tyrannosaurus rex',
    rarity: 'common',
    era: 'Late Cretaceous · 68–66 million years ago · North America',
    fact: 'Up to 12 m long, with one of the strongest bites of any land animal ever.',
    colors: const DinoColors(
        body: Color(0xFF6F7D3C), dark: Color(0xFF454F22), belly: Color(0xFFCFCC9C), accent: Color(0xFF3D4420), horn: Color(0xFFF5F0DC)),
    grid: const [
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
    legs: const [Leg(11, 3, near: false, pair: 1), Leg(14, 3, near: true, pair: 0)],
    legH: 6,
    ability: const Ability('roar', 'Roar', 12, 'A mighty roar blasts away every obstacle in front of you.'),
    superPower: const SuperPower('giant', 'King of the Dinos', 6,
        'Grows GIANT, crushing everything under its feet while coins rain from the sky.'),
  ),
  DinoDef(
    id: 'raptor',
    name: 'Velociraptor',
    rarity: 'common',
    era: 'Late Cretaceous · 75–71 million years ago · Mongolia',
    fact: 'Really only about 2 m long and covered in feathers, with a big sickle claw on each foot.',
    colors: const DinoColors(
        body: Color(0xFFB0662A), dark: Color(0xFF5E3512), belly: Color(0xFFECD2AC), accent: Color(0xFF2F5C9E), horn: Color(0xFFF3EAD2)),
    grid: const [
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
    legs: const [Leg(12, 2, near: false, pair: 1), Leg(14, 2, near: true, pair: 0)],
    legH: 7,
    toe: 'H',
    ability: const Ability('dash', 'Dash', 10, 'Burst forward at full speed, invincible, smashing through anything.'),
    superPower: const SuperPower('pack', 'Raptor Pack', 8,
        'Calls 3 raptor friends that run ahead and pounce on every obstacle before it reaches you.'),
  ),
  DinoDef(
    id: 'stego',
    name: 'Stegosaurus',
    rarity: 'rare',
    era: 'Late Jurassic · 155–145 million years ago · North America',
    fact: 'Its spiky tail is called a "thagomizer", and its brain was about the size of a lemon.',
    colors: const DinoColors(
        body: Color(0xFF7C8C4E), dark: Color(0xFF545F35), belly: Color(0xFFD2D6A9), accent: Color(0xFFC4552E), horn: Color(0xFFEFE6CC)),
    grid: const [
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
    legs: const [
      Leg(7, 3, near: false, pair: 1),
      Leg(17, 2, near: false, pair: 0),
      Leg(9, 3, near: true, pair: 0),
      Leg(19, 3, near: true, pair: 1),
    ],
    legH: 6,
    ability: const Ability('shield', 'Plate Armor', 14, 'Grows a shield that absorbs one hit.'),
    superPower: const SuperPower('orbit', 'Plate Cyclone', 8,
        'Its back plates break off and spin around it like saw blades, shredding everything nearby.'),
  ),
  DinoDef(
    id: 'pachy',
    name: 'Pachycephalosaurus',
    rarity: 'common',
    era: 'Late Cretaceous · 70–66 million years ago · North America',
    fact: 'Its domed skull roof could be up to 25 cm thick, ringed with bony knobs.',
    colors: const DinoColors(
        body: Color(0xFF9B7A52), dark: Color(0xFF664C32), belly: Color(0xFFE8D6B6), accent: Color(0xFFDCC493), horn: Color(0xFFF6EEDB)),
    grid: const [
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
    legs: const [Leg(10, 2, near: false, pair: 1), Leg(12, 2, near: true, pair: 0)],
    legH: 7,
    ability: const Ability('superjump', 'Super Jump', 9, 'Launches sky-high and is invincible while rising.'),
    superPower: const SuperPower('ball', 'Boulder Roll', 6,
        'Curls into a spinning, bouncing skull-ball and bowls over everything in its path.'),
  ),
  DinoDef(
    id: 'tricera',
    name: 'Triceratops',
    rarity: 'rare',
    era: 'Late Cretaceous · 68–66 million years ago · North America',
    fact: 'About 9 m long, with a huge bony frill and brow horns up to 1 m long.',
    colors: const DinoColors(
        body: Color(0xFF8A6D4A), dark: Color(0xFF5A462E), belly: Color(0xFFDCCAA8), accent: Color(0xFFB4532F), horn: Color(0xFFF3E8CB)),
    grid: const [
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
    legs: const [
      Leg(5, 3, near: false, pair: 1),
      Leg(17, 2, near: false, pair: 0),
      Leg(7, 3, near: true, pair: 0),
      Leg(19, 3, near: true, pair: 1),
    ],
    legH: 6,
    ability: const Ability('charge', 'Charge', 12, 'Lowers its horns and rams through ground obstacles for 3s.'),
    superPower: const SuperPower('stampede', 'Stampede', 6,
        'A whole herd of Triceratops thunders across the screen and flattens everything.'),
  ),
  DinoDef(
    id: 'parasaur',
    name: 'Parasaurolophus',
    rarity: 'common',
    era: 'Late Cretaceous · 76–73 million years ago · North America',
    fact: 'Its long hollow crest probably worked like a trumpet to make deep calls.',
    colors: const DinoColors(
        body: Color(0xFF4F806A),
        dark: Color(0xFF2F5243),
        belly: Color(0xFFD2E3C9),
        accent: Color(0xFFD4782F),
        crest: Color(0xFFD4782F),
        horn: Color(0xFFE9D9A8)),
    grid: const [
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
    legs: const [Leg(10, 3, near: false, pair: 1), Leg(13, 3, near: true, pair: 0)],
    legH: 6,
    ability: const Ability('echo', 'Echo Call', 14, 'Its crest hums: coin magnet + double coins for 8s.'),
    superPower: const SuperPower('midas', 'Golden Song', 7,
        'A magical trumpet song turns every obstacle on screen into gold coins.'),
  ),
  DinoDef(
    id: 'ankylo',
    name: 'Ankylosaurus',
    rarity: 'epic',
    era: 'Late Cretaceous · 68–66 million years ago · North America',
    fact: 'Covered in bony armor plates, it could swing a heavy tail club strong enough to break bones.',
    colors: const DinoColors(
        body: Color(0xFF7E705A), dark: Color(0xFF4F4636), belly: Color(0xFFCDC1A8), accent: Color(0xFF5B544A), horn: Color(0xFFECE2CB)),
    grid: const [
      '........H.H.H.H.H.H.........',
      '.......DBDBDBDBDBDBDB.......',
      '.....HBBBBBBBBBBBBBBBBH.....',
      'AA..BBDBBDBBDBBDBBDBBBBBB...',
      'AAABBBBBBBBBBBBBBBBBBBBBBBB.',
      'AAA.BBBBBBBBBBBBBBBBBBBBWKBB',
      'AA...BBBBBBBBBBBBBBBBBBBBBBM',
      '.......BLLLLLLLLLLLLLLLBB...',
    ],
    legs: const [
      Leg(7, 3, near: false, pair: 1),
      Leg(18, 2, near: false, pair: 0),
      Leg(9, 3, near: true, pair: 0),
      Leg(20, 3, near: true, pair: 1),
    ],
    legH: 5,
    ability: const Ability('quake', 'Quake', 16, 'Tail-slams the ground, shattering every ground obstacle on screen.'),
    superPower: const SuperPower('fortress', 'Iron Fortress', 8,
        'Turns to living steel: obstacles bounce off it like pinballs and pay out coins.'),
  ),
  DinoDef(
    id: 'ptero',
    name: 'Pteranodon',
    rarity: 'epic',
    era: 'Late Cretaceous · 86–84 million years ago · North America',
    fact: 'Not actually a dinosaur but a flying reptile (pterosaur), with wings up to 7 m across.',
    colors: const DinoColors(
        body: Color(0xFFCBB99F),
        dark: Color(0xFF8A7760),
        belly: Color(0xFFF1E8D8),
        accent: Color(0xFF9A6A4A),
        horn: Color(0xFFE9C44C),
        crest: Color(0xFFC0392B)),
    grid: const [
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
    alt: const [
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
    legs: const [Leg(11, 1, near: false, pair: 1), Leg(13, 1, near: true, pair: 0)],
    legH: 6,
    ability: const Ability('soar', 'Soar', 12, 'Takes flight for 3s, gliding over everything.'),
    superPower: const SuperPower('storm', 'Thunder Wings', 8,
        'Flies through a storm (tap to flap!) and calls lightning down on every obstacle.'),
    passive: 'doubleJump',
    passiveDesc: 'Double jump + hold to glide',
  ),
  DinoDef(
    id: 'spino',
    name: 'Spinosaurus',
    rarity: 'legendary',
    era: 'Mid Cretaceous · 99–93 million years ago · North Africa',
    fact:
        'Possibly longer than T. rex, it spent much of its life in rivers hunting giant fish. Its fossils come from North Africa!',
    colors: const DinoColors(
        body: Color(0xFF5C6A72), dark: Color(0xFF3A444A), belly: Color(0xFFCBCFC8), accent: Color(0xFFC0392B), horn: Color(0xFFF2EDE0)),
    grid: const [
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
    legs: const [Leg(10, 3, near: false, pair: 1), Leg(13, 3, near: true, pair: 0)],
    legH: 6,
    ability: const Ability('dive', 'River Dive', 11,
        'Dives underground like into a river; only its sail shows, so everything passes over.'),
    superPower: const SuperPower('wave', 'Tsunami Surf', 7,
        'Summons a giant wave and surfs it, washing away everything ahead.'),
  ),
  DinoDef(
    id: 'brachio',
    name: 'Brachiosaurus',
    rarity: 'legendary',
    era: 'Late Jurassic · 154–150 million years ago · North America',
    fact: 'Its front legs were longer than its back legs, letting it lift its head about 9 m high.',
    colors: const DinoColors(
        body: Color(0xFF7C8A72), dark: Color(0xFF56614D), belly: Color(0xFFD6DAC6), accent: Color(0xFF56614D), horn: Color(0xFFEEE8D6)),
    grid: const [
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
    legs: const [
      Leg(7, 2, near: false, pair: 1),
      Leg(14, 2, near: false, pair: 0),
      Leg(9, 3, near: true, pair: 0),
      Leg(16, 3, near: true, pair: 1),
    ],
    legH: 6,
    ability: const Ability('sweep', 'Neck Sweep', 12, 'Swings its long neck to knock every flying enemy and meteor out of the sky.'),
    superPower: const SuperPower('meteors', 'Meteor Rain', 6,
        'Calls down a meteor shower that blows up every obstacle ahead. (Ironic, right?)'),
  ),
  DinoDef(
    id: 'dilo',
    name: 'Dilophosaurus',
    rarity: 'rare',
    era: 'Early Jurassic · about 193 million years ago · North America',
    fact:
        'Had two thin crests on its head and was about 7 m long. The venom spit and neck frill come from the movies!',
    colors: const DinoColors(
        body: Color(0xFF9AA33A),
        dark: Color(0xFF5C6320),
        belly: Color(0xFFE6E5B6),
        accent: Color(0xFFD35400),
        crest: Color(0xFFE67E22),
        horn: Color(0xFFF5F0DC),
        frill: Color(0xFFE74C3C)),
    grid: const [
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
    legs: const [Leg(10, 2, near: false, pair: 1), Leg(12, 2, near: true, pair: 0)],
    legH: 7,
    ability: const Ability('spit', 'Venom Spit', 5, 'Opens its frill and spits a venom glob that melts the first obstacle it hits.'),
    superPower: const SuperPower('toxic', 'Toxic Fog', 7,
        'Breathes out a poison cloud ahead; every obstacle that enters it melts away.'),
  ),
];

DinoDef getDino(String id) => kDinos.firstWhere((d) => d.id == id, orElse: () => kDinos.first);

// ---------------------------------------------------------------------------
// Composition (body grid + animated legs)
// ---------------------------------------------------------------------------
const Map<String, int> _priority = {'.': 0, 'B': 1, 'L': 2, 'D': 3, 'A': 3, 'R': 3, 'H': 4, 'M': 4, 'W': 5, 'K': 5};

class Composed {
  Composed(this.cells, this.w, this.h, this.eyeX, this.eyeY);
  final List<List<String>> cells;
  final int w, h, eyeX, eyeY;
}

List<List<String>> _padRows(List<String> rows) {
  final w = rows.map((r) => r.length).reduce(math.max);
  return rows.map((r) => r.padRight(w, '.').split('')).toList();
}

/// Squash a tall body into [n] rows (keeps eyes/teeth) and lean it forward.
List<List<String>> _squash(List<List<String>> rows, int n) {
  if (rows.length <= n) return rows;
  final out = <List<String>>[];
  final w = rows[0].length + 2;
  for (var r = 0; r < n; r++) {
    final a = (r * rows.length) ~/ n;
    final b = math.max(a + 1, ((r + 1) * rows.length) ~/ n);
    final shift = ((1 - r / (n - 1)) * 2).round();
    final row = List<String>.filled(w, '.');
    for (var c = 0; c < rows[0].length; c++) {
      var best = '.';
      for (var s = a; s < b; s++) {
        if ((_priority[rows[s][c]] ?? 0) > (_priority[best] ?? 0)) best = rows[s][c];
      }
      row[c + shift] = best;
    }
    out.add(row);
  }
  return out;
}

final Map<String, Composed> _composeCache = {};

Composed compose(DinoDef def, String pose, int frame) {
  final key = '${def.id}|$pose|$frame';
  final hit = _composeCache[key];
  if (hit != null) return hit;

  var body = _padRows(frame == 1 && def.alt != null ? def.alt! : def.grid);
  var legH = def.legH;
  if (pose == 'duck') {
    body = _squash(body, 9);
    legH = 4;
  }
  final top = body.length - 1;
  final legsMaxX = def.legs.map((l) => l.x + l.w + 2).reduce(math.max);
  final w = math.max(body[0].length, legsMaxX);
  final h = top + legH;
  final cells = List.generate(h, (_) => List<String>.filled(w, '.'));

  void set(int x, int y, String ch, bool onlyEmpty) {
    if (x < 0 || y < 0 || x >= w || y >= h) return;
    if (onlyEmpty && cells[y][x] != '.') return;
    cells[y][x] = ch;
  }

  void drawLeg(Leg l, bool onlyEmpty) {
    final down = frame == 2 || (frame == 0 ? l.pair == 0 : l.pair == 1);
    final col = l.near ? 'B' : 'D';
    final toe = def.toe;
    if (down) {
      for (var y = top; y < top + legH; y++) {
        for (var x = l.x; x < l.x + l.w; x++) {
          set(x, y, col, onlyEmpty);
        }
      }
      set(l.x + l.w, top + legH - 1, toe, onlyEmpty);
      if (l.near) set(l.x, top + legH - 1, 'D', false);
    } else {
      for (var y = top; y < top + legH - 2; y++) {
        for (var x = l.x + 1; x < l.x + 1 + l.w; x++) {
          set(x, y, col, onlyEmpty);
        }
      }
      set(l.x + l.w + 1, top + legH - 3, toe, onlyEmpty);
    }
  }

  for (final l in def.legs) {
    if (!l.near) drawLeg(l, true);
  }
  for (var y = 0; y < body.length; y++) {
    for (var x = 0; x < body[y].length; x++) {
      if (body[y][x] != '.') cells[y][x] = body[y][x];
    }
  }
  for (final l in def.legs) {
    if (l.near) drawLeg(l, false);
  }

  var eyeX = w - 4, eyeY = 2;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (cells[y][x] == 'W') {
        eyeX = x;
        eyeY = y;
      }
    }
  }
  return _composeCache[key] = Composed(cells, w, h, eyeX, eyeY);
}

// ---------------------------------------------------------------------------
// Hit boxes (auto-generated from the shape)
// ---------------------------------------------------------------------------
final Map<String, List<Rect>> _hitCache = {};

List<Rect> _gridHitboxes(DinoDef def, String pose) {
  final key = '${def.id}|$pose';
  final hit = _hitCache[key];
  if (hit != null) return hit;
  final c = compose(def, pose, 2);
  final out = <Rect>[];
  const slice = 5;
  for (var c0 = 0; c0 < c.w; c0 += slice) {
    var minX = 1 << 30, maxX = -1, minY = 1 << 30, maxY = -1, n = 0;
    for (var y = 0; y < c.h; y++) {
      for (var x = c0; x < math.min(c.w, c0 + slice); x++) {
        if (c.cells[y][x] == '.') continue;
        n++;
        minX = math.min(minX, x);
        maxX = math.max(maxX, x);
        minY = math.min(minY, y);
        maxY = math.max(maxY, y);
      }
    }
    if (n < 5) continue;
    out.add(Rect.fromLTWH((minX + 1).toDouble(), (minY + 1).toDouble(), math.max(1, maxX - minX - 1).toDouble(),
        math.max(1, maxY - minY).toDouble()));
  }
  return _hitCache[key] = out;
}

/// Hit boxes in world coordinates for a dino whose bottom-left is (x, footY).
List<Rect> dinoHitboxes(DinoDef def, String pose, double x, double footY, [double scale = 1]) {
  final c = compose(def, pose, 2);
  return _gridHitboxes(def, pose).map((r) {
    final bx = x + r.left * kScale;
    final by = footY - (c.h - r.top) * kScale;
    return Rect.fromLTWH(
      x + (bx - x) * scale,
      footY - (footY - by) * scale,
      r.width * kScale * scale,
      r.height * kScale * scale,
    );
  }).toList();
}

Size poseSize(DinoDef def, String pose) {
  final c = compose(def, pose, 2);
  return Size(c.w * kScale, c.h * kScale);
}

/// Eye position relative to (x, footY).
Offset headAnchor(DinoDef def, String pose) {
  final c = compose(def, pose, 2);
  return Offset(c.eyeX * kScale, -(c.h - c.eyeY) * kScale);
}

// ---------------------------------------------------------------------------
// Palette & sprite pictures
// ---------------------------------------------------------------------------
class SpriteOpts {
  const SpriteOpts({
    this.classic = false,
    this.fg = const Color(0xFF535353),
    this.bg = const Color(0xFFF7F7F7),
    this.dead = false,
    this.locked = false,
    this.tint,
  });
  final bool classic, dead, locked;
  final Color fg, bg;
  final String? tint;

  String get key => '${classic ? 1 : 0}|${fg.toARGB32()}|${bg.toARGB32()}|${dead ? 1 : 0}|${locked ? 1 : 0}|${tint ?? ''}';
}

const Map<String, Map<String, Color>> _tints = {
  'steel': {
    'B': Color(0xFF9FB3C8),
    'L': Color(0xFFE3EBF3),
    'D': Color(0xFF5D7186),
    'A': Color(0xFF7B8FA3),
    'H': Color(0xFFFFFFFF),
    'R': Color(0xFF7B8FA3),
  },
};

Map<String, Color> _makePalette(DinoDef def, SpriteOpts o) {
  if (o.locked) {
    const c = Color(0xFF2B2B3A), d = Color(0xFF22222E);
    return {'B': c, 'L': c, 'D': d, 'A': d, 'H': d, 'R': d, 'W': c, 'K': c, 'M': c};
  }
  if (o.classic) {
    return {
      'B': o.fg, 'L': o.fg, 'D': o.fg, 'A': o.fg, 'H': o.fg, 'R': o.fg,
      'W': o.dead ? o.fg : o.bg,
      'K': o.dead ? o.bg : o.fg,
      'M': o.bg,
    };
  }
  final c = def.colors;
  final p = <String, Color>{
    'B': c.body,
    'L': c.belly,
    'D': c.dark,
    'A': c.accent,
    'H': c.horn,
    'R': c.crest ?? c.accent,
    'W': o.dead ? const Color(0xFF1A1A1A) : const Color(0xFFFFFFFF),
    'K': o.dead ? const Color(0xFFFFFFFF) : const Color(0xFF1A1A1A),
    'M': const Color(0xFF5A1A1A),
  };
  if (o.tint != null && _tints.containsKey(o.tint)) p.addAll(_tints[o.tint]!);
  return p;
}

class Sprite {
  Sprite(this.picture, this.w, this.h);
  final ui.Picture picture;
  final double w, h;
}

final Map<String, Sprite> _spriteCache = {};

Sprite getSprite(DinoDef def, String pose, int frame, [SpriteOpts opts = const SpriteOpts()]) {
  final key = '${def.id}|$pose|$frame|${opts.key}';
  final hit = _spriteCache[key];
  if (hit != null) return hit;
  if (_spriteCache.length > 600) _spriteCache.clear();

  final c = compose(def, pose, frame);
  final pal = _makePalette(def, opts);
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  final paints = <String, Paint>{
    for (final e in pal.entries) e.key: Paint()..color = e.value..isAntiAlias = false,
  };
  for (var y = 0; y < c.h; y++) {
    for (var x = 0; x < c.w; x++) {
      final ch = c.cells[y][x];
      if (ch == '.') continue;
      final p = paints[ch];
      if (p == null) continue;
      canvas.drawRect(Rect.fromLTWH(x * kScale, y * kScale, kScale, kScale), p);
    }
  }
  return _spriteCache[key] = Sprite(rec.endRecording(), c.w * kScale, c.h * kScale);
}

/// Draw the dino with its bottom-left at ([x], [footY]).
void drawDino(Canvas canvas, DinoDef def, String pose, int frame, double x, double footY, [SpriteOpts opts = const SpriteOpts()]) {
  final s = getSprite(def, pose, frame, opts);
  canvas.save();
  canvas.translate(x.roundToDouble(), (footY - s.h).roundToDouble());
  canvas.drawPicture(s.picture);
  canvas.restore();
}

/// Draw a dino centered inside [size] (menu, collection, hatch).
void paintDinoPreview(Canvas canvas, Size size, DinoDef def,
    {bool locked = false, bool classic = false, int frame = 2}) {
  final s = getSprite(def, 'stand', frame, SpriteOpts(locked: locked, classic: classic));
  final k = math.min((size.width - 8) / s.w, (size.height - 8) / s.h);
  final scale = k >= 1 ? (k * 2).floorToDouble() / 2 : k;
  canvas.save();
  canvas.translate((size.width - s.w * scale) / 2, (size.height - s.h * scale) / 2);
  canvas.scale(scale);
  canvas.drawPicture(s.picture);
  canvas.restore();
}

// Core game: physics, spawning, abilities, SUPER POWERS, power-ups and rendering
// for both the monochrome "Classic" (offline) mode and the colorful "Jurassic"
// (online) mode.
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show FontWeight, HSLColor;

import 'audio.dart';
import 'ctx.dart';
import 'dinos.dart';
import 'entities.dart';
import 'world.dart';

const double kGravity = 2600;
const double kJumpV = 760;
const double kStartSpeed = 360;
const double kAccel = 4.2;
const double kMaxSpeedClassic = 780;
const double kMaxSpeedColor = 880;
const double kScoreK = 0.025;
const double kBiomeLen = 600;
const double kModeTransition = 1.2; // seconds

/// How the SUPER meter fills (1 = full).
const double kSuperStart = 0.25, kSuperPerSecond = 0.012, kSuperCoin = 0.012, kSuperSmash = 0.04, kSuperPower = 0.1;

enum GameState { idle, running, paused, over }

class GameOverInfo {
  const GameOverInfo({required this.score, required this.best, required this.newBest, required this.coins, required this.colorful});
  final int score, best, coins;
  final bool newBest, colorful;
}

/// What the on-screen buttons need to know; updated only when it changes.
@immutable
class HudInfo {
  const HudInfo({
    this.abilityName = '',
    this.abilityReady = true,
    this.abilityPct = 1,
    this.superName = '',
    this.superPct = 0,
    this.superFull = false,
    this.superActive = false,
  });
  final String abilityName, superName;
  final bool abilityReady, superFull, superActive;
  final double abilityPct, superPct;

  @override
  bool operator ==(Object other) =>
      other is HudInfo &&
      other.abilityName == abilityName &&
      other.superName == superName &&
      other.abilityReady == abilityReady &&
      other.superFull == superFull &&
      other.superActive == superActive &&
      (other.abilityPct * 40).round() == (abilityPct * 40).round() &&
      (other.superPct * 100).round() == (superPct * 100).round();

  @override
  int get hashCode => Object.hash(abilityName, superName, abilityReady, superFull, superActive, (abilityPct * 40).round(), (superPct * 100).round());
}

class DinoState {
  double x = 44, y = 0, vy = 0;
  bool onGround = true, dead = false, ducking = false;
  int jumps = 0, frame = 0;
  double frameT = 0;
}

class Fx {
  double magnet = 0, doubleCoins = 0, rocket = 0, dash = 0, charge = 0, invuln = 0, rise = 0, dive = 0, frill = 0, superT = 0;
  bool soar = false, slam = false;
}

class GameBanner {
  GameBanner(this.text, this.sub);
  final String text, sub;
  double t = 0;
}

final math.Random _rng = math.Random();
double rand(double a, double b) => a + _rng.nextDouble() * (b - a);
T pick<T>(List<T> l) => l[_rng.nextInt(l.length)];
double _clamp(double v, double a, double b) => v < a ? a : (v > b ? b : v);
double _ease(double t) => t < 0.5 ? 2 * t * t : 1 - math.pow(-2 * t + 2, 2) / 2;
bool _circleHitsRect(double cx, double cy, double r, Rect b) {
  final nx = _clamp(cx, b.left, b.right), ny = _clamp(cy, b.top, b.bottom);
  return (cx - nx) * (cx - nx) + (cy - ny) * (cy - ny) < r * r;
}

class Game {
  Game({this.onGameOver});

  void Function(GameOverInfo info)? onGameOver;

  /// Buttons listen to this.
  final ValueNotifier<HudInfo> hud = ValueNotifier(const HudInfo());

  bool colorful = false;
  double modeT = 0;
  GameState state = GameState.idle;
  DinoDef def = getDino('rex');
  int bestClassic = 0, bestColor = 0;
  bool inputJump = false, inputDuck = false;
  double time = 0, scroll = 0, nightT = 0;
  int biomeIdx = 0, biomeFrom = 0;
  double biomeT = 1;
  GameBanner? banner;
  List<Particle> particles = [];

  // world size (logical units)
  double W = 600, H = 260, gy = 226, k = 1;
  Size _size = Size.zero;
  bool _ready = false;

  // run state
  double speed = kStartSpeed, dist = 0, bonus = 0, score = 0, runTime = 0;
  List<Obstacle> obstacles = [];
  List<Coin> coins = [];
  List<Powerup> powerups = [];
  List<Bone> bones = [];
  List<Ring> rings = [];
  List<Shot> shots = [];
  List<Bolt> bolts = [];
  List<Ally> allies = [];
  double nextSpawn = 0, nextPower = 0, nextBone = 0, rocketCoinT = 0;
  DinoState d = DinoState();
  Fx fx = Fx();
  bool shield = false;
  double abilityCd = 0, superMeter = kSuperStart;
  String? superId;
  double superTimer = 0, superAngle = 0, stormFlash = 0;
  int runCoins = 0, milestone = 0;
  double flashT = 0, shake = 0, scoreBlink = 0, overT = 0;

  // ------------------------------------------------------------------ setup
  void resize(Size size) {
    if (size == _size || size.isEmpty) return;
    _size = size;
    final aspect = size.width / size.height;
    final newW = _clamp((260 * aspect).roundToDouble(), 420, 900);
    k = size.width / newW;
    W = newW;
    H = size.height / k;
    final oldGy = gy;
    gy = aspect < 1 ? (H * 0.62).roundToDouble() : H - 34;
    if (_ready) {
      final dy = gy - oldGy;
      d.y += dy;
      for (final o in obstacles) {
        o.y += dy;
      }
      for (final c in coins) {
        c.y += dy;
      }
      for (final p in powerups) {
        p.y += dy;
      }
      for (final b in bones) {
        b.y += dy;
      }
      for (final p in particles) {
        p.y += dy;
      }
      for (final a in allies) {
        a.y += dy;
      }
    } else {
      reset();
    }
  }

  void setDino(String id) {
    def = getDino(id);
    _pushHud(force: true);
  }

  void setBest(int classic, int color) {
    bestClassic = classic;
    bestColor = color;
  }

  void setColorful(bool v, {bool animate = true}) {
    if (v == colorful) return;
    colorful = v;
    if (!animate) modeT = v ? 1 : 0;
    if (v) {
      _showBanner('JURASSIC MODE', 'Internet connected — colors & powers unlocked!');
      biomeIdx = biomeFrom = (score / kBiomeLen).floor() % kBiomes.length;
      biomeT = 1;
    } else {
      _showBanner('CLASSIC MODE', 'No internet — back to basics');
      // power-ups & super powers only exist in the connected world
      fx = Fx();
      endSuper(silent: true);
      shield = false;
      coins = [];
      powerups = [];
      shots = [];
    }
    if (state == GameState.running) {
      flashT = 0.6;
      fx.invuln = math.max(fx.invuln, 1.5); // grace period while the world transforms
    }
  }

  void reset() {
    speed = kStartSpeed;
    dist = 0;
    bonus = 0;
    score = 0;
    runTime = 0;
    obstacles = [];
    coins = [];
    powerups = [];
    bones = [];
    rings = [];
    shots = [];
    bolts = [];
    allies = [];
    nextSpawn = W * 0.55;
    nextPower = rand(1500, 2600);
    nextBone = rand(2500, 4500);
    rocketCoinT = 0;
    d = DinoState()..y = gy;
    fx = Fx();
    shield = false;
    abilityCd = 0;
    superMeter = kSuperStart;
    superId = null;
    superTimer = 0;
    superAngle = 0;
    stormFlash = 0;
    runCoins = 0;
    milestone = 0;
    flashT = 0;
    shake = 0;
    scoreBlink = 0;
    biomeIdx = biomeFrom = 0;
    biomeT = 1;
    nightT = 0;
    overT = 0;
    particles = [];
    _ready = true;
    _pushHud(force: true);
  }

  void start() {
    reset();
    state = GameState.running;
    if (colorful) _showBanner(kBiomes[0].name.toUpperCase(), 'Zone 1');
  }

  void toMenu() {
    state = GameState.idle;
    reset();
  }

  void pause() {
    if (state == GameState.running) {
      state = GameState.paused;
      inputJump = inputDuck = false;
    }
  }

  void resume() {
    if (state == GameState.paused) state = GameState.running;
  }

  void _showBanner(String text, String sub) => banner = GameBanner(text, sub);

  bool isSuper(String id) => fx.superT > 0 && superId == id;

  String get pose => d.ducking ? 'duck' : 'stand';

  Offset head() {
    final a = headAnchor(def, pose);
    final s = isSuper('giant') ? 2.0 : 1.0;
    return Offset(d.x + a.dx * s, d.y + a.dy * s);
  }

  Offset center() {
    final sz = poseSize(def, pose);
    final s = isSuper('giant') ? 2.0 : 1.0;
    return Offset(d.x + sz.width * s / 2, d.y - sz.height * s / 2);
  }

  // ------------------------------------------------------------------ input
  void jumpPress() {
    inputJump = true;
    if (state != GameState.running) return;
    if (isSuper('storm')) {
      d.vy = -430;
      d.onGround = false;
      sfx.play('jump', colorful: true);
      _puff(d.x + 10, d.y - 10, 4, const Color(0xFFFFFFFF));
      return;
    }
    if (fx.rocket > 0 || isSuper('wave')) return;
    if (d.onGround) {
      d.vy = -kJumpV;
      d.onGround = false;
      d.jumps = 1;
      sfx.play('jump', colorful: colorful);
      if (colorful) _puff(d.x + 14, d.y, 6, const Color(0xAAFFFFFF));
    } else if (colorful && def.passive == 'doubleJump' && d.jumps < 2) {
      d.vy = -kJumpV * 0.88;
      d.jumps = 2;
      sfx.play('jump', colorful: true);
      _puff(d.x + 14, d.y, 10, const Color(0xFFFFFFFF));
    }
  }

  void jumpRelease() => inputJump = false;
  void duck(bool v) => inputDuck = v;

  double get abilityPct => def.ability.cd > 0 ? 1 - abilityCd / def.ability.cd : 1;
  double get superPct => fx.superT > 0 ? fx.superT / def.superPower.dur : superMeter;

  void _pushHud({bool force = false}) {
    final h = HudInfo(
      abilityName: def.ability.name,
      abilityReady: abilityCd <= 0,
      abilityPct: abilityPct,
      superName: def.superPower.name,
      superPct: superPct,
      superFull: superMeter >= 1,
      superActive: fx.superT > 0,
    );
    if (force || h != hud.value) hud.value = h;
  }

  bool useAbility() {
    if (!colorful || state != GameState.running || abilityCd > 0) return false;
    final a = def.ability;
    abilityCd = a.cd;
    sfx.play('ability', colorful: true);
    buzz();
    final c = center();
    rings.add(Ring(c.dx, c.dy, 120, def.colors.accent, 0.5));
    switch (a.id) {
      case 'roar':
        rings.add(Ring(c.dx, c.dy, 320, const Color(0xFFFFFFFF), 0.6));
        for (final o in obstacles) {
          if (o.x < d.x + 340 && o.x + o.w > d.x - 10) destroy(o);
        }
        shake = 8;
      case 'dash':
        fx.dash = 1.4;
      case 'shield':
        shield = true;
      case 'superjump':
        d.vy = -kJumpV * 1.5;
        d.onGround = false;
        d.jumps = 2;
        fx.rise = 0.8;
        _puff(d.x + 14, d.y, 14, const Color(0xFFFFFFFF));
      case 'charge':
        fx.charge = 3;
      case 'echo':
        fx.magnet = math.max(fx.magnet, 8);
        fx.doubleCoins = math.max(fx.doubleCoins, 8);
      case 'quake':
        if (d.onGround) {
          _quake();
        } else {
          fx.slam = true;
          d.vy = math.max(d.vy, 900);
        }
      case 'soar':
        fx.rocket = 3;
        fx.soar = true;
      case 'dive':
        fx.dive = 1.8;
        if (!d.onGround) d.vy = math.max(d.vy, 1000);
        sfx.play('splash', colorful: true);
        _splash(c.dx, gy, 16);
      case 'sweep':
        final h = head();
        rings.add(Ring(h.dx, h.dy, 420, const Color(0xFFFFE082), 0.6));
        for (final o in obstacles) {
          if ((o.kind == ObstacleKind.flyer || o.kind == ObstacleKind.meteor) && o.x < W + 20) destroy(o);
        }
        fx.magnet = math.max(fx.magnet, 4);
      case 'spit':
        final h = head();
        fx.frill = 0.6;
        // aim at the nearest obstacle ahead (the glob flies in a straight line)
        Obstacle? target;
        for (final o in obstacles) {
          if (!o.dead && o.flung == null && o.x + o.w > h.dx && (target == null || o.x < target.x)) target = o;
        }
        var vy = -20.0;
        if (target != null) {
          final t = math.max(0.05, (target.x + target.w / 2 - (h.dx + 8)) / (720 + speed));
          vy = ((target.y + target.h / 2) - (h.dy + 4)) / t;
        }
        shots.add(Shot.venom(x: h.dx + 8, y: h.dy + 4, vx: 720, vy: vy, life: 1.6));
    }
    _text(c.dx, c.dy - 40, '${a.name.toUpperCase()}!', const Color(0xFFFFFFFF), 14);
    _pushHud();
    return true;
  }

  bool useSuper() {
    if (!colorful || state != GameState.running || superMeter < 1 || fx.superT > 0) return false;
    final s = def.superPower;
    superMeter = 0;
    fx.superT = s.dur;
    superId = s.id;
    superTimer = 0;
    _showBanner(s.name.toUpperCase(), '⚡ SUPER POWER ⚡');
    flashT = 0.5;
    shake = 10;
    sfx.play('super', colorful: true);
    buzz(heavy: true);
    final c = center();
    const cols = [Color(0xFFFF5252), Color(0xFFFFD740), Color(0xFF40C4FF)];
    for (var i = 0; i < 3; i++) {
      rings.add(Ring(c.dx, c.dy, 200.0 + i * 120, cols[i], 0.5 + i * 0.15));
    }
    if (s.id == 'pack') {
      allies = [for (var i = 0; i < 3; i++) Ally(kind: 'raptor', i: i, x: -40.0 - i * 40, y: gy)];
    } else if (s.id == 'stampede') {
      allies = [for (var i = 0; i < 6; i++) Ally(kind: 'tricera', i: i, x: -70.0 - i * 75, y: gy, sp: rand(420, 560))..frame = i % 2];
    } else if (s.id == 'storm') {
      d.vy = -520;
      d.onGround = false;
    }
    _pushHud();
    return true;
  }

  void endSuper({bool silent = false}) {
    if (superId != null && !silent) fx.invuln = math.max(fx.invuln, 1);
    fx.superT = 0;
    superId = null;
    allies = [];
  }

  void _quake() {
    shake = 14;
    sfx.play('smash', colorful: true);
    buzz(heavy: true);
    for (final o in obstacles) {
      if (o.kind != ObstacleKind.flyer && o.x < W) destroy(o);
    }
    for (var i = 0; i < 30; i++) {
      particles.add(Particle(
          x: rand(0, W), y: gy, vx: rand(-40, 40), vy: rand(-260, -80), g: 900, life: rand(0.4, 0.8), max: 0.8, size: rand(2, 4), color: const Color(0xFFA1887F)));
    }
  }

  // ------------------------------------------------------------------ update
  void update(double rawDt) {
    final dt = math.min(0.05, rawDt);
    if (state == GameState.paused) return;
    time += dt;
    final target = colorful ? 1.0 : 0.0;
    if (modeT != target) {
      modeT = _clamp(modeT + (target - modeT).sign * (dt / kModeTransition), 0, 1);
    }
    final wantNight = !colorful && state != GameState.idle && (score / 700).floor() % 2 == 1;
    nightT = _clamp(nightT + (wantNight ? dt : -dt) / 1.2, 0, 1);
    if (banner != null) {
      banner!.t += dt;
      if (banner!.t > 2.6) banner = null;
    }
    flashT = math.max(0, flashT - dt);
    shake = math.max(0, shake - dt * 30);
    scoreBlink = math.max(0, scoreBlink - dt);
    stormFlash = math.max(0, stormFlash - dt);
    biomeT = math.min(1, biomeT + dt / 2.5);

    if (state != GameState.running) {
      if (state == GameState.idle && colorful) scroll += 30 * dt; // gentle menu ambience
      if (state == GameState.over) overT += dt;
      _updateParticles(dt);
      if (colorful) _weather(dt);
      return;
    }

    final prevRocket = fx.rocket;
    fx.magnet = math.max(0, fx.magnet - dt);
    fx.doubleCoins = math.max(0, fx.doubleCoins - dt);
    fx.rocket = math.max(0, fx.rocket - dt);
    fx.dash = math.max(0, fx.dash - dt);
    fx.charge = math.max(0, fx.charge - dt);
    fx.invuln = math.max(0, fx.invuln - dt);
    fx.rise = math.max(0, fx.rise - dt);
    fx.dive = math.max(0, fx.dive - dt);
    fx.frill = math.max(0, fx.frill - dt);
    if (prevRocket > 0 && fx.rocket <= 0) {
      fx.invuln = math.max(fx.invuln, 0.9);
      fx.soar = false;
    }
    if (fx.superT > 0) {
      fx.superT -= dt;
      if (fx.superT <= 0) endSuper();
    } else if (colorful) {
      superMeter = math.min(1, superMeter + kSuperPerSecond * dt);
    }
    abilityCd = math.max(0, abilityCd - dt);

    runTime += dt;
    speed = math.min(colorful ? kMaxSpeedColor : kMaxSpeedClassic, speed + kAccel * dt);
    var boost = 1.0;
    if (fx.dash > 0) {
      boost = 1.6;
    } else if (isSuper('ball')) {
      boost = 1.3;
    } else if (isSuper('wave') || isSuper('stampede')) {
      boost = 1.2;
    }
    final dx = speed * boost * dt;
    dist += dx;
    scroll += dx;
    score = dist * kScoreK + bonus;

    final m = (score / 100).floor();
    if (m > milestone) {
      milestone = m;
      sfx.play('point', colorful: colorful);
      if (!colorful) scoreBlink = 0.9;
    }
    final bi = (score / kBiomeLen).floor() % kBiomes.length;
    if (bi != biomeIdx) {
      biomeFrom = biomeIdx;
      biomeIdx = bi;
      biomeT = 0;
      if (colorful && fx.superT <= 0) _showBanner(kBiomes[bi].name.toUpperCase(), 'Zone ${(score / kBiomeLen).floor() + 1}');
    }

    _updateDino(dt);
    _spawn(dx, dt);
    _moveEntities(dx, dt);
    if (fx.superT > 0) _updateSuper(dt, dx);
    _updateShots(dt, dx);
    if (state != GameState.running) {
      _pushHud();
      return;
    }
    _collide();
    _updateParticles(dt);
    if (colorful) _weather(dt);
    _pushHud();
  }

  void _updateDino(double dt) {
    if (fx.rocket > 0 || isSuper('wave')) {
      final surf = isSuper('wave');
      final target = surf ? gy - 44 + math.sin(time * 5) * 5 : gy - 110 + math.sin(time * 4) * 6;
      d.y += (target - d.y) * math.min(1, dt * 5);
      d.vy = 0;
      d.onGround = false;
      d.jumps = 1;
      if (!surf && !fx.soar && _rng.nextDouble() < 0.8) {
        particles.add(Particle(
            x: d.x + 6, y: d.y - 14, vx: rand(-220, -120), vy: rand(-30, 30), life: 0.35, size: rand(2, 5),
            color: pick(const [Color(0xFFFFEB3B), Color(0xFFFF9800), Color(0xFFFF5722)])));
      }
    } else {
      final storm = isSuper('storm');
      var g = storm ? 1100.0 : kGravity;
      if (!storm && inputJump && d.vy < 0) g *= 0.65;
      if (!storm && inputDuck && !d.onGround) g *= 3;
      d.vy += g * dt;
      if (storm) d.vy = math.min(d.vy, 420);
      if (colorful && def.id == 'ptero' && inputJump && d.vy > 140 && !storm) d.vy = 140; // glide
      if (fx.slam) d.vy = math.max(d.vy, 1400);
      d.y += d.vy * dt;
      if (d.y < 50) {
        d.y = 50;
        d.vy = math.max(d.vy, 0);
      }
      if (d.y >= gy) {
        if (!d.onGround) {
          if (colorful) _puff(d.x + 16, gy, 5, const Color(0x99FFFFFF));
          if (fx.slam) {
            fx.slam = false;
            _quake();
          }
          if (isSuper('ball')) {
            shake = math.max(shake, 4);
            _puff(d.x + 20, gy, 10, const Color(0xFFD7CCC8));
          }
        }
        d.y = gy;
        d.vy = 0;
        d.onGround = true;
        d.jumps = 0;
        if (isSuper('ball')) {
          d.vy = -640;
          d.onGround = false;
        }
      } else {
        d.onGround = false;
      }
    }
    d.ducking = inputDuck && d.onGround && fx.rocket <= 0 && !isSuper('ball') && !isSuper('giant');
    d.frameT += dt * (speed / 360);
    if (d.frameT > 0.1) {
      d.frameT = 0;
      d.frame ^= 1;
      if (isSuper('giant') && d.onGround) {
        shake = math.max(shake, 3);
        _puff(d.x + 30, gy, 3, const Color(0xFFBCAAA4));
      }
    }
    if ((fx.dash > 0 || fx.charge > 0) && _rng.nextDouble() < 0.9) {
      particles.add(Particle(x: d.x + rand(0, 10), y: d.y - rand(4, 36), vx: rand(-260, -160), vy: rand(-20, 20), life: 0.3, size: rand(2, 4), color: def.colors.accent));
    }
  }

  // ------------------------------------------------------------------ SUPER POWERS
  void _updateSuper(double dt, double dx) {
    superTimer -= dt;
    bool tick(double interval) {
      if (superTimer <= 0) {
        superTimer = interval;
        return true;
      }
      return false;
    }

    final live = obstacles.where((o) => !o.dead && o.flung == null).toList();
    switch (superId) {
      case 'giant': // T. rex — coin rain while giant
        if (tick(0.12)) coins.add(Coin(rand(W * 0.3, W), -10, vy: rand(220, 320)));

      case 'pack': // Velociraptor — allies pounce on obstacles ahead
        for (final a in allies) {
          final home = d.x + 90 + a.i * 55;
          if (a.target != null && (a.target!.dead || a.target!.x + a.target!.w < a.x - 40)) a.target = null;
          if (a.target == null) {
            Obstacle? o;
            for (final c in live) {
              if (!c.claimed && c.x < a.x + 230 && c.x + c.w > a.x - 10) {
                o = c;
                break;
              }
            }
            if (o != null) {
              o.claimed = true;
              a.target = o;
              a.vy = o.kind == ObstacleKind.ground ? -560 : -820;
              sfx.play('chomp', colorful: true);
            } else {
              a.x += (home - a.x) * math.min(1, dt * 3);
            }
          }
          if (a.target != null) {
            final o = a.target!;
            a.x += (o.x + o.w / 2 - 24 - a.x) * math.min(1, dt * 9);
            if (Rect.fromLTWH(a.x, a.y - 36, 54, 36).overlaps(_hitbox(o))) {
              destroy(o);
              bonus += 5;
              _text(o.x + o.w / 2, o.y - 10, 'CHOMP!', const Color(0xFFFF8A65), 12);
              a.target = null;
            }
          }
          a.vy += 2200 * dt;
          a.y += a.vy * dt;
          if (a.y >= gy) {
            a.y = gy;
            a.vy = 0;
          }
          a.frameT += dt;
          if (a.frameT > 0.09) {
            a.frameT = 0;
            a.frame ^= 1;
          }
        }

      case 'orbit': // Stegosaurus — spinning plates shred anything close
        superAngle += dt * 7;
        final c = center();
        for (final o in live) {
          if (_circleHitsRect(c.dx, c.dy, 60, _hitbox(o))) {
            destroy(o);
            bonus += 5;
          }
        }

      case 'ball': // Pachycephalosaurus — spinning bouncing skull
        superAngle += dt * 16;

      case 'stampede': // Triceratops — a herd runs over everything
        for (final a in allies) {
          a.x += a.sp * dt;
          a.frameT += dt;
          if (a.frameT > 0.08) {
            a.frameT = 0;
            a.frame ^= 1;
          }
          if (a.x > W + 80 && fx.superT > 1) a.x = -80 - rand(0, 120);
          if (_rng.nextDouble() < 0.5) {
            particles.add(Particle(x: a.x + 5, y: gy - 2, vx: rand(-120, -40), vy: rand(-60, -10), life: 0.4, size: rand(2, 4), color: const Color(0xFFBCAAA4)));
          }
          final box = Rect.fromLTWH(a.x, gy - 30, 60, 30);
          for (final o in live) {
            if (!o.dead && box.overlaps(_hitbox(o))) {
              destroy(o);
              bonus += 5;
            }
          }
        }
        if (_rng.nextDouble() < dt * 8) shake = math.max(shake, 2);

      case 'midas': // Parasaurolophus — obstacles turn into gold
        for (final o in live) {
          if (o.x < W - 20 && o.x + o.w > 0) {
            o.dead = true;
            final cx = o.x + o.w / 2, cy = o.kind == ObstacleKind.ground ? gy - 20 : o.y + o.h / 2;
            for (var i = 0; i < 5; i++) {
              coins.add(Coin(cx + (i - 2) * 14, cy - (i - 2).abs() * -6 - 10));
            }
            for (var i = 0; i < 10; i++) {
              _sparkle(cx, cy, pick(const [Color(0xFFFFD54F), Color(0xFFFFF59D), Color(0xFFFFFFFF)]));
            }
            sfx.play('coin', colorful: true);
          }
        }
        if (tick(0.14)) {
          final h = head();
          particles.add(Particle(
              x: h.dx - 6, y: h.dy - 14, vx: rand(-60, 30), vy: rand(-90, -50), life: 1.1, size: 14, text: pick(const ['♪', '♫', '♬']),
              color: pick(const [Color(0xFFFFD54F), Color(0xFFFF8A80), Color(0xFF80D8FF), Color(0xFFB9F6CA)])));
        }

      case 'fortress': // Ankylosaurus — handled in collisions (pinball)
        break;

      case 'storm': // Pteranodon — lightning on everything ahead
        if (tick(0.38)) {
          final ahead = live.where((o) => o.x > d.x && o.x < W).toList()..sort((a, b) => a.x.compareTo(b.x));
          final h = head();
          if (ahead.isNotEmpty) {
            final o = ahead.first;
            bolts.add(Bolt(h.dx, h.dy, o.x + o.w / 2, o.y + o.h / 2, 0.25, rand(0, 100)));
            destroy(o);
            bonus += 5;
            sfx.play('zap', colorful: true);
            stormFlash = 0.12;
          } else if (_rng.nextDouble() < 0.3) {
            final x = rand(W * 0.3, W);
            bolts.add(Bolt(x + rand(-30, 30), 0, x, gy, 0.2, rand(0, 100)));
            stormFlash = 0.08;
          }
        }
        for (var i = 0; i < 3; i++) {
          particles.add(Particle(x: rand(0, W + 100), y: -5, vx: -160, vy: 650, life: 0.8, size: 1, color: const Color(0xFFB3E5FC), rain: true));
        }

      case 'wave': // Spinosaurus — tsunami surf
        for (final o in live) {
          if (o.x < d.x + 120) {
            destroy(o);
            bonus += 5;
            _splash(o.x, gy - 10, 10);
          }
        }
        if (_rng.nextDouble() < dt * 4) {
          particles.add(Particle(x: rand(d.x + 60, d.x + 160), y: gy - 10, vx: rand(-120, 60), vy: rand(-420, -300), g: 1200, life: 1, size: 14, text: '🐟'));
        }
        if (_rng.nextDouble() < 0.7) _splash(d.x + rand(60, 100), gy - 40 + rand(-10, 10), 1);

      case 'meteors': // Brachiosaurus — meteor shower on obstacles
        if (tick(0.24)) {
          Obstacle? o;
          for (final c in live) {
            if (!c.claimed && c.x > d.x + 50 && c.x < W + 40) {
              o = c;
              break;
            }
          }
          final tx = o != null ? o.x + o.w / 2 : rand(d.x + 160, W);
          o?.claimed = true;
          shots.add(Shot.fireball(sx: tx + 160, sy: -30, tx: tx, ty: gy - 8, dur: 0.45));
        }

      case 'toxic': // Dilophosaurus — poison fog ahead
        fx.frill = 0.2;
        final x0 = d.x + 60, x1 = d.x + 330;
        for (final o in live) {
          if (o.x < x1 && o.x + o.w > x0) {
            o.dead = true;
            bonus += 5;
            for (var i = 0; i < 14; i++) {
              particles.add(Particle(
                  x: o.x + rand(0, o.w), y: o.y + rand(0, o.h), vx: rand(-30, 30), vy: rand(-90, -20), life: rand(0.5, 0.9), max: 0.9, size: rand(2, 4), circle: true,
                  color: pick(const [Color(0xFF76FF03), Color(0xFFB2FF59), Color(0xFF33691E)])));
            }
            _text(o.x + o.w / 2, o.y - 6, 'MELT!', const Color(0xFFB2FF59), 11);
            sfx.play('splash', colorful: true);
          }
        }
    }
    for (final b in bolts) {
      b.life -= dt;
    }
    bolts.removeWhere((b) => b.life <= 0);
  }

  void _updateShots(double dt, double dx) {
    for (final s in shots) {
      if (s.kind == ShotKind.venom) {
        s.x += s.vx * dt;
        s.y += s.vy * dt;
        s.life -= dt;
        if (_rng.nextDouble() < 0.6) {
          particles.add(Particle(x: s.x, y: s.y, vx: rand(-60, 0), vy: rand(-20, 20), life: 0.3, size: 2, color: const Color(0xFFB2FF59)));
        }
        for (final o in obstacles) {
          if (!o.dead && o.flung == null && Rect.fromLTWH(s.x - 5, s.y - 5, 10, 10).overlaps(_hitbox(o))) {
            o.dead = true;
            s.life = 0;
            for (var i = 0; i < 14; i++) {
              particles.add(Particle(
                  x: o.x + rand(0, o.w), y: o.y + rand(0, o.h), vx: rand(-30, 30), vy: rand(-90, -20), life: 0.7, size: rand(2, 4), circle: true,
                  color: pick(const [Color(0xFF76FF03), Color(0xFFB2FF59)])));
            }
            _text(o.x + o.w / 2, o.y - 6, 'MELT!', const Color(0xFFB2FF59), 11);
            sfx.play('splash', colorful: true);
            superMeter = math.min(1, superMeter + kSuperSmash);
            break;
          }
        }
        if (s.y > gy) s.life = 0;
      } else {
        s.tx -= dx;
        s.sx -= dx;
        s.t += dt;
        final kk = math.min(1.0, s.t / s.dur);
        s.x = s.sx + (s.tx - s.sx) * kk;
        s.y = s.sy + (s.ty - s.sy) * kk;
        if (_rng.nextDouble() < 0.9) {
          particles.add(Particle(
              x: s.x, y: s.y, vx: rand(20, 80), vy: rand(-60, -10), life: 0.35, size: rand(2, 5),
              color: pick(const [Color(0xFFFFEB3B), Color(0xFFFF9800), Color(0xFFFF5722)])));
        }
        if (kk >= 1) {
          s.life = 0;
          shake = math.max(shake, 6);
          sfx.play('smash', colorful: true);
          rings.add(Ring(s.tx, gy - 8, 60, const Color(0xFFFF9800), 0.35)..r = 6);
          for (var i = 0; i < 16; i++) {
            particles.add(Particle(
                x: s.tx, y: gy - 6, vx: rand(-200, 200), vy: rand(-380, -80), g: 900, life: rand(0.4, 0.8), max: 0.8, size: rand(2, 5),
                color: pick(const [Color(0xFFFFEB3B), Color(0xFFFF9800), Color(0xFFFF5722), Color(0xFF5D4037)])));
          }
          for (final o in obstacles) {
            if (!o.dead && (o.x + o.w / 2 - s.tx).abs() < 60) {
              destroy(o);
              bonus += 5;
            }
          }
        }
      }
    }
    shots.removeWhere((s) => s.life <= 0 || s.x < -50 || s.x > W + 300);
  }

  // ------------------------------------------------------------------ world
  void _spawn(double dx, double dt) {
    nextSpawn -= dx;
    if (nextSpawn <= 0) {
      _spawnObstacle();
      final min = speed * 0.8 + 90;
      nextSpawn = rand(min, min * 1.9);
    }
    if (colorful) {
      nextPower -= dx;
      if (nextPower <= 0) {
        nextPower = rand(2600, 5200);
        powerups.add(Powerup(pick(kPowerups.keys.toList()), W + 30, gy - rand(55, 95)));
      }
      if (fx.rocket > 0) {
        rocketCoinT -= dt;
        if (rocketCoinT <= 0) {
          rocketCoinT = 0.08;
          coins.add(Coin(W + 10, gy - 96 + math.sin(time * 3) * 16));
        }
      }
    } else {
      nextBone -= dx;
      if (nextBone <= 0) {
        nextBone = rand(4000, 8000);
        bones.add(Bone(W + 20, gy - rand(50, 75)));
      }
    }
  }

  void _spawnObstacle() {
    final sc = score;
    final b = kBiomes[biomeIdx];
    final x = W + 20;
    final r = _rng.nextDouble();
    if (colorful && b.meteors && sc > 200 && r < 0.2) {
      final landX = W * rand(0.5, 0.7);
      final t = (x - landX) / speed;
      final fall = gy - 20 + 40;
      obstacles.add(Obstacle(kind: ObstacleKind.meteor, x: x, y: -40, w: 20, h: 20, vy: fall / t, seed: rand(0, 100)));
      return;
    }
    if (sc > (colorful ? 250 : 400) && r < 0.32) {
      final ufo = colorful && b.ufo;
      final y = pick([gy - 38, gy - 54, gy - 86]);
      obstacles.add(Obstacle(
          kind: ObstacleKind.flyer, x: x, y: y, w: ufo ? 36 : 42, h: 30, seed: rand(0, 100), biome: b, vx: speed * rand(0.05, 0.15)));
      if (colorful && y < gy - 80) _coinLine(x + 4, gy - 16, 3);
      return;
    }
    final large = sc > 80 && _rng.nextDouble() < 0.45;
    final maxN = speed > 700 ? 3 : speed > 480 ? (large ? 2 : 3) : (large ? 1 : 2);
    final n = 1 + _rng.nextInt(maxN);
    final uw = large ? 25.0 : 17.0, h = large ? 50.0 : 35.0;
    final o = Obstacle(
        kind: ObstacleKind.ground, x: x, y: gy - h, w: uw * n, h: h, n: n, seed: rand(0, 100), skin: colorful ? b.obstacle : 'cactus', biome: b);
    obstacles.add(o);
    if (colorful) {
      final r2 = _rng.nextDouble();
      if (r2 < 0.45) {
        for (var i = 0; i < 5; i++) {
          final t = (i - 2) / 2.6;
          coins.add(Coin(o.x + o.w / 2 + (i - 2) * 24, gy - h - 22 - 50 * (1 - t * t)));
        }
      } else if (r2 < 0.75) {
        _coinLine(o.x + o.w + 110, gy - 16, 5);
      }
    }
  }

  void _coinLine(double x, double y, int n) {
    for (var i = 0; i < n; i++) {
      coins.add(Coin(x + i * 20, y));
    }
  }

  Rect _hitbox(Obstacle o) {
    switch (o.kind) {
      case ObstacleKind.flyer:
        return Rect.fromLTWH(o.x + 4, o.y + 6, o.w - 8, o.h - 14);
      case ObstacleKind.meteor:
        return Rect.fromLTWH(o.x + 2, o.y + 2, o.w - 4, o.h - 4);
      case ObstacleKind.ground:
        return Rect.fromLTWH(o.x + 3, o.y + 4, o.w - 6, o.h - 4);
    }
  }

  void _moveEntities(double dx, double dt) {
    for (final o in obstacles) {
      o.x -= dx;
      final f = o.flung;
      if (f != null) {
        o.x += f.vx * dt;
        o.y += f.vy * dt;
        f.vy += 1500 * dt;
        f.rot += f.vr * dt;
        continue;
      }
      if (o.kind == ObstacleKind.flyer && colorful) o.x -= o.vx * dt;
      if (o.kind == ObstacleKind.meteor) {
        o.y += o.vy * dt;
        if (_rng.nextDouble() < 0.5) {
          particles.add(Particle(
              x: o.x + 10, y: o.y + 4, vx: rand(10, 60), vy: rand(-60, -20), life: 0.4, size: rand(2, 4),
              color: pick(const [Color(0xFFFF9800), Color(0xFFFFEB3B), Color(0xFF795548)])));
        }
        if (o.y + o.h >= gy) {
          // impact: becomes a smoking rock on the ground
          o.kind = ObstacleKind.ground;
          o.skin = 'meteorite';
          o.n = 1;
          o.w = 30;
          o.h = 22;
          o.y = gy - 22;
          o.x -= 5;
          shake = math.max(shake, 6);
          sfx.play('smash', colorful: true);
          _puff(o.x + 15, gy, 14, const Color(0xFFFF7043));
        }
      }
    }
    obstacles.removeWhere((o) => o.dead || o.x + o.w < -60 || o.x > W + 400 || o.y > H + 80);

    final c = center();
    final magnet = fx.magnet > 0;
    for (final coin in coins) {
      coin.x -= dx;
      if (coin.vy != 0) {
        coin.y += coin.vy * dt;
        if (coin.y >= gy - 14) {
          coin.y = gy - 14;
          coin.vy = 0;
        }
      }
      if (magnet) {
        final ddx = c.dx - coin.x, ddy = c.dy - coin.y;
        final dd = math.sqrt(ddx * ddx + ddy * ddy);
        if (dd < 280 && dd > 0) {
          coin.x += (ddx / dd) * 650 * dt;
          coin.y += (ddy / dd) * 650 * dt;
        }
      }
    }
    coins.removeWhere((c) => c.taken || c.x < -20);
    for (final p in powerups) {
      p.x -= dx;
    }
    powerups.removeWhere((p) => p.taken || p.x < -30);
    for (final b in bones) {
      b.x -= dx;
    }
    bones.removeWhere((b) => b.taken || b.x < -30);
    for (final r in rings) {
      r.t += dt;
      r.r = 10 + (r.max - 10) * (r.t / r.life);
    }
    rings.removeWhere((r) => r.t >= r.life);
  }

  void _collide() {
    final scale = isSuper('giant') ? 2.0 : 1.0;
    final boxes = dinoHitboxes(def, pose, d.x, d.y, scale);
    for (final o in obstacles) {
      if (o.dead || o.flung != null) continue;
      final hb = _hitbox(o);
      if (!boxes.any((b) => b.overlaps(hb))) continue;
      if (fx.dive > 0) continue; // underground: everything passes over
      if (isSuper('fortress')) {
        _fling(o);
        continue;
      }
      final smash = fx.superT > 0 || fx.dash > 0 || fx.rocket > 0 || fx.rise > 0 || (fx.charge > 0 && o.kind != ObstacleKind.flyer);
      if (smash) {
        destroy(o);
        bonus += 5;
        _text(o.x, o.y - 6, '+5', const Color(0xFFFFE082), 11);
        continue;
      }
      if (fx.invuln > 0) continue;
      if (shield) {
        shield = false;
        fx.invuln = 1;
        destroy(o);
        _text(d.x + 20, d.y - 50, 'SHIELD!', const Color(0xFF4FC3F7), 12);
        continue;
      }
      _die();
      return;
    }
    final c = center();
    final reachX = scale == 2 ? 40.0 : 24.0, reachY = scale == 2 ? 50.0 : 28.0;
    final dbl = fx.doubleCoins > 0;
    for (final coin in coins) {
      if ((coin.x - c.dx).abs() < reachX && (coin.y - c.dy).abs() < reachY) {
        coin.taken = true;
        runCoins += dbl ? 2 : 1;
        if (fx.superT <= 0) superMeter = math.min(1, superMeter + kSuperCoin);
        sfx.play('coin', colorful: true);
        _sparkle(coin.x, coin.y, const Color(0xFFFFD54F));
      }
    }
    for (final p in powerups) {
      if ((p.x - c.dx).abs() < 28 && (p.y - c.dy).abs() < 32) {
        p.taken = true;
        sfx.play('power', colorful: true);
        superMeter = math.min(1, superMeter + kSuperPower);
        final def = kPowerups[p.type]!;
        _text(p.x, p.y - 20, def.name.toUpperCase(), def.color, 12);
        switch (p.type) {
          case 'shield':
            shield = true;
          case 'magnet':
            fx.magnet = 9;
          case 'double':
            fx.doubleCoins = 10;
          case 'rocket':
            fx.rocket = 4.5;
            fx.soar = false;
        }
      }
    }
    for (final b in bones) {
      if ((b.x - c.dx).abs() < 24 && (b.y - c.dy).abs() < 30) {
        b.taken = true;
        bonus += 50;
        sfx.play('bonus', colorful: false);
        _text(b.x, b.y - 14, '+50', null, 12);
      }
    }
  }

  void _fling(Obstacle o) {
    o.flung = Flung(rand(250, 520), rand(-720, -420), rand(-14, 14));
    runCoins += 2;
    bonus += 5;
    sfx.play('smash', colorful: true);
    shake = math.max(shake, 5);
    rings.add(Ring(o.x + o.w / 2, o.y + o.h / 2, 40, const Color(0xFFE3F2FD), 0.25)..r = 4);
    _text(o.x + o.w / 2, o.y - 10, 'BONK! +2🪙', const Color(0xFFE3F2FD), 11);
  }

  static const _debris = <String, List<Color>>{
    'cactus': [Color(0xFF34B257), Color(0xFF1F7A3A)],
    'stump': [Color(0xFF8B5A2B), Color(0xFF4CAF50)],
    'ice': [Color(0xFFFFFFFF), Color(0xFF6EC6FF)],
    'lava': [Color(0xFFFF5722), Color(0xFF3E2723)],
    'crystal': [Color(0xFFEA80FC), Color(0xFF651FFF)],
    'meteorite': [Color(0xFFFF5722), Color(0xFF3E2723)],
  };

  void destroy(Obstacle o) {
    if (o.dead) return;
    o.dead = true;
    sfx.play('smash', colorful: colorful);
    shake = math.max(shake, 4);
    if (colorful && fx.superT <= 0) superMeter = math.min(1, superMeter + kSuperSmash);
    final palette = o.kind == ObstacleKind.flyer
        ? const [Color(0xFFFFFFFF), Color(0xFFBDBDBD)]
        : _debris[o.skin] ?? const [Color(0xFF9E9E9E), Color(0xFF616161)];
    for (var i = 0; i < 16; i++) {
      particles.add(Particle(
          x: o.x + rand(0, o.w), y: o.y + rand(0, o.h), vx: rand(-60, 260), vy: rand(-320, -60), g: 900, life: rand(0.4, 0.8), max: 0.8, size: rand(2, 5), color: pick(palette)));
    }
  }

  void _die() {
    d.dead = true;
    state = GameState.over;
    overT = 0;
    shake = 10;
    inputJump = inputDuck = false;
    endSuper(silent: true);
    sfx.play('hit', colorful: colorful);
    buzz(heavy: true);
    final sc = score.floor();
    final best = colorful ? bestColor : bestClassic;
    final newBest = sc > best;
    if (newBest) {
      if (colorful) {
        bestColor = sc;
      } else {
        bestClassic = sc;
      }
    }
    if (colorful) {
      for (var i = 0; i < 20; i++) {
        _sparkle(d.x + 20, d.y - 20, pick(const [Color(0xFFFF5252), Color(0xFFFFD54F), Color(0xFFFFFFFF)]));
      }
    }
    _pushHud(force: true);
    onGameOver?.call(GameOverInfo(
        score: sc, best: colorful ? bestColor : bestClassic, newBest: newBest, coins: colorful ? runCoins : 0, colorful: colorful));
  }

  /// Test/debug helper.
  void debugDie() => _die();

  // ------------------------------------------------------------------ particles
  void _puff(double x, double y, int n, Color color) {
    for (var i = 0; i < n; i++) {
      particles.add(Particle(x: x, y: y, vx: rand(-90, 40), vy: rand(-90, -10), life: rand(0.25, 0.5), max: 0.5, size: rand(2, 4), color: color));
    }
  }

  void _sparkle(double x, double y, Color color) {
    for (var i = 0; i < 6; i++) {
      particles.add(Particle(x: x, y: y, vx: rand(-120, 120), vy: rand(-120, 120), life: 0.35, size: rand(1.5, 3), color: color));
    }
  }

  void _splash(double x, double y, int n) {
    for (var i = 0; i < n; i++) {
      particles.add(Particle(
          x: x, y: y, vx: rand(-140, 140), vy: rand(-320, -120), g: 1100, life: rand(0.4, 0.7), max: 0.7, size: rand(2, 4), circle: true,
          color: pick(const [Color(0xFFE1F5FE), Color(0xFF81D4FA), Color(0xFF29B6F6)])));
    }
  }

  void _text(double x, double y, String text, Color? color, double size) {
    particles.add(Particle(x: x, y: y, vy: -40, life: 0.9, size: size, text: text, color: color ?? const Color(0xFFFFFFFF)));
  }

  void _updateParticles(double dt) {
    for (final p in particles) {
      p.life -= dt;
      p.vy += p.g * dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      if (p.rot != null) p.rot = p.rot! + dt * 3;
    }
    particles.removeWhere((p) => p.life <= 0);
    if (particles.length > 500) particles.removeRange(0, particles.length - 500);
  }

  void _weather(double dt) {
    final b = kBiomes[biomeIdx];
    final r = _rng.nextDouble();
    switch (b.weather) {
      case 'leaf':
        if (r < dt * 6) {
          particles.add(Particle(
              x: rand(0, W + 40), y: -5, vx: rand(-80, -30), vy: rand(30, 60), life: 6, size: 3, weather: true, rot: 0,
              color: pick(const [Color(0xFF66BB6A), Color(0xFF9CCC65), Color(0xFF2E7D32)])));
        }
      case 'dust':
        if (r < dt * 10) {
          particles.add(Particle(x: W + 5, y: rand(gy - 120, gy), vx: rand(-420, -260), vy: rand(-10, 10), life: 2.5, size: rand(1, 2.5), weather: true, color: const Color(0x88FFF3D6)));
        }
      case 'snow':
        if (r < dt * 30) {
          particles.add(Particle(x: rand(0, W + 60), y: -5, vx: rand(-60, -20), vy: rand(30, 70), life: 7, size: rand(1.5, 3), weather: true, circle: true));
        }
      case 'ember':
        if (r < dt * 18) {
          particles.add(Particle(
              x: rand(0, W), y: gy, vx: rand(-60, 10), vy: rand(-90, -30), life: 3, size: rand(1.5, 3), weather: true,
              color: pick(const [Color(0xFFFF9800), Color(0xFFFF5722), Color(0xFFFFEB3B)])));
        }
      case 'star':
        if (r < dt * 0.6) {
          particles.add(Particle(x: rand(W * 0.3, W), y: rand(0, gy * 0.3), vx: -420, vy: 160, life: 0.7, size: 2, weather: true, streak: true));
        }
    }
  }

  // ------------------------------------------------------------------ render
  void paint(Canvas canvas, Size size) {
    resize(size);
    final ctx = Ctx(canvas);
    canvas.save();
    canvas.scale(k, k);
    canvas.clipRect(Rect.fromLTWH(0, 0, W, H));
    ctx.save();
    if (shake > 0) ctx.translate(rand(-1, 1) * shake * 0.5, rand(-1, 1) * shake * 0.5);
    final m = modeT;
    if (m <= 0) {
      _drawScene(ctx, false);
    } else if (m >= 1) {
      _drawScene(ctx, true);
    } else {
      _drawScene(ctx, false);
      final c = center();
      final maxR = math.sqrt(math.pow(math.max(c.dx, W - c.dx), 2) + math.pow(math.max(c.dy, H - c.dy), 2)) + 10;
      final r = _ease(m) * maxR;
      ctx.save();
      ctx.beginPath();
      ctx.arc(c.dx, c.dy, r, 0, math.pi * 2);
      ctx.clip();
      _drawScene(ctx, true);
      ctx.restore();
      final g = Grad.linear(c.dx - r, c.dy, c.dx + r, c.dy);
      const cols = [Color(0xFFFF1744), Color(0xFFFF9100), Color(0xFFFFEA00), Color(0xFF00E676), Color(0xFF2979FF), Color(0xFFD500F9)];
      for (var i = 0; i < cols.length; i++) {
        g.addColorStop(i / 5, cols[i]);
      }
      ctx.strokeStyle = g;
      ctx.lineWidth = 5;
      ctx.strokeCircle(c.dx, c.dy, r);
    }
    ctx.restore();
    _drawHud(ctx, m >= 0.5);
    if (flashT > 0) {
      ctx.fillStyle = Color.fromRGBO(255, 255, 255, math.min(1, flashT * 0.8));
      ctx.fillRect(0, 0, W, H);
    }
    canvas.restore();
  }

  ClassicPalette _classicPalette() {
    final n = (nightT * 10).round() / 10;
    return ClassicPalette(
      lerpColor(const Color(0xFFF7F7F7), const Color(0xFF202124), n),
      lerpColor(const Color(0xFF535353), const Color(0xFFDADCE0), n),
      lerpColor(const Color(0xFFD4D4D4), const Color(0xFF5F6368), n),
    );
  }

  void _drawScene(Ctx ctx, bool col) {
    final cp = _classicPalette();
    BiomePalette? pal;
    if (col) {
      pal = biomePalette(kBiomes[biomeFrom], kBiomes[biomeIdx], biomeT);
      drawColorBackground(ctx, W, H, gy, scroll, time, pal);
      if (isSuper('storm')) {
        ctx.fillStyle = Color.fromRGBO(15, 20, 55, _clamp(0.45 - stormFlash * 2, 0, 1));
        ctx.fillRect(0, 0, W, H);
      } else if (isSuper('meteors')) {
        ctx.fillStyle = const Color(0x29FF5A00);
        ctx.fillRect(0, 0, W, H);
      } else if (isSuper('midas')) {
        ctx.fillStyle = const Color(0x1FFFD740);
        ctx.fillRect(0, 0, W, H);
      }
    } else {
      drawClassicBackground(ctx, W, H, gy, scroll, time, cp, nightT);
      // "HI" flag at the distance of your best run
      if (state != GameState.idle && bestClassic > 50) {
        final fxp = d.x + 20 + (bestClassic / kScoreK - dist - bonus / kScoreK);
        if (fxp > -20 && fxp < W + 20) {
          ctx.fillStyle = cp.fg;
          ctx.fillRect(fxp, gy - 60, 2, 58);
          ctx.fillRect(fxp + 2, gy - 60, 20, 12);
          ctx.text('HI', fxp + 6, gy - 53.5, size: 9, family: 'monospace', align: -1, color: cp.bg);
        }
      }
    }

    if (col) {
      for (final c in coins) {
        drawCoin(ctx, c.x, c.y, time);
      }
      for (final p in powerups) {
        drawPowerup(ctx, p, time);
      }
    } else {
      for (final b in bones) {
        drawBone(ctx, b, cp.fg);
      }
    }
    for (final o in obstacles) {
      final f = o.flung;
      if (f != null) {
        ctx.save();
        ctx.translate(o.x + o.w / 2, o.y + o.h / 2);
        ctx.rotate(f.rot);
        ctx.translate(-(o.x + o.w / 2), -(o.y + o.h / 2));
        drawObstacle(ctx, o, col, time, cp.fg, gy);
        ctx.restore();
      } else {
        drawObstacle(ctx, o, col, time, cp.fg, gy);
      }
    }

    if (col) _drawSuperBack(ctx);

    for (final r in rings) {
      ctx.strokeStyle = col ? r.color : cp.fg;
      ctx.globalAlpha = (1 - r.t / r.life).clamp(0.0, 1.0);
      ctx.lineWidth = 3;
      ctx.strokeCircle(r.x, r.y, r.r);
      ctx.globalAlpha = 1;
    }

    _drawDinoLayer(ctx, col, cp);
    if (col) _drawSuperFront(ctx);
    _drawParticles(ctx, col, cp);
  }

  // effects behind the player
  void _drawSuperBack(Ctx ctx) {
    final t = time;
    if (isSuper('wave')) {
      final front = d.x + 110;
      final g = Grad.linear(0, gy - 70, 0, gy + 20)
        ..addColorStop(0, const Color(0xFF4FC3F7))
        ..addColorStop(1, const Color(0xFF01579B));
      ctx.fillStyle = g;
      ctx.beginPath();
      ctx.moveTo(-10, gy + 30);
      for (double x = -10; x <= front - 30; x += 8) {
        ctx.lineTo(x, gy - 40 + math.sin(x * 0.05 + t * 6) * 5);
      }
      ctx.quadraticCurveTo(front, gy - 70, front + 10, gy - 34);
      ctx.quadraticCurveTo(front - 4, gy - 30, front - 12, gy - 40);
      ctx.quadraticCurveTo(front + 20, gy - 10, front + 30, gy + 30);
      ctx.closePath();
      ctx.fill();
      ctx.strokeStyle = const Color(0xFFFFFFFF);
      ctx.lineWidth = 3;
      ctx.beginPath();
      for (double x = -10; x <= front - 30; x += 8) {
        ctx.lineTo(x, gy - 40 + math.sin(x * 0.05 + t * 6) * 5);
      }
      ctx.quadraticCurveTo(front, gy - 70, front + 10, gy - 34);
      ctx.stroke();
      // surfboard
      ctx.fillStyle = const Color(0xFFFFCA28);
      ctx.fillEllipse(d.x + 30, d.y + 2, 34, 4, -0.08);
      ctx.fillStyle = const Color(0xFFE53935);
      ctx.fillRect(d.x + 10, d.y, 40, 2);
    }
    if (isSuper('toxic')) {
      final x0 = d.x + 60;
      const span = 270.0;
      for (var i = 0; i < 18; i++) {
        final x = x0 + ((i * 41 + t * 50) % span);
        final y = gy - 12 - (i % 6) * 17 + math.sin(t * 2 + i) * 6;
        final r = 16.0 + (i % 3) * 9;
        ctx.fillStyle = Color.fromRGBO(110 + (i % 3) * 30, 230, 70, 0.22);
        ctx.fillCircle(x, y, r);
      }
      for (var i = 0; i < 6; i++) {
        final x = x0 + ((i * 53 + t * 80) % span), y = gy - ((t * 40 + i * 20) % 90);
        ctx.strokeStyle = const Color(0xB3B2FF59);
        ctx.lineWidth = 1;
        ctx.strokeCircle(x, y, 2.5);
      }
    }
    if (isSuper('midas')) {
      final h = head();
      for (var i = 0; i < 3; i++) {
        final r = ((t * 120 + i * 60) % 180) + 10;
        ctx.strokeStyle = Color.fromRGBO(255, 215, 64, (1 - r / 190).clamp(0.0, 1.0));
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.arc(h.dx - 10, h.dy - 8, r, -0.9, 0.9);
        ctx.stroke();
      }
    }
    if (isSuper('pack') || isSuper('stampede')) {
      final kind = isSuper('pack') ? getDino('raptor') : getDino('tricera');
      for (final a in allies) {
        if (a.x < -80 || a.x > W + 80) continue;
        ctx.fillStyle = const Color(0x33000000);
        ctx.fillEllipse(a.x + 26, gy + 2, 16, 3);
        drawDino(ctx.canvas, kind, 'stand', a.y < gy ? 2 : a.frame, a.x, a.y);
      }
    }
    if (fx.frill > 0 && def.id == 'dilo') {
      final h = head();
      final cx = h.dx - 6, cy = h.dy + 8;
      ctx.fillStyle = def.colors.frill ?? const Color(0xFFE74C3C);
      ctx.beginPath();
      ctx.arc(cx, cy, 13, math.pi * 0.35, math.pi * 1.65);
      ctx.closePath();
      ctx.fill();
      ctx.strokeStyle = const Color(0xFFFFEB3B);
      ctx.lineWidth = 1.5;
      for (double a = math.pi * 0.45; a < math.pi * 1.6; a += 0.3) {
        ctx.strokeLine(cx, cy, cx + math.cos(a) * 12, cy + math.sin(a) * 12);
      }
    }
  }

  // effects in front of the player
  void _drawSuperFront(Ctx ctx) {
    if (isSuper('orbit')) {
      final c = center();
      for (var i = 0; i < 6; i++) {
        final a = superAngle + (i * math.pi * 2) / 6;
        final px = c.dx + math.cos(a) * 50, py = c.dy + math.sin(a) * 50;
        ctx.save();
        ctx.translate(px, py);
        ctx.rotate(a + math.pi / 2 + superAngle * 2);
        ctx.fillStyle = def.colors.accent;
        ctx.beginPath();
        ctx.moveTo(0, -10);
        ctx.lineTo(8, 6);
        ctx.lineTo(-8, 6);
        ctx.closePath();
        ctx.fill();
        ctx.strokeStyle = const Color(0xFFFFE0B2);
        ctx.lineWidth = 1.5;
        ctx.stroke();
        ctx.restore();
      }
      ctx.strokeStyle = const Color(0x40FF7043);
      ctx.lineWidth = 2;
      ctx.strokeCircle(c.dx, c.dy, 50);
    }
    for (final b in bolts) {
      const segs = 7;
      final pts = <Offset>[];
      for (var i = 0; i <= segs; i++) {
        final kk = i / segs;
        final j = i == 0 || i == segs ? 0.0 : (((math.sin(b.seed + i * 12.9898) * 43758.5453) % 1).abs()) * 18;
        pts.add(Offset(b.x1 + (b.x2 - b.x1) * kk + j, b.y1 + (b.y2 - b.y1) * kk));
      }
      for (final s in const [(6.0, Color(0x8081D4FA)), (2.5, Color(0xFFFFFFFF))]) {
        ctx.strokeStyle = s.$2;
        ctx.lineWidth = s.$1;
        ctx.beginPath();
        for (var i = 0; i < pts.length; i++) {
          if (i == 0) {
            ctx.moveTo(pts[i].dx, pts[i].dy);
          } else {
            ctx.lineTo(pts[i].dx, pts[i].dy);
          }
        }
        ctx.stroke();
      }
    }
    for (final s in shots) {
      if (s.kind == ShotKind.venom) {
        ctx.fillStyle = const Color(0xFF76FF03);
        ctx.fillCircle(s.x, s.y, 5);
        ctx.fillStyle = const Color(0xFFCCFF90);
        ctx.fillCircle(s.x - 1.5, s.y - 1.5, 2);
      } else {
        final g = Grad.radial(s.x, s.y, 2, s.x, s.y, 16)
          ..addColorStop(0, const Color(0xFFFFFDE7))
          ..addColorStop(0.4, const Color(0xFFFFB300))
          ..addColorStop(1, const Color(0x00FF3D00));
        ctx.fillStyle = g;
        ctx.fillCircle(s.x, s.y, 16);
        ctx.fillStyle = const Color(0xFF4E342E);
        ctx.fillCircle(s.x, s.y, 6);
        ctx.strokeStyle = const Color(0xCCFF5722);
        ctx.lineWidth = 2;
        ctx.strokeEllipse(s.tx, s.ty + 6, 14, 3);
      }
    }
  }

  void _drawDinoLayer(Ctx ctx, bool col, ClassicPalette cp) {
    var pose = 'stand';
    var frame = 2;
    if (!d.dead && state == GameState.running) {
      if (d.ducking) {
        pose = 'duck';
        frame = d.frame;
      } else if (d.onGround || isSuper('wave')) {
        frame = isSuper('wave') ? 2 : d.frame;
      }
      if (def.id == 'ptero' && (fx.rocket > 0 || isSuper('storm') || (!d.onGround && inputJump))) {
        frame = (time * 10).floor() % 2;
      }
    }
    final opts = col
        ? SpriteOpts(dead: d.dead, tint: isSuper('fortress') ? 'steel' : null)
        : SpriteOpts(classic: true, fg: cp.fg, bg: cp.bg, dead: d.dead);
    final sz = poseSize(def, pose);
    final w = sz.width, h = sz.height;
    final canvas = ctx.canvas;

    if (col) {
      final hh = math.max(0, gy - d.y);
      if (!isSuper('wave') && fx.dive <= 0) {
        ctx.fillStyle = Color.fromRGBO(0, 0, 0, 0.25 * math.max(0.2, 1 - hh / 150));
        final sw = isSuper('giant') ? 2 : 1;
        ctx.fillEllipse(d.x + (w * sw) / 2, gy + 2, (w * sw) / 2.6 * math.max(0.4, 1 - hh / 200), 3);
      }
      if (fx.dash > 0) {
        for (var i = 3; i >= 1; i--) {
          ctx.saveLayerAlpha(0.15 * (4 - i));
          drawDino(canvas, def, pose, frame, d.x - i * 12, d.y, opts);
          ctx.restoreLayer();
        }
      }
    }
    final blink = fx.invuln > 0 && state == GameState.running && (time * 16).floor() % 2 == 0;
    if (blink) ctx.saveLayerAlpha(0.4);
    if (col && fx.rocket > 0 && !fx.soar) {
      ctx.fillStyle = const Color(0xFFB0BEC5);
      ctx.fillRect(d.x + 2, d.y - 26, 8, 14);
      ctx.fillStyle = const Color(0xFFE53935);
      ctx.fillRect(d.x + 2, d.y - 30, 8, 4);
    }

    if (col && isSuper('giant')) {
      ctx.save();
      ctx.translate(d.x, d.y);
      ctx.scale(2);
      drawDino(canvas, def, pose, frame, 0, 0, opts);
      ctx.restore();
      // golden crown
      final hd = head();
      ctx.fillStyle = const Color(0xFFFFD54F);
      ctx.beginPath();
      ctx.moveTo(hd.dx - 10, hd.dy - 8);
      ctx.lineTo(hd.dx - 10, hd.dy - 20);
      ctx.lineTo(hd.dx - 4, hd.dy - 13);
      ctx.lineTo(hd.dx + 2, hd.dy - 22);
      ctx.lineTo(hd.dx + 8, hd.dy - 13);
      ctx.lineTo(hd.dx + 14, hd.dy - 20);
      ctx.lineTo(hd.dx + 14, hd.dy - 8);
      ctx.closePath();
      ctx.fill();
      ctx.fillStyle = const Color(0xFFE53935);
      ctx.fillRect(hd.dx + 1, hd.dy - 13, 3, 3);
    } else if (col && isSuper('ball')) {
      final cx = d.x + w / 2, cy = d.y - h / 2;
      final dsz = poseSize(def, 'duck');
      ctx.save();
      ctx.translate(cx, cy);
      ctx.rotate(superAngle);
      drawDino(canvas, def, 'duck', 2, -dsz.width / 2, dsz.height / 2, opts);
      ctx.restore();
      ctx.strokeStyle = const Color(0xCCFFE082);
      ctx.lineWidth = 3;
      ctx.beginPath();
      ctx.arc(cx, cy, 26, superAngle, superAngle + 4);
      ctx.stroke();
    } else if (col && fx.dive > 0) {
      ctx.save();
      ctx.clipRect(0, 0, W, gy);
      drawDino(canvas, def, pose, frame, d.x, d.y + h * 0.62, opts);
      ctx.restore();
      ctx.strokeStyle = const Color(0xFF81D4FA);
      ctx.lineWidth = 2;
      for (var i = 0; i < 3; i++) {
        final r = ((time * 40 + i * 12) % 36) + 6;
        ctx.globalAlpha = (1 - r / 42).clamp(0.0, 1.0);
        ctx.strokeEllipse(d.x + w / 2, gy, r, r * 0.2);
      }
      ctx.globalAlpha = 1;
      if (_rng.nextDouble() < 0.4) _splash(d.x + w * 0.8, gy, 1);
    } else {
      drawDino(canvas, def, pose, frame, d.x, d.y, opts);
    }
    if (blink) ctx.restoreLayer();

    if (col && isSuper('fortress')) {
      ctx.strokeStyle = Color.fromRGBO(227, 242, 253, 0.5 + 0.5 * math.sin(time * 10));
      ctx.lineWidth = 2;
      ctx.strokeRect(d.x - 2, d.y - h - 2, w + 4, h + 4);
      if (_rng.nextDouble() < 0.3) _sparkle(d.x + rand(0, w), d.y - rand(0, h), const Color(0xFFFFFFFF));
    }
    if (col && fx.soar && fx.rocket > 0 && def.id != 'ptero') {
      final flap = math.sin(time * 20) * 8;
      ctx.fillStyle = const Color(0xCCFFFFFF);
      ctx.beginPath();
      ctx.moveTo(d.x + 14, d.y - 24);
      ctx.lineTo(d.x - 10, d.y - 40 + flap);
      ctx.lineTo(d.x + 4, d.y - 22);
      ctx.fill();
    }
    if (col && (shield || fx.charge > 0)) {
      final c = center();
      ctx.lineWidth = 2;
      ctx.strokeStyle = fx.charge > 0 ? const Color(0xFFFFB74D) : const Color(0xFF4FC3F7);
      ctx.fillStyle = fx.charge > 0 ? const Color(0x26FFB74D) : const Color(0x264FC3F7);
      final r = math.max(w, h) / 2 + 8 + math.sin(time * 8) * 1.5;
      ctx.fillCircle(c.dx, c.dy, r);
      ctx.strokeCircle(c.dx, c.dy, r);
    }
    if (col && fx.superT > 0 && !isSuper('orbit')) {
      final c = center();
      final s = isSuper('giant') ? 2.0 : 1.0;
      ctx.strokeStyle = HSLColor.fromAHSL(0.6, (time * 300) % 360, 1, 0.65).toColor();
      ctx.lineWidth = 2;
      ctx.strokeCircle(c.dx, c.dy, (math.max(w, h) / 2 + 12) * s);
    }
  }

  void _drawParticles(Ctx ctx, bool col, ClassicPalette cp) {
    for (final p in particles) {
      if (!col && (p.weather || p.rain)) continue; // weather is a colorful-only thing
      final a = (p.life / p.max).clamp(0.0, 1.0);
      ctx.globalAlpha = math.min(1, a * 1.5);
      final c = col ? p.color : cp.fg;
      if (p.text != null) {
        ctx.fillStyle = c;
        ctx.text(p.text!, p.x, p.y,
            size: p.size,
            weight: FontWeight.w800,
            family: col ? null : 'monospace',
            strokeText: col,
            strokeColorOverride: const Color(0x99000000),
            strokeWidth: 3,
            color: c);
      } else if (p.streak) {
        ctx.strokeStyle = c;
        ctx.lineWidth = 1.5;
        ctx.strokeLine(p.x, p.y, p.x + 30, p.y - 12);
      } else if (p.rain) {
        ctx.strokeStyle = c;
        ctx.lineWidth = 1;
        ctx.strokeLine(p.x, p.y, p.x + 3, p.y - 12);
      } else if (p.rot != null && col) {
        ctx.fillStyle = c;
        ctx.fillEllipse(p.x, p.y, 4, 2, p.rot!);
      } else if (p.circle) {
        ctx.fillStyle = c;
        ctx.fillCircle(p.x, p.y, p.size);
      } else {
        ctx.fillStyle = c;
        ctx.fillRect(p.x, p.y, p.size, p.size);
      }
    }
    ctx.globalAlpha = 1;
  }

  void _drawHud(Ctx ctx, bool col) {
    if (state == GameState.idle) {
      _drawBanner(ctx, col);
      return;
    }
    final sc = score.floor();
    String pad(int n) => n.toString().padLeft(5, '0');
    if (!col) {
      final cp = _classicPalette();
      final hide = scoreBlink > 0 && (scoreBlink * 8).floor() % 2 == 0;
      ctx.text(hide ? '' : pad(sc), W - 12, 10, size: 13, family: 'monospace', align: 1, baseline: 0, color: cp.fg);
      ctx.globalAlpha = 0.7;
      ctx.text('HI ${pad(bestClassic)}', W - 70, 10, size: 13, family: 'monospace', align: 1, baseline: 0, color: cp.fg);
      ctx.globalAlpha = 1;
    } else {
      const shadow = Color(0x73000000);
      ctx.text('$sc', W - 12, 8,
          size: 20, weight: FontWeight.w800, align: 1, baseline: 0, strokeText: true, strokeColorOverride: shadow, strokeWidth: 4, color: const Color(0xFFFFFFFF));
      ctx.text('BEST $bestColor', W - 12, 31,
          size: 10, align: 1, baseline: 0, strokeText: true, strokeColorOverride: shadow, strokeWidth: 4, color: const Color(0xFFFFE082));
      final ctext = '$runCoins';
      ctx.text(ctext, W - 12, 45,
          size: 14, weight: FontWeight.w800, align: 1, baseline: 0, strokeText: true, strokeColorOverride: shadow, strokeWidth: 4, color: const Color(0xFFFFD54F));
      final tw = ctx.measure(ctext, size: 14, weight: FontWeight.w800);
      drawCoin(ctx, W - 22 - tw, 52, 0);

      final act = <(String, double)>[];
      if (shield) act.add(('🛡️', 1));
      if (fx.magnet > 0) act.add(('🧲', fx.magnet / 9));
      if (fx.doubleCoins > 0) act.add(('×2', fx.doubleCoins / 10));
      if (fx.rocket > 0) act.add((fx.soar ? '🪽' : '🚀', fx.rocket / 4.5));
      if (fx.charge > 0) act.add(('💥', fx.charge / 3));
      if (fx.dive > 0) act.add(('🌊', fx.dive / 1.8));
      for (var i = 0; i < act.length; i++) {
        final x = W - 22 - i * 26, y = 76.0;
        ctx.fillStyle = const Color(0x59000000);
        ctx.fillCircle(x, y, 11);
        ctx.strokeStyle = const Color(0xFFFFFFFF);
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.arc(x, y, 11, -math.pi / 2, -math.pi / 2 + math.pi * 2 * math.min(1, act[i].$2));
        ctx.stroke();
        ctx.text(act[i].$1, x, y + 1, size: act[i].$1 == '×2' ? 10 : 11, color: const Color(0xFFFFFFFF));
      }
      // super power timer bar
      if (fx.superT > 0) {
        final bw = math.min(220.0, W * 0.4), bx = (W - bw) / 2;
        const by = 30.0;
        ctx.fillStyle = const Color(0x73000000);
        ctx.fillRect(bx - 2, by - 2, bw + 4, 10);
        final g = Grad.linear(bx, 0, bx + bw, 0);
        const cols = [Color(0xFFFF5252), Color(0xFFFFD740), Color(0xFF69F0AE), Color(0xFF40C4FF), Color(0xFFE040FB)];
        for (var i = 0; i < cols.length; i++) {
          g.addColorStop(i / 4, cols[i]);
        }
        ctx.fillStyle = g;
        ctx.fillRect(bx, by, bw * (fx.superT / def.superPower.dur), 6);
        ctx.text(def.superPower.name.toUpperCase(), W / 2, by + 9,
            size: 10, weight: FontWeight.w800, baseline: 0, strokeText: true, strokeColorOverride: const Color(0x99000000), color: const Color(0xFFFFFFFF));
      }
    }
    _drawBanner(ctx, col);
  }

  void _drawBanner(Ctx ctx, bool col) {
    final b = banner;
    if (b == null) return;
    final a = b.t < 0.3 ? b.t / 0.3 : b.t > 2.1 ? math.max(0.0, (2.6 - b.t) / 0.5) : 1.0;
    final y = math.min(gy * 0.32, 90.0);
    ctx.saveLayerAlpha(a);
    if (col) {
      final s = 1 + math.max(0.0, 0.3 - b.t) * 1.5;
      ctx.save();
      ctx.translate(W / 2, y);
      ctx.scale(s);
      final tw = ctx.measure(b.text, size: 26, weight: FontWeight.w900);
      if (tw > W - 20) ctx.scale((W - 20) / tw);
      final g = Grad.linear(-120, 0, 120, 0);
      const cols = [Color(0xFFFF5252), Color(0xFFFFD740), Color(0xFF69F0AE), Color(0xFF40C4FF), Color(0xFFE040FB)];
      for (var i = 0; i < cols.length; i++) {
        g.addColorStop(i / 4, cols[i]);
      }
      ctx.fillStyle = g;
      ctx.text(b.text, 0, 0, size: 26, weight: FontWeight.w900, strokeText: true, strokeColorOverride: const Color(0x8C000000), strokeWidth: 6);
      ctx.text(b.sub, 0, 22, size: 11, strokeText: true, strokeColorOverride: const Color(0x8C000000), strokeWidth: 3, color: const Color(0xFFFFFFFF));
      ctx.restore();
    } else {
      final cp = _classicPalette();
      ctx.text(b.text, W / 2, y, size: 16, family: 'monospace', color: cp.fg);
      ctx.text(b.sub, W / 2, y + 18, size: 11, weight: FontWeight.w400, family: 'monospace', color: cp.fg);
    }
    ctx.restoreLayer();
  }
}

// Core game: physics, spawning, abilities, power-ups and rendering for both
// the monochrome "Classic" (offline) mode and the colorful "Jurassic" (online) mode.
import { getDino, drawDino, dinoHitboxes } from './dinos.js';
import {
  BIOMES, biomePalette, drawColorBackground, drawClassicBackground, drawObstacle,
  drawCoin, drawPowerup, drawBone, POWERUPS, lerpColor,
} from './world.js';
import { sfx, vibrate } from './audio.js';

const GRAVITY = 2600;
const JUMP_V = 760;
const START_SPEED = 360;
const ACCEL = 4.2;
const MAX_SPEED = { classic: 780, color: 880 };
const SCORE_K = 0.025;
const BIOME_LEN = 600;
const MODE_TRANSITION = 1.2; // seconds

const rand = (a, b) => a + Math.random() * (b - a);
const pick = (arr) => arr[Math.floor(Math.random() * arr.length)];
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
const overlap = (a, b) => a.x < b.x + b.w && a.x + a.w > b.x && a.y < b.y + b.h && a.y + a.h > b.y;
const ease = (t) => (t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2);

export class Game {
  constructor(canvas, hooks = {}) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d');
    this.hooks = hooks;
    this.colorful = false;
    this.modeT = 0;
    this.state = 'idle'; // idle | running | paused | over
    this.def = getDino('rex');
    this.best = { classic: 0, color: 0 };
    this.input = { jump: false, duck: false };
    this.time = 0;
    this.scroll = 0;
    this.nightT = 0;
    this.biomeIdx = 0; this.biomeFrom = 0; this.biomeT = 1;
    this.banner = null;
    this.particles = [];
    this.resize();
    this.reset();
    this.last = performance.now();
    requestAnimationFrame(this.loop);
  }

  // ---------------------------------------------------------------- setup
  resize() {
    const cw = Math.max(1, window.innerWidth), ch = Math.max(1, window.innerHeight);
    const aspect = cw / ch;
    const W = clamp(Math.round(260 * aspect), 420, 900);
    const H = Math.round(W / aspect);
    const oldGy = this.gy;
    this.W = W; this.H = H;
    this.gy = aspect < 1 ? Math.round(H * 0.62) : H - 34;
    const dpr = Math.min(window.devicePixelRatio || 1, 3);
    this.canvas.width = Math.round(cw * dpr);
    this.canvas.height = Math.round(ch * dpr);
    this.k = this.canvas.width / W;
    if (oldGy !== undefined && this.d) {
      const dy = this.gy - oldGy;
      this.d.y += dy;
      for (const list of [this.obstacles, this.coins, this.powerups, this.bones, this.particles]) {
        for (const o of list) o.y += dy;
      }
    }
  }

  setDino(id) { this.def = getDino(id); }
  setBest(classic, color) { this.best = { classic, color }; }

  setColorful(v, animate = true) {
    v = !!v;
    if (v === this.colorful) return;
    this.colorful = v;
    if (!animate) this.modeT = v ? 1 : 0;
    if (v) {
      this.showBanner('JURASSIC MODE', 'Internet connected — colors & powers unlocked!');
      this.biomeIdx = this.biomeFrom = Math.floor(this.score / BIOME_LEN) % BIOMES.length;
      this.biomeT = 1;
    } else {
      this.showBanner('CLASSIC MODE', 'No internet — back to basics');
      // power-ups only exist in the connected world
      const keep = this.fx.invuln;
      this.fx = this.freshFx();
      this.fx.invuln = Math.max(keep, 1);
      this.shield = false;
      this.coins = [];
      this.powerups = [];
    }
    if (this.state === 'running') {
      this.flashT = 0.6;
      this.fx.invuln = Math.max(this.fx.invuln, 1.5); // grace period while the world transforms
    }
  }

  freshFx() {
    return { magnet: 0, double: 0, rocket: 0, soar: false, dash: 0, charge: 0, hyper: 0, slow: 0, invuln: 0, rise: 0, slam: false };
  }

  reset() {
    this.speed = START_SPEED;
    this.dist = 0; this.bonus = 0; this.score = 0; this.runTime = 0;
    this.obstacles = []; this.coins = []; this.powerups = []; this.bones = []; this.rings = [];
    this.nextSpawn = this.W * 0.55;
    this.nextPower = rand(1500, 2600);
    this.nextBone = rand(2500, 4500);
    this.rocketCoinT = 0;
    this.d = { x: 44, y: this.gy, vy: 0, onGround: true, jumps: 0, frameT: 0, frame: 0, dead: false, ducking: false };
    this.fx = this.freshFx();
    this.shield = false;
    this.abilityCd = 0;
    this.runCoins = 0;
    this.milestone = 0;
    this.flashT = 0; this.shake = 0; this.scoreBlink = 0;
    this.biomeIdx = this.biomeFrom = 0; this.biomeT = 1;
    this.nightT = 0;
    this.overT = 0;
  }

  start() {
    this.reset();
    this.state = 'running';
    if (this.colorful) this.showBanner(BIOMES[0].name.toUpperCase(), 'Zone 1');
  }

  pause() { if (this.state === 'running') { this.state = 'paused'; this.input.jump = this.input.duck = false; } }
  resume() { if (this.state === 'paused') { this.state = 'running'; this.last = performance.now(); } }

  showBanner(text, sub) { this.banner = { text, sub, t: 0 }; }

  // ---------------------------------------------------------------- input
  jumpPress() {
    this.input.jump = true;
    if (this.state !== 'running') return;
    const d = this.d;
    if (this.fx.rocket > 0) return;
    if (d.onGround) {
      d.vy = -JUMP_V * (this.colorful ? (this.def.jumpMul || 1) : 1);
      d.onGround = false;
      d.jumps = 1;
      sfx.play('jump', this.colorful);
      if (this.colorful) this.puff(d.x + 14, d.y, 6, '#ffffffaa');
    } else if (this.colorful && this.def.passive === 'doubleJump' && d.jumps < 2) {
      d.vy = -JUMP_V * 0.88;
      d.jumps = 2;
      sfx.play('jump', true);
      this.puff(d.x + 14, d.y, 10, '#ffffff');
    }
  }
  jumpRelease() { this.input.jump = false; }
  duck(v) { this.input.duck = v; }

  abilityInfo() {
    const a = this.def.ability;
    return { name: a.name, ready: this.abilityCd <= 0, pct: a.cd ? 1 - this.abilityCd / a.cd : 1 };
  }

  useAbility() {
    if (!this.colorful || this.state !== 'running' || this.abilityCd > 0) return false;
    const a = this.def.ability;
    const d = this.d, fx = this.fx;
    this.abilityCd = a.cd;
    sfx.play('ability', true);
    vibrate(30);
    const cx = d.x + 20, cy = d.y - 20;
    this.rings.push({ x: cx, y: cy, r: 10, max: 120, color: this.def.colors.accent, life: 0.5, t: 0 });
    switch (a.id) {
      case 'roar':
        this.rings.push({ x: cx, y: cy, r: 10, max: 320, color: '#ffffff', life: 0.6, t: 0 });
        for (const o of this.obstacles) if (o.x < d.x + 320 && o.x + o.w > d.x - 10) this.destroy(o);
        this.shake = 8;
        break;
      case 'dash': fx.dash = 1.4; break;
      case 'shield': this.shield = true; break;
      case 'superjump':
        d.vy = -JUMP_V * 1.5; d.onGround = false; d.jumps = 2; fx.rise = 0.8;
        this.puff(d.x + 14, d.y, 14, '#ffffff');
        break;
      case 'charge': fx.charge = 3; break;
      case 'echo': fx.magnet = Math.max(fx.magnet, 8); fx.double = Math.max(fx.double, 8); break;
      case 'quake':
        if (d.onGround) this.quake(); else { fx.slam = true; d.vy = Math.max(d.vy, 900); }
        break;
      case 'soar': fx.rocket = 3; fx.soar = true; break;
      case 'warp': fx.slow = 4; break;
      case 'hyper': fx.hyper = 5; break;
      default: break;
    }
    this.texts(cx, cy - 34, a.name.toUpperCase() + '!', '#ffffff', 14);
    return true;
  }

  quake() {
    this.shake = 14;
    sfx.play('smash', true);
    vibrate(60);
    for (const o of this.obstacles) if (o.kind !== 'flyer' && o.x < this.W) this.destroy(o);
    for (let i = 0; i < 30; i++) {
      this.particles.push({ x: rand(0, this.W), y: this.gy, vx: rand(-40, 40), vy: rand(-260, -80), g: 900, life: rand(0.4, 0.8), max: 0.8, size: rand(2, 4), color: '#a1887f' });
    }
  }

  // ---------------------------------------------------------------- loop
  loop = (now) => {
    const dt = Math.min(0.05, (now - this.last) / 1000);
    this.last = now;
    try {
      this.update(dt);
      this.render();
    } catch (e) {
      console.error(e);
    }
    requestAnimationFrame(this.loop);
  };

  update(dt) {
    if (this.state === 'paused') return;
    this.time += dt;
    const target = this.colorful ? 1 : 0;
    if (this.modeT !== target) {
      this.modeT = clamp(this.modeT + Math.sign(target - this.modeT) * (dt / MODE_TRANSITION), 0, 1);
    }
    const wantNight = !this.colorful && this.state !== 'idle' && Math.floor(this.score / 700) % 2 === 1;
    this.nightT = clamp(this.nightT + (wantNight ? dt : -dt) / 1.2, 0, 1);
    if (this.banner) { this.banner.t += dt; if (this.banner.t > 2.6) this.banner = null; }
    this.flashT = Math.max(0, this.flashT - dt);
    this.shake = Math.max(0, this.shake - dt * 30);
    this.scoreBlink = Math.max(0, this.scoreBlink - dt);
    this.biomeT = Math.min(1, this.biomeT + dt / 2.5);

    if (this.state !== 'running') {
      if (this.state === 'idle' && this.colorful) this.scroll += 30 * dt; // gentle menu ambience
      if (this.state === 'over') this.overT += dt;
      this.updateParticles(dt);
      if (this.colorful) this.weather(dt);
      return;
    }

    const fx = this.fx;
    const prevRocket = fx.rocket;
    for (const k of ['magnet', 'double', 'rocket', 'dash', 'charge', 'hyper', 'slow', 'invuln', 'rise']) fx[k] = Math.max(0, fx[k] - dt);
    if (prevRocket > 0 && fx.rocket <= 0) { fx.invuln = Math.max(fx.invuln, 0.9); fx.soar = false; }
    this.abilityCd = Math.max(0, this.abilityCd - dt);

    const ts = fx.slow > 0 ? 0.55 : 1;
    const wdt = dt * ts;
    this.runTime += dt;
    this.speed = Math.min(this.colorful ? MAX_SPEED.color : MAX_SPEED.classic, this.speed + ACCEL * dt);
    const boost = fx.dash > 0 ? 1.6 : fx.hyper > 0 ? 1.25 : 1;
    const dx = this.speed * boost * wdt;
    this.dist += dx;
    this.scroll += dx;
    this.score = this.dist * SCORE_K + this.bonus;

    const m = Math.floor(this.score / 100);
    if (m > this.milestone) {
      this.milestone = m;
      sfx.play('point', this.colorful);
      if (!this.colorful) this.scoreBlink = 0.9;
    }
    const bi = Math.floor(this.score / BIOME_LEN) % BIOMES.length;
    if (bi !== this.biomeIdx) {
      this.biomeFrom = this.biomeIdx; this.biomeIdx = bi; this.biomeT = 0;
      if (this.colorful) this.showBanner(BIOMES[bi].name.toUpperCase(), `Zone ${Math.floor(this.score / BIOME_LEN) + 1}`);
    }

    this.updateDino(dt);
    this.spawn(dx, dt);
    this.moveEntities(dx, wdt, dt);
    this.collide();
    this.updateParticles(wdt);
    if (this.colorful) this.weather(dt);
  }

  updateDino(dt) {
    const d = this.d, fx = this.fx, gy = this.gy;
    if (fx.rocket > 0) {
      const target = gy - 110 + Math.sin(this.time * 4) * 6;
      d.y += (target - d.y) * Math.min(1, dt * 5);
      d.vy = 0; d.onGround = false; d.jumps = 1;
      if (!fx.soar && Math.random() < 0.8) {
        this.particles.push({ x: d.x + 6, y: d.y - 14, vx: rand(-220, -120), vy: rand(-30, 30), life: 0.35, max: 0.35, size: rand(2, 5), color: pick(['#ffeb3b', '#ff9800', '#ff5722']) });
      }
    } else {
      let g = GRAVITY;
      if (this.input.jump && d.vy < 0) g *= 0.65;
      if (this.input.duck && !d.onGround) g *= 3;
      d.vy += g * dt;
      if (this.colorful && this.def.id === 'ptero' && this.input.jump && d.vy > 140) d.vy = 140; // glide
      if (fx.slam) d.vy = Math.max(d.vy, 1400);
      d.y += d.vy * dt;
      if (d.y < 46) { d.y = 46; d.vy = Math.max(d.vy, 0); }
      if (d.y >= gy) {
        if (!d.onGround) {
          if (this.colorful) this.puff(d.x + 16, gy, 5, '#ffffff99');
          if (fx.slam) { fx.slam = false; this.quake(); }
        }
        d.y = gy; d.vy = 0; d.onGround = true; d.jumps = 0;
      } else {
        d.onGround = false;
      }
    }
    d.ducking = this.input.duck && d.onGround && fx.rocket <= 0;
    d.frameT += dt * (this.speed / 360);
    if (d.frameT > 0.1) { d.frameT = 0; d.frame ^= 1; }

    if ((fx.dash > 0 || fx.hyper > 0 || fx.charge > 0) && Math.random() < 0.9) {
      const col = fx.hyper > 0 ? `hsl(${(this.time * 400) % 360},100%,60%)` : this.def.colors.accent;
      this.particles.push({ x: d.x + rand(0, 10), y: d.y - rand(4, 36), vx: rand(-260, -160), vy: rand(-20, 20), life: 0.3, max: 0.3, size: rand(2, 4), color: col });
    }
  }

  spawn(dx, dt) {
    this.nextSpawn -= dx;
    if (this.nextSpawn <= 0) {
      this.spawnObstacle();
      const min = this.speed * 0.8 + 90;
      this.nextSpawn = rand(min, min * 1.9);
    }
    if (this.colorful) {
      this.nextPower -= dx;
      if (this.nextPower <= 0) {
        this.nextPower = rand(2600, 5200);
        const type = pick(Object.keys(POWERUPS));
        this.powerups.push({ type, x: this.W + 30, y: this.gy - rand(55, 95) });
      }
      if (this.fx.rocket > 0) {
        this.rocketCoinT -= dt;
        if (this.rocketCoinT <= 0) {
          this.rocketCoinT = 0.08;
          this.coins.push({ x: this.W + 10, y: this.gy - 96 + Math.sin(this.time * 3) * 16 });
        }
      }
    } else {
      this.nextBone -= dx;
      if (this.nextBone <= 0) {
        this.nextBone = rand(4000, 8000);
        this.bones.push({ x: this.W + 20, y: this.gy - rand(50, 75) });
      }
    }
  }

  spawnObstacle() {
    const colorful = this.colorful, sc = this.score, gy = this.gy;
    const b = BIOMES[this.biomeIdx];
    const x = this.W + 20;
    const r = Math.random();
    if (colorful && b.meteors && sc > 200 && r < 0.2) {
      const landX = this.W * rand(0.5, 0.7);
      const time = (x - landX) / this.speed;
      const fall = gy - 20 + 40;
      this.obstacles.push({ kind: 'meteor', x, y: -40, w: 20, h: 20, vy: fall / time, seed: Math.random() * 100 });
      return;
    }
    if (sc > (colorful ? 250 : 400) && r < 0.32) {
      const ufo = colorful && b.flyer === 'ufo';
      const y = pick([gy - 38, gy - 54, gy - 86]);
      const o = { kind: 'flyer', x, y, w: ufo ? 36 : 42, h: 30, seed: Math.random() * 100, biome: b, vx: this.speed * rand(0.05, 0.15) };
      this.obstacles.push(o);
      if (colorful && y < gy - 80) this.coinLine(x + 4, gy - 16, 3);
      return;
    }
    const large = sc > 80 && Math.random() < 0.45;
    const maxN = this.speed > 700 ? 3 : this.speed > 480 ? (large ? 2 : 3) : (large ? 1 : 2);
    const n = 1 + Math.floor(Math.random() * maxN);
    const uw = large ? 25 : 17, h = large ? 50 : 35;
    const o = { kind: 'ground', x, y: gy - h, w: uw * n, h, n, seed: Math.random() * 100, skin: colorful ? b.obstacle : 'cactus', biome: b };
    this.obstacles.push(o);
    if (colorful) {
      const r2 = Math.random();
      if (r2 < 0.45) {
        for (let i = 0; i < 5; i++) {
          const t = (i - 2) / 2.6;
          this.coins.push({ x: o.x + o.w / 2 + (i - 2) * 24, y: gy - h - 22 - 50 * (1 - t * t) });
        }
      } else if (r2 < 0.75) {
        this.coinLine(o.x + o.w + 110, gy - 16, 5);
      }
    }
  }

  coinLine(x, y, n) { for (let i = 0; i < n; i++) this.coins.push({ x: x + i * 20, y }); }

  hitbox(o) {
    if (o.kind === 'flyer') return { x: o.x + 4, y: o.y + 6, w: o.w - 8, h: o.h - 14 };
    if (o.kind === 'meteor') return { x: o.x + 2, y: o.y + 2, w: o.w - 4, h: o.h - 4 };
    return { x: o.x + 3, y: o.y + 4, w: o.w - 6, h: o.h - 4 };
  }

  moveEntities(dx, wdt, dt) {
    const gy = this.gy, d = this.d;
    for (const o of this.obstacles) {
      o.x -= dx;
      if (o.kind === 'flyer' && this.colorful) o.x -= o.vx * wdt;
      if (o.kind === 'meteor') {
        o.y += o.vy * wdt;
        if (Math.random() < 0.5) this.particles.push({ x: o.x + 10, y: o.y + 4, vx: rand(10, 60), vy: rand(-60, -20), life: 0.4, max: 0.4, size: rand(2, 4), color: pick(['#ff9800', '#ffeb3b', '#795548']) });
        if (o.y + o.h >= gy) {
          // impact: becomes a smoking rock on the ground
          o.kind = 'ground'; o.skin = 'meteorite'; o.n = 1; o.w = 30; o.h = 22; o.y = gy - 22; o.x -= 5;
          this.shake = Math.max(this.shake, 6);
          sfx.play('smash', true);
          this.puff(o.x + 15, gy, 14, '#ff7043');
        }
      }
    }
    this.obstacles = this.obstacles.filter((o) => !o.dead && o.x + o.w > -60);

    const cx = d.x + 20, cy = d.y - 20;
    const magnet = this.fx.magnet > 0 || this.fx.hyper > 0;
    for (const c of this.coins) {
      c.x -= dx;
      if (magnet) {
        const ddx = cx - c.x, ddy = cy - c.y, dist = Math.hypot(ddx, ddy);
        if (dist < 280) { c.x += (ddx / dist) * 650 * dt; c.y += (ddy / dist) * 650 * dt; }
      }
    }
    this.coins = this.coins.filter((c) => !c.taken && c.x > -20);
    for (const p of this.powerups) p.x -= dx;
    this.powerups = this.powerups.filter((p) => !p.taken && p.x > -30);
    for (const b of this.bones) b.x -= dx;
    this.bones = this.bones.filter((b) => !b.taken && b.x > -30);
    for (const r of this.rings) { r.t += dt; r.r = 10 + (r.max - 10) * (r.t / r.life); }
    this.rings = this.rings.filter((r) => r.t < r.life);
  }

  collide() {
    const d = this.d, fx = this.fx;
    const pose = d.ducking ? 'duck' : 'stand';
    const boxes = dinoHitboxes(pose, d.x, d.y);
    for (const o of this.obstacles) {
      if (o.dead) continue;
      const hb = this.hitbox(o);
      if (!boxes.some((b) => overlap(b, hb))) continue;
      const smash = fx.dash > 0 || fx.hyper > 0 || fx.rocket > 0 || fx.rise > 0 || (fx.charge > 0 && o.kind !== 'flyer');
      if (smash) { this.destroy(o); this.bonus += 5; this.texts(o.x, o.y - 6, '+5', '#ffe082', 11); continue; }
      if (fx.invuln > 0) continue;
      if (this.shield) {
        this.shield = false;
        fx.invuln = 1;
        this.destroy(o);
        this.texts(d.x + 20, d.y - 50, 'SHIELD!', '#4fc3f7', 12);
        continue;
      }
      this.die();
      return;
    }
    const cx = d.x + 20, cy = d.y - (d.ducking ? 12 : 22);
    const dbl = fx.double > 0 || fx.hyper > 0;
    for (const c of this.coins) {
      if (Math.abs(c.x - cx) < 22 && Math.abs(c.y - cy) < 26) {
        c.taken = true;
        this.runCoins += dbl ? 2 : 1;
        sfx.play('coin', true);
        this.sparkle(c.x, c.y, '#ffd54f');
      }
    }
    for (const p of this.powerups) {
      if (Math.abs(p.x - cx) < 26 && Math.abs(p.y - cy) < 30) {
        p.taken = true;
        sfx.play('power', true);
        this.texts(p.x, p.y - 20, POWERUPS[p.type].name.toUpperCase(), POWERUPS[p.type].color, 12);
        if (p.type === 'shield') this.shield = true;
        if (p.type === 'magnet') fx.magnet = 9;
        if (p.type === 'double') fx.double = 10;
        if (p.type === 'rocket') { fx.rocket = 4.5; fx.soar = false; }
      }
    }
    for (const b of this.bones) {
      if (Math.abs(b.x - cx) < 22 && Math.abs(b.y - cy) < 28) {
        b.taken = true;
        this.bonus += 50;
        sfx.play('bonus', false);
        this.texts(b.x, b.y - 14, '+50', null, 12);
      }
    }
  }

  destroy(o) {
    if (o.dead) return;
    o.dead = true;
    sfx.play('smash', this.colorful);
    this.shake = Math.max(this.shake, 4);
    const cols = { cactus: ['#34b257', '#1f7a3a'], stump: ['#8b5a2b', '#4caf50'], ice: ['#ffffff', '#6ec6ff'], lava: ['#ff5722', '#3e2723'], crystal: ['#ea80fc', '#651fff'], meteorite: ['#ff5722', '#3e2723'] };
    const palette = o.kind === 'flyer' ? ['#ffffff', '#bdbdbd'] : cols[o.skin] || ['#9e9e9e', '#616161'];
    for (let i = 0; i < 16; i++) {
      this.particles.push({ x: o.x + rand(0, o.w), y: o.y + rand(0, o.h), vx: rand(-60, 260), vy: rand(-320, -60), g: 900, life: rand(0.4, 0.8), max: 0.8, size: rand(2, 5), color: pick(palette) });
    }
  }

  die() {
    const d = this.d;
    d.dead = true;
    this.state = 'over';
    this.overT = 0;
    this.shake = 10;
    this.input.jump = this.input.duck = false;
    sfx.play('hit', this.colorful);
    vibrate(120);
    const score = Math.floor(this.score);
    const key = this.colorful ? 'color' : 'classic';
    const newBest = score > this.best[key];
    if (newBest) this.best[key] = score;
    if (this.colorful) for (let i = 0; i < 20; i++) this.sparkle(d.x + 20, d.y - 20, pick(['#ff5252', '#ffd54f', '#ffffff']));
    this.hooks.onGameOver?.({ score, best: this.best[key], newBest, coins: this.colorful ? this.runCoins : 0, colorful: this.colorful });
  }

  // ---------------------------------------------------------------- particles
  puff(x, y, n, color) {
    for (let i = 0; i < n; i++) this.particles.push({ x, y, vx: rand(-90, 40), vy: rand(-90, -10), life: rand(0.25, 0.5), max: 0.5, size: rand(2, 4), color });
  }
  sparkle(x, y, color) {
    for (let i = 0; i < 6; i++) this.particles.push({ x, y, vx: rand(-120, 120), vy: rand(-120, 120), life: 0.35, max: 0.35, size: rand(1.5, 3), color });
  }
  texts(x, y, text, color, size) {
    this.particles.push({ x, y, vx: 0, vy: -40, life: 0.9, max: 0.9, text, color, size });
  }
  updateParticles(dt) {
    for (const p of this.particles) {
      p.life -= dt;
      p.vy += (p.g || 0) * dt;
      p.x += p.vx * dt; p.y += p.vy * dt;
      if (p.rot !== undefined) p.rot += dt * 3;
    }
    this.particles = this.particles.filter((p) => p.life > 0);
    if (this.particles.length > 400) this.particles.splice(0, this.particles.length - 400);
  }
  weather(dt) {
    const b = BIOMES[this.biomeIdx];
    const W = this.W, gy = this.gy;
    const r = Math.random();
    switch (b.weather) {
      case 'leaf': if (r < dt * 6) this.particles.push({ x: rand(0, W + 40), y: -5, vx: rand(-80, -30), vy: rand(30, 60), life: 6, max: 6, size: 3, color: pick(['#66bb6a', '#9ccc65', '#2e7d32']), rot: 0, w: true }); break;
      case 'dust': if (r < dt * 10) this.particles.push({ x: W + 5, y: rand(gy - 120, gy), vx: rand(-420, -260), vy: rand(-10, 10), life: 2.5, max: 2.5, size: rand(1, 2.5), color: '#fff3d688', w: true }); break;
      case 'snow': if (r < dt * 30) this.particles.push({ x: rand(0, W + 60), y: -5, vx: rand(-60, -20), vy: rand(30, 70), life: 7, max: 7, size: rand(1.5, 3), color: '#ffffff', circle: true, w: true }); break;
      case 'ember': if (r < dt * 18) this.particles.push({ x: rand(0, W), y: gy, vx: rand(-60, 10), vy: rand(-90, -30), life: 3, max: 3, size: rand(1.5, 3), color: pick(['#ff9800', '#ff5722', '#ffeb3b']), w: true }); break;
      case 'star': if (r < dt * 0.6) this.particles.push({ x: rand(W * 0.3, W), y: rand(0, gy * 0.3), vx: -420, vy: 160, life: 0.7, max: 0.7, size: 2, color: '#ffffff', streak: true, w: true }); break;
      default: break;
    }
  }

  // ---------------------------------------------------------------- render
  render() {
    const ctx = this.ctx;
    ctx.setTransform(this.k, 0, 0, this.k, 0, 0);
    ctx.imageSmoothingEnabled = false;
    ctx.save();
    if (this.shake > 0) ctx.translate(rand(-1, 1) * this.shake * 0.5, rand(-1, 1) * this.shake * 0.5);
    const m = this.modeT;
    if (m <= 0) this.drawScene(false);
    else if (m >= 1) this.drawScene(true);
    else {
      this.drawScene(false);
      const cx = this.d.x + 20, cy = this.d.y - 20;
      const maxR = Math.hypot(Math.max(cx, this.W - cx), Math.max(cy, this.H - cy)) + 10;
      const r = ease(m) * maxR;
      ctx.save();
      ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.clip();
      this.drawScene(true);
      ctx.restore();
      const g = ctx.createLinearGradient(cx - r, cy, cx + r, cy);
      ['#ff1744', '#ff9100', '#ffea00', '#00e676', '#2979ff', '#d500f9'].forEach((c, i) => g.addColorStop(i / 5, c));
      ctx.strokeStyle = g; ctx.lineWidth = 5;
      ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.stroke();
    }
    ctx.restore();
    this.drawHUD(m >= 0.5);
    if (this.flashT > 0) {
      ctx.fillStyle = `rgba(255,255,255,${this.flashT * 0.8})`;
      ctx.fillRect(0, 0, this.W, this.H);
    }
  }

  classicPalette() {
    const n = Math.round(this.nightT * 10) / 10;
    return {
      bg: lerpColor('#f7f7f7', '#202124', n),
      fg: lerpColor('#535353', '#dadce0', n),
      cloud: lerpColor('#d4d4d4', '#5f6368', n),
    };
  }

  drawScene(colorful) {
    const ctx = this.ctx, W = this.W, H = this.H, gy = this.gy, d = this.d, t = this.time;
    const cp = this.classicPalette();
    let pal = null;
    if (colorful) {
      pal = biomePalette(BIOMES[this.biomeFrom], BIOMES[this.biomeIdx], this.biomeT);
      drawColorBackground(ctx, W, H, gy, this.scroll, t, pal);
    } else {
      drawClassicBackground(ctx, W, H, gy, this.scroll, t, cp, this.nightT);
      // "HI" flag at the distance of your best run
      if (this.state !== 'idle' && this.best.classic > 50) {
        const fxp = d.x + 20 + (this.best.classic / SCORE_K - this.dist - this.bonus / SCORE_K);
        if (fxp > -20 && fxp < W + 20) {
          ctx.fillStyle = cp.fg;
          ctx.fillRect(fxp, gy - 60, 2, 58);
          ctx.fillRect(fxp + 2, gy - 60, 20, 12);
          ctx.fillStyle = cp.bg;
          ctx.font = 'bold 9px monospace';
          ctx.textAlign = 'left'; ctx.textBaseline = 'middle';
          ctx.fillText('HI', fxp + 6, gy - 53.5);
        }
      }
    }

    if (colorful) {
      for (const c of this.coins) drawCoin(ctx, c, t);
      for (const p of this.powerups) drawPowerup(ctx, p, t);
    } else {
      for (const b of this.bones) drawBone(ctx, b, cp.fg);
    }
    for (const o of this.obstacles) drawObstacle(ctx, o, colorful, pal, t, cp.fg, gy);

    for (const r of this.rings) {
      ctx.strokeStyle = colorful ? r.color : cp.fg;
      ctx.globalAlpha = 1 - r.t / r.life;
      ctx.lineWidth = 3;
      ctx.beginPath(); ctx.arc(r.x, r.y, r.r, 0, Math.PI * 2); ctx.stroke();
      ctx.globalAlpha = 1;
    }

    this.drawDinoLayer(colorful, cp);
    this.drawParticles(colorful, cp);

    if (colorful && this.fx.slow > 0) {
      ctx.fillStyle = `rgba(90,40,200,${0.18 * Math.min(1, this.fx.slow)})`;
      ctx.fillRect(0, 0, W, H);
    }
  }

  drawDinoLayer(colorful, cp) {
    const ctx = this.ctx, d = this.d, fx = this.fx, gy = this.gy;
    let pose = 'stand', frame = 2;
    if (!d.dead && this.state === 'running') {
      if (d.ducking) { pose = 'duck'; frame = d.frame; } else if (d.onGround) frame = d.frame;
    }
    const opts = colorful
      ? { hue: this.time * 140, dead: d.dead }
      : { classic: true, fg: cp.fg, bg: cp.bg, dead: d.dead };

    if (colorful) {
      // shadow
      const h = Math.max(0, gy - d.y);
      ctx.fillStyle = `rgba(0,0,0,${0.25 * Math.max(0.2, 1 - h / 150)})`;
      ctx.beginPath(); ctx.ellipse(d.x + 22, gy + 2, 16 * Math.max(0.4, 1 - h / 200), 3, 0, 0, Math.PI * 2); ctx.fill();
      if (fx.dash > 0 || fx.hyper > 0) {
        for (let i = 3; i >= 1; i--) {
          ctx.globalAlpha = 0.15 * (4 - i);
          drawDino(ctx, this.def, pose, frame, d.x - i * 12, d.y, opts);
        }
        ctx.globalAlpha = 1;
      }
    }
    const blink = fx.invuln > 0 && this.state === 'running' && Math.floor(this.time * 16) % 2 === 0;
    if (blink) ctx.globalAlpha = 0.4;
    if (colorful && fx.rocket > 0 && !fx.soar) {
      // little rocket pack
      ctx.fillStyle = '#b0bec5'; ctx.fillRect(d.x + 2, d.y - 26, 8, 14);
      ctx.fillStyle = '#e53935'; ctx.fillRect(d.x + 2, d.y - 30, 8, 4);
    }
    drawDino(ctx, this.def, pose, frame, d.x, d.y, opts);
    ctx.globalAlpha = 1;

    if (colorful && fx.soar && fx.rocket > 0 && this.def.id !== 'ptero') {
      const flap = Math.sin(this.time * 20) * 8;
      ctx.fillStyle = '#ffffffcc';
      ctx.beginPath(); ctx.moveTo(d.x + 14, d.y - 24); ctx.lineTo(d.x - 10, d.y - 40 + flap); ctx.lineTo(d.x + 4, d.y - 22); ctx.fill();
    }
    if (colorful && (this.shield || fx.charge > 0 || fx.hyper > 0)) {
      const cx = d.x + 22, cy = d.y - (d.ducking ? 12 : 20);
      ctx.lineWidth = 2;
      ctx.strokeStyle = fx.hyper > 0 ? `hsl(${(this.time * 400) % 360},100%,60%)` : fx.charge > 0 ? '#ffb74d' : '#4fc3f7';
      ctx.fillStyle = fx.charge > 0 ? 'rgba(255,183,77,.15)' : 'rgba(79,195,247,.15)';
      ctx.beginPath(); ctx.arc(cx, cy, 30 + Math.sin(this.time * 8) * 1.5, 0, Math.PI * 2); ctx.fill(); ctx.stroke();
    }
  }

  drawParticles(colorful, cp) {
    const ctx = this.ctx;
    for (const p of this.particles) {
      if (!colorful && p.w) continue; // weather is a colorful-only thing
      const a = Math.max(0, p.life / p.max);
      ctx.globalAlpha = Math.min(1, a * 1.5);
      const col = colorful ? p.color || '#fff' : cp.fg;
      if (p.text) {
        ctx.font = `bold ${p.size}px ${colorful ? 'system-ui, sans-serif' : 'monospace'}`;
        ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
        if (colorful) { ctx.strokeStyle = 'rgba(0,0,0,.6)'; ctx.lineWidth = 3; ctx.strokeText(p.text, p.x, p.y); }
        ctx.fillStyle = col;
        ctx.fillText(p.text, p.x, p.y);
      } else if (p.streak) {
        ctx.strokeStyle = col; ctx.lineWidth = 1.5;
        ctx.beginPath(); ctx.moveTo(p.x, p.y); ctx.lineTo(p.x + 30, p.y - 12); ctx.stroke();
      } else if (p.rot !== undefined && colorful) {
        ctx.fillStyle = col;
        ctx.beginPath(); ctx.ellipse(p.x, p.y, 4, 2, p.rot, 0, Math.PI * 2); ctx.fill();
      } else if (p.circle) {
        ctx.fillStyle = col;
        ctx.beginPath(); ctx.arc(p.x, p.y, p.size, 0, Math.PI * 2); ctx.fill();
      } else {
        ctx.fillStyle = col;
        ctx.fillRect(p.x, p.y, p.size, p.size);
      }
    }
    ctx.globalAlpha = 1;
  }

  drawHUD(colorful) {
    const ctx = this.ctx, W = this.W;
    if (this.state === 'idle') { this.drawBanner(colorful); return; }
    const score = Math.floor(this.score);
    const pad = (n) => String(n).padStart(5, '0');
    if (!colorful) {
      const cp = this.classicPalette();
      ctx.font = 'bold 13px "Courier New", monospace';
      ctx.textAlign = 'right'; ctx.textBaseline = 'top';
      ctx.fillStyle = cp.fg;
      const hide = this.scoreBlink > 0 && Math.floor(this.scoreBlink * 8) % 2 === 0;
      ctx.fillText(hide ? '' : pad(score), W - 12, 10);
      ctx.globalAlpha = 0.7;
      ctx.fillText(`HI ${pad(this.best.classic)}`, W - 70, 10);
      ctx.globalAlpha = 1;
    } else {
      ctx.textAlign = 'right'; ctx.textBaseline = 'top';
      ctx.font = '800 20px system-ui, sans-serif';
      ctx.lineWidth = 4; ctx.strokeStyle = 'rgba(0,0,0,.45)';
      ctx.strokeText(score, W - 12, 8);
      ctx.fillStyle = '#fff';
      ctx.fillText(score, W - 12, 8);
      ctx.font = '700 10px system-ui, sans-serif';
      ctx.strokeText(`BEST ${this.best.color}`, W - 12, 31);
      ctx.fillStyle = '#ffe082';
      ctx.fillText(`BEST ${this.best.color}`, W - 12, 31);
      // coins
      ctx.font = '800 14px system-ui, sans-serif';
      const ctext = `${this.runCoins}`;
      ctx.strokeText(ctext, W - 12, 45);
      ctx.fillStyle = '#ffd54f';
      ctx.fillText(ctext, W - 12, 45);
      const tw = ctx.measureText(ctext).width;
      drawCoin(ctx, { x: W - 22 - tw, y: 52 }, 0);
      // active effects
      const fx = this.fx;
      const act = [];
      if (this.shield) act.push(['🛡️', 1]);
      if (fx.magnet > 0) act.push(['🧲', fx.magnet / 9]);
      if (fx.double > 0) act.push(['×2', fx.double / 10]);
      if (fx.rocket > 0) act.push([fx.soar ? '🪽' : '🚀', fx.rocket / 4.5]);
      if (fx.slow > 0) act.push(['⏳', fx.slow / 4]);
      if (fx.hyper > 0) act.push(['🌈', fx.hyper / 5]);
      if (fx.charge > 0) act.push(['💥', fx.charge / 3]);
      act.forEach(([icon, p], i) => {
        const x = W - 22 - i * 26, y = 76;
        ctx.fillStyle = 'rgba(0,0,0,.35)';
        ctx.beginPath(); ctx.arc(x, y, 11, 0, Math.PI * 2); ctx.fill();
        ctx.strokeStyle = '#fff'; ctx.lineWidth = 2;
        ctx.beginPath(); ctx.arc(x, y, 11, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * Math.min(1, p)); ctx.stroke();
        ctx.font = icon === '×2' ? 'bold 10px system-ui' : '11px system-ui';
        ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
        ctx.fillStyle = '#fff';
        ctx.fillText(icon, x, y + 1);
      });
    }
    this.drawBanner(colorful);
  }

  drawBanner(colorful) {
    const b = this.banner;
    if (!b) return;
    const ctx = this.ctx, W = this.W;
    const a = b.t < 0.3 ? b.t / 0.3 : b.t > 2.1 ? Math.max(0, (2.6 - b.t) / 0.5) : 1;
    const y = Math.min(this.gy * 0.32, 90);
    ctx.globalAlpha = a;
    ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
    if (colorful) {
      const s = 1 + Math.max(0, 0.3 - b.t) * 1.5;
      ctx.save();
      ctx.translate(W / 2, y);
      ctx.scale(s, s);
      ctx.font = '900 26px system-ui, sans-serif';
      const g = ctx.createLinearGradient(-120, 0, 120, 0);
      ['#ff5252', '#ffd740', '#69f0ae', '#40c4ff', '#e040fb'].forEach((c, i) => g.addColorStop(i / 4, c));
      ctx.lineWidth = 6; ctx.strokeStyle = 'rgba(0,0,0,.55)';
      ctx.strokeText(b.text, 0, 0);
      ctx.fillStyle = g;
      ctx.fillText(b.text, 0, 0);
      ctx.font = '700 11px system-ui, sans-serif';
      ctx.lineWidth = 3;
      ctx.strokeText(b.sub, 0, 22);
      ctx.fillStyle = '#fff';
      ctx.fillText(b.sub, 0, 22);
      ctx.restore();
    } else {
      const cp = this.classicPalette();
      ctx.fillStyle = cp.fg;
      ctx.font = 'bold 16px "Courier New", monospace';
      ctx.fillText(b.text, W / 2, y);
      ctx.font = '11px "Courier New", monospace';
      ctx.fillText(b.sub, W / 2, y + 18);
    }
    ctx.globalAlpha = 1;
  }
}

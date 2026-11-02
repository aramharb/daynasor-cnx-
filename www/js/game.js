// Core game: physics, spawning, abilities, SUPER POWERS, power-ups and rendering for both
// the monochrome "Classic" (offline) mode and the colorful "Jurassic" (online) mode.
import { getDino, drawDino, dinoHitboxes, poseSize, headAnchor } from './dinos.js';
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
// how the SUPER meter fills (1 = full)
const SUPER_GAIN = { start: 0.25, perSecond: 0.012, coin: 0.012, smash: 0.04, power: 0.1 };

const rand = (a, b) => a + Math.random() * (b - a);
const pick = (arr) => arr[Math.floor(Math.random() * arr.length)];
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
const overlap = (a, b) => a.x < b.x + b.w && a.x + a.w > b.x && a.y < b.y + b.h && a.y + a.h > b.y;
const ease = (t) => (t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2);
const circleHitsRect = (cx, cy, r, b) => {
  const nx = clamp(cx, b.x, b.x + b.w), ny = clamp(cy, b.y, b.y + b.h);
  return (cx - nx) ** 2 + (cy - ny) ** 2 < r * r;
};

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
      for (const list of [this.obstacles, this.coins, this.powerups, this.bones, this.particles, this.allies]) {
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
      // power-ups & super powers only exist in the connected world
      this.fx = this.freshFx();
      this.endSuper(true);
      this.shield = false;
      this.coins = [];
      this.powerups = [];
      this.shots = [];
    }
    if (this.state === 'running') {
      this.flashT = 0.6;
      this.fx.invuln = Math.max(this.fx.invuln, 1.5); // grace period while the world transforms
    }
  }

  freshFx() {
    return {
      magnet: 0, double: 0, rocket: 0, soar: false, dash: 0, charge: 0, invuln: 0, rise: 0, slam: false,
      dive: 0, frill: 0, super: 0,
    };
  }

  reset() {
    this.speed = START_SPEED;
    this.dist = 0; this.bonus = 0; this.score = 0; this.runTime = 0;
    this.obstacles = []; this.coins = []; this.powerups = []; this.bones = []; this.rings = [];
    this.shots = []; this.bolts = []; this.allies = [];
    this.nextSpawn = this.W * 0.55;
    this.nextPower = rand(1500, 2600);
    this.nextBone = rand(2500, 4500);
    this.rocketCoinT = 0;
    this.d = { x: 44, y: this.gy, vy: 0, onGround: true, jumps: 0, frameT: 0, frame: 0, dead: false, ducking: false };
    this.fx = this.freshFx();
    this.shield = false;
    this.abilityCd = 0;
    this.superMeter = SUPER_GAIN.start;
    this.superId = null; this.superTimer = 0; this.superAngle = 0; this.stormFlash = 0;
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

  isSuper(id) { return this.fx.super > 0 && this.superId === id; }

  pose() { return this.d.ducking ? 'duck' : 'stand'; }
  head() {
    const a = headAnchor(this.def, this.pose());
    const s = this.isSuper('giant') ? 2 : 1;
    return { x: this.d.x + a.x * s, y: this.d.y + a.y * s };
  }
  center() {
    const { w, h } = poseSize(this.def, this.pose());
    const s = this.isSuper('giant') ? 2 : 1;
    return { x: this.d.x + (w * s) / 2, y: this.d.y - (h * s) / 2 };
  }

  // ---------------------------------------------------------------- input
  jumpPress() {
    this.input.jump = true;
    if (this.state !== 'running') return;
    const d = this.d;
    if (this.isSuper('storm')) { d.vy = -430; d.onGround = false; sfx.play('jump', true); this.puff(d.x + 10, d.y - 10, 4, '#ffffff'); return; }
    if (this.fx.rocket > 0 || this.isSuper('wave')) return;
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
  superInfo() {
    const s = this.def.super;
    return { name: s.name, pct: this.fx.super > 0 ? this.fx.super / s.dur : this.superMeter, full: this.superMeter >= 1, active: this.fx.super > 0 };
  }

  useAbility() {
    if (!this.colorful || this.state !== 'running' || this.abilityCd > 0) return false;
    const a = this.def.ability;
    const d = this.d, fx = this.fx;
    this.abilityCd = a.cd;
    sfx.play('ability', true);
    vibrate(30);
    const c = this.center();
    this.rings.push({ x: c.x, y: c.y, r: 10, max: 120, color: this.def.colors.accent, life: 0.5, t: 0 });
    switch (a.id) {
      case 'roar':
        this.rings.push({ x: c.x, y: c.y, r: 10, max: 320, color: '#ffffff', life: 0.6, t: 0 });
        for (const o of this.obstacles) if (o.x < d.x + 340 && o.x + o.w > d.x - 10) this.destroy(o);
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
      case 'dive':
        fx.dive = 1.8;
        if (!d.onGround) d.vy = Math.max(d.vy, 1000);
        sfx.play('splash', true);
        this.splash(c.x, this.gy, 16);
        break;
      case 'sweep': {
        const h = this.head();
        this.rings.push({ x: h.x, y: h.y, r: 10, max: 420, color: '#ffe082', life: 0.6, t: 0 });
        for (const o of this.obstacles) if ((o.kind === 'flyer' || o.kind === 'meteor') && o.x < this.W + 20) this.destroy(o);
        fx.magnet = Math.max(fx.magnet, 4);
        break;
      }
      case 'spit': {
        const h = this.head();
        fx.frill = 0.6;
        this.shots.push({ kind: 'venom', x: h.x + 8, y: h.y + 4, vx: 720, vy: -80, life: 1.6 });
        break;
      }
      default: break;
    }
    this.texts(c.x, c.y - 40, a.name.toUpperCase() + '!', '#ffffff', 14);
    return true;
  }

  useSuper() {
    if (!this.colorful || this.state !== 'running' || this.superMeter < 1 || this.fx.super > 0) return false;
    const s = this.def.super;
    const d = this.d;
    this.superMeter = 0;
    this.fx.super = s.dur;
    this.superId = s.id;
    this.superTimer = 0;
    this.showBanner(s.name.toUpperCase(), '⚡ SUPER POWER ⚡');
    this.flashT = 0.5;
    this.shake = 10;
    sfx.play('super', true);
    vibrate([60, 40, 90]);
    const c = this.center();
    for (let i = 0; i < 3; i++) this.rings.push({ x: c.x, y: c.y, r: 10, max: 200 + i * 120, color: ['#ff5252', '#ffd740', '#40c4ff'][i], life: 0.5 + i * 0.15, t: 0 });
    if (s.id === 'pack') {
      this.allies = [0, 1, 2].map((i) => ({ kind: 'raptor', i, x: -40 - i * 40, y: this.gy, vy: 0, target: null, frame: 0, frameT: 0 }));
    } else if (s.id === 'stampede') {
      this.allies = Array.from({ length: 6 }, (_, i) => ({ kind: 'tricera', i, x: -70 - i * 75, y: this.gy, vy: 0, sp: rand(420, 560), frame: i % 2, frameT: 0 }));
    } else if (s.id === 'storm') {
      d.vy = -520; d.onGround = false;
    }
    return true;
  }

  endSuper(silent) {
    if (this.superId && !silent) this.fx.invuln = Math.max(this.fx.invuln, 1);
    this.fx.super = 0;
    this.superId = null;
    this.allies = [];
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
    this.stormFlash = Math.max(0, this.stormFlash - dt);
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
    for (const k of ['magnet', 'double', 'rocket', 'dash', 'charge', 'invuln', 'rise', 'dive', 'frill']) fx[k] = Math.max(0, fx[k] - dt);
    if (prevRocket > 0 && fx.rocket <= 0) { fx.invuln = Math.max(fx.invuln, 0.9); fx.soar = false; }
    if (fx.super > 0) {
      fx.super -= dt;
      if (fx.super <= 0) this.endSuper();
    } else if (this.colorful) {
      this.superMeter = Math.min(1, this.superMeter + SUPER_GAIN.perSecond * dt);
    }
    this.abilityCd = Math.max(0, this.abilityCd - dt);

    const wdt = dt;
    this.runTime += dt;
    this.speed = Math.min(this.colorful ? MAX_SPEED.color : MAX_SPEED.classic, this.speed + ACCEL * dt);
    let boost = 1;
    if (fx.dash > 0) boost = 1.6;
    else if (this.isSuper('ball')) boost = 1.3;
    else if (this.isSuper('wave') || this.isSuper('stampede')) boost = 1.2;
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
      if (this.colorful && !(this.fx.super > 0)) this.showBanner(BIOMES[bi].name.toUpperCase(), `Zone ${Math.floor(this.score / BIOME_LEN) + 1}`);
    }

    this.updateDino(dt);
    this.spawn(dx, dt);
    this.moveEntities(dx, wdt, dt);
    if (fx.super > 0) this.updateSuper(dt, dx);
    this.updateShots(dt, dx);
    if (this.state !== 'running') return;
    this.collide();
    this.updateParticles(wdt);
    if (this.colorful) this.weather(dt);
  }

  updateDino(dt) {
    const d = this.d, fx = this.fx, gy = this.gy;
    if (fx.rocket > 0 || this.isSuper('wave')) {
      const surf = this.isSuper('wave');
      const target = surf ? gy - 44 + Math.sin(this.time * 5) * 5 : gy - 110 + Math.sin(this.time * 4) * 6;
      d.y += (target - d.y) * Math.min(1, dt * 5);
      d.vy = 0; d.onGround = false; d.jumps = 1;
      if (!surf && !fx.soar && Math.random() < 0.8) {
        this.particles.push({ x: d.x + 6, y: d.y - 14, vx: rand(-220, -120), vy: rand(-30, 30), life: 0.35, max: 0.35, size: rand(2, 5), color: pick(['#ffeb3b', '#ff9800', '#ff5722']) });
      }
    } else {
      const storm = this.isSuper('storm');
      let g = storm ? 1100 : GRAVITY;
      if (!storm && this.input.jump && d.vy < 0) g *= 0.65;
      if (!storm && this.input.duck && !d.onGround) g *= 3;
      d.vy += g * dt;
      if (storm) d.vy = Math.min(d.vy, 420);
      if (this.colorful && this.def.id === 'ptero' && this.input.jump && d.vy > 140 && !storm) d.vy = 140; // glide
      if (fx.slam) d.vy = Math.max(d.vy, 1400);
      d.y += d.vy * dt;
      if (d.y < 50) { d.y = 50; d.vy = Math.max(d.vy, 0); }
      if (d.y >= gy) {
        if (!d.onGround) {
          if (this.colorful) this.puff(d.x + 16, gy, 5, '#ffffff99');
          if (fx.slam) { fx.slam = false; this.quake(); }
          if (this.isSuper('ball')) { this.shake = Math.max(this.shake, 4); this.puff(d.x + 20, gy, 10, '#d7ccc8'); }
        }
        d.y = gy; d.vy = 0; d.onGround = true; d.jumps = 0;
        if (this.isSuper('ball')) { d.vy = -640; d.onGround = false; }
      } else {
        d.onGround = false;
      }
    }
    d.ducking = this.input.duck && d.onGround && fx.rocket <= 0 && !this.isSuper('ball') && !this.isSuper('giant');
    d.frameT += dt * (this.speed / 360);
    if (d.frameT > 0.1) {
      d.frameT = 0; d.frame ^= 1;
      if (this.isSuper('giant') && d.onGround) { this.shake = Math.max(this.shake, 3); this.puff(d.x + 30, this.gy, 3, '#bcaaa4'); }
    }

    if ((fx.dash > 0 || fx.charge > 0) && Math.random() < 0.9) {
      this.particles.push({ x: d.x + rand(0, 10), y: d.y - rand(4, 36), vx: rand(-260, -160), vy: rand(-20, 20), life: 0.3, max: 0.3, size: rand(2, 4), color: this.def.colors.accent });
    }
  }

  // ---------------------------------------------------------------- SUPER POWERS
  updateSuper(dt, dx) {
    const d = this.d, gy = this.gy, W = this.W;
    this.superTimer -= dt;
    const tick = (interval) => { if (this.superTimer <= 0) { this.superTimer = interval; return true; } return false; };
    const live = this.obstacles.filter((o) => !o.dead && !o.flung);
    switch (this.superId) {
      case 'giant': // T. rex — coin rain while giant
        if (tick(0.12)) this.coins.push({ x: rand(W * 0.3, W), y: -10, vy: rand(220, 320) });
        break;

      case 'pack': // Velociraptor — allies pounce on obstacles ahead
        for (const a of this.allies) {
          const home = d.x + 90 + a.i * 55;
          if (a.target && (a.target.dead || a.target.x + a.target.w < a.x - 40)) a.target = null;
          if (!a.target) {
            const o = live.find((o) => !o.claimed && o.x < a.x + 230 && o.x + o.w > a.x - 10);
            if (o) { o.claimed = true; a.target = o; a.vy = o.kind === 'ground' ? -560 : -820; sfx.play('chomp', true); }
            else a.x += (home - a.x) * Math.min(1, dt * 3);
          }
          if (a.target) {
            const o = a.target;
            a.x += (o.x + o.w / 2 - 24 - a.x) * Math.min(1, dt * 9);
            if (overlap({ x: a.x, y: a.y - 36, w: 54, h: 36 }, this.hitbox(o))) {
              this.destroy(o); this.bonus += 5; this.superSmash();
              this.texts(o.x + o.w / 2, o.y - 10, 'CHOMP!', '#ff8a65', 12);
              a.target = null;
            }
          }
          a.vy += 2200 * dt; a.y += a.vy * dt;
          if (a.y >= gy) { a.y = gy; a.vy = 0; }
          a.frameT += dt; if (a.frameT > 0.09) { a.frameT = 0; a.frame ^= 1; }
        }
        break;

      case 'orbit': { // Stegosaurus — spinning plates shred anything close
        this.superAngle += dt * 7;
        const c = this.center();
        for (const o of live) if (circleHitsRect(c.x, c.y, 60, this.hitbox(o))) { this.destroy(o); this.bonus += 5; this.superSmash(); }
        break;
      }

      case 'ball': // Pachycephalosaurus — spinning bouncing skull
        this.superAngle += dt * 16;
        break;

      case 'stampede': // Triceratops — a herd runs over everything
        for (const a of this.allies) {
          a.x += a.sp * dt;
          a.frameT += dt; if (a.frameT > 0.08) { a.frameT = 0; a.frame ^= 1; }
          if (a.x > W + 80 && this.fx.super > 1) a.x = -80 - rand(0, 120);
          if (Math.random() < 0.5) this.particles.push({ x: a.x + 5, y: gy - 2, vx: rand(-120, -40), vy: rand(-60, -10), life: 0.4, max: 0.4, size: rand(2, 4), color: '#bcaaa4' });
          const box = { x: a.x, y: gy - 30, w: 60, h: 30 };
          for (const o of live) if (!o.dead && overlap(box, this.hitbox(o))) { this.destroy(o); this.bonus += 5; this.superSmash(); }
        }
        if (Math.random() < dt * 8) this.shake = Math.max(this.shake, 2);
        break;

      case 'midas': { // Parasaurolophus — obstacles turn into gold
        for (const o of live) {
          if (o.x < W - 20 && o.x + o.w > 0) {
            o.dead = true;
            const cx = o.x + o.w / 2, cy = (o.kind === 'ground' ? gy - 20 : o.y + o.h / 2);
            for (let i = 0; i < 5; i++) this.coins.push({ x: cx + (i - 2) * 14, y: cy - Math.abs(i - 2) * -6 - 10 });
            for (let i = 0; i < 10; i++) this.sparkle(cx, cy, pick(['#ffd54f', '#fff59d', '#ffffff']));
            this.superSmash();
            sfx.play('coin', true);
          }
        }
        if (tick(0.14)) {
          const h = this.head();
          this.particles.push({ x: h.x - 6, y: h.y - 14, vx: rand(-60, 30), vy: rand(-90, -50), life: 1.1, max: 1.1, text: pick(['♪', '♫', '♬']), color: pick(['#ffd54f', '#ff8a80', '#80d8ff', '#b9f6ca']), size: 14 });
        }
        break;
      }

      case 'fortress': // Ankylosaurus — handled in collisions (pinball)
        break;

      case 'storm': { // Pteranodon — lightning on everything ahead
        if (tick(0.38)) {
          const o = live.filter((o) => o.x > d.x && o.x < W).sort((a, b) => a.x - b.x)[0];
          const h = this.head();
          if (o) {
            this.bolts.push({ x1: h.x, y1: h.y, x2: o.x + o.w / 2, y2: o.y + o.h / 2, life: 0.25, seed: Math.random() * 100 });
            this.destroy(o); this.bonus += 5; this.superSmash();
            sfx.play('zap', true);
            this.stormFlash = 0.12;
          } else if (Math.random() < 0.3) {
            const x = rand(W * 0.3, W);
            this.bolts.push({ x1: x + rand(-30, 30), y1: 0, x2: x, y2: gy, life: 0.2, seed: Math.random() * 100 });
            this.stormFlash = 0.08;
          }
        }
        for (let i = 0; i < 3; i++) this.particles.push({ x: rand(0, W + 100), y: -5, vx: -160, vy: 650, life: 0.8, max: 0.8, size: 1, color: '#b3e5fc', rain: true });
        break;
      }

      case 'wave': { // Spinosaurus — tsunami surf
        for (const o of live) {
          if (o.x < d.x + 120) { this.destroy(o); this.bonus += 5; this.superSmash(); this.splash(o.x, gy - 10, 10); }
        }
        if (Math.random() < dt * 4) {
          this.particles.push({ x: rand(d.x + 60, d.x + 160), y: gy - 10, vx: rand(-120, 60), vy: rand(-420, -300), g: 1200, life: 1, max: 1, text: '🐟', size: 14, color: '#fff' });
        }
        if (Math.random() < 0.7) this.splash(d.x + rand(60, 100), gy - 40 + rand(-10, 10), 1);
        break;
      }

      case 'meteors': { // Brachiosaurus — meteor shower on obstacles
        if (tick(0.24)) {
          const o = live.find((o) => !o.claimed && o.x > d.x + 50 && o.x < W + 40);
          const tx = o ? o.x + o.w / 2 : rand(d.x + 160, W);
          if (o) o.claimed = true;
          this.shots.push({ kind: 'fireball', sx: tx + 160, sy: -30, tx, ty: gy - 8, t: 0, dur: 0.45, x: tx + 160, y: -30 });
        }
        break;
      }

      case 'toxic': { // Dilophosaurus — poison fog ahead
        this.fx.frill = 0.2;
        const x0 = d.x + 60, x1 = d.x + 330;
        for (const o of live) {
          if (o.x < x1 && o.x + o.w > x0) {
            o.dead = true;
            this.superSmash(); this.bonus += 5;
            for (let i = 0; i < 14; i++) this.particles.push({ x: o.x + rand(0, o.w), y: o.y + rand(0, o.h), vx: rand(-30, 30), vy: rand(-90, -20), life: rand(0.5, 0.9), max: 0.9, size: rand(2, 4), color: pick(['#76ff03', '#b2ff59', '#33691e']), circle: true });
            this.texts(o.x + o.w / 2, o.y - 6, 'MELT!', '#b2ff59', 11);
            sfx.play('splash', true);
          }
        }
        break;
      }
      default: break;
    }
    for (const b of this.bolts) b.life -= dt;
    this.bolts = this.bolts.filter((b) => b.life > 0);
  }

  superSmash() { /* hook for future combo counters */ }

  updateShots(dt, dx) {
    const gy = this.gy;
    for (const s of this.shots) {
      if (s.kind === 'venom') {
        s.x += s.vx * dt; s.vy += 300 * dt; s.y += s.vy * dt; s.life -= dt;
        if (Math.random() < 0.6) this.particles.push({ x: s.x, y: s.y, vx: rand(-60, 0), vy: rand(-20, 20), life: 0.3, max: 0.3, size: 2, color: '#b2ff59' });
        for (const o of this.obstacles) {
          if (!o.dead && !o.flung && overlap({ x: s.x - 5, y: s.y - 5, w: 10, h: 10 }, this.hitbox(o))) {
            o.dead = true; s.life = 0;
            for (let i = 0; i < 14; i++) this.particles.push({ x: o.x + rand(0, o.w), y: o.y + rand(0, o.h), vx: rand(-30, 30), vy: rand(-90, -20), life: 0.7, max: 0.7, size: rand(2, 4), color: pick(['#76ff03', '#b2ff59']), circle: true });
            this.texts(o.x + o.w / 2, o.y - 6, 'MELT!', '#b2ff59', 11);
            sfx.play('splash', true);
            this.superMeter = Math.min(1, this.superMeter + SUPER_GAIN.smash);
            break;
          }
        }
        if (s.y > gy) s.life = 0;
      } else if (s.kind === 'fireball') {
        s.tx -= dx; s.sx -= dx;
        s.t += dt;
        const k = Math.min(1, s.t / s.dur);
        s.x = s.sx + (s.tx - s.sx) * k; s.y = s.sy + (s.ty - s.sy) * k;
        if (Math.random() < 0.9) this.particles.push({ x: s.x, y: s.y, vx: rand(20, 80), vy: rand(-60, -10), life: 0.35, max: 0.35, size: rand(2, 5), color: pick(['#ffeb3b', '#ff9800', '#ff5722']) });
        if (k >= 1) {
          s.life = 0;
          this.shake = Math.max(this.shake, 6);
          sfx.play('smash', true);
          this.rings.push({ x: s.tx, y: gy - 8, r: 6, max: 60, color: '#ff9800', life: 0.35, t: 0 });
          for (let i = 0; i < 16; i++) this.particles.push({ x: s.tx, y: gy - 6, vx: rand(-200, 200), vy: rand(-380, -80), g: 900, life: rand(0.4, 0.8), max: 0.8, size: rand(2, 5), color: pick(['#ffeb3b', '#ff9800', '#ff5722', '#5d4037']) });
          for (const o of this.obstacles) {
            if (!o.dead && Math.abs(o.x + o.w / 2 - s.tx) < 60) { this.destroy(o); this.bonus += 5; }
          }
        }
      }
    }
    this.shots = this.shots.filter((s) => (s.life === undefined || s.life > 0) && s.x > -50 && s.x < this.W + 300);
  }

  // ---------------------------------------------------------------- world
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
    const gy = this.gy;
    for (const o of this.obstacles) {
      o.x -= dx;
      if (o.flung) {
        o.x += o.flung.vx * dt; o.y += o.flung.vy * dt;
        o.flung.vy += 1500 * dt; o.flung.rot += o.flung.vr * dt;
        continue;
      }
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
    this.obstacles = this.obstacles.filter((o) => !o.dead && o.x + o.w > -60 && o.x < this.W + 400 && o.y < this.H + 80);

    const c = this.center();
    const magnet = this.fx.magnet > 0;
    for (const coin of this.coins) {
      coin.x -= dx;
      if (coin.vy) { coin.y += coin.vy * dt; if (coin.y >= gy - 14) { coin.y = gy - 14; coin.vy = 0; } }
      if (magnet) {
        const ddx = c.x - coin.x, ddy = c.y - coin.y, dist = Math.hypot(ddx, ddy);
        if (dist < 280) { coin.x += (ddx / dist) * 650 * dt; coin.y += (ddy / dist) * 650 * dt; }
      }
    }
    this.coins = this.coins.filter((coin) => !coin.taken && coin.x > -20);
    for (const p of this.powerups) p.x -= dx;
    this.powerups = this.powerups.filter((p) => !p.taken && p.x > -30);
    for (const b of this.bones) b.x -= dx;
    this.bones = this.bones.filter((b) => !b.taken && b.x > -30);
    for (const r of this.rings) { r.t += dt; r.r = 10 + (r.max - 10) * (r.t / r.life); }
    this.rings = this.rings.filter((r) => r.t < r.life);
  }

  collide() {
    const d = this.d, fx = this.fx;
    const pose = this.pose();
    const scale = this.isSuper('giant') ? 2 : 1;
    const boxes = dinoHitboxes(this.def, pose, d.x, d.y, scale);
    for (const o of this.obstacles) {
      if (o.dead || o.flung) continue;
      const hb = this.hitbox(o);
      if (!boxes.some((b) => overlap(b, hb))) continue;
      if (fx.dive > 0) continue; // underground: everything passes over
      if (this.isSuper('fortress')) { this.fling(o); continue; }
      const smash = fx.super > 0 || fx.dash > 0 || fx.rocket > 0 || fx.rise > 0 || (fx.charge > 0 && o.kind !== 'flyer');
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
    const c = this.center();
    const reachX = scale === 2 ? 40 : 24, reachY = scale === 2 ? 50 : 28;
    const dbl = fx.double > 0;
    for (const coin of this.coins) {
      if (Math.abs(coin.x - c.x) < reachX && Math.abs(coin.y - c.y) < reachY) {
        coin.taken = true;
        this.runCoins += dbl ? 2 : 1;
        if (!(fx.super > 0)) this.superMeter = Math.min(1, this.superMeter + SUPER_GAIN.coin);
        sfx.play('coin', true);
        this.sparkle(coin.x, coin.y, '#ffd54f');
      }
    }
    for (const p of this.powerups) {
      if (Math.abs(p.x - c.x) < 28 && Math.abs(p.y - c.y) < 32) {
        p.taken = true;
        sfx.play('power', true);
        this.superMeter = Math.min(1, this.superMeter + SUPER_GAIN.power);
        this.texts(p.x, p.y - 20, POWERUPS[p.type].name.toUpperCase(), POWERUPS[p.type].color, 12);
        if (p.type === 'shield') this.shield = true;
        if (p.type === 'magnet') fx.magnet = 9;
        if (p.type === 'double') fx.double = 10;
        if (p.type === 'rocket') { fx.rocket = 4.5; fx.soar = false; }
      }
    }
    for (const b of this.bones) {
      if (Math.abs(b.x - c.x) < 24 && Math.abs(b.y - c.y) < 30) {
        b.taken = true;
        this.bonus += 50;
        sfx.play('bonus', false);
        this.texts(b.x, b.y - 14, '+50', null, 12);
      }
    }
  }

  fling(o) {
    o.flung = { vx: rand(250, 520), vy: rand(-720, -420), rot: 0, vr: rand(-14, 14) };
    this.runCoins += 2;
    this.bonus += 5;
    sfx.play('smash', true);
    this.shake = Math.max(this.shake, 5);
    this.rings.push({ x: o.x + o.w / 2, y: o.y + o.h / 2, r: 4, max: 40, color: '#e3f2fd', life: 0.25, t: 0 });
    this.texts(o.x + o.w / 2, o.y - 10, 'BONK! +2🪙', '#e3f2fd', 11);
  }

  destroy(o) {
    if (o.dead) return;
    o.dead = true;
    sfx.play('smash', this.colorful);
    this.shake = Math.max(this.shake, 4);
    if (this.colorful && !(this.fx.super > 0)) this.superMeter = Math.min(1, this.superMeter + SUPER_GAIN.smash);
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
    this.endSuper(true);
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
  splash(x, y, n) {
    for (let i = 0; i < n; i++) this.particles.push({ x, y, vx: rand(-140, 140), vy: rand(-320, -120), g: 1100, life: rand(0.4, 0.7), max: 0.7, size: rand(2, 4), color: pick(['#e1f5fe', '#81d4fa', '#29b6f6']), circle: true });
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
    if (this.particles.length > 500) this.particles.splice(0, this.particles.length - 500);
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
      const c = this.center();
      const maxR = Math.hypot(Math.max(c.x, this.W - c.x), Math.max(c.y, this.H - c.y)) + 10;
      const r = ease(m) * maxR;
      ctx.save();
      ctx.beginPath(); ctx.arc(c.x, c.y, r, 0, Math.PI * 2); ctx.clip();
      this.drawScene(true);
      ctx.restore();
      const g = ctx.createLinearGradient(c.x - r, c.y, c.x + r, c.y);
      ['#ff1744', '#ff9100', '#ffea00', '#00e676', '#2979ff', '#d500f9'].forEach((col, i) => g.addColorStop(i / 5, col));
      ctx.strokeStyle = g; ctx.lineWidth = 5;
      ctx.beginPath(); ctx.arc(c.x, c.y, r, 0, Math.PI * 2); ctx.stroke();
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
      if (this.isSuper('storm')) {
        ctx.fillStyle = `rgba(15,20,55,${0.45 - this.stormFlash * 2})`;
        ctx.fillRect(0, 0, W, H);
      } else if (this.isSuper('meteors')) {
        ctx.fillStyle = 'rgba(255,90,0,.16)';
        ctx.fillRect(0, 0, W, H);
      } else if (this.isSuper('midas')) {
        ctx.fillStyle = 'rgba(255,215,64,.12)';
        ctx.fillRect(0, 0, W, H);
      }
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
    for (const o of this.obstacles) {
      if (o.flung) {
        ctx.save();
        ctx.translate(o.x + o.w / 2, o.y + o.h / 2);
        ctx.rotate(o.flung.rot);
        ctx.translate(-(o.x + o.w / 2), -(o.y + o.h / 2));
        drawObstacle(ctx, o, colorful, pal, t, cp.fg, gy);
        ctx.restore();
      } else drawObstacle(ctx, o, colorful, pal, t, cp.fg, gy);
    }

    if (colorful) this.drawSuperBack();

    for (const r of this.rings) {
      ctx.strokeStyle = colorful ? r.color : cp.fg;
      ctx.globalAlpha = 1 - r.t / r.life;
      ctx.lineWidth = 3;
      ctx.beginPath(); ctx.arc(r.x, r.y, r.r, 0, Math.PI * 2); ctx.stroke();
      ctx.globalAlpha = 1;
    }

    this.drawDinoLayer(colorful, cp);
    if (colorful) this.drawSuperFront();
    this.drawParticles(colorful, cp);
  }

  // effects behind the player
  drawSuperBack() {
    const ctx = this.ctx, d = this.d, gy = this.gy, t = this.time;
    if (this.isSuper('wave')) {
      const front = d.x + 110;
      const g = ctx.createLinearGradient(0, gy - 70, 0, gy + 20);
      g.addColorStop(0, '#4fc3f7'); g.addColorStop(1, '#01579b');
      ctx.fillStyle = g;
      ctx.beginPath();
      ctx.moveTo(-10, gy + 30);
      for (let x = -10; x <= front - 30; x += 8) ctx.lineTo(x, gy - 40 + Math.sin(x * 0.05 + t * 6) * 5);
      ctx.quadraticCurveTo(front, gy - 70, front + 10, gy - 34); // curling crest
      ctx.quadraticCurveTo(front - 4, gy - 30, front - 12, gy - 40);
      ctx.quadraticCurveTo(front + 20, gy - 10, front + 30, gy + 30);
      ctx.closePath();
      ctx.fill();
      ctx.strokeStyle = '#ffffff'; ctx.lineWidth = 3;
      ctx.beginPath();
      for (let x = -10; x <= front - 30; x += 8) ctx.lineTo(x, gy - 40 + Math.sin(x * 0.05 + t * 6) * 5);
      ctx.quadraticCurveTo(front, gy - 70, front + 10, gy - 34);
      ctx.stroke();
      // surfboard
      ctx.fillStyle = '#ffca28';
      ctx.beginPath(); ctx.ellipse(d.x + 30, d.y + 2, 34, 4, -0.08, 0, Math.PI * 2); ctx.fill();
      ctx.fillStyle = '#e53935'; ctx.fillRect(d.x + 10, d.y, 40, 2);
    }
    if (this.isSuper('toxic')) {
      const x0 = d.x + 60, span = 270;
      for (let i = 0; i < 18; i++) {
        const x = x0 + ((i * 41 + t * 50) % span);
        const y = gy - 12 - (i % 6) * 17 + Math.sin(t * 2 + i) * 6;
        const r = 16 + (i % 3) * 9;
        ctx.fillStyle = `rgba(${110 + (i % 3) * 30},230,70,0.22)`;
        ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.fill();
      }
      for (let i = 0; i < 6; i++) {
        const x = x0 + ((i * 53 + t * 80) % span), y = gy - ((t * 40 + i * 20) % 90);
        ctx.strokeStyle = 'rgba(178,255,89,.7)'; ctx.lineWidth = 1;
        ctx.beginPath(); ctx.arc(x, y, 2.5, 0, Math.PI * 2); ctx.stroke();
      }
    }
    if (this.isSuper('midas')) {
      const h = this.head();
      for (let i = 0; i < 3; i++) {
        const r = ((t * 120 + i * 60) % 180) + 10;
        ctx.strokeStyle = `rgba(255,215,64,${1 - r / 190})`;
        ctx.lineWidth = 2;
        ctx.beginPath(); ctx.arc(h.x - 10, h.y - 8, r, -0.9, 0.9); ctx.stroke();
      }
    }
    if (this.isSuper('pack') || this.isSuper('stampede')) {
      const kind = this.isSuper('pack') ? getDino('raptor') : getDino('tricera');
      for (const a of this.allies) {
        if (a.x < -80 || a.x > this.W + 80) continue;
        ctx.fillStyle = 'rgba(0,0,0,.2)';
        ctx.beginPath(); ctx.ellipse(a.x + 26, gy + 2, 16, 3, 0, 0, Math.PI * 2); ctx.fill();
        drawDino(ctx, kind, 'stand', a.y < gy ? 2 : a.frame, a.x, a.y, {});
      }
    }
    if (this.fx.frill > 0 && this.def.id === 'dilo') {
      const h = this.head();
      const cx = h.x - 6, cy = h.y + 8;
      ctx.fillStyle = this.def.colors.frill;
      ctx.beginPath(); ctx.arc(cx, cy, 13, Math.PI * 0.35, Math.PI * 1.65); ctx.closePath(); ctx.fill();
      ctx.strokeStyle = '#ffeb3b'; ctx.lineWidth = 1.5;
      for (let a = Math.PI * 0.45; a < Math.PI * 1.6; a += 0.3) {
        ctx.beginPath(); ctx.moveTo(cx, cy); ctx.lineTo(cx + Math.cos(a) * 12, cy + Math.sin(a) * 12); ctx.stroke();
      }
    }
  }

  // effects in front of the player
  drawSuperFront() {
    const ctx = this.ctx;
    if (this.isSuper('orbit')) {
      const c = this.center();
      for (let i = 0; i < 6; i++) {
        const a = this.superAngle + (i * Math.PI * 2) / 6;
        const px = c.x + Math.cos(a) * 50, py = c.y + Math.sin(a) * 50;
        ctx.save();
        ctx.translate(px, py);
        ctx.rotate(a + Math.PI / 2 + this.superAngle * 2);
        ctx.fillStyle = this.def.colors.accent;
        ctx.beginPath(); ctx.moveTo(0, -10); ctx.lineTo(8, 6); ctx.lineTo(-8, 6); ctx.closePath(); ctx.fill();
        ctx.strokeStyle = '#ffe0b2'; ctx.lineWidth = 1.5; ctx.stroke();
        ctx.restore();
      }
      ctx.strokeStyle = 'rgba(255,112,67,.25)'; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.arc(c.x, c.y, 50, 0, Math.PI * 2); ctx.stroke();
    }
    for (const b of this.bolts) {
      const segs = 7;
      const pts = [];
      for (let i = 0; i <= segs; i++) {
        const k = i / segs;
        const j = i === 0 || i === segs ? 0 : (Math.sin(b.seed + i * 12.9898) * 43758.5453 % 1) * 18;
        pts.push([b.x1 + (b.x2 - b.x1) * k + j, b.y1 + (b.y2 - b.y1) * k]);
      }
      for (const [w, col] of [[6, 'rgba(129,212,250,.5)'], [2.5, '#ffffff']]) {
        ctx.strokeStyle = col; ctx.lineWidth = w;
        ctx.beginPath(); pts.forEach(([x, y], i) => (i ? ctx.lineTo(x, y) : ctx.moveTo(x, y))); ctx.stroke();
      }
    }
    for (const s of this.shots) {
      if (s.kind === 'venom') {
        ctx.fillStyle = '#76ff03';
        ctx.beginPath(); ctx.arc(s.x, s.y, 5, 0, Math.PI * 2); ctx.fill();
        ctx.fillStyle = '#ccff90';
        ctx.beginPath(); ctx.arc(s.x - 1.5, s.y - 1.5, 2, 0, Math.PI * 2); ctx.fill();
      } else if (s.kind === 'fireball') {
        const g = ctx.createRadialGradient(s.x, s.y, 2, s.x, s.y, 16);
        g.addColorStop(0, '#fffde7'); g.addColorStop(0.4, '#ffb300'); g.addColorStop(1, 'rgba(255,61,0,0)');
        ctx.fillStyle = g;
        ctx.beginPath(); ctx.arc(s.x, s.y, 16, 0, Math.PI * 2); ctx.fill();
        ctx.fillStyle = '#4e342e';
        ctx.beginPath(); ctx.arc(s.x, s.y, 6, 0, Math.PI * 2); ctx.fill();
        // landing marker
        ctx.strokeStyle = 'rgba(255,87,34,.8)'; ctx.lineWidth = 2;
        ctx.beginPath(); ctx.ellipse(s.tx, s.ty + 6, 14, 3, 0, 0, Math.PI * 2); ctx.stroke();
      }
    }
  }

  drawDinoLayer(colorful, cp) {
    const ctx = this.ctx, d = this.d, fx = this.fx, gy = this.gy;
    let pose = 'stand', frame = 2;
    if (!d.dead && this.state === 'running') {
      if (d.ducking) { pose = 'duck'; frame = d.frame; } else if (d.onGround || this.isSuper('wave')) frame = this.isSuper('wave') ? 2 : d.frame;
      if (this.def.id === 'ptero' && (fx.rocket > 0 || this.isSuper('storm') || (!d.onGround && this.input.jump))) frame = Math.floor(this.time * 10) % 2;
    }
    const opts = colorful
      ? { dead: d.dead, tint: this.isSuper('fortress') ? 'steel' : this.isSuper('midas') ? null : null }
      : { classic: true, fg: cp.fg, bg: cp.bg, dead: d.dead };
    const { w, h } = poseSize(this.def, pose);

    if (colorful) {
      const hh = Math.max(0, gy - d.y);
      if (!this.isSuper('wave') && fx.dive <= 0) {
        ctx.fillStyle = `rgba(0,0,0,${0.25 * Math.max(0.2, 1 - hh / 150)})`;
        const sw = this.isSuper('giant') ? 2 : 1;
        ctx.beginPath(); ctx.ellipse(d.x + (w * sw) / 2, gy + 2, (w * sw) / 2.6 * Math.max(0.4, 1 - hh / 200), 3, 0, 0, Math.PI * 2); ctx.fill();
      }
      if (fx.dash > 0) {
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
      ctx.fillStyle = '#b0bec5'; ctx.fillRect(d.x + 2, d.y - 26, 8, 14);
      ctx.fillStyle = '#e53935'; ctx.fillRect(d.x + 2, d.y - 30, 8, 4);
    }

    if (colorful && this.isSuper('giant')) {
      ctx.save();
      ctx.translate(d.x, d.y);
      ctx.scale(2, 2);
      drawDino(ctx, this.def, pose, frame, 0, 0, opts);
      ctx.restore();
      // golden crown
      const hd = this.head();
      ctx.fillStyle = '#ffd54f';
      ctx.beginPath();
      ctx.moveTo(hd.x - 10, hd.y - 8); ctx.lineTo(hd.x - 10, hd.y - 20); ctx.lineTo(hd.x - 4, hd.y - 13);
      ctx.lineTo(hd.x + 2, hd.y - 22); ctx.lineTo(hd.x + 8, hd.y - 13); ctx.lineTo(hd.x + 14, hd.y - 20); ctx.lineTo(hd.x + 14, hd.y - 8);
      ctx.closePath(); ctx.fill();
      ctx.fillStyle = '#e53935'; ctx.fillRect(hd.x + 1, hd.y - 13, 3, 3);
    } else if (colorful && this.isSuper('ball')) {
      const cx = d.x + w / 2, cy = d.y - h / 2;
      ctx.save();
      ctx.translate(cx, cy);
      ctx.rotate(this.superAngle);
      drawDino(ctx, this.def, 'duck', 2, -poseSize(this.def, 'duck').w / 2, poseSize(this.def, 'duck').h / 2, opts);
      ctx.restore();
      ctx.strokeStyle = 'rgba(255,224,130,.8)'; ctx.lineWidth = 3;
      ctx.beginPath(); ctx.arc(cx, cy, 26, this.superAngle, this.superAngle + 4); ctx.stroke();
    } else if (fx.dive > 0 && colorful) {
      ctx.save();
      ctx.beginPath(); ctx.rect(0, 0, this.W, gy); ctx.clip();
      drawDino(ctx, this.def, pose, frame, d.x, d.y + h * 0.62, opts);
      ctx.restore();
      ctx.strokeStyle = '#81d4fa'; ctx.lineWidth = 2;
      for (let i = 0; i < 3; i++) {
        const r = ((this.time * 40 + i * 12) % 36) + 6;
        ctx.globalAlpha = 1 - r / 42;
        ctx.beginPath(); ctx.ellipse(d.x + w / 2, gy, r, r * 0.2, 0, 0, Math.PI * 2); ctx.stroke();
      }
      ctx.globalAlpha = 1;
      if (Math.random() < 0.4) this.splash(d.x + w * 0.8, gy, 1);
    } else {
      drawDino(ctx, this.def, pose, frame, d.x, d.y, opts);
    }
    ctx.globalAlpha = 1;

    if (colorful && this.isSuper('fortress')) {
      ctx.strokeStyle = `rgba(227,242,253,${0.5 + 0.5 * Math.sin(this.time * 10)})`;
      ctx.lineWidth = 2;
      ctx.strokeRect(d.x - 2, d.y - h - 2, w + 4, h + 4);
      if (Math.random() < 0.3) this.sparkle(d.x + rand(0, w), d.y - rand(0, h), '#ffffff');
    }
    if (colorful && fx.soar && fx.rocket > 0 && this.def.id !== 'ptero') {
      const flap = Math.sin(this.time * 20) * 8;
      ctx.fillStyle = '#ffffffcc';
      ctx.beginPath(); ctx.moveTo(d.x + 14, d.y - 24); ctx.lineTo(d.x - 10, d.y - 40 + flap); ctx.lineTo(d.x + 4, d.y - 22); ctx.fill();
    }
    if (colorful && (this.shield || fx.charge > 0)) {
      const c = this.center();
      ctx.lineWidth = 2;
      ctx.strokeStyle = fx.charge > 0 ? '#ffb74d' : '#4fc3f7';
      ctx.fillStyle = fx.charge > 0 ? 'rgba(255,183,77,.15)' : 'rgba(79,195,247,.15)';
      ctx.beginPath(); ctx.arc(c.x, c.y, Math.max(w, h) / 2 + 8 + Math.sin(this.time * 8) * 1.5, 0, Math.PI * 2); ctx.fill(); ctx.stroke();
    }
    if (colorful && this.fx.super > 0 && !this.isSuper('orbit')) {
      // glowing super aura
      const c = this.center();
      const s = this.isSuper('giant') ? 2 : 1;
      ctx.strokeStyle = `hsla(${(this.time * 300) % 360},100%,65%,.6)`;
      ctx.lineWidth = 2;
      ctx.beginPath(); ctx.arc(c.x, c.y, (Math.max(w, h) / 2 + 12) * s, 0, Math.PI * 2); ctx.stroke();
    }
  }

  drawParticles(colorful, cp) {
    const ctx = this.ctx;
    for (const p of this.particles) {
      if (!colorful && (p.w || p.rain)) continue; // weather is a colorful-only thing
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
      } else if (p.rain) {
        ctx.strokeStyle = col; ctx.lineWidth = 1;
        ctx.beginPath(); ctx.moveTo(p.x, p.y); ctx.lineTo(p.x + 3, p.y - 12); ctx.stroke();
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
      ctx.font = '800 14px system-ui, sans-serif';
      const ctext = `${this.runCoins}`;
      ctx.strokeText(ctext, W - 12, 45);
      ctx.fillStyle = '#ffd54f';
      ctx.fillText(ctext, W - 12, 45);
      const tw = ctx.measureText(ctext).width;
      drawCoin(ctx, { x: W - 22 - tw, y: 52 }, 0);
      const fx = this.fx;
      const act = [];
      if (this.shield) act.push(['🛡️', 1]);
      if (fx.magnet > 0) act.push(['🧲', fx.magnet / 9]);
      if (fx.double > 0) act.push(['×2', fx.double / 10]);
      if (fx.rocket > 0) act.push([fx.soar ? '🪽' : '🚀', fx.rocket / 4.5]);
      if (fx.charge > 0) act.push(['💥', fx.charge / 3]);
      if (fx.dive > 0) act.push(['🌊', fx.dive / 1.8]);
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
      // super power timer bar
      if (fx.super > 0) {
        const bw = Math.min(220, W * 0.4), bx = (W - bw) / 2, by = 30;
        ctx.fillStyle = 'rgba(0,0,0,.45)';
        ctx.fillRect(bx - 2, by - 2, bw + 4, 10);
        const g = ctx.createLinearGradient(bx, 0, bx + bw, 0);
        ['#ff5252', '#ffd740', '#69f0ae', '#40c4ff', '#e040fb'].forEach((c, i) => g.addColorStop(i / 4, c));
        ctx.fillStyle = g;
        ctx.fillRect(bx, by, bw * (fx.super / this.def.super.dur), 6);
        ctx.font = '800 10px system-ui, sans-serif';
        ctx.textAlign = 'center'; ctx.textBaseline = 'top';
        ctx.lineWidth = 3; ctx.strokeStyle = 'rgba(0,0,0,.6)';
        ctx.strokeText(this.def.super.name.toUpperCase(), W / 2, by + 9);
        ctx.fillStyle = '#fff';
        ctx.fillText(this.def.super.name.toUpperCase(), W / 2, by + 9);
      }
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
      const tw = ctx.measureText(b.text).width;
      if (tw > W - 20) { const k = (W - 20) / tw; ctx.scale(k, k); }
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

// Backgrounds, biomes and obstacle / pickup art for both modes.

export const BIOMES = [
  { id: 'jungle', name: 'Jungle', sky: ['#5ec8f2', '#d6f6ff'], far: '#7cc69a', mid: '#3f9a5a', near: '#2a7140',
    ground: '#7a5230', groundTop: '#5dbb46', pebble: '#5e3d22', sun: '#fff3b0', decor: 'tree', weather: 'leaf',
    obstacle: 'stump', flyer: '#8e5a2b', flyerWing: '#c98b4c' },
  { id: 'desert', name: 'Desert', sky: ['#ff9f43', '#ffe6b8'], far: '#f0b77a', mid: '#d69454', near: '#b9743a',
    ground: '#e0a95f', groundTop: '#f2cb88', pebble: '#b98245', sun: '#fff7d6', decor: 'cactus', weather: 'dust',
    obstacle: 'cactus', flyer: '#c0392b', flyerWing: '#e67e22' },
  { id: 'glacier', name: 'Glacier', sky: ['#7fc3ff', '#eef8ff'], far: '#d6ecff', mid: '#a9d2f5', near: '#80b4e0',
    ground: '#dcecff', groundTop: '#ffffff', pebble: '#a9c8ea', sun: '#ffffff', decor: 'pine', weather: 'snow',
    obstacle: 'ice', flyer: '#455a64', flyerWing: '#90a4ae' },
  { id: 'volcano', name: 'Volcano', sky: ['#2a0a17', '#ff6a3d'], far: '#5a1f26', mid: '#3a1418', near: '#240c0f',
    ground: '#2e1b1b', groundTop: '#ff5722', pebble: '#ff8a50', sun: '#ff3d00', decor: 'volcano', weather: 'ember',
    obstacle: 'lava', flyer: '#212121', flyerWing: '#ff5722', meteors: true },
  { id: 'cosmic', name: 'Cosmic', sky: ['#070320', '#4b1d7a'], far: '#2c1460', mid: '#1f0e48', near: '#150933',
    ground: '#1d0d42', groundTop: '#b388ff', pebble: '#7c4dff', sun: '#ffd1ff', decor: 'crystal', weather: 'star',
    obstacle: 'crystal', flyer: 'ufo', meteors: true },
];

// ---- color helpers --------------------------------------------------------------
const rgbCache = new Map();
function rgb(hex) {
  let v = rgbCache.get(hex);
  if (v) return v;
  const h = hex.replace('#', '');
  v = [parseInt(h.slice(0, 2), 16), parseInt(h.slice(2, 4), 16), parseInt(h.slice(4, 6), 16)];
  rgbCache.set(hex, v);
  return v;
}
export function lerpColor(a, b, t) {
  if (t <= 0) return a;
  if (t >= 1) return b;
  const A = rgb(a), B = rgb(b);
  const c = A.map((x, i) => Math.round(x + (B[i] - x) * t));
  return `#${c.map((x) => x.toString(16).padStart(2, '0')).join('')}`;
}
export function hash(n) {
  const s = Math.sin(n * 127.1 + 311.7) * 43758.5453;
  return s - Math.floor(s);
}

export function biomePalette(from, to, t) {
  const keys = ['far', 'mid', 'near', 'ground', 'groundTop', 'pebble', 'sun'];
  const out = { decor: t < 0.5 ? from.decor : to.decor, id: t < 0.5 ? from.id : to.id, src: t < 0.5 ? from : to };
  for (const k of keys) out[k] = lerpColor(from[k], to[k], t);
  out.sky = [lerpColor(from.sky[0], to.sky[0], t), lerpColor(from.sky[1], to.sky[1], t)];
  return out;
}

function hill(x, seed, amp) {
  return amp * (Math.sin(x * 0.004 + seed) * 0.6 + Math.sin(x * 0.011 + seed * 2.3) * 0.3 + Math.sin(x * 0.027 + seed * 3.7) * 0.1);
}

// ---- decor silhouettes -------------------------------------------------------------
function decor(ctx, type, x, y, s, color, accent) {
  ctx.fillStyle = color;
  switch (type) {
    case 'tree':
      ctx.fillRect(x - 2 * s, y - 18 * s, 4 * s, 18 * s);
      ctx.beginPath();
      ctx.arc(x, y - 24 * s, 10 * s, 0, Math.PI * 2);
      ctx.arc(x - 8 * s, y - 18 * s, 7 * s, 0, Math.PI * 2);
      ctx.arc(x + 8 * s, y - 18 * s, 7 * s, 0, Math.PI * 2);
      ctx.fill();
      break;
    case 'cactus':
      ctx.fillRect(x - 3 * s, y - 26 * s, 6 * s, 26 * s);
      ctx.fillRect(x - 10 * s, y - 16 * s, 4 * s, 9 * s);
      ctx.fillRect(x - 10 * s, y - 10 * s, 8 * s, 3 * s);
      ctx.fillRect(x + 6 * s, y - 20 * s, 4 * s, 10 * s);
      ctx.fillRect(x + 2 * s, y - 13 * s, 8 * s, 3 * s);
      break;
    case 'pine':
      for (let i = 0; i < 3; i++) {
        ctx.beginPath();
        const ty = y - (8 + i * 9) * s;
        ctx.moveTo(x, ty - 12 * s);
        ctx.lineTo(x - (12 - i * 3) * s, ty + 4 * s);
        ctx.lineTo(x + (12 - i * 3) * s, ty + 4 * s);
        ctx.fill();
      }
      if (accent) {
        ctx.fillStyle = accent;
        ctx.beginPath();
        ctx.moveTo(x, y - 38 * s); ctx.lineTo(x - 3 * s, y - 33 * s); ctx.lineTo(x + 3 * s, y - 33 * s); ctx.fill();
      }
      break;
    case 'volcano':
      ctx.beginPath();
      ctx.moveTo(x - 9 * s, y);
      ctx.lineTo(x - 2 * s, y - 20 * s);
      ctx.lineTo(x + 1 * s, y - 14 * s);
      ctx.lineTo(x + 4 * s, y - 24 * s);
      ctx.lineTo(x + 9 * s, y);
      ctx.fill();
      break;
    case 'crystal':
      for (const [dx, h, w] of [[-6, 20, 5], [0, 30, 6], [7, 16, 5]]) {
        ctx.beginPath();
        ctx.moveTo(x + (dx - w) * s, y);
        ctx.lineTo(x + dx * s, y - h * s);
        ctx.lineTo(x + (dx + w) * s, y);
        ctx.fill();
      }
      break;
    default: break;
  }
}

// ---- colorful background ---------------------------------------------------------------
export function drawColorBackground(ctx, W, H, gy, scroll, time, pal) {
  const sky = ctx.createLinearGradient(0, 0, 0, gy);
  sky.addColorStop(0, pal.sky[0]);
  sky.addColorStop(1, pal.sky[1]);
  ctx.fillStyle = sky;
  ctx.fillRect(0, 0, W, gy + 2);

  const dark = pal.id === 'cosmic' || pal.id === 'volcano';
  // stars
  if (dark) {
    for (let i = 0; i < 70; i++) {
      const x = (hash(i) * W * 1.5 - scroll * 0.01) % W;
      const y = hash(i + 99) * gy * 0.75;
      const tw = 0.5 + 0.5 * Math.sin(time * 3 + i);
      ctx.globalAlpha = (pal.id === 'cosmic' ? 0.9 : 0.35) * tw;
      ctx.fillStyle = '#fff';
      ctx.fillRect((x + W) % W, y, 1.5, 1.5);
    }
    ctx.globalAlpha = 1;
  }

  // sun / planet
  const sx = W * 0.78, sy = gy * 0.28;
  if (pal.id === 'cosmic') {
    ctx.fillStyle = '#ff9ff3';
    ctx.beginPath(); ctx.arc(sx, sy, 22, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = 'rgba(255,255,255,.25)';
    ctx.beginPath(); ctx.arc(sx - 6, sy - 6, 9, 0, Math.PI * 2); ctx.fill();
    ctx.strokeStyle = '#ffd1ff'; ctx.lineWidth = 3;
    ctx.beginPath(); ctx.ellipse(sx, sy, 38, 9, -0.35, 0, Math.PI * 2); ctx.stroke();
  } else {
    const glow = ctx.createRadialGradient(sx, sy, 4, sx, sy, 60);
    glow.addColorStop(0, pal.sun);
    glow.addColorStop(0.35, pal.sun + 'aa');
    glow.addColorStop(1, pal.sun + '00');
    ctx.fillStyle = glow;
    ctx.beginPath(); ctx.arc(sx, sy, 60, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = pal.sun;
    ctx.beginPath(); ctx.arc(sx, sy, 18, 0, Math.PI * 2); ctx.fill();
  }

  // clouds
  if (!dark) {
    ctx.fillStyle = 'rgba(255,255,255,.85)';
    for (let i = 0; i < 6; i++) {
      const span = W + 200;
      const x = ((hash(i + 5) * span - scroll * (0.05 + hash(i) * 0.05) - time * 6) % span + span) % span - 100;
      const y = 18 + hash(i + 50) * gy * 0.35;
      const s = 0.7 + hash(i + 7) * 0.8;
      ctx.beginPath();
      ctx.moveTo(x + 12 * s, y); ctx.arc(x, y, 12 * s, 0, Math.PI * 2);
      ctx.moveTo(x + 29 * s, y - 6 * s); ctx.arc(x + 14 * s, y - 6 * s, 15 * s, 0, Math.PI * 2);
      ctx.moveTo(x + 41 * s, y); ctx.arc(x + 30 * s, y, 11 * s, 0, Math.PI * 2);
      ctx.rect(x, y, 30 * s, 11 * s);
      ctx.fill('nonzero');
    }
  }

  // parallax hills
  const layers = [
    { f: 0.08, amp: 34, base: gy - 62, color: pal.far, decor: pal.decor === 'volcano' ? 'volcano' : null, big: true },
    { f: 0.22, amp: 20, base: gy - 32, color: pal.mid, decor: pal.decor, spacing: 95 },
    { f: 0.5, amp: 8, base: gy - 10, color: pal.near, decor: pal.decor === 'volcano' ? 'crystal' : pal.decor, spacing: 170, small: true },
  ];
  layers.forEach((L, li) => {
    const off = scroll * L.f;
    ctx.fillStyle = L.color;
    ctx.beginPath();
    ctx.moveTo(0, gy + 1);
    for (let x = 0; x <= W + 8; x += 8) ctx.lineTo(x, L.base + hill(x + off, li * 3.1, L.amp));
    ctx.lineTo(W, gy + 1);
    ctx.closePath();
    ctx.fill();

    if (L.big && L.decor === 'volcano') {
      // a slow giant volcano with glow
      const span = W + 400;
      const vx = ((W * 0.35 - off * 0.6) % span + span) % span - 150;
      const vy = gy - 18;
      decor(ctx, 'volcano', vx, vy, 5, L.color);
      const g = ctx.createRadialGradient(vx + 15, vy - 120, 2, vx + 15, vy - 120, 40);
      g.addColorStop(0, 'rgba(255,140,0,.9)'); g.addColorStop(1, 'rgba(255,60,0,0)');
      ctx.fillStyle = g;
      ctx.beginPath(); ctx.arc(vx + 15, vy - 120, 40, 0, Math.PI * 2); ctx.fill();
    }
    if (L.spacing && L.decor) {
      const start = Math.floor(off / L.spacing) - 1;
      for (let i = start; i < start + W / L.spacing + 3; i++) {
        if (hash(i * 3.3 + li) < 0.45) continue;
        const x = i * L.spacing - off + hash(i) * L.spacing * 0.6;
        const y = L.base + hill(x + off, li * 3.1, L.amp) + 2;
        const s = (L.small ? 0.8 : 0.65) * (0.7 + hash(i + 1) * 0.6);
        decor(ctx, L.decor, x, y, s, L.color, pal.id === 'glacier' ? '#ffffff' : null);
      }
    }
  });

  // ground
  ctx.fillStyle = pal.ground;
  ctx.fillRect(0, gy, W, H - gy);
  ctx.fillStyle = pal.groundTop;
  ctx.fillRect(0, gy - 1, W, 5);
  // underground strata + fossils (visible on tall/portrait screens)
  if (H - gy > 80) {
    for (let i = 1; (gy + 40 + (i - 1) * 70) < H; i++) {
      const by = gy + 40 + (i - 1) * 70;
      ctx.fillStyle = lerpColor(pal.ground, '#000000', Math.min(0.5, i * 0.09));
      ctx.beginPath();
      ctx.moveTo(0, H);
      for (let x = 0; x <= W + 10; x += 10) ctx.lineTo(x, by + Math.sin((x + scroll * 0.9) * 0.03 + i) * 4);
      ctx.lineTo(W, H);
      ctx.fill();
    }
    ctx.globalAlpha = 0.25;
    ctx.fillStyle = '#ffffff';
    const fs = 260, f0 = Math.floor(scroll / fs);
    for (let i = f0; i < f0 + W / fs + 2; i++) {
      const fx = i * fs - scroll + hash(i + 400) * 100;
      const fy = gy + 60 + hash(i + 401) * (H - gy - 80);
      if (hash(i + 402) < 0.5) {
        ctx.fillRect(fx - 10, fy - 1.5, 20, 3);
        ctx.beginPath(); ctx.arc(fx - 10, fy, 3.5, 0, Math.PI * 2); ctx.arc(fx + 10, fy, 3.5, 0, Math.PI * 2); ctx.fill();
      } else {
        ctx.strokeStyle = '#ffffff'; ctx.lineWidth = 2;
        ctx.beginPath();
        for (let a = 0; a < Math.PI * 5; a += 0.3) ctx.lineTo(fx + Math.cos(a) * a * 1.4, fy + Math.sin(a) * a * 1.4);
        ctx.stroke();
      }
    }
    ctx.globalAlpha = 1;
  }
  // pebbles / texture
  ctx.fillStyle = pal.pebble;
  const sp = 23;
  const start = Math.floor(scroll / sp);
  for (let i = start; i < start + W / sp + 2; i++) {
    const x = i * sp - scroll + hash(i) * 10;
    const y = gy + 8 + hash(i + 3) * Math.min(28, H - gy - 10);
    ctx.fillRect(x, y, 2 + hash(i + 9) * 4, 2);
  }
  if (pal.id === 'jungle') {
    ctx.fillStyle = '#3e9b2f';
    for (let i = start; i < start + W / sp + 2; i++) {
      if (hash(i + 21) < 0.5) continue;
      const x = i * sp - scroll + hash(i + 2) * 12;
      ctx.fillRect(x, gy - 4, 2, 4); ctx.fillRect(x + 3, gy - 6, 2, 6); ctx.fillRect(x + 6, gy - 3, 2, 3);
    }
  }
  if (pal.id === 'volcano') {
    // lava glow cracks
    for (let i = start; i < start + W / sp + 2; i++) {
      if (hash(i + 77) < 0.6) continue;
      const x = i * sp - scroll;
      ctx.fillStyle = `rgba(255,${90 + Math.floor(60 * Math.sin(time * 4 + i))},0,.8)`;
      ctx.fillRect(x, gy + 12 + hash(i) * 10, 10, 2);
    }
  }
}

// ---- classic background ------------------------------------------------------------------
export function drawClassicBackground(ctx, W, H, gy, scroll, time, pal, nightT) {
  ctx.fillStyle = pal.bg;
  ctx.fillRect(0, 0, W, H);

  if (nightT > 0.01) {
    ctx.globalAlpha = nightT;
    // moon
    ctx.fillStyle = pal.fg;
    const mx = W * 0.75 - ((scroll * 0.01) % (W * 0.5)), my = gy * 0.3;
    ctx.beginPath(); ctx.arc(mx, my, 12, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = pal.bg;
    ctx.beginPath(); ctx.arc(mx + 6, my - 3, 11, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = pal.fg;
    for (let i = 0; i < 14; i++) {
      const x = ((hash(i) * W * 2 - scroll * 0.02) % W + W) % W;
      ctx.fillRect(x, hash(i + 40) * gy * 0.6, 1.5, 1.5);
    }
    ctx.globalAlpha = 1;
  }

  // clouds
  ctx.strokeStyle = pal.cloud;
  ctx.lineWidth = 1.5;
  for (let i = 0; i < 4; i++) {
    const span = W + 120;
    const x = ((hash(i + 13) * span - scroll * 0.18) % span + span) % span - 60;
    const y = 24 + hash(i + 31) * gy * 0.4;
    ctx.beginPath();
    ctx.moveTo(x, y + 8);
    ctx.lineTo(x + 42, y + 8);
    ctx.arc(x + 34, y + 3, 6, Math.PI * 0.5, -Math.PI * 0.4, true);
    ctx.arc(x + 22, y, 9, -0.2, Math.PI * 1.1, true);
    ctx.arc(x + 8, y + 3, 6, -Math.PI * 0.6, Math.PI * 0.5, true);
    ctx.stroke();
  }

  // horizon line with bumps
  ctx.fillStyle = pal.fg;
  const lineY = gy - 3;
  ctx.fillRect(0, lineY, W, 1.5);
  const seg = 40;
  const s0 = Math.floor(scroll / seg);
  for (let i = s0; i < s0 + W / seg + 2; i++) {
    const x = i * seg - scroll;
    const r = hash(i);
    if (r > 0.82) { ctx.fillRect(x, lineY - 2, 6, 2); ctx.fillRect(x + 6, lineY - 1, 3, 1); }
    // ground specks
    ctx.fillRect(x + r * 20, gy + 3 + hash(i + 5) * 8, 2 + hash(i + 2) * 4, 1);
    if (r < 0.3) ctx.fillRect(x + 25, gy + 6, 1.5, 1.5);
  }
}

// ---- obstacles ---------------------------------------------------------------------------
function rr(ctx, x, y, w, h, r) {
  ctx.beginPath();
  if (ctx.roundRect) ctx.roundRect(x, y, w, h, r); else ctx.rect(x, y, w, h);
}

function classicCactus(ctx, x, y, w, h, seed, fg) {
  ctx.fillStyle = fg;
  const tw = Math.max(5, Math.round(w * 0.36));
  const tx = x + Math.round((w - tw) / 2);
  ctx.fillRect(tx, y + 2, tw, h - 2);
  ctx.fillRect(tx + 1, y, tw - 2, 2);
  const armW = Math.max(3, Math.round(tw * 0.6));
  const lA = y + h * (0.25 + seed * 0.15);
  ctx.fillRect(x, lA, armW, h * 0.3);
  ctx.fillRect(x, lA + h * 0.3 - 3, tx - x, 3);
  const rA = y + h * (0.18 + (1 - seed) * 0.18);
  ctx.fillRect(x + w - armW, rA, armW, h * 0.28);
  ctx.fillRect(tx + tw, rA + h * 0.28 - 3, x + w - armW - tx - tw + armW, 3);
}

function colorCactus(ctx, x, y, w, h, seed) {
  const tw = Math.max(6, Math.round(w * 0.4));
  const tx = x + (w - tw) / 2;
  ctx.fillStyle = '#1f7a3a';
  rr(ctx, tx - 1, y - 1, tw + 2, h + 1, tw / 2); ctx.fill();
  const armW = Math.max(4, Math.round(tw * 0.6));
  const lA = y + h * (0.25 + seed * 0.15);
  rr(ctx, x - 1, lA - 1, armW + 2, h * 0.32 + 2, armW / 2); ctx.fill();
  ctx.fillRect(x, lA + h * 0.3 - 4, tx - x + 2, 5);
  const rA = y + h * (0.18 + (1 - seed) * 0.18);
  rr(ctx, x + w - armW - 1, rA - 1, armW + 2, h * 0.3 + 2, armW / 2); ctx.fill();
  ctx.fillRect(tx + tw - 2, rA + h * 0.28 - 4, x + w - armW - tx - tw + 4, 5);
  ctx.fillStyle = '#34b257';
  rr(ctx, tx, y, tw, h, tw / 2); ctx.fill();
  rr(ctx, x, lA, armW, h * 0.3, armW / 2); ctx.fill();
  rr(ctx, x + w - armW, rA, armW, h * 0.28, armW / 2); ctx.fill();
  ctx.fillStyle = '#7fe08f';
  ctx.fillRect(tx + tw * 0.3, y + 4, 1.5, h - 8);
  ctx.fillStyle = '#ff6fa8';
  ctx.beginPath(); ctx.arc(tx + tw / 2, y + 1, 3, 0, Math.PI * 2); ctx.fill();
}

function colorStump(ctx, x, y, w, h, seed) {
  const sw = w * 0.82, sx = x + (w - sw) / 2;
  const g = ctx.createLinearGradient(sx, 0, sx + sw, 0);
  g.addColorStop(0, '#5a3618'); g.addColorStop(0.5, '#8b5a2b'); g.addColorStop(1, '#5a3618');
  ctx.fillStyle = g;
  ctx.fillRect(sx, y + 4, sw, h - 4);
  ctx.fillStyle = '#d9a066';
  ctx.beginPath(); ctx.ellipse(sx + sw / 2, y + 4, sw / 2, 4, 0, 0, Math.PI * 2); ctx.fill();
  ctx.strokeStyle = '#a8703d'; ctx.lineWidth = 1;
  ctx.beginPath(); ctx.ellipse(sx + sw / 2, y + 4, sw / 4, 2, 0, 0, Math.PI * 2); ctx.stroke();
  ctx.fillStyle = '#4caf50';
  ctx.fillRect(sx, y + 5, sw, 3);
  ctx.fillRect(sx + sw * 0.2, y + 7, 3, 5 + seed * 6);
  ctx.fillRect(sx + sw * 0.7, y + 7, 3, 3 + seed * 8);
  if (h > 40) {
    ctx.fillStyle = '#e53935';
    ctx.beginPath(); ctx.arc(sx + sw, y + h * 0.55, 5, Math.PI, 0); ctx.fill();
    ctx.fillStyle = '#fff';
    ctx.fillRect(sx + sw - 2, y + h * 0.55 - 3, 2, 2);
  }
}

function colorSpikes(ctx, x, y, w, h, seed, c1, c2, edge) {
  const spikes = [[0.15, 0.6, 0.3], [0.5, 1, 0.38], [0.85, 0.7, 0.3]];
  for (const [cx, hh, ww] of spikes) {
    const px = x + w * cx, top = y + h * (1 - hh * (0.85 + seed * 0.15));
    const g = ctx.createLinearGradient(px, top, px, y + h);
    g.addColorStop(0, c1); g.addColorStop(1, c2);
    ctx.fillStyle = g;
    ctx.beginPath();
    ctx.moveTo(px - w * ww, y + h);
    ctx.lineTo(px, top);
    ctx.lineTo(px + w * ww, y + h);
    ctx.closePath();
    ctx.fill();
    ctx.strokeStyle = edge; ctx.lineWidth = 1;
    ctx.beginPath(); ctx.moveTo(px, top + 2); ctx.lineTo(px - w * ww * 0.4, y + h - 2); ctx.stroke();
  }
}

function colorLava(ctx, x, y, w, h, seed, time) {
  ctx.fillStyle = '#2b2020';
  ctx.beginPath();
  ctx.moveTo(x, y + h);
  ctx.lineTo(x + w * 0.1, y + h * 0.35);
  ctx.lineTo(x + w * 0.4, y);
  ctx.lineTo(x + w * 0.75, y + h * 0.15);
  ctx.lineTo(x + w, y + h * 0.5);
  ctx.lineTo(x + w, y + h);
  ctx.closePath();
  ctx.fill();
  const glow = 0.6 + 0.4 * Math.sin(time * 6 + seed * 10);
  ctx.strokeStyle = `rgba(255,${100 + 80 * glow | 0},0,${glow})`;
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(x + w * 0.3, y + h * 0.2); ctx.lineTo(x + w * 0.45, y + h * 0.55); ctx.lineTo(x + w * 0.35, y + h * 0.9);
  ctx.moveTo(x + w * 0.45, y + h * 0.55); ctx.lineTo(x + w * 0.75, y + h * 0.7);
  ctx.stroke();
}

function drawGround(ctx, o, colorful, pal, time, fg) {
  const n = o.n || 1;
  const uw = o.w / n;
  for (let i = 0; i < n; i++) {
    const seed = hash(o.seed + i);
    const ux = o.x + i * uw;
    const uh = o.h * (i === 1 || n === 1 ? 1 : 0.86);
    const uy = o.y + (o.h - uh);
    if (!colorful) { classicCactus(ctx, ux, uy, uw, uh, seed, fg); continue; }
    switch (o.skin) {
      case 'stump': colorStump(ctx, ux, uy, uw, uh, seed); break;
      case 'ice': colorSpikes(ctx, ux, uy, uw, uh, seed, '#ffffff', '#6ec6ff', '#e3f6ff'); break;
      case 'lava': colorLava(ctx, ux, uy, uw, uh, seed, time); break;
      case 'crystal': colorSpikes(ctx, ux, uy, uw, uh, seed, '#ea80fc', '#651fff', '#ffd1ff'); break;
      case 'meteorite': colorLava(ctx, ux, uy, uw, uh, seed, time); break;
      default: colorCactus(ctx, ux, uy, uw, uh, seed);
    }
  }
}

function drawFlyer(ctx, o, colorful, pal, time, fg) {
  const flap = Math.floor(time * 6 + o.seed) % 2;
  const { x, y, w, h } = o;
  if (!colorful) {
    ctx.fillStyle = fg;
    // simple original bird: beak left, body, tail right
    ctx.fillRect(x, y + 12, 6, 3);
    ctx.fillRect(x + 6, y + 9, 8, 8);
    ctx.fillRect(x + 14, y + 12, 22, 6);
    ctx.fillRect(x + 36, y + 10, 6, 3);
    ctx.fillStyle = '#fff';
    ctx.fillRect(x + 9, y + 11, 2, 2);
    ctx.fillStyle = fg;
    if (flap) { ctx.fillRect(x + 18, y, 5, 12); ctx.fillRect(x + 23, y + 4, 4, 8); }
    else { ctx.fillRect(x + 18, y + 18, 5, 12); ctx.fillRect(x + 23, y + 18, 4, 8); }
    return;
  }
  const b = o.biome || BIOMES[0];
  if (b.flyer === 'ufo') {
    const cx = x + w / 2, cy = y + h / 2 + Math.sin(time * 5 + o.seed) * 2;
    ctx.fillStyle = 'rgba(160,255,240,.7)';
    ctx.beginPath(); ctx.ellipse(cx, cy - 4, 9, 8, 0, Math.PI, 0); ctx.fill();
    ctx.fillStyle = '#b0bec5';
    ctx.beginPath(); ctx.ellipse(cx, cy, w / 2, 6, 0, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = '#78909c';
    ctx.fillRect(cx - w / 2 + 4, cy + 1, w - 8, 2);
    for (let i = 0; i < 4; i++) {
      ctx.fillStyle = (Math.floor(time * 8) + i) % 2 ? '#ffeb3b' : '#ff4081';
      ctx.beginPath(); ctx.arc(cx - 13 + i * 9, cy, 1.8, 0, Math.PI * 2); ctx.fill();
    }
    return;
  }
  // pterosaur facing left
  const bodyC = b.flyer, wingC = b.flyerWing;
  const cy = y + h / 2;
  ctx.fillStyle = wingC;
  ctx.beginPath();
  if (flap) { ctx.moveTo(x + 16, cy); ctx.lineTo(x + 30, y - 4); ctx.lineTo(x + 34, cy); }
  else { ctx.moveTo(x + 16, cy); ctx.lineTo(x + 30, y + h + 6); ctx.lineTo(x + 34, cy); }
  ctx.fill();
  ctx.fillStyle = bodyC;
  ctx.beginPath(); ctx.ellipse(x + 26, cy, 13, 5, 0, 0, Math.PI * 2); ctx.fill();
  ctx.beginPath(); ctx.arc(x + 12, cy - 3, 6, 0, Math.PI * 2); ctx.fill();
  // beak + crest
  ctx.beginPath(); ctx.moveTo(x + 8, cy - 5); ctx.lineTo(x - 4, cy - 1); ctx.lineTo(x + 8, cy); ctx.fill();
  ctx.beginPath(); ctx.moveTo(x + 14, cy - 7); ctx.lineTo(x + 24, cy - 12); ctx.lineTo(x + 17, cy - 3); ctx.fill();
  ctx.fillStyle = '#fff';
  ctx.beginPath(); ctx.arc(x + 11, cy - 4, 1.8, 0, Math.PI * 2); ctx.fill();
  ctx.fillStyle = '#000';
  ctx.fillRect(x + 10, cy - 5, 1.2, 1.2);
}

function drawMeteor(ctx, o, time, gy) {
  // warning marker
  const pulse = 0.5 + 0.5 * Math.sin(time * 18);
  ctx.strokeStyle = `rgba(255,60,40,${0.4 + pulse * 0.6})`;
  ctx.lineWidth = 2;
  ctx.beginPath(); ctx.ellipse(o.x + o.w / 2, gy, 16, 4, 0, 0, Math.PI * 2); ctx.stroke();
  // trail
  const cx = o.x + o.w / 2, cy = o.y + o.h / 2;
  const g = ctx.createLinearGradient(cx, cy, cx + 30, cy - 60);
  g.addColorStop(0, 'rgba(255,200,60,.9)'); g.addColorStop(1, 'rgba(255,60,0,0)');
  ctx.fillStyle = g;
  ctx.beginPath(); ctx.moveTo(cx - 9, cy); ctx.lineTo(cx + 34, cy - 70); ctx.lineTo(cx + 9, cy); ctx.fill();
  ctx.fillStyle = '#4e342e';
  ctx.beginPath(); ctx.arc(cx, cy, 10, 0, Math.PI * 2); ctx.fill();
  ctx.fillStyle = '#ff7043';
  ctx.beginPath(); ctx.arc(cx - 3, cy + 2, 4, 0, Math.PI * 2); ctx.fill();
}

export function drawObstacle(ctx, o, colorful, pal, time, fg, gy) {
  if (o.kind === 'ground') drawGround(ctx, o, colorful, pal, time, fg);
  else if (o.kind === 'flyer') drawFlyer(ctx, o, colorful, pal, time, fg);
  else if (o.kind === 'meteor') drawMeteor(ctx, o, time, gy);
}

// ---- pickups ------------------------------------------------------------------------------
export function drawCoin(ctx, c, time) {
  const sx = Math.abs(Math.cos(time * 4 + c.x * 0.05));
  ctx.fillStyle = '#b8860b';
  ctx.beginPath(); ctx.ellipse(c.x, c.y, 6 * sx + 1, 6, 0, 0, Math.PI * 2); ctx.fill();
  ctx.fillStyle = '#ffd54f';
  ctx.beginPath(); ctx.ellipse(c.x, c.y, 4.6 * sx + 0.5, 4.6, 0, 0, Math.PI * 2); ctx.fill();
  ctx.fillStyle = '#fff8e1';
  ctx.fillRect(c.x - 1.5 * sx, c.y - 3, 1.5, 3);
}

export const POWERUPS = {
  shield: { icon: '🛡️', color: '#4fc3f7', name: 'Shield' },
  magnet: { icon: '🧲', color: '#ef5350', name: 'Magnet' },
  double: { icon: '×2', color: '#ffd54f', name: 'Double Coins' },
  rocket: { icon: '🚀', color: '#ab47bc', name: 'Rocket' },
};

export function drawPowerup(ctx, p, time) {
  const def = POWERUPS[p.type];
  const y = p.y + Math.sin(time * 4 + p.x * 0.02) * 4;
  const g = ctx.createRadialGradient(p.x, y, 2, p.x, y, 16);
  g.addColorStop(0, 'rgba(255,255,255,.95)'); g.addColorStop(1, def.color + '66');
  ctx.fillStyle = g;
  ctx.beginPath(); ctx.arc(p.x, y, 14, 0, Math.PI * 2); ctx.fill();
  ctx.strokeStyle = def.color; ctx.lineWidth = 2;
  ctx.beginPath(); ctx.arc(p.x, y, 14, 0, Math.PI * 2); ctx.stroke();
  ctx.font = p.type === 'double' ? 'bold 12px system-ui, sans-serif' : '14px system-ui, sans-serif';
  ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
  ctx.fillStyle = '#5d4037';
  ctx.fillText(def.icon, p.x, y + 1);
}

export function drawBone(ctx, b, fg) {
  ctx.fillStyle = fg;
  const { x, y } = b;
  ctx.fillRect(x - 8, y - 2, 16, 4);
  ctx.beginPath();
  ctx.arc(x - 8, y - 2.5, 3, 0, Math.PI * 2); ctx.arc(x - 8, y + 2.5, 3, 0, Math.PI * 2);
  ctx.arc(x + 8, y - 2.5, 3, 0, Math.PI * 2); ctx.arc(x + 8, y + 2.5, 3, 0, Math.PI * 2);
  ctx.fill();
}

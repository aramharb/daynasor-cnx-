import { Game } from './game.js';
import { DINOS, RARITY, getDino, drawPreview } from './dinos.js';
import { NetworkMonitor } from './network.js';
import { store } from './store.js';
import { sfx } from './audio.js';

const EGG_COOLDOWN_MS = 5 * 60 * 1000; // one free egg per connection, at most every 5 min
const EGG_PRICE = 250;
const ALL_DUPES_COINS = 150;

const $ = (id) => document.getElementById(id);
const screens = ['menu', 'dinos', 'settings', 'hatch', 'pause', 'over'];
let screen = 'menu';
let online = false;
let colorful = false;

const game = new Game($('game'), { onGameOver });
game.setDino(store.get('selected'));
game.setBest(store.get('hiClassic'), store.get('hiColor'));
sfx.setEnabled(store.get('sound'));

// ------------------------------------------------------------------ helpers
function show(name) {
  screen = name;
  for (const s of screens) $(s).classList.toggle('hidden', s !== name);
  const playing = name === 'none';
  $('controls').classList.toggle('hidden', !playing);
  document.body.classList.toggle('playing', playing);
  if (name === 'menu') refreshMenu();
  if (name === 'dinos') buildCollection();
}

let toastTimer;
function toast(msg, ms = 2600) {
  const t = $('toast');
  t.textContent = msg;
  t.classList.remove('hidden');
  t.style.animation = 'none'; void t.offsetWidth; t.style.animation = '';
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => t.classList.add('hidden'), ms);
}

// ------------------------------------------------------------------ connection / modes
function applyMode(animate) {
  const next = online && !store.get('forceClassic');
  const changed = next !== colorful;
  colorful = next;
  game.setColorful(colorful, animate);
  document.body.classList.toggle('classic', !colorful);
  document.querySelector('meta[name=theme-color]').content = colorful ? '#1b1036' : '#f7f7f7';
  const pill = $('netPill');
  pill.classList.toggle('online', online);
  pill.classList.toggle('offline', !online);
  $('netText').textContent = online ? (colorful ? 'Online · Jurassic' : 'Online · Classic') : 'Offline · Classic';
  if (changed && animate) sfx.play(colorful ? 'online' : 'offline', colorful);
  if (screen === 'menu') refreshMenu();
  if (screen === 'dinos') buildCollection();
}

function grantEgg() {
  const now = Date.now();
  if (now - store.get('lastEggAt') < EGG_COOLDOWN_MS) return;
  store.update((s) => { s.eggs += 1; s.lastEggAt = now; });
  sfx.play('egg', true);
  toast('📶 Connected! You found a 🥚 mystery egg!');
  if (screen === 'menu') refreshMenu();
}

const net = new NetworkMonitor();
net.onChange((isOnline, prev) => {
  online = isOnline;
  applyMode(true);
  if (isOnline) grantEgg();
  else if (prev) toast('📴 No internet — Classic mode');
});
net.start();

// ------------------------------------------------------------------ menu
let menuAnim = 0;
function refreshMenu() {
  const def = getDino(store.get('selected'));
  $('menuDinoName').textContent = def.name;
  $('modeLine').textContent = colorful
    ? 'Online · Jurassic mode — colors, coins & powers!'
    : online ? 'Classic mode (forced in settings)' : 'Offline · Classic mode — connect for Jurassic mode';
  const eggs = store.get('eggs');
  $('hatchBtn').classList.toggle('hidden', eggs <= 0);
  $('eggCount').textContent = eggs > 1 ? `×${eggs}` : '';
  $('dinoCount').textContent = `${store.get('unlocked').length}/${DINOS.length}`;
  $('coinTotal').textContent = store.get('coins');
  $('hiTotal').textContent = colorful ? store.get('hiColor') : store.get('hiClassic');
  $('menuHint').textContent = colorful
    ? 'Tap to jump · Swipe down to duck · ⚡ button = dino ability'
    : 'Tap / Space to jump · Swipe down / ↓ to duck';
}
setInterval(() => {
  if (screen !== 'menu') return;
  menuAnim++;
  drawPreview($('menuDino'), getDino(store.get('selected')), { classic: !colorful, hue: menuAnim * 20, frame: menuAnim % 2 });
}, 120);

function play() {
  sfx.unlock();
  game.setDino(store.get('selected'));
  game.setBest(store.get('hiClassic'), store.get('hiColor'));
  game.start();
  const a = getDino(store.get('selected')).ability;
  $('abilityName').textContent = a.name;
  show('none');
}

$('playBtn').onclick = play;
$('dinosBtn').onclick = () => show('dinos');
$('settingsBtn').onclick = () => {
  $('optSound').checked = store.get('sound');
  $('optClassic').checked = store.get('forceClassic');
  show('settings');
};
$('hatchBtn').onclick = openHatch;
document.querySelectorAll('[data-back]').forEach((b) => (b.onclick = () => show('menu')));

// ------------------------------------------------------------------ settings
$('optSound').onchange = (e) => { store.set('sound', e.target.checked); sfx.setEnabled(e.target.checked); };
$('optClassic').onchange = (e) => { store.set('forceClassic', e.target.checked); applyMode(true); };
$('resetBtn').onclick = () => {
  if (!confirm('Reset all dinos, coins and scores?')) return;
  store.reset();
  game.setDino('rex');
  game.setBest(0, 0);
  toast('Progress reset');
  show('menu');
};

// ------------------------------------------------------------------ collection
let detailId = null;
function buildCollection() {
  const grid = $('dinoGrid');
  grid.innerHTML = '';
  const unlocked = store.get('unlocked');
  const selected = store.get('selected');
  for (const d of DINOS) {
    const has = unlocked.includes(d.id);
    const card = document.createElement('button');
    card.className = `card${has ? '' : ' locked'}${d.id === selected ? ' selected' : ''}`;
    const cv = document.createElement('canvas');
    cv.width = 80; cv.height = 60;
    drawPreview(cv, d, { locked: !has, classic: has && !colorful, hue: 300 });
    const name = document.createElement('span');
    name.textContent = has ? d.name : '???';
    const rar = document.createElement('span');
    rar.className = 'rar';
    rar.textContent = RARITY[d.rarity].label;
    if (colorful) rar.style.color = RARITY[d.rarity].color;
    card.append(cv, name, rar);
    card.onclick = () => {
      detailId = d.id;
      if (has) {
        store.set('selected', d.id);
        game.setDino(d.id);
        sfx.play('point', colorful);
      }
      buildCollection();
    };
    grid.append(card);
  }
  const d = getDino(detailId || selected);
  const has = unlocked.includes(d.id);
  const det = $('dinoDetail');
  det.innerHTML = '';
  const title = document.createElement('div');
  title.innerHTML = `<b></b> · <span class="rar"></span>`;
  title.querySelector('b').textContent = has ? d.name : '??? (locked)';
  const r = title.querySelector('.rar');
  r.textContent = RARITY[d.rarity].label;
  if (colorful) r.style.color = RARITY[d.rarity].color;
  const ab = document.createElement('div');
  ab.innerHTML = `<span class="ab"></span> <span></span>`;
  ab.firstElementChild.textContent = `⚡ ${d.ability.name}:`;
  ab.lastElementChild.textContent = has ? d.ability.desc : 'Hatch eggs to discover this dino and its power.';
  const blurb = document.createElement('div');
  blurb.className = 'sub';
  blurb.textContent = has ? d.blurb : '';
  det.append(title, ab, blurb);
  if (!colorful) {
    const n = document.createElement('div');
    n.className = 'sub';
    n.textContent = '📴 Abilities, coins and colors only work in Jurassic mode (online).';
    det.append(n);
  }
  $('coinTotal2').textContent = store.get('coins');
  const buy = $('buyEggBtn');
  const allDone = unlocked.length >= DINOS.length;
  buy.disabled = !colorful || store.get('coins') < EGG_PRICE;
  buy.textContent = !colorful ? '🔌 Go online to buy eggs' : allDone ? `🥚 Buy egg (bonus coins) · 🪙 ${EGG_PRICE}` : `🥚 Buy egg · 🪙 ${EGG_PRICE}`;
}
$('buyEggBtn').onclick = () => {
  if (!colorful || store.get('coins') < EGG_PRICE) return;
  store.update((s) => { s.coins -= EGG_PRICE; s.eggs += 1; });
  openHatch();
};

// ------------------------------------------------------------------ hatching
let hatchState = null;
function rollDino() {
  const unlocked = store.get('unlocked');
  const locked = DINOS.filter((d) => !unlocked.includes(d.id));
  if (!locked.length) return null;
  const total = locked.reduce((s, d) => s + RARITY[d.rarity].weight, 0);
  let r = Math.random() * total;
  for (const d of locked) { r -= RARITY[d.rarity].weight; if (r <= 0) return d; }
  return locked[locked.length - 1];
}
function openHatch() {
  if (store.get('eggs') <= 0) return;
  hatchState = { taps: 0, result: rollDino(), done: false };
  const egg = $('egg');
  egg.className = '';
  $('eggWrap').classList.remove('hidden');
  $('hatchDino').classList.add('hidden');
  $('hatchDone').classList.add('hidden');
  $('hatchTitle').textContent = 'A mystery egg!';
  $('hatchText').textContent = 'Tap the egg to crack it!';
  show('hatch');
}
$('egg').onclick = () => {
  if (!hatchState || hatchState.done) return;
  const egg = $('egg');
  hatchState.taps++;
  sfx.unlock();
  sfx.play('crack');
  egg.classList.remove('shake'); void egg.offsetWidth;
  egg.classList.add('shake');
  if (hatchState.taps === 1) egg.classList.add('crack1');
  if (hatchState.taps === 2) egg.classList.add('crack2');
  if (hatchState.taps >= 3) {
    hatchState.done = true;
    egg.classList.add('burst');
    setTimeout(revealHatch, 450);
  }
};
function revealHatch() {
  const d = hatchState.result;
  store.update((s) => {
    s.eggs = Math.max(0, s.eggs - 1);
    if (d) { s.unlocked.push(d.id); s.selected = d.id; } else s.coins += ALL_DUPES_COINS;
  });
  sfx.play('egg', true);
  $('eggWrap').classList.add('hidden');
  const cv = $('hatchDino');
  cv.classList.remove('hidden');
  const txt = $('hatchText');
  if (d) {
    game.setDino(d.id);
    cv.style.background = `radial-gradient(circle, ${RARITY[d.rarity].color}88, transparent 70%)`;
    drawPreview(cv, d, { hue: 0 });
    $('hatchTitle').textContent = `You hatched ${d.name}!`;
    txt.innerHTML = '<span class="rarity-tag"></span><br><b></b><br><span></span>';
    const tag = txt.querySelector('.rarity-tag');
    tag.textContent = RARITY[d.rarity].label;
    tag.style.background = RARITY[d.rarity].color;
    txt.querySelector('b').textContent = `⚡ ${d.ability.name}`;
    txt.querySelector('span:last-child').textContent = d.ability.desc;
  } else {
    cv.style.background = 'none';
    cv.getContext('2d').clearRect(0, 0, cv.width, cv.height);
    $('hatchTitle').textContent = 'You have every dino!';
    txt.textContent = `The egg was full of coins: +${ALL_DUPES_COINS} 🪙`;
  }
  const more = store.get('eggs') > 0;
  $('hatchDone').textContent = more ? 'Next egg 🥚' : 'Awesome!';
  $('hatchDone').classList.remove('hidden');
}
$('hatchDone').onclick = () => (store.get('eggs') > 0 ? openHatch() : show('menu'));

// ------------------------------------------------------------------ game over / pause
function onGameOver({ score, best, newBest, coins, colorful: wasColorful }) {
  store.update((s) => {
    s.runs += 1;
    if (wasColorful) { s.hiColor = Math.max(s.hiColor, score); s.coins += coins; } else s.hiClassic = Math.max(s.hiClassic, score);
  });
  setTimeout(() => {
    if (game.state !== 'over') return;
    $('overTitle').textContent = newBest ? 'NEW BEST!' : 'GAME OVER';
    $('overScore').textContent = score;
    $('overBest').textContent = best;
    $('overCoins').textContent = `+${coins}`;
    $('overCoinsBox').classList.toggle('hidden', !wasColorful);
    $('overNote').textContent = wasColorful
      ? `Total coins: ${store.get('coins')} 🪙 · eggs cost ${EGG_PRICE}`
      : online ? 'Tip: turn off "Always Classic" in settings for Jurassic mode.' : 'Connect to the internet to unlock Jurassic mode, coins & eggs!';
    show('over');
  }, 650);
}
$('retryBtn').onclick = play;
$('overMenuBtn').onclick = () => { game.state = 'idle'; game.reset(); show('menu'); };
$('pauseBtn').onpointerdown = (e) => { e.stopPropagation(); pauseGame(); };
$('resumeBtn').onclick = () => { show('none'); game.resume(); };
$('quitBtn').onclick = () => { game.state = 'idle'; game.reset(); show('menu'); };
function pauseGame() {
  if (game.state !== 'running') return;
  game.pause();
  show('pause');
}
document.addEventListener('visibilitychange', () => { if (document.hidden) pauseGame(); });

// ------------------------------------------------------------------ touch input
const canvas = $('game');
let touch = null;
canvas.addEventListener('pointerdown', (e) => {
  e.preventDefault();
  if (screen === 'menu') { play(); return; }
  if (screen !== 'none') return;
  touch = { id: e.pointerId, y: e.clientY, ducking: false };
  game.jumpPress();
});
canvas.addEventListener('pointermove', (e) => {
  if (!touch || e.pointerId !== touch.id) return;
  if (!touch.ducking && e.clientY - touch.y > 28) {
    touch.ducking = true;
    game.jumpRelease();
    game.duck(true);
  }
});
const endTouch = (e) => {
  if (!touch || e.pointerId !== touch.id) return;
  game.jumpRelease();
  if (touch.ducking) game.duck(false);
  touch = null;
};
canvas.addEventListener('pointerup', endTouch);
canvas.addEventListener('pointercancel', endTouch);

const duckBtn = $('duckBtn');
duckBtn.addEventListener('pointerdown', (e) => { e.preventDefault(); e.stopPropagation(); game.duck(true); });
['pointerup', 'pointercancel', 'pointerleave'].forEach((ev) => duckBtn.addEventListener(ev, () => game.duck(false)));
$('abilityBtn').addEventListener('pointerdown', (e) => { e.preventDefault(); e.stopPropagation(); game.useAbility(); });

// ------------------------------------------------------------------ keyboard
window.addEventListener('keydown', (e) => {
  if (e.repeat) return;
  const k = e.code;
  if (k === 'Space' || k === 'ArrowUp' || k === 'KeyW') {
    e.preventDefault();
    if (screen === 'menu') return play();
    if (screen === 'over' && game.overT > 0.5) return play();
    if (screen === 'none') game.jumpPress();
  } else if (k === 'ArrowDown' || k === 'KeyS') {
    e.preventDefault();
    if (screen === 'none') game.duck(true);
  } else if (k === 'KeyX' || k === 'KeyE' || k === 'ShiftLeft' || k === 'ShiftRight') {
    if (screen === 'none') game.useAbility();
  } else if (k === 'Escape' || k === 'KeyP') {
    if (screen === 'none') pauseGame();
    else if (screen === 'pause') { show('none'); game.resume(); }
  }
});
window.addEventListener('keyup', (e) => {
  if (e.code === 'Space' || e.code === 'ArrowUp' || e.code === 'KeyW') game.jumpRelease();
  if (e.code === 'ArrowDown' || e.code === 'KeyS') game.duck(false);
});

// ------------------------------------------------------------------ HUD sync + resize
let lastAb = '';
(function hudLoop() {
  if (screen === 'none' && colorful) {
    const a = game.abilityInfo();
    const key = `${a.ready}|${Math.round(a.pct * 40)}`;
    if (key !== lastAb) {
      lastAb = key;
      const btn = $('abilityBtn');
      btn.style.setProperty('--p', a.pct.toFixed(3));
      btn.classList.toggle('ready', a.ready);
    }
  }
  requestAnimationFrame(hudLoop);
})();
window.addEventListener('resize', () => game.resize());

applyMode(false);
show('menu');

// ------------------------------------------------------------------ PWA offline support (browser only)
const isNative = !!window.Capacitor?.isNativePlatform?.();
if ('serviceWorker' in navigator && !isNative && location.protocol !== 'file:') {
  navigator.serviceWorker.register('sw.js').catch(() => {});
}

// debug handle for automated tests: open with ?debug
if (new URLSearchParams(location.search).has('debug')) window.__dino = { game, store, net };

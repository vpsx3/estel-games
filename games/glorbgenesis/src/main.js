// Bootstrap, game loop, câmera, input e orquestração dos sistemas.

import { RNG, hashString } from './rng.js';
import { World, TILE, T } from './world.js';
import { E, ELEMENTS, elemColor } from './elements.js';
import { Creature } from './creature.js';
import { MUTATION_POOLS } from './evolution.js';
import { societyTick } from './society.js';
import { render, buildTerrainCanvas } from './render.js';
import { initUI, setGame, pushFeed, updateHUD, selectCreature } from './ui.js';

const STEP = 1 / 30;

class SpatialHash {
  constructor(cell = 48) { this.cell = cell; this.map = new Map(); }
  rebuild(creatures) {
    this.map.clear();
    for (const c of creatures) {
      const k = ((c.x / this.cell) | 0) + ',' + ((c.y / this.cell) | 0);
      let a = this.map.get(k);
      if (!a) { a = []; this.map.set(k, a); }
      a.push(c);
    }
  }
  query(x, y, r) {
    const out = [];
    const c0x = ((x - r) / this.cell) | 0, c1x = ((x + r) / this.cell) | 0;
    const c0y = ((y - r) / this.cell) | 0, c1y = ((y + r) / this.cell) | 0;
    const r2 = r * r;
    for (let cy = c0y; cy <= c1y; cy++) {
      for (let cx = c0x; cx <= c1x; cx++) {
        const a = this.map.get(cx + ',' + cy);
        if (!a) continue;
        for (const c of a) {
          const dx = c.x - x, dy = c.y - y;
          if (dx * dx + dy * dy <= r2) out.push(c);
        }
      }
    }
    return out;
  }
}

class Game {
  constructor(seed, seedText) {
    this.seedText = seedText;
    this.RNGClass = RNG;
    this.mutationPools = MUTATION_POOLS;
    const master = new RNG(seed);
    this.worldSeed = Math.floor(master.next() * 4294967296);
    this.creatureSeedRng = master.fork();
    this.envRng = master.fork();
    this.fxRng = master.fork();
    this.societyRng = master.fork();
    this.pourRng = master.fork();

    this.world = new World(this.worldSeed);
    this.terrainCanvas = buildTerrainCanvas(this.world);
    this.creatures = [];
    this.buildings = [];
    this.factions = [];
    this.particles = [];
    this.usedFactionNames = new Set();
    this.popCap = 220;
    this.time = 0;
    this.speed = 1;
    this.envAcc = 0;
    this.societyAcc = 0;
    this.cooldowns = {};
    this.tool = 'inspect';
    this.brush = { x: 0, y: 0, radius: 2, visible: false };
    this.selected = null;
    this.killCount = 0;
    this.combatKills = 0;
    this.combatCount = 0;

    // o Primeiro: surge num ponto aleatório fora d'água (determinístico pela seed)
    const spawnRng = master.fork();
    let sx = 0, sy = 0;
    for (let i = 0; i < 400; i++) {
      const tx = spawnRng.int(20, this.world.w - 20), ty = spawnRng.int(20, this.world.h - 20);
      if (this.world.terrain[this.world.idx(tx, ty)] !== T.WATER) {
        sx = tx * TILE + TILE / 2; sy = ty * TILE + TILE / 2;
        break;
      }
    }
    this.first = new Creature(this, sx, sy, { isFirst: true });
    this.creatures.push(this.first);
    this.hash = new SpatialHash();
    this.hash.rebuild(this.creatures);
  }

  feed(msg, color) { pushFeed(msg, color); }
  setSpeed(s) { this.speed = s; }

  addCreature(c) { this.creatures.push(c); }

  kill(c, cause, attacker) {
    if (!c.alive) return;
    // slime elástico: divide-se ao invés de morrer (uma vez)
    if (c.splitOnDeath && !c.hasSplit) {
      c.hasSplit = true; c.splitOnDeath = false;
      c.hp = c.stats.maxHp * 0.4;
      if (this.creatures.length < this.popCap) {
        const twin = new Creature(this, c.x + 8, c.y + 8, { parentA: c });
        twin.bodyPlan.size = Math.max(4, c.bodyPlan.size - 1.5);
        this.addCreature(twin);
        this.feed(`🫧 ${c.name} dividiu-se ao invés de morrer! Surgiu ${twin.name}`, '#5fe07a');
      }
      return;
    }
    c.alive = false;
    this.killCount++;
    if (attacker) this.combatKills++;
    const i = this.creatures.indexOf(c);
    if (i >= 0) this.creatures.splice(i, 1);
    if (c.faction) c.faction.removeMember(c);
    if (this.selected === c) selectCreature(null);
    // partículas do elemento dominante
    const col = c.dominantElem >= 0 ? elemColor(c.dominantElem) : `hsl(${c.bodyPlan.hue},50%,60%)`;
    for (let k = 0; k < 14; k++) {
      const a = this.fxRng.angle(), sp = this.fxRng.range(12, 45);
      this.spawnP(c.x, c.y, Math.cos(a) * sp, Math.sin(a) * sp, this.fxRng.range(0.4, 0.9), col, 2);
    }
    const mins = (c.age / 60).toFixed(c.age < 120 ? 1 : 0);
    if (c.isFirst) this.feed(`☠️ O Primeiro, ${c.name}, morreu ${cause} aos ${mins} min de idade`, '#ffd0d0');
    else if (attacker) this.feed(`☠️ ${c.name} foi morto por ${attacker.name}`, '#ff8a7a');
    else if (this.fxRng.chance(0.6)) this.feed(`☠️ ${c.name} morreu ${cause}`, '#c0a0a0');
  }

  addBuilding(b) {
    this.buildings.push(b);
    this.world.buildingAt.set(this.world.idx(b.tx, b.ty), b);
    if (b.faction) b.faction.buildings.push(b);
  }

  removeBuilding(b, cause) {
    const i = this.buildings.indexOf(b);
    if (i < 0) return;
    this.buildings.splice(i, 1);
    this.world.buildingAt.delete(this.world.idx(b.tx, b.ty));
    if (b.faction) {
      const j = b.faction.buildings.indexOf(b);
      if (j >= 0) b.faction.buildings.splice(j, 1);
    }
    const col = elemColor(b.element);
    for (let k = 0; k < 10; k++) {
      const a = this.fxRng.angle(), sp = this.fxRng.range(8, 30);
      this.spawnP(b.x, b.y, Math.cos(a) * sp, Math.sin(a) * sp - 10, this.fxRng.range(0.3, 0.8), col, 2);
    }
    if (b.burning > 0) {
      const idx = this.world.idx(b.tx, b.ty);
      if (this.envRng.chance(0.5)) this.world.setDep(idx, E.FIRE, this.envRng.range(2, 4));
      this.feed(`💥 ${b.label} ${cause}`, '#ff9a6a');
    }
  }

  // ---- partículas -------------------------------------------------------
  spawnP(x, y, vx, vy, life, color, size, type) {
    if (this.particles.length > 700) return;
    this.particles.push({ x, y, vx, vy, life, maxLife: life, color, size: size || 2, type: type || 'dot', x2: 0, y2: 0 });
  }
  flameAt(x, y, rng) {
    if (!rng.chance(0.25)) return;
    this.spawnP(x + rng.range(-4, 4), y, rng.range(-3, 3), rng.range(-22, -10), rng.range(0.3, 0.7), rng.chance(0.5) ? '#ff9a3a' : '#ffd75a', rng.range(1.2, 2.4));
  }
  smokeAt(x, y) {
    this.spawnP(x, y, this.fxRng.range(-3, 3), -12, 0.8, 'rgba(150,150,150,0.6)', 2.6);
  }
  sparkBurst(x, y, color, n) {
    for (let k = 0; k < n; k++) {
      const a = this.fxRng.angle(), sp = this.fxRng.range(20, 60);
      this.spawnP(x, y, Math.cos(a) * sp, Math.sin(a) * sp, 0.3, color, 1.4);
    }
  }
  hitSpark(x, y, elem) {
    this.sparkBurst(x, y, elem >= 0 ? elemColor(elem) : '#fff', 4);
  }
  absorbPuff(x, y, color) {
    for (let k = 0; k < 8; k++) {
      const a = (k / 8) * Math.PI * 2;
      this.spawnP(x + Math.cos(a) * 6, y + Math.sin(a) * 6, Math.cos(a) * -14, Math.sin(a) * -14, 0.5, color, 2);
    }
  }
  traitParticle(c, p) {
    const r = this.fxRng;
    const x = c.x + r.range(-4, 4), y = c.y + r.range(-4, 4);
    switch (p.type) {
      case 'flame': this.spawnP(x, y, r.range(-3, 3), -16, 0.5, p.color, 1.8); break;
      case 'smoke': this.spawnP(x, y - 4, r.range(-2, 2), -10, 0.9, 'rgba(140,140,140,0.5)', 2.2); break;
      case 'spark': this.spawnP(x, y, r.range(-25, 25), r.range(-25, 25), 0.25, p.color, 1.3); break;
      case 'drip': this.spawnP(x, y + 3, 0, 18, 0.5, p.color, 1.6); break;
      case 'puff': this.spawnP(x, y, r.range(-6, 6), r.range(-6, 0), 0.6, p.color, 2.4); break;
      case 'snow': this.spawnP(x, y - 6, r.range(-4, 4), 8, 0.9, p.color, 1.4); break;
    }
  }
  lightningAt(x, y, r, dmg) {
    // visual: raio caindo do céu em segmentos
    let px = x + this.fxRng.range(-14, 14), py = y - 80;
    for (let k = 0; k < 4; k++) {
      const nx = k === 3 ? x : px + this.fxRng.range(-12, 12);
      const ny = py + 20;
      const p = { x: px, y: py, x2: nx, y2: ny, vx: 0, vy: 0, life: 0.35, maxLife: 0.35, color: '#ffe94a', size: 1, type: 'bolt' };
      if (this.particles.length < 750) this.particles.push(p);
      px = nx; py = ny;
    }
    this.spawnP(x, y, 0, 0, 0.25, 'rgba(255,240,150,0.9)', r * 0.7);
    for (const c of this.hash.query(x, y, r)) {
      if (!c.immunities.has(E.LIGHTNING)) c.hurt(dmg, null, 'eletrocutado por um raio');
    }
  }
  notifyGold(x, y) {
    const tx = Math.floor(x / TILE), ty = Math.floor(y / TILE);
    for (const c of this.hash.query(x, y, 140)) {
      if (c.temperament.greed > 0.45 && c.state !== 'fight' && c.state !== 'flee') {
        c.seekTile = { tx, ty, elem: E.GOLD, mode: c.temperament.curiosity > c.temperament.industriousness ? 'absorb' : 'collect' };
        c.state = 'seek';
      }
    }
  }

  // ---- tick de simulação -------------------------------------------------
  tick(dt) {
    this.time += dt;
    this.hash.rebuild(this.creatures);

    const cs = this.creatures.slice();
    for (const c of cs) if (c.alive) c.update(dt);

    const bs = this.buildings.slice();
    for (const b of bs) b.update(this, dt);

    this.envAcc += dt;
    if (this.envAcc >= 0.25) { this.world.envTick(this, this.envAcc); this.envAcc = 0; }

    this.societyAcc += dt;
    if (this.societyAcc >= 8) { societyTick(this); this.societyAcc = 0; }

    for (const [k, v] of Object.entries(this.cooldowns)) {
      if (v > 0) this.cooldowns[k] = Math.max(0, v - dt);
    }

    // partículas
    for (let i = this.particles.length - 1; i >= 0; i--) {
      const p = this.particles[i];
      p.life -= dt;
      if (p.life <= 0) { this.particles.splice(i, 1); continue; }
      p.x += p.vx * dt; p.y += p.vy * dt;
    }
  }

  pour(elem, wx, wy) {
    const def = ELEMENTS[elem];
    if (def.rare) {
      if ((this.cooldowns[elem] || 0) > 0) return;
      this.cooldowns[elem] = def.cooldown;
    }
    const tx = Math.floor(wx / TILE), ty = Math.floor(wy / TILE);
    this.world.pour(elem, tx, ty, elem === E.DIAMOND ? 0 : this.brush.radius, this.pourRng, this);
  }
}

// ---------------------------------------------------------------------------
// Bootstrap + loop + input
// ---------------------------------------------------------------------------
const canvas = document.getElementById('game');
const ctx = canvas.getContext('2d');
let game = null;
const cam = { x: 0, y: 0, zoom: 1.6 };

function newSeed() {
  // fora da simulação: só para escolher a seed inicial do mundo
  return (Date.now() ^ (performance.now() * 1000)) >>> 0;
}

function startWorld(seedStr) {
  let seed, text;
  if (seedStr) {
    seed = /^\d+$/.test(seedStr) ? (parseInt(seedStr, 10) >>> 0) : hashString(seedStr);
    text = seedStr;
  } else {
    seed = newSeed();
    text = String(seed);
  }
  game = new Game(seed, text);
  window.__game = game; // handle de debug/observação (não usado pela simulação)
  setGame(game);
  cam.zoom = 1.6;
  cam.x = game.first.x - canvas.width / 2 / cam.zoom;
  cam.y = game.first.y - canvas.height / 2 / cam.zoom;
  clampCam();
  game.feed(`🌱 O Primeiro, ${game.first.name}, surgiu no mundo (seed ${text})`, '#a0e8a0');
}

function resize() {
  canvas.width = window.innerWidth;
  canvas.height = window.innerHeight;
}
window.addEventListener('resize', resize);
resize();

function clampCam() {
  const W = game.world.w * TILE, H = game.world.h * TILE;
  const vw = canvas.width / cam.zoom, vh = canvas.height / cam.zoom;
  cam.x = Math.max(-vw * 0.3, Math.min(W - vw * 0.7, cam.x));
  cam.y = Math.max(-vh * 0.3, Math.min(H - vh * 0.7, cam.y));
}

function toWorld(mx, my) {
  return { x: cam.x + mx / cam.zoom, y: cam.y + my / cam.zoom };
}

let pouring = false, panning = false, lastMx = 0, lastMy = 0, pourCd = 0;

function pickCreature(w) {
  let best = null, bd = 18 / cam.zoom + 8;
  for (const c of game.creatures) {
    const d = Math.hypot(c.x - w.x, c.y - w.y);
    if (d < bd) { bd = d; best = c; }
  }
  return best;
}

canvas.addEventListener('mousedown', e => {
  const w = toWorld(e.offsetX, e.offsetY);
  if (e.button === 1 || e.button === 2) { panning = true; }
  else if (e.button === 0) {
    if (game.tool === 'inspect') {
      selectCreature(pickCreature(w));
    } else {
      pouring = true;
      game.pour(game.tool, w.x, w.y);
      pourCd = 0.08;
    }
  }
  lastMx = e.offsetX; lastMy = e.offsetY;
});
window.addEventListener('mouseup', () => { pouring = false; panning = false; });
canvas.addEventListener('mouseleave', () => { game.brush.visible = false; });
canvas.addEventListener('mousemove', e => {
  const w = toWorld(e.offsetX, e.offsetY);
  game.brush.x = w.x; game.brush.y = w.y; game.brush.visible = true;
  if (panning) {
    cam.x -= (e.offsetX - lastMx) / cam.zoom;
    cam.y -= (e.offsetY - lastMy) / cam.zoom;
    clampCam();
  }
  lastMx = e.offsetX; lastMy = e.offsetY;
});
canvas.addEventListener('wheel', e => {
  e.preventDefault();
  const before = toWorld(e.offsetX, e.offsetY);
  cam.zoom = Math.max(0.5, Math.min(5, cam.zoom * (e.deltaY < 0 ? 1.12 : 1 / 1.12)));
  const after = toWorld(e.offsetX, e.offsetY);
  cam.x += before.x - after.x;
  cam.y += before.y - after.y;
  clampCam();
}, { passive: false });
canvas.addEventListener('contextmenu', e => e.preventDefault());

// ---- touch (celular) -------------------------------------------------------
// 1 dedo: na lupa arrasta a câmera (toque curto seleciona); com um elemento,
// despeja. 2 dedos: sempre movem a câmera, com pinça para zoom.
let touchMode = null; // 'pan' | 'tool' | 'pinch'
let tapX = 0, tapY = 0, tapTime = 0, tapMoved = false;
let pinchDist = 0;

function touchPos(t) {
  const r = canvas.getBoundingClientRect();
  return { x: t.clientX - r.left, y: t.clientY - r.top };
}

canvas.addEventListener('touchstart', e => {
  e.preventDefault(); // bloqueia gestos do browser e eventos de mouse emulados
  if (e.touches.length === 1) {
    const p = touchPos(e.touches[0]);
    lastMx = p.x; lastMy = p.y;
    tapX = p.x; tapY = p.y; tapTime = performance.now(); tapMoved = false;
    const w = toWorld(p.x, p.y);
    game.brush.x = w.x; game.brush.y = w.y;
    if (game.tool === 'inspect') {
      touchMode = 'pan';
    } else {
      touchMode = 'tool';
      game.brush.visible = true;
      pouring = true;
      game.pour(game.tool, w.x, w.y);
      pourCd = 0.08;
    }
  } else if (e.touches.length === 2) {
    pouring = false; game.brush.visible = false;
    touchMode = 'pinch';
    const a = touchPos(e.touches[0]), b = touchPos(e.touches[1]);
    lastMx = (a.x + b.x) / 2; lastMy = (a.y + b.y) / 2;
    pinchDist = Math.hypot(a.x - b.x, a.y - b.y);
  }
}, { passive: false });

canvas.addEventListener('touchmove', e => {
  e.preventDefault();
  if (touchMode === 'pinch' && e.touches.length >= 2) {
    const a = touchPos(e.touches[0]), b = touchPos(e.touches[1]);
    const mx = (a.x + b.x) / 2, my = (a.y + b.y) / 2;
    const d = Math.hypot(a.x - b.x, a.y - b.y);
    if (pinchDist > 0) {
      const before = toWorld(mx, my);
      cam.zoom = Math.max(0.5, Math.min(5, cam.zoom * (d / pinchDist)));
      const after = toWorld(mx, my);
      cam.x += before.x - after.x;
      cam.y += before.y - after.y;
    }
    cam.x -= (mx - lastMx) / cam.zoom;
    cam.y -= (my - lastMy) / cam.zoom;
    clampCam();
    lastMx = mx; lastMy = my; pinchDist = d;
  } else if (touchMode && e.touches.length === 1) {
    const p = touchPos(e.touches[0]);
    if (Math.hypot(p.x - tapX, p.y - tapY) > 10) tapMoved = true;
    if (touchMode === 'pan') {
      cam.x -= (p.x - lastMx) / cam.zoom;
      cam.y -= (p.y - lastMy) / cam.zoom;
      clampCam();
    } else if (touchMode === 'tool') {
      const w = toWorld(p.x, p.y);
      game.brush.x = w.x; game.brush.y = w.y; game.brush.visible = true;
    }
    lastMx = p.x; lastMy = p.y;
  }
}, { passive: false });

canvas.addEventListener('touchend', e => {
  e.preventDefault();
  if (e.touches.length === 0) {
    // toque curto e parado com a lupa: seleciona a criatura tocada
    if (touchMode === 'pan' && !tapMoved && performance.now() - tapTime < 350) {
      selectCreature(pickCreature(toWorld(tapX, tapY)));
    }
    pouring = false; game.brush.visible = false; touchMode = null;
  } else if (e.touches.length === 1) {
    // saiu da pinça com um dedo ainda na tela: continua movendo a câmera
    const p = touchPos(e.touches[0]);
    lastMx = p.x; lastMy = p.y;
    touchMode = 'pan'; pouring = false; tapMoved = true;
  }
}, { passive: false });

canvas.addEventListener('touchcancel', () => {
  pouring = false; game.brush.visible = false; touchMode = null;
});

initUIOnce();
function initUIOnce() {
  // Game precisa existir antes do initUI (referências de brush/tool)
  startWorldBootstrap();
}
function startWorldBootstrap() {
  let seed = newSeed();
  game = new Game(seed, String(seed));
  window.__game = game;
  initUI(game, { onNewWorld: s => startWorld(s) });
  setGame(game);
  cam.x = game.first.x - canvas.width / 2 / cam.zoom;
  cam.y = game.first.y - canvas.height / 2 / cam.zoom;
  clampCam();
  game.feed(`🌱 O Primeiro, ${game.first.name}, surgiu no mundo (seed ${game.seedText})`, '#a0e8a0');
}

let last = performance.now(), simAcc = 0;
function frame(now) {
  const dtReal = Math.min(0.1, (now - last) / 1000);
  last = now;

  // despejo contínuo enquanto arrasta
  if (pouring && game.tool !== 'inspect') {
    pourCd -= dtReal;
    if (pourCd <= 0) { game.pour(game.tool, game.brush.x, game.brush.y); pourCd = 0.09; }
  }

  simAcc += dtReal * game.speed;
  let steps = 0;
  while (simAcc >= STEP && steps < 8) { game.tick(STEP); simAcc -= STEP; steps++; }
  if (steps === 8) simAcc = 0; // não deixa acumular atraso

  render(game, ctx, cam, now / 1000);
  updateHUD();
  requestAnimationFrame(frame);
}
requestAnimationFrame(frame);

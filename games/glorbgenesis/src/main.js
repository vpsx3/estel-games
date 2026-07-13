// Bootstrap, game loop, câmera, input e orquestração dos sistemas.

import { RNG, hashString } from './rng.js';
import { World, TILE, T, fuseLife } from './world.js';
import { E, ELEMENTS, ENDGAME, elemName, elemColor } from './elements.js';
import { Creature } from './creature.js';
import { MUTATION_POOLS } from './evolution.js';
import { societyTick, recordWarScore } from './society.js';
import { render, buildTerrainCanvas, repaintTerritory } from './render.js';
import { initUI, setGame, pushFeed, updateHUD, selectCreature, selectBuilding, selectTool, showEraBanner, setFollowActive } from './ui.js';
const STEP = 1 / 30;

// Perfil de desempenho: em aparelhos de toque / poucos núcleos, reduzimos o
// teto de partículas (puramente visual — não altera a simulação nem a seed).
const IS_TOUCH = typeof matchMedia === 'function' && matchMedia('(pointer: coarse)').matches;
const LOW_POWER = IS_TOUCH || ((navigator.hardwareConcurrency || 8) <= 4);
const PERF = {
  particleCap: LOW_POWER ? 320 : 700,
  particleHardCap: LOW_POWER ? 360 : 750,
};

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
    this.territoryCanvas = document.createElement('canvas');
    this.territoryCanvas.width = this.world.w;
    this.territoryCanvas.height = this.world.h;
    this.creatures = [];
    this.buildings = [];
    this.factions = [];
    this.particles = [];
    this.usedFactionNames = new Set();
    this.era = 0;                    // 0 Primordial, 1 Tribal, 2 Guerras, 3 Reinos
    this.wars = [];                  // [{aId, bId, score:{}, t0}]
    this.cataclysmTimer = 0;         // agendado quando era ≥ CATA_MIN_ERA
    this.cataclysmPending = null;    // {type, tx, ty, at} durante o telegraph
    this.purgeLevel = 0;             // 0 nenhuma, 1 devora depósitos, 2 também construções
    this.purgeTimer = 0;             // reavalia a saturação periodicamente
    this.territoryDirty = true;
    this.territoryTimer = 0;
    this.shake = 0;                  // intensidade de tremor de tela (decai por dt)
    this.popCap = 220;
    this.time = 0;
    this.speed = 1;
    this.envAcc = 0;
    this.societyAcc = 0;
    this.cooldowns = {};
    this.tool = 'inspect';
    this.brush = { x: 0, y: 0, radius: 2, visible: false };
    this.selected = null;
    this.lensFactions = false;
    this.killCount = 0;
    this.combatKills = 0;
    this.combatCount = 0;

    // fusões descobertas: meta-progressão global, persiste entre mundos/seeds
    this.discovered = new Set();
    try { for (const id of JSON.parse(localStorage.getItem('glorb_fusions') || '[]')) this.discovered.add(id); } catch (e) {}
    this.onDiscover = null;

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
  addShake(v) { this.shake = Math.min(10, this.shake + v); }
  announceEra(era) { showEraBanner(era); }

  addCreature(c) { this.creatures.push(c); }

  kill(c, cause, attacker) {
    if (!c.alive) return;
    // renascido das cinzas: cancela a morte uma única vez
    if (c.ashRebirth && !c.ashUsed && c.hp <= 0) {
      c.ashUsed = true;
      c.hp = c.stats.maxHp * 0.25;
      this.smokeAt(c.x, c.y);
      this.feed(`♻ ${c.name} renasceu das cinzas`, '#7d7468');
      return;
    }
    // Dom das Cinzas: revive 1 única vez e o dom é consumido
    // (independente e cumulativo com a mutação ashRebirth)
    if (c.hp <= 0 && c.gifts.has(E.ASH)) {
      c.gifts.delete(E.ASH);
      c.hp = c.stats.maxHp * 0.25;
      this.smokeAt(c.x, c.y);
      this.feed(`♻ ${c.name} renasceu das cinzas`, '#7d7468');
      return;
    }
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
    // guerra: abate de inimigo pontua no placar da facção do atacante
    if (attacker && attacker.faction && c.faction && attacker.faction.isAtWar(c.faction)) {
      recordWarScore(this, attacker.faction, c.faction, ENDGAME.WAR_SCORE_KILL);
    }
    // a queda de um colosso devolve ao mundo o que ele devorou
    if (c.giantTier >= 2) {
      const drops = Math.min(ENDGAME.TITAN_DROP_MAX, Math.floor(c.absorbLifetime / 4));
      const top = Object.entries(c.absorbed).filter(([, v]) => v > 0)
        .sort((a, b) => b[1] - a[1]).slice(0, 3);
      if (drops > 0 && top.length) {
        const total = top.reduce((s, [, v]) => s + v, 0);
        const ctx0 = Math.floor(c.x / TILE), cty0 = Math.floor(c.y / TILE);
        for (let k = 0; k < drops; k++) {
          const tx = ctx0 + this.envRng.int(-ENDGAME.TITAN_DROP_RADIUS, ENDGAME.TITAN_DROP_RADIUS);
          const ty = cty0 + this.envRng.int(-ENDGAME.TITAN_DROP_RADIUS, ENDGAME.TITAN_DROP_RADIUS);
          if (!this.world.inBounds(tx, ty)) continue;
          const ti = this.world.idx(tx, ty);
          if (this.world.buildingAt.has(ti)) continue;
          // proporção ponderada pelas contagens dos 3 elementos mais absorvidos
          let roll = this.envRng.next() * total, elem = +top[0][0];
          for (const [ek, ev] of top) { roll -= ev; if (roll <= 0) { elem = +ek; break; } }
          this.world.setDep(ti, elem, fuseLife(elem, this.envRng));
        }
      }
      this.addShake(c.giantTier * 2);
      this.sparkBurst(c.x, c.y, c.dominantElem >= 0 ? elemColor(c.dominantElem) : '#ffd75a', 14);
      this.feed(`💥 ${c.name}, o ${ENDGAME.GIANT_TIER_NAMES[c.giantTier - 1]}, tombou ${cause}! Seus elementos se espalham pelo mundo.`, '#ffb36a');
    }
    // explosivo póstumo: estilhaços atingem quem estiver perto
    if (c.deathBurst) {
      for (const o of this.hash.query(c.x, c.y, 40)) {
        if (o !== c && o.alive) o.hurt(12, null, 'pela explosão póstuma');
      }
      this.sparkBurst(c.x, c.y, '#e6d44e', 8);
    }
    // Dom Sulfúrico: explosão ao morrer (dobra o raio se também é explosivo póstumo)
    if (c.gifts.has(E.SULFUR)) {
      const r = c.deathBurst ? 80 : 40;
      for (const o of this.hash.query(c.x, c.y, r)) {
        if (o !== c && o.alive) o.hurt(15, null, 'pela explosão sulfúrica');
      }
      this.sparkBurst(c.x, c.y, '#e6d44e', 10);
    }
    // dons de caça do matador: Midas (chance de ouro) e Eletro (presas viram ouro)
    if (attacker && attacker.alive && attacker.gifts.size) {
      const vtx = Math.floor(c.x / TILE), vty = Math.floor(c.y / TILE);
      if (this.world.inBounds(vtx, vty)) {
        const vi = this.world.idx(vtx, vty);
        if (!this.world.buildingAt.has(vi)) {
          if (attacker.gifts.has(E.ELECTRUM)) this.world.setDep(vi, E.GOLD, 0);
          else if (attacker.gifts.has(E.GOLD) && attacker.rng.chance(0.25)) this.world.setDep(vi, E.GOLD, 0);
        }
      }
    }
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
    this.territoryDirty = true;
  }

  removeBuilding(b, cause) {
    const i = this.buildings.indexOf(b);
    if (i < 0) return;
    // guerra: construção derrubada por inimigo pontua no placar
    if (b.lastAttacker && b.lastAttacker.faction && b.faction &&
        b.lastAttacker.faction.isAtWar(b.faction)) {
      recordWarScore(this, b.lastAttacker.faction, b.faction, ENDGAME.WAR_SCORE_BUILDING);
    }
    this.buildings.splice(i, 1);
    this.world.buildingAt.delete(this.world.idx(b.tx, b.ty));
    if (b.faction) {
      const j = b.faction.buildings.indexOf(b);
      if (j >= 0) b.faction.buildings.splice(j, 1);
    }
    this.territoryDirty = true;
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
    if (this.particles.length > PERF.particleCap) return;
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
      if (this.particles.length < PERF.particleHardCap) this.particles.push(p);
      px = nx; py = ny;
    }
    this.spawnP(x, y, 0, 0, 0.25, 'rgba(255,240,150,0.9)', r * 0.7);
    for (const c of this.hash.query(x, y, r)) {
      // Dom Prismático: absorve o raio e cura
      if (c.gifts.has(E.PRISM)) { c.hp = Math.min(c.stats.maxHp, c.hp + 5); continue; }
      // Dom do Reflexo: anula o raio e o re-dispara num tile vizinho
      if (c.gifts.has(E.GLASS) && (c.giftTimers.glass || 0) <= 0) {
        c.giftTimers.glass = 20;
        const rtx = Math.floor(c.x / TILE) + this.envRng.int(-1, 1);
        const rty = Math.floor(c.y / TILE) + this.envRng.int(-1, 1);
        this.world.lightningStrike(rtx, rty, this.envRng, this, 1);
        continue;
      }
      if (!c.immunities.has(E.LIGHTNING)) {
        // efeito único: METAL — amplificador: raio dói mais sobre tile de metal
        const ctx2 = Math.floor(c.x / TILE), cty2 = Math.floor(c.y / TILE);
        const onMetal = this.world.inBounds(ctx2, cty2) && this.world.dep[this.world.idx(ctx2, cty2)] === E.METAL;
        c.hurt(dmg * (onMetal ? 1.5 : 1), null, 'eletrocutado por um raio');
      }
    }
  }
  notifyFusion(elem, px, py) {
    if (this.discovered.has(elem)) return;
    this.discovered.add(elem);
    try { localStorage.setItem('glorb_fusions', JSON.stringify([...this.discovered])); } catch (e) {}
    this.feed(`🧪 Elemento descoberto: ${elemName(elem)}!`, elemColor(elem));
    this.onDiscover && this.onDiscover(elem);
  }
  // efeito único: OURO — cobiça: despertar ouro atrai os gananciosos da região
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

    // cataclismos: o mundo se agita sozinho a partir da Era Tribal
    if (this.era >= ENDGAME.CATA_MIN_ERA) updateCataclysm(this, dt);

    // devoração do excesso: quando o mapa transborda de depósitos, os glorbs
    // entram em modo de limpeza (avaliado ~1×/s, com histerese)
    this.purgeTimer -= dt;
    if (this.purgeTimer <= 0) {
      this.purgeTimer = 1;
      updatePurge(this);
    }

    // tremor de tela decai com o tempo de simulação
    if (this.shake > 0) this.shake = Math.max(0, this.shake - dt * 8);

    // território: repinta quando sujo, no máximo a cada TERRITORY_REFRESH s
    if (this.territoryTimer > 0) this.territoryTimer -= dt;
    if (this.territoryDirty && this.territoryTimer <= 0) {
      repaintTerritory(this);
      this.territoryDirty = false;
      this.territoryTimer = ENDGAME.TERRITORY_REFRESH;
    }

    for (const k in this.cooldowns) {
      if (this.cooldowns[k] > 0) this.cooldowns[k] = Math.max(0, this.cooldowns[k] - dt);
    }

    // partículas (remoção por swap-pop: a ordem de desenho não importa)
    const ps = this.particles;
    for (let i = ps.length - 1; i >= 0; i--) {
      const p = ps[i];
      p.life -= dt;
      if (p.life <= 0) {
        ps[i] = ps[ps.length - 1];
        ps.pop();
        continue;
      }
      p.x += p.vx * dt; p.y += p.vy * dt;
    }
  }

  pour(elem, wx, wy) {
    const tx = Math.floor(wx / TILE), ty = Math.floor(wy / TILE);
    if (elem === 'erase') {
      this.world.erase(tx, ty, this.brush.radius);
      return;
    }
    const def = ELEMENTS[elem];
    if (def.cooldown > 0) {
      if ((this.cooldowns[elem] || 0) > 0) return;
      this.cooldowns[elem] = def.cooldown;
    }
    this.world.pour(elem, tx, ty, elem === E.DIAMOND ? 0 : this.brush.radius, this.pourRng, this);
  }
}

// ---------------------------------------------------------------------------
// Devoração do excesso: quando a maioria dos tiles de terra está tomada por
// depósitos, os glorbs passam a consumir/destruir o excesso (e construções, no
// auge) para liberar espaço. Ligado/desligado por histerese na saturação.
// ---------------------------------------------------------------------------
function updatePurge(game) {
  const sat = game.world.saturation();
  const prev = game.purgeLevel;
  if (game.purgeLevel === 0) {
    if (sat >= ENDGAME.PURGE_START) game.purgeLevel = sat >= ENDGAME.PURGE_EXTREME ? 2 : 1;
  } else if (sat < ENDGAME.PURGE_STOP) {
    game.purgeLevel = 0;
  } else {
    game.purgeLevel = sat >= ENDGAME.PURGE_EXTREME ? 2 : 1;
  }
  if (prev === 0 && game.purgeLevel > 0) {
    game.feed('🌀 O mundo transborda de elementos — os glorbs começam a devorar o excesso!', '#b6f0ff');
  } else if (prev > 0 && game.purgeLevel === 0) {
    game.feed('✨ O excesso foi consumido; o mundo respira de novo.', '#a0e8a0');
  } else if (prev === 1 && game.purgeLevel === 2) {
    game.feed('⛏️ O excesso é tanto que os glorbs passam a derrubar até construções!', '#ffcf8a');
  }
}

// ---------------------------------------------------------------------------
// Cataclismos autônomos (Fase A): a partir da Era Tribal o mundo se agita
// sozinho e devolve química ao mapa. Todo sorteio usa envRng (determinismo).
// ---------------------------------------------------------------------------
const CATACLYSMS = [
  { w: 2, type: 'meteoro',    warn: d => `⚠️ Uma luz cresce no céu ${d}...` },
  { w: 3, type: 'erupcao',    warn: d => `⚠️ O chão treme ${d}...` },
  { w: 3, type: 'nevasca',    warn: d => `⚠️ Um vento gélido sopra ${d}...` },
  { w: 3, type: 'tempestade', warn: d => `⚠️ Nuvens negras se acumulam ${d}...` },
  { w: 1, type: 'praga',      warn: d => `⚠️ Um odor pútrido se espalha ${d}...` },
];

// Direção aproximada do alvo em relação ao centro do mapa, já com preposição.
function compassDir(world, tx, ty) {
  const dx = tx - world.w / 2, dy = ty - world.h / 2;
  let d;
  if (Math.abs(dy) > Math.abs(dx) * 2) d = dy < 0 ? 'norte' : 'sul';
  else if (Math.abs(dx) > Math.abs(dy) * 2) d = dx < 0 ? 'oeste' : 'leste';
  else d = (dy < 0 ? 'nor' : 'su') + (dx < 0 ? (dy < 0 ? 'oeste' : 'doeste') : 'deste');
  return (d === 'norte' || d === 'sul') ? `ao ${d}` : `a ${d}`;
}

function updateCataclysm(game, dt) {
  // telegraph em andamento: aguarda a hora do impacto
  if (game.cataclysmPending) {
    if (game.time >= game.cataclysmPending.at) {
      executeCataclysm(game, game.cataclysmPending);
      game.cataclysmPending = null;
    }
    return;
  }
  const rng = game.envRng;
  if (game.cataclysmTimer <= 0) {
    // agenda o próximo: o intervalo encurta a cada era
    const scale = Math.pow(ENDGAME.CATA_ERA_SCALE, Math.max(0, game.era - 1));
    game.cataclysmTimer = rng.range(ENDGAME.CATA_INTERVAL[0], ENDGAME.CATA_INTERVAL[1]) * scale;
    return;
  }
  game.cataclysmTimer -= dt;
  if (game.cataclysmTimer > 0) return;

  // sorteia tipo e alvo: tile de terra, com viés de 50% para perto de criaturas
  const world = game.world;
  const kind = rng.weighted(CATACLYSMS);
  let tx = -1, ty = -1;
  for (let i = 0; i < 40; i++) {
    let cx, cy;
    if (game.creatures.length && rng.chance(0.5)) {
      const c = rng.pick(game.creatures);
      const near = game.hash.query(c.x, c.y, 80);
      const p = near.length ? rng.pick(near) : c;
      cx = Math.floor(p.x / TILE) + rng.int(-4, 4);
      cy = Math.floor(p.y / TILE) + rng.int(-4, 4);
    } else {
      cx = rng.int(4, world.w - 5);
      cy = rng.int(4, world.h - 5);
    }
    if (world.inBounds(cx, cy) && world.terrain[world.idx(cx, cy)] !== T.WATER) { tx = cx; ty = cy; break; }
  }
  if (tx < 0) { game.cataclysmTimer = 30; return; } // sem alvo em terra: tenta em breve
  game.feed(kind.warn(compassDir(world, tx, ty)), '#ffb36a');
  game.cataclysmPending = { type: kind.type, tx, ty, at: game.time + ENDGAME.CATA_WARNING };
}

function executeCataclysm(game, ev) {
  const world = game.world, rng = game.envRng;
  const { tx, ty } = ev;
  // mancha orgânica de `elem` — nunca sobrescreve tiles com construção
  const splat = (elem, radius, density) => {
    for (let dy = -radius; dy <= radius; dy++) {
      for (let dx = -radius; dx <= radius; dx++) {
        if (dx * dx + dy * dy > radius * radius + 0.5) continue;
        const x = tx + dx, y = ty + dy;
        if (!world.inBounds(x, y)) continue;
        const i = world.idx(x, y);
        if (world.buildingAt.has(i) || !rng.chance(density)) continue;
        world.setDep(i, elem, fuseLife(elem, rng));
      }
    }
  };
  switch (ev.type) {
    case 'meteoro': {
      // núcleo estelar na cratera (o colapso explosivo já existe em envTick)
      const i = world.idx(tx, ty);
      if (!world.buildingAt.has(i)) world.setDep(i, E.STARCORE, fuseLife(E.STARCORE, rng));
      // anel de fogo ao redor do impacto (raio 2)
      for (let dy = -2; dy <= 2; dy++) {
        for (let dx = -2; dx <= 2; dx++) {
          const d2 = dx * dx + dy * dy;
          if (d2 < 2 || d2 > 6) continue;
          const x = tx + dx, y = ty + dy;
          if (!world.inBounds(x, y)) continue;
          const ni = world.idx(x, y);
          if (world.buildingAt.has(ni) || !rng.chance(0.6)) continue;
          world.setDep(ni, E.FIRE, rng.range(3, 6));
        }
      }
      game.addShake(6);
      game.feed('☄️ Um meteoro caiu! Um núcleo estelar arde na cratera.', '#ff9a3a');
      break;
    }
    case 'erupcao':
      splat(E.LAVA, rng.int(1, 2), 0.5);
      game.addShake(4);
      game.feed('🌋 Uma erupção rasga o chão!', '#ff4a1a');
      break;
    case 'nevasca':
      splat(E.BLIZZARD, rng.int(2, 3), 0.5);
      game.feed('🌨️ Uma nevasca desaba sobre a região!', '#d8ecff');
      break;
    case 'tempestade':
      splat(E.STORM, 2, 0.5);
      game.feed('⛈️ Uma tempestade se forma!', '#8f82e0');
      break;
    case 'praga':
      splat(E.PLAGUE, 2, 0.4);
      game.feed('☣️ A praga brota da terra!', '#8fae52');
      break;
  }
}

// ---------------------------------------------------------------------------
// Bootstrap + loop + input
// ---------------------------------------------------------------------------
const canvas = document.getElementById('game');
const ctx = canvas.getContext('2d');
let game = null;
const cam = { x: 0, y: 0, zoom: 1.6, follow: false };
let panVel = { x: 0, y: 0 }, lastPanT = 0; // inércia da câmera no toque

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
  setCamFollow(false);
  panVel.x = panVel.y = 0;
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

// ---- câmera: seguir / recentrar (essencial no celular p/ não perder o glorb) --
function followTarget() {
  if (game.selected && game.selected.alive) return game.selected;
  if (game.first && game.first.alive) return game.first;
  return game.creatures[0] || null;
}
function setCamFollow(on) {
  cam.follow = on;
  if (on) { panVel.x = panVel.y = 0; }
  setFollowActive(on);
}
function toggleFollow() {
  if (cam.follow) { setCamFollow(false); return false; }
  if (!(game.selected && game.selected.alive)) {
    const c = (game.first && game.first.alive) ? game.first : game.creatures[0];
    if (c) selectCreature(c);
  }
  setCamFollow(!!followTarget());
  return cam.follow;
}
function recenterCam() {
  const c = followTarget();
  if (!c) return;
  cam.x = c.x - canvas.width / 2 / cam.zoom;
  cam.y = c.y - canvas.height / 2 / cam.zoom;
  clampCam();
}
// arrasto manual (mouse ou dedo) cancela o seguir
function breakFollow() { if (cam.follow) setCamFollow(false); }

let pouring = false, panning = false, lastMx = 0, lastMy = 0, pourCd = 0;
let rcX = 0, rcY = 0; // origem do clique direito (clique parado volta à lupa)

// câmera WASD (desktop)
const heldKeys = new Set();
window.addEventListener('keydown', e => {
  if (e.target && (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA')) return;
  heldKeys.add(e.key.toLowerCase());
});
window.addEventListener('keyup', e => heldKeys.delete(e.key.toLowerCase()));
window.addEventListener('blur', () => heldKeys.clear());

function pickCreature(w) {
  let best = null, bd = 18 / cam.zoom + (IS_TOUCH ? 16 : 8);
  for (const c of game.creatures) {
    const d = Math.hypot(c.x - w.x, c.y - w.y);
    if (d < bd) { bd = d; best = c; }
  }
  return best;
}

function pickBuilding(w) {
  const tx = Math.floor(w.x / TILE), ty = Math.floor(w.y / TILE);
  if (!game.world.inBounds(tx, ty)) return null;
  return game.world.buildingAt.get(game.world.idx(tx, ty)) || null;
}

canvas.addEventListener('mousedown', e => {
  const w = toWorld(e.offsetX, e.offsetY);
  if (e.button === 1 || e.button === 2) {
    panning = true;
    if (e.button === 2) { rcX = e.clientX; rcY = e.clientY; }
  }
  else if (e.button === 0) {
    if (game.tool === 'inspect') {
      const c = pickCreature(w);
      if (c) selectCreature(c);
      else selectBuilding(pickBuilding(w)); // vazio fecha o inspetor
    } else {
      pouring = true;
      game.pour(game.tool, w.x, w.y);
      pourCd = 0.08;
    }
  }
  lastMx = e.offsetX; lastMy = e.offsetY;
});
window.addEventListener('mouseup', e => {
  // clique direito parado (sem arrasto) volta para a lupa
  if (e.button === 2 && Math.hypot(e.clientX - rcX, e.clientY - rcY) < 5) selectTool('inspect');
  pouring = false; panning = false;
});
canvas.addEventListener('mouseleave', () => { game.brush.visible = false; });
canvas.addEventListener('mousemove', e => {
  const w = toWorld(e.offsetX, e.offsetY);
  game.brush.x = w.x; game.brush.y = w.y; game.brush.visible = true;
  if (panning) {
    breakFollow();
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
let lastTapT = 0, lastTapX = 0, lastTapY = 0; // duplo-toque para zoom
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
      panVel.x = panVel.y = 0; lastPanT = performance.now();
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
    panVel.x = panVel.y = 0;
    const a = touchPos(e.touches[0]), b = touchPos(e.touches[1]);
    lastMx = (a.x + b.x) / 2; lastMy = (a.y + b.y) / 2;
    pinchDist = Math.hypot(a.x - b.x, a.y - b.y);
  }
}, { passive: false });

canvas.addEventListener('touchmove', e => {
  e.preventDefault();
  if (touchMode === 'pinch' && e.touches.length >= 2) {
    breakFollow();
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
      breakFollow();
      const dxw = (p.x - lastMx) / cam.zoom, dyw = (p.y - lastMy) / cam.zoom;
      cam.x -= dxw; cam.y -= dyw;
      clampCam();
      // velocidade suavizada (unidades de mundo/s) para a inércia ao soltar
      const tnow = performance.now();
      const dtp = Math.max(0.001, (tnow - lastPanT) / 1000);
      lastPanT = tnow;
      panVel.x = 0.6 * panVel.x + 0.4 * (-dxw / dtp);
      panVel.y = 0.6 * panVel.y + 0.4 * (-dyw / dtp);
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
    if (touchMode === 'pan' && !tapMoved && performance.now() - tapTime < 350) {
      // toque curto e parado: duplo-toque dá zoom; toque simples seleciona
      const tnow = performance.now();
      if (tnow - lastTapT < 300 && Math.hypot(tapX - lastTapX, tapY - lastTapY) < 30) {
        const before = toWorld(tapX, tapY);
        cam.zoom = Math.min(5, cam.zoom * 1.8);
        const after = toWorld(tapX, tapY);
        cam.x += before.x - after.x; cam.y += before.y - after.y; clampCam();
        lastTapT = 0;
      } else {
        lastTapT = tnow; lastTapX = tapX; lastTapY = tapY;
        const w = toWorld(tapX, tapY);
        const c = pickCreature(w);
        if (c) selectCreature(c);
        else selectBuilding(pickBuilding(w));
      }
      panVel.x = panVel.y = 0; // toque parado não desliza
    } else if (touchMode === 'pan') {
      // soltou após arrastar: limita a velocidade para a inércia não disparar
      const MAXV = 1600, sp = Math.hypot(panVel.x, panVel.y);
      if (sp > MAXV) { panVel.x *= MAXV / sp; panVel.y *= MAXV / sp; }
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
  panVel.x = panVel.y = 0;
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
  initUI(game, { onNewWorld: s => startWorld(s), onToggleFollow: toggleFollow, onRecenter: recenterCam });
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

  // câmera WASD
  const PAN_SPEED = 420;
  let pdx = 0, pdy = 0;
  if (heldKeys.has('w')) pdy -= 1;
  if (heldKeys.has('s')) pdy += 1;
  if (heldKeys.has('a')) pdx -= 1;
  if (heldKeys.has('d')) pdx += 1;
  if (pdx || pdy) {
    breakFollow();
    cam.x += pdx * PAN_SPEED * dtReal / cam.zoom;
    cam.y += pdy * PAN_SPEED * dtReal / cam.zoom;
    clampCam();
  }

  // câmera seguindo a criatura selecionada (ou o Primeiro) — suave
  if (cam.follow) {
    const tgt = followTarget();
    if (tgt) {
      const k = Math.min(1, dtReal * 6);
      cam.x += (tgt.x - canvas.width / 2 / cam.zoom - cam.x) * k;
      cam.y += (tgt.y - canvas.height / 2 / cam.zoom - cam.y) * k;
      clampCam();
    } else {
      setCamFollow(false);
    }
  } else if (touchMode === null && !panning && (Math.abs(panVel.x) > 3 || Math.abs(panVel.y) > 3)) {
    // inércia do arrasto por toque (glide que desacelera)
    cam.x += panVel.x * dtReal;
    cam.y += panVel.y * dtReal;
    clampCam();
    const decay = Math.pow(0.0016, dtReal);
    panVel.x *= decay; panVel.y *= decay;
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


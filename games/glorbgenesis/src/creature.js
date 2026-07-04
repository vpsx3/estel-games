// Classe Creature: DNA (genome), corpo procedural, comportamento e combate.

import { E, elemColor } from './elements.js';
import { TILE, T } from './world.js';
import { absorbElement } from './evolution.js';
import { creatureName } from './names.js';
import { tryEncounter } from './society.js';
import { attemptBuild, BUILD_THRESHOLD } from './building.js';

let nextId = 1;

function clamp01(v) { return Math.max(0, Math.min(1, v)); }

function baseBodyPlan(rng) {
  const blobOffsets = [];
  for (let i = 0; i < 8; i++) blobOffsets.push(rng.range(-0.14, 0.14));
  const spots = [];
  for (let i = 0; i < 5; i++) spots.push({ a: rng.angle(), d: rng.range(0.1, 0.75), r: rng.range(0.12, 0.3) });
  return {
    shape: rng.pick(['blob', 'blob', 'segment', 'radial']),
    size: rng.range(5.5, 8),
    hue: rng.range(0, 360), sat: rng.range(18, 45), light: rng.range(45, 62),
    eyes: rng.int(1, 3),
    limbs: rng.int(0, 4),
    wobble: rng.range(0.25, 0.6),
    spikes: 0, plates: 0, antennae: 0, antennaColor: null, spikeColor: null,
    tail: null, glow: null, aura: null,
    alpha: 1, crystal: false, prism: false, metallicLimbs: false,
    pattern: rng.chance(0.35) ? rng.pick(['stripes', 'spots']) : 'none',
    patternColor: `hsl(${rng.int(0, 360)},40%,30%)`,
    particles: [],
    blobOffsets, spots,
    phase: rng.angle(),
  };
}

function baseTemperament(rng) {
  return {
    aggression: rng.next(), sociability: rng.next(), curiosity: rng.next(),
    industriousness: rng.next(), greed: rng.next(),
  };
}

function baseStats(rng) {
  return {
    maxHp: rng.range(22, 32), speed: rng.range(26, 40),
    strength: rng.range(3, 6), defense: rng.range(1, 3),
    lifespan: rng.range(260, 460),
  };
}

function inheritPlan(rng, plan) {
  const p = JSON.parse(JSON.stringify(plan));
  // ~70% conservado; jitter + mutação visual obrigatória
  p.hue = (p.hue + rng.range(-25, 25) + 360) % 360;
  p.size = Math.max(4.5, Math.min(11, p.size + rng.range(-0.8, 0.8)));
  if (rng.chance(0.3)) p.eyes = Math.max(1, Math.min(5, p.eyes + rng.sign()));
  if (rng.chance(0.3)) p.limbs = Math.max(0, Math.min(8, p.limbs + rng.sign()));
  if (rng.chance(0.15)) p.shape = rng.pick(['blob', 'segment', 'radial']);
  if (rng.chance(0.25)) p.pattern = rng.pick(['none', 'stripes', 'spots']);
  for (let i = 0; i < 8; i++) p.blobOffsets[i] += rng.range(-0.05, 0.05);
  p.phase = rng.angle();
  return p;
}

function inheritTemperament(rng, ta, tb) {
  const out = {};
  const keys = Object.keys(ta);
  for (const k of keys) {
    const base = tb ? (ta[k] + tb[k]) / 2 : ta[k];
    out[k] = clamp01(base + rng.range(-0.15, 0.15));
  }
  // mutação forte ocasional: um eixo do temperamento é sorteado do zero
  // (evita que a espécie inteira convirja para o temperamento do Primeiro)
  if (rng.chance(0.25)) out[rng.pick(keys)] = rng.next();
  return out;
}

export class Creature {
  // opts: { isFirst, parentA, parentB, forcedSeed }
  constructor(game, x, y, opts = {}) {
    this.id = nextId++;
    this.game = game;
    this.x = x; this.y = y;
    this.heading = 0;
    this.rng = opts.forcedSeed !== undefined
      ? new game.RNGClass(opts.forcedSeed)
      : game.creatureSeedRng.fork();
    const rng = this.rng;
    this.heading = rng.angle();
    this.name = creatureName(rng);
    this.isFirst = !!opts.isFirst;

    const pa = opts.parentA, pb = opts.parentB;
    if (pa) {
      this.basePlan = inheritPlan(rng, pa.basePlan);
      this.temperament = inheritTemperament(rng, pa.temperament, pb && pb.temperament);
      this.stats = baseStats(rng);
      const src = pb && rng.chance(0.5) ? pb : pa;
      for (const k of Object.keys(this.stats)) {
        this.stats[k] = this.stats[k] * 0.3 + src.baseStatsSnapshot[k] * 0.7;
      }
    } else {
      this.basePlan = baseBodyPlan(rng);
      this.temperament = baseTemperament(rng);
      this.stats = baseStats(rng);
    }
    this.baseStatsSnapshot = { ...this.stats };
    this.bodyPlan = JSON.parse(JSON.stringify(this.basePlan));

    // flags/efeitos de traits
    this.traits = [];
    this.absorbed = {};
    this.immunities = new Set();
    this.contactDamage = 0;
    this.regen = 0;
    this.scary = 0;
    this.shiny = 0;
    this.floaty = false;
    this.aquatic = false;
    this.ignoreTerrain = false;
    this.conductive = false;
    this.chainDamage = false;
    this.slowAura = false;
    this.dashType = null;
    this.splitOnDeath = false;
    this.hasSplit = false;

    // herança de traits (~70% cada) + reaplicação de efeitos
    if (pa) {
      const pool = [...pa.traits, ...(pb ? pb.traits.filter(t => !pa.traits.some(o => o.id === t.id)) : [])];
      for (const t of pool) {
        if (rng.chance(0.7)) this.inheritTrait(t);
      }
    }

    this.hp = this.stats.maxHp;
    this.age = 0;
    this.carry = {}; this.carryTotal = 0;
    this.faction = null;
    this.weapon = null;
    this.vehicle = null;

    this.state = 'wander';
    this.target = null;        // criatura inimiga
    this.seekTile = null;      // {tx,ty,mode:'absorb'|'collect'}
    this.buildSpot = null;
    this.raidTarget = null;
    this.fleeFrom = null; this.fleeTimer = 0;
    this.senseTimer = rng.range(0, 0.5);
    this.wanderTimer = 0;
    this.encounterCd = rng.range(2, 6);
    this.attackCd = 0;
    this.dashCd = rng.range(2, 5);
    this.dashTime = 0;
    this.reproTimer = this.isFirst ? rng.range(12, 18) : rng.range(20, 34);
    this.animPhase = rng.angle();
    this.alive = true;
    this.dominantElem = -1;

    // filhote herda a facção do pai (nem sempre — e facções têm tamanho máximo)
    if (pa && pa.faction && pa.faction.members.length < 24 && rng.chance(0.75)) {
      pa.faction.addMember(this);
    }
  }

  inheritTrait(t) {
    if (this.traits.some(o => o.id === t.id)) return;
    const pool = this.game.mutationPools[t.element] || [];
    const mut = pool.find(m => m.id === t.id);
    if (!mut) return;
    mut.apply(this);
    this.traits.push({ ...t });
    this.absorbed[t.element] = (this.absorbed[t.element] || 0); // marca linhagem sem contar absorção
  }

  addParticleTrait(type, color) {
    if (this.bodyPlan.particles.length < 4) this.bodyPlan.particles.push({ type, color });
  }

  refreshDominant() {
    let best = -1, bestN = 0;
    for (const [k, v] of Object.entries(this.absorbed)) {
      if (v > bestN) { bestN = v; best = +k; }
    }
    if (best === -1 && this.traits.length) best = this.traits[this.traits.length - 1].element;
    this.dominantElem = best;
  }

  get attack() { return this.stats.strength + (this.weapon ? this.weapon.atk : 0) + this.contactDamage * 0.5; }

  update(dt) {
    const game = this.game, world = game.world, rng = this.rng;
    this.age += dt;
    if (this.age > this.stats.lifespan) return game.kill(this, 'de velhice');

    // dano/efeito do tile atual
    const tx = Math.floor(this.x / TILE), ty = Math.floor(this.y / TILE);
    if (world.inBounds(tx, ty)) {
      const d = world.dep[world.idx(tx, ty)];
      if (d === E.FIRE && !this.immunities.has(E.FIRE)) this.hurt(9 * dt, null, 'queimado');
      else if (d === E.POISON && !this.immunities.has(E.POISON)) this.hurt(4.5 * dt, null, 'envenenado');
    }
    if (!this.alive) return;
    if (this.regen > 0) this.hp = Math.min(this.stats.maxHp, this.hp + this.regen * dt);

    // percepção periódica
    this.senseTimer -= dt;
    this.encounterCd -= dt;
    if (this.senseTimer <= 0) {
      this.senseTimer = 0.5 + rng.next() * 0.3;
      this.sense();
    }

    // reprodução
    this.reproTimer -= dt;
    if (this.reproTimer <= 0) this.tryReproduce();

    // dash elétrico / salto
    if (this.dashType) {
      this.dashCd -= dt;
      this.dashTime -= dt;
      if (this.dashCd <= 0) {
        this.dashCd = rng.range(3, 7);
        this.dashTime = 0.35;
        if (this.dashType === 'electric') game.sparkBurst(this.x, this.y, '#ffe94a', 5);
      }
    }

    this.behave(dt);
    this.move(dt);
    this.emitTraitParticles(dt);
  }

  sense() {
    const game = this.game;
    if (this.state === 'fight' && this.target && this.target.alive) return;

    // fugir de criaturas assustadoras / inimigos fortes
    const near = game.hash.query(this.x, this.y, 60);
    for (const o of near) {
      if (o === this || !o.alive) continue;
      const hostileFaction = this.faction && o.faction && this.faction.isAtWar(o.faction);
      if ((o.scary > 0.3 && this.temperament.aggression < 0.5 && o.scary > this.scary) ||
          (hostileFaction && o.attack > this.attack * 1.6)) {
        this.fleeFrom = o; this.fleeTimer = 2.5; this.state = 'flee';
        return;
      }
      if (hostileFaction && this.dist(o) < 46) { this.engage(o); return; }
    }

    // encontro social
    if (this.encounterCd <= 0) {
      for (const o of near) {
        if (o === this || !o.alive || o.encounterCd > 0) continue;
        if (this.faction && this.faction === o.faction) continue;
        if (this.dist(o) < 30) { tryEncounter(game, this, o); break; }
      }
    }

    if (this.state === 'fight' || this.state === 'flee') return;

    // construir se carregando o suficiente de um mesmo elemento
    let maxCarry = 0;
    for (const v of Object.values(this.carry)) if (v > maxCarry) maxCarry = v;
    if (maxCarry >= BUILD_THRESHOLD && this.state !== 'build') {
      this.pickBuildSpot();
      if (this.buildSpot) { this.state = 'build'; return; }
    }
    if (this.state === 'build' && this.buildSpot) return;
    if (this.state === 'raid' && this.raidTarget) return;

    // procurar depósitos de elementos
    if (!this.seekTile) this.findDeposit();
    this.state = this.seekTile ? 'seek' : 'wander';
  }

  findDeposit() {
    const world = this.game.world, rng = this.rng;
    const ctx = Math.floor(this.x / TILE), cty = Math.floor(this.y / TILE);
    const greedy = this.temperament.greed > 0.5;
    const R = greedy ? 8 : 5;
    let best = null, bestScore = 0;
    for (let dy = -R; dy <= R; dy++) {
      for (let dx = -R; dx <= R; dx++) {
        const x = ctx + dx, y = cty + dy;
        if (!world.inBounds(x, y)) continue;
        const i = world.idx(x, y);
        const d = world.dep[i];
        if (d === -1 || d === E.AIR && world.depLife[i] < 0.5) continue;
        if (d === E.FIRE && !this.immunities.has(E.FIRE) && this.temperament.curiosity < 0.75) continue;
        if (d === E.POISON && !this.immunities.has(E.POISON) && this.temperament.curiosity < 0.7) continue;
        const distW = 1 / (1 + Math.abs(dx) + Math.abs(dy));
        let w = distW;
        if (d === E.GOLD) w *= 1 + this.temperament.greed * 4;
        if (d === E.DIAMOND) w *= 1.5;
        const jitter = 0.5 + rng.next();
        if (w * jitter > bestScore) { bestScore = w * jitter; best = { tx: x, ty: y, elem: d }; }
      }
    }
    if (!best) return;
    // ABSORVER ou COLETAR?
    let mode;
    const absorbDesire = this.temperament.curiosity * (0.6 + rng.next() * 0.8);
    const collectDesire = this.temperament.industriousness * (0.6 + rng.next() * 0.8) + this.temperament.greed * (best.elem === E.GOLD ? 0.6 : 0);
    mode = absorbDesire >= collectDesire ? 'absorb' : 'collect';
    if (best.elem === E.DIAMOND && this.stats.strength < 8) mode = 'collect'; // duríssimo: exige força para absorver
    if (this.carryTotal >= BUILD_THRESHOLD + 2) mode = 'absorb';
    best.mode = mode;
    this.seekTile = best;
  }

  pickBuildSpot() {
    const world = this.game.world, rng = this.rng;
    let ox = this.x, oy = this.y;
    if (this.faction && this.faction.buildings.length > 0 && rng.chance(0.7)) {
      const c = this.faction.center();
      ox = c.x + rng.range(-3, 3) * TILE; oy = c.y + rng.range(-3, 3) * TILE;
    }
    const ctx = Math.floor(ox / TILE), cty = Math.floor(oy / TILE);
    for (let ring = 0; ring < 6; ring++) {
      for (let attempt = 0; attempt < 6; attempt++) {
        const x = ctx + rng.int(-ring - 1, ring + 1), y = cty + rng.int(-ring - 1, ring + 1);
        if (!world.inBounds(x, y)) continue;
        const i = world.idx(x, y);
        if (world.buildingAt.has(i)) continue;
        if (world.terrain[i] === T.WATER) continue;
        this.buildSpot = { tx: x, ty: y };
        return;
      }
    }
    this.buildSpot = null;
  }

  behave(dt) {
    const game = this.game;
    switch (this.state) {
      case 'flee': {
        this.fleeTimer -= dt;
        if (!this.fleeFrom || !this.fleeFrom.alive || this.fleeTimer <= 0) { this.state = 'wander'; this.fleeFrom = null; break; }
        this.heading = Math.atan2(this.y - this.fleeFrom.y, this.x - this.fleeFrom.x);
        break;
      }
      case 'fight': {
        const t = this.target;
        if (!t || !t.alive) { this.state = 'wander'; this.target = null; break; }
        // ferido demais: foge ao invés de lutar até a morte
        if (this.hp < this.stats.maxHp * 0.25 && this.temperament.aggression < 0.7) {
          this.fleeFrom = t; this.fleeTimer = 4; this.state = 'flee'; this.target = null;
          break;
        }
        this.heading = Math.atan2(t.y - this.y, t.x - this.x);
        this.attackCd -= dt;
        const reach = this.bodyPlan.size + t.bodyPlan.size + 4;
        if (this.dist(t) < reach && this.attackCd <= 0) {
          this.attackCd = 0.8;
          const dmg = Math.max(1, this.attack + this.contactDamage - t.stats.defense * 0.55);
          t.hurt(dmg, this, `em combate com ${this.name}`);
          game.hitSpark(t.x, t.y, this.dominantElem);
          if (this.chainDamage) {
            for (const o of game.hash.query(t.x, t.y, 40)) {
              if (o !== t && o !== this && o.alive && (!this.faction || o.faction !== this.faction)) {
                o.hurt(dmg * 0.4, this, `por dano em cadeia de ${this.name}`);
                game.sparkBurst(o.x, o.y, '#ffe94a', 3);
              }
            }
          }
          if (t.alive && t.contactDamage > 0) this.hurt(t.contactDamage * 0.6, t, `pelos espinhos de ${t.name}`);
        }
        break;
      }
      case 'seek': {
        const s = this.seekTile;
        if (!s) { this.state = 'wander'; break; }
        const px = s.tx * TILE + TILE / 2, py = s.ty * TILE + TILE / 2;
        this.heading = Math.atan2(py - this.y, px - this.x);
        const world = game.world, i = world.idx(s.tx, s.ty);
        if (world.dep[i] !== s.elem) { this.seekTile = null; this.state = 'wander'; break; }
        if (Math.hypot(px - this.x, py - this.y) < TILE * 0.7) {
          world.clearDep(i);
          if (s.mode === 'absorb') {
            absorbElement(this, s.elem, game);
            game.absorbPuff(this.x, this.y, elemColor(s.elem));
          } else {
            this.carry[s.elem] = (this.carry[s.elem] || 0) + 1;
            this.carryTotal++;
          }
          this.seekTile = null; this.state = 'wander';
        }
        break;
      }
      case 'build': {
        const b = this.buildSpot;
        if (!b) { this.state = 'wander'; break; }
        const px = b.tx * TILE + TILE / 2, py = b.ty * TILE + TILE / 2;
        this.heading = Math.atan2(py - this.y, px - this.x);
        if (Math.hypot(px - this.x, py - this.y) < TILE * 0.9) {
          attemptBuild(game, this, b.tx, b.ty);
          this.buildSpot = null; this.state = 'wander';
        }
        break;
      }
      case 'raid': {
        const r = this.raidTarget;
        if (!r || !this.faction || !this.faction.isAtWar(r.faction)) { this.raidTarget = null; this.state = 'wander'; break; }
        const c = r.faction.center();
        this.heading = Math.atan2(c.y - this.y, c.x - this.x);
        // ao chegar na vila: atacar construção ou inimigo próximo
        if (Math.hypot(c.x - this.x, c.y - this.y) < 60) {
          for (const o of this.game.hash.query(this.x, this.y, 70)) {
            if (o.alive && o.faction === r.faction) { this.engage(o); return; }
          }
          const b = r.faction.nearestBuilding(this.x, this.y);
          if (b) {
            this.heading = Math.atan2(b.y - this.y, b.x - this.x);
            if (Math.hypot(b.x - this.x, b.y - this.y) < TILE) {
              this.attackCd -= dt;
              if (this.attackCd <= 0) { this.attackCd = 0.8; b.hp -= this.attack; this.game.hitSpark(b.x, b.y, this.dominantElem); }
            }
          } else { this.raidTarget = null; this.state = 'wander'; }
        }
        break;
      }
      default: { // wander
        this.wanderTimer -= dt;
        if (this.wanderTimer <= 0) {
          this.wanderTimer = this.rng.range(0.8, 2.4);
          this.heading += this.rng.range(-1.4, 1.4);
        }
      }
    }
  }

  move(dt) {
    const world = this.game.world;
    let f = this.ignoreTerrain || this.floaty ? 1 : world.moveFactorAtPx(this.x, this.y);
    if (this.aquatic && world.terrainAtPx(this.x, this.y) === T.WATER) f = Math.max(f, 1.05);
    let sp = this.stats.speed * f;
    if (this.vehicle) sp *= this.vehicle.speedMul;
    if (this.dashTime > 0) sp *= this.dashType === 'electric' ? 2.6 : 1.9;
    if (this.state === 'fight' && this.target && this.target.slowAura) sp *= 0.7;
    this.x += Math.cos(this.heading) * sp * dt;
    this.y += Math.sin(this.heading) * sp * dt;
    const m = 8, W = world.w * TILE, H = world.h * TILE;
    if (this.x < m) { this.x = m; this.heading = Math.PI - this.heading; }
    if (this.x > W - m) { this.x = W - m; this.heading = Math.PI - this.heading; }
    if (this.y < m) { this.y = m; this.heading = -this.heading; }
    if (this.y > H - m) { this.y = H - m; this.heading = -this.heading; }
    this.animPhase += sp * dt * 0.12;
    this.speedNow = sp;
  }

  emitTraitParticles(dt) {
    const game = this.game;
    for (const p of this.bodyPlan.particles) {
      if (game.fxRng.chance(dt * 2.2)) game.traitParticle(this, p);
    }
  }

  engage(other) {
    if (!other.alive) return;
    if (this.target !== other) this.game.combatCount++;
    this.target = other; this.state = 'fight';
    if (other.state !== 'fight' || !other.target || !other.target.alive) {
      other.target = this; other.state = 'fight';
    }
  }

  tryReproduce() {
    const game = this.game, rng = this.rng;
    this.reproTimer = rng.range(22, 38);
    if (this.age < 8 || !this.alive) return;
    if (game.creatures.length >= game.popCap) return;
    // fertilidade cai com densidade local (cap populacional suave)
    const neighbors = game.hash.query(this.x, this.y, 90).length;
    if (rng.chance(Math.min(0.9, neighbors / 12))) { this.reproTimer = rng.range(10, 18); return; }
    // reprodução mista se aliado próximo
    let mate = null;
    if (this.faction) {
      for (const o of game.hash.query(this.x, this.y, 50)) {
        if (o !== this && o.alive && o.faction === this.faction && o.age > 8) { mate = o; break; }
      }
    }
    const a = rng.angle();
    const child = new Creature(game, this.x + Math.cos(a) * 14, this.y + Math.sin(a) * 14, { parentA: this, parentB: mate });
    game.addCreature(child);
    game.feed(`🐣 ${child.name} nasceu de ${this.name}${mate ? ' e ' + mate.name : ''}`, '#8fd18f');
  }

  hurt(dmg, attacker, cause) {
    if (!this.alive) return;
    this.hp -= dmg;
    if (this.hp <= 0) this.game.kill(this, cause || 'em combate', attacker);
    else if (attacker && this.state !== 'fight' && this.state !== 'flee') {
      if (this.temperament.aggression > 0.35 || this.attack >= attacker.attack) this.engage(attacker);
      else { this.fleeFrom = attacker; this.fleeTimer = 3; this.state = 'flee'; }
    }
  }

  dist(o) { return Math.hypot(o.x - this.x, o.y - this.y); }
}

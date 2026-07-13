// Classe Creature: DNA (genome), corpo procedural, comportamento e combate.

import { E, ENDGAME, elemColor } from './elements.js';
import { TILE, T } from './world.js';
import { absorbElement } from './evolution.js';
import { creatureName } from './names.js';
import { tryEncounter, factionCap } from './society.js';
import { attemptBuild, BUILD_THRESHOLD } from './building.js';
let nextId = 1;

function clamp01(v) { return Math.max(0, Math.min(1, v)); }

// Depósitos que machucam quem pisa: a IA de coleta evita buscá-los, a menos
// que a criatura tenha uma das imunidades listadas ou curiosidade ≥ limiar
// (fogo e veneno mantêm os limiares históricos; os letais exigem quase 1).
const HAZARD_DEPOSITS = {
  [E.FIRE]:     { imm: [E.FIRE], curio: 0.75 },
  [E.POISON]:   { imm: [E.POISON], curio: 0.7 },
  [E.LAVA]:     { imm: [E.LAVA, E.FIRE], curio: 0.9 },
  [E.PLASMA]:   { imm: [], curio: 0.97 },
  [E.ACID]:     { imm: [E.ACID, E.POISON], curio: 0.85 },
  [E.MIASMA]:   { imm: [E.MIASMA, E.POISON], curio: 0.85 },
  [E.PLAGUE]:   { imm: [E.PLAGUE, E.MIASMA, E.POISON], curio: 0.9 },
  [E.STARCORE]: { imm: [], curio: 0.97 },
};

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

const ARCHETYPES = [
  { id: 'valente',      name: 'Valente',      w: 6, anchors: { aggression: 0.85 } },
  { id: 'ousado',       name: 'Ousado',       w: 5, anchors: { aggression: 0.70, curiosity: 0.85 } },
  { id: 'pacifico',     name: 'Pacífico',     w: 6, anchors: { aggression: 0.15 } },
  { id: 'diplomata',    name: 'Diplomata',    w: 5, anchors: { sociability: 0.85, aggression: 0.30 } },
  { id: 'curioso',      name: 'Curioso',      w: 7, anchors: { curiosity: 0.85 } },
  { id: 'mistico',      name: 'Místico',      w: 4, anchors: { curiosity: 0.85, industriousness: 0.15 } },
  { id: 'construtor',   name: 'Construtor',   w: 7, anchors: { industriousness: 0.85 } },
  { id: 'trabalhador',  name: 'Trabalhador',  w: 5, anchors: { industriousness: 0.85, curiosity: 0.30 } },
  { id: 'inventivo',    name: 'Inventivo',    w: 5, anchors: { curiosity: 0.70, industriousness: 0.85 } },
  { id: 'coletor',      name: 'Coletor',      w: 5, anchors: { industriousness: 0.85, greed: 0.70 } },
  { id: 'ganancioso',   name: 'Ganancioso',   w: 6, anchors: { greed: 0.85 } },
  { id: 'trapaceiro',   name: 'Trapaceiro',   w: 4, anchors: { greed: 0.85, curiosity: 0.70, sociability: 0.15 } },
  { id: 'vaidoso',      name: 'Vaidoso',      w: 4, anchors: { sociability: 0.70, greed: 0.85 } },
  { id: 'cauteloso',    name: 'Cauteloso',    w: 5, anchors: { aggression: 0.15, curiosity: 0.30, industriousness: 0.70 } },
  { id: 'medroso',      name: 'Medroso',      w: 5, anchors: { aggression: 0.15, curiosity: 0.15 } },
  { id: 'solitario',    name: 'Solitário',    w: 5, anchors: { sociability: 0.15, curiosity: 0.70 } },
  { id: 'gregario',     name: 'Gregário',     w: 7, anchors: { sociability: 0.85 } },
  { id: 'protetor',     name: 'Protetor',     w: 5, anchors: { aggression: 0.70, sociability: 0.85, greed: 0.15 } },
  { id: 'predador',     name: 'Predador',     w: 4, anchors: { aggression: 0.85, sociability: 0.15 } },
  { id: 'imprevisivel', name: 'Imprevisível', w: 3, anchors: {} },
];

function rollArchetype(rng) {
  let total = 0;
  for (const a of ARCHETYPES) total += a.w;
  let r = rng.next() * total;
  for (const a of ARCHETYPES) { r -= a.w; if (r <= 0) return a; }
  return ARCHETYPES[ARCHETYPES.length - 1];
}

function archetypeTemperament(rng, arch) {
  const t = baseTemperament(rng);
  for (const k of Object.keys(arch.anchors)) {
    t[k] = clamp01(arch.anchors[k] + rng.range(-0.12, 0.12));
  }
  return t;
}

// Atribui o rótulo cujas âncoras melhor descrevem um temperamento herdado.
// Bônus de 0.03 por eixo ancorado favorece arquétipos mais específicos em empates.
// Se nenhum arquétipo descreve bem (score bruto < 0.72), a criatura é Imprevisível.
function classifyArchetype(t) {
  let best = null, bestAdj = -1;
  for (const a of ARCHETYPES) {
    const keys = Object.keys(a.anchors);
    if (keys.length === 0) continue; // imprevisivel é o fallback
    let s = 0;
    for (const k of keys) s += 1 - Math.abs(t[k] - a.anchors[k]);
    const raw = s / keys.length;
    if (raw < 0.72) continue;
    const adj = raw + 0.03 * keys.length;
    if (adj > bestAdj) { bestAdj = adj; best = a; }
  }
  return best || ARCHETYPES.find(a => a.id === 'imprevisivel');
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

function inheritPlan(rng, plan, planB) {
  const p = JSON.parse(JSON.stringify(plan));
  if (planB) {
    // dois pais: mescla campo a campo
    let dh = planB.hue - plan.hue;
    if (dh > 180) dh -= 360; else if (dh < -180) dh += 360;
    p.hue = (plan.hue + dh / 2 + rng.range(-15, 15) + 360) % 360; // média circular (menor arco)
    p.size = Math.max(4.5, Math.min(11, (plan.size + planB.size) / 2 + rng.range(-0.6, 0.6)));
    if (rng.chance(0.5)) p.eyes = planB.eyes;
    if (rng.chance(0.5)) p.limbs = planB.limbs;
    if (rng.chance(0.5)) p.pattern = planB.pattern;
    if (rng.chance(0.5)) p.patternColor = planB.patternColor;
    const shapeSrc = rng.chance(0.5) ? planB : plan;
    p.shape = shapeSrc.shape;
    p.blobOffsets = shapeSrc.blobOffsets.slice();
  } else {
    // um pai só: ~70% conservado; jitter + mutação visual obrigatória
    p.hue = (p.hue + rng.range(-25, 25) + 360) % 360;
    p.size = Math.max(4.5, Math.min(11, p.size + rng.range(-0.8, 0.8)));
  }
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
    this.parents = pa ? [pa.name, pb ? pb.name : null] : null;
    if (pa) {
      this.basePlan = inheritPlan(rng, pa.basePlan, pb && pb.basePlan);
      this.temperament = inheritTemperament(rng, pa.temperament, pb && pb.temperament);
      this.archetype = classifyArchetype(this.temperament);
      this.stats = baseStats(rng);
      const src = pb && rng.chance(0.5) ? pb : pa;
      for (const k of Object.keys(this.stats)) {
        this.stats[k] = this.stats[k] * 0.3 + src.baseStatsSnapshot[k] * 0.7;
      }
    } else {
      this.basePlan = baseBodyPlan(rng);
      this.archetype = rollArchetype(rng);
      this.temperament = archetypeTemperament(rng, this.archetype);
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
    // flags dos elementos de fusão (efeitos implementados nas Etapas 5/6)
    this.fireTrail = false;
    this.acidBlood = false;
    this.deathBurst = false;
    this.sporeParent = false;
    this.plagueTrail = false;
    this.magneticBody = false;
    this.mistVeil = false;
    this.inMist = false;
    this.relicTimer = 0;
    this.ashRebirth = false;
    this.ashUsed = false;
    this.inEther = false;     // flutuação transitória no raio do éter
    this.electrumShock = 0;   // cooldown individual do choque do eletro
    // gigantismo (Fase A): permanente, nunca decai; filhotes nascem normais
    this.absorbLifetime = 0;  // total de absorções na vida (nunca decai)
    this.sizeMul = 1;         // escala visual/física derivada
    this.giantTier = 0;       // 0 normal, 1 Graúdo, 2 Colosso, 3 Titã
    // dons elementais: status e temporizadores
    this.gifts = new Set();       // ids de elemento cujos dons despertou
    this.giftTimers = {};         // cooldowns por dom
    this.dots = [];               // dano contínuo [{dps, t, src, ignoreDefense, hops}]
    this.chillTimer = 0;          // lentidão de status (×0.7 enquanto > 0)
    this.frozenTimer = 0;         // congelamento total (Dom da Nevasca)
    this.stillTime = 0;           // tempo parado (dons da Semente/Névoa/Musgo)
    this.charcoalStacks = 0;      // acúmulo do Dom do Carvão (máx +5)
    this.giftVeil = false;        // véu efetivo do Dom da Névoa
    this.plateStripped = false;   // já perdeu 1 placa para o Dom da Corrosão
    this.depositDamageTick = false; // dano sendo aplicado pelo tile (Dom Etéreo)

    // herança de traits (~70% cada) + reaplicação de efeitos
    if (pa) {
      const pool = [...pa.traits, ...(pb ? pb.traits.filter(t => !pa.traits.some(o => o.id === t.id)) : [])];
      for (const t of pool) {
        if (rng.chance(0.7)) this.inheritTrait(t);
      }
    }

    this.hp = this.stats.maxHp;
    this.age = 0;
    this.driftT = 0;
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
    this.produceTimer = rng.range(24, 40);
    this.consumeCd = rng.range(0, 0.5); // cadência da devoração do excesso
    this.animPhase = rng.angle();
    this.alive = true;
    this.dominantElem = -1;

    // filhote herda a facção do pai (nem sempre — e facções têm tamanho máximo)
    if (pa && pa.faction && pa.faction.members.length < factionCap(game) && rng.chance(0.75)) {
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
    if (this.archetype && this.archetype.id === 'imprevisivel') {
      this.driftT += dt;
      if (this.driftT >= 20) {
        this.driftT = 0;
        const keys = Object.keys(this.temperament);
        const k = rng.pick(keys);
        this.temperament[k] = clamp01(this.temperament[k] + rng.range(-0.10, 0.10));
      }
    }
    if (this.age > this.stats.lifespan) return game.kill(this, 'de velhice');

    // status contínuos (dots) e temporizadores de dons
    if (this.dots.length) {
      for (let i = this.dots.length - 1; i >= 0; i--) {
        const dot = this.dots[i];
        dot.t -= dt;
        this.hurt(dot.dps * dt, null, dot.src); // attacker null: dots não reativam efeitos on-hit
        if (dot.t <= 0) this.dots.splice(i, 1);
      }
      if (!this.alive) return;
    }
    if (this.chillTimer > 0) this.chillTimer -= dt;
    if (this.frozenTimer > 0) this.frozenTimer -= dt;
    for (const k in this.giftTimers) if (this.giftTimers[k] > 0) this.giftTimers[k] -= dt;

    // dano/efeito do tile atual
    this.inMist = false;
    this.inEther = false;
    if (this.electrumShock > 0) this.electrumShock -= dt;
    const tx = Math.floor(this.x / TILE), ty = Math.floor(this.y / TILE);
    this.depositDamageTick = true;
    if (world.inBounds(tx, ty)) {
      const d = world.dep[world.idx(tx, ty)];
      if (d === E.FIRE && !this.immunities.has(E.FIRE)) this.hurt(9 * dt, null, 'queimado');
      else if (d === E.POISON && !this.immunities.has(E.POISON)) this.hurt(4.5 * dt, null, 'envenenado');
      else if (d === E.LAVA && !this.immunities.has(E.LAVA) && !this.immunities.has(E.FIRE)) this.hurt(14 * dt, null, 'derretido pela lava');
      else if (d === E.PLASMA) this.hurt(40 * dt, null, 'desintegrado por plasma');
      else if (d === E.ACID && !this.immunities.has(E.ACID)) this.hurt((this.immunities.has(E.POISON) ? 4 : 8) * dt, null, 'corroído por ácido');
      else if (d === E.MIASMA && !this.immunities.has(E.MIASMA) && !this.immunities.has(E.POISON)) this.hurt(4.5 * dt, null, 'consumido pelo miasma');
      else if (d === E.MOSS) this.hp = Math.min(this.stats.maxHp, this.hp + 2 * dt);
      else if (d === E.FUNGUS && this.rng.chance(0.02 * dt)) this.gainRandomMutation();
      else if (d === E.SMOKE && this.rng.chance(0.5 * dt)) { this.target = null; this.seekTile = null; } // cegueira
      else if (d === E.MIST) this.inMist = true;
      else if (d === E.VAPOR && this.rng.chance(0.25 * dt)) { this.target = null; this.seekTile = null; } // névoa quente ofusca
      else if (d === E.BLIZZARD && !this.immunities.has(E.ICE) && !this.immunities.has(E.SNOW) && !this.immunities.has(E.BLIZZARD)) this.hurt(2 * dt, null, 'congelado pela nevasca');
      else if (d === E.SWAMP) {
        // pântano nutre criaturas orgânicas e envenena as demais
        const ORGANIC = [E.WOOD, E.SLIME, E.MOSS, E.FUNGUS, E.MUD, E.SWAMP];
        if (this.traits.some(t => ORGANIC.includes(t.element))) this.hp = Math.min(this.stats.maxHp, this.hp + 2 * dt);
        else if (!this.immunities.has(E.POISON)) this.hurt(1.5 * dt, null, 'consumido pelo pântano');
      }
      else if (d === E.MERCURY && !this.immunities.has(E.POISON)) this.hurt(3 * dt, null, 'intoxicado por mercúrio');
      else if (d === E.ELECTRUM && this.electrumShock <= 0) { this.electrumShock = 3; this.hurt(6, null, 'pelo choque do eletro'); }
      else if (d === E.PLAGUE && !this.immunities.has(E.MIASMA) && !this.immunities.has(E.POISON) && !this.immunities.has(E.PLAGUE)) {
        this.hurt(3 * dt, null, 'consumido pela praga');
        if (this.alive && this.rng.chance(0.02 * dt * 60)) this.gainRandomMutation(this.rng.chance(0.5) ? E.MIASMA : E.SMOKE);
      }
      else if (d === E.STARCORE) this.hurt(25 * dt, null, 'incinerado pelo núcleo estelar');
      // calor dos 8 vizinhos do núcleo estelar
      if (this.alive && world.starcoreTiles.size && d !== E.STARCORE) {
        outer: for (let ndy = -1; ndy <= 1; ndy++) {
          for (let ndx = -1; ndx <= 1; ndx++) {
            if (!ndx && !ndy) continue;
            const nx = tx + ndx, ny = ty + ndy;
            if (world.inBounds(nx, ny) && world.dep[world.idx(nx, ny)] === E.STARCORE) {
              this.hurt(8 * dt, null, 'queimado pelo calor estelar');
              break outer;
            }
          }
        }
      }
    }
    this.depositDamageTick = false;
    if (!this.alive) return;
    if (this.regen > 0) this.hp = Math.min(this.stats.maxHp, this.hp + this.regen * dt);

    // rastros deixados por mutações de fusão
    if ((this.fireTrail || this.plagueTrail) && world.inBounds(tx, ty)) {
      const ti = world.idx(tx, ty);
      if (world.dep[ti] === -1 && !world.buildingAt.has(ti)) {
        if (this.fireTrail && rng.chance(0.02 * dt * 60)) world.setDep(ti, E.FIRE, rng.range(1.5, 2.5));
        else if (this.plagueTrail && rng.chance(0.02 * dt * 60)) world.setDep(ti, E.MIASMA, 8);
      }
    }
    // campos de atração: ímã, relíquia e corpo magnético
    this.applyFieldPulls(dt);
    if (!this.alive) return;

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

    // produção: devolve ao mapa cópias dos elementos que absorveu
    this.produceTimer -= dt;
    if (this.produceTimer <= 0) {
      this.produceTimer = rng.range(24, 40);
      const elems = Object.entries(this.absorbed).filter(([k, v]) => v >= 1);
      if (elems.length && rng.chance(0.5)) {
        // sorteio ponderado pela contagem de absorções
        const total = elems.reduce((s, [, v]) => s + v, 0);
        let roll = rng.next() * total, elem = +elems[0][0];
        for (const [k, v] of elems) { roll -= v; if (roll <= 0) { elem = +k; break; } }
        const ptx = Math.floor(this.x / TILE), pty = Math.floor(this.y / TILE);
        if (elem === E.LIGHTNING) game.world.lightningStrike(ptx, pty, rng, game, 3);
        else game.world.pour(elem, ptx, pty, 1, rng, game);
        game.smokeAt(this.x, this.y);
      }
    }

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
    // devoração do excesso: enquanto o mapa transborda, come depósitos ao redor
    // (e, no auge, corrói construções) para liberar espaço
    if (game.purgeLevel > 0 && this.state !== 'fight' && this.state !== 'flee') this.consumeExcess(dt);
    if (this.gifts.size) this.updateGifts(dt);
    if (!this.alive) return;
    this.emitTraitParticles(dt);
  }

  // Dons contínuos (hook upd): rodam depois do movimento, quando há dons.
  updateGifts(dt) {
    const game = this.game, world = game.world, rng = this.rng, gifts = this.gifts;
    const tx = Math.floor(this.x / TILE), ty = Math.floor(this.y / TILE);
    const inB = world.inBounds(tx, ty);
    const ti = inB ? world.idx(tx, ty) : -1;
    const dep = inB ? world.dep[ti] : -1;
    const tileEmpty = inB && dep === -1 && !world.buildingAt.has(ti);

    // Dom da Névoa: véu efetivo enquanto parada há ≥2s
    this.giftVeil = gifts.has(E.MIST) && this.stillTime >= 2;
    // Dom da Semente: parada há ≥3s pode plantar madeira
    if (gifts.has(E.WOOD) && this.stillTime >= 3 && tileEmpty && rng.chance(0.05 * dt * 60)) world.setDep(ti, E.WOOD, 0);
    // Dom da Gosma: deixa slime pelo caminho
    if (gifts.has(E.SLIME) && tileEmpty && rng.chance(0.03 * dt * 60)) world.setDep(ti, E.SLIME, 0);
    // Dom do Lodo: fugindo, deixa lama para atrasar o perseguidor
    if (gifts.has(E.MUD) && this.state === 'flee' && tileEmpty && rng.chance(0.05 * dt * 60)) world.setDep(ti, E.MUD, 0);
    // Dom Glacial: fugindo, deposita geleira no tile que acabou de deixar
    if (gifts.has(E.GLACIER) && this.state === 'flee' && (this.giftTimers.glacier || 0) <= 0 && tileEmpty) {
      this.giftTimers.glacier = 18;
      world.setDep(ti, E.GLACIER, 0);
    }
    // Dom do Musgo: regen extra parada
    if (gifts.has(E.MOSS) && this.stillTime > 0.5) this.hp = Math.min(this.stats.maxHp, this.hp + 1 * dt);
    // Dom do Pântano: cura em lama/pântano/água
    if (gifts.has(E.SWAMP) && (dep === E.MUD || dep === E.SWAMP || (inB && world.terrain[ti] === T.WATER))) {
      this.hp = Math.min(this.stats.maxHp, this.hp + 3 * dt);
    }
    // Dom da Fumaça: abaixo de 30% hp solta fumaça e acelera por 3s
    if (gifts.has(E.SMOKE) && this.hp < this.stats.maxHp * 0.3 && (this.giftTimers.smoke || 0) <= 0) {
      this.giftTimers.smoke = 25; // vel ×1.4 enquanto o timer está acima de 22
      if (tileEmpty) world.setDep(ti, E.SMOKE, rng.range(6, 9));
    }
    // Dom do Vento: rajada periódica empurra os vizinhos
    if (gifts.has(E.AIR) && (this.giftTimers.air || 0) <= 0) {
      this.giftTimers.air = 12;
      const W = world.w * TILE, H = world.h * TILE;
      for (const o of game.hash.query(this.x, this.y, 50)) {
        if (o === this || !o.alive) continue;
        const d = Math.max(1, this.dist(o));
        o.x = Math.max(8, Math.min(W - 8, o.x + (o.x - this.x) / d * 24));
        o.y = Math.max(8, Math.min(H - 8, o.y + (o.y - this.y) / d * 24));
      }
      game.sparkBurst(this.x, this.y, '#c9e6e2', 6);
    }
    // Dom da Tempestade: raio periódico no inimigo mais próximo
    if (gifts.has(E.STORM) && (this.giftTimers.storm || 0) <= 0) {
      let best = null, bd = 100;
      for (const o of game.hash.query(this.x, this.y, 100)) {
        if (o === this || !o.alive || (this.faction && o.faction === this.faction)) continue;
        const d = this.dist(o);
        if (d < bd) { bd = d; best = o; }
      }
      if (best) {
        this.giftTimers.storm = 20;
        world.lightningStrike(Math.floor(best.x / TILE), Math.floor(best.y / TILE), rng, game, 1);
      }
    }
    // Dom Miasmático: aura de dano em inimigos colados
    if (gifts.has(E.MIASMA)) {
      for (const o of game.hash.query(this.x, this.y, 20)) {
        if (o !== this && o.alive && (!this.faction || o.faction !== this.faction)) o.hurt(2 * dt, null, `pelo miasma de ${this.name}`);
      }
    }
    // Dom do Carvão: forja lenta perto de fogo/lava (máx +5 de força)
    if (gifts.has(E.CHARCOAL) && this.charcoalStacks < 5 && (this.giftTimers.charcoal || 0) <= 0 && inB) {
      let nearFire = false;
      outer: for (let dy = -1; dy <= 1; dy++) {
        for (let dx = -1; dx <= 1; dx++) {
          const nx = tx + dx, ny = ty + dy;
          if (!world.inBounds(nx, ny)) continue;
          const nd = world.dep[world.idx(nx, ny)];
          if (nd === E.FIRE || nd === E.LAVA) { nearFire = true; break outer; }
        }
      }
      if (nearFire) { this.giftTimers.charcoal = 10; this.charcoalStacks++; this.stats.strength += 1; }
    }
    // Dom da Aurora: cura aliados de facção por perto
    if (gifts.has(E.AURORA) && this.faction) {
      for (const o of game.hash.query(this.x, this.y, 60)) {
        if (o !== this && o.alive && o.faction === this.faction) o.hp = Math.min(o.stats.maxHp, o.hp + 0.5 * dt);
      }
    }
    // Dom Estelar: puxa inimigos para o próprio corpo
    if (gifts.has(E.STARCORE)) {
      for (const o of game.hash.query(this.x, this.y, 60)) {
        if (o === this || !o.alive || (this.faction && o.faction === this.faction)) continue;
        const d = Math.max(1, this.dist(o));
        o.x += (this.x - o.x) / d * 6 * dt;
        o.y += (this.y - o.y) / d * 6 * dt;
      }
    }
  }

  // Ímã atrai corpos condutores/metálicos; relíquia atrai qualquer criatura
  // (e converte em Devoto quem fica por perto); corpo magnético puxa condutores.
  applyFieldPulls(dt) {
    const world = this.game.world;
    if (world.magnetTiles.size && (this.conductive || this.bodyPlan.metallicLimbs || this.bodyPlan.plates >= 2)) {
      const m = this.nearestFieldTile(world.magnetTiles, 60);
      if (m) { this.x += (m.x - this.x) / m.d * 12 * dt; this.y += (m.y - this.y) / m.d * 12 * dt; }
    }
    if (world.relicTiles.size) {
      const r = this.nearestFieldTile(world.relicTiles, 100);
      if (r) {
        this.x += (r.x - this.x) / r.d * 8 * dt;
        this.y += (r.y - this.y) / r.d * 8 * dt;
        if (r.d < 20) {
          this.relicTimer += dt;
          if (this.relicTimer >= 3 && !this.traits.some(t => t.id === 'devoto')) {
            this.temperament.sociability = Math.min(1, this.temperament.sociability + 0.2);
            this.shiny += 0.3;
            this.traits.push({ id: 'devoto', name: 'Devoto', element: E.RELIC });
          }
        }
      }
    }
    if (this.magneticBody) {
      for (const o of this.game.hash.query(this.x, this.y, 40)) {
        if (o === this || !o.alive || !o.conductive) continue;
        const d = Math.max(1, this.dist(o));
        o.x += (this.x - o.x) / d * 10 * dt;
        o.y += (this.y - o.y) / d * 10 * dt;
      }
    }
    // eletro atrai como a relíquia (choque aplicado ao pisar no tile)
    if (world.electrumTiles.size) {
      const e = this.nearestFieldTile(world.electrumTiles, 80);
      if (e) { this.x += (e.x - this.x) / e.d * 8 * dt; this.y += (e.y - this.y) / e.d * 8 * dt; }
    }
    // núcleo estelar: gravidade própria puxa TODAS as criaturas
    if (world.starcoreTiles.size) {
      const s = this.nearestFieldTile(world.starcoreTiles, 140);
      if (s) { this.x += (s.x - this.x) / s.d * 16 * dt; this.y += (s.y - this.y) / s.d * 16 * dt; }
    }
    // monólito: atração lenta e solene
    if (world.monolithTiles.size) {
      const m2 = this.nearestFieldTile(world.monolithTiles, 120);
      if (m2) { this.x += (m2.x - this.x) / m2.d * 6 * dt; this.y += (m2.y - this.y) / m2.d * 6 * dt; }
    }
    // éter: cura e flutuação transitória no raio
    if (world.etherTiles.size && this.nearestFieldTile(world.etherTiles, 60)) {
      this.inEther = true;
      this.hp = Math.min(this.stats.maxHp, this.hp + 4 * dt);
    }
    // aurora: cura suave e mutação benigna ocasional no raio
    if (world.auroraTiles.size && this.nearestFieldTile(world.auroraTiles, 80)) {
      this.hp = Math.min(this.stats.maxHp, this.hp + 3 * dt);
      if (this.rng.chance(0.01 * dt * 60)) this.gainRandomMutation(this.rng.pick([E.MOSS, E.PRISM, E.RELIC]));
    }
  }

  nearestFieldTile(tiles, radius) {
    const world = this.game.world;
    let bx = 0, by = 0, bd2 = radius * radius, found = false;
    for (const i of tiles) {
      const x = (i % world.w) * TILE + TILE / 2, y = ((i / world.w) | 0) * TILE + TILE / 2;
      const d2 = (x - this.x) ** 2 + (y - this.y) ** 2;
      if (d2 < bd2) { bd2 = d2; bx = x; by = y; found = true; }
    }
    return found ? { x: bx, y: by, d: Math.max(1, Math.sqrt(bd2)) } : null;
  }

  // Devoração — alvo: o depósito seguro mais próximo dentro do raio de busca.
  // Ignora o freio de temperamento, mas nunca manda os não-imunes para tiles
  // letais (plasma, lava, praga…); esses caem pela devoração de área.
  findExcess() {
    const world = this.game.world;
    const ctx = Math.floor(this.x / TILE), cty = Math.floor(this.y / TILE);
    const R = ENDGAME.PURGE_SEEK_R;
    let best = null, bd = Infinity;
    for (let dy = -R; dy <= R; dy++) {
      for (let dx = -R; dx <= R; dx++) {
        const x = ctx + dx, y = cty + dy;
        if (!world.inBounds(x, y)) continue;
        const d = world.dep[world.idx(x, y)];
        if (d === -1) continue;
        const hz = HAZARD_DEPOSITS[d];
        if (hz && !hz.imm.some(im => this.immunities.has(im))) continue;
        const dd = dx * dx + dy * dy;
        if (dd < bd) { bd = dd; best = { tx: x, ty: y, elem: d, mode: 'devour' }; }
      }
    }
    this.seekTile = best;
  }

  // Devoração de área: come o depósito mais próximo ao redor e, no auge
  // (nível 2), corrói uma construção vizinha para liberar o tile.
  consumeExcess(dt) {
    this.consumeCd -= dt;
    if (this.consumeCd > 0) return;
    const game = this.game, world = game.world, rng = this.rng;
    const ctx = Math.floor(this.x / TILE), cty = Math.floor(this.y / TILE);
    const R = ENDGAME.PURGE_CONSUME_R;
    let bi = -1, belem = -1, bd = Infinity, bx = 0, by = 0, building = null;
    for (let dy = -R; dy <= R; dy++) {
      for (let dx = -R; dx <= R; dx++) {
        const x = ctx + dx, y = cty + dy;
        if (!world.inBounds(x, y)) continue;
        const i = world.idx(x, y);
        const d = world.dep[i];
        if (d !== -1) {
          const dd = dx * dx + dy * dy;
          if (dd < bd) { bd = dd; bi = i; belem = d; bx = x; by = y; }
        } else if (game.purgeLevel >= 2 && !building) {
          const b = world.buildingAt.get(i);
          if (b && b.element !== E.MONOLITH) building = b;
        }
      }
    }
    if (bi >= 0) {
      this.consumeCd = rng.range(0.3, 0.6);
      world.clearDep(bi);
      this.devour(belem);
      game.sparkBurst(bx * TILE + TILE / 2, by * TILE + TILE / 2, elemColor(belem), 3);
      return;
    }
    if (game.purgeLevel >= 2 && building) {
      this.consumeCd = rng.range(0.3, 0.6);
      building.lastAttacker = this;
      building.hp -= ENDGAME.PURGE_BUILDING_DPS * this.consumeCd;
      game.hitSpark(building.x, building.y, this.dominantElem);
    }
  }

  // Recompensa da devoração: quase sempre só destrói (com um leve reparo),
  // e raramente absorve de verdade — evoluindo — para dar sabor ao evento.
  devour(elem) {
    const game = this.game;
    if (!HAZARD_DEPOSITS[elem] && this.rng.chance(0.05)) {
      absorbElement(this, elem, game);
      game.absorbPuff(this.x, this.y, elemColor(elem));
    } else if (this.hp < this.stats.maxHp) {
      this.hp = Math.min(this.stats.maxHp, this.hp + 0.5);
    }
  }

  // Mutação de um pool aleatório (cogumelo/esporos/praga/aurora): sem contar
  // absorção, sem feed global — só avisa se a criatura está aberta no inspetor.
  // `forcedPool` restringe a um pool específico (praga e aurora usam isso).
  gainRandomMutation(forcedPool) {
    const game = this.game, rng = this.rng;
    const poolKey = forcedPool !== undefined ? forcedPool : +rng.pick(Object.keys(game.mutationPools));
    const pool = game.mutationPools[poolKey] || [];
    const owned = new Set(this.traits.map(t => t.id));
    const options = pool.filter(m => !owned.has(m.id));
    if (options.length === 0) return;
    const mut = rng.pick(options);
    mut.apply(this);
    this.traits.push({ id: mut.id, name: mut.name, element: poolKey });
    this.refreshDominant();
    if (game.selected === this) game.feed(`🍄 ${this.name} mutou: ${mut.name}!`, '#c07ad0');
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
      // névoa esconde presas do predador (inclui o véu do Dom da Névoa)
      if ((o.inMist || o.mistVeil || o.giftVeil) && this.rng.chance(0.8)) continue;
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
    // (Dom do Monólito: constrói 2× mais rápido — precisa de metade da carga)
    let maxCarry = 0;
    for (const v of Object.values(this.carry)) if (v > maxCarry) maxCarry = v;
    const buildNeed = this.gifts.has(E.MONOLITH) ? Math.max(1, BUILD_THRESHOLD / 2) : BUILD_THRESHOLD;
    if (maxCarry >= buildNeed && this.state !== 'build') {
      this.pickBuildSpot();
      if (this.buildSpot) { this.state = 'build'; return; }
    }
    if (this.state === 'build' && this.buildSpot) return;
    if (this.state === 'raid' && this.raidTarget) return;

    // devoração ativa: todos caçam o excesso mais próximo, sem o freio de
    // temperamento (a fome coletiva ignora curiosidade/ganância)
    if (game.purgeLevel > 0 && !this.seekTile) {
      this.findExcess();
      if (this.seekTile) { this.state = 'seek'; return; }
    }

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
        // depósitos perigosos: só quem é imune (ou curioso demais) se aproxima
        const hz = HAZARD_DEPOSITS[d];
        if (hz && this.temperament.curiosity < hz.curio && !hz.imm.some(im => this.immunities.has(im))) continue;
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
    let collectDesire = this.temperament.industriousness * (0.6 + rng.next() * 0.8) + this.temperament.greed * (best.elem === E.GOLD ? 0.6 : 0);
    // monólito próximo: criaturas de facção têm o dobro de chance de iniciar construção
    if (this.faction && world.monolithTiles.size && this.nearestFieldTile(world.monolithTiles, 120)) collectDesire *= 2;
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
          const defMul = this.gifts.has(E.STEEL) ? 0.5 : 1; // Dom do Aço ignora metade da defesa
          const dmg = Math.max(1, this.attack + this.contactDamage - t.stats.defense * 0.55 * defMul);
          t.hurt(dmg, this, `em combate com ${this.name}`);
          game.hitSpark(t.x, t.y, this.dominantElem);
          if (this.gifts.size) this.applyAttackGifts(t);
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
        // destinos sem depósito (êxodo, tributo de vassalagem) usam elem -1
        if (!s.chest && s.elem !== -1 && world.dep[i] !== s.elem) { this.seekTile = null; this.state = 'wander'; break; }
        if (Math.hypot(px - this.x, py - this.y) < TILE * (s.chest ? 1 : 0.7)) {
          if (s.chest) {
            // tributo: despeja o ouro carregado no baú do suserano
            if (game.buildings.includes(s.chest) && (this.carry[E.GOLD] || 0) > 0) {
              s.chest.gold += this.carry[E.GOLD];
              this.carryTotal -= this.carry[E.GOLD];
              delete this.carry[E.GOLD];
            }
          } else if (s.elem !== -1) {
            world.clearDep(i);
            if (s.mode === 'devour') {
              this.devour(s.elem);
            } else if (s.mode === 'absorb') {
              absorbElement(this, s.elem, game);
              game.absorbPuff(this.x, this.y, elemColor(s.elem));
            } else {
              this.carry[s.elem] = (this.carry[s.elem] || 0) + 1;
              this.carryTotal++;
            }
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
        if (!r) { this.state = 'wander'; break; }
        // caçada (Fase A): o alvo é uma criatura gigante, não uma facção
        if (r.creature) {
          const t = r.creature;
          if (!t.alive) { this.raidTarget = null; this.state = 'wander'; break; }
          this.heading = Math.atan2(t.y - this.y, t.x - this.x);
          if (this.dist(t) < 40) this.engage(t);
          break;
        }
        if (!this.faction || !this.faction.isAtWar(r.faction)) { this.raidTarget = null; this.state = 'wander'; break; }
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
              // Dom da Corrosão: dano dobrado contra construções
              if (this.attackCd <= 0) { this.attackCd = 0.8; b.lastAttacker = this; b.hp -= this.attack * (this.gifts.has(E.RUST) ? 2 : 1); this.game.hitSpark(b.x, b.y, this.dominantElem); }
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
    let f = this.ignoreTerrain || this.floaty || this.inEther ? 1 : world.moveFactorAtPx(this.x, this.y);
    if (this.aquatic && world.terrainAtPx(this.x, this.y) === T.WATER) f = Math.max(f, 1.05);
    // dons de movimento: imunidades a lentidão e bônus por tile
    if (this.gifts.size) {
      if (this.gifts.has(E.WATER) && world.terrainAtPx(this.x, this.y) === T.WATER) f = Math.max(f, 1.6); // Dom da Correnteza
      const mtx = Math.floor(this.x / TILE), mty = Math.floor(this.y / TILE);
      const md = world.inBounds(mtx, mty) ? world.dep[world.idx(mtx, mty)] : -1;
      if (md !== -1 && !(this.ignoreTerrain || this.floaty || this.inEther)) {
        if (this.gifts.has(E.SLIME) && md === E.SLIME) f /= 0.75;             // Dom da Gosma
        if (this.gifts.has(E.MUD) && md === E.MUD) f /= 0.5;                  // Dom do Lodo
        if (this.gifts.has(E.MUD) && md === E.SWAMP) f /= 0.55;
        if (this.gifts.has(E.SNOW)) {                                          // Dom da Neve
          if (md === E.SNOW) f /= 0.85;
          if (md === E.SNOW || md === E.ICE || md === E.GLACIER) f *= 1.15;
        }
      }
    }
    let sp = this.stats.speed * f;
    if (this.vehicle) sp *= this.vehicle.speedMul;
    if (this.dashTime > 0) sp *= this.dashType === 'electric' ? 2.6 : 1.9;
    if (this.state === 'fight' && this.target && this.target.slowAura) sp *= 0.7;
    if (this.chillTimer > 0) sp *= 0.7;
    if ((this.giftTimers.smoke || 0) > 22) sp *= 1.4; // fuga fumegante (Dom da Fumaça)
    if (this.frozenTimer > 0) sp = 0;
    this.x += Math.cos(this.heading) * sp * dt;
    this.y += Math.sin(this.heading) * sp * dt;
    const m = 8, W = world.w * TILE, H = world.h * TILE;
    if (this.x < m) { this.x = m; this.heading = Math.PI - this.heading; }
    if (this.x > W - m) { this.x = W - m; this.heading = Math.PI - this.heading; }
    if (this.y < m) { this.y = m; this.heading = -this.heading; }
    if (this.y > H - m) { this.y = H - m; this.heading = -this.heading; }
    this.animPhase += sp * dt * 0.12;
    this.speedNow = sp;
    // tempo parado (dons da Semente/Névoa/Musgo)
    if (sp < 5) this.stillTime += dt; else this.stillTime = 0;
  }

  emitTraitParticles(dt) {
    const game = this.game;
    for (const p of this.bodyPlan.particles) {
      if (game.fxRng.chance(dt * 2.2)) game.traitParticle(this, p);
    }
  }

  // Dons ofensivos (hook atk): efeitos extras ao acertar um golpe corpo-a-corpo.
  applyAttackGifts(t) {
    const game = this.game, world = game.world, rng = this.rng, gifts = this.gifts;
    if (t.alive) {
      if (gifts.has(E.FIRE)) t.dots.push({ dps: 2, t: 2, src: `queimado pela chama de ${this.name}` });
      if (gifts.has(E.POISON)) t.dots.push({ dps: 1, t: 3, src: `envenenado por ${this.name}` });
      if (gifts.has(E.ACID)) t.dots.push({ dps: 2, t: 2, src: `corroído por ${this.name}`, ignoreDefense: true });
      if (gifts.has(E.PLAGUE)) t.dots.push({ dps: 1, t: 5, src: `infectado pela praga de ${this.name}`, hops: 1 });
      if (gifts.has(E.ICE)) t.chillTimer = 2;
      if (gifts.has(E.BLIZZARD) && rng.chance(0.3)) t.frozenTimer = 1;
      if (gifts.has(E.RUST) && t.bodyPlan.plates >= 1 && !t.plateStripped) { t.plateStripped = true; t.bodyPlan.plates -= 1; }
    }
    if (gifts.has(E.LAVA) && rng.chance(0.3)) {
      const ltx = Math.floor(t.x / TILE), lty = Math.floor(t.y / TILE);
      if (world.inBounds(ltx, lty)) {
        const li = world.idx(ltx, lty);
        if (!world.buildingAt.has(li)) world.setDep(li, E.LAVA, 3);
      }
    }
    // Dom do Plasma: a cada 15s o próximo golpe estoura +8 em área
    if (gifts.has(E.PLASMA) && (this.giftTimers.plasma || 0) <= 0) {
      this.giftTimers.plasma = 15;
      game.sparkBurst(t.x, t.y, '#ff4ae0', 6);
      for (const o of game.hash.query(t.x, t.y, 30)) {
        if (o !== this && o.alive && (!this.faction || o.faction !== this.faction)) o.hurt(8, null, `pelo plasma de ${this.name}`);
      }
    }
    // Dom da Pólvora: explosão ocasional no alvo (poupa a própria facção)
    if (gifts.has(E.GUNPOWDER) && rng.chance(0.15)) {
      game.sparkBurst(t.x, t.y, '#ffb36a', 8);
      for (const o of game.hash.query(t.x, t.y, 25)) {
        if (o !== this && o.alive && (!this.faction || o.faction !== this.faction)) o.hurt(10, null, `pela pólvora de ${this.name}`);
      }
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
    if (this.sporeParent) child.gainRandomMutation(); // esporos: trait extra no filhote
    game.feed(`🐣 ${child.name} (${child.archetype.name}) nasceu de ${this.name}${mate ? ' e ' + mate.name : ''}`, '#8fd18f');
  }

  hurt(dmg, attacker, cause) {
    if (!this.alive) return;
    if (this.gifts.size) {
      // Dom Etéreo: o 1º tick de dano de depósito ativa fase imune de 3s (cooldown 20s)
      if (this.depositDamageTick && this.gifts.has(E.ETHER)) {
        const et = this.giftTimers.ether || 0;
        if (et > 17) return; // fase etérea ativa
        if (et <= 0) { this.giftTimers.ether = 20; this.game.absorbPuff(this.x, this.y, '#d8ccff'); return; }
      }
      if (attacker) {
        // Dom do Mercúrio: esquiva total ocasional
        if (this.gifts.has(E.MERCURY) && this.rng.chance(0.25)) return;
        // Dom Adamantino: anula 1 golpe a cada 30s (flash branco)
        if (this.gifts.has(E.DIAMOND) && (this.giftTimers.diamond || 0) <= 0) {
          this.giftTimers.diamond = 30;
          this.game.sparkBurst(this.x, this.y, '#ffffff', 8);
          return;
        }
        if (this.gifts.has(E.STONE)) dmg *= 0.85; // Dom da Rocha
        if (this.gifts.has(E.LIGHTNING) && this.rng.chance(0.3)) attacker.hurt(5, null, `pela descarga de ${this.name}`);
        if (this.gifts.has(E.METAL)) attacker.hurt(1, null, `pelo ferro de ${this.name}`);
        // Dom Magnético: repele agressores condutores
        if (this.gifts.has(E.MAGNET) && attacker.conductive && attacker.alive) {
          const d = Math.max(1, this.dist(attacker));
          attacker.x += (attacker.x - this.x) / d * 20;
          attacker.y += (attacker.y - this.y) / d * 20;
          attacker.hurt(2, null, `pelo campo magnético de ${this.name}`);
        }
        if (this.gifts.has(E.SWAMP) && attacker.alive) attacker.dots.push({ dps: 1, t: 2, src: `pelo lodo de ${this.name}` });
        // Dom do Vapor: solta vapor ao ser golpeada
        if (this.gifts.has(E.VAPOR) && this.rng.chance(0.25)) {
          const world = this.game.world;
          const vtx = Math.floor(this.x / TILE), vty = Math.floor(this.y / TILE);
          if (world.inBounds(vtx, vty)) {
            const vi = world.idx(vtx, vty);
            if (world.dep[vi] === -1 && !world.buildingAt.has(vi)) world.setDep(vi, E.VAPOR, 5);
          }
        }
      }
    }
    // efeito único: PEDRA — abrigo: pedra adjacente à vítima amortece dano de combate
    if (attacker) {
      const world = this.game.world;
      const stx = Math.floor(this.x / TILE), sty = Math.floor(this.y / TILE);
      outer: for (let dy = -1; dy <= 1; dy++) {
        for (let dx = -1; dx <= 1; dx++) {
          if (!dx && !dy) continue;
          const nx = stx + dx, ny = sty + dy;
          if (!world.inBounds(nx, ny)) continue;
          if (world.dep[world.idx(nx, ny)] === E.STONE) { dmg *= 0.92; break outer; }
        }
      }
    }
    // contágio da praga: quem toca o infectado herda o dot (1 salto)
    if (attacker && this.dots.length) {
      for (const dot of this.dots) {
        if (dot.hops > 0) { dot.hops = 0; attacker.dots.push({ dps: dot.dps, t: dot.t, src: dot.src }); break; }
      }
    }
    this.hp -= dmg;
    // sangue corrosivo respinga no agressor (attacker=null evita recursão)
    if (this.acidBlood && attacker && dmg > 1) attacker.hurt(2, null, 'por sangue corrosivo');
    if (this.hp <= 0) this.game.kill(this, cause || 'em combate', attacker);
    else if (attacker && this.state !== 'fight' && this.state !== 'flee') {
      if (this.temperament.aggression > 0.35 || this.attack >= attacker.attack) this.engage(attacker);
      else { this.fleeFrom = attacker; this.fleeTimer = 3; this.state = 'flee'; }
    }
  }

  dist(o) { return Math.hypot(o.x - this.x, o.y - this.y); }
}


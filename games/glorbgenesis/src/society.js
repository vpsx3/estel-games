// Relações entre criaturas: encontros, facções, guerra e aliança.

import { factionName } from './names.js';
import { E, ENDGAME } from './elements.js';
import { TILE, T } from './world.js';
let nextFid = 1;

// Cap de membros por facção cresce com a era do mundo.
export function factionCap(game) { return ENDGAME.FACTION_CAP_BY_ERA[game.era] || 40; }

// ---------------------------------------------------------------------------
// Eras: o arco macro do mundo. Progridem por conquistas dos glorbs e NUNCA
// regridem. A Fase C acrescentará a Era Ancestral (Ascensão).
// ---------------------------------------------------------------------------
export const ERAS = [
  { id: 0, name: 'Era Primordial',  short: 'Primordial', icon: '🌱' },
  { id: 1, name: 'Era Tribal',      short: 'Tribal',     icon: '🏕️' },
  { id: 2, name: 'Era das Guerras', short: 'Guerras',    icon: '⚔️' },
  { id: 3, name: 'Era dos Reinos',  short: 'Reinos',     icon: '👑' },
];

function checkEraProgress(game) {
  if (game.era === 0 && game.factions.some(f => f.members.length >= ENDGAME.ERA_TRIBAL_MEMBERS)) {
    advanceEra(game, 1);
  } else if (game.era === 1 && (game.wars.length > 0 || game.factions.some(f => {
    for (const [, rel] of f.relations) if (rel.state === 'war') return true;
    return false;
  }))) {
    advanceEra(game, 2);
  } else if (game.era === 2 && game.factions.some(f => f.buildings.length >= ENDGAME.ERA_KINGDOMS_BUILDINGS)) {
    advanceEra(game, 3);
  }
}

function advanceEra(game, era) {
  game.era = era;
  const e = ERAS[era];
  game.addShake(3);
  game.feed(`${e.icon} O mundo entrou na ${e.name}!`, '#ffd75a');
  game.announceEra(e);
}

export class Faction {
  constructor(game, founderA, founderB) {
    this.id = nextFid++;
    this.game = game;
    this.name = factionName(game.societyRng, game.usedFactionNames);
    this.hue = game.societyRng.int(0, 360);
    this.color = `hsl(${this.hue},70%,60%)`;
    this.members = [];
    this.buildings = [];
    this.tributeTo = null; // id da facção suserana (vassalagem, Fase A)
    this.relations = new Map(); // factionId -> { state: 'neutral'|'war'|'ally', heat: number }
    this.addMember(founderA);
    if (founderB) this.addMember(founderB);
  }

  addMember(c) {
    if (c.faction === this) return;
    if (c.faction) c.faction.removeMember(c);
    c.faction = this;
    this.members.push(c);
  }

  removeMember(c) {
    const i = this.members.indexOf(c);
    if (i >= 0) this.members.splice(i, 1);
    if (c.faction === this) c.faction = null;
  }

  relationWith(other) {
    let r = this.relations.get(other.id);
    if (!r) { r = { state: 'neutral', heat: 0 }; this.relations.set(other.id, r); }
    return r;
  }

  isAtWar(other) {
    if (!other || other === this) return false;
    return this.relationWith(other).state === 'war';
  }

  center() {
    let sx = 0, sy = 0, n = 0;
    for (const b of this.buildings) { sx += b.x; sy += b.y; n++; }
    if (n === 0) {
      for (const m of this.members) { sx += m.x; sy += m.y; n++; }
    }
    return n ? { x: sx / n, y: sy / n } : { x: 0, y: 0 };
  }

  nearestBuilding(x, y) {
    let best = null, bd = Infinity;
    for (const b of this.buildings) {
      const d = (b.x - x) ** 2 + (b.y - y) ** 2;
      if (d < bd) { bd = d; best = b; }
    }
    return best;
  }

  avgTemperament(key) {
    if (this.members.length === 0) return 0.5;
    let s = 0;
    for (const m of this.members) s += m.temperament[key];
    return s / this.members.length;
  }
}

function similarity(a, b) {
  let dh = Math.abs(a.bodyPlan.hue - b.bodyPlan.hue);
  if (dh > 180) dh = 360 - dh;
  let shared = 0;
  for (const t of a.traits) if (b.traits.some(o => o.id === t.id)) shared++;
  return (1 - dh / 180) * 0.6 + Math.min(1, shared / 3) * 0.4;
}

// Encontro entre duas criaturas: aliança, neutro ou hostilidade.
export function tryEncounter(game, a, b) {
  const rng = game.societyRng;
  a.encounterCd = rng.range(9, 18);
  b.encounterCd = rng.range(9, 18);

  const sim = similarity(a, b);
  // disputa por ouro: dois gananciosos atrás do mesmo tesouro se estranham
  const wantsGold = c => (c.carry[E.GOLD] || 0) > 0 || (c.seekTile && c.seekTile.elem === E.GOLD);
  const goldTension = (wantsGold(a) && wantsGold(b))
    ? 0.3 * (a.temperament.greed + b.temperament.greed) / 2 : 0;
  // Dom da Relíquia: acalma a agressão efetiva de quem encara a portadora
  const aggrA = a.temperament.aggression - (b.gifts.has(E.RELIC) ? 0.3 : 0);
  const aggrB = b.temperament.aggression - (a.gifts.has(E.RELIC) ? 0.3 : 0);
  const hostScore =
    (aggrA + aggrB) / 2 +
    (a.scary + b.scary) * 0.35 +
    (a.shiny * b.temperament.greed + b.shiny * a.temperament.greed) * 0.5 + // ouro atiça ganância
    goldTension -
    sim * 0.25;
  const allyScore =
    (a.temperament.sociability + b.temperament.sociability) / 2 +
    sim * 0.4 -
    (a.scary + b.scary) * 0.4;

  const r = rng.next();
  if (hostScore > 0.56 + r * 0.3) {
    a.engage(b);
    if (game.envRng.chance(0.5)) game.feed(`⚔️ ${a.name} atacou ${b.name}!`, '#ff7a6a');
    return 'hostile';
  }
  if (allyScore > 0.46 + r * 0.28) {
    if (a.faction && b.faction && a.faction !== b.faction) {
      // duas facções se aproximam
      const ra = a.faction.relationWith(b.faction);
      const rb = b.faction.relationWith(a.faction);
      if (ra.state === 'neutral') { ra.heat -= 0.4; rb.heat -= 0.4; }
    } else if (a.faction || b.faction) {
      const f = a.faction || b.faction;
      const joiner = a.faction ? b : a;
      if (f.members.length < factionCap(game)) {
        f.addMember(joiner);
        game.feed(`🤝 ${joiner.name} juntou-se à facção ${f.name}`, f.color);
      }
    } else if (rng.chance(0.55)) {
      const f = new Faction(game, a, b);
      game.factions.push(f);
      game.feed(`🏳️ ${a.name} e ${b.name} fundaram a facção ${f.name}!`, f.color);
    }
    return 'ally';
  }
  return 'neutral';
}

// Tick da sociedade (~a cada 8s): relações entre facções derivam com o tempo.
export function societyTick(game) {
  const rng = game.societyRng;
  checkEraProgress(game);
  // facções extintas (sem membros e sem construções) saem do registro,
  // e as relações que apontam para elas são esquecidas — sem isso ambos
  // crescem sem limite em sessões longas.
  const liveIds = new Set();
  game.factions = game.factions.filter(f => {
    if (f.members.length === 0 && f.buildings.length === 0) return false;
    liveIds.add(f.id);
    return true;
  });
  for (const f of game.factions) {
    for (const id of f.relations.keys()) if (!liveIds.has(id)) f.relations.delete(id);
    if (f.tributeTo !== null && !liveIds.has(f.tributeTo)) f.tributeTo = null;
  }
  // guerras órfãs saem do registro: facção extinta ou reduzida a < 2 membros
  // não briga mais — sem isso o registro cresce sem limite em sessões longas
  // (a relação, se esfriar depois, resolve como paz branca sem placar).
  game.wars = game.wars.filter(w => {
    const a = game.factions.find(f => f.id === w.aId);
    const b = game.factions.find(f => f.id === w.bId);
    return a && b && a.members.length >= 2 && b.members.length >= 2;
  });
  const fs = game.factions.filter(f => f.members.length >= 2);
  for (let i = 0; i < fs.length; i++) {
    for (let j = i + 1; j < fs.length; j++) {
      const A = fs[i], B = fs[j];
      const rA = A.relationWith(B);
      const rb = B.relationWith(A);
      const aggr = (A.avgTemperament('aggression') + B.avgTemperament('aggression')) / 2;
      const soc = (A.avgTemperament('sociability') + B.avgTemperament('sociability')) / 2;
      const greed = (A.avgTemperament('greed') + B.avgTemperament('greed')) / 2;
      rA.heat += (aggr * 0.6 + greed * 0.3 - soc * 0.5) * rng.range(0.2, 0.7) + rng.range(-0.18, 0.22);
      rA.heat *= 0.97;
      rA.heat = Math.max(-2, Math.min(2, rA.heat));
      rb.heat = rA.heat; // relação simétrica

      const bothEstablished = A.members.length >= 3 && B.members.length >= 3;
      const alreadyAtWar = f => {
        for (const [, rel] of f.relations) if (rel.state === 'war') return true;
        return false;
      };
      if (rA.state !== 'war' && rA.heat > 0.8 && bothEstablished &&
          !((alreadyAtWar(A) || alreadyAtWar(B)) && rng.chance(0.7))) {
        rA.state = rb.state = 'war';
        rA.heat = rb.heat = 2; // guerra dura um tempo até esfriar
        // nova guerra abre placar (se ainda não houver) e quebra vassalagens entre os dois
        if (!findWar(game, A.id, B.id)) {
          game.wars.push({ aId: A.id, bId: B.id, score: { [A.id]: 0, [B.id]: 0 }, t0: game.time });
        }
        if (A.tributeTo === B.id) A.tributeTo = null;
        if (B.tributeTo === A.id) B.tributeTo = null;
        game.feed(`🔥 A facção ${A.name} declarou guerra à facção ${B.name}!`, '#ff5a4a');
      } else if (rA.state !== 'ally' && rA.heat < -0.8) {
        rA.state = rb.state = 'ally';
        game.feed(`🕊️ As facções ${A.name} e ${B.name} formaram uma aliança`, '#8fd1ff');
      } else if (rA.state === 'war' && rA.heat < 0.25) {
        resolveWar(game, A, B);
      }

      // guerra: designa raides
      if (rA.state === 'war') {
        assignRaiders(game, A, B, rng);
        assignRaiders(game, B, A, rng);
      }
    }
  }

  // Caçadas (Fase A): facções agressivas saem atrás de gigantes (Colosso+)
  // que não sejam dos seus. Caçar gigante de outra facção esquenta a relação.
  for (const f of fs) {
    if (f.avgTemperament('aggression') <= ENDGAME.HUNT_AGGR) continue;
    let target = null, td = Infinity;
    const c = f.center();
    for (const o of game.creatures) {
      if (!o.alive || o.giantTier < ENDGAME.HUNT_MIN_TIER || o.faction === f) continue;
      const d = (o.x - c.x) ** 2 + (o.y - c.y) ** 2;
      if (d < td) { td = d; target = o; }
    }
    if (!target || !rng.chance(0.3)) continue;
    if (f.members.some(m => m.raidTarget && m.raidTarget.creature === target)) continue; // caçada já em curso
    let started = false;
    for (const m of f.members) {
      if (m.alive && m.temperament.aggression > 0.5 && m.state !== 'fight') {
        m.raidTarget = { creature: target };
        m.state = 'raid';
        started = true;
      }
    }
    if (started) {
      game.feed(`🏹 A facção ${f.name} saiu à caça de ${target.name}!`, f.color);
      if (target.faction) {
        const r1 = f.relationWith(target.faction), r2 = target.faction.relationWith(f);
        r1.heat += 0.3;
        r2.heat = r1.heat;
      }
    }
  }

  // vassalagem: facção tributária envia 1 carregador de ouro ao baú do suserano
  for (const f of game.factions) {
    if (!f.tributeTo) continue;
    const lord = game.factions.find(o => o.id === f.tributeTo);
    if (!lord) { f.tributeTo = null; continue; }
    let chest = null, cd = Infinity;
    const c = f.center();
    for (const b of lord.buildings) {
      if (b.type !== 'chest') continue;
      const d = (b.x - c.x) ** 2 + (b.y - c.y) ** 2;
      if (d < cd) { cd = d; chest = b; }
    }
    if (!chest) continue;
    const carriers = f.members.filter(m =>
      m.alive && (m.carry[E.GOLD] || 0) > 0 && m.state !== 'fight' && m.state !== 'flee');
    if (carriers.length) {
      const m = rng.pick(carriers);
      m.seekTile = { tx: chest.tx, ty: chest.ty, elem: -1, mode: 'collect', chest };
      m.state = 'seek';
    }
  }
}

function assignRaiders(game, from, to, rng) {
  if (to.members.length === 0 && to.buildings.length === 0) return;
  for (const m of from.members) {
    if (m.alive && m.temperament.aggression > 0.45 && m.state !== 'fight' && rng.chance(0.4)) {
      m.raidTarget = { faction: to };
      m.state = 'raid';
    }
  }
}

// ---------------------------------------------------------------------------
// Guerras com desfecho (Fase A): cada guerra tem um placar (abates e
// construções derrubadas); quando o calor esfria, o placar decide a cicatriz.
// ---------------------------------------------------------------------------
function findWar(game, idA, idB) {
  return game.wars.find(w => (w.aId === idA && w.bId === idB) || (w.aId === idB && w.bId === idA));
}

// Soma pontos para a facção `from` na guerra contra `against` (se houver).
export function recordWarScore(game, from, against, pts) {
  if (!from || !against || from === against) return;
  const w = findWar(game, from.id, against.id);
  if (w) w.score[from.id] = (w.score[from.id] || 0) + pts;
}

function resolveWar(game, A, B) {
  const rng = game.societyRng;
  const rA = A.relationWith(B), rB = B.relationWith(A);
  rA.state = rB.state = 'neutral';
  rA.heat = rB.heat = -0.5; // rancor esquecido: demora para nova guerra
  const wi = game.wars.findIndex(w => (w.aId === A.id && w.bId === B.id) || (w.aId === B.id && w.bId === A.id));
  const war = wi >= 0 ? game.wars.splice(wi, 1)[0] : null;
  const diff = war ? (war.score[A.id] || 0) - (war.score[B.id] || 0) : 0;

  // placar equilibrado (ou guerra sem registro): paz branca, sem cicatriz
  if (!war || Math.abs(diff) <= ENDGAME.WAR_DRAW_MARGIN) {
    game.feed(`🏳️ Paz entre ${A.name} e ${B.name}`, '#cfcfcf');
    return;
  }
  const winner = diff > 0 ? A : B;
  const loser = diff > 0 ? B : A;
  const aggr = winner.avgTemperament('aggression');
  const opts = [
    { w: 1 + aggr * 1.5, kind: 'conquista' },
    { w: 1 + (1 - aggr), kind: 'exodo' },
  ];
  if (game.era >= 3) opts.push({ w: winner.avgTemperament('greed') * 1.5, kind: 'vassalagem' });
  const kind = rng.weighted(opts).kind;

  if (kind === 'conquista') {
    // construções e parte dos membros mudam de dono; a facção perdedora acaba
    for (const b of loser.buildings) { b.faction = winner; winner.buildings.push(b); }
    loser.buildings.length = 0;
    for (const m of loser.members.slice()) {
      if (winner.members.length < factionCap(game) && rng.chance(0.6)) winner.addMember(m);
      else loser.removeMember(m);
    }
    const fi = game.factions.indexOf(loser);
    if (fi >= 0) game.factions.splice(fi, 1);
    game.territoryDirty = true;
    game.addShake(3);
    game.feed(`👑 ${winner.name} conquistou ${loser.name}!`, winner.color);
  } else if (kind === 'exodo') {
    // construções ficam como ruínas neutras; a facção parte em caravana
    for (const b of loser.buildings) b.faction = null;
    loser.buildings.length = 0;
    const c = loser.center();
    const ctx0 = Math.floor(c.x / TILE), cty0 = Math.floor(c.y / TILE);
    let dest = null;
    for (let i = 0; i < 50 && !dest; i++) {
      const tx = game.envRng.int(4, game.world.w - 5), ty = game.envRng.int(4, game.world.h - 5);
      if (Math.hypot(tx - ctx0, ty - cty0) >= ENDGAME.EXODUS_DIST &&
          game.world.terrain[game.world.idx(tx, ty)] !== T.WATER) dest = { tx, ty };
    }
    if (dest) {
      for (const m of loser.members) {
        if (!m.alive) continue;
        m.seekTile = { tx: dest.tx, ty: dest.ty, elem: -1, mode: 'collect' };
        m.state = 'seek';
      }
    }
    game.territoryDirty = true;
    game.feed(`🏜️ A facção ${loser.name} partiu em êxodo...`, loser.color);
  } else {
    // vassalagem: perdedor mantém tudo, mas paga tributo em ouro ao suserano
    loser.tributeTo = winner.id;
    game.feed(`⛓️ ${loser.name} agora paga tributo a ${winner.name}`, winner.color);
  }
}


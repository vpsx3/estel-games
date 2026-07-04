// Relações entre criaturas: encontros, facções, guerra e aliança.

import { factionName } from './names.js';
import { E } from './elements.js';

let nextFid = 1;

export class Faction {
  constructor(game, founderA, founderB) {
    this.id = nextFid++;
    this.game = game;
    this.name = factionName(game.societyRng, game.usedFactionNames);
    this.hue = game.societyRng.int(0, 360);
    this.color = `hsl(${this.hue},70%,60%)`;
    this.members = [];
    this.buildings = [];
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
  const hostScore =
    (a.temperament.aggression + b.temperament.aggression) / 2 +
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
      if (f.members.length < 24) {
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
        game.feed(`🔥 A facção ${A.name} declarou guerra à facção ${B.name}!`, '#ff5a4a');
      } else if (rA.state !== 'ally' && rA.heat < -0.8) {
        rA.state = rb.state = 'ally';
        game.feed(`🕊️ As facções ${A.name} e ${B.name} formaram uma aliança`, '#8fd1ff');
      } else if (rA.state === 'war' && rA.heat < 0.25) {
        rA.state = rb.state = 'neutral';
        rA.heat = rb.heat = -0.5; // rancor esquecido: demora para nova guerra
        game.feed(`🏳️ Paz entre ${A.name} e ${B.name}`, '#cfcfcf');
      }

      // guerra: designa raides
      if (rA.state === 'war') {
        assignRaiders(game, A, B, rng);
        assignRaiders(game, B, A, rng);
      }
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

// Grid do mundo, terreno procedural (value noise feito à mão),
// depósitos de elementos no chão e o tick ambiental de reações.

import { E, REACT, FUSE, CONDUCTIVE, FLAMMABLE } from './elements.js';
import { RNG } from './rng.js';

// Vida inicial de depósitos criados por fusão (0 = permanente/passivo).
export function fuseLife(elem, rng) {
  if (elem === E.LAVA) return rng.range(12, 18);
  if (elem === E.PLASMA) return rng.range(2, 3);
  if (elem === E.SMOKE) return rng.range(6, 9);
  if (elem === E.MIST) return rng.range(20, 30);
  if (elem === E.STORM) return rng.range(15, 20);
  if (elem === E.ACID) return rng.range(10, 15);
  if (elem === E.MIASMA) return 25;
  if (elem === E.VAPOR) return rng.range(8, 12);
  if (elem === E.BLIZZARD) return rng.range(15, 22);
  if (elem === E.AURORA) return rng.range(20, 30);
  if (elem === E.PLAGUE) return 18;
  if (elem === E.STARCORE) return 10;
  if (elem === E.ETHER) return 25;
  return 0;
}

// Elementos com comportamento ambiental próprio: entram em `active` ao despejar.
const ACTIVE_ELEMS = new Set([
  E.FIRE, E.AIR, E.WATER, E.POISON, E.ICE,
  E.LAVA, E.PLASMA, E.SMOKE, E.MIST, E.STORM, E.ACID, E.RUST, E.MIASMA, E.SNOW, E.FUNGUS, E.MUD,
  E.VAPOR, E.BLIZZARD, E.ASH, E.MERCURY, E.PLAGUE, E.AURORA, E.STARCORE, E.ETHER,
  E.WOOD, // floresta viva: acorda brevemente ao ser criado (remoção rápida)
]);
// Elementos com vida limitada: depLife conta até expirar.
const TIMED = new Set([
  E.FIRE, E.AIR, E.LAVA, E.PLASMA, E.SMOKE, E.MIST, E.STORM, E.ACID, E.MIASMA,
  E.VAPOR, E.BLIZZARD, E.PLAGUE, E.AURORA, E.STARCORE, E.ETHER,
]);
export const WORLD_W = 192;
export const WORLD_H = 192;
export const TILE = 16;

export const T = { PLAIN: 0, ROCKY: 1, WATER: 2, DESERT: 3 };
export const TERRAIN_SPEED = [1.0, 0.72, 0.45, 0.88];

// --- value noise à mão -------------------------------------------------
function makeNoise(rng, size) {
  const g = new Float32Array(size * size);
  for (let i = 0; i < g.length; i++) g[i] = rng.next();
  const at = (x, y) => g[((y % size + size) % size) * size + ((x % size + size) % size)];
  return function noise(x, y) {
    const x0 = Math.floor(x), y0 = Math.floor(y);
    const fx = x - x0, fy = y - y0;
    const sx = fx * fx * (3 - 2 * fx), sy = fy * fy * (3 - 2 * fy);
    const a = at(x0, y0), b = at(x0 + 1, y0), c = at(x0, y0 + 1), d = at(x0 + 1, y0 + 1);
    return a + (b - a) * sx + (c - a) * sy + (a - b - c + d) * sx * sy;
  };
}

export class World {
  constructor(seed) {
    this.seed = seed;
    this.w = WORLD_W;
    this.h = WORLD_H;
    const rng = new RNG(seed ^ 0x9e3779b9);

    this.terrain = new Uint8Array(this.w * this.h);
    this.shade = new Float32Array(this.w * this.h); // variação cosmética
    this.dep = new Int16Array(this.w * this.h).fill(-1); // elemento no chão (-1 = nada)
    this.depLife = new Float32Array(this.w * this.h);   // vida de fogo/ar
    this.active = new Set();      // tiles com comportamento ambiental pendente
    this.buildingAt = new Map();  // idx -> Building
    this.magnetTiles = new Set(); // tiles com ímã (campo de atração)
    this.relicTiles = new Set();  // tiles com relíquia
    this.electrumTiles = new Set();  // tiles com eletro (atração + choque)
    this.auroraTiles = new Set();    // tiles com aurora (cura + mutação)
    this.starcoreTiles = new Set();  // tiles com núcleo estelar (atração + dano)
    this.etherTiles = new Set();     // tiles com éter (cura + flutuação)
    this.monolithTiles = new Set();  // tiles com monólito (atração + construção)

    const hNoise = makeNoise(rng.fork(), 64);
    const mNoise = makeNoise(rng.fork(), 64);
    const detail = rng.fork();
    for (let y = 0; y < this.h; y++) {
      for (let x = 0; x < this.w; x++) {
        const i = y * this.w + x;
        const hgt = 0.65 * hNoise(x / 24, y / 24) + 0.35 * hNoise(x / 7 + 100, y / 7 + 100);
        const moist = mNoise(x / 30 + 50, y / 30 + 50);
        let t = T.PLAIN;
        if (hgt < 0.36) t = T.WATER;
        else if (hgt > 0.68) t = T.ROCKY;
        else if (moist < 0.34) t = T.DESERT;
        this.terrain[i] = t;
        this.shade[i] = detail.range(-0.05, 0.05);
      }
    }
  }

  idx(tx, ty) { return ty * this.w + tx; }
  inBounds(tx, ty) { return tx >= 0 && ty >= 0 && tx < this.w && ty < this.h; }
  terrainAtPx(x, y) {
    const tx = Math.floor(x / TILE), ty = Math.floor(y / TILE);
    if (!this.inBounds(tx, ty)) return T.ROCKY;
    return this.terrain[this.idx(tx, ty)];
  }
  moveFactorAtPx(x, y) {
    const tx = Math.floor(x / TILE), ty = Math.floor(y / TILE);
    if (!this.inBounds(tx, ty)) return 0.4;
    const i = this.idx(tx, ty);
    let f = TERRAIN_SPEED[this.terrain[i]];
    const b = this.buildingAt.get(i);
    if (b && (b.type === 'bridge' || b.type === 'floor')) f = Math.max(f, 1);
    const d = this.dep[i];
    if (d === E.ICE) f *= 1.3;        // escorregadio
    else if (d === E.SLIME) f *= 0.75; // pegajoso
    else if (d === E.MUD) f *= 0.5;
    else if (d === E.SNOW) f *= 0.85;
    else if (d === E.GLACIER) f *= 1.35;
    else if (d === E.LAVA) f *= 0.6;
    else if (d === E.SWAMP) f *= 0.55;
    else if (d === E.MERCURY) f *= 0.8;
    else if (d === E.ASH) f *= 0.9;
    else if (d === E.BLIZZARD) f *= 0.6;
    return f;
  }

  setDep(i, elem, life) {
    this.dep[i] = elem;
    this.depLife[i] = life !== undefined ? life : 0;
    this.magnetTiles.delete(i); this.relicTiles.delete(i); this.electrumTiles.delete(i);
    this.auroraTiles.delete(i); this.starcoreTiles.delete(i); this.etherTiles.delete(i); this.monolithTiles.delete(i);
    if (elem === E.MAGNET) this.magnetTiles.add(i);
    else if (elem === E.RELIC) this.relicTiles.add(i);
    else if (elem === E.ELECTRUM) this.electrumTiles.add(i);
    else if (elem === E.AURORA) this.auroraTiles.add(i);
    else if (elem === E.STARCORE) this.starcoreTiles.add(i);
    else if (elem === E.ETHER) this.etherTiles.add(i);
    else if (elem === E.MONOLITH) this.monolithTiles.add(i);
    if (ACTIVE_ELEMS.has(elem)) {
      this.active.add(i);
    } else if (FUSE[elem]) {
      // elemento passivo com par de fusão adjacente: acorda para poder fundir
      const x = i % this.w, y = (i / this.w) | 0;
      outer: for (let dy = -1; dy <= 1; dy++) {
        for (let dx = -1; dx <= 1; dx++) {
          if (!dx && !dy) continue;
          const nx = x + dx, ny = y + dy;
          if (!this.inBounds(nx, ny)) continue;
          const nd = this.dep[this.idx(nx, ny)];
          if (nd !== -1 && FUSE[elem][nd] !== undefined) { this.active.add(i); break outer; }
        }
      }
    }
  }
  clearDep(i) {
    this.dep[i] = -1;
    this.active.delete(i);
    this.magnetTiles.delete(i);
    this.relicTiles.delete(i);
    this.electrumTiles.delete(i);
    this.auroraTiles.delete(i);
    this.starcoreTiles.delete(i);
    this.etherTiles.delete(i);
    this.monolithTiles.delete(i);
  }

  // Despeja `elem` num raio de tiles ao redor de (tx,ty). Raio especial: raio-relâmpago.
  pour(elem, tx, ty, radius, rng, game) {
    if (elem === E.LIGHTNING) {
      this.lightningStrike(tx, ty, rng, game, 10);
      return;
    }
    for (let dy = -radius; dy <= radius; dy++) {
      for (let dx = -radius; dx <= radius; dx++) {
        if (dx * dx + dy * dy > radius * radius + 0.5) continue;
        const x = tx + dx, y = ty + dy;
        if (!this.inBounds(x, y)) continue;
        if (!rng.chance(0.75)) continue; // pincel orgânico, não bloco cheio
        const i = this.idx(x, y);
        if (this.buildingAt.has(i)) {
          if (elem === E.FIRE) this.igniteBuilding(this.buildingAt.get(i), game);
          continue;
        }
        if (elem === E.FIRE) this.setDep(i, E.FIRE, rng.range(3, 6));
        else if (elem === E.AIR) this.setDep(i, E.AIR, rng.range(1.5, 3));
        else this.setDep(i, elem, fuseLife(elem, rng));
        if (elem === E.GOLD) game.notifyGold(x * TILE + TILE / 2, y * TILE + TILE / 2);
      }
    }
  }

  igniteBuilding(b, game) {
    if (b.element === E.WOOD && !b.burning) {
      b.burning = 4;
      game.feed(`🔥 ${b.label} pegou fogo!`, '#ff6a2a');
    }
  }

  // Borracha divina: limpa todos os depósitos no raio (círculo cheio, sem
  // falhas de pincel — apagar deve ser confiável) e apaga chamas de construções.
  erase(tx, ty, radius) {
    for (let dy = -radius; dy <= radius; dy++) {
      for (let dx = -radius; dx <= radius; dx++) {
        if (dx * dx + dy * dy > radius * radius + 0.5) continue;
        const x = tx + dx, y = ty + dy;
        if (!this.inBounds(x, y)) continue;
        const i = this.idx(x, y);
        if (this.dep[i] !== -1) this.clearDep(i);
        const b = this.buildingAt.get(i);
        if (b && b.burning > 0) b.burning = 0;
      }
    }
  }

  // Explosão de enxofre: fogo em área, dano em construções e criaturas próximas.
  sulfurExplosion(tx, ty, rng, game) {
    const px = tx * TILE + TILE / 2, py = ty * TILE + TILE / 2;
    game.lightningAt(px, py, 30, 20); // flash + onda de choque
    for (let dy = -2; dy <= 2; dy++) {
      for (let dx = -2; dx <= 2; dx++) {
        const x = tx + dx, y = ty + dy;
        if (!this.inBounds(x, y)) continue;
        const i = this.idx(x, y);
        const b = this.buildingAt.get(i);
        if (b) b.hp -= 40;
        if (this.dep[i] !== -1) this.setDep(i, E.FIRE, rng.range(2, 4));
      }
    }
    for (const c of game.hash.query(px, py, 2.5 * TILE)) c.hurt(30, null, 'pela explosão de enxofre');
  }

  // Explosão de pólvora: raio 3 tiles, cascata por fila (nunca recursão).
  // Também usada pelo Núcleo Estelar ao expirar (valores idênticos).
  gunpowderExplosion(tx, ty, rng, game) {
    const queue = [[tx, ty]];
    const done = new Set();
    while (queue.length) {
      const [x, y] = queue.shift();
      if (!this.inBounds(x, y)) continue;
      const start = this.idx(x, y);
      if (done.has(start)) continue;
      done.add(start);
      const px = x * TILE + TILE / 2, py = y * TILE + TILE / 2;
      game.lightningAt(px, py, 40, 25); // flash + onda de choque
      for (let dy = -3; dy <= 3; dy++) {
        for (let dx = -3; dx <= 3; dx++) {
          const nx = x + dx, ny = y + dy;
          if (!this.inBounds(nx, ny)) continue;
          const i = this.idx(nx, ny);
          const b = this.buildingAt.get(i);
          if (b) b.hp -= 60;
          if (this.dep[i] === E.GUNPOWDER && !done.has(i)) { queue.push([nx, ny]); continue; }
          if (this.dep[i] !== -1 && this.dep[i] !== E.MONOLITH) this.setDep(i, E.FIRE, rng.range(2, 4));
        }
      }
      for (const c of game.hash.query(px, py, 3.5 * TILE)) c.hurt(45, null, 'pela explosão de pólvora');
    }
  }

  // Raio: dano em área, vitrifica areia, conduz por metal/ouro (depósitos e construções).
  lightningStrike(tx, ty, rng, game, maxChain, depth = 0) {
    const visited = new Set();
    const queue = [[tx, ty]];
    let chained = 0;
    while (queue.length && chained < maxChain) {
      const [x, y] = queue.shift();
      if (!this.inBounds(x, y)) continue;
      const i = this.idx(x, y);
      if (visited.has(i)) continue;
      visited.add(i);
      chained++;
      const px = x * TILE + TILE / 2, py = y * TILE + TILE / 2;
      game.lightningAt(px, py, chained === 1 ? 26 : 14, chained === 1 ? 24 : 12);
      // vitrificação: deserto vira depósito de vidro
      if (this.terrain[i] === T.DESERT && this.dep[i] === -1 && rng.chance(0.6)) {
        this.setDep(i, E.GLASS);
      }
      if (this.dep[i] === E.WOOD && rng.chance(0.5)) this.setDep(i, E.FIRE, rng.range(2, 4));
      // pólvora atingida por raio detona
      if (this.dep[i] === E.GUNPOWDER) { this.gunpowderExplosion(x, y, rng, game); continue; }
      // fusões desencadeadas pelo raio (o raio nunca vira depósito no chão)
      const strikeFuse = (FUSE[E.LIGHTNING] || {})[this.dep[i]];
      if (strikeFuse !== undefined && rng.chance(0.4)) {
        this.setDep(i, strikeFuse, fuseLife(strikeFuse, rng));
        game.notifyFusion(strikeFuse, px, py);
      }
      // condução em cadeia por vizinhos condutores
      for (let dy = -1; dy <= 1; dy++) {
        for (let dx = -1; dx <= 1; dx++) {
          if (!dx && !dy) continue;
          const nx = x + dx, ny = y + dy;
          if (!this.inBounds(nx, ny)) continue;
          const ni = this.idx(nx, ny);
          if (visited.has(ni)) continue;
          // prisma refrata o raio para outro ponto (recursão limitada)
          if (this.dep[ni] === E.PRISM && depth < 2 && rng.chance(0.7)) {
            this.lightningStrike(nx + rng.int(-2, 2), ny + rng.int(-2, 2), rng, game, 2, depth + 1);
          }
          // efeitos únicos: VIDRO (ricochete) e DIAMANTE (prisma natural, mais raro)
          // — versões mais fracas do prisma, compartilhando o mesmo limite de depth
          if ((this.dep[ni] === E.GLASS || this.dep[ni] === E.DIAMOND) && depth < 2 &&
              rng.chance(this.dep[ni] === E.GLASS ? 0.5 : 0.3)) {
            this.lightningStrike(nx + rng.int(-1, 1), ny + rng.int(-1, 1), rng, game, 1, depth + 1);
          }
          const nb = this.buildingAt.get(ni);
          if ((this.dep[ni] >= 0 && CONDUCTIVE.has(this.dep[ni])) || (nb && CONDUCTIVE.has(nb.element))) {
            if (nb) nb.hp -= 14;
            queue.push([nx, ny]);
          }
        }
      }
    }
  }

  // Tick ambiental (~4x/s): processa a matriz de reações nos tiles ativos.
  envTick(game, dt) {
    if (this.active.size === 0) return;
    const rng = game.envRng;
    const toClear = [];
    const toSet = [];
    for (const i of this.active) {
      const elem = this.dep[i];
      if (elem === -1) { toClear.push(i); continue; }
      const x = i % this.w, y = (i / this.w) | 0;

      // vida limitada de fogo, ar e elementos fundidos voláteis
      if (TIMED.has(elem)) {
        this.depLife[i] -= dt;
        if (this.depLife[i] <= 0) {
          if (elem === E.LAVA) {
            // lava esfria em pedra; no deserto pode vitrificar
            const glass = this.terrain[i] === T.DESERT && !rng.chance(0.7);
            toSet.push([i, glass ? E.GLASS : E.STONE, 0]);
          } else if (elem === E.VAPOR) {
            // vapor condensa em névoa ou dissipa
            if (rng.chance(0.4)) toSet.push([i, E.MIST, fuseLife(E.MIST, rng)]);
            else toSet.push([i, -1]);
          } else if (elem === E.BLIZZARD) {
            toSet.push([i, E.SNOW, 0]);
          } else if (elem === E.STARCORE) {
            // colapso: explosão idêntica à da pólvora e o tile vira obsidiana
            this.gunpowderExplosion(x, y, rng, game);
            toSet.push([i, E.OBSIDIAN, 0]);
          } else {
            toSet.push([i, -1]);
            if (elem === E.FIRE || elem === E.PLASMA) game.smokeAt(x * TILE + 8, y * TILE + 8);
          }
          continue;
        }
      }
      if (elem === E.FIRE || elem === E.LAVA) game.flameAt(x * TILE + 8, y * TILE + 8, rng);

      // tempestade: raios reduzidos caem por perto
      if (elem === E.STORM && rng.chance(0.12)) {
        this.lightningStrike(x + rng.int(-3, 3), y + rng.int(-3, 3), rng, game, 2);
      }

      // reações com vizinhos (matriz declarativa REACT)
      const table = REACT[elem];
      let inert = true;
      let rustHasMetal = false;
      for (let dy = -1; dy <= 1; dy++) {
        for (let dx = -1; dx <= 1; dx++) {
          if (!dx && !dy) continue;
          const nx = x + dx, ny = y + dy;
          if (!this.inBounds(nx, ny)) continue;
          const ni = this.idx(nx, ny);
          const nElem = this.dep[ni];
          // fogo e lava incendeiam construções inflamáveis vizinhas
          if (elem === E.FIRE || elem === E.LAVA) {
            const nb = this.buildingAt.get(ni);
            if (nb && FLAMMABLE.has(nb.element)) this.igniteBuilding(nb, game);
            // fogo derrete construções de gelo
            if (elem === E.FIRE && nb && nb.element === E.ICE) nb.hp -= 20 * dt * 4;
          }
          // enxofre vizinho de fogo detona (reação especial, não é fusão)
          if (elem === E.FIRE && nElem === E.SULFUR) {
            this.sulfurExplosion(nx, ny, rng, game);
            inert = false;
            continue;
          }
          // pólvora vizinha de fogo detona (tratada como o enxofre)
          if (elem === E.FIRE && nElem === E.GUNPOWDER) {
            this.gunpowderExplosion(nx, ny, rng, game);
            inert = false;
            continue;
          }
          // carvão incendiado queima 3× mais tempo que a madeira
          if (elem === E.FIRE && nElem === E.CHARCOAL) {
            if (rng.chance(0.35)) toSet.push([ni, E.FIRE, rng.range(12, 18)]);
            inert = false;
            continue;
          }
          // fusões: o par a×b vira o produto (prioridade sobre REACT neste tick)
          if (nElem !== -1) {
            const fuseTo = (FUSE[elem] || {})[nElem];
            if (fuseTo !== undefined) {
              if (rng.chance(0.4)) {
                toSet.push([i, fuseTo, fuseLife(fuseTo, rng)]);
                toSet.push([ni, fuseTo, fuseLife(fuseTo, rng)]);
                game.notifyFusion(fuseTo, x * TILE + 8, y * TILE + 8);
                continue;
              }
              inert = false; // fusão possível pendente, continua ativo
            }
          }
          // efeitos ambientais dos elementos de fusão sobre vizinhos
          if (elem === E.LAVA) {
            if (nElem === E.GUNPOWDER && rng.chance(0.3)) this.gunpowderExplosion(nx, ny, rng, game);
            else if (nElem !== -1 && FLAMMABLE.has(nElem) && rng.chance(0.3)) toSet.push([ni, E.FIRE, nElem === E.CHARCOAL ? rng.range(12, 18) : rng.range(3, 5)]);
            else if (nElem === -1 && !this.buildingAt.has(ni) && rng.chance(0.1)) toSet.push([ni, E.LAVA, this.depLife[i] * 0.7]);
          } else if (elem === E.PLASMA) {
            if (nElem !== -1 && nElem !== E.OBSIDIAN && nElem !== E.DIAMOND && nElem !== E.MONOLITH && rng.chance(0.5)) toSet.push([ni, -1]);
          } else if (elem === E.RUST) {
            if (nElem === E.METAL || nElem === E.STEEL) {
              rustHasMetal = true;
              if (rng.chance(0.2)) toSet.push([ni, E.RUST, 0]);
            }
            const nb = this.buildingAt.get(ni);
            if (nb && (nb.element === E.METAL || nb.element === E.STEEL)) { rustHasMetal = true; nb.hp -= 4 * dt; }
          } else if (elem === E.SNOW) {
            if (nElem === E.WATER && rng.chance(0.1)) { toSet.push([ni, E.ICE, 0]); inert = false; }
          } else if (elem === E.ACID) {
            if ((nElem === E.STONE || nElem === E.METAL || nElem === E.GLASS || nElem === E.STEEL) && rng.chance(0.25)) toSet.push([ni, -1]);
            const nb = this.buildingAt.get(ni);
            if (nb && nb.element !== E.OBSIDIAN && nb.element !== E.MONOLITH) nb.hp -= 6 * dt;
          } else if (elem === E.MIASMA) {
            if (nElem === -1 && !this.buildingAt.has(ni) && rng.chance(0.05)) toSet.push([ni, E.MIASMA, this.depLife[i] * 0.6]);
          } else if (elem === E.VAPOR) {
            if (nElem === -1 && !this.buildingAt.has(ni) && rng.chance(0.15)) toSet.push([ni, E.VAPOR, this.depLife[i] * 0.6]);
          } else if (elem === E.BLIZZARD) {
            if (nElem === -1 && !this.buildingAt.has(ni) && rng.chance(0.2)) toSet.push([ni, E.SNOW, 0]);
            else if (nElem === E.WATER && rng.chance(0.3)) toSet.push([ni, E.ICE, 0]);
          } else if (elem === E.PLAGUE) {
            if (nElem === -1 && !this.buildingAt.has(ni) && rng.chance(0.07)) toSet.push([ni, E.PLAGUE, this.depLife[i] * 0.7]);
          }
          if (nElem === -1 || !table) continue;
          const rule = table[nElem];
          if (!rule) continue;
          if (rng.chance(elem === E.FIRE ? 0.35 : 0.5)) {
            if (rule.other !== undefined && rule.other !== nElem) {
              toSet.push([ni, rule.other, rule.other === E.FIRE ? rng.range(3, 5) : 0]);
              inert = false;
            }
            if (rule.self !== undefined && rule.self !== elem) {
              toSet.push([i, rule.self, rule.self === E.FIRE ? rng.range(3, 5) : 0]);
              inert = false;
            }
          } else {
            inert = false; // reação possível pendente, continua ativo
          }
        }
      }

      // água (e mercúrio, que flui igual) recém-despejada espalha um pouco e assenta
      if (elem === E.WATER || elem === E.MERCURY) {
        if (rng.chance(0.25)) {
          const nx = x + rng.int(-1, 1), ny = y + rng.int(-1, 1);
          if (this.inBounds(nx, ny)) {
            const ni = this.idx(nx, ny);
            if (this.dep[ni] === -1 && !this.buildingAt.has(ni) && rng.chance(0.4)) toSet.push([ni, elem]);
          }
        }
        if (rng.chance(0.15) && inert) toClear.push(i); // assenta (vira passivo)
      } else if (elem === E.ASH) {
        // cinza fértil: pode brotar madeira ou musgo; senão logo assenta
        if (rng.chance(0.004)) toSet.push([i, rng.chance(0.5) ? E.WOOD : E.MOSS, 0]);
        else if (rng.chance(0.15)) toClear.push(i);
      } else if (elem === E.WOOD) {
        // efeito único: MADEIRA — floresta viva espalha devagar em terreno plano
        if (rng.chance(0.0008)) {
          const nx = x + rng.int(-1, 1), ny = y + rng.int(-1, 1);
          if (this.inBounds(nx, ny)) {
            const ni = this.idx(nx, ny);
            if (this.dep[ni] === -1 && !this.buildingAt.has(ni) && this.terrain[ni] === T.PLAIN) toSet.push([ni, E.WOOD, 0]);
          }
        }
        if (rng.chance(0.3)) toClear.push(i); // remoção rápida: não infla o conjunto ativo
      } else if (elem === E.POISON || elem === E.ICE || elem === E.SNOW) {
        if (inert && rng.chance(0.2)) toClear.push(i); // nada mais a reagir por perto
      } else if (elem === E.MUD) {
        // lama fértil: pode brotar madeira nos primeiros ticks, depois assenta
        if (rng.chance(0.002)) toSet.push([i, E.WOOD, 0]);
        else if (rng.chance(0.2)) toClear.push(i);
      } else if (elem === E.FUNGUS) {
        if (rng.chance(0.001)) {
          const nx = x + rng.int(-1, 1), ny = y + rng.int(-1, 1);
          if (this.inBounds(nx, ny)) {
            const ni = this.idx(nx, ny);
            if (this.dep[ni] === -1 && !this.buildingAt.has(ni) && this.terrain[ni] === T.PLAIN) toSet.push([ni, E.FUNGUS, 0]);
          }
        }
        if (rng.chance(0.2)) toClear.push(i);
      } else if (elem === E.RUST) {
        if (!rustHasMetal) toClear.push(i); // sem metal por perto: inerte
      } else if (!TIMED.has(elem)) {
        // tile passivo acordado só para uma fusão: dorme quando nada por perto
        if (inert && rng.chance(0.2)) toClear.push(i);
      }
    }
    for (const i of toClear) this.active.delete(i);
    for (const [i, elem, life] of toSet) {
      if (elem === -1) this.clearDep(i);
      else this.setDep(i, elem, life);
    }
  }
}


// Grid do mundo, terreno procedural (value noise feito à mão),
// depósitos de elementos no chão e o tick ambiental de reações.

import { E, REACT, CONDUCTIVE, FLAMMABLE } from './elements.js';
import { RNG } from './rng.js';

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
    return f;
  }

  setDep(i, elem, life) {
    this.dep[i] = elem;
    this.depLife[i] = life !== undefined ? life : 0;
    if (elem === E.FIRE || elem === E.AIR || elem === E.WATER || elem === E.POISON || elem === E.ICE) {
      this.active.add(i);
    }
  }
  clearDep(i) {
    this.dep[i] = -1;
    this.active.delete(i);
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
        else this.setDep(i, elem);
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

  // Raio: dano em área, vitrifica areia, conduz por metal/ouro (depósitos e construções).
  lightningStrike(tx, ty, rng, game, maxChain) {
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
      // condução em cadeia por vizinhos condutores
      for (let dy = -1; dy <= 1; dy++) {
        for (let dx = -1; dx <= 1; dx++) {
          if (!dx && !dy) continue;
          const nx = x + dx, ny = y + dy;
          if (!this.inBounds(nx, ny)) continue;
          const ni = this.idx(nx, ny);
          if (visited.has(ni)) continue;
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

      // vida limitada de fogo e ar
      if (elem === E.FIRE || elem === E.AIR) {
        this.depLife[i] -= dt;
        if (this.depLife[i] <= 0) {
          toSet.push([i, -1]);
          if (elem === E.FIRE) game.smokeAt(x * TILE + 8, y * TILE + 8);
          continue;
        }
      }
      if (elem === E.FIRE) game.flameAt(x * TILE + 8, y * TILE + 8, rng);

      // reações com vizinhos (matriz declarativa REACT)
      const table = REACT[elem];
      let inert = true;
      for (let dy = -1; dy <= 1; dy++) {
        for (let dx = -1; dx <= 1; dx++) {
          if (!dx && !dy) continue;
          const nx = x + dx, ny = y + dy;
          if (!this.inBounds(nx, ny)) continue;
          const ni = this.idx(nx, ny);
          const nElem = this.dep[ni];
          // fogo incendeia construções inflamáveis vizinhas
          if (elem === E.FIRE) {
            const nb = this.buildingAt.get(ni);
            if (nb && FLAMMABLE.has(nb.element)) this.igniteBuilding(nb, game);
            // fogo derrete construções de gelo
            if (nb && nb.element === E.ICE) nb.hp -= 20 * dt * 4;
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

      // água recém-despejada espalha um pouco e assenta
      if (elem === E.WATER) {
        if (rng.chance(0.25)) {
          const nx = x + rng.int(-1, 1), ny = y + rng.int(-1, 1);
          if (this.inBounds(nx, ny)) {
            const ni = this.idx(nx, ny);
            if (this.dep[ni] === -1 && !this.buildingAt.has(ni) && rng.chance(0.4)) toSet.push([ni, E.WATER]);
          }
        }
        if (rng.chance(0.15) && inert) toClear.push(i); // assenta (vira passivo)
      } else if (elem === E.POISON || elem === E.ICE) {
        if (inert && rng.chance(0.2)) toClear.push(i); // nada mais a reagir por perto
      }
    }
    for (const i of toClear) this.active.delete(i);
    for (const [i, elem, life] of toSet) {
      if (elem === -1) this.clearDep(i);
      else this.setDep(i, elem, life);
    }
  }
}

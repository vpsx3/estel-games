// Construções procedurais: estruturas, objetos, armas e veículos.
// O que construir é sorteado de uma tabela ponderada por elemento carregado + temperamento.

import { E, elemName, elemColor, FLAMMABLE, STRUCTURAL } from './elements.js';
import { TILE, T } from './world.js';

export const BUILD_THRESHOLD = 2;

export const TYPE_NAMES = {
  wall: 'Parede', floor: 'Piso', tower: 'Torre', house: 'Casa', bridge: 'Ponte',
  campfire: 'Fogueira', totem: 'Totem', chest: 'Baú', sculpture: 'Escultura',
};

const HP_BY_ELEM = {
  [E.WOOD]: 30, [E.STONE]: 60, [E.GLASS]: 18, [E.ICE]: 24, [E.METAL]: 80,
  [E.GOLD]: 40, [E.DIAMOND]: 150, [E.SLIME]: 26, [E.WATER]: 20, [E.FIRE]: 20,
  [E.AIR]: 15, [E.POISON]: 22, [E.LIGHTNING]: 25,
};

let nextBid = 1;

export class Building {
  constructor(game, type, tx, ty, elem, faction, builder) {
    this.id = nextBid++;
    this.type = type;
    this.tx = tx; this.ty = ty;
    this.x = tx * TILE + TILE / 2;
    this.y = ty * TILE + TILE / 2;
    this.element = elem;
    this.faction = faction || null;
    this.maxHp = (HP_BY_ELEM[elem] || 30) * (type === 'tower' ? 1.5 : 1);
    this.hp = this.maxHp;
    this.burning = 0;
    this.gold = type === 'chest' ? 1 : 0;
    this.seed = builder ? Math.floor(builder.rng.next() * 4294967296) : game.envRng.int(0, 1e9);
    this.height = type === 'tower' ? 2.2 : type === 'house' ? 1.4 : 1;
  }

  get label() { return `${TYPE_NAMES[this.type]} de ${elemName(this.element)}`; }

  update(game, dt) {
    if (this.burning > 0) {
      this.burning -= dt;
      this.hp -= 9 * dt;
      if (game.fxRng.chance(dt * 6)) game.flameAt(this.x + game.fxRng.range(-5, 5), this.y + game.fxRng.range(-6, 2), game.fxRng);
      // fogo se espalha para construções/depósitos inflamáveis vizinhos
      if (game.fxRng.chance(dt * 1.2)) {
        const world = game.world;
        const nx = this.tx + game.envRng.int(-1, 1), ny = this.ty + game.envRng.int(-1, 1);
        if (world.inBounds(nx, ny)) {
          const ni = world.idx(nx, ny);
          const nb = world.buildingAt.get(ni);
          if (nb && FLAMMABLE.has(nb.element)) world.igniteBuilding(nb, game);
          else if (world.dep[ni] === E.WOOD || world.dep[ni] === E.SLIME) world.setDep(ni, E.FIRE, game.envRng.range(3, 5));
        }
      }
    }
    if (this.hp <= 0) game.removeBuilding(this, this.burning > 0 ? 'queimou até o chão' : 'foi destruída');
  }
}

function buildOptions(c, elem, waterNearby) {
  const t = c.temperament;
  const opts = [];
  const add = (type, w, elems) => {
    if (w > 0 && (!elems || elems.includes(elem))) opts.push({ type, w });
  };
  const structural = STRUCTURAL.has(elem);
  if (structural) {
    add('wall', 1 + t.industriousness);
    add('floor', 0.7 + t.industriousness * 0.5);
  }
  add('tower', 0.5 + t.aggression * 0.9, [E.STONE, E.METAL]);
  add('house', 1 + t.sociability * 1.2, [E.WOOD, E.STONE]);
  add('campfire', 0.8, [E.WOOD]);
  if (waterNearby) add('bridge', 1.2, [E.WOOD, E.STONE]);
  add('totem', c.faction ? 1.0 : 0.25);
  add('chest', t.greed * 1.6, [E.WOOD, E.GOLD]);
  add('sculpture', 0.5 + t.curiosity * 0.9);
  if (!c.weapon) add('weapon', 0.5 + t.aggression * 1.8, [E.GLASS, E.METAL, E.DIAMOND]);
  if (!c.vehicle) add('vehicle', 0.3 + t.curiosity * 0.7, [E.METAL, E.WOOD, E.ICE, E.AIR]);
  return opts;
}

const WEAPON_STATS = {
  [E.GLASS]: { name: 'Lâmina de Vidro', atk: 4 },
  [E.METAL]: { name: 'Lança de Metal', atk: 6 },
  [E.DIAMOND]: { name: 'Lâmina de Diamante', atk: 11 },
};
const VEHICLE_STATS = {
  [E.METAL]: { name: 'Carrinho de Metal', speedMul: 1.22 },
  [E.WOOD]: { name: 'Carroça de Madeira', speedMul: 1.18 },
  [E.ICE]: { name: 'Trenó de Gelo', speedMul: 1.32 },
  [E.AIR]: { name: 'Planador', speedMul: 1.38 },
};

// Consome a carga da criatura e materializa uma construção (ou equipa arma/veículo).
export function attemptBuild(game, c, tx, ty) {
  // elemento mais carregado (precisa ter o suficiente dele)
  let elem = -1, n = 0;
  for (const [k, v] of Object.entries(c.carry)) if (v > n) { n = v; elem = +k; }
  if (elem === -1 || n < BUILD_THRESHOLD) return;
  const world = game.world;

  // ponte precisa de água por perto
  let waterTile = null;
  outer: for (let dy = -2; dy <= 2; dy++) {
    for (let dx = -2; dx <= 2; dx++) {
      const x = tx + dx, y = ty + dy;
      if (world.inBounds(x, y) && world.terrain[world.idx(x, y)] === T.WATER && !world.buildingAt.has(world.idx(x, y))) {
        waterTile = { x, y }; break outer;
      }
    }
  }

  const opts = buildOptions(c, elem, !!waterTile);
  if (opts.length === 0) return;
  const choice = c.rng.weighted(opts);

  // paga o custo
  c.carry[elem] -= BUILD_THRESHOLD;
  if (c.carry[elem] <= 0) delete c.carry[elem];
  c.carryTotal = Object.values(c.carry).reduce((a, b) => a + b, 0);

  if (choice.type === 'weapon') {
    c.weapon = { ...WEAPON_STATS[elem], element: elem };
    game.feed(`⚔️ ${c.name} forjou ${c.weapon.name}!`, elemColor(elem));
    return;
  }
  if (choice.type === 'vehicle') {
    c.vehicle = { ...VEHICLE_STATS[elem], element: elem };
    game.feed(`🛞 ${c.name} montou em um(a) ${c.vehicle.name}!`, elemColor(elem));
    return;
  }

  let bx = tx, by = ty;
  if (choice.type === 'bridge' && waterTile) { bx = waterTile.x; by = waterTile.y; }
  const i = world.idx(bx, by);
  if (world.buildingAt.has(i)) return;

  const b = new Building(game, choice.type, bx, by, elem, c.faction, c);
  game.addBuilding(b);
  if (game.buildings.length <= 24 || game.envRng.chance(0.25)) {
    game.feed(`🔨 ${c.name} construiu ${b.label}`, elemColor(elem));
  }
}

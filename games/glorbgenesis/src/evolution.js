// Absorção de elemento -> mutação. Cada elemento tem um pool de 4+ mutações;
// a escolha rola no RNG individual da criatura, então o mesmo elemento gera
// resultados diferentes em criaturas diferentes.

import { E, elemName } from './elements.js';

// Cada mutação: { id, name, apply(c) } — apply altera stats/flags/bodyPlan.
export const MUTATION_POOLS = {
  [E.FIRE]: [
    { id: 'flame_tail', name: 'Cauda Flamejante', apply(c) { c.bodyPlan.tail = { type: 'flame', color: '#ff6a2a' }; c.contactDamage += 3; c.addParticleTrait('flame', '#ff8a3a'); } },
    { id: 'fire_immune', name: 'Imunidade ao Fogo', apply(c) { c.immunities.add(E.FIRE); c.bodyPlan.hue = mixHue(c.bodyPlan.hue, 22, 0.4); } },
    { id: 'boiling_blood', name: 'Sangue Fervente', apply(c) { c.temperament.aggression = clamp01(c.temperament.aggression + 0.3); c.bodyPlan.glow = '#ff3a2a'; } },
    { id: 'ember_skin', name: 'Pele de Brasa', apply(c) { c.bodyPlan.hue = 18; c.bodyPlan.sat = 85; c.stats.strength += 3; } },
    { id: 'smolder', name: 'Fumegante', apply(c) { c.addParticleTrait('smoke', '#777'); c.stats.strength += 1; c.contactDamage += 1; } },
  ],
  [E.METAL]: [
    { id: 'metal_plates', name: 'Placas de Metal', apply(c) { c.bodyPlan.plates += 2; c.stats.defense += 4; c.stats.speed *= 0.85; } },
    { id: 'metal_limbs', name: 'Membros Metálicos', apply(c) { c.bodyPlan.limbs = Math.min(8, c.bodyPlan.limbs + 2); c.bodyPlan.metallicLimbs = true; c.stats.strength += 3; } },
    { id: 'conductor', name: 'Corpo Condutor', apply(c) { c.conductive = true; c.stats.defense += 2; c.bodyPlan.sat = Math.max(8, c.bodyPlan.sat - 30); } },
    { id: 'polished_shell', name: 'Carapaça Polida', apply(c) { c.bodyPlan.sat = 6; c.bodyPlan.light = 68; c.stats.defense += 3; } },
    { id: 'heavy_core', name: 'Núcleo Pesado', apply(c) { c.stats.maxHp += 12; c.hp += 12; c.stats.speed *= 0.9; c.bodyPlan.size += 1; } },
  ],
  [E.ICE]: [
    { id: 'frost_aura', name: 'Aura Congelante', apply(c) { c.bodyPlan.aura = 'rgba(140,210,255,0.30)'; c.slowAura = true; } },
    { id: 'crystal_body', name: 'Corpo Cristalino', apply(c) { c.bodyPlan.alpha = 0.7; c.bodyPlan.hue = 198; c.bodyPlan.crystal = true; c.stats.defense += 3; } },
    { id: 'cold_blood', name: 'Sangue Frio', apply(c) { c.stats.speed *= 0.8; c.stats.maxHp += 16; c.hp += 16; } },
    { id: 'ice_spikes', name: 'Espinhos de Gelo', apply(c) { c.bodyPlan.spikes += 3; c.bodyPlan.spikeColor = '#bfe6ff'; c.contactDamage += 2; } },
    { id: 'cold_immune', name: 'Imunidade ao Frio', apply(c) { c.immunities.add(E.ICE); c.addParticleTrait('snow', '#dff2ff'); } },
  ],
  [E.POISON]: [
    { id: 'toxic_spikes', name: 'Espinhos Tóxicos', apply(c) { c.bodyPlan.spikes += 3; c.bodyPlan.spikeColor = '#7dc832'; c.contactDamage += 3; } },
    { id: 'poison_immune', name: 'Imunidade a Veneno', apply(c) { c.immunities.add(E.POISON); } },
    { id: 'sickly_hue', name: 'Pele Doentia', apply(c) { c.bodyPlan.hue = 82; c.bodyPlan.sat = 60; c.bodyPlan.light = 42; c.scary += 0.4; } },
    { id: 'acid_slobber', name: 'Baba Corrosiva', apply(c) { c.contactDamage += 2; c.addParticleTrait('drip', '#7dc832'); } },
    { id: 'putrid_breath', name: 'Hálito Pútrido', apply(c) { c.scary += 0.3; c.temperament.sociability = clamp01(c.temperament.sociability - 0.2); } },
  ],
  [E.GOLD]: [
    { id: 'golden_body', name: 'Corpo Dourado', apply(c) { c.bodyPlan.hue = 46; c.bodyPlan.sat = 90; c.bodyPlan.light = 60; c.bodyPlan.glow = '#ffc832'; c.shiny += 0.5; } },
    { id: 'glittering_greed', name: 'Ganância Cintilante', apply(c) { c.temperament.greed = clamp01(c.temperament.greed + 0.35); c.addParticleTrait('spark', '#ffd75a'); } },
    { id: 'gleaming_crown', name: 'Coroa Reluzente', apply(c) { c.bodyPlan.antennae = Math.min(4, c.bodyPlan.antennae + 2); c.bodyPlan.antennaColor = '#ffc832'; c.temperament.sociability = clamp01(c.temperament.sociability + 0.2); c.shiny += 0.3; } },
    { id: 'midas_touch', name: 'Toque de Midas', apply(c) { c.temperament.greed = clamp01(c.temperament.greed + 0.2); c.temperament.industriousness = clamp01(c.temperament.industriousness + 0.2); } },
  ],
  [E.SLIME]: [
    { id: 'elastic_body', name: 'Corpo Elástico', apply(c) { c.splitOnDeath = true; c.bodyPlan.wobble = Math.min(1, c.bodyPlan.wobble + 0.5); } },
    { id: 'sticky', name: 'Aderente', apply(c) { c.ignoreTerrain = true; c.bodyPlan.pattern = 'spots'; c.bodyPlan.patternColor = '#5fe07a'; } },
    { id: 'goo_membrane', name: 'Membrana Gosmenta', apply(c) { c.stats.maxHp += 10; c.hp += 10; c.bodyPlan.wobble = Math.min(1, c.bodyPlan.wobble + 0.3); c.bodyPlan.size += 1; } },
    { id: 'goo_green', name: 'Verde Gosma', apply(c) { c.bodyPlan.hue = 135; c.bodyPlan.sat = 70; c.regen += 0.4; c.addParticleTrait('drip', '#5fe07a'); } },
  ],
  [E.AIR]: [
    { id: 'floaty', name: 'Flutuação', apply(c) { c.floaty = true; c.stats.speed *= 1.15; } },
    { id: 'ethereal', name: 'Corpo Etéreo', apply(c) { c.bodyPlan.alpha = Math.max(0.45, c.bodyPlan.alpha - 0.3); c.stats.defense += 2; } },
    { id: 'wind_feet', name: 'Pés de Vento', apply(c) { c.stats.speed *= 1.25; c.bodyPlan.limbs = Math.min(8, c.bodyPlan.limbs + 1); } },
    { id: 'cloud_hop', name: 'Salto Nebuloso', apply(c) { c.dashType = 'hop'; c.addParticleTrait('puff', '#dfeeec'); } },
  ],
  [E.LIGHTNING]: [
    { id: 'electric_dash', name: 'Dash Elétrico', apply(c) { c.dashType = 'electric'; c.addParticleTrait('spark', '#ffe94a'); } },
    { id: 'chain_damage', name: 'Dano em Cadeia', apply(c) { c.chainDamage = true; c.contactDamage += 2; } },
    { id: 'sparking_fur', name: 'Pelagem Faiscante', apply(c) { c.addParticleTrait('spark', '#fff27a'); c.stats.speed *= 1.1; c.bodyPlan.glow = '#ffe94a'; } },
    { id: 'turbo_nerves', name: 'Nervos Turbo', apply(c) { c.stats.speed *= 1.3; } },
  ],
  [E.DIAMOND]: [
    { id: 'adamant_body', name: 'Corpo Adamantino', apply(c) { c.stats.defense += 10; c.bodyPlan.crystal = true; c.bodyPlan.hue = 190; c.bodyPlan.light = 80; c.shiny += 0.6; } },
    { id: 'bright_facets', name: 'Facetas Brilhantes', apply(c) { c.addParticleTrait('spark', '#e0fbff'); c.shiny += 0.6; c.temperament.sociability = clamp01(c.temperament.sociability + 0.15); } },
    { id: 'diamond_heart', name: 'Coração de Diamante', apply(c) { c.stats.maxHp += 30; c.hp += 30; } },
  ],
  [E.WATER]: [
    { id: 'regeneration', name: 'Regeneração', apply(c) { c.regen += 0.8; c.addParticleTrait('drip', '#3f8cff'); } },
    { id: 'fluid_body', name: 'Corpo Fluido', apply(c) { c.bodyPlan.hue = 210; c.bodyPlan.wobble = Math.min(1, c.bodyPlan.wobble + 0.3); c.aquatic = true; } },
    { id: 'hydrated', name: 'Hidratado', apply(c) { c.stats.maxHp += 10; c.hp += 10; c.bodyPlan.size += 1; } },
    { id: 'flame_dampener', name: 'Apaga-Chamas', apply(c) { c.immunities.add(E.FIRE); c.bodyPlan.sat = Math.min(100, c.bodyPlan.sat + 10); } },
  ],
  [E.WOOD]: [
    { id: 'camouflage', name: 'Camuflagem', apply(c) { c.bodyPlan.hue = 95; c.bodyPlan.sat = 35; c.bodyPlan.pattern = 'spots'; c.bodyPlan.patternColor = '#5a4326'; c.scary -= 0.2; } },
    { id: 'thick_bark', name: 'Casca Grossa', apply(c) { c.stats.defense += 3; c.bodyPlan.pattern = 'stripes'; c.bodyPlan.patternColor = '#6a4a26'; } },
    { id: 'branches', name: 'Galhos', apply(c) { c.bodyPlan.antennae = Math.min(4, c.bodyPlan.antennae + 2); c.bodyPlan.antennaColor = '#9a6a35'; c.stats.strength += 2; } },
    { id: 'roots', name: 'Raízes', apply(c) { c.regen += 0.5; } },
  ],
  [E.STONE]: [
    { id: 'sturdy', name: 'Robustez', apply(c) { c.stats.maxHp += 14; c.hp += 14; c.stats.defense += 2; c.stats.speed *= 0.9; } },
    { id: 'rocky_skin', name: 'Pele Rochosa', apply(c) { c.bodyPlan.sat = 8; c.bodyPlan.light = 48; c.bodyPlan.plates += 1; c.stats.defense += 2; } },
    { id: 'stone_fists', name: 'Punhos de Pedra', apply(c) { c.stats.strength += 4; c.bodyPlan.limbs = Math.max(2, c.bodyPlan.limbs); } },
    { id: 'mountain_still', name: 'Imóvel como Montanha', apply(c) { c.stats.defense += 6; c.stats.speed *= 0.75; c.bodyPlan.size += 2; } },
  ],
  [E.GLASS]: [
    { id: 'reflective_body', name: 'Corpo Refletivo', apply(c) { c.bodyPlan.alpha = 0.65; c.bodyPlan.crystal = true; c.stats.defense += 2; c.shiny += 0.3; } },
    { id: 'cutting_spikes', name: 'Espinhos Cortantes', apply(c) { c.bodyPlan.spikes += 4; c.bodyPlan.spikeColor = '#cfeef5'; c.contactDamage += 3; } },
    { id: 'fragile_lethal', name: 'Frágil e Letal', apply(c) { c.stats.strength += 6; c.stats.maxHp = Math.max(10, c.stats.maxHp - 8); c.hp = Math.min(c.hp, c.stats.maxHp); } },
    { id: 'prism', name: 'Prisma', apply(c) { c.bodyPlan.prism = true; c.addParticleTrait('spark', '#bfe8ff'); c.shiny += 0.4; } },
  ],
};

function clamp01(v) { return Math.max(0, Math.min(1, v)); }
function mixHue(a, b, t) { return a + (b - a) * t; }

// Absorve `elem`: rola uma mutação nova (sem repetir) no RNG da criatura.
export function absorbElement(creature, elem, game) {
  creature.absorbed[elem] = (creature.absorbed[elem] || 0) + 1;
  const pool = MUTATION_POOLS[elem] || [];
  const owned = new Set(creature.traits.map(t => t.id));
  const options = pool.filter(m => !owned.has(m.id));
  const rng = creature.rng;
  if (options.length === 0) {
    // já tem tudo desse elemento: só reforça stats levemente
    creature.stats.maxHp += 2;
    creature.hp += 2;
    return null;
  }
  const mut = options[Math.floor(rng.next() * options.length)];
  mut.apply(creature);
  creature.traits.push({ id: mut.id, name: mut.name, element: elem });
  creature.refreshDominant();
  game.feed(`✨ ${creature.name} absorveu ${elemName(elem)} e ganhou ${mut.name}!`, '#c9a6ff');
  return mut;
}

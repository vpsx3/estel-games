// Absorção de elemento -> mutação. Cada elemento tem um pool de 4+ mutações;
// a escolha rola no RNG individual da criatura, então o mesmo elemento gera
// resultados diferentes em criaturas diferentes.

import { E, ENDGAME, elemName, elemColor } from './elements.js';
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
  [E.LAVA]: [
    { id: 'magma_blood', name: 'Sangue de Magma', apply(c) { c.immunities.add(E.FIRE); c.immunities.add(E.LAVA); c.bodyPlan.glow = '#ff4a1a'; } },
    { id: 'volcanic_skin', name: 'Pele Vulcânica', apply(c) { c.stats.defense += 4; c.bodyPlan.hue = 12; c.bodyPlan.sat = 80; } },
    { id: 'burning_trail', name: 'Rastro Ardente', apply(c) { c.fireTrail = true; c.addParticleTrait('flame', '#ff6a2a'); } },
    { id: 'magma_core', name: 'Núcleo Magmático', apply(c) { c.contactDamage += 3; c.stats.maxHp += 8; c.hp += 8; } },
  ],
  [E.STEEL]: [
    { id: 'steel_skeleton', name: 'Esqueleto de Aço', apply(c) { c.stats.defense += 5; c.stats.speed *= 0.9; c.bodyPlan.plates += 2; } },
    { id: 'forged_claws', name: 'Garras Forjadas', apply(c) { c.stats.strength += 4; } },
    { id: 'tempered', name: 'Temperado', apply(c) { c.stats.maxHp += 16; c.hp += 16; } },
    { id: 'metallic_sheen', name: 'Reflexo Metálico', apply(c) { c.shiny += 0.4; c.bodyPlan.sat = 10; c.bodyPlan.light = 70; c.conductive = true; } },
  ],
  [E.PLASMA]: [
    { id: 'ionized_body', name: 'Corpo Ionizado', apply(c) { c.chainDamage = true; c.bodyPlan.glow = '#ff4ae0'; } },
    { id: 'plasma_dash', name: 'Dash de Plasma', apply(c) { c.dashType = 'electric'; c.contactDamage += 2; c.addParticleTrait('spark', '#ff8af0'); } },
    { id: 'radiance', name: 'Fulgor', apply(c) { c.bodyPlan.glow = '#ff4ae0'; c.scary += 0.3; c.shiny += 0.3; } },
    { id: 'overload', name: 'Sobrecarga', apply(c) { c.stats.speed *= 1.3; c.stats.maxHp = Math.max(10, c.stats.maxHp - 8); c.hp = Math.min(c.hp, c.stats.maxHp); } },
  ],
  [E.SMOKE]: [
    { id: 'smoke_cloak', name: 'Manto de Fumaça', apply(c) { c.addParticleTrait('smoke', '#6a6a72'); c.scary += 0.3; } },
    { id: 'evasive', name: 'Evasivo', apply(c) { c.stats.speed *= 1.1; c.bodyPlan.alpha = Math.max(0.5, c.bodyPlan.alpha - 0.2); } },
    { id: 'suffocating', name: 'Sufocante', apply(c) { c.contactDamage += 2; } },
    { id: 'shadowy', name: 'Sombrio', apply(c) { c.bodyPlan.hue = 260; c.bodyPlan.sat = 10; c.bodyPlan.light = 30; c.scary += 0.2; } },
  ],
  [E.MUD]: [
    { id: 'mud_skin', name: 'Pele Lamacenta', apply(c) { c.aquatic = true; c.bodyPlan.hue = 32; c.bodyPlan.sat = 45; } },
    { id: 'earth_regen', name: 'Regeneração Térrea', apply(c) { c.regen += 0.5; } },
    { id: 'brown_camo', name: 'Camuflagem Parda', apply(c) { c.scary -= 0.2; c.bodyPlan.pattern = 'spots'; c.bodyPlan.patternColor = '#5a4326'; } },
    { id: 'dense_body', name: 'Corpo Denso', apply(c) { c.stats.maxHp += 10; c.hp += 10; c.stats.speed *= 0.95; } },
  ],
  [E.MIST]: [
    { id: 'nebulous_body', name: 'Corpo Nebuloso', apply(c) { c.bodyPlan.alpha = Math.max(0.4, c.bodyPlan.alpha - 0.35); c.stats.defense += 2; } },
    { id: 'silent_step', name: 'Passo Silencioso', apply(c) { c.scary -= 0.3; c.stats.speed *= 1.1; } },
    { id: 'veil', name: 'Véu', apply(c) { c.mistVeil = true; } },
    { id: 'dew', name: 'Orvalho', apply(c) { c.regen += 0.3; c.addParticleTrait('drip', '#cfe2e6'); } },
  ],
  [E.RUST]: [
    { id: 'corrosive_touch', name: 'Toque Corrosivo', apply(c) { c.contactDamage += 3; } },
    { id: 'oxidized_shell', name: 'Carapaça Oxidada', apply(c) { c.stats.defense += 3; c.bodyPlan.hue = 20; c.bodyPlan.sat = 55; c.bodyPlan.light = 35; } },
    { id: 'decadent', name: 'Decadente', apply(c) { c.scary += 0.3; c.bodyPlan.pattern = 'spots'; c.bodyPlan.patternColor = '#b0622a'; } },
    { id: 'rust_plates', name: 'Placas Enferrujadas', apply(c) { c.bodyPlan.plates += 1; c.stats.defense += 1; c.stats.maxHp += 6; c.hp += 6; } },
  ],
  [E.SNOW]: [
    { id: 'snow_fur', name: 'Pelagem de Neve', apply(c) { c.immunities.add(E.ICE); c.immunities.add(E.SNOW); c.addParticleTrait('snow', '#ffffff'); } },
    { id: 'light_step', name: 'Passo Leve', apply(c) { c.floaty = true; } },
    { id: 'white_mantle', name: 'Manto Branco', apply(c) { c.bodyPlan.light = 85; c.bodyPlan.sat = 5; c.scary -= 0.15; } },
    { id: 'cold_veins', name: 'Veias Gélidas', apply(c) { c.stats.maxHp += 12; c.hp += 12; c.stats.speed *= 0.9; } },
  ],
  [E.GLACIER]: [
    { id: 'glacial_wall', name: 'Muralha Glacial', apply(c) { c.stats.defense += 5; c.stats.speed *= 0.85; } },
    { id: 'glacier_heart', name: 'Coração de Geleira', apply(c) { c.stats.maxHp += 20; c.hp += 20; } },
    { id: 'frost_field', name: 'Aura Gélida', apply(c) { c.slowAura = true; c.bodyPlan.aura = 'rgba(134,196,232,0.30)'; } },
    { id: 'crystallized', name: 'Cristalizado', apply(c) { c.bodyPlan.crystal = true; c.bodyPlan.alpha = 0.75; c.stats.defense += 2; } },
  ],
  [E.MAGNET]: [
    { id: 'magnetic_body', name: 'Corpo Magnético', apply(c) { c.magneticBody = true; c.conductive = true; } },
    { id: 'stable_field', name: 'Campo Estável', apply(c) { c.stats.defense += 3; } },
    { id: 'true_north', name: 'Norte Verdadeiro', apply(c) { c.stats.speed *= 1.08; c.temperament.industriousness = Math.min(1, c.temperament.industriousness + 0.2); } },
    { id: 'polarized', name: 'Polarizado', apply(c) { c.bodyPlan.hue = 228; c.bodyPlan.sat = 45; c.stats.strength += 2; } },
  ],
  [E.STORM]: [
    { id: 'storm_skin', name: 'Pele Tempestuosa', apply(c) { c.addParticleTrait('spark', '#8f82e0'); c.bodyPlan.glow = '#8f82e0'; } },
    { id: 'thunder_call', name: 'Chamado do Trovão', apply(c) { c.chainDamage = true; c.contactDamage += 1; } },
    { id: 'electric_nerves', name: 'Nervos Elétricos', apply(c) { c.stats.speed *= 1.15; } },
    { id: 'storm_eye', name: 'Olho da Tempestade', apply(c) { c.stats.defense += 2; c.temperament.aggression = Math.max(0, c.temperament.aggression - 0.15); } },
  ],
  [E.ACID]: [
    { id: 'acid_slobber2', name: 'Saliva Ácida', apply(c) { c.contactDamage += 3; c.addParticleTrait('drip', '#c8e42a'); } },
    { id: 'acid_blood', name: 'Sangue Corrosivo', apply(c) { c.acidBlood = true; } },
    { id: 'chem_immunity', name: 'Imunidade Química', apply(c) { c.immunities.add(E.POISON); c.immunities.add(E.ACID); } },
    { id: 'blistered_skin', name: 'Pele Bolhosa', apply(c) { c.stats.maxHp += 8; c.hp += 8; c.scary += 0.2; } },
  ],
  [E.SULFUR]: [
    { id: 'sulfur_breath', name: 'Hálito Sulfuroso', apply(c) { c.scary += 0.4; } },
    { id: 'living_powder', name: 'Pólvora Viva', apply(c) { c.stats.strength += 4; c.bodyPlan.hue = 55; c.bodyPlan.sat = 75; } },
    { id: 'death_burst', name: 'Explosivo Póstumo', apply(c) { c.deathBurst = true; } },
    { id: 'yellowed', name: 'Amarelado', apply(c) { c.bodyPlan.hue = 55; c.contactDamage += 1; } },
  ],
  [E.FUNGUS]: [
    { id: 'spores', name: 'Esporos', apply(c) { c.sporeParent = true; c.addParticleTrait('puff', '#c07ad0'); } },
    { id: 'mycelium', name: 'Micélio', apply(c) { c.regen += 0.6; } },
    { id: 'fungal_cap', name: 'Chapéu Fúngico', apply(c) { c.bodyPlan.antennae = Math.min(4, c.bodyPlan.antennae + 2); c.bodyPlan.antennaColor = '#c07ad0'; } },
    { id: 'symbiont', name: 'Simbionte', apply(c) { c.temperament.sociability = Math.min(1, c.temperament.sociability + 0.25); } },
  ],
  [E.MOSS]: [
    { id: 'moss_skin', name: 'Pele de Musgo', apply(c) { c.regen += 0.5; c.bodyPlan.hue = 110; c.bodyPlan.sat = 50; } },
    { id: 'photosynthesis', name: 'Fotossíntese', apply(c) { c.regen += 0.4; c.stats.lifespan += 60; } },
    { id: 'green_rest', name: 'Repouso Verde', apply(c) { c.stats.maxHp += 10; c.hp += 10; } },
    { id: 'moss_camo', name: 'Camuflado', apply(c) { c.scary -= 0.3; c.bodyPlan.pattern = 'spots'; c.bodyPlan.patternColor = '#4f8f3c'; } },
  ],
  [E.PRISM]: [
    { id: 'prismatic_skin', name: 'Pele Prismática', apply(c) { c.shiny += 0.6; c.bodyPlan.alpha = 0.8; } },
    { id: 'refraction', name: 'Refração', apply(c) { c.immunities.add(E.LIGHTNING); } },
    { id: 'facets', name: 'Facetas', apply(c) { c.bodyPlan.crystal = true; c.stats.defense += 2; } },
    { id: 'hypnotic_glow', name: 'Brilho Hipnótico', apply(c) { c.scary -= 0.2; c.temperament.sociability = Math.min(1, c.temperament.sociability + 0.2); c.addParticleTrait('spark', '#dcc4f4'); } },
  ],
  [E.RELIC]: [
    { id: 'sacred_aura', name: 'Aura Sagrada', apply(c) { c.temperament.sociability = Math.min(1, c.temperament.sociability + 0.3); c.shiny += 0.5; } },
    { id: 'guardian', name: 'Guardião', apply(c) { c.stats.defense += 4; } },
    { id: 'devotion', name: 'Devoção', apply(c) { c.temperament.aggression = Math.max(0, c.temperament.aggression - 0.2); c.stats.maxHp += 10; c.hp += 10; } },
    { id: 'living_idol', name: 'Ídolo Vivo', apply(c) { c.bodyPlan.glow = '#ffdf6a'; c.shiny += 0.4; c.scary -= 0.2; } },
  ],
  [E.OBSIDIAN]: [
    { id: 'obsidian_skin', name: 'Pele de Obsidiana', apply(c) { c.stats.defense += 6; c.stats.speed *= 0.9; } },
    { id: 'volcanic_blades', name: 'Lâminas Vulcânicas', apply(c) { c.contactDamage += 4; c.bodyPlan.spikes += 3; c.bodyPlan.spikeColor = '#5a4a7a'; } },
    { id: 'black_heart', name: 'Coração Negro', apply(c) { c.stats.maxHp += 25; c.hp += 25; } },
    { id: 'unbreakable', name: 'Inquebrável', apply(c) { c.immunities.add(E.FIRE); c.bodyPlan.crystal = true; } },
  ],
  [E.MIASMA]: [
    { id: 'miasmic_breath', name: 'Hálito Miasmático', apply(c) { c.scary += 0.4; c.contactDamage += 2; } },
    { id: 'plague_bearer', name: 'Portador da Praga', apply(c) { c.plagueTrail = true; } },
    { id: 'putrid_immunity', name: 'Imunidade Pútrida', apply(c) { c.immunities.add(E.POISON); c.immunities.add(E.MIASMA); } },
    { id: 'sickly_aspect', name: 'Aspecto Doentio', apply(c) { c.bodyPlan.hue = 80; c.bodyPlan.sat = 40; c.bodyPlan.light = 38; } },
  ],
  [E.CHARCOAL]: [
    { id: 'charcoal_skin', name: 'Pele de Carvão', apply(c) { c.stats.defense += 3; c.bodyPlan.sat = 0; c.bodyPlan.light = 15; } },
    { id: 'inner_ember', name: 'Brasa Interna', apply(c) { c.contactDamage += 2; c.bodyPlan.glow = '#ff6a2a'; } },
    { id: 'slow_burn', name: 'Combustão Lenta', apply(c) { c.stats.lifespan += 80; } },
    { id: 'soot', name: 'Fuligem', apply(c) { c.scary += 0.2; c.addParticleTrait('smoke', '#3a3a3a'); } },
  ],
  [E.VAPOR]: [
    { id: 'vapor_body', name: 'Corpo de Vapor', apply(c) { c.bodyPlan.alpha = Math.max(0.45, c.bodyPlan.alpha - 0.3); c.floaty = true; } },
    { id: 'scalding_breath', name: 'Sopro Escaldante', apply(c) { c.contactDamage += 2; } },
    { id: 'condensation', name: 'Condensação', apply(c) { c.regen += 0.4; } },
    { id: 'personal_cloud', name: 'Nuvem Pessoal', apply(c) { c.addParticleTrait('puff', '#e8f0f2'); c.scary -= 0.15; } },
  ],
  [E.BLIZZARD]: [
    { id: 'blizzard_child', name: 'Filho da Nevasca', apply(c) { c.immunities.add(E.ICE); c.immunities.add(E.SNOW); c.immunities.add(E.BLIZZARD); } },
    { id: 'cutting_wind', name: 'Vento Cortante', apply(c) { c.stats.strength += 3; c.stats.speed *= 1.1; } },
    { id: 'polar_mantle', name: 'Manto Polar', apply(c) { c.stats.maxHp += 14; c.hp += 14; } },
    { id: 'blizzard_aura', name: 'Aura de Nevasca', apply(c) { c.slowAura = true; c.bodyPlan.aura = 'rgba(216,236,255,0.30)'; } },
  ],
  [E.ASH]: [
    { id: 'ash_rebirth', name: 'Renascido das Cinzas', apply(c) { c.ashRebirth = true; } },
    { id: 'gray_skin', name: 'Pele Cinzenta', apply(c) { c.stats.defense += 2; c.bodyPlan.sat = 0; c.bodyPlan.light = 45; } },
    { id: 'living_compost', name: 'Adubo Vivo', apply(c) { c.regen += 0.5; } },
    { id: 'lesser_phoenix', name: 'Fênix Menor', apply(c) { c.immunities.add(E.FIRE); c.bodyPlan.glow = '#ff9a3a'; } },
  ],
  [E.SWAMP]: [
    { id: 'amphibian', name: 'Anfíbio', apply(c) { c.aquatic = true; } },
    { id: 'swamp_skin', name: 'Pele Pantanosa', apply(c) { c.immunities.add(E.POISON); c.bodyPlan.hue = 90; c.bodyPlan.sat = 40; } },
    { id: 'quagmire', name: 'Atoleiro', apply(c) { c.slowAura = true; } },
    { id: 'bog_vigor', name: 'Vigor do Brejo', apply(c) { c.stats.maxHp += 12; c.hp += 12; c.regen += 0.3; } },
  ],
  [E.MERCURY]: [
    { id: 'quicksilver_blood', name: 'Sangue de Mercúrio', apply(c) { c.stats.speed *= 1.2; } },
    { id: 'fluid_body_hg', name: 'Corpo Fluido', apply(c) { c.bodyPlan.alpha = 0.85; c.stats.defense += 2; } },
    { id: 'toxic_touch', name: 'Toque Tóxico', apply(c) { c.contactDamage += 2; c.immunities.add(E.POISON); } },
    { id: 'liquid_mirror', name: 'Espelho Líquido', apply(c) { c.shiny += 0.5; c.conductive = true; } },
  ],
  [E.ELECTRUM]: [
    { id: 'living_wealth', name: 'Riqueza Viva', apply(c) { c.shiny += 0.6; c.temperament.greed = Math.min(1, c.temperament.greed + 0.25); } },
    { id: 'golden_charge', name: 'Carga Dourada', apply(c) { c.chainDamage = true; c.bodyPlan.glow = '#ffe88a'; } },
    { id: 'greed_magnet', name: 'Ímã de Cobiça', apply(c) { c.scary -= 0.2; c.temperament.sociability = Math.min(1, c.temperament.sociability + 0.2); } },
    { id: 'voltage', name: 'Voltagem', apply(c) { c.stats.speed *= 1.12; c.contactDamage += 1; } },
  ],
  [E.GUNPOWDER]: [
    { id: 'short_fuse', name: 'Pavio Curto', apply(c) { c.temperament.aggression = Math.min(1, c.temperament.aggression + 0.3); c.stats.strength += 3; } },
    { id: 'explosive_body', name: 'Corpo Explosivo', apply(c) { c.deathBurst = true; } },
    { id: 'ready_spark', name: 'Faísca Pronta', apply(c) { c.dashType = 'electric'; } },
    { id: 'grained', name: 'Granulado', apply(c) { c.stats.defense += 2; c.bodyPlan.pattern = 'spots'; c.bodyPlan.patternColor = '#5a4a3a'; } },
  ],
  [E.PLAGUE]: [
    { id: 'pestilent', name: 'Pestilento', apply(c) { c.contactDamage += 3; c.scary += 0.4; } },
    { id: 'host', name: 'Hospedeiro', apply(c) { c.plagueTrail = true; } },
    { id: 'sick_resilience', name: 'Resiliência Doentia', apply(c) { c.immunities.add(E.POISON); c.immunities.add(E.MIASMA); c.immunities.add(E.PLAGUE); c.regen += 0.3; } },
    { id: 'swarm', name: 'Enxame', apply(c) { c.splitOnDeath = true; } },
  ],
  [E.AURORA]: [
    { id: 'aurora_touch', name: 'Toque da Aurora', apply(c) { c.regen += 0.8; } },
    { id: 'boreal_light', name: 'Luz Boreal', apply(c) { c.bodyPlan.glow = '#a0ffd8'; c.shiny += 0.5; c.scary -= 0.3; } },
    { id: 'blessed', name: 'Abençoado', apply(c) { c.stats.maxHp += 15; c.hp += 15; c.temperament.sociability = Math.min(1, c.temperament.sociability + 0.2); } },
    { id: 'polar_veil', name: 'Véu Polar', apply(c) { c.bodyPlan.alpha = Math.max(0.5, c.bodyPlan.alpha - 0.2); c.immunities.add(E.ICE); } },
  ],
  [E.STARCORE]: [
    { id: 'stellar_heart', name: 'Coração Estelar', apply(c) { c.stats.maxHp += 30; c.hp += 30; } },
    { id: 'own_gravity', name: 'Gravidade Própria', apply(c) { c.magneticBody = true; } },
    { id: 'solar_glare', name: 'Fulgor Solar', apply(c) { c.bodyPlan.glow = '#ff9a3a'; c.contactDamage += 3; c.scary += 0.3; } },
    { id: 'dense_matter', name: 'Matéria Densa', apply(c) { c.stats.defense += 5; c.stats.speed *= 0.9; } },
  ],
  [E.ETHER]: [
    { id: 'ethereal_ether', name: 'Etéreo', apply(c) { c.floaty = true; c.bodyPlan.alpha = Math.max(0.4, c.bodyPlan.alpha - 0.35); } },
    { id: 'healing_touch', name: 'Toque Curativo', apply(c) { c.regen += 1.0; } },
    { id: 'serenity', name: 'Serenidade', apply(c) { c.temperament.aggression = Math.max(0, c.temperament.aggression - 0.3); c.temperament.sociability = Math.min(1, c.temperament.sociability + 0.3); } },
    { id: 'old_soul', name: 'Alma Antiga', apply(c) { c.stats.lifespan += 120; } },
  ],
  [E.MONOLITH]: [
    { id: 'monolithic_skin', name: 'Pele Monolítica', apply(c) { c.stats.defense += 7; c.stats.speed *= 0.85; } },
    { id: 'unshakable_will', name: 'Vontade Inabalável', apply(c) { c.stats.maxHp += 25; c.hp += 25; } },
    { id: 'born_builder', name: 'Construtor Nato', apply(c) { c.temperament.industriousness = Math.min(1, c.temperament.industriousness + 0.35); } },
    { id: 'ancestral_presence', name: 'Presença Ancestral', apply(c) { c.scary += 0.2; c.shiny += 0.3; c.temperament.sociability = Math.min(1, c.temperament.sociability + 0.15); } },
  ],
};

function clamp01(v) { return Math.max(0, Math.min(1, v)); }
function mixHue(a, b, t) { return a + (b - a) * t; }

// ---------------------------------------------------------------------------
// Dons Elementais: 1 dom único por elemento, despertado na PRIMEIRA absorção.
// Permanentes (exceto o Dom das Cinzas, consumível), não herdados pelos filhos
// e fora do pool de mutações. A maioria é comportamental: os hooks em
// creature.js/main.js checam c.gifts.has(E.X); `apply` cobre a parte imediata.
// ---------------------------------------------------------------------------
export const ELEMENT_GIFTS = {
  [E.WOOD]:      { name: 'Dom da Semente' },
  [E.STONE]:     { name: 'Dom da Rocha' },
  [E.GLASS]:     { name: 'Dom do Reflexo' },
  [E.FIRE]:      { name: 'Dom da Chama' },
  [E.WATER]:     { name: 'Dom da Correnteza', apply(c) { c.aquatic = true; } },
  [E.AIR]:       { name: 'Dom do Vento' },
  [E.LIGHTNING]: { name: 'Dom da Descarga' },
  [E.ICE]:       { name: 'Dom do Gelo' },
  [E.POISON]:    { name: 'Dom da Toxina' },
  [E.SLIME]:     { name: 'Dom da Gosma' },
  [E.METAL]:     { name: 'Dom do Ferro', apply(c) { c.stats.defense += 2; } },
  [E.GOLD]:      { name: 'Dom de Midas' },
  [E.DIAMOND]:   { name: 'Dom Adamantino' },
  [E.LAVA]:      { name: 'Dom Magmático' },
  [E.STEEL]:     { name: 'Dom do Aço' },
  [E.PLASMA]:    { name: 'Dom do Plasma' },
  [E.SMOKE]:     { name: 'Dom da Fumaça' },
  [E.MUD]:       { name: 'Dom do Lodo' },
  [E.MIST]:      { name: 'Dom da Névoa' },
  [E.RUST]:      { name: 'Dom da Corrosão' },
  [E.SNOW]:      { name: 'Dom da Neve' },
  [E.GLACIER]:   { name: 'Dom Glacial' },
  [E.MAGNET]:    { name: 'Dom Magnético' },
  [E.STORM]:     { name: 'Dom da Tempestade' },
  [E.ACID]:      { name: 'Dom Ácido' },
  [E.SULFUR]:    { name: 'Dom Sulfúrico' },
  [E.FUNGUS]:    { name: 'Dom Fúngico', apply(c) { c.sporeParent = true; } },
  [E.MOSS]:      { name: 'Dom do Musgo' },
  [E.PRISM]:     { name: 'Dom Prismático', apply(c) { c.immunities.add(E.LIGHTNING); } },
  [E.RELIC]:     { name: 'Dom da Relíquia' },
  [E.OBSIDIAN]:  { name: 'Dom Obsidiano', apply(c) { c.stats.defense += 4; c.immunities.add(E.LAVA); } },
  [E.MIASMA]:    { name: 'Dom Miasmático' },
  [E.CHARCOAL]:  { name: 'Dom do Carvão' },
  [E.VAPOR]:     { name: 'Dom do Vapor' },
  [E.BLIZZARD]:  { name: 'Dom da Nevasca' },
  [E.ASH]:       { name: 'Dom das Cinzas' },
  [E.SWAMP]:     { name: 'Dom do Pântano' },
  [E.MERCURY]:   { name: 'Dom do Mercúrio' },
  [E.ELECTRUM]:  { name: 'Dom do Eletro', apply(c) { c.temperament.greed = Math.min(1, c.temperament.greed + 0.2); } },
  [E.GUNPOWDER]: { name: 'Dom da Pólvora' },
  [E.AURORA]:    { name: 'Dom da Aurora' },
  [E.PLAGUE]:    { name: 'Dom da Praga' },
  [E.STARCORE]:  { name: 'Dom Estelar', apply(c) { c.contactDamage += 3; } },
  [E.ETHER]:     { name: 'Dom Etéreo', apply(c) { c.floaty = true; } },
  [E.MONOLITH]:  { name: 'Dom do Monólito' },
};

// Desperta o dom do elemento na criatura (só avisa se ela está no inspetor).
function grantGift(creature, elem, game) {
  const gift = ELEMENT_GIFTS[elem];
  if (!gift || creature.gifts.has(elem)) return;
  creature.gifts.add(elem);
  if (gift.apply) gift.apply(creature);
  if (game.selected === creature) game.feed(`✨ ${creature.name} despertou: ${gift.name}`, elemColor(elem));
}

// Gigantismo permanente (Fase A): absorver muito faz o corpo crescer para
// sempre. Cada limiar de GIANT_TIERS cruzado aplica bônus uma única vez —
// mais forte e resistente, porém mais lento e assustador. Nunca encolhe.
function updateGiantTier(c, game) {
  c.sizeMul = Math.min(ENDGAME.GIANT_MAX_MUL, 1 + Math.sqrt(c.absorbLifetime) * ENDGAME.GIANT_K);
  while (c.giantTier < ENDGAME.GIANT_TIERS.length && c.sizeMul >= ENDGAME.GIANT_TIERS[c.giantTier]) {
    c.giantTier++;
    c.stats.maxHp += ENDGAME.GIANT_HP_PER_TIER;
    c.hp += ENDGAME.GIANT_HP_PER_TIER;
    c.stats.strength += ENDGAME.GIANT_STR_PER_TIER;
    c.stats.speed *= ENDGAME.GIANT_SPEED_MUL_PER_TIER;
    c.scary += ENDGAME.GIANT_SCARY_PER_TIER;
    const title = ENDGAME.GIANT_TIER_NAMES[c.giantTier - 1];
    if (c.giantTier >= 3) {
      game.feed(`🗿 ${c.name} tornou-se ${title}! O mundo estremece sob seus passos.`, '#ffd75a');
      game.addShake(2);
    } else {
      game.feed(`🗿 ${c.name} tornou-se ${title}!`, '#d9c9a6');
    }
  }
}

// Absorve `elem`: rola uma mutação nova (sem repetir) no RNG da criatura.
export function absorbElement(creature, elem, game) {
  creature.absorbed[elem] = (creature.absorbed[elem] || 0) + 1;
  creature.absorbLifetime++;
  updateGiantTier(creature, game);
  // primeira absorção do elemento também desperta o dom único dele
  if (creature.absorbed[elem] === 1) grantGift(creature, elem, game);
  // Dom Fúngico: absorver alimenta
  if (creature.gifts.has(E.FUNGUS) && creature.rng.chance(0.2)) creature.hp = Math.min(creature.stats.maxHp, creature.hp + 5);
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


// Renderização: terreno, depósitos, construções, criaturas procedurais e partículas.
// Tudo desenhado em canvas — nenhum asset externo.

import { E, ELEMENTS, ENDGAME, elemColor } from './elements.js';
import { TILE, T } from './world.js';
const TERRAIN_COLORS = {
  [T.PLAIN]: [38, 51, 42],
  [T.ROCKY]: [51, 52, 61],
  [T.WATER]: [26, 48, 76],
  [T.DESERT]: [74, 68, 51],
};

export function buildTerrainCanvas(world) {
  const cv = document.createElement('canvas');
  cv.width = world.w; cv.height = world.h;
  const c = cv.getContext('2d');
  const img = c.createImageData(world.w, world.h);
  for (let i = 0; i < world.terrain.length; i++) {
    const base = TERRAIN_COLORS[world.terrain[i]];
    const sh = 1 + world.shade[i];
    img.data[i * 4] = base[0] * sh;
    img.data[i * 4 + 1] = base[1] * sh;
    img.data[i * 4 + 2] = base[2] * sh;
    img.data[i * 4 + 3] = 255;
  }
  c.putImageData(img, 0, 0);
  return cv;
}

// Território de facções: canvas offscreen 1px/tile pintado com a influência
// (círculos) das construções de cada facção. Composto sobre o terreno com
// alpha baixa — o mapa vira um mapa político vivo.
export function repaintTerritory(game) {
  const cv = game.territoryCanvas;
  if (!cv) return;
  const c = cv.getContext('2d');
  c.clearRect(0, 0, cv.width, cv.height);
  for (const f of game.factions) {
    if (f.buildings.length === 0) continue;
    c.fillStyle = f.color;
    for (const b of f.buildings) {
      const r = b.type === 'totem' ? ENDGAME.TERRITORY_R_TOTEM : ENDGAME.TERRITORY_R_BUILDING;
      c.beginPath();
      c.arc(b.tx + 0.5, b.ty + 0.5, r, 0, 7);
      c.fill();
    }
  }
}

export function render(game, ctx, cam, t) {
  const { world } = game;
  const vw = ctx.canvas.width, vh = ctx.canvas.height;
  ctx.setTransform(1, 0, 0, 1, 0, 0);
  ctx.fillStyle = '#0b0d12';
  ctx.fillRect(0, 0, vw, vh);

  // tremor de tela enquanto game.shake > 0. Math.random é deliberado aqui:
  // o render roda por FRAME (não por tick) — consumir um RNG da simulação
  // dessincronizaria a seed conforme o framerate.
  let shakeX = 0, shakeY = 0;
  if (game.shake > 0) {
    shakeX = (Math.random() * 2 - 1) * game.shake;
    shakeY = (Math.random() * 2 - 1) * game.shake;
  }
  ctx.setTransform(cam.zoom, 0, 0, cam.zoom, -(cam.x + shakeX) * cam.zoom, -(cam.y + shakeY) * cam.zoom);
  ctx.imageSmoothingEnabled = false;

  // terreno (offscreen 1px/tile, escalado)
  ctx.drawImage(game.terrainCanvas, 0, 0, world.w, world.h, 0, 0, world.w * TILE, world.h * TILE);

  // território das facções (sob os depósitos; alpha dobrada com a lente ativa)
  if (game.territoryCanvas) {
    ctx.globalAlpha = game.lensFactions ? ENDGAME.TERRITORY_ALPHA * 2 : ENDGAME.TERRITORY_ALPHA;
    ctx.drawImage(game.territoryCanvas, 0, 0, world.w, world.h, 0, 0, world.w * TILE, world.h * TILE);
    ctx.globalAlpha = 1;
  }

  // rect visível em tiles (culling)
  const tx0 = Math.max(0, Math.floor(cam.x / TILE));
  const ty0 = Math.max(0, Math.floor(cam.y / TILE));
  const tx1 = Math.min(world.w - 1, Math.ceil((cam.x + vw / cam.zoom) / TILE));
  const ty1 = Math.min(world.h - 1, Math.ceil((cam.y + vh / cam.zoom) / TILE));

  // depósitos
  for (let ty = ty0; ty <= ty1; ty++) {
    for (let tx = tx0; tx <= tx1; tx++) {
      const i = ty * world.w + tx;
      const d = world.dep[i];
      if (d !== -1) drawDeposit(ctx, d, tx, ty, i, t);
    }
  }

  // construções (com culling)
  const x0 = cam.x - TILE * 3, y0 = cam.y - TILE * 3;
  const x1 = cam.x + vw / cam.zoom + TILE * 3, y1 = cam.y + vh / cam.zoom + TILE * 3;
  for (const b of game.buildings) {
    if (b.x < x0 || b.x > x1 || b.y < y0 || b.y > y1) continue;
    drawBuilding(ctx, b, t);
  }

  // criaturas
  for (const c of game.creatures) {
    if (c.x < x0 || c.x > x1 || c.y < y0 || c.y > y1) continue;
    drawCreature(ctx, c, t);
  }

  // lente de facções: anéis por criatura e contorno das construções
  if (game.lensFactions) {
    ctx.lineWidth = 2 / cam.zoom;
    for (const c of game.creatures) {
      if (c.x < x0 || c.x > x1 || c.y < y0 || c.y > y1) continue;
      ctx.strokeStyle = c.faction ? c.faction.color : '#777';
      if (!c.faction) ctx.setLineDash([3, 3]);
      ctx.beginPath(); ctx.arc(c.x, c.y, c.bodyPlan.size + 7, 0, 7); ctx.stroke();
      if (!c.faction) ctx.setLineDash([]);
    }
    ctx.globalAlpha = 0.8;
    for (const b of game.buildings) {
      if (!b.faction || b.x < x0 || b.x > x1 || b.y < y0 || b.y > y1) continue;
      ctx.strokeStyle = b.faction.color;
      ctx.strokeRect(b.tx * TILE + 1, b.ty * TILE + 1, TILE - 2, TILE - 2);
    }
    ctx.globalAlpha = 1;
  }

  // partículas
  for (const p of game.particles) {
    const a = Math.max(0, p.life / p.maxLife);
    ctx.globalAlpha = a;
    if (p.type === 'bolt') {
      ctx.strokeStyle = p.color; ctx.lineWidth = 1.6;
      ctx.beginPath(); ctx.moveTo(p.x, p.y); ctx.lineTo(p.x2, p.y2); ctx.stroke();
    } else {
      ctx.fillStyle = p.color;
      ctx.beginPath(); ctx.arc(p.x, p.y, p.size * (0.4 + 0.6 * a), 0, 7); ctx.fill();
    }
    ctx.globalAlpha = 1;
  }

  // seleção do inspetor
  if (game.selected && game.selected.alive) {
    const s = game.selected;
    ctx.strokeStyle = 'rgba(255,255,255,0.75)';
    ctx.lineWidth = 1.2;
    ctx.setLineDash([3, 3]);
    ctx.beginPath(); ctx.arc(s.x, s.y, s.bodyPlan.size + 7, 0, 7); ctx.stroke();
    ctx.setLineDash([]);
  }

  // cursor do pincel
  if (game.brush.visible && game.tool !== 'inspect') {
    ctx.strokeStyle = 'rgba(255,255,255,0.35)';
    ctx.lineWidth = 1 / cam.zoom;
    ctx.beginPath();
    ctx.arc(game.brush.x, game.brush.y, game.brush.radius * TILE, 0, 7);
    ctx.stroke();
  }
  ctx.setTransform(1, 0, 0, 1, 0, 0);
}

// hash barato para variação por tile
function h2(i) { let x = (i * 2654435761) >>> 0; x ^= x >>> 13; return (x % 1000) / 1000; }

function drawDeposit(ctx, d, tx, ty, i, t) {
  const px = tx * TILE, py = ty * TILE;
  const cx = px + TILE / 2, cy = py + TILE / 2;
  const v = h2(i);
  const col = elemColor(d);
  switch (d) {
    case E.FIRE: {
      const fl = 0.7 + 0.3 * Math.sin(t * 9 + v * 20);
      ctx.fillStyle = '#ff9a3a';
      ctx.beginPath();
      ctx.moveTo(cx - 5, py + 14);
      ctx.quadraticCurveTo(cx - 6, py + 6, cx, py + 14 - 10 * fl);
      ctx.quadraticCurveTo(cx + 6, py + 6, cx + 5, py + 14);
      ctx.fill();
      ctx.fillStyle = '#ffe27a';
      ctx.beginPath(); ctx.arc(cx, py + 11, 2.4 * fl, 0, 7); ctx.fill();
      break;
    }
    case E.WATER: case E.POISON: {
      ctx.fillStyle = col; ctx.globalAlpha = 0.55;
      ctx.beginPath(); ctx.ellipse(cx, cy, 7, 5.5, 0, 0, 7); ctx.fill();
      ctx.globalAlpha = 1;
      break;
    }
    case E.AIR: {
      ctx.strokeStyle = col; ctx.globalAlpha = 0.45; ctx.lineWidth = 1;
      ctx.beginPath(); ctx.arc(cx, cy, 4 + 2 * Math.sin(t * 3 + v * 9), 0.5, 4.5); ctx.stroke();
      ctx.globalAlpha = 1;
      break;
    }
    case E.ICE: case E.GLASS: {
      ctx.fillStyle = col; ctx.globalAlpha = 0.5;
      ctx.fillRect(px + 3, py + 3, 10, 10);
      ctx.globalAlpha = 1;
      ctx.strokeStyle = 'rgba(255,255,255,0.5)'; ctx.lineWidth = 1;
      ctx.strokeRect(px + 3.5, py + 3.5, 9, 9);
      break;
    }
    case E.DIAMOND: {
      ctx.fillStyle = col;
      ctx.beginPath();
      ctx.moveTo(cx, cy - 6); ctx.lineTo(cx + 5, cy); ctx.lineTo(cx, cy + 6); ctx.lineTo(cx - 5, cy);
      ctx.closePath(); ctx.fill();
      if ((t * 2 + v * 7) % 3 < 0.4) { ctx.fillStyle = '#fff'; ctx.fillRect(cx - 1, cy - 4, 2, 2); }
      break;
    }
    case E.GOLD: {
      ctx.fillStyle = col;
      ctx.beginPath(); ctx.arc(cx, cy + 1, 5, 0, 7); ctx.fill();
      if ((t * 1.6 + v * 5) % 2.5 < 0.3) { ctx.fillStyle = '#fff8d0'; ctx.fillRect(cx + 1, cy - 3, 2, 2); }
      break;
    }
    case E.METAL: {
      ctx.fillStyle = col;
      ctx.fillRect(px + 4, py + 5, 9, 7);
      ctx.fillStyle = 'rgba(255,255,255,0.35)'; ctx.fillRect(px + 4, py + 5, 9, 2);
      break;
    }
    case E.SLIME: {
      ctx.fillStyle = col; ctx.globalAlpha = 0.8;
      const w = 1 + 0.12 * Math.sin(t * 4 + v * 12);
      ctx.beginPath(); ctx.ellipse(cx, cy + 2, 6 * w, 5 / w, 0, 0, 7); ctx.fill();
      ctx.globalAlpha = 1;
      break;
    }
    default: { // madeira, pedra
      ctx.fillStyle = col;
      ctx.beginPath();
      ctx.ellipse(cx + (v - 0.5) * 3, cy + 1, 5.5, 4.5, v * 3, 0, 7);
      ctx.fill();
      ctx.fillStyle = 'rgba(0,0,0,0.25)';
      ctx.beginPath(); ctx.ellipse(cx + (v - 0.5) * 3 + 1, cy + 2, 3, 2, v * 3, 0, 7); ctx.fill();
    }
  }
}

function elemFill(ctx, elem) {
  ctx.fillStyle = elemColor(elem);
  ctx.globalAlpha = (elem === E.GLASS || elem === E.ICE) ? 0.55 : 1;
}

function drawBuilding(ctx, b, t) {
  const px = b.tx * TILE, py = b.ty * TILE;
  const cx = b.x, cy = b.y;
  const col = elemColor(b.element);
  ctx.save();
  switch (b.type) {
    case 'wall':
      elemFill(ctx, b.element);
      ctx.fillRect(px + 1, py + 1, TILE - 2, TILE - 2);
      ctx.globalAlpha = 1;
      ctx.strokeStyle = 'rgba(0,0,0,0.4)'; ctx.strokeRect(px + 1.5, py + 1.5, TILE - 3, TILE - 3);
      ctx.strokeStyle = 'rgba(255,255,255,0.15)';
      ctx.beginPath(); ctx.moveTo(px + 2, py + 8); ctx.lineTo(px + 14, py + 8); ctx.stroke();
      break;
    case 'floor': case 'bridge':
      elemFill(ctx, b.element);
      ctx.globalAlpha *= 0.75;
      ctx.fillRect(px + 0.5, py + 0.5, TILE - 1, TILE - 1);
      ctx.globalAlpha = 0.3; ctx.strokeStyle = '#000';
      ctx.beginPath();
      ctx.moveTo(px + 5, py + 1); ctx.lineTo(px + 5, py + 15);
      ctx.moveTo(px + 11, py + 1); ctx.lineTo(px + 11, py + 15);
      ctx.stroke();
      break;
    case 'tower': {
      elemFill(ctx, b.element);
      ctx.fillRect(px + 3, py - 14, 10, 28);
      ctx.globalAlpha = 1;
      ctx.fillStyle = 'rgba(0,0,0,0.3)'; ctx.fillRect(px + 3, py + 8, 10, 6);
      ctx.fillStyle = col;
      ctx.fillRect(px + 1, py - 18, 14, 5);
      if (b.faction) { ctx.fillStyle = b.faction.color; ctx.fillRect(px + 6, py - 24, 6, 4); }
      break;
    }
    case 'house': {
      elemFill(ctx, b.element);
      ctx.fillRect(px + 2, py + 4, 12, 10);
      ctx.globalAlpha = 1;
      ctx.fillStyle = shadeColor(col, -30);
      ctx.beginPath(); ctx.moveTo(px + 1, py + 5); ctx.lineTo(px + 8, py - 4); ctx.lineTo(px + 15, py + 5); ctx.closePath(); ctx.fill();
      ctx.fillStyle = 'rgba(0,0,0,0.5)'; ctx.fillRect(px + 6, py + 9, 4, 5);
      break;
    }
    case 'campfire': {
      ctx.fillStyle = '#6a4a26';
      ctx.fillRect(px + 3, py + 9, 10, 3);
      const fl = 0.7 + 0.3 * Math.sin(t * 10 + b.id);
      ctx.fillStyle = '#ff9a3a';
      ctx.beginPath();
      ctx.moveTo(cx - 4, py + 10); ctx.quadraticCurveTo(cx, py + 10 - 12 * fl, cx + 4, py + 10);
      ctx.fill();
      ctx.fillStyle = '#ffe27a';
      ctx.beginPath(); ctx.arc(cx, py + 8, 2 * fl, 0, 7); ctx.fill();
      break;
    }
    case 'totem': {
      const rr = mulberryLite(b.seed);
      for (let k = 0; k < 3; k++) {
        ctx.fillStyle = k % 2 ? shadeColor(col, -25) : col;
        const w = 10 - k * 2 + rr() * 2;
        ctx.fillRect(cx - w / 2, py + 10 - (k + 1) * 7, w, 7);
      }
      if (b.faction) { ctx.fillStyle = b.faction.color; ctx.fillRect(cx - 2, py - 15, 8, 5); }
      break;
    }
    case 'chest': {
      ctx.fillStyle = '#7a5a30';
      ctx.fillRect(px + 3, py + 6, 10, 8);
      ctx.fillStyle = '#ffc832';
      ctx.fillRect(px + 3, py + 9, 10, 2);
      ctx.fillRect(px + 7, py + 8, 2, 4);
      break;
    }
    case 'sculpture': {
      const rr = mulberryLite(b.seed);
      let yy = py + 14;
      const n = 2 + Math.floor(rr() * 3);
      for (let k = 0; k < n; k++) {
        const w = 4 + rr() * 9, hh = 3 + rr() * 5;
        elemFill(ctx, b.element);
        if (rr() < 0.5) ctx.fillRect(cx - w / 2 + (rr() - 0.5) * 4, yy - hh, w, hh);
        else { ctx.beginPath(); ctx.arc(cx + (rr() - 0.5) * 5, yy - hh / 2, w / 2, 0, 7); ctx.fill(); }
        yy -= hh;
      }
      ctx.globalAlpha = 1;
      break;
    }
  }
  ctx.globalAlpha = 1;
  // marca de facção
  if (b.faction && (b.type === 'wall' || b.type === 'house')) {
    ctx.fillStyle = b.faction.color;
    ctx.fillRect(px + 2, py + 2, 3, 3);
  }
  // dano
  if (b.hp < b.maxHp * 0.5) {
    ctx.strokeStyle = 'rgba(0,0,0,0.55)'; ctx.lineWidth = 1;
    ctx.beginPath(); ctx.moveTo(px + 4, py + 4); ctx.lineTo(px + 9, py + 10); ctx.lineTo(px + 7, py + 13); ctx.stroke();
  }
  ctx.restore();
}

function mulberryLite(seed) {
  let s = seed >>> 0;
  return function () {
    s = (s + 0x6D2B79F5) >>> 0;
    let x = s;
    x = Math.imul(x ^ (x >>> 15), x | 1);
    x ^= x + Math.imul(x ^ (x >>> 7), x | 61);
    return ((x ^ (x >>> 14)) >>> 0) / 4294967296;
  };
}

function shadeColor(hex, amt) {
  const n = parseInt(hex.slice(1), 16);
  const r = Math.max(0, Math.min(255, (n >> 16) + amt));
  const g = Math.max(0, Math.min(255, ((n >> 8) & 255) + amt));
  const b = Math.max(0, Math.min(255, (n & 255) + amt));
  return `rgb(${r},${g},${b})`;
}

// ---------------------------------------------------------------------------
// Criatura procedural — o corpo inteiro sai do bodyPlan, nada de sprites.
// ---------------------------------------------------------------------------
export function drawCreature(ctx, c, t, portrait = false) {
  const bp = c.bodyPlan;
  const s = bp.size * (c.sizeMul || 1); // gigantismo: escala visual permanente
  const wob = Math.sin(t * 3.2 + bp.phase) * bp.wobble * 0.12;
  const moving = !portrait && c.speedNow > 4;
  const squash = moving ? 1 + Math.sin(c.animPhase * 2) * 0.12 : 1 + wob;
  const sx = s * squash, sy = s / squash;
  const hd = portrait ? -0.35 : c.heading;
  const bodyColor = `hsla(${bp.hue},${bp.sat}%,${bp.light}%,${bp.alpha})`;

  ctx.save();
  ctx.translate(c.x, c.y);

  // veículo (desenhado sob a criatura)
  if (c.vehicle && !portrait) drawVehicle(ctx, c, s, t);

  // sombra
  const floatOff = c.floaty ? -3 - Math.sin(t * 2.5 + bp.phase) * 1.5 : 0;
  ctx.fillStyle = 'rgba(0,0,0,0.3)';
  ctx.beginPath(); ctx.ellipse(0, s * 0.75, sx * 0.8, s * 0.3, 0, 0, 7); ctx.fill();
  ctx.translate(0, floatOff);

  // aura
  if (bp.aura) {
    ctx.fillStyle = bp.aura;
    ctx.beginPath(); ctx.arc(0, 0, s + 5 + Math.sin(t * 2 + bp.phase) * 1.5, 0, 7); ctx.fill();
  }

  // cauda
  if (bp.tail) {
    const ta = hd + Math.PI;
    const txx = Math.cos(ta) * (sx + 2), tyy = Math.sin(ta) * (sy + 2);
    if (bp.tail.type === 'flame') {
      const fl = 0.75 + 0.25 * Math.sin(t * 11 + bp.phase);
      ctx.fillStyle = bp.tail.color;
      ctx.beginPath();
      ctx.moveTo(txx * 0.6, tyy * 0.6);
      ctx.lineTo(txx + Math.cos(ta + 0.5) * 4, tyy + Math.sin(ta + 0.5) * 4);
      ctx.lineTo(txx * (1.6 + fl * 0.6), tyy * (1.6 + fl * 0.6));
      ctx.lineTo(txx + Math.cos(ta - 0.5) * 4, tyy + Math.sin(ta - 0.5) * 4);
      ctx.closePath(); ctx.fill();
    } else {
      ctx.strokeStyle = bp.tail.color; ctx.lineWidth = 2.5;
      ctx.beginPath(); ctx.moveTo(txx * 0.5, tyy * 0.5);
      ctx.quadraticCurveTo(txx * 1.3, tyy * 1.3 + Math.sin(t * 4) * 3, txx * 1.8, tyy * 1.8);
      ctx.stroke();
    }
  }

  // membros (perninhas)
  if (bp.limbs > 0) {
    ctx.strokeStyle = bp.metallicLimbs ? '#b9c4d0' : `hsla(${bp.hue},${bp.sat}%,${Math.max(10, bp.light - 18)}%,${bp.alpha})`;
    ctx.lineWidth = 2;
    for (let i = 0; i < bp.limbs; i++) {
      const a = hd + Math.PI / 2 + (i - (bp.limbs - 1) / 2) * (Math.PI / Math.max(3, bp.limbs)) * (i % 2 ? 1 : -1) + (i % 2 ? 0 : Math.PI);
      const step = moving ? Math.sin(c.animPhase * 2.2 + i * 1.7) * 2 : Math.sin(t * 2 + i) * 0.6;
      const lx = Math.cos(a) * sx, ly = Math.sin(a) * sy;
      ctx.beginPath();
      ctx.moveTo(lx * 0.7, ly * 0.7);
      ctx.lineTo(lx * 1.35 + step, ly * 1.35 + Math.abs(step) * 0.5 + 1.5);
      ctx.stroke();
    }
  }

  // glow
  if (bp.glow) { ctx.shadowColor = bp.glow; ctx.shadowBlur = 9; }

  // corpo (blob / segmentado / radial)
  ctx.fillStyle = bodyColor;
  if (bp.shape === 'segment') {
    for (let k = 2; k >= 0; k--) {
      const f = 1 - k * 0.25;
      const ox = -Math.cos(hd) * k * s * 0.95, oy = -Math.sin(hd) * k * s * 0.95;
      ctx.beginPath(); ctx.ellipse(ox, oy, sx * f, sy * f, 0, 0, 7); ctx.fill();
    }
  } else if (bp.shape === 'radial') {
    const lobes = 5 + (bp.blobOffsets[0] > 0 ? 1 : 0);
    ctx.beginPath();
    for (let i = 0; i <= 24; i++) {
      const a = (i / 24) * Math.PI * 2;
      const r = s * (1 + 0.22 * Math.sin(a * lobes + t * 1.5 * bp.wobble));
      const x = Math.cos(a) * r * squash, y = Math.sin(a) * r / squash;
      i ? ctx.lineTo(x, y) : ctx.moveTo(x, y);
    }
    ctx.closePath(); ctx.fill();
  } else { // blob irregular
    ctx.beginPath();
    for (let i = 0; i <= 16; i++) {
      const a = (i / 16) * Math.PI * 2;
      const off = bp.blobOffsets[i % 8];
      const r = s * (1 + off + Math.sin(a * 2 + t * 2.4 * bp.wobble + bp.phase) * 0.05);
      const x = Math.cos(a) * r * squash, y = Math.sin(a) * r / squash;
      i ? ctx.lineTo(x, y) : ctx.moveTo(x, y);
    }
    ctx.closePath(); ctx.fill();
  }
  ctx.shadowBlur = 0;

  // brilho cristalino / prisma
  if (bp.crystal) {
    ctx.strokeStyle = 'rgba(255,255,255,0.6)'; ctx.lineWidth = 1;
    ctx.beginPath(); ctx.moveTo(-sx * 0.4, -sy * 0.5); ctx.lineTo(sx * 0.1, -sy * 0.1); ctx.lineTo(-sx * 0.1, sy * 0.3); ctx.stroke();
  }
  if (bp.prism) {
    ctx.strokeStyle = `hsla(${(t * 90) % 360},80%,70%,0.8)`; ctx.lineWidth = 1.2;
    ctx.beginPath(); ctx.arc(0, 0, s * 0.65, t % 7, (t % 7) + 1.6); ctx.stroke();
  }

  // padrão (listras/manchas)
  if (bp.pattern === 'stripes') {
    ctx.save();
    ctx.beginPath(); ctx.ellipse(0, 0, sx, sy, 0, 0, 7); ctx.clip();
    ctx.strokeStyle = bp.patternColor; ctx.lineWidth = 2; ctx.globalAlpha = 0.6 * bp.alpha;
    for (let i = -2; i <= 2; i++) {
      ctx.beginPath(); ctx.moveTo(i * s * 0.45 - s, -s); ctx.lineTo(i * s * 0.45 + s * 0.4, s); ctx.stroke();
    }
    ctx.restore();
  } else if (bp.pattern === 'spots') {
    ctx.fillStyle = bp.patternColor; ctx.globalAlpha = 0.55 * bp.alpha;
    for (const sp of bp.spots) {
      ctx.beginPath();
      ctx.arc(Math.cos(sp.a) * sx * sp.d, Math.sin(sp.a) * sy * sp.d, s * sp.r, 0, 7);
      ctx.fill();
    }
    ctx.globalAlpha = 1;
  }

  // placas
  if (bp.plates > 0) {
    ctx.fillStyle = 'rgba(190,200,212,0.9)';
    for (let i = 0; i < bp.plates; i++) {
      const a = hd + Math.PI + (i - (bp.plates - 1) / 2) * 0.7;
      ctx.save();
      ctx.translate(Math.cos(a) * sx * 0.55, Math.sin(a) * sy * 0.55);
      ctx.rotate(a);
      ctx.fillRect(-2.4, -3, 4.8, 6);
      ctx.restore();
    }
  }

  // espinhos
  if (bp.spikes > 0) {
    ctx.fillStyle = bp.spikeColor || '#ddd';
    for (let i = 0; i < bp.spikes; i++) {
      const a = bp.phase + (i / bp.spikes) * Math.PI * 2;
      const bx = Math.cos(a) * sx * 0.9, by = Math.sin(a) * sy * 0.9;
      ctx.beginPath();
      ctx.moveTo(bx + Math.cos(a + 1.7) * 2, by + Math.sin(a + 1.7) * 2);
      ctx.lineTo(bx + Math.cos(a) * 5, by + Math.sin(a) * 5);
      ctx.lineTo(bx + Math.cos(a - 1.7) * 2, by + Math.sin(a - 1.7) * 2);
      ctx.closePath(); ctx.fill();
    }
  }

  // antenas
  if (bp.antennae > 0) {
    ctx.strokeStyle = bp.antennaColor || bodyColor; ctx.lineWidth = 1.5;
    ctx.fillStyle = bp.antennaColor || bodyColor;
    for (let i = 0; i < bp.antennae; i++) {
      const a = hd + (i - (bp.antennae - 1) / 2) * 0.5;
      const ex = Math.cos(a) * (sx + 6), ey = Math.sin(a) * (sy + 6) - 4;
      ctx.beginPath();
      ctx.moveTo(Math.cos(a) * sx * 0.6, Math.sin(a) * sy * 0.6 - 2);
      ctx.quadraticCurveTo(ex * 0.7, ey * 0.7 - 3, ex, ey);
      ctx.stroke();
      ctx.beginPath(); ctx.arc(ex, ey, 1.6, 0, 7); ctx.fill();
    }
  }

  // olhos
  const eyeSpread = Math.min(1.1, 0.35 + bp.eyes * 0.16);
  for (let i = 0; i < bp.eyes; i++) {
    const off = bp.eyes === 1 ? 0 : (i / (bp.eyes - 1) - 0.5) * eyeSpread;
    const a = hd + off;
    const ex = Math.cos(a) * sx * 0.5, ey = Math.sin(a) * sy * 0.5 - s * 0.15;
    const er = s * (bp.eyes > 3 ? 0.16 : 0.22);
    ctx.fillStyle = '#f2f2f2';
    ctx.beginPath(); ctx.arc(ex, ey, er, 0, 7); ctx.fill();
    ctx.fillStyle = '#15151c';
    ctx.beginPath(); ctx.arc(ex + Math.cos(hd) * er * 0.4, ey + Math.sin(hd) * er * 0.4, er * 0.5, 0, 7); ctx.fill();
  }

  // arma equipada
  if (c.weapon && !portrait) {
    const wa = hd + 0.8;
    const wc = elemColor(c.weapon.element);
    ctx.strokeStyle = wc; ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(Math.cos(wa) * sx * 0.8, Math.sin(wa) * sy * 0.8);
    ctx.lineTo(Math.cos(wa) * (sx + 9), Math.sin(wa) * (sy + 9) - 4);
    ctx.stroke();
    ctx.fillStyle = wc;
    ctx.beginPath();
    const tipx = Math.cos(wa) * (sx + 9), tipy = Math.sin(wa) * (sy + 9) - 4;
    ctx.moveTo(tipx, tipy - 3); ctx.lineTo(tipx + 2.5, tipy + 2); ctx.lineTo(tipx - 2.5, tipy + 2);
    ctx.closePath(); ctx.fill();
  }

  ctx.restore();
}

function drawVehicle(ctx, c, s, t) {
  const v = c.vehicle;
  const col = elemColor(v.element);
  ctx.fillStyle = col;
  if (v.element === E.AIR) { // planador
    ctx.globalAlpha = 0.6;
    ctx.beginPath(); ctx.ellipse(0, s * 0.5, s * 1.7, s * 0.4, 0, 0, 7); ctx.fill();
    ctx.globalAlpha = 1;
  } else if (v.element === E.ICE) { // trenó
    ctx.globalAlpha = 0.7;
    ctx.fillRect(-s, s * 0.4, s * 2, 3);
    ctx.globalAlpha = 1;
  } else { // carrinho
    ctx.fillRect(-s, s * 0.3, s * 2, 4);
    ctx.fillStyle = '#333';
    ctx.beginPath(); ctx.arc(-s * 0.6, s * 0.55 + 3, 2.5, 0, 7); ctx.arc(s * 0.6, s * 0.55 + 3, 2.5, 0, 7); ctx.fill();
  }
}


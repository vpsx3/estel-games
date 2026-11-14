# Balanceamento final (Godot) - Pegue o Ursinho

O dono do jogo autorizou mudar o balanceamento. O Godot e a **fonte da verdade**; `../index.html` (legado) ficou intocado
e passa a divergir. Os JSON de `data/legacy/` sao editados direto (`tools/extract_legacy_data.mjs` exige `--force`, pois
sobrescreveria estes valores). Os guardas de valores finais ficam em `tests/test_parity_guards.gd`.

`run._biome_base()` le primeiro o `BiomeConfig` (`data/biomes/biome_XX.tres`: `ghost_speed`, `ghost_spawn_rate`, `mech`) e so
depois `biomes.json`/`biome_mech.json`: **os dois lugares precisam ficar iguais** (o teste confere).

## Numeros (unidades legadas)

| Item | Antes | Agora | Onde |
|---|---|---|---|
| Velocidade base do urso | 3.3 | 4.3 | gameplay_lits BEAR_BASE_SPEED |
| CD base do pulo | 10 s | 8 s | JUMP_CD_BASE |
| Escala de ciclo: velocidade / taxa / minimo | +0.10 / -2 s / 5 s | +0.12 / -1 s / 6 s | CYCLE_SPEED_ADD, CYCLE_RATE_SUB, MIN_GHOST_SPAWN_RATE |
| GHOST_PHASE_SCALING | 0.10 | 0.03 | constants.json |
| Teto de dificuldade (diff_mult) | - | 0.93 | GHOST_DIFF_CAP |
| Teto de fantasmas | - | min(5 + fases, 14 + 2*ciclos, 18) | GHOST_CAP_* |
| Graca de spawn | - | 0.8 s | GHOST_SPAWN_GRACE |
| Invuln. pouso / fim da invisibilidade / teleporte | - | 0.3 / 0.6 / 0.5 s | JUMP_LAND_INVULN, INVISIBLE_END_INVULN, TELEPORT_INVULN |
| Explosao de Luz | empurra 2.2 cel. | empurra 3.0 cel. + atordoa 1.5 s | BURST_PUSH_CELLS, BURST_STUN |
| Pisao: raio de empurrao / atordoamento / duracao | - | 1.6 / 2.5 cel. / 2.0 s | STOMP_* |
| Ima: raio / puxada | - | 4 cel. / 6 cel/s | MAGNET_* |
| Orbes: intervalo | 8 s fixo | max(4, 8 / (1 + 0.15*(pool-1))) | ORB_INTERVAL_* |
| Mel do pote | 5 | min(15, 5 + fases) | HONEY_PICKUP_* |
| Bonus de mundo concluido | - | min(100, 10 * fases concluidas) | BIOME_CLEAR_HONEY |
| Intervalo do pote de mel | 12 s | 10 s | constants.json |
| Gelo: velocidade max. | 3.6 fixo | bear.speed * mult. de velocidade * (veneno) * 1.65; accel = accel * mx/3.6 | ICE_MAX_SPEED_MULT |
| Veneno: raio / debuff / cooldown | 80 / 0.6 / 1000 ms | 64 / 0.75 / 3000 ms | constants.json |
| Fixos: ghost_slow / spirit_trap / lightning / decoy | 15 / 15 / 50 / 30 s | 12 / 12 / 35 / 25 s | constants.json + buffs.json |
| Spray sonolento (mult / dur) | 0.7 / 3 s | 0.6 / 4 s | SPRAY_SLOW_* |
| Teia (prende) | 5 s | 4 s | BUFF_FX.spirit_trap |
| Morcegos freeze / Janelas frac, cd / Castelo gateFrac | 2 / 0.12, 12 / 0.5 | 1.2 / 0.08, 15 / 0.35 | biome_mech.json + .tres |

Fantasmas (`ghost_types.json`): velocidade comum 2.9, rapido 3.9, pesado 1.9, errante 2.9, venenoso 2.55;
`minPhase` 0/1/1/2/3 (so sorteia tipos com `minPhase <= fases concluidas`).

Biomas 1..10: `ghostSpeed` 0.62, 0.70, 0.78, 0.85, 0.91, 0.97, 1.01, 1.05, 1.08, 1.12;
`ghostSpawnRate` 12, 12, 11, 11, 10, 10, 9, 9, 8, 8.

Loja (`attrs.json`): speed_base +4%..+40%, jump_cd -4%..-40%, jump_ext +0.045..+0.45 s (por nivel; custos iguais);
pulo duplo 1500, reroll 1200.

## Sistemas

1. **Pulo desvia**: em pulo (`jump.active`) o urso nao e capturado; ao pousar `invuln >= 0.3` e `Events.bear_landed`.
2. **Teto de fantasmas** no spawn periodico e nas janelas (janela cheia entra em cooldown sem criar).
3. **Graca de spawn**: fantasma novo (nao o 1o da run) fica 0.8 s sem mover/capturar/envenenar/roubar (alpha 0.25 -> 1).
4. **Atordoamento** (`GhostModel.stunned`): igual a congelado para movimento/separacao.
5. **Lentidao nao se sobrescreve**: `min(mult)`, `max(timer)`.
6. **Teleporte seguro** (`run.safest_free_pos`, 5 melhores por distancia ao fantasma mais proximo) no buff e nos portais; invuln 0.5 s.
7. **Invisibilidade**: fantasmas vagam, nao envenenam, nao capturam; ao acabar `invuln >= 0.6`.
8. **Skills removidas**: dash, swap, rebound (e os ramos mortos de `apply_map_buff`).
9. **Skills novas (tipo `passive`, sem timer)**: Pisao (`stomp`) e Ima de Mel (`magnet`); `buffs.passives`, `has_passive`, `magnet_pulling`.
10. **Pool**: `selectable_pool()` exclui buffs de mapa ja no `spawn_pool`; `open_selection()` limpa pool/passivos/build.
11. **VFX** ligados: `stomp` (one-shot), `stun`, `ghost_boost`, `magnet` (loops). `VfxPlayer.spawn` devolve null se o asset faltar ou nao carregar.

#!/usr/bin/env python3
"""Gerador dos MAP_TEMPLATEs da Jornada do Ursinho (spec-jornada-ursinho).

Para cada um dos 10 biomas, busca seeds até encontrar um mapa 30x18 que:
  - tenha densidade de paredes dentro de ±2pp do alvo da spec;
  - passe no flood-fill de acessibilidade (todas as células livres conectadas);
  - tenha spawn de ursinho e fantasma válidos e afastados (≥10 células).

Uso:
  python3 generate_biome_maps.py          # imprime os templates em JS
  python3 generate_biome_maps.py --ascii  # imprime também a arte ASCII de cada mapa
"""
import random
import sys
from collections import deque

ROWS, COLS = 18, 30
TOTAL = ROWS * COLS

# (id, nome, densidade-alvo, estilo)  — densidades da tabela da spec
BIOME_PARAMS = [
    (1,  'Floresta Encantada',     0.38, 'scatter'),
    (2,  'Praia dos Coqueiros',    0.32, 'spaced'),
    (3,  'Montanha Gelada',        0.48, 'maze'),
    (4,  'Pantano Verde',          0.52, 'automata'),
    (5,  'Caverna dos Ecos',       0.62, 'rooms'),
    (6,  'Vila Assombrada',        0.58, 'blocks'),
    (7,  'Castelo do Rei',         0.67, 'symmetric'),
    (8,  'Ilhas Flutuantes',       0.46, 'lanes'),
    (9,  'Inferno Fofo',           0.63, 'corridors'),
    (10, 'Dimensao dos Fantasmas', 0.72, 'densemaze'),
]
DENSITY_TOL = 0.02
MIN_FREE = 80
MIN_SPAWN_DIST = 10  # células (euclidiana)


def new_grid(fill=0):
    g = [[fill] * COLS for _ in range(ROWS)]
    for c in range(COLS):
        g[0][c] = g[ROWS - 1][c] = 1
    for r in range(ROWS):
        g[r][0] = g[r][COLS - 1] = 1
    return g


def interior(g):
    for r in range(1, ROWS - 1):
        for c in range(1, COLS - 1):
            yield r, c


def free_cells(g):
    return [(r, c) for r, c in interior(g) if g[r][c] == 0]


def density(g):
    return sum(sum(row) for row in g) / TOTAL


def flood_count(g, start):
    seen = {start}
    q = deque([start])
    while q:
        r, c = q.popleft()
        for dr, dc in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nr, nc = r + dr, c + dc
            if 0 <= nr < ROWS and 0 <= nc < COLS and g[nr][nc] == 0 and (nr, nc) not in seen:
                seen.add((nr, nc))
                q.append((nr, nc))
    return seen


def is_connected(g):
    free = free_cells(g)
    if not free:
        return False
    return len(flood_count(g, free[0])) == len(free)


def connect_components(g, rng):
    """Liga todos os componentes livres ao maior, cavando caminhos em L."""
    while True:
        free = free_cells(g)
        if not free:
            return
        comp = flood_count(g, free[0])
        rest = [c for c in free if c not in comp]
        if not rest:
            return
        # par mais próximo entre o componente principal e o resto
        best = None
        for (r1, c1) in rest:
            for (r2, c2) in comp:
                d = abs(r1 - r2) + abs(c1 - c2)
                if best is None or d < best[0]:
                    best = (d, (r1, c1), (r2, c2))
        _, (r1, c1), (r2, c2) = best
        # cava caminho em L (limitado ao interior)
        r, c = r1, c1
        while r != r2:
            r += 1 if r2 > r else -1
            if 0 < r < ROWS - 1:
                g[r][c1] = 0
        while c != c2:
            c += 1 if c2 > c else -1
            if 0 < r2 < ROWS - 1:
                g[r2][c] = 0


def tune_density(g, rng, target):
    """Ajusta a densidade adicionando paredes seguras ou removendo paredes."""
    # remover paredes se denso demais
    attempts = 0
    while density(g) > target + DENSITY_TOL / 2 and attempts < 4000:
        attempts += 1
        r = rng.randrange(1, ROWS - 1)
        c = rng.randrange(1, COLS - 1)
        if g[r][c] == 1:
            # só remove se encostar em célula livre (evita buracos isolados)
            if any(g[r + dr][c + dc] == 0 for dr, dc in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                g[r][c] = 0
    # adicionar paredes se aberto demais (mantendo conectividade)
    attempts = 0
    while density(g) < target - DENSITY_TOL / 2 and attempts < 6000:
        attempts += 1
        r = rng.randrange(1, ROWS - 1)
        c = rng.randrange(1, COLS - 1)
        if g[r][c] == 0:
            g[r][c] = 1
            if not is_connected(g):
                g[r][c] = 0


# ---------- estilos de geração ----------

def init_scatter(g, rng, p):
    for r, c in interior(g):
        if rng.random() < p:
            g[r][c] = 1


def init_spaced(g, rng):
    """Obstáculos 1x1/2x2 espaçados — máximo de área aberta (praia)."""
    for _ in range(26):
        r = rng.randrange(2, ROWS - 3)
        c = rng.randrange(2, COLS - 3)
        w = rng.choice((1, 2))
        h = rng.choice((1, 2))
        for dr in range(h):
            for dc in range(w):
                g[r + dr][c + dc] = 1


def init_maze(g, rng):
    """Labirinto DFS em malha de 2 células (corredores estreitos)."""
    for r, c in interior(g):
        g[r][c] = 1
    cells = [(r, c) for r in range(1, ROWS - 1, 2) for c in range(1, COLS - 1, 2)]
    start = rng.choice(cells)
    g[start[0]][start[1]] = 0
    stack = [start]
    visited = {start}
    while stack:
        r, c = stack[-1]
        nbrs = [(r + dr, c + dc, r + dr // 2, c + dc // 2)
                for dr, dc in ((2, 0), (-2, 0), (0, 2), (0, -2))
                if (r + dr, c + dc) in set(cells) and (r + dr, c + dc) not in visited]
        if not nbrs:
            stack.pop()
            continue
        nr, nc, wr, wc = rng.choice(nbrs)
        g[nr][nc] = 0
        g[wr][wc] = 0
        visited.add((nr, nc))
        stack.append((nr, nc))


def init_automata(g, rng, p=0.50, steps=3):
    """Cellular automata — formas orgânicas e irregulares (pântano)."""
    init_scatter(g, rng, p)
    for _ in range(steps):
        ng = [row[:] for row in g]
        for r, c in interior(g):
            walls = sum(g[r + dr][c + dc]
                        for dr in (-1, 0, 1) for dc in (-1, 0, 1)
                        if not (dr == 0 and dc == 0))
            ng[r][c] = 1 if walls >= 5 else 0
        g[:] = ng


def init_rooms(g, rng):
    """Interior sólido com salas cavadas; conexões viram passagens únicas."""
    for r, c in interior(g):
        g[r][c] = 1
    for _ in range(9):
        h = rng.randrange(2, 5)
        w = rng.randrange(3, 6)
        r = rng.randrange(1, ROWS - 1 - h)
        c = rng.randrange(1, COLS - 1 - w)
        for dr in range(h):
            for dc in range(w):
                g[r + dr][c + dc] = 0


def init_blocks(g, rng):
    """Blocos grandes (casas) com ruas estreitas entre eles (vila)."""
    for _ in range(16):
        h = rng.randrange(2, 5)
        w = rng.randrange(2, 6)
        r = rng.randrange(1, max(2, ROWS - 1 - h))
        c = rng.randrange(1, max(2, COLS - 1 - w))
        for dr in range(h):
            for dc in range(w):
                g[r + dr][c + dc] = 1


def init_symmetric(g, rng):
    """Labirinto espelhado esquerda/direita (castelo)."""
    init_maze(g, rng)
    for r in range(1, ROWS - 1):
        for c in range(1, COLS // 2):
            g[r][COLS - 1 - c] = g[r][c]


def init_lanes(g, rng):
    """Clusters de parede separados por faixas livres horizontais (ilhas/pontes)."""
    lanes = (4, 9, 13)
    init_scatter(g, rng, 0.55)
    for r in lanes:
        for c in range(1, COLS - 1):
            g[r][c] = 0


def init_corridors(g, rng):
    """Corredores horizontais alternando largo/estreito (inferno)."""
    for r, c in interior(g):
        g[r][c] = 1
    r = 1
    wide = True
    while r < ROWS - 1:
        h = 2 if wide else 1
        for dr in range(h):
            if r + dr < ROWS - 1:
                for c in range(1, COLS - 1):
                    g[r + dr][c] = 0
        r += h + rng.choice((1, 2))
        wide = not wide
    # conexões verticais aleatórias
    for _ in range(10):
        c = rng.randrange(2, COLS - 2)
        r0 = rng.randrange(1, ROWS - 4)
        for dr in range(4):
            g[r0 + dr][c] = 0


INITS = {
    'scatter':   lambda g, rng: init_scatter(g, rng, 0.26),
    'spaced':    init_spaced,
    'maze':      init_maze,
    'automata':  init_automata,
    'rooms':     init_rooms,
    'blocks':    init_blocks,
    'symmetric': init_symmetric,
    'lanes':     init_lanes,
    'corridors': init_corridors,
    'densemaze': init_maze,
}


def pick_spawns(g):
    """Ursinho: célula livre mais próxima do centro. Fantasma: a mais distante dele."""
    free = free_cells(g)
    cr, cc = (ROWS - 1) / 2, (COLS - 1) / 2
    bear = min(free, key=lambda x: (x[0] - cr) ** 2 + (x[1] - cc) ** 2)
    ghost = max(free, key=lambda x: (x[0] - bear[0]) ** 2 + (x[1] - bear[1]) ** 2)
    dist = ((bear[0] - ghost[0]) ** 2 + (bear[1] - ghost[1]) ** 2) ** 0.5
    return bear, ghost, dist


def generate(bid, target, style, seed):
    rng = random.Random(seed)
    g = new_grid()
    INITS[style](g, rng)
    connect_components(g, rng)
    tune_density(g, rng, target)
    if not is_connected(g):
        return None
    if abs(density(g) - target) > DENSITY_TOL:
        return None
    if len(free_cells(g)) < MIN_FREE:
        return None
    bear, ghost, dist = pick_spawns(g)
    if dist < MIN_SPAWN_DIST:
        return None
    return g, bear, ghost


def main():
    show_ascii = '--ascii' in sys.argv
    print('// MAP_TEMPLATEs gerados por tools/generate_biome_maps.py')
    for bid, name, target, style in BIOME_PARAMS:
        result = None
        for seed in range(bid * 1000, bid * 1000 + 500):
            result = generate(bid, target, style, seed)
            if result:
                break
        if not result:
            print(f'// ERRO: bioma {bid} sem seed valida', file=sys.stderr)
            sys.exit(1)
        g, bear, ghost = result
        d = density(g)
        print(f'// Bioma {bid} — {name} | seed {seed} | densidade {d:.0%} (alvo {target:.0%}) | '
              f'bearSpawn c:{bear[1]} r:{bear[0]} | ghostSpawn c:{ghost[1]} r:{ghost[0]}')
        print('[')
        for row in g:
            print('  [' + ','.join(str(v) for v in row) + '],')
        print('],')
        if show_ascii:
            for r, row in enumerate(g):
                line = ''
                for c, v in enumerate(row):
                    if (r, c) == bear:
                        line += 'U'
                    elif (r, c) == ghost:
                        line += 'G'
                    else:
                        line += '#' if v else '.'
                print('// ' + line, file=sys.stderr)
            print(file=sys.stderr)


if __name__ == '__main__':
    main()

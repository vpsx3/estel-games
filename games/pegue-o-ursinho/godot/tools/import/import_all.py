"""E8 parte 1: copia a arte APROVADA (art_source/pixellab -> assets/) e gera TileSets, corner maps,
SpriteFrames, cenas de decor e marcadores de mecanica. Idempotente.
Uso (a partir de games/pegue-o-ursinho/godot):  python tools/import/import_all.py [etapa ...]
  etapas: tilesets decor mechanics markers bear vfx configs ghosts props   (sem argumento = todas)
  (E8 parte 2: ghosts = fantasmas 5 classes; props = isca, pote de mel, orbes de buff)
Depois:  godot --headless --path . --import
         godot --headless --path . --script res://tools/import/apply_to_levels.gd
Fontes aprovadas: art_source/pixellab/ledger*.csv (tileset, variacoes escolhidas, decor, mecanicas).
"""
import glob
import json
import os
import re
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_spriteframes as bsf          # noqa: E402
import pixellab_tileset_to_godot as ptg   # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
SRC = os.path.join(ROOT, "art_source", "pixellab")
BIO = os.path.join(SRC, "biomes")

B = {1: "biome_01_floresta_encantada", 2: "biome_02_praia_dos_coqueiros", 3: "biome_03_montanha_gelada",
     4: "biome_04_pantano_verde", 5: "biome_05_caverna_dos_ecos", 6: "biome_06_vila_assombrada",
     7: "biome_07_castelo_do_rei", 8: "biome_08_ilhas_flutuantes", 9: "biome_09_inferno_fofo",
     10: "biome_10_dimensao_dos_fantasmas"}
SLUG = {n: B[n][9:] for n in B}   # "floresta_encantada", ...


def var_files(n, sub, ids):
    return [os.path.join(BIO, B[n], sub, "var_%02d.png" % i) for i in ids]


def sel_files(n, sub="floor_selected"):
    return sorted(glob.glob(os.path.join(BIO, B[n], sub, "*.png")))


# tileset aprovado (ledger) + variacoes de piso escolhidas (picks do ledger / floor_selected)
TILESETS = {
    1: dict(src=os.path.join(SRC, "tilesets", B[1], "v3"), details=var_files(1, "variations", [0, 3, 4, 8, 10, 12])),
    2: dict(src=os.path.join(BIO, B[2], "tileset_v1"), details=var_files(2, "variations", [0, 4, 8, 12, 2, 10])),
    3: dict(src=os.path.join(BIO, B[3], "tileset_v1"), details=var_files(3, "variations", [0, 3, 5, 8, 12, 14])),
    4: dict(src=os.path.join(BIO, B[4], "tileset_v1_recolor"), details=var_files(4, "variations_v2", [0, 3, 5, 8, 10, 12])),
    5: dict(src=os.path.join(BIO, B[5], "tileset_v4"), details=var_files(5, "variations_v2", [0, 2, 4, 6, 8, 13])),
    6: dict(src=os.path.join(BIO, B[6], "tileset_v1"), details=sel_files(6)),
    7: dict(src=os.path.join(BIO, B[7], "tileset_v1"), details=sel_files(7)),
    8: dict(src=os.path.join(BIO, B[8], "tileset_v2"), details=sel_files(8), fix_gray=True,
             # tiles 12 e 14 vieram com artefato cinza/sem rim: refeitos girando tiles bons (13 e 10)
             rebuild=[("12", "10", "cw"), ("14", "13", "ccw")]),
    9: dict(src=os.path.join(BIO, B[9], "tileset_v2"), details=sel_files(9)),
    10: dict(src=os.path.join(BIO, B[10], "tileset_v2"), details=sel_files(10)),
}

# decor aprovado: (nome, arquivo relativo a biomes/<bioma>/)
DECOR = {
    1: [(n, "decor/%s/rotations/unknown.png" % n) for n in ("toadstools", "flores", "vaga_lume", "toco")],
    2: [(n, "decor/%s/rotations/unknown.png" % n) for n in ("estrela_do_mar", "guarda_sol", "balde", "concha")],
    3: [(n, "decor/%s/rotations/unknown.png" % n) for n in ("boneco_de_neve", "cristais", "treno", "monte_de_neve")],
    4: [(n, "decor/%s/rotations/unknown.png" % n) for n in ("taboas", "sapinho", "cogumelo", "tronco")],
    5: [(n, "decor/%s/rotations/unknown.png" % n) for n in ("cogumelos_luminosos", "estalagmites", "lanterna", "cristais")],
    6: [(n, "decor_%s/base.png" % n) for n in ("pumpkin", "black_cat", "lamp_post", "cottage_fence")],
    7: [(n, "decor_%s/base.png" % n) for n in ("torch", "armor", "statue", "vase")],
    8: [(n, "decor_%s/base.png" % n) for n in ("kite", "bluebird", "daisies")],
    9: [(n, "decor_%s/base.png" % n) for n in ("flame_sprite", "hot_spring", "campfire")],   # rock_face = candidato, fora
    10: [(n, "decor_%s/base.png" % n) for n in ("candle", "melting_clock", "star", "crystal_shard")],
}


def frames_of(d):
    return sorted(glob.glob(os.path.join(d, "frame_*.png")))


def cl(path):
    return ptg.clean_alpha(Image.open(path))


# ---------------------------------------------------------------- tilesets
def do_tilesets():
    for n, t in TILESETS.items():
        ptg.convert(t["src"], n, SLUG[n], fix_gray=t.get("fix_gray", False), details=t["details"], root=ROOT,
                    rebuild=t.get("rebuild"))


# ---------------------------------------------------------------- decor
DECOR_TSCN = """[gd_scene load_steps=2 format=3]

[ext_resource type="Texture2D" path="res://assets/decor/{slug}/{name}.png" id="1"]

[node name="{node}" type="Sprite2D"]
texture = ExtResource("1")
offset = Vector2(0, {oy})
"""


def do_decor():
    for n, items in DECOR.items():
        out = os.path.join(ROOT, "assets", "decor", SLUG[n])
        os.makedirs(out, exist_ok=True)
        for name, rel in items:
            im = cl(os.path.join(BIO, B[n], rel))
            im.save(os.path.join(out, name + ".png"))
            # origem = base da celula (pe do objeto): ancora do y-sort; objetos altos crescem para cima
            oy = 16 - im.height // 2
            open(os.path.join(out, name + ".tscn"), "w", newline="\n").write(DECOR_TSCN.format(
                slug=SLUG[n], name=name, node="".join(p.capitalize() for p in name.split("_")), oy=oy))
        print("decor %02d: %d" % (n, len(items)))


# ---------------------------------------------------------------- mecanicas
def anim(name, files, fps, loop=True):
    return {"name": name, "frames": [cl(f) for f in files], "fps": fps, "loop": loop}


def build(slot, anims):
    bsf.build("assets/mechanics/%s/%s_frames.tres" % (slot, slot), anims, root=ROOT)


def do_mechanics():
    b1 = os.path.join(BIO, B[1], "mechanics", "mushroom")
    build("mushroom", [anim("idle", frames_of(b1 + "/idle"), 6), anim("bounce", frames_of(b1 + "/bounce"), 16, False)])
    b2 = os.path.join(BIO, B[2], "mechanics")
    build("water", [anim("default", frames_of(b2 + "/water_tile/anim"), 3)])    # water_tile aprovado (1eedb8ab)
    build("foam", [anim("default", frames_of(b2 + "/foam/loop"), 8)])
    b4 = os.path.join(BIO, B[4], "mechanics", "lilypad")
    build("lilypad", [anim("float", frames_of(b4 + "/float"), 6), anim("sink", frames_of(b4 + "/sink"), 8, False)])
    b5 = os.path.join(BIO, B[5], "mechanics", "morcego", "fly")
    build("bat", [anim("fly_" + d, frames_of(b5 + "/" + d), 12) for d in ("south", "north", "east", "west")])
    b6 = os.path.join(BIO, B[6], "mech_window_eyes")
    build("window_eyes", [anim("blink", frames_of(b6 + "/blink"), 8), anim("glow", frames_of(b6 + "/glow"), 8)])
    b7 = os.path.join(BIO, B[7])
    build("gate", [anim("open_close", frames_of(b7 + "/mech_gate/open_close"), 9, False)])
    carpets = sorted(glob.glob(b7 + "/carpet_selected/*.png"))
    build("carpet", [anim("v%d" % i, [f], 1, False) for i, f in enumerate(carpets)])
    b8 = os.path.join(BIO, B[8], "mech_platform")
    build("platform", [anim("float", frames_of(b8 + "/float"), 7)])
    b9 = os.path.join(BIO, B[9])
    build("geyser", [anim("idle", frames_of(b9 + "/mech_geyser/geyser_idle"), 8),
                     anim("fire", frames_of(b9 + "/mech_geyser/geyser_fire"), 14, False)])
    build("fire_trail", [anim("default", frames_of(b9 + "/mech_fire_trail/fire_trail"), 10)])
    b10 = os.path.join(BIO, B[10], "mech_portal", "spiral")
    build("portal", [anim("default", frames_of(b10), 9)])
    print("mecanicas: ok")


MARKER = """[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/gameplay/mech_marker.gd" id="1"]
[ext_resource type="SpriteFrames" path="{frames}" id="2"]

[node name="{node}" type="Node2D"]
script = ExtResource("1")
kind = "{kind}"
{props}
[node name="Sprite" type="AnimatedSprite2D" parent="."]
{sprop}sprite_frames = ExtResource("2")
animation = &"{anim}"
autoplay = "{anim}"
"""

# (kind, no, slot, animacao, props extras do MechMarker)
MARKERS = [
    ("bat_spawn", "BatSpawn", "bat", "fly_south", ""),
    ("carpet", "Carpet", "carpet", "v0", "length_cells = 3\n"),
    ("gate", "Gate", "gate", "open_close", ""),
    ("geyser", "Geyser", "geyser", "idle", ""),
    ("lilypad", "Lilypad", "lilypad", "float", ""),
    ("mushroom", "Mushroom", "mushroom", "idle", ""),
    ("platform", "Platform", "platform", "float", ""),
    ("portal", "Portal", "portal", "default", ""),
    ("window", "Window", "window_eyes", "blink", "radius_cells = -1.0\n"),
]


def do_markers():
    for kind, node, slot, an, props in MARKERS:
        open(os.path.join(ROOT, "scenes", "mechanics", kind + ".tscn"), "w", newline="\n").write(
            MARKER.format(frames="res://assets/mechanics/%s/%s_frames.tres" % (slot, slot), node=node, kind=kind,
                          props=props, anim=an, sprop=""))
    # vento: o marcador usa o VFX 'wind' (corrente de ar), so no editor
    open(os.path.join(ROOT, "scenes", "mechanics", "wind.tscn"), "w", newline="\n").write(
        MARKER.format(frames="res://assets/vfx/wind/wind_frames.tres", node="Wind", kind="wind",
                      props="length_cells = 4\n", anim="default",
                      sprop="modulate = Color(1, 1, 1, 0.8)\nscale = Vector2(0.5, 0.5)\n"))


# ---------------------------------------------------------------- urso
BEAR = os.path.join(SRC, "actors", "bear", "cand_b", "animations")
BEAR_SHADOW = (129, 128, 128)   # sombra cinza solta do walk/north
CANVAS = 64


def _strip_shadow(im):
    px = im.load()
    n = 0
    for y in range(im.height):
        for x in range(im.width):
            p = px[x, y]
            if p[3] > 0 and (p[0], p[1], p[2]) == BEAR_SHADOW:
                px[x, y] = (0, 0, 0, 0)
                n += 1
    return n


def _bbox(im):
    return im.getchannel("A").point(lambda v: 255 if v else 0).getbbox()


def _to_canvas(im, dy=0):
    out = Image.new("RGBA", (CANVAS, CANVAS))
    out.paste(im, ((CANVAS - im.width) // 2, CANVAS - im.height + dy))   # centro-base
    return out


def bear_frames():
    """{(anim, dir): [Image 64x64]} alinhados pelo centro-base; canvas maior (60/64) tem os pes do 1o
    frame igualados aos do idle da mesma direcao."""
    raw = {}
    stripped = 0
    for a in sorted(os.listdir(BEAR)):
        for d in sorted(os.listdir(os.path.join(BEAR, a))):
            fs = sorted(glob.glob(os.path.join(BEAR, a, d, "frame_*.png")))
            ims = [ptg.clean_alpha(Image.open(f)) for f in fs]
            for im in ims:
                stripped += _strip_shadow(im)
            raw[(a, d)] = ims
    out = {}
    idle_ref = {d: _bbox(_to_canvas(raw[("idle", d)][0])) for d in ("south", "north", "east", "west")}
    for (a, d), ims in raw.items():
        ref = idle_ref[d]
        dy = 0
        if ims[0].width > 48:
            dy = ref[3] - _bbox(_to_canvas(ims[0]))[3]
        frames = [_to_canvas(im, dy) for im in ims]
        for f in frames:
            bb = _bbox(f)
            assert bb[1] >= 0 and bb[3] <= CANVAS, (a, d, bb)
        out[(a, d)] = frames
    print("urso: sombra cinza removida (%d px)" % stripped)
    return out


def do_bear():
    fr = bear_frames()
    anims = []
    fps = {"idle": 4, "walk": 10, "dash": 14, "jump": 16, "caught": 10, "celebrate": 10}
    loop = {"idle": True, "walk": True, "dash": True, "jump": False, "caught": False, "celebrate": False}
    for a in ("idle", "walk", "dash", "jump"):
        for d in ("south", "north", "east", "west"):
            anims.append({"name": "%s_%s" % (a, d), "frames": fr[(a, d)], "fps": fps[a], "loop": loop[a]})
    for a in ("caught", "celebrate"):
        anims.append({"name": a, "frames": fr[(a, "south")], "fps": fps[a], "loop": loop[a]})
    bsf.build("assets/actors/bear/bear_frames.tres", anims, root=ROOT)
    print("urso: bear_frames.tres (%d animacoes)" % len(anims))


# ---------------------------------------------------------------- vfx
def do_vfx():
    n = 0
    for d in sorted(os.listdir(os.path.join(SRC, "vfx"))):
        e = json.load(open(os.path.join(SRC, "vfx", d, "effect.json"), encoding="utf8"))
        whole = [c for c in e["clips"] if c["name"] == "whole"][0]
        fs = sorted(glob.glob(os.path.join(SRC, "vfx", d, "frames", "whole_*.png")))
        assert fs, d
        meta = {"anchor": '"%s"' % e["anchor"]["kind"],
                "offset": "Vector2(%d, %d)" % (whole["offset"]["x"], whole["offset"]["y"]),
                "loop": "true" if e["loop"] else "false"}
        bsf.build("assets/vfx/%s/%s_frames.tres" % (d, d),
                  [{"name": "default", "frames": [cl(f) for f in fs], "fps": e["fps"], "loop": bool(e["loop"])}],
                  root=ROOT, meta=meta)
        n += 1
    print("vfx: %d efeitos" % n)


# ---------------------------------------------------------------- fantasmas / isca / mel / orbes (E8 parte 2)
GHOSTS = ("comum", "rapido", "pesado", "errante", "venenoso")   # canvas 48/42/68/48/48, centro, 1:1
ACT = os.path.join(SRC, "actors")
COL = os.path.join(SRC, "collectibles")
# orbe por raridade (comum=verde, incomum=azul, raro=vermelho)
ORBS = ("buff_orb_verde", "buff_orb_azul", "buff_orb_vermelho")


def do_ghosts():
    for c in GHOSTS:
        anims = [anim("float_" + d, frames_of(os.path.join(ACT, "ghosts", c, "float", d)), 8)
                 for d in ("south", "north", "east", "west")]
        assert all(len(a["frames"]) == 6 for a in anims), c
        bsf.build("assets/actors/ghosts/%s_frames.tres" % c, anims, root=ROOT)
    print("fantasmas: %d SpriteFrames" % len(GHOSTS))


def _diameter(im):
    """diametro equivalente (pela area opaca) do corpo; ignora faiscas soltas."""
    h = im.getchannel("A").histogram()
    n = sum(h[1:])
    return (4.0 * n / 3.14159265) ** 0.5


def do_props():
    fs = frames_of(os.path.join(ACT, "decoy", "wobble", "unknown"))
    assert len(fs) == 6
    bsf.build("assets/actors/decoy/decoy_frames.tres", [anim("wobble", fs, 8)], root=ROOT)
    fs = frames_of(os.path.join(COL, "honey_pot", "sparkle", "unknown"))   # honey_pot v2 (v1 reprovado fica fora)
    assert len(fs) == 6
    bsf.build("assets/collectibles/honey_pot/honey_pot_frames.tres", [anim("sparkle", fs, 8)], root=ROOT)
    orbs = {o: [cl(f) for f in frames_of(os.path.join(COL, o, "pulse", "unknown"))] for o in ORBS}
    diam = {o: [_diameter(im) for im in ims] for o, ims in orbs.items()}
    ref = sum(sum(d) for d in diam.values()) / sum(len(d) for d in diam.values())   # diametro-alvo comum
    for o, ims in orbs.items():
        assert len(ims) == 6
        # escala por frame que uniformiza o diametro aparente (o orbe azul e menor e encolhe nos frames 3-5)
        sc = ", ".join("%.4f" % (ref / x) for x in diam[o])
        bsf.build("assets/collectibles/%s/%s_frames.tres" % (o, o),
                  [{"name": "pulse", "frames": ims, "fps": 8, "loop": True}], root=ROOT,
                  meta={"frame_scale": "PackedFloat32Array(%s)" % sc})
    print("props: isca, pote de mel, 3 orbes")


# ---------------------------------------------------------------- data/biomes/*.tres
def do_biome_configs():
    for n in B:
        p = os.path.join(ROOT, "data", "biomes", "biome_%02d.tres" % n)
        txt = open(p, encoding="utf8").read()
        txt = re.sub(r'\[ext_resource type="TileSet" path="[^"]*" id="(?!3_details)([^"]+)"\]',
                     lambda m: '[ext_resource type="TileSet" path="res://tilesets/biome_%02d.tres" id="%s"]' % (n, m.group(1)),
                     txt, count=1)
        if "3_details" not in txt:
            txt = re.sub(r'(\[ext_resource type="TileSet"[^\n]*\])',
                         lambda m: m.group(1) + '\n[ext_resource type="TileSet" path="res://tilesets/biome_%02d_details.tres" id="3_details"]' % n,
                         txt, count=1)
            txt = txt.rstrip("\n") + '\ndetail_tiles = ExtResource("3_details")\n'
        txt = re.sub(r'corner_map_path = "[^"]*"',
                     'corner_map_path = "res://tilesets/corner_maps/biome_%02d_%s.json"' % (n, SLUG[n]), txt)
        open(p, "w", newline="\n", encoding="utf8").write(txt)
    print("data/biomes/*.tres atualizados")


if __name__ == "__main__":
    os.chdir(ROOT)
    steps = sys.argv[1:] or ["tilesets", "decor", "mechanics", "markers", "bear", "vfx", "configs", "ghosts", "props"]
    table = {"tilesets": do_tilesets, "decor": do_decor, "mechanics": do_mechanics, "markers": do_markers,
             "bear": do_bear, "vfx": do_vfx, "configs": do_biome_configs,
             "ghosts": do_ghosts, "props": do_props}
    for s in steps:
        table[s]()

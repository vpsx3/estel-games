"""PixelLab get_topdown_tileset (PNG + tileset_metadata.json) -> TileSet Godot (dual-grid).

Gera, a partir de uma pasta de tileset aprovado:
  assets/tiles/<slug>/tileset.png            (PNG limpo: alfa 0/255; opcional: manchas cinza)
  tilesets/biome_XX.tres                     (TileSet 32 px, 1 AtlasSource com todos os tiles)
  tilesets/corner_maps/biome_XX_<slug>.json  (bitmask -> coord de atlas; formato do DualGridPainter)
  (opcional) assets/tiles/<slug>/details.png + tilesets/biome_XX_details.tres  (variacoes de piso)

Bitmask: NW=8, NE=4, SW=2, SE=1; canto 'upper' = parede. Suporta 16 tiles (standard) e 25 (pro):
quando varios tiles tem o mesmo bitmask, o primeiro (ordem do metadata) vence.

Uso (a partir de games/pegue-o-ursinho/godot):
  python tools/import/pixellab_tileset_to_godot.py <pasta_tileset> --biome 8 --slug ilhas_flutuantes \
      [--swap] [--fix-gray] [--details a.png b.png ...]
"""
import argparse
import json
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BIT = {"NW": 8, "NE": 4, "SW": 2, "SE": 1}
TILE = 32


def clean_alpha(img, threshold=128):
    """Alfa -> 0/255 (sem semitransparencia); RGB de pixel transparente zerado."""
    img = img.convert("RGBA")
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a == 0 or a == 255:
                if a == 0:
                    px[x, y] = (0, 0, 0, 0)
                continue
            px[x, y] = (r, g, b, 255) if a >= threshold else (0, 0, 0, 0)
    return img


def _is_gray(p):
    r, g, b, a = p
    return a > 0 and max(r, g, b) - min(r, g, b) <= 14 and 150 < min(r, g, b) < 240


def fix_gray_patches(img, tiles):
    """Remove manchas cinza opacas (bug do bioma 8): nos quadrantes cujo canto e 'upper', copia o
    pixel do mesmo ponto do tile plano 'upper' (4 cantos upper); em 'lower', usa o tile plano lower."""
    flat = {}
    for t in tiles:
        vals = set(t["corners"].values())
        if len(vals) == 1:
            flat[vals.pop()] = t["bounding_box"]
    if "upper" not in flat or "lower" not in flat:
        return img, 0
    px = img.load()
    fixed = 0
    half = TILE // 2
    quad = {"NW": (0, 0), "NE": (half, 0), "SW": (0, half), "SE": (half, half)}
    for t in tiles:
        bb = t["bounding_box"]
        for qn, (qx, qy) in quad.items():
            src = flat[t["corners"][qn]]
            for y in range(qy, qy + half):
                for x in range(qx, qx + half):
                    p = px[bb["x"] + x, bb["y"] + y]
                    if _is_gray(p):
                        px[bb["x"] + x, bb["y"] + y] = px[src["x"] + x, src["y"] + y]
                        fixed += 1
    return img, fixed


def rebuild_tiles(img, tiles, rules):
    """Refaz tiles quebrados girando um tile bom: rules = [(id_alvo, id_fonte, 'cw'|'ccw')].
    Confere que os cantos do fonte girado batem com os do alvo (senao aborta)."""
    by_id = {t["id"]: t for t in tiles}
    cw = {"NW": "NE", "NE": "SE", "SE": "SW", "SW": "NW"}   # canto -> destino ao girar 90 horario
    for tgt, srcid, way in rules:
        t, s = by_id[tgt], by_id[srcid]
        mp = cw if way == "cw" else {v: k for k, v in cw.items()}
        rotated = {mp[k]: v for k, v in s["corners"].items()}
        assert rotated == t["corners"], (tgt, srcid, way, rotated, t["corners"])
        sb, tb = s["bounding_box"], t["bounding_box"]
        tile = img.crop((sb["x"], sb["y"], sb["x"] + TILE, sb["y"] + TILE))
        tile = tile.transpose(Image.ROTATE_270 if way == "cw" else Image.ROTATE_90)
        img.paste(tile, (tb["x"], tb["y"]))
    return img


def tres_atlas(res_png, cols_rows, size=TILE, extra_header=""):
    lines = ['[gd_resource type="TileSet" load_steps=3 format=3]', "",
             '[ext_resource type="Texture2D" path="%s" id="1_tex"]' % res_png, "",
             '[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_1"]',
             'texture = ExtResource("1_tex")',
             "texture_region_size = Vector2i(%d, %d)" % (size, size)]
    for (c, r) in cols_rows:
        lines.append("%d:%d/0 = 0" % (c, r))
    lines += ["", "[resource]", "tile_size = Vector2i(%d, %d)" % (size, size),
              'sources/0 = SubResource("TileSetAtlasSource_1")']
    return "\n".join(lines) + "\n"


def convert(src_dir, biome, slug, swap=False, fix_gray=False, details=None, root=ROOT, rebuild=None):
    meta = json.load(open(os.path.join(src_dir, "tileset_metadata.json"), encoding="utf8"))
    tiles = meta["tileset_data"]["tiles"]
    size = int(meta["tileset_data"]["tile_size"]["width"])
    assert size == TILE, "tile_size %d != 32" % size
    img = Image.open(os.path.join(src_dir, "tileset.png")).convert("RGBA")
    img = clean_alpha(img)
    if rebuild:
        img = rebuild_tiles(img, tiles, rebuild)
    fixed = 0
    if fix_gray:
        img, fixed = fix_gray_patches(img, tiles)
    out_dir = os.path.join(root, "assets", "tiles", slug)
    os.makedirs(out_dir, exist_ok=True)
    img.save(os.path.join(out_dir, "tileset.png"))

    cmap = {}
    coords = []
    for t in tiles:
        bb = t["bounding_box"]
        coord = [bb["x"] // size, bb["y"] // size]
        coords.append((coord[0], coord[1]))
        corners = t["corners"]
        if swap:
            corners = {k: ("lower" if v == "upper" else "upper") for k, v in corners.items()}
        b = sum(BIT[k] for k, v in corners.items() if v == "upper")
        cmap.setdefault(str(b), coord)
    assert len(cmap) == 16, "corner_map incompleto (%d/16): %s" % (len(cmap), sorted(cmap))
    cm_path = os.path.join(root, "tilesets", "corner_maps", "biome_%02d_%s.json" % (biome, slug))
    os.makedirs(os.path.dirname(cm_path), exist_ok=True)
    json.dump({"tile_size": size, "bit_order": "NW=8,NE=4,SW=2,SE=1", "source_id": 0,
               "tileset_id": meta.get("id", ""), "tile_count": len(tiles), "map": cmap},
              open(cm_path, "w"), indent=1)
    open(os.path.join(root, "tilesets", "biome_%02d.tres" % biome), "w", newline="\n").write(
        tres_atlas("res://assets/tiles/%s/tileset.png" % slug, coords))

    n_det = 0
    if details:
        n_det = make_details(details, biome, slug, root)
    print("bioma %02d %-22s tiles=%d corner_map=%s alfa_limpo gray_fix=%d detalhes=%d" % (
        biome, slug, len(tiles), os.path.basename(cm_path), fixed, n_det))


def make_details(files, biome, slug, root=ROOT, cols=3):
    n = len(files)
    rows = (n + cols - 1) // cols
    atlas = Image.new("RGBA", (cols * TILE, rows * TILE))
    coords = []
    for i, f in enumerate(files):
        im = clean_alpha(Image.open(f))
        assert im.size == (TILE, TILE), (f, im.size)
        atlas.paste(im, ((i % cols) * TILE, (i // cols) * TILE))
        coords.append((i % cols, i // cols))
    out_dir = os.path.join(root, "assets", "tiles", slug)
    os.makedirs(out_dir, exist_ok=True)
    atlas.save(os.path.join(out_dir, "details.png"))
    open(os.path.join(root, "tilesets", "biome_%02d_details.tres" % biome), "w", newline="\n").write(
        tres_atlas("res://assets/tiles/%s/details.png" % slug, coords))
    return n


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("src_dir")
    ap.add_argument("--biome", type=int, required=True)
    ap.add_argument("--slug", required=True)
    ap.add_argument("--swap", action="store_true", help="inverte lower/upper (terrenos trocados pelo modelo)")
    ap.add_argument("--fix-gray", action="store_true")
    ap.add_argument("--details", nargs="*", default=None)
    a = ap.parse_args()
    convert(a.src_dir, a.biome, a.slug, a.swap, a.fix_gray, a.details)

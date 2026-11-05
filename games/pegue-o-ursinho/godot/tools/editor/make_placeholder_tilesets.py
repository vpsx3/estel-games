"""Gera atlas dual-grid placeholder (4x4, 16 combinacoes) por bioma, corner_map e TileSet .tres.
Uso: python tools/editor/make_placeholder_tilesets.py   (a partir de games/pegue-o-ursinho/godot)
Bitmask: NW=8, NE=4, SW=2, SE=1; bit ligado = canto 'upper' = parede. Tile b -> atlas (b%4, b//4).
Tambem: --pixellab <tileset_metadata.json> <saida.json> converte metadados PixelLab em corner_map.
"""
import json, os, sys
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ASSETS = os.path.join(ROOT, "..", "assets", "biomes")
BIT = {"NW": 8, "NE": 4, "SW": 2, "SE": 1}


def tres_for(res_png, size, cols, rows, physics=None):
    lines = ['[gd_resource type="TileSet" load_steps=3 format=3]', "",
             '[ext_resource type="Texture2D" path="%s" id="1_tex"]' % res_png, "",
             '[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_1"]',
             "texture = ExtResource(\"1_tex\")",
             "texture_region_size = Vector2i(%d, %d)" % (size, size)]
    for r in range(rows):
        for c in range(cols):
            lines.append("%d:%d/0 = 0" % (c, r))
            if physics and (c, r) in physics:
                h = size // 2
                lines.append("%d:%d/0/physics_layer_0/polygon_0/points = PackedVector2Array(-%d, -%d, %d, -%d, %d, %d, -%d, %d)" % (c, r, h, h, h, h, h, h, h, h))
    lines += ["", "[resource]", "tile_size = Vector2i(%d, %d)" % (size, size)]
    if physics:
        lines.append("physics_layer_0/collision_layer = 1")
    lines.append('sources/0 = SubResource("TileSetAtlasSource_1")')
    return "\n".join(lines) + "\n"


def placeholder():
    maps = json.load(open(os.path.join(ROOT, "data/legacy/constants.json"), encoding="utf8"))["BIOME_SLUGS"]
    for slug in maps:
        floor = Image.open(os.path.join(ASSETS, slug, "floor.png")).convert("RGBA").resize((32, 32), Image.NEAREST)
        wall = Image.open(os.path.join(ASSETS, slug, "wall_a.png")).convert("RGBA").resize((32, 32), Image.NEAREST)
        atlas = Image.new("RGBA", (128, 128))
        cmap = {}
        for b in range(16):
            tile = Image.new("RGBA", (32, 32))
            for name, (qx, qy) in {"NW": (0, 0), "NE": (16, 0), "SW": (0, 16), "SE": (16, 16)}.items():
                src = wall if b & BIT[name] else floor
                tile.paste(src.crop((qx, qy, qx + 16, qy + 16)), (qx, qy))
            atlas.paste(tile, ((b % 4) * 32, (b // 4) * 32))
            cmap[str(b)] = [b % 4, b // 4]
        name = slug.replace("-", "_")
        atlas.save(os.path.join(ROOT, "tilesets/placeholder/%s.png" % slug))
        open(os.path.join(ROOT, "tilesets/placeholder/%s.tres" % slug), "w", newline="\n").write(
            tres_for("res://tilesets/placeholder/%s.png" % slug, 32, 4, 4))
        json.dump({"tile_size": 32, "bit_order": "NW=8,NE=4,SW=2,SE=1", "source_id": 0, "map": cmap},
                  open(os.path.join(ROOT, "tilesets/corner_maps/biome_%s.json" % name), "w"), indent=1)
    # editor_logic: piso claro (0,0) e parede escura com X (1,0)
    img = Image.new("RGBA", (64, 32))
    for y in range(32):
        for x in range(32):
            img.putpixel((x, y), (214, 222, 200, 255) if (x in (0, 31) or y in (0, 31)) is False else (170, 180, 160, 255))
            img.putpixel((32 + x, y), (40, 36, 52, 255) if (x in (0, 31) or y in (0, 31)) is False else (90, 80, 110, 255))
    for i in range(3, 29):
        for t in (0, 1, 2):
            for (px, py) in ((i + t, i), (31 - i - t, i)):
                if 0 <= px < 32:
                    img.putpixel((32 + px, py), (230, 90, 90, 255))
    img.save(os.path.join(ROOT, "tilesets/editor_logic.png"))
    open(os.path.join(ROOT, "tilesets/editor_logic.tres"), "w", newline="\n").write(
        tres_for("res://tilesets/editor_logic.png", 32, 2, 1, physics={(1, 0)}))


def pixellab(meta, out):
    tiles = json.load(open(meta, encoding="utf8"))["tileset_data"]["tiles"]
    cmap = {}
    for t in tiles:
        b = sum(BIT[k] for k, v in t["corners"].items() if v == "upper")
        bb = t["bounding_box"]
        cmap[str(b)] = [bb["x"] // bb["width"], bb["y"] // bb["height"]]
    assert len(cmap) == 16, len(cmap)
    json.dump({"tile_size": 32, "bit_order": "NW=8,NE=4,SW=2,SE=1", "source_id": 0, "map": cmap}, open(out, "w"), indent=1)


if __name__ == "__main__":
    if len(sys.argv) >= 4 and sys.argv[1] == "--pixellab":
        pixellab(sys.argv[2], sys.argv[3])
    else:
        placeholder()

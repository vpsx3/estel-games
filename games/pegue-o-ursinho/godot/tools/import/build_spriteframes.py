"""Frames PNG -> atlas PNG + SpriteFrames .tres (AtlasTexture por frame).

Uso como biblioteca:
    build(out_tres, anims, root=ROOT, atlas=None)
      out_tres : caminho relativo ao projeto (ex.: "assets/actors/bear/bear_frames.tres")
      anims    : lista de {"name": str, "frames": [caminhos PNG ou PIL.Image], "fps": float, "loop": bool}
      atlas    : PNG do atlas (default: mesmo nome do .tres com _atlas.png)
      meta     : dict opcional {chave: literal Godot} gravado como metadata/<chave> no .tres
Uso CLI:  python tools/import/build_spriteframes.py spec.json
  spec.json = {"out": "...tres", "animations": [{"name":..., "frames":[...], "fps":.., "loop":..}]}
Todos os frames de um atlas sao colados centralizados em celulas do mesmo tamanho (maior frame);
o AnimatedSprite2D deve usar centered=true (ou offset coerente) para o conjunto.
"""
import json
import math
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def _load(f):
    return f.convert("RGBA") if isinstance(f, Image.Image) else Image.open(f).convert("RGBA")


def build(out_tres, anims, root=ROOT, atlas=None, max_cols=8, meta=None):
    atlas = atlas or out_tres[:-5] + "_atlas.png"
    frames = []   # (anim_idx, Image)
    for ai, a in enumerate(anims):
        for f in a["frames"]:
            frames.append((ai, _load(f)))
    cw = max(im.width for _, im in frames)
    ch = max(im.height for _, im in frames)
    cols = min(max_cols, len(frames))
    rows = math.ceil(len(frames) / cols)
    sheet = Image.new("RGBA", (cols * cw, rows * ch))
    regions = []
    for i, (_, im) in enumerate(frames):
        x, y = (i % cols) * cw, (i // cols) * ch
        sheet.paste(im, (x + (cw - im.width) // 2, y + (ch - im.height) // 2))
        regions.append((x, y))
    atlas_fs = os.path.join(root, atlas)
    os.makedirs(os.path.dirname(atlas_fs), exist_ok=True)
    sheet.save(atlas_fs)

    n = len(frames)
    L = ['[gd_resource type="SpriteFrames" load_steps=%d format=3]' % (n + 2), "",
         '[ext_resource type="Texture2D" path="res://%s" id="1_atlas"]' % atlas, ""]
    for i, (x, y) in enumerate(regions):
        L += ['[sub_resource type="AtlasTexture" id="AtlasTexture_%d"]' % i,
              'atlas = ExtResource("1_atlas")',
              "region = Rect2(%d, %d, %d, %d)" % (x, y, cw, ch), ""]
    L.append("[resource]")
    L.append("animations = [")
    idx = 0
    parts = []
    for a in anims:
        fr = []
        for _ in a["frames"]:
            fr.append('{\n"duration": 1.0,\n"texture": SubResource("AtlasTexture_%d")\n}' % idx)
            idx += 1
        parts.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %s\n}' % (
            ", ".join(fr), "true" if a.get("loop", True) else "false", a["name"], float(a.get("fps", 10))))
    L.append(", ".join(parts))
    L.append("]")
    for k, v in (meta or {}).items():   # metadata/<k> = <literal Godot>
        L.append("metadata/%s = %s" % (k, v))
    out_fs = os.path.join(root, out_tres)
    os.makedirs(os.path.dirname(out_fs), exist_ok=True)
    open(out_fs, "w", newline="\n").write("\n".join(L) + "\n")
    return (cw, ch)


if __name__ == "__main__":
    spec = json.load(open(sys.argv[1], encoding="utf8"))
    print(build(spec["out"], spec["animations"]))

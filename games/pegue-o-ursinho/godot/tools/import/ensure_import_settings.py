"""Normaliza os .png.import de assets/ e tilesets/ para pixel-perfect (HANDOFF 3.2):
lossless (compress/mode=0), sem mipmaps, sem fix_alpha_border (nao mexe nas bordas do pixel art) e
sem deteccao 3D. O filtro "nearest" vem do projeto (default_texture_filter=0) e dos nos 2D.
Uso (apos `godot --headless --import`):  python tools/import/ensure_import_settings.py
Se algo mudou, rode o --import de novo para reimportar.
"""
import glob
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
WANT = {
    "compress/mode": "0",
    "compress/high_quality": "false",
    "mipmaps/generate": "false",
    "process/fix_alpha_border": "false",
    "process/premult_alpha": "false",
    "detect_3d/compress_to": "0",
}


def main():
    changed = total = 0
    for pat in ("assets/**/*.png.import", "tilesets/**/*.png.import"):
        for f in glob.glob(os.path.join(ROOT, pat), recursive=True):
            if os.sep + "ui" + os.sep in f.replace(ROOT, ""):
                continue   # assets/ui pertence ao ui-artist
            total += 1
            txt = open(f, encoding="utf8").read()
            new = txt
            for k, v in WANT.items():
                new = re.sub(r"(?m)^%s=.*$" % re.escape(k), "%s=%s" % (k, v), new)
            if new != txt:
                open(f, "w", encoding="utf8", newline="\n").write(new)
                changed += 1
    print("import settings: %d arquivos, %d ajustados" % (total, changed))


if __name__ == "__main__":
    main()

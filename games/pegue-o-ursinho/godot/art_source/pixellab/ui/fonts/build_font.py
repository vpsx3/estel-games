# Compoe fonte final: glifos do atlas PixelLab + acentos PT desenhados em pixel + travessoes.
import json
from PIL import Image
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont
import os
os.chdir(os.path.dirname(os.path.abspath(__file__)))
a = Image.open('atlas.png').convert('RGBA')
CH = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz.,!?:;'\"-+()0123456789/%*=_$"
G = {}
for i, ch in enumerate(CH):
    x, y = (i % 8) * 16, (i // 8) * 16
    G[ch] = {(c, r) for r in range(16) for c in range(16) if a.getpixel((x+c, y+r))[3] > 0}
raw = TTFont('UrsinhoCozy_raw.ttf'); cmap = raw.getBestCmap()
ADV = {ch: raw['hmtx'][cmap[ord(ch)]][0] for ch in CH if ord(ch) in cmap}
def bbox(s):
    xs = [p[0] for p in s]; ys = [p[1] for p in s]; return min(xs), min(ys), max(xs), max(ys)
SH = {  # forma por altura (linhas de cima para baixo), dx relativo ao centro
 'acute': {3:[(1,2),(0,1),(-1,0)], 2:[(0,1,2),(-1,0,1)]},
 'circ':  {3:[(0,1),(-1,0,1,2),(-2,-1,2,3)], 2:[(0,1),(-1,0,1,2)]},
 'tilde': {3:[(-1,1),(-2,0)], 2:[(-1,1),(-2,0)]},
}
SH['grave'] = {h: [tuple(1-d for d in row) for row in rows] for h, rows in SH['acute'].items()}
def with_accent(base, kind, upper):
    s = set(G[base])
    if base.lower() == 'i':
        s = {p for p in s if 6 <= p[1] <= 12} | {(6,5),(7,5),(8,5)}
    x0, y0, x1, _ = bbox(s)
    top = 5 if base.lower() == 'i' and not upper else y0
    cx = (x0 + x1) // 2
    bottom = top - 2
    h = 3 if bottom >= 2 else 2
    rows = SH[kind][h]
    if kind == 'tilde': h = 2; rows = SH[kind][2]
    for k, row in enumerate(rows):
        r = bottom - (len(rows) - 1) + k
        for d in row: s.add((cx + d, r))
    return s
def cedilla(base):
    s = set(G[base]); x0,_,x1,_ = bbox(s); cx=(x0+x1)//2
    s |= {(cx,13),(cx+1,13),(cx-1,14),(cx,14)}
    return s
NEW = {}
vow = {'a':'á à â ã','e':'é è ê ẽ','i':'í ì î ĩ','o':'ó ò ô õ','u':'ú ù û ũ'}
kinds = ['acute','grave','circ','tilde']
for v, lst in vow.items():
    for k, ch in zip(kinds, lst.split()):
        if ch in 'èẽìĩùûũîòû' and ch not in 'êîôûò': pass
        NEW[ch] = with_accent(v, k, False)
        NEW[ch.upper()] = with_accent(v.upper(), k, True)
NEW['ç'] = cedilla('c'); NEW['Ç'] = cedilla('C')
NEW['—'] = {(c, r) for c in range(1, 15) for r in (8, 9)}
NEW['–'] = {(c, r) for c in range(3, 13) for r in (8, 9)}
NEW[' '] = set(); NEW[' '] = set()
NEW['…'] = {(c,r) for r in (11,12) for c in (2,3, 7,8, 12,13)}
NEW['•'] = {(c,r) for c in (6,7,8,9) for r in (7,8,9,10)}
NEW['<'] = {(10,4),(11,4),(8,5),(9,5),(6,6),(7,6),(4,7),(5,7),(6,8),(7,8),(8,9),(9,9),(10,10),(11,10)}
NEW['>'] = {(15-x,y) for x,y in NEW['<']}

def P(*rows, ox=0, oy=0):
    return {(c+ox, r+oy) for r, line in enumerate(rows) for c, ch in enumerate(line) if ch == '#'}
NEW['·'] = P('##', '##', ox=7, oy=7)
NEW['º'] = P('.##.', '#..#', '#..#', '.##.', ox=6, oy=3)
NEW['ª'] = P('.##.', '#..#', '.###', '####', '....', '####', ox=6, oy=3)
NEW['×'] = P('##...##', '.##.##.', '..###..', '.##.##.', '##...##', ox=4, oy=5)
NEW['−'] = {(c, r) for c in range(4, 12) for r in (8, 9)}
NEW['→'] = P('........#...', '........##..', '#########.#.', '#########..#', '........##..', '........#...'.replace('#','#'), ox=2, oy=5)
NEW['←'] = {(15 - x, y) for x, y in NEW['→']}
NEW['▶'] = P('#.......', '###.....', '#####...', '#######.', '#####...', '###.....', '#.......', ox=4, oy=5)
NEW['◆'] = P('...##...', '..####..', '.######.', '########', '########', '.######.', '..####..', '...##...', ox=4, oy=4)
NEW['◇'] = P('...##...', '..#..#..', '.#....#.', '#......#', '#......#', '.#....#.', '..#..#..', '...##...', ox=4, oy=4)
NEW['★'] = P('....##....', '....##....', '...####...', '##########', '.########.', '..######..', '..######..', '.###..###.', '.##....##.', ox=3, oy=4)
NEW['⬆'] = P('...##...', '..####..', '.######.', '########', '..####..', '..####..', '..####..', '..####..', ox=4, oy=4)
NEW['#'] = P('.##..##.', '.##..##.', '########', '########', '.##..##.', '########', '########', '.##..##.', '.##..##.', ox=4, oy=4)
NEW['|'] = {(c, r) for c in (7, 8) for r in range(3, 15)}
NEW['['] = P('####', '##..', '##..', '##..', '##..', '##..', '##..', '##..', '##..', '####', ox=5, oy=3)
NEW[']'] = {(15 - x + 0, y) for x, y in NEW['[']}
ALL = dict(G); ALL.update(NEW)
adv = lambda ch: ADV.get(ch, ADV.get(ch.lower(), 800))
for ch in NEW:
    base = {'á':'a','à':'a','â':'a','ã':'a','é':'e','è':'e','ê':'e','ẽ':'e','í':'i','ì':'i','î':'i','ĩ':'i','ó':'o','ò':'o','ô':'o','õ':'o','ú':'u','ù':'u','û':'u','ũ':'u','ç':'c'}.get(ch.lower())
    if base: ADV[ch] = ADV[base.upper()] if ch.isupper() else ADV[base]
for _c in 'ºª×−→←▶◆◇★⬆#[]': ADV[_c]=832
ADV['·']=512; ADV['|']=512
ADV[' ']=ADV[' ']=512; ADV['—']=1024; ADV['–']=832; ADV['…']=1024; ADV['•']=832; ADV['<']=832; ADV['>']=832
U = 64
def glyph(s):
    pen = TTGlyphPen(None)
    rows = {}
    for c, r in s: rows.setdefault(r, []).append(c)
    for r, cs in rows.items():
        cs.sort(); runs = []; st = pr = cs[0]
        for c in cs[1:]:
            if c != pr + 1: runs.append((st, pr)); st = c
            pr = c
        runs.append((st, pr))
        for a_, b_ in runs:
            x0, x1 = a_ * U, (b_ + 1) * U
            y1 = (13 - r) * U; y0 = y1 - U
            pen.moveTo((x0, y0)); pen.lineTo((x0, y1)); pen.lineTo((x1, y1)); pen.lineTo((x1, y0)); pen.closePath()
    return pen.glyph()
names = ['.notdef']; cm = {}; gl = {'.notdef': glyph({(c,r) for c in range(2,12) for r in range(3,13) if c in (2,11) or r in (3,12)})}
metrics = {'.notdef': (832, 0)}
for ch, s in ALL.items():
    n = 'uni%04X' % ord(ch); names.append(n); cm[ord(ch)] = n; gl[n] = glyph(s)
    metrics[n] = (ADV.get(ch, 832), 0)
fb = FontBuilder(1024, isTTF=True)
fb.setupGlyphOrder(names); fb.setupCharacterMap(cm); fb.setupGlyf(gl)
fb.setupHorizontalMetrics(metrics)
fb.setupHorizontalHeader(ascent=832, descent=-192)
fb.setupNameTable({'familyName': 'UrsinhoCozy', 'styleName': 'Bold'})
fb.setupOS2(sTypoAscender=832, sTypoDescender=-192, usWinAscent=832, usWinDescent=192, sxHeight=512, sCapHeight=640)
fb.setupPost(); fb.save('UrsinhoCozy.ttf')
# cobertura
REQ = "áàâãéêíóôõúçÁÀÂÃÉÊÍÓÔÕÚÇ0123456789.,!?:;'\"-—()+/%*=_$ "
miss = [c for c in REQ if ord(c) not in cm]
print('missing', miss, 'glyphs', len(cm))
json.dump({'font':'UrsinhoCozy.ttf','pixel_size':16,'note':'use size multiple of 16, antialiasing off','codepoints':''.join(chr(k) for k in sorted(cm))}, open('UrsinhoCozy.json','w',encoding='utf8'), ensure_ascii=False, indent=1)
# amostra
from PIL import ImageFont, ImageDraw
def render(txt, scale, path, size=16):
    f = ImageFont.truetype('UrsinhoCozy.ttf', size)
    w = int(f.getlength(txt)) + 8
    im = Image.new('RGBA', (w, 28), (250,238,197,255)); d = ImageDraw.Draw(im); d.fontmode = '1'
    d.text((4, 3), txt, font=f, fill=(49,3,8,255))
    im.resize((im.width*scale, im.height*scale), Image.NEAREST).save(path)
render("Pegue o Ursinho — Ação, Coração, ÉPICO! 0123456789", 3, 'sample_main.png')
render("áàâãéêíóôõúç ÁÀÂÃÉÊÍÓÔÕÚÇ", 3, 'sample_accents.png')

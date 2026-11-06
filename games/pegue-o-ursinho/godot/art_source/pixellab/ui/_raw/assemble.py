# Monta os assets finais de painel/botao/card/barra/joystick/pulo a partir dos raw_*.png do PixelLab.
import os, colorsys, json
from PIL import Image
R = os.path.dirname(os.path.abspath(__file__)); P = os.path.join(R, '..', 'panels'); os.makedirs(P, exist_ok=True)
L = lambda n: Image.open(os.path.join(R, n)).convert('RGBA')
def crop(im, pad=0):
    bb = im.getbbox(); return im.crop((bb[0]-pad, bb[1]-pad, bb[2]+pad, bb[3]+pad))
def save(im, n): im.save(os.path.join(P, n))
def tint(im, f_v=1.0, f_s=1.0, add=0.0):
    out = im.copy(); px = out.load()
    for y in range(im.size[1]):
        for x in range(im.size[0]):
            r, g, b, a = px[x, y]
            if a == 0: continue
            h, s, v = colorsys.rgb_to_hsv(r/255, g/255, b/255)
            v = min(1, max(0, v*f_v + add)); s = min(1, s*f_s)
            r, g, b = [round(c*255) for c in colorsys.hsv_to_rgb(h, s, v)]
            px[x, y] = (r, g, b, a)
    return out
# painel
save(crop(L('raw_panel.png')), 'panel.png')
# botao (4 estados)
b = crop(L('raw_button.png'))
save(b, 'button_normal.png')
save(tint(b, 1.10, 0.95, 0.04), 'button_hover.png')
pr = tint(b, 0.82, 1.0); 
pp = Image.new('RGBA', b.size, (0,0,0,0)); pp.alpha_composite(pr, (0, 1)); save(pp, 'button_pressed.png')
save(tint(b, 0.95, 0.15, 0.0), 'button_disabled.png')
# cards por raridade a partir da moldura 'raro' (azul) -> verde / vermelho (rotacao de matiz so nos pixels azuis)
raro = crop(L('raw_card_raro.png'))
def recolor(im, target_h):
    out = im.copy(); px = out.load()
    for y in range(im.size[1]):
        for x in range(im.size[0]):
            r, g, b_, a = px[x, y]
            if a == 0: continue
            h, s, v = colorsys.rgb_to_hsv(r/255, g/255, b_/255)
            if 0.5 < h < 0.72 and s > 0.15:
                r, g, b_ = [round(c*255) for c in colorsys.hsv_to_rgb(target_h, s, v)]
                px[x, y] = (r, g, b_, a)
    return out
save(recolor(raro, 143/360), 'card_comum.png'); save(raro, 'card_incomum.png'); save(recolor(raro, 0/360), 'card_raro.png')
def darken_inner(im):
    out = im.copy(); px = out.load()
    for y in range(im.size[1]):
        for x in range(im.size[0]):
            r, g, b_, a = px[x, y]
            if a == 0: continue
            h, s, v = colorsys.rgb_to_hsv(r/255, g/255, b_/255)
            if s < 0.30 and v > 0.80: px[x, y] = (0x4A, 0x25, 0x30, 255)
            elif s < 0.35 and v > 0.62: px[x, y] = (0x3A, 0x1C, 0x26, 255)
    return out
for k in ('comum', 'incomum', 'raro'):
    save(darken_inner(Image.open(os.path.join(P, 'card_%s.png' % k)).convert('RGBA')), 'card_%s_dark.png' % k)
# botoes 2x (pixel doubling) e chip escuro (paineis pequenos, linhas, LineEdit)
for st in ('normal', 'hover', 'pressed', 'disabled'):
    im = Image.open(os.path.join(P, 'button_%s.png' % st)).convert('RGBA'); save(im.resize((im.size[0]*2, im.size[1]*2), Image.NEAREST), 'button_%s_x2.png' % st)
def plum(im):
    out = im.copy(); px = out.load()
    for y in range(im.size[1]):
        for x in range(im.size[0]):
            r, g, b_, a = px[x, y]
            if a == 0: continue
            h, s, v = colorsys.rgb_to_hsv(r/255, g/255, b_/255)
            r, g, b_ = [round(c*255) for c in colorsys.hsv_to_rgb(0.95, min(1, s*0.75), v*0.42)]
            px[x, y] = (r, g, b_, a)
    return out
save(plum(b), 'chip_dark.png')
# barra de tempo
bar = crop(L('raw_timebar_bg.png')); save(bar, 'timebar_bg.png')
W, H = 180, 20; f = Image.new('RGBA', (W, H), (0,0,0,0)); fp = f.load()
OUT=(0x99,0x39,0x20,255); BODY=(0xFF,0xC8,0x3D,255); HI=(0xFF,0xE4,0x8A,255); SH=(0xE9,0xA1,0x4D,255)
rad = 6
def inside(x, y):
    cx = min(max(x, rad), W-1-rad); cy = min(max(y, rad), H-1-rad)
    return (x-cx)**2 + (y-cy)**2 <= rad*rad + 1
for y in range(H):
    for x in range(W):
        if not inside(x, y): continue
        edge = not (inside(x-1,y) and inside(x+1,y) and inside(x,y-1) and inside(x,y+1))
        fp[x, y] = OUT if edge else (HI if y in (2,3) else (SH if y >= H-4 else BODY))
save(f, 'timebar_fill.png')
# joystick
save(crop(L('raw_joy_base.png')), 'joystick_base.png'); save(crop(L('raw_joy_knob.png')), 'joystick_knob.png')
# botao de pulo
if os.path.exists(os.path.join(R, 'raw_jump.png')):
    j = crop(L('raw_jump.png')); save(j, 'jump_normal.png'); save(tint(j, 0.62, 0.12), 'jump_cooldown.png')
print('ok')

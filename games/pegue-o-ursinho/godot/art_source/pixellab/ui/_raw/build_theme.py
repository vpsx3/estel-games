# Gera themes/cozy_theme.tres (StyleBoxTexture 9-slice + fonte UrsinhoCozy). Rodar da raiz godot/.
import os
P = 'res://assets/ui/panels/'
names = ['button_normal_x2', 'button_hover_x2', 'button_pressed_x2', 'button_disabled_x2', 'chip_dark',
         'card_comum_dark', 'card_incomum_dark', 'card_raro_dark', 'timebar_bg', 'timebar_fill', 'panel']
ext = ['[ext_resource type="Texture2D" path="%s%s.png" id="tex_%s"]' % (P, n, n) for n in names]
ext.append('[ext_resource type="FontFile" path="res://assets/ui/fonts/UrsinhoCozy.ttf" id="font_main"]')
subs = []


def quad(v):
    return v if isinstance(v, tuple) else (v, v, v, v)


def box(id_, tex, m, c, mod=None):
    ml, mt, mr, mb = quad(m)
    cl, ct, cr, cb = quad(c)
    s = '[sub_resource type="StyleBoxTexture" id="%s"]\ntexture = ExtResource("tex_%s")\n' % (id_, tex)
    s += 'texture_margin_left = %d\ntexture_margin_top = %d\ntexture_margin_right = %d\ntexture_margin_bottom = %d\n' % (ml, mt, mr, mb)
    s += 'content_margin_left = %d\ncontent_margin_top = %d\ncontent_margin_right = %d\ncontent_margin_bottom = %d\n' % (cl, ct, cr, cb)
    if mod:
        s += 'modulate_color = Color(%s, %s, %s, 1)\n' % mod
    subs.append(s)


btn = (20, 16, 20, 16)
box('btn_n', 'button_normal_x2', 16, btn)
box('btn_h', 'button_hover_x2', 16, btn)
box('btn_p', 'button_pressed_x2', 16, (20, 18, 20, 14))
box('btn_d', 'button_disabled_x2', 16, btn)
subs.append('[sub_resource type="StyleBoxFlat" id="focus"]\ndraw_center = false\nborder_width_left = 2\nborder_width_top = 2\nborder_width_right = 2\nborder_width_bottom = 2\nborder_color = Color(0.9804, 0.9333, 0.7725, 1)\ncorner_radius_top_left = 8\ncorner_radius_top_right = 8\ncorner_radius_bottom_right = 8\ncorner_radius_bottom_left = 8\n')
box('panel', 'chip_dark', 8, (12, 8, 12, 8))
box('panel_top', 'chip_dark', 8, (12, 8, 12, 8), (1.9, 1.55, 0.8))
box('panel_me', 'chip_dark', 8, (12, 8, 12, 8), (0.75, 1.5, 0.9))
box('line', 'chip_dark', 8, (14, 8, 14, 8))
box('line_focus', 'chip_dark', 8, (14, 8, 14, 8), (1.4, 1.3, 1.1))
box('line_bad', 'chip_dark', 8, (14, 8, 14, 8), (2.0, 0.8, 0.8))
box('card_n', 'chip_dark', 8, (24, 16, 24, 16))
box('card_h', 'chip_dark', 8, (24, 16, 24, 16), (1.35, 1.25, 1.0))
box('card_p', 'chip_dark', 8, (24, 16, 24, 16), (1.9, 1.55, 0.8))
for k in ('comum', 'incomum', 'raro'):
    box('cardr_%s_n' % k, 'card_%s_dark' % k, 24, (28, 20, 28, 20))
    box('cardr_%s_h' % k, 'card_%s_dark' % k, 24, (28, 20, 28, 20), (1.2, 1.2, 1.2))
    box('cardr_%s_p' % k, 'card_%s_dark' % k, 24, (28, 20, 28, 20), (1.9, 1.6, 0.9))
box('bar_bg', 'timebar_bg', (16, 14, 16, 13), (4, 4, 4, 4))
box('bar_fill', 'timebar_fill', 8, (0, 0, 0, 0))
box('bigpanel', 'panel', 40, (44, 44, 44, 44))

cream = 'Color(0.9804, 0.9333, 0.7725, 1)'
ink = 'Color(0.1922, 0.0118, 0.0314, 1)'
honey = 'Color(0.9529, 0.8549, 0.6078, 1)'
dim = 'Color(0.8431, 0.6549, 0.4784, 1)'
r = ['[resource]', 'default_font = ExtResource("font_main")', 'default_font_size = 16',
     'Label/colors/font_color = ' + cream, 'Label/colors/font_shadow_color = ' + ink,
     'Label/constants/shadow_offset_x = 1', 'Label/constants/shadow_offset_y = 1', 'Label/font_sizes/font_size = 16',
     'Button/colors/font_color = ' + ink, 'Button/colors/font_hover_color = ' + ink, 'Button/colors/font_pressed_color = ' + ink,
     'Button/colors/font_focus_color = ' + ink, 'Button/colors/font_disabled_color = Color(0.4784, 0.4157, 0.5569, 1)',
     'Button/font_sizes/font_size = 32',
     'Button/styles/normal = SubResource("btn_n")', 'Button/styles/hover = SubResource("btn_h")',
     'Button/styles/pressed = SubResource("btn_p")', 'Button/styles/hover_pressed = SubResource("btn_p")',
     'Button/styles/disabled = SubResource("btn_d")', 'Button/styles/focus = SubResource("focus")',
     'LineEdit/colors/font_color = ' + cream, 'LineEdit/colors/font_placeholder_color = ' + dim,
     'LineEdit/colors/caret_color = ' + cream, 'LineEdit/font_sizes/font_size = 32',
     'LineEdit/styles/normal = SubResource("line")', 'LineEdit/styles/focus = SubResource("line_focus")',
     'PanelContainer/styles/panel = SubResource("panel")', 'Panel/styles/panel = SubResource("panel")',
     'ProgressBar/styles/background = SubResource("bar_bg")', 'ProgressBar/styles/fill = SubResource("bar_fill")',
     'ProgressBar/constants/outline_size = 0',
     'InvalidLineEdit/base_type = &"LineEdit"', 'InvalidLineEdit/styles/normal = SubResource("line_bad")',
     'InvalidLineEdit/styles/focus = SubResource("line_bad")',
     'BigPanel/base_type = &"PanelContainer"', 'BigPanel/styles/panel = SubResource("bigpanel")',
     'BuffCard/base_type = &"Button"', 'BuffCard/colors/font_color = ' + cream,
     'BuffCard/styles/normal = SubResource("card_n")', 'BuffCard/styles/hover = SubResource("card_h")',
     'BuffCard/styles/pressed = SubResource("card_p")', 'BuffCard/styles/hover_pressed = SubResource("card_p")',
     'BuffCard/styles/focus = SubResource("focus")',
     'RankRowTop/base_type = &"PanelContainer"', 'RankRowTop/styles/panel = SubResource("panel_top")',
     'RankRowMe/base_type = &"PanelContainer"', 'RankRowMe/styles/panel = SubResource("panel_me")',
     'TitleLabel/base_type = &"Label"', 'TitleLabel/font_sizes/font_size = 48', 'TitleLabel/colors/font_color = ' + honey,
     'TitleLabel/constants/shadow_offset_x = 2', 'TitleLabel/constants/shadow_offset_y = 2',
     'HeaderLabel/base_type = &"Label"', 'HeaderLabel/font_sizes/font_size = 32', 'HeaderLabel/colors/font_color = ' + honey,
     'BigTimeLabel/base_type = &"Label"', 'BigTimeLabel/font_sizes/font_size = 64',
     'BigTimeLabel/constants/shadow_offset_x = 2', 'BigTimeLabel/constants/shadow_offset_y = 2',
     'HudBigLabel/base_type = &"Label"', 'HudBigLabel/font_sizes/font_size = 32',
     'WarningLabel/base_type = &"Label"', 'WarningLabel/font_sizes/font_size = 32', 'WarningLabel/colors/font_color = ' + honey,
     'WarningLabel/constants/shadow_offset_x = 2', 'WarningLabel/constants/shadow_offset_y = 2',
     'DimLabel/base_type = &"Label"', 'DimLabel/font_sizes/font_size = 16', 'DimLabel/colors/font_color = ' + dim,
     'RarityComum/base_type = &"Label"', 'RarityComum/colors/font_color = Color(0.4863, 0.8784, 0.6275, 1)',
     'RarityIncomum/base_type = &"Label"', 'RarityIncomum/colors/font_color = Color(0.5412, 0.7059, 1.0, 1)',
     'RarityRaro/base_type = &"Label"', 'RarityRaro/colors/font_color = Color(1.0, 0.5412, 0.5412, 1)']
for K, k in (('Comum', 'comum'), ('Incomum', 'incomum'), ('Raro', 'raro')):
    r += ['BuffCard%s/base_type = &"Button"' % K, 'BuffCard%s/colors/font_color = %s' % (K, cream),
          'BuffCard%s/styles/normal = SubResource("cardr_%s_n")' % (K, k), 'BuffCard%s/styles/hover = SubResource("cardr_%s_h")' % (K, k),
          'BuffCard%s/styles/pressed = SubResource("cardr_%s_p")' % (K, k), 'BuffCard%s/styles/hover_pressed = SubResource("cardr_%s_p")' % (K, k),
          'BuffCard%s/styles/focus = SubResource("focus")' % K]
txt = '[gd_resource type="Theme" load_steps=%d format=3]\n\n' % (len(ext) + len(subs) + 1)
txt += '\n'.join(ext) + '\n\n' + '\n'.join(subs) + '\n' + '\n'.join(r) + '\n'
open('themes/cozy_theme.tres', 'w', encoding='utf8').write(txt)
print('ok')

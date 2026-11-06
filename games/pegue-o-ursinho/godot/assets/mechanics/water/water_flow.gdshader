shader_type canvas_item;
// Agua da mare: atlas horizontal com `frames` quadros de 32 px (water_tile). Em espaco de mundo:
// anima os quadros (t = relogio de jogo), desliza a textura (scroll) e adiciona brilho (shimmer).
uniform float t = 0.0;
uniform int frames = 4;
uniform float fps = 3.0;
uniform vec2 scroll = vec2(5.0, 2.5);     // px/s
uniform float shimmer = 0.07;
uniform float opacity = 0.92;
varying vec2 wpos;

void vertex() {
	wpos = VERTEX;   // a camada fica na origem da WorldView = origem do mundo
}

void fragment() {
	vec2 p = (wpos + scroll * t) / 32.0;
	vec2 uv = fract(p);
	float f = floor(mod(t * fps, float(frames)));
	vec4 c = texture(TEXTURE, vec2((f + uv.x) / float(frames), uv.y));
	float sh = 0.5 + 0.5 * sin(t * 2.2 + wpos.x * 0.11 + wpos.y * 0.07);
	c.rgb += shimmer * sh * (1.0 - step(0.5, uv.y)) ;
	c.rgb += shimmer * 0.5 * sh;
	COLOR = vec4(c.rgb, c.a * opacity);
}

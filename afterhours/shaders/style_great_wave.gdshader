shader_type canvas_item;
// Hokusai, The Great Wave: a woodblock print. Flat colour bands, dark carved outlines,
// Prussian blue on paper, and the picture rocking on a slow swell.
#include "res://shaders/style_common.gdshaderinc"

// The swell: its sway (UV), how many waves fit down, how fast it rolls.
uniform float swell = 0.003;
uniform float swell_scale = 24.0;
uniform float speed = 1.2;
// Colour bands per channel; outline width (picture pixels) and darkness threshold.
uniform float bands = 5.0;
uniform float line = 1.5;
uniform float line_edge = 0.12;
uniform vec3 ink = vec3(0.08, 0.14, 0.3);
uniform vec3 paper = vec3(0.93, 0.87, 0.72);
// How far the bands lean towards the two-colour print palette.
uniform float print_tone = 0.45;

void fragment() {
	vec2 uv = STYLE_UV;
	vec2 at = uv + vec2(sin(uv.y * swell_scale + TIME * speed) * swell, 0.0);
	vec2 px = STYLE_PX * line;
	vec3 c = STYLE_READ(at).rgb;
	float gx = style_luma(STYLE_READ(at + vec2(px.x, 0.0)).rgb) - style_luma(STYLE_READ(at - vec2(px.x, 0.0)).rgb);
	float gy = style_luma(STYLE_READ(at + vec2(0.0, px.y)).rgb) - style_luma(STYLE_READ(at - vec2(0.0, px.y)).rgb);
	float edge = smoothstep(line_edge, line_edge * 2.0, length(vec2(gx, gy)));
	vec3 banded = floor(c * bands + 0.5) / bands;
	banded = mix(banded, mix(ink, paper, style_luma(banded)), print_tone);
	vec4 plain = STYLE_READ(uv);
	STYLE_OUT(plain, vec4(mix(banded, ink, edge), plain.a));
}

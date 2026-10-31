shader_type canvas_item;
// Seurat, A Sunday on La Grande Jatte: pointillism. The picture breaks into round dots of
// pure colour on pale paper, each dot nudged off its neighbours' hue, gently breathing.
#include "res://shaders/style_common.gdshaderinc"

// Dots across the picture; a dot's radius in its cell (0.5 touches the next).
uniform float dots = 70.0;
uniform float radius = 0.5;
// How much each dot breathes, and how fast.
uniform float breathe = 0.05;
uniform float speed = 0.8;
// How far a dot's colour strays per channel, and how strongly the paper shows between dots.
uniform float hue_jitter = 0.12;
uniform vec3 paper = vec3(0.93, 0.9, 0.82);
uniform float paper_show = 0.3;

void fragment() {
	vec2 uv = STYLE_UV;
	vec2 px = STYLE_PX;
	// Cells are square on screen: as many rows as the picture's height allows.
	vec2 grid = vec2(dots, dots * px.x / px.y);
	vec2 g = uv * grid;
	g.x += mod(floor(g.y), 2.0) * 0.5;
	vec2 cell = floor(g);
	vec2 centre = (cell + 0.5 - vec2(mod(cell.y, 2.0) * 0.5, 0.0)) / grid;
	float seed = style_hash(cell);
	vec3 dot_colour = STYLE_READ(centre).rgb;
	dot_colour += (vec3(style_hash(cell + 1.0), style_hash(cell + 2.0), style_hash(cell + 3.0)) - 0.5) * hue_jitter;
	float r = radius + breathe * sin(TIME * speed + seed * 6.2832);
	float in_dot = 1.0 - smoothstep(r - 0.08, r, length(fract(g) - 0.5));
	vec4 plain = STYLE_READ(uv);
	vec3 between = mix(plain.rgb, paper, paper_show);
	STYLE_OUT(plain, vec4(mix(between, dot_colour, in_dot), plain.a));
}

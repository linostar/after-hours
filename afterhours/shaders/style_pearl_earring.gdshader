shader_type canvas_item;
// Vermeer, Girl with a Pearl Earring: soft daylight from a window on the left, swaying a
// little as clouds pass; warm glaze, softened edges, the dark side falling into shadow.
#include "res://shaders/style_common.gdshaderinc"

// The window (UV, left of the picture), how far its light sways and how fast.
uniform vec2 window = vec2(-0.25, 0.2);
uniform float sway = 0.12;
uniform float speed = 0.3;
// Light near the window and in the far shadow; the softening blur (picture pixels).
uniform float lit = 1.3;
uniform float shadow = 0.4;
uniform float soften = 1.5;
uniform vec3 glaze = vec3(1.06, 1.0, 0.88);

void fragment() {
	vec2 uv = STYLE_UV;
	vec2 px = STYLE_PX * soften;
	vec3 c = (STYLE_READ(uv).rgb * 2.0 + STYLE_READ(uv + vec2(px.x, 0.0)).rgb + STYLE_READ(uv - vec2(px.x, 0.0)).rgb
		+ STYLE_READ(uv + vec2(0.0, px.y)).rgb + STYLE_READ(uv - vec2(0.0, px.y)).rgb) / 6.0;
	vec2 light_at = window + vec2(0.0, sin(TIME * speed) * sway);
	float aspect = px.y / px.x;
	float far = distance(uv * vec2(aspect, 1.0), light_at * vec2(aspect, 1.0));
	float light = mix(lit, shadow, smoothstep(0.3, 1.6, far));
	vec4 plain = STYLE_READ(uv);
	STYLE_OUT(plain, vec4(c * light * glaze, plain.a));
}

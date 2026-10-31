shader_type canvas_item;
// Leonardo, Mona Lisa: sfumato. Edges melt into smoke, the colours sink into a warm green
// haze that slowly breathes, and the corners darken like old varnish.
#include "res://shaders/style_common.gdshaderinc"

// The smoke's blur radius (UV) and how much of it shows, breathing by drift at speed.
uniform float smoke = 0.006;
uniform float smoke_mix = 0.6;
uniform float drift = 0.2;
uniform float speed = 0.35;
// The haze's colour and share; how dark the corners get.
uniform vec3 haze = vec3(0.55, 0.5, 0.33);
uniform float haze_mix = 0.18;
uniform float corners = 0.45;

void fragment() {
	vec2 uv = STYLE_UV;
	vec2 r = vec2(smoke * STYLE_PX.x / STYLE_PX.y, smoke);
	vec3 blur = vec3(0.0);
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.7854;
		blur += STYLE_READ(uv + vec2(cos(a), sin(a)) * r).rgb;
	}
	blur /= 8.0;
	vec3 c = STYLE_READ(uv).rgb;
	c = mix(c, blur, smoke_mix + drift * sin(TIME * speed));
	c = mix(c, haze * (0.5 + style_luma(c)), haze_mix);
	c *= 1.0 - corners * smoothstep(0.35, 0.75, length(uv - 0.5));
	vec4 plain = STYLE_READ(uv);
	STYLE_OUT(plain, vec4(c, plain.a));
}

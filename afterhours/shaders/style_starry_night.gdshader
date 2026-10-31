shader_type canvas_item;
// Van Gogh, The Starry Night: the picture flows in slow swirls, smeared into thick strokes
// along the flow, its blues and yellows glowing.
#include "res://shaders/style_common.gdshaderinc"

// How far the swirls push the picture (UV), how many swirls fit across, how fast they turn.
uniform float swirl = 0.006;
uniform float swirl_scale = 9.0;
uniform float speed = 0.25;
// A stroke's half length, in picture pixels.
uniform float stroke = 3.0;
uniform float saturation = 1.3;

void fragment() {
	vec2 uv = STYLE_UV;
	float t = TIME * speed;
	vec2 flow = vec2(
		sin(uv.y * swirl_scale + t + sin(uv.x * swirl_scale * 0.7 - t)),
		cos(uv.x * swirl_scale - t + cos(uv.y * swirl_scale * 0.8 + t)));
	vec2 at = uv + flow * swirl;
	vec2 along = normalize(vec2(flow.y, -flow.x) + 0.0001) * STYLE_PX * stroke;
	vec3 c = (STYLE_READ(at - along).rgb + STYLE_READ(at).rgb + STYLE_READ(at + along).rgb) / 3.0;
	c = mix(vec3(style_luma(c)), c, saturation);
	vec4 plain = STYLE_READ(uv);
	STYLE_OUT(plain, vec4(c, plain.a));
}

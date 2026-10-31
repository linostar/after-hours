shader_type canvas_item;
// Bosch, The Garden of Earthly Delights: crisp, tiny detail under old varnish. The picture
// is sharpened and warmed, its creatures squirm, and a soft glint drifts across the gloss.
#include "res://shaders/style_common.gdshaderinc"

// Sharpening (0 none) and its reach (picture pixels).
uniform float sharpen = 0.6;
uniform float reach = 1.0;
// The squirm: how far (UV), how fine, how fast.
uniform float squirm = 0.0012;
uniform float squirm_scale = 70.0;
uniform float speed = 1.0;
// The varnish: its tint, and the glint's brightness, width and drift speed.
uniform vec3 varnish = vec3(1.05, 1.0, 0.85);
uniform float glint = 0.1;
uniform float glint_width = 0.08;
uniform float glint_speed = 0.04;

void fragment() {
	vec2 uv = STYLE_UV;
	vec2 at = uv + vec2(sin(uv.y * squirm_scale + TIME * speed), cos(uv.x * squirm_scale + TIME * speed)) * squirm;
	vec2 px = STYLE_PX * reach;
	vec3 c = STYLE_READ(at).rgb;
	vec3 around = STYLE_READ(at + vec2(px.x, 0.0)).rgb + STYLE_READ(at - vec2(px.x, 0.0)).rgb
		+ STYLE_READ(at + vec2(0.0, px.y)).rgb + STYLE_READ(at - vec2(0.0, px.y)).rgb;
	c = c * (1.0 + 4.0 * sharpen) - around * sharpen;
	float band = abs(fract(uv.x + uv.y * 0.5 - TIME * glint_speed) - 0.5);
	c += glint * (1.0 - smoothstep(0.0, glint_width, band));
	vec4 plain = STYLE_READ(uv);
	STYLE_OUT(plain, vec4(clamp(c * varnish, 0.0, 1.0), plain.a));
}

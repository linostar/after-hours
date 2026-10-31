// Shared by the style shaders (one per painting, style_<id>.gdshader). A style reads its
// picture from the node's own texture (a framed painting, the forgery canvas) or, with
// use_screen, from the screen behind a full-screen rect (the hide-inside view), and mixes
// its look over the plain picture by strength. Every animation is slow and soft (no
// flashing: nothing pulses faster than 2 Hz).

uniform bool use_screen = false;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float strength : hint_range(0.0, 1.0) = 1.0;

// The picture's UV, one pixel of it in UV, and a read of it at a UV.
#define STYLE_UV (use_screen ? SCREEN_UV : UV)
#define STYLE_PX (use_screen ? SCREEN_PIXEL_SIZE : TEXTURE_PIXEL_SIZE)
#define STYLE_READ(at) (use_screen ? texture(screen_texture, (at)) : texture(TEXTURE, (at)))
// The style's colour mixed over the plain picture by strength, tinted by the node's colour
// (modulate and self_modulate, which the vertex COLOR carries).
#define STYLE_OUT(plain, styled) COLOR = mix((plain), (styled), strength) * style_tint

varying vec4 style_tint;

void vertex() {
	style_tint = COLOR;
}

float style_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float style_luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

// A character in a room after dark: drawn unshaded at `lit` (picked out by the guards'
// lanterns and the picture lights, so it reads against the dark room) with a pale moonlit
// rim along every part's edge. The room sets it on each character rig; the rig's parts use
// their parent's material. Modulate (the far limb's shade, the ghost's tint, a fade) still
// applies.
shader_type canvas_item;
render_mode unshaded;

uniform vec4 lit : source_color = vec4(0.82, 0.84, 0.95, 1.0);
uniform vec4 rim_color : source_color = vec4(0.72, 0.8, 1.0, 1.0);
// Rim width in texels and strength.
uniform float rim_width = 2.5;
uniform float rim_strength = 0.55;

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	vec2 step_uv = TEXTURE_PIXEL_SIZE * rim_width;
	float inner = min(
		min(texture(TEXTURE, UV + vec2(step_uv.x, 0.0)).a, texture(TEXTURE, UV - vec2(step_uv.x, 0.0)).a),
		min(texture(TEXTURE, UV + vec2(0.0, step_uv.y)).a, texture(TEXTURE, UV - vec2(0.0, step_uv.y)).a));
	float rim = clamp(c.a - inner, 0.0, 1.0);
	COLOR = vec4(c.rgb * lit.rgb + rim_color.rgb * rim * rim_strength * c.a, c.a);
}

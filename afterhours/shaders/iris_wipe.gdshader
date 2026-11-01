// The screen change's cover (Game.goto): a silent-film iris closing on the screen's centre
// with a gilt rim. The cover's alpha (tweened by Game) is how far it has closed: 0 open,
// 1 shut. With `fade` (Reduce Motion) it is a plain fade instead.
shader_type canvas_item;

uniform bool fade = false;
uniform vec4 rim_color : source_color = vec4(0.91, 0.72, 0.29, 1.0);
const float RIM = 5.0;

void fragment() {
	float closed = COLOR.a;
	if (fade) {
		COLOR = vec4(COLOR.rgb, closed);
	} else {
		vec2 size = 1.0 / SCREEN_PIXEL_SIZE;
		float radius = (1.0 - closed) * length(size) * 0.5;
		float from_centre = length(SCREEN_UV * size - size * 0.5);
		if (closed <= 0.0 || from_centre < radius) {
			COLOR = vec4(0.0);
		} else if (closed < 1.0 && from_centre < radius + RIM) {
			COLOR = rim_color;
		} else {
			COLOR = vec4(COLOR.rgb, 1.0);
		}
	}
}

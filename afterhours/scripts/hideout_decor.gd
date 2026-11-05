class_name HideoutDecor
extends Node2D
## The mime's lair, drawn under the stolen originals and the mime: rough brick walls and a
## ceiling beam, a brass plaque under every frame (Hideout's layout; its replay button sits
## on it between the wing's four challenge badges (Challenges), bright where ever completed and
## faint where not; an unrobbed frame's plaque left blank), a lamp hanging over the room on its cord
## (swaying at SWAY_HZ, held still under Reduce Motion) and its pool of warm light, a round
## patterned rug, the forger's easel with paint pots, and stacked crates.

const WALL_BOTTOM := 200.0
const BEAM := 18.0
const BRICK := Vector2(32, 12)
const BRICK_COLOURS: Array[Color] = [Color(0.36, 0.2, 0.15), Color(0.4, 0.23, 0.17), Color(0.33, 0.18, 0.14)]
const MORTAR := Color(0.2, 0.12, 0.1)
const WOOD := Color(0.42, 0.28, 0.16)
const WOOD_DARK := Color(0.25, 0.16, 0.09)
const BRASS := Color(0.78, 0.62, 0.3)
const BRASS_DARK := Color(0.45, 0.33, 0.14)
const INK := Color(0.08, 0.06, 0.08)
## A challenge badge's side on a plaque, and a missed one's fading.
const BADGE_SIZE := 16.0
const BADGE_MISSED := Color(0.25, 0.2, 0.15, 0.45)
## The lamp: where it hangs from, how long its cord, its swing.
const LAMP_FROM := Vector2(480, 0)
const LAMP_CORD := 236.0
const SWAY_HZ := 0.25
const SWAY := 0.035
const LIGHT := Color(1.0, 0.85, 0.55, 0.12)
const RUG_CENTRE := Vector2(480, 400)
const RUG_RADIUS := Vector2(190, 74)
const RUG_RINGS: Array[Color] = [Color(0.45, 0.14, 0.16), Color(0.75, 0.55, 0.25), Color(0.2, 0.22, 0.4), Color(0.45, 0.14, 0.16), Color(0.75, 0.55, 0.25)]
const PAINTS: Array[Color] = [Color(0.2, 0.35, 0.7), Color(0.9, 0.75, 0.25), Color(0.75, 0.2, 0.2), Color(0.3, 0.55, 0.3)]

## Which frames hold a stolen original (per wing, from the hideout).
var stolen: Array[bool] = []
## Per wing: the challenges it ever had completed (Save.challenges_of, Challenge order).
var challenges: Array = []
var _clock := 0.0


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


## Where the plaque under frame `index` sits (centred on its replay button).
static func plaque_rect(index: int) -> Rect2:
	var centre := Vector2(Hideout.FIRST_X + index * Hideout.GAP, Hideout.FRAME_Y + Hideout.REPLAY_DROP)
	return Rect2(centre - Vector2(54, 30), Vector2(108, 60))


## Where challenge `challenge`'s badge sits on frame `index`'s plaque: the first two stacked
## left of the replay button, the last two right of it.
static func badge_rect(index: int, challenge: int) -> Rect2:
	var plate := plaque_rect(index)
	var side := (plate.size.x - Hideout.REPLAY_SIZE) / 2.0
	var x := plate.position.x + side / 2.0 if challenge < 2 else plate.end.x - side / 2.0
	var y := plate.get_center().y + (-10.0 if challenge % 2 == 0 else 10.0)
	return Rect2(Vector2(x, y) - Vector2.ONE * BADGE_SIZE / 2.0, Vector2.ONE * BADGE_SIZE)


func _draw() -> void:
	_draw_bricks()
	draw_rect(Rect2(0, WALL_BOTTOM - BEAM, 960, BEAM), WOOD_DARK)
	draw_line(Vector2(0, WALL_BOTTOM - BEAM), Vector2(960, WALL_BOTTOM - BEAM), WOOD, 2.0)
	for i in Content.WINGS.size():
		_draw_plaque(i, i < stolen.size() and stolen[i])
	_draw_rug()
	_draw_easel(Vector2(150, 330))
	_draw_crates(Vector2(860, 470))
	_draw_lamp()


func _draw_bricks() -> void:
	var rows := int((WALL_BOTTOM - BEAM) / BRICK.y)
	draw_rect(Rect2(0, 0, 960, WALL_BOTTOM - BEAM), MORTAR)
	for row in rows:
		var shift := BRICK.x / 2.0 if row % 2 == 1 else 0.0
		var x := -shift
		var k := row * 7
		while x < 960.0:
			draw_rect(Rect2(x + 1, row * BRICK.y + 1, BRICK.x - 2, BRICK.y - 2), BRICK_COLOURS[k % BRICK_COLOURS.size()])
			x += BRICK.x
			k += 1


## A brass plate with four screws; a stolen original's carries its replay button.
func _draw_plaque(index: int, robbed: bool) -> void:
	var plate := plaque_rect(index)
	draw_rect(plate, BRASS if robbed else BRASS_DARK)
	draw_rect(plate.grow(-4.0), BRASS_DARK, false, 1.5)
	draw_rect(plate, INK, false, 1.5)
	for corner: Vector2 in [Vector2(6, 6), Vector2(plate.size.x - 6, 6), Vector2(6, plate.size.y - 6), plate.size - Vector2(6, 6)]:
		draw_circle(plate.position + corner, 2.0, BRASS_DARK.darkened(0.3))
	if not robbed or index >= challenges.size():
		return
	var done: Array = challenges[index]
	for i in done.size():
		draw_texture_rect(Challenges.ICONS[i], badge_rect(index, i), false, Color.WHITE if done[i] else BADGE_MISSED)


func _draw_rug() -> void:
	for i in RUG_RINGS.size():
		var ring := 1.0 - i * 0.17
		draw_set_transform(RUG_CENTRE, 0.0, Vector2(1.0, RUG_RADIUS.y / RUG_RADIUS.x))
		draw_circle(Vector2.ZERO, RUG_RADIUS.x * ring, RUG_RINGS[i])
	draw_set_transform(RUG_CENTRE, 0.0, Vector2(1.0, RUG_RADIUS.y / RUG_RADIUS.x))
	for k in 12:
		var at := Vector2.from_angle(TAU * k / 12.0) * RUG_RADIUS.x * 0.75
		draw_circle(at, 7.0, RUG_RINGS[2])
	draw_arc(Vector2.ZERO, RUG_RADIUS.x, 0.0, TAU, 48, INK, 2.0, true)
	draw_set_transform(Vector2.ZERO)


## The forger's easel, a canvas on it half painted, paint pots at its foot.
func _draw_easel(foot: Vector2) -> void:
	for leg: Vector2 in [Vector2(-26, 0), Vector2(26, 0), Vector2(0, -6)]:
		draw_line(foot + Vector2(0, -110), foot + leg, WOOD, 4.0, true)
	var canvas := Rect2(foot + Vector2(-34, -104), Vector2(68, 52))
	draw_rect(canvas, Color(0.93, 0.9, 0.82))
	draw_rect(canvas, INK, false, 1.5)
	# A sketch in progress: a moon and a swirl.
	draw_circle(canvas.position + Vector2(50, 14), 7.0, Color(0.95, 0.85, 0.4))
	draw_polyline(Gimmick.spiral(canvas.position + Vector2(24, 30), 2.0, 14.0, 0.0, TAU * 1.5), Color(0.2, 0.3, 0.6), 2.0, true)
	draw_rect(Rect2(foot + Vector2(-38, -54), Vector2(76, 5)), WOOD_DARK)
	for i in PAINTS.size():
		var pot := foot + Vector2(-46 + i * 22, 26)
		draw_rect(Rect2(pot - Vector2(8, 10), Vector2(16, 14)), Color(0.6, 0.6, 0.62))
		draw_set_transform(pot - Vector2(0, 10), 0.0, Vector2(1.0, 0.4))
		draw_circle(Vector2.ZERO, 8.0, PAINTS[i])
		draw_set_transform(Vector2.ZERO)


## Two crates and a smaller one on top, by the right wall (`foot`: the front bottom middle).
func _draw_crates(foot: Vector2) -> void:
	for crate: Rect2 in [Rect2(foot + Vector2(-80, -64), Vector2(70, 64)), Rect2(foot + Vector2(-6, -60), Vector2(66, 60)), Rect2(foot + Vector2(-50, -112), Vector2(56, 48))]:
		draw_rect(crate, WOOD)
		draw_rect(crate, WOOD_DARK, false, 2.0)
		draw_line(crate.position, crate.end, WOOD_DARK, 2.0)
		draw_line(Vector2(crate.position.x, crate.end.y), Vector2(crate.end.x, crate.position.y), WOOD_DARK, 2.0)
		draw_rect(Rect2(crate.position, Vector2(crate.size.x, 6)), WOOD.lightened(0.15))


## The lamp on its cord, swaying slowly, and the warm pool it throws on the rug.
func _draw_lamp() -> void:
	var sway := 0.0 if GameState.reduce_motion_for(self) else SWAY * sin(TAU * SWAY_HZ * _clock)
	var bulb := LAMP_FROM + Vector2(0, LAMP_CORD).rotated(sway)
	draw_set_transform(RUG_CENTRE + Vector2((bulb.x - LAMP_FROM.x) * 1.5, 0), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 200.0, LIGHT)
	draw_circle(Vector2.ZERO, 120.0, LIGHT)
	draw_set_transform(Vector2.ZERO)
	draw_line(LAMP_FROM, bulb, INK, 1.5, true)
	draw_circle(bulb + Vector2(0, 8), 30.0, Color(LIGHT, 0.2))
	var shade := PackedVector2Array([bulb + Vector2(-6, 0), bulb + Vector2(6, 0), bulb + Vector2(18, 14), bulb + Vector2(-18, 14)])
	draw_colored_polygon(shade, Color(0.22, 0.32, 0.24))
	draw_polyline(PackedVector2Array([shade[0], shade[1], shade[2], shade[3], shade[0]]), INK, 1.2, true)
	draw_circle(bulb + Vector2(0, 16), 5.0, Color(1.0, 0.92, 0.65))

class_name TitleScene
extends Control
## The title's night, behind the logo: a sky deepening to the top, STARS stars twinkling at
## TWINKLE_HZ (still under Reduce Motion), a halo round the logo's moon (its O), and the
## museum's front below: steps, columns and lit windows either side of its door (the play
## button's gilt frame). The mime tiptoes along the foot of the steps, sneaking a few steps
## and freezing in turn (SNEAK, FREEZE), across and round again.

const SKY_TOP := Color(0.03, 0.03, 0.08)
const SKY_LOW := Color(0.16, 0.12, 0.26)
const STARS := 70
const STAR_SEED := 1503
const TWINKLE_HZ := 0.5
## The logo's moon, from the screen's centre, and its halo.
const MOON := Vector2(-78, -68)
const HALO := Color(1.0, 0.94, 0.7, 0.07)
## The facade, from the screen's centre: the entablature's top and the columns' foot, the
## columns' x either side, the facade's half width and the steps.
const FRIEZE_Y := 8.0
const FRIEZE := 22.0
const COLUMN_FOOT := 214.0
const COLUMNS: Array[float] = [160.0, 245.0, 330.0]
const COLUMN_WIDTH := 30.0
const HALF_WIDTH := 380.0
const STEPS := 3
const STEP := 9.0
const STONE := Color(0.24, 0.23, 0.32)
const STONE_LIGHT := Color(0.33, 0.32, 0.43)
const STONE_DARK := Color(0.15, 0.14, 0.21)
const WINDOW := Color(0.95, 0.76, 0.38, 0.55)
## The mime's sneak: units a second, seconds sneaking then frozen, its size.
const SNEAK_SPEED := 70.0
const SNEAK := 1.6
const FREEZE := 0.9
const MIME_SCALE := 0.85

var _clock := 0.0
var _stars: Array[Vector3] = []
var _walked := 0.0

@onready var _holder: Node2D = $MimeHolder
@onready var mime: CharacterRig = $MimeHolder/Mime


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = STAR_SEED
	for i in STARS:
		# x and y as shares of the sky (y over its upper part), z the twinkle's phase.
		_stars.append(Vector3(rng.randf(), rng.randf() * 0.55, rng.randf()))
	_holder.scale = Vector2.ONE * MIME_SCALE
	mime.face(Vector2.RIGHT)


func _process(delta: float) -> void:
	_clock += delta
	# Sneaking for SNEAK, then frozen for FREEZE, round again.
	var sneaking := fmod(_clock, SNEAK + FREEZE) < SNEAK
	var step := SNEAK_SPEED * delta if sneaking else 0.0
	_walked += step
	var span := size.x + 80.0
	_holder.position = Vector2(fmod(_walked, span) - 40.0, size.y - 6.0)
	mime.walk(step, delta, false)
	queue_redraw()


func _draw() -> void:
	var still := GameState.reduce_motion_for(self)
	var bands := 40
	for i in bands:
		draw_rect(Rect2(0, size.y * i / bands, size.x, size.y / bands + 1.0), SKY_TOP.lerp(SKY_LOW, float(i) / (bands - 1)))
	for star in _stars:
		var twinkle := 0.75 if still else 0.5 + 0.5 * sin(TAU * (TWINKLE_HZ * _clock + star.z))
		draw_circle(Vector2(star.x * size.x, star.y * size.y), 1.0 + star.z, Color(1.0, 0.97, 0.85, 0.3 + 0.6 * twinkle))
	var centre := size / 2.0
	for radius: float in [150.0, 110.0, 80.0]:
		draw_circle(centre + MOON, radius, HALO)
	_draw_facade(centre)


func _draw_facade(centre: Vector2) -> void:
	var top := centre.y + FRIEZE_Y
	var foot := centre.y + COLUMN_FOOT
	# The wall behind the columns, the entablature and its cornice.
	draw_rect(Rect2(centre.x - HALF_WIDTH, top, HALF_WIDTH * 2.0, foot - top), STONE_DARK)
	draw_rect(Rect2(centre.x - HALF_WIDTH - 10.0, top, HALF_WIDTH * 2.0 + 20.0, FRIEZE), STONE)
	draw_rect(Rect2(centre.x - HALF_WIDTH - 14.0, top - 5.0, HALF_WIDTH * 2.0 + 28.0, 5.0), STONE_LIGHT)
	for x in range(int(centre.x - HALF_WIDTH), int(centre.x + HALF_WIDTH), 14):
		draw_rect(Rect2(x, top + 6.0, 6.0, FRIEZE - 12.0), STONE_DARK)
	for side: float in [-1.0, 1.0]:
		for i in COLUMNS.size():
			var x := centre.x + side * COLUMNS[i]
			# A lit window between this column and the next one out.
			if i < COLUMNS.size() - 1:
				var between := centre.x + side * (COLUMNS[i] + COLUMNS[i + 1]) / 2.0
				var window := Rect2(between - 12.0, top + FRIEZE + 40.0, 24.0, 70.0)
				draw_rect(window, WINDOW)
				draw_circle(Vector2(between, window.position.y), 12.0, WINDOW)
				draw_line(Vector2(between, window.position.y - 12.0), Vector2(between, window.end.y), STONE_DARK, 2.0)
			_draw_column(x, top + FRIEZE, foot)
	for k in STEPS:
		var inset := (STEPS - k) * 10.0
		draw_rect(Rect2(centre.x - HALF_WIDTH - 20.0 + inset, foot + k * STEP, (HALF_WIDTH + 20.0 - inset) * 2.0, STEP), STONE_LIGHT if k % 2 == 0 else STONE)


func _draw_column(x: float, top: float, foot: float) -> void:
	draw_rect(Rect2(x - COLUMN_WIDTH / 2.0, top, COLUMN_WIDTH, foot - top), STONE_LIGHT)
	for k in 4:
		var fx := x - COLUMN_WIDTH / 2.0 + 6.0 + k * 6.0
		draw_line(Vector2(fx, top + 8.0), Vector2(fx, foot - 8.0), STONE, 1.5)
	draw_rect(Rect2(x - COLUMN_WIDTH / 2.0 - 4.0, top, COLUMN_WIDTH + 8.0, 7.0), STONE)
	draw_rect(Rect2(x - COLUMN_WIDTH / 2.0 - 4.0, foot - 7.0, COLUMN_WIDTH + 8.0, 7.0), STONE)

class_name TiltFrame
extends Node2D
## A small framed picture on the back wall, a decoy: the mime tilts it (a noise the
## guards hear, shown as a ripple spreading from the frame so it reads without sound),
## and a guard who sees it tilted walks over and straightens it. Its origin is the
## frame's centre, in room coordinates.

const SIZE := Vector2(60, 50)
const TILT_ANGLE := 0.35
const SWING_TIME := 0.2
const RIPPLE_TIME := 0.6
const RIPPLE_RADIUS := 70.0
const RIPPLE_COLOR := Color(0.95, 0.85, 0.4, 0.8)
## Where the mime or a guard stands to reach it, and where a guard looks to see it (the
## floor at the wall's foot: sight rays to the frame itself would hit the back wall).
const STAND_Y := 195.0
const VIEW_Y := 180.0

## Its picture (a Paintings id; the enum lists Paintings.IDS).
@export_enum("pearl_earring", "great_wave", "grande_jatte", "starry_night", "earthly_delights", "mona_lisa") var painting := "great_wave":
	set(value):
		painting = value
		if is_node_ready():
			($Swing/Picture as FramedPainting).painting = value

var tilted := false
## The ripple's progress, 0 (just tilted) to 1 (gone).
var _ripple := 1.0

@onready var _swing: Node2D = $Swing


func _ready() -> void:
	($Swing/Picture as FramedPainting).painting = painting


## Where a tap means this frame.
func rect() -> Rect2:
	return Rect2(position - SIZE / 2.0, SIZE)


func spot() -> Vector2:
	return Vector2(position.x, STAND_Y)


func view_point() -> Vector2:
	return Vector2(position.x, VIEW_Y)


func tilt() -> void:
	tilted = true
	_ripple = 0.0
	create_tween().tween_property(_swing, "rotation", TILT_ANGLE, SWING_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func straighten() -> void:
	tilted = false
	create_tween().tween_property(_swing, "rotation", 0.0, SWING_TIME)


func _process(delta: float) -> void:
	if _ripple >= 1.0:
		return
	_ripple = minf(_ripple + delta / RIPPLE_TIME, 1.0)
	queue_redraw()


func _draw() -> void:
	if _ripple >= 1.0:
		return
	var color := RIPPLE_COLOR
	color.a *= 1.0 - _ripple
	draw_arc(Vector2.ZERO, lerpf(SIZE.x * 0.5, RIPPLE_RADIUS, _ripple), 0.0, TAU, 48, color, 4.0, true)

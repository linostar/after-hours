class_name TapRipple
extends Node2D
## A tap's feedback where it landed (rooms and the hub): a ring that widens and fades over
## LIFE, then frees itself.

const LIFE := 0.35
const FROM_RADIUS := 5.0
const TO_RADIUS := 22.0
const COLOR := Color(1.0, 0.95, 0.8, 0.8)
const WIDTH := 3.0

var _age := 0.0


## Adds a ripple at `at` (in `parent`'s space) above the floor and its props.
static func spawn(parent: Node, at: Vector2) -> TapRipple:
	var ripple := TapRipple.new()
	ripple.name = "TapRipple"
	ripple.position = at
	ripple.z_index = 50
	parent.add_child(ripple)
	return ripple


func _process(delta: float) -> void:
	_age += delta / LIFE
	if _age >= 1.0:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var color := COLOR
	color.a *= 1.0 - _age
	draw_arc(Vector2.ZERO, lerpf(FROM_RADIUS, TO_RADIUS, ease(_age, 0.4)), 0.0, TAU, 32, color, WIDTH, true)

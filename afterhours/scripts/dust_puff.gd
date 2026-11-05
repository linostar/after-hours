class_name DustPuff
extends Node2D
## A dashed footfall's dust: PUFFS little clouds kicked up round the foot that swell, rise
## and fade over LIFE, then it frees itself. Not spawned under Reduce Motion (Mime).

const LIFE := 0.45
const PUFFS := 3
const COLOR := Color(0.85, 0.8, 0.72, 0.55)
## Each cloud's radius at the start and the end, and how far it drifts out and up.
const FROM_RADIUS := 2.5
const TO_RADIUS := 7.0
const DRIFT := Vector2(12, -8)

var _age := 0.0


## Adds a puff at the feet `at` (in `parent`'s space), y-sorted just behind the feet.
static func spawn(parent: Node, at: Vector2) -> DustPuff:
	var puff := DustPuff.new()
	puff.name = "DustPuff"
	puff.position = at + Vector2(0, -1)
	# Pale dust against a room's night (Room.NIGHT), as lit as what the player uses.
	puff.modulate = Room.lit_boost()
	parent.add_child(puff)
	return puff


func _process(delta: float) -> void:
	_age += delta / LIFE
	if _age >= 1.0:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var color := COLOR
	color.a *= 1.0 - _age
	var grow := ease(_age, 0.4)
	for i in PUFFS:
		# Spread from behind the left foot to behind the right, the middle one highest.
		var across := float(i) / (PUFFS - 1) * 2.0 - 1.0
		var at := Vector2(across * DRIFT.x, DRIFT.y * (1.0 - absf(across) * 0.5)) * grow + Vector2(across * 4.0, 0.0)
		draw_circle(at, lerpf(FROM_RADIUS, TO_RADIUS, grow), color)

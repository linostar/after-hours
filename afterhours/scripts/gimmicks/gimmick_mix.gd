class_name GimmickMix
extends Gimmick
## Wing 6 (Leonardo), the finale: every earlier wing's gimmick at once. Its Gimmick children
## all apply: light is their product (shade from any still hides the mime), slowing their
## product, loudness the loudest, the clue the first child's that shows one; each child
## ticks with the room and knows the mime. A glass sheen is drawn over the masterpiece
## (glass_rect: the Mona Lisa hangs under glass).

const SHEEN := Color(0.85, 0.95, 1.0, 0.18)
const GLINT := Color(1.0, 1.0, 1.0, 0.35)

@export var glass_rect := Rect2()

## The glass, drawn just above the paintings.
var _glass: Node2D


func _ready() -> void:
	_glass = Node2D.new()
	_glass.z_as_relative = false
	_glass.z_index = -8
	_glass.draw.connect(_draw_glass)
	add_child(_glass)


func parts() -> Array[Gimmick]:
	var found: Array[Gimmick] = []
	for child in get_children():
		if child is Gimmick:
			found.append(child)
	return found


func light_at(point: Vector2) -> float:
	var light := 1.0
	for part in parts():
		light *= part.light_at(point)
	return light


func slow_at(point: Vector2) -> float:
	var slow := 1.0
	for part in parts():
		slow *= part.slow_at(point)
	return slow


func noise_at(point: Vector2) -> float:
	var loudest := 0.0
	for part in parts():
		loudest = maxf(loudest, part.noise_at(point))
	return loudest


func clue_seen_by(guard: Guard) -> Vector2:
	for part in parts():
		var clue := part.clue_seen_by(guard)
		if clue != Vector2.INF:
			return clue
	return Vector2.INF


func tick(delta: float) -> void:
	for part in parts():
		part.mime = mime
		part.tick(delta)


func _draw_glass() -> void:
	if glass_rect.has_area():
		_glass.draw_rect(glass_rect, SHEEN)
		_glass.draw_line(glass_rect.position + Vector2(glass_rect.size.x * 0.2, 0.0), glass_rect.position + Vector2(0.0, glass_rect.size.y * 0.4), GLINT, 3.0)

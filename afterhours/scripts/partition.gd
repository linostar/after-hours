class_name Partition
extends StaticBody2D
## A freestanding display wall on the floor, seen 3/4 top-down: its origin is the middle
## of its footprint's front edge (so Actors y-sorts it with the mime and guards). Its
## footprint (`width` x `depth`, on the floor behind the origin) blocks walking (the room
## bakes its navmesh around the nav_obstacles group) and sight (Guard.SIGHT_MASK); it is
## drawn as a face `height` tall with its top above it.

const TOP := Color(0.85, 0.82, 0.74)
const FACE := Color(0.7, 0.66, 0.58)

@export var width := 160.0
@export var depth := 60.0
@export var height := 90.0


func _ready() -> void:
	add_to_group(&"nav_obstacles")
	var footprint := CollisionPolygon2D.new()
	footprint.polygon = PackedVector2Array([Vector2(-width / 2.0, -depth), Vector2(width / 2.0, -depth), Vector2(width / 2.0, 0.0), Vector2(-width / 2.0, 0.0)])
	add_child(footprint)


func _draw() -> void:
	draw_rect(Rect2(-width / 2.0, -height - depth, width, depth), TOP)
	draw_rect(Rect2(-width / 2.0, -height, width, height), FACE)

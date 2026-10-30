class_name Room
extends Node2D
## The vertical slice's gallery room, seen 3/4 top-down: the back wall across the top, a
## parquet floor, a freestanding display partition the mime walks around (its navmesh
## leaves the partition's footprint out). A tap on the floor walks the mime there.

## Where the mime enters the room (the door in the left wall), in room coordinates.
const ENTRANCE := Vector2(70, 330)

@onready var mime: Mime = $Actors/Mime
@onready var _floor: FloorInput = $FloorInput


func _ready() -> void:
	mime.place_at(ENTRANCE)
	_floor.tapped.connect(_on_floor_tapped)
	(get_node(GameState.AUTOLOAD_PATH) as GameState).arrive(GameState.Flow.ROOM)


func _on_floor_tapped(at: Vector2) -> void:
	mime.walk_to(at)

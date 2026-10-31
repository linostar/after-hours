class_name HidingPortrait
extends Node2D
## A tall portrait hung low on the back wall, big enough for the mime to step into: while
## it hides there (occupied) the sitter wears the mime's face. Its origin is the
## portrait's centre, in room coordinates.

const SIZE := Vector2(70, 130)
## Where the mime stands to step in (the floor at the wall's foot below it).
const STAND_Y := 195.0

## Its painting (a Paintings id): the room is seen in its style from inside.
@export var painting := "mona_lisa"
## Where the mime's face covers the sitter's (portrait-relative).
@export var face := Vector2(0, -23)

var occupied := false:
	set(value):
		occupied = value
		if is_node_ready():
			_face.visible = value

@onready var _face: Sprite2D = $MimeFace


func _ready() -> void:
	($Picture as FramedPainting).painting = painting
	_face.position = face
	_face.visible = occupied


## Where a tap means this portrait.
func rect() -> Rect2:
	return Rect2(position - SIZE / 2.0, SIZE)


func spot() -> Vector2:
	return Vector2(position.x, STAND_Y)

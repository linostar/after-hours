class_name Easel
extends Sprite2D
## The forgery kit: an easel standing on the floor, its origin at its feet, glowing on the
## floor until the fake is painted. A tap on it (rect) walks the mime to spot, where the
## forgery canvas opens.

const SIZE := Vector2(70, 110)
## Where the mime stands to paint (easel-relative: beside its right leg).
const STAND := Vector2(48, 2)

## Whether its floor glow shows (until the fake is painted).
var glowing := true:
	set(value):
		glowing = value
		if is_node_ready():
			_glow.visible = value

@onready var _glow: Polygon2D = $Glow


func _ready() -> void:
	_glow.visible = glowing


## Where a tap means the easel (room coordinates).
func rect() -> Rect2:
	return Rect2(position + Vector2(-SIZE.x / 2.0, -SIZE.y), SIZE)


func spot() -> Vector2:
	return position + STAND

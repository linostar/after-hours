class_name Door
extends Node2D
## A doorway in a side wall. Its origin is the spot in front of it where the mime goes
## through (within REACH); `opening` is the doorway drawn on the wall (door-relative).
## to_room is the wing room it leads to (an index into WingData.rooms), or EXIT: out of
## the museum, open only to a mime carrying the original (the doorway glows then). A mime
## that comes in through it first stands at `arrival` (door-relative, inside the room, out
## of REACH so it does not go straight back).

## to_room for the way out of the museum.
const EXIT := -1
## How close to the door's spot counts as going through.
const REACH := 24.0
## How far around the doorway and spot a tap still means the door.
const TAP_MARGIN := 20.0
const DARK := Color(0.12, 0.09, 0.1)
const GLOW := Color(0.95, 0.85, 0.4, 0.55)
const GLOW_GROW := 6.0

@export var to_room := EXIT
@export var opening := Rect2(11, -40, 24, 80)
@export var arrival := Vector2(-60, 0)

var glowing := false:
	set(value):
		glowing = value
		queue_redraw()


## Where a tap means this door (room coordinates): the doorway and the spot before it.
func rect() -> Rect2:
	var doorway := Rect2(position + opening.position, opening.size)
	return doorway.merge(Rect2(position, Vector2.ZERO)).grow(TAP_MARGIN)


## Where a mime coming in through this door stands (room coordinates).
func arrival_point() -> Vector2:
	return position + arrival


func _draw() -> void:
	draw_rect(opening, DARK)
	if glowing:
		draw_rect(opening.grow(GLOW_GROW), GLOW)

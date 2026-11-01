class_name WingDoor
extends Node2D
## A wing's door in the hub's back wall, wordless: the wing's painting hangs above an
## archway (its origin is the floor spot in front of it, where the mime goes through within
## Door.REACH), the best stars of the wing (Save) sit between them once it was escaped
## from, and a locked door is chained shut (a tap rattles the chain) with its painting dimmed.
## A wing whose data is broken shows the error badge on its door and never opens.

const OPENING := Rect2(-25, -98, 50, 72)
const PICTURE_CENTER := Vector2(0, -150)
const PICTURE_SIZE := Vector2(84, 62)
const STAR_SIZE := 18.0
const STAR_ROW_Y := -114.0
## How far around the door, its painting and its spot a tap still means the door.
const TAP_RECT := Rect2(-58, -190, 116, 214)
const DARK := Color(0.1, 0.07, 0.09)
const ARCH := Color(0.62, 0.52, 0.36)
const CHAIN := Color(0.7, 0.7, 0.74)
const LOCK := Color(0.85, 0.7, 0.3)
const DIM := Color(0.45, 0.45, 0.5)
const RATTLE_ANGLE := 0.12
const RATTLE_TIME := 0.32
const STAR := preload("res://art/svg/star.svg")
const STAR_EMPTY := preload("res://art/svg/star_empty.svg")
const BADGE := preload("res://art/svg/error_badge.svg")

## The wing's index in Content.WINGS and its painting.
var index := 0
var painting := "pearl_earring"
var open := false
## Whether the wing was escaped from, and its best stars then.
var finished := false
var stars := 0
var broken := false
var _picture: FramedPainting
## The chain's swing while it rattles.
var _rattle := 0.0:
	set(value):
		_rattle = value
		queue_redraw()


func _ready() -> void:
	if broken:
		return
	_picture = FramedPainting.new()
	_picture.size = PICTURE_SIZE
	_picture.moulding = 4.0
	_picture.position = PICTURE_CENTER
	_picture.painting = painting
	_picture.modulate = Color.WHITE if open else DIM
	add_child(_picture)


## Where a tap means this door (hub coordinates).
func rect() -> Rect2:
	return Rect2(position + TAP_RECT.position, TAP_RECT.size)


## Shakes the chain of a locked door.
func rattle() -> void:
	Audio.play_for(self, &"chain_rattle")
	var swing := create_tween()
	for angle: float in [RATTLE_ANGLE, -RATTLE_ANGLE, RATTLE_ANGLE / 2.0, 0.0]:
		swing.tween_property(self, "_rattle", angle, RATTLE_TIME / 4.0)


func _draw() -> void:
	draw_rect(OPENING.grow(5.0), ARCH)
	draw_circle(Vector2(0, OPENING.position.y), OPENING.size.x / 2.0 + 5.0, ARCH)
	draw_rect(OPENING, DARK)
	draw_circle(Vector2(0, OPENING.position.y), OPENING.size.x / 2.0, DARK)
	if finished:
		for i in 3:
			var at := Vector2((i - 1) * (STAR_SIZE + 4.0) - STAR_SIZE / 2.0, STAR_ROW_Y - STAR_SIZE / 2.0)
			draw_texture_rect(STAR if i < stars else STAR_EMPTY, Rect2(at, Vector2(STAR_SIZE, STAR_SIZE)), false)
	if broken:
		draw_texture_rect(BADGE, Rect2(Vector2(-24, -86), Vector2(48, 48)), false)
	elif not open:
		_draw_chain()


## Two chains crossing the doorway and a padlock where they meet, swinging by _rattle.
func _draw_chain() -> void:
	var middle := OPENING.get_center()
	draw_set_transform(middle, _rattle)
	var half := OPENING.size / 2.0 + Vector2(4, -8)
	for direction: Vector2 in [Vector2(1, 1), Vector2(1, -1)]:
		var from := -half * direction
		var links := 7
		for i in links:
			var at := from.lerp(half * direction, (i + 0.5) / links)
			draw_arc(at, 5.0, 0.0, TAU, 10, CHAIN, 2.5)
	draw_rect(Rect2(-10, -2, 20, 16), LOCK)
	draw_arc(Vector2(0, -2), 7.0, PI, TAU, 10, LOCK, 3.0)
	draw_circle(Vector2(0, 6), 2.5, DARK)
	draw_set_transform(Vector2.ZERO)

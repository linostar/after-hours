class_name RoomLights
extends Node2D
## The room's lights after dark, added over the night (LIGHT_ADD: additive and unshaded,
## so they brighten whatever lies below, never darken; cheap textures, no Light2D):
## - a picture light over every painting on the back wall (`paintings`, their rects): a
##   brass lamp on an arm above the frame (drawn by the Lamps child at full brightness, over
##   the frames) and a warm wash fanning down the wall and onto the floor below it;
## - pools (`pools`: centre, radius, colour), the light of lamps other nodes draw (the
##   wall sconces).
## Drawing only: no light here changes what a guard sees (Gimmick.light_at does that).

const LIGHT_POOL := preload("res://art/light_pool.tres")
const LIGHT_ADD := preload("res://art/light_add.tres")
const GLOW := preload("res://art/glow.tres")
const WASH := Color(1.0, 0.86, 0.6, 0.3)
## How far the wash spreads past the painting's sides, and down past its foot.
const WASH_SPREAD := 0.5
const WASH_DROP := 70.0
const BRASS := Color(0.78, 0.6, 0.3)
const BRASS_DARK := Color(0.42, 0.3, 0.14)
const BULB := Color(1.0, 0.93, 0.7)
## The lamp's hood: its share of the painting's width, its height and how far above the
## frame it hangs.
const HOOD_SHARE := 0.55
const HOOD_HEIGHT := 5.0
const HOOD_GAP := 7.0

## The paintings' rects (frame included), room units.
var paintings: Array[Rect2] = []:
	set(value):
		paintings = value
		queue_redraw()
		if _lamps != null:
			_lamps.queue_redraw()
## [centre, radius, colour] each.
var pools: Array[Array] = []:
	set(value):
		pools = value
		queue_redraw()
var _lamps: Node2D


func _ready() -> void:
	material = LIGHT_ADD
	_lamps = Node2D.new()
	_lamps.name = "Lamps"
	_lamps.material = GLOW
	_lamps.z_as_relative = false
	_lamps.z_index = 1
	_lamps.draw.connect(_draw_lamps)
	add_child(_lamps)


func _draw() -> void:
	for rect in paintings:
		var wide := rect.size.x * (1.0 + WASH_SPREAD * 2.0)
		var top := rect.position.y - HOOD_GAP
		var wash := Rect2(rect.get_center().x - wide / 2.0, top - wide * 0.25, wide, rect.end.y - top + WASH_DROP + wide * 0.25)
		draw_texture_rect(LIGHT_POOL, wash, false, WASH)
	for pool in pools:
		var radius: float = pool[1]
		draw_texture_rect(LIGHT_POOL, Rect2(pool[0] - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), false, pool[2])


## A picture light over each painting: the arm from the wall, the hood and its bulb's glow.
func _draw_lamps() -> void:
	for rect in paintings:
		var hood := Rect2(rect.get_center().x - rect.size.x * HOOD_SHARE / 2.0, rect.position.y - HOOD_GAP - HOOD_HEIGHT, rect.size.x * HOOD_SHARE, HOOD_HEIGHT)
		var mount := Vector2(rect.get_center().x, rect.position.y - 2.0)
		_lamps.draw_line(mount, hood.get_center() + Vector2(0, -HOOD_HEIGHT * 0.5), BRASS_DARK, 2.0, true)
		_lamps.draw_rect(hood, BRASS)
		_lamps.draw_rect(Rect2(hood.position + Vector2(0, hood.size.y - 1.5), Vector2(hood.size.x, 1.5)), BULB)
		_lamps.draw_rect(hood, BRASS_DARK, false, 1.0)

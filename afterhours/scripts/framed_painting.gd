class_name FramedPainting
extends Node2D
## A masterpiece in a gilt frame, centred on its origin and `size` big frame included: the
## painting's scan (Paintings) cut to fill the inside (centred, nothing stretched) and alive
## through its style shader. An unknown painting id is reported and leaves the frame empty.

const GILT := Color(0.79, 0.64, 0.29)
const GILT_SHADE := Color(0.54, 0.42, 0.16)
const LIP := Color(0.24, 0.17, 0.08)

## Its painting (a Paintings id; the enum lists Paintings.IDS).
@export_enum("pearl_earring", "great_wave", "grande_jatte", "starry_night", "earthly_delights", "mona_lisa") var painting := "starry_night":
	set(value):
		painting = value
		if is_node_ready():
			_sync()
## The whole frame's size, and its moulding's width.
@export var size := Vector2(120, 90)
@export var moulding := 6.0

var _picture := Sprite2D.new()


func _ready() -> void:
	_picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_picture.region_enabled = true
	add_child(_picture)
	_sync()


## The picture's texture (null while the painting id is unknown).
func picture() -> Texture2D:
	return _picture.texture


func _sync() -> void:
	var id := StringName(painting)
	_picture.material = Paintings.style(id)
	_picture.texture = Paintings.SCANS.get(id)
	if _picture.texture == null:
		(get_node(GameState.AUTOLOAD_PATH) as GameState).report_error("Painting '%s' at %s: unknown painting '%s'" % [name, get_path(), painting])
		return
	var inside := size - Vector2(moulding, moulding) * 2.0
	var scan := _picture.texture.get_size()
	var fit := maxf(inside.x / scan.x, inside.y / scan.y)
	_picture.region_rect = Rect2((scan - inside / fit) / 2.0, inside / fit)
	_picture.scale = Vector2(fit, fit)
	queue_redraw()


func _draw() -> void:
	var outer := Rect2(-size / 2.0, size)
	draw_rect(outer, GILT_SHADE)
	draw_rect(outer.grow(-1.5), GILT)
	draw_rect(outer.grow(-moulding + 1.0), LIP)

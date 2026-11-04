class_name FramedPainting
extends Node2D
## A masterpiece in a gilt frame (plain wood when not `gilded`), centred on its origin and `size` big frame included: the
## painting's scan (Paintings) cut to fill the inside (centred, nothing stretched) and alive
## through its style shader. An unknown painting id is reported and leaves the frame empty.

const GILT := Color(0.79, 0.64, 0.29)
const GILT_SHADE := Color(0.54, 0.42, 0.16)
const LIP := Color(0.24, 0.17, 0.08)
const WOOD := Color(0.45, 0.3, 0.18)
const WOOD_SHADE := Color(0.3, 0.19, 0.1)

## Its painting (a Paintings id; the enum lists Paintings.ALL).
@export_enum("pearl_earring", "great_wave", "grande_jatte", "starry_night", "earthly_delights", "mona_lisa", "madame_x", "van_gogh_self", "castiglione", "fighting_temeraire", "impression_sunrise") var painting := "starry_night":
	set(value):
		painting = value
		if is_node_ready():
			_sync()
## The whole frame's size, and its moulding's width.
@export var size := Vector2(120, 90)
@export var moulding := 6.0
## Gilt, or plain wood (the hideout gilds an original stolen with all three stars).
@export var gilded := true:
	set(value):
		gilded = value
		queue_redraw()

var _picture: Sprite2D


func _ready() -> void:
	_picture = Sprite2D.new()
	_picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_picture.region_enabled = true
	add_child(_picture)
	_sync()


## The picture's texture (null before _ready or while the painting id is unknown).
func picture() -> Texture2D:
	return _picture.texture if _picture != null else null


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
	draw_rect(outer, GILT_SHADE if gilded else WOOD_SHADE)
	draw_rect(outer.grow(-1.5), GILT if gilded else WOOD)
	draw_rect(outer.grow(-moulding + 1.0), LIP)

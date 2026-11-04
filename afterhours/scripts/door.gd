class_name Door
extends Node2D
## A doorway in a side wall. Its origin is the spot in front of it where the mime goes
## through (within REACH); `opening` is the doorway drawn on the wall (door-relative).
## to_room is the wing room it leads to (an index into WingData.rooms), or EXIT: out of
## the museum, open only to a mime carrying the original (the doorway glows then). A mime
## that comes in through it first stands at `arrival` (door-relative, inside the room, out
## of REACH so it does not go straight back).
## Drawn as a doorway seen from the room: the dark way through, its jambs above and below,
## the reveal lit on the room side and a threshold mat before it, dressed after its wing's
## painting (`painting`, set by the room: a brass-handled frame with a checker sill, a noren
## curtain, park-gate railings, swirling jambs, pointed stone arches, a velvet swag), or as
## the lobby's secret door (`secret`: a bookcase panel left ajar). swing_shut closes a door
## leaf over it (the escape).

## to_room for the way out of the museum.
const EXIT := -1
## How close to the door's spot counts as going through.
const REACH := 24.0
## How far around the doorway and spot a tap still means the door.
const TAP_MARGIN := 20.0
const DARK := Color(0.12, 0.09, 0.1)
const DEEP := Color(0.04, 0.03, 0.05)
const GLOW := Color(0.95, 0.85, 0.4, 0.55)
const GLOW_GROW := 6.0
const INK := Color(0.08, 0.06, 0.1)
## The jamb blocks' height above and below the opening, the reveal's width and the mat's.
const JAMB := 9.0
const REVEAL := 5.0
const MAT := 14.0
const SHUT_TIME := 0.35
## Per painting: trim (jambs, reveal), accent (mat, curtain, details).
const TRIMS: Dictionary[StringName, Array] = {
	&"pearl_earring": [Color(0.42, 0.3, 0.18), Color(0.82, 0.66, 0.3)],
	&"great_wave": [Color(0.2, 0.14, 0.12), Color(0.16, 0.27, 0.5)],
	&"grande_jatte": [Color(0.18, 0.32, 0.2), Color(0.86, 0.74, 0.42)],
	&"starry_night": [Color(0.12, 0.2, 0.42), Color(0.95, 0.82, 0.3)],
	&"earthly_delights": [Color(0.5, 0.47, 0.44), Color(0.36, 0.5, 0.26)],
	&"mona_lisa": [Color(0.36, 0.25, 0.14), Color(0.56, 0.12, 0.14)],
}
const PLAIN := [Color(0.4, 0.33, 0.24), Color(0.5, 0.18, 0.18)]
const WOOD := Color(0.45, 0.3, 0.17)
const WOOD_LIGHT := Color(0.6, 0.42, 0.24)
const BOOKS: Array[Color] = [Color(0.55, 0.16, 0.14), Color(0.16, 0.3, 0.45), Color(0.2, 0.4, 0.22), Color(0.7, 0.55, 0.2), Color(0.4, 0.2, 0.4)]

@export var to_room := EXIT
@export var opening := Rect2(11, -40, 24, 80)
@export var arrival := Vector2(-60, 0)
## The lobby's hideout door: drawn as a bookcase left ajar, not a gallery doorway.
@export var secret := false

var glowing := false:
	set(value):
		glowing = value
		queue_redraw()
## The wing's painting (a Paintings id) the doorway is dressed after; empty for plain.
var painting: StringName = &"":
	set(value):
		painting = value
		queue_redraw()
## How far the door leaf has swung shut over the opening (0 open, 1 shut).
var shut := 0.0:
	set(value):
		shut = value
		queue_redraw()


## Where a tap means this door (room coordinates): the doorway and the spot before it.
func rect() -> Rect2:
	var doorway := Rect2(position + opening.position, opening.size)
	return doorway.merge(Rect2(position, Vector2.ZERO)).grow(TAP_MARGIN)


## Where a mime coming in through this door stands (room coordinates).
func arrival_point() -> Vector2:
	return position + arrival


## Swings the leaf shut over SHUT_TIME, a thud as it closes and its glow out; returns its
## tween.
func swing_shut() -> Tween:
	var tween := create_tween()
	tween.tween_property(self, "shut", 1.0, SHUT_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(Audio.play_for.bind(self, &"door"))
	tween.tween_property(self, "glowing", false, 0.0)
	return tween


## The side of the opening the room is on: +1 when the room lies to its right.
func _inward() -> float:
	return 1.0 if opening.get_center().x < 0.0 else -1.0


func _draw() -> void:
	var colours: Array = TRIMS.get(painting, PLAIN)
	var trim: Color = colours[0]
	var accent: Color = colours[1]
	var inward := _inward()
	# The room-side edge of the opening, and the strip just inside the room for the mat.
	var inner_x := opening.end.x if inward > 0.0 else opening.position.x
	if secret:
		_draw_secret(inner_x, inward)
		_draw_glow()
		return
	var mat := Rect2(inner_x if inward > 0.0 else inner_x - MAT, opening.position.y + 6.0, MAT, opening.size.y - 12.0)
	draw_rect(mat, accent.darkened(0.15))
	draw_rect(mat.grow(-2.0), accent, false, 1.5)
	# The way through: darkest at the far side.
	draw_rect(opening, DARK)
	var far := Rect2(opening.position.x if inward > 0.0 else opening.end.x - opening.size.x * 0.5, opening.position.y, opening.size.x * 0.5, opening.size.y)
	draw_rect(far, DEEP)
	# The reveal, lit from the room, and the jambs above and below.
	draw_rect(Rect2(inner_x - REVEAL if inward > 0.0 else inner_x, opening.position.y, REVEAL, opening.size.y), trim.lightened(0.25))
	var top := Rect2(opening.position.x, opening.position.y - JAMB, opening.size.x, JAMB)
	var bottom := Rect2(opening.position.x, opening.end.y, opening.size.x, JAMB)
	for jamb: Rect2 in [top, bottom]:
		draw_rect(jamb, trim)
		draw_rect(jamb, INK, false, 1.2)
	_draw_dressing(top, bottom, inner_x, inward, trim, accent)
	_draw_leaf(inner_x, inward)
	_draw_glow()


## The open way out (or the hideout door once there are originals): a glow over the doorway.
func _draw_glow() -> void:
	if glowing:
		draw_rect(opening.grow(GLOW_GROW), GLOW)


## The wing's own touch on the doorway.
func _draw_dressing(top: Rect2, bottom: Rect2, inner_x: float, inward: float, trim: Color, accent: Color) -> void:
	match painting:
		&"pearl_earring":
			# A checker sill and a brass handle on the jamb.
			for i in 4:
				draw_rect(Rect2(opening.position.x + i * opening.size.x / 4.0, bottom.position.y + 2.0, opening.size.x / 8.0, JAMB - 4.0), accent.lightened(0.3))
			draw_circle(Vector2(inner_x - inward * 2.0, opening.get_center().y), 2.4, accent)
		&"great_wave":
			# A split noren curtain over the top half, a white crest on each panel.
			var panel := opening.size.x / 2.0
			for i in 2:
				var cloth := Rect2(opening.position.x + i * panel + 1.0, opening.position.y, panel - 2.0, opening.size.y * 0.45)
				draw_rect(cloth, accent)
				draw_arc(Vector2(cloth.get_center().x, cloth.end.y - 6.0), panel * 0.3, PI, TAU, 8, Color(0.92, 0.9, 0.82), 1.5, true)
		&"grande_jatte":
			# Park-gate railings across the jambs, tipped with dots.
			for jamb: Rect2 in [top, bottom]:
				for i in 4:
					var x := jamb.position.x + 3.0 + i * (jamb.size.x - 6.0) / 3.0
					draw_line(Vector2(x, jamb.position.y), Vector2(x, jamb.end.y), trim.darkened(0.4), 1.5)
					draw_circle(Vector2(x, jamb.position.y), 1.6, accent)
		&"starry_night":
			# A swirl painted on each jamb.
			for jamb: Rect2 in [top, bottom]:
				draw_polyline(Gimmick.spiral(jamb.get_center(), 1.0, jamb.size.y * 0.4, 0.0, TAU * 1.3), accent, 1.4, true)
		&"earthly_delights":
			# Pointed stone arches on the jambs, ivy on the reveal.
			for jamb: Rect2 in [top, bottom]:
				# A dark pointed-arch niche cut in each stone jamb.
				var foot := jamb.end.y - 1.5
				var half := jamb.size.x * 0.22
				var niche := PackedVector2Array([Vector2(jamb.get_center().x - half, foot), Vector2(jamb.get_center().x - half, foot - jamb.size.y * 0.35), Vector2(jamb.get_center().x, jamb.position.y + 1.5), Vector2(jamb.get_center().x + half, foot - jamb.size.y * 0.35), Vector2(jamb.get_center().x + half, foot)])
				draw_colored_polygon(niche, DEEP)
			for i in 5:
				draw_circle(Vector2(inner_x - inward * REVEAL * 0.5, opening.position.y + 8.0 + i * (opening.size.y - 16.0) / 4.0), 2.2, accent)
		&"mona_lisa":
			# A velvet swag across the top and its tassels.
			var swag := PackedVector2Array()
			for i in 9:
				var t := i / 8.0
				swag.append(Vector2(opening.position.x + t * opening.size.x, opening.position.y + sin(t * PI) * 10.0))
			draw_polyline(swag, accent, 5.0, true)
			for x: float in [opening.position.x + 1.5, opening.end.x - 1.5]:
				draw_line(Vector2(x, opening.position.y), Vector2(x, opening.position.y + 16.0), Color(0.85, 0.68, 0.3), 2.0)


## The door leaf, swung `shut` of the way across the opening from its hinge at the far side.
func _draw_leaf(inner_x: float, inward: float) -> void:
	if shut <= 0.0:
		return
	var width := opening.size.x * shut
	var leaf := Rect2(opening.position.x if inward > 0.0 else opening.end.x - width, opening.position.y, width, opening.size.y)
	draw_rect(leaf, WOOD.lerp(WOOD_LIGHT, shut))
	draw_rect(leaf.grow(-3.0), WOOD.darkened(0.25), false, 1.2)
	draw_rect(leaf, INK, false, 1.2)
	if shut >= 1.0:
		draw_circle(Vector2(inner_x - inward * 4.0, opening.get_center().y), 2.0, Color(0.85, 0.68, 0.3))


## The lobby's hideout door in disguise: a bookcase swung a crack ajar, dark behind it.
func _draw_secret(inner_x: float, inward: float) -> void:
	draw_rect(opening, DEEP)
	var case := Rect2(opening.position.x + inward * 4.0, opening.position.y - JAMB, opening.size.x, opening.size.y + JAMB * 2.0)
	draw_rect(case, WOOD)
	var shelves := 4
	for s in shelves:
		var shelf_y := case.position.y + 4.0 + s * (case.size.y - 8.0) / shelves
		var x := case.position.x + 3.0
		var i := s * 2
		while x < case.end.x - 4.0:
			var book := 3.0 + (i % 3)
			draw_rect(Rect2(x, shelf_y + 2.0 + (i % 2), book, (case.size.y - 8.0) / shelves - 4.0 - (i % 2)), BOOKS[i % BOOKS.size()])
			x += book + 0.6
			i += 1
		draw_line(Vector2(case.position.x, shelf_y + (case.size.y - 8.0) / shelves), Vector2(case.end.x, shelf_y + (case.size.y - 8.0) / shelves), WOOD_LIGHT, 2.0)
	draw_rect(case, INK, false, 1.4)
	# The crack it stands ajar at, on the room side.
	draw_line(Vector2(inner_x + inward * 4.0, case.position.y), Vector2(inner_x + inward * 4.0, case.end.y), DEEP, 2.0)

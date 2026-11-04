class_name RoomHint
extends Node2D
## Where a room's trick is, shown once the mime has been caught Room.HINT_AFTER times there
## (the room's hint_in or hint_out, by which way the mime is going): a soft gilt halo round
## each frame or portrait to use (`rects`: soft bands round its edge, never over the picture)
## and a ring on each floor spot (`spots`: a puddle, a searchlight pool, parasol shade),
## breathing at HINT_HZ (a steady glow under Reduce Motion). The room draws it with its GLOW
## material, at full brightness against the night. Purely visual: nothing reads it.

const HINT_HZ := 0.7
const GILT := Color(0.95, 0.85, 0.4)
## The halo's soft reach beyond a painting's edge (at the breath's low and high), in fading
## bands with rounded corners, and how strong its innermost band is.
const HALO_LOW := 8.0
const HALO_HIGH := 16.0
const HALO_BANDS := 8
const HALO_CORNER := 4
const HALO_ALPHA := 0.45
## The floor ring's radius (it swells by RING_SWELL at the breath's high), its squash (the
## floor is seen at 3/4) and stroke.
const RING_RADIUS := 26.0
const RING_SWELL := 4.0
const RING_SQUASH := 0.45
const RING_WIDTH := 2.5
## The breath held under Reduce Motion (0 low, 1 high).
const STEADY := 0.7

## The frames' and portraits' tap rects (room units) to glow round, and the floor spots.
var rects: Array[Rect2] = []
var spots := PackedVector2Array()
var _clock := 0.0
var _halo := StyleBoxFlat.new()


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


## How far into its breath the glow is, 0 to 1 (STEADY under Reduce Motion).
func breath() -> float:
	return STEADY if GameState.reduce_motion_for(self) else 0.5 + 0.5 * sin(TAU * HINT_HZ * _clock)


func _draw() -> void:
	var glow := breath()
	var band := lerpf(HALO_LOW, HALO_HIGH, glow) / HALO_BANDS
	_halo.draw_center = false
	_halo.set_border_width_all(ceili(band) + 1)
	for rect in rects:
		for i in HALO_BANDS:
			_halo.border_color = Color(GILT, HALO_ALPHA * (0.6 + 0.4 * glow) * (1.0 - float(i) / HALO_BANDS))
			_halo.set_corner_radius_all(HALO_CORNER + ceili(band * (i + 1)))
			draw_style_box(_halo, rect.grow(band * (i + 1)))
	var radius := RING_RADIUS + RING_SWELL * glow
	for spot in spots:
		draw_set_transform(spot, 0.0, Vector2(1.0, RING_SQUASH))
		draw_circle(Vector2.ZERO, radius, Color(GILT, 0.12 + 0.1 * glow))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(GILT, 0.55 + 0.35 * glow), RING_WIDTH, true)
		draw_arc(Vector2.ZERO, radius + 6.0, 0.0, TAU, 48, Color(GILT, 0.2 * glow), RING_WIDTH * 0.6, true)
	draw_set_transform(Vector2.ZERO)

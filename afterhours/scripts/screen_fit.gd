class_name ScreenFit
extends Node
## Game's screen fit (a child of Game, Game.screen; not an autoload of its own): sizes the
## desktop window (fit_window), measures the visible area and its safe part (fit, on every
## viewport resize), centres the museum's 960x540 worlds on the safe area through the
## canvas transform (world_offset), shows the wordless rotate overlay and pauses the tree on
## a portrait screen, and moves the world for a screen shake or camera punch. Game keeps its
## public names (fit_screen, safe_rect, world_offset, shake, punch...) as thin delegates.

## A desktop window opens at this share of the usable screen, kept 16:9 (the 960x540 base
## is tiny on a high-DPI screen, where window sizes count physical pixels).
const WINDOW_SCREEN_SHARE := 0.85

## Emitted when the visible area or its safe part changes (world_offset() with them).
signal changed

## Tests set this (base units) to stand in for a notched screen's safe area; it applies from
## the next fit(). An empty rect means the display's own safe area.
var safe_area_override := Rect2()
## Whether the world is drawn at world_offset() (every flow but the title, a Control that
## fills the screen, drawn at the origin).
var centred := false
## Whether the rotate overlay paused the tree (it then unpauses on hiding; Game.goto sets it
## when a screen change under the overlay leaves the tree paused).
var paused_by_rotate := false
## The wordless rotate-phone overlay (Game's RotateLayer/RotateOverlay).
var rotate_overlay: Control
var _visible_rect := Rect2()
var _safe_rect := Rect2()
## The running screen shake (strength in base units) and camera punch (extra zoom), each
## easing to rest over its time (shake, punch).
var _shake_strength := 0.0
var _shake_time := 0.0
var _shake_left := 0.0
var _punch_zoom := 0.0
var _punch_time := 0.0
var _punch_left := 0.0


## Grows the desktop window to WINDOW_SCREEN_SHARE of the usable screen at 16:9 and centres
## it. The web canvas fills its page and headless runs have no screen, so both are skipped.
func fit_window() -> void:
	if OS.has_feature("web") or DisplayServer.get_name() == "headless":
		return
	var window := get_window()
	var usable := DisplayServer.screen_get_usable_rect(window.current_screen)
	var base := Vector2(window.content_scale_size)
	var scale := minf(usable.size.x / base.x, usable.size.y / base.y) * WINDOW_SCREEN_SHARE
	window.size = Vector2i(base * scale)
	window.position = usable.position + Vector2i(Vector2(usable.size - window.size) / 2.0)
	print("[Game] Window %s on a usable screen of %s" % [window.size, usable.size])


## The visible area in base units: 960x540, or larger on one axis (aspect expand).
func visible_rect() -> Rect2:
	return _visible_rect


## The part of the visible area clear of notches and rounded corners, in base units.
func safe_rect() -> Rect2:
	return _safe_rect


## Where the 960x540 base sits on screen: centred on the safe area (whole units), but kept
## inside the visible area, so a safe area shorter than the base (a phone's home-indicator
## inset) never crops the world.
func world_offset() -> Vector2:
	var centre := (_safe_rect.get_center() - Content.BASE / 2.0).round()
	return centre.clamp(_visible_rect.position, (_visible_rect.end - Content.BASE).max(_visible_rect.position))


## Converts the screen-pixel safe area to base units and clips it to `visible`. An empty
## safe area (headless, some browsers) means the whole visible rect.
static func safe_rect_in(visible: Rect2, safe_pixels: Rect2i, window_position: Vector2i, stretch: Transform2D) -> Rect2:
	if safe_pixels.size.x <= 0 or safe_pixels.size.y <= 0:
		return visible
	var local := Rect2(Vector2(safe_pixels.position - window_position), Vector2(safe_pixels.size))
	var clipped := (stretch.affine_inverse() * local).intersection(visible)
	return clipped if clipped.has_area() else visible


## Whether a visible area of `area` needs the rotate overlay: taller than wide.
static func is_portrait(area: Vector2) -> bool:
	return area.y > area.x


func is_rotate_overlay_shown() -> bool:
	return rotate_overlay.visible


## Measures the visible area and its safe part again, moves the world to world_offset() and
## shows or hides the rotate overlay; emits changed when either rect moved.
func fit() -> void:
	var window := get_window()
	var visible := get_viewport().get_visible_rect()
	var safe := safe_area_override if safe_area_override.has_area() else safe_rect_in(visible, DisplayServer.get_display_safe_area(), window.position, window.get_final_transform())
	if visible.is_equal_approx(_visible_rect) and safe.is_equal_approx(_safe_rect):
		return
	_visible_rect = visible
	_safe_rect = safe
	print("[Game] Screen fit: visible %s, safe %s, world at %s" % [visible, safe, world_offset()])
	place_world()
	_update_rotate_overlay()
	changed.emit()


## Draws the world at world_offset() when centred, else at the origin. A running shake moves
## it about and a punch zooms it about the world's centre.
func place_world() -> void:
	var offset := world_offset() if centred else Vector2.ZERO
	var zoom := 1.0
	if _punch_left > 0.0:
		zoom += _punch_zoom * _punch_left / _punch_time
	if _shake_left > 0.0:
		# Fixed waves, not random: runs stay repeatable.
		var t := _shake_time - _shake_left
		offset += Vector2(sin(t * 53.0), cos(t * 41.0)) * _shake_strength * _shake_left / _shake_time
	var centre := Content.BASE / 2.0
	get_viewport().canvas_transform = Transform2D(0.0, Vector2(zoom, zoom), 0.0, offset + centre * (1.0 - zoom))


## Shakes the world `strength` base units about, easing to rest over `seconds`.
func shake(strength: float, seconds: float) -> void:
	_shake_strength = strength
	_shake_time = seconds
	_shake_left = seconds


## Zooms the world in by `zoom` (0.04 is 4 %) about its centre, easing back over `seconds`.
func punch(zoom: float, seconds: float) -> void:
	_punch_zoom = zoom
	_punch_time = seconds
	_punch_left = seconds


## Ends a running shake and punch (the world stays where it is until place_world).
func stop_jolts() -> void:
	_shake_left = 0.0
	_punch_left = 0.0


## Whether a shake or a punch is moving the world.
func jolting() -> bool:
	return _shake_left > 0.0 or _punch_left > 0.0


func _process(delta: float) -> void:
	if not jolting():
		return
	_shake_left = maxf(_shake_left - delta, 0.0)
	_punch_left = maxf(_punch_left - delta, 0.0)
	place_world()


## Shows the rotate overlay and pauses the tree while the visible area is portrait; hides
## it and restores the pause state when it is landscape again.
func _update_rotate_overlay() -> void:
	var portrait := is_portrait(_visible_rect.size)
	if portrait == rotate_overlay.visible:
		return
	var tree := get_tree()
	if portrait:
		paused_by_rotate = not tree.paused
		tree.paused = true
		rotate_overlay.show()
		# Keys must not press a focused button hidden behind the overlay.
		get_viewport().gui_disable_input = true
		print("[Game] Rotate overlay shown (visible %s); tree paused" % _visible_rect.size)
	else:
		rotate_overlay.hide()
		get_viewport().gui_disable_input = false
		if paused_by_rotate:
			tree.paused = false
		print("[Game] Rotate overlay hidden (visible %s); tree %s" % [_visible_rect.size, "unpaused" if paused_by_rotate else "stays paused"])
		paused_by_rotate = false

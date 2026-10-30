class_name GameState
extends Node
## The one autoload (Game): the flow state, screen changes (goto: a fade to the museum's
## dark that blocks touches while it runs) and wordless error reporting.
## Every error goes to the log (push_error) and shows the cracked-frame ErrorBadge,
## never text (CLAUDE.md, "Errors are visible without words").

enum Flow { TITLE, ROOM }

## Scripts reach the autoload through this path (get_node(GameState.AUTOLOAD_PATH)), never
## the bare Game name, which tool runs (--script) cannot compile against.
const AUTOLOAD_PATH := ^"/root/Game"
## Seconds to fade out, and again to fade in, on a screen change.
const FADE_TIME := 0.25
## A desktop window opens at this share of the usable screen, kept 16:9 (the 960x540 base
## is tiny on a high-DPI screen, where window sizes count physical pixels).
const WINDOW_SCREEN_SHARE := 0.85

## Emitted when a goto's fade-in has finished.
signal transition_finished(flow: Flow)

## The scene each flow state runs (run_main.gd checks the running scene against it).
var scene_paths: Dictionary[Flow, String] = {
	Flow.TITLE: "res://scenes/title.tscn",
	Flow.ROOM: "res://scenes/room.tscn",
}
var state := Flow.TITLE
## Every error reported this run, oldest first.
var errors: Array[String] = []
## While true, report_error logs with print instead of push_error, so a test that
## provokes an error on purpose does not fail validate.sh's ERROR scan.
var quiet_errors := false
var _transitioning := false

@onready var _error_badge: TextureRect = $ErrorLayer/ErrorBadge
@onready var _cover: ColorRect = $CoverLayer/Cover


func _ready() -> void:
	_fit_window()


## Grows the desktop window to WINDOW_SCREEN_SHARE of the usable screen at 16:9 and centres
## it. The web canvas fills its page and headless runs have no screen, so both are skipped.
func _fit_window() -> void:
	if OS.has_feature("web") or DisplayServer.get_name() == "headless":
		return
	var window := get_window()
	var usable := DisplayServer.screen_get_usable_rect(window.current_screen)
	var base := Vector2(window.content_scale_size)
	var scale := minf(usable.size.x / base.x, usable.size.y / base.y) * WINDOW_SCREEN_SHARE
	window.size = Vector2i(base * scale)
	window.position = usable.position + Vector2i(Vector2(usable.size - window.size) / 2.0)
	print("[Game] Window %s on a usable screen of %s" % [window.size, usable.size])


## Changes to `flow`'s scene behind a fade (touches are blocked until it has faded in).
## Ignored while another change runs; a missing scene is reported and nothing changes.
func goto(flow: Flow) -> void:
	var to_name: String = Flow.keys()[flow]
	var path := scene_paths[flow]
	if _transitioning:
		print("[Game] Ignored goto %s while a transition is running" % to_name)
		return
	if not ResourceLoader.exists(path):
		report_error("Cannot go to %s: scene '%s' does not exist" % [to_name, path])
		return
	_transitioning = true
	print("[Game] %s -> %s (%s)" % [Flow.keys()[state], to_name, path])
	_cover.mouse_filter = Control.MOUSE_FILTER_STOP
	await _fade(1.0)
	var error := get_tree().change_scene_to_file(path)
	if error == OK:
		# The new scene enters the tree (and runs its _ready) at the end of this frame.
		await get_tree().scene_changed
	else:
		report_error("Failed to load scene '%s' for %s: %s" % [path, to_name, error_string(error)])
	await _fade(0.0)
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transitioning = false
	if error == OK:
		transition_finished.emit(flow)


func is_transitioning() -> bool:
	return _transitioning


func _fade(alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(_cover, "color:a", alpha, FADE_TIME)
	await tween.finished


## Called by each flow state's scene once it is ready.
func arrive(flow: Flow) -> void:
	state = flow
	print("[Game] Arrived at %s (%s)" % [Flow.keys()[flow], scene_paths[flow]])


func report_error(message: String) -> void:
	errors.append(message)
	if quiet_errors:
		print("[Game] Error (quiet): " + message)
	else:
		push_error(message)
	_error_badge.visible = true


func error_badge_visible() -> bool:
	return _error_badge.visible

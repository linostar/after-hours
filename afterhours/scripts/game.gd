class_name GameState
extends Node
## The one autoload (Game): the flow state and wordless error reporting.
## Every error goes to the log (push_error) and shows the cracked-frame ErrorBadge,
## never text (CLAUDE.md, "Errors are visible without words").

enum Flow { TITLE, ROOM }

## Scripts reach the autoload through this path (get_node(GameState.AUTOLOAD_PATH)), never
## the bare Game name, which tool runs (--script) cannot compile against.
const AUTOLOAD_PATH := ^"/root/Game"

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

@onready var _error_badge: TextureRect = $ErrorLayer/ErrorBadge


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

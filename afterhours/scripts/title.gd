extends Control
## The title screen (the main scene): a gilded frame on the gallery wall (where the logo
## will hang) holding the play button, which opens the hub (the museum lobby). Run with
## `-- --wing N` (N from 1) to start wing N at once (development, locked or not; an N out
## of range, or a wing whose data is broken, is reported).

## Starts a wing at once (development).
const WING_FLAG := "--wing"

@onready var _play: Button = $PlayButton


func _ready() -> void:
	var game := get_node(GameState.AUTOLOAD_PATH) as GameState
	_play.pressed.connect(game.goto.bind(GameState.Flow.HUB))
	_play.grab_focus()
	game.arrive(GameState.Flow.TITLE)
	_log_layout.call_deferred()
	var args := OS.get_cmdline_user_args()
	var at := args.find(WING_FLAG)
	if at >= 0:
		var number := int(args[at + 1]) if at + 1 < args.size() else 0
		if number >= 1 and number <= Content.WINGS.size():
			game.play_wing_file.call_deferred(Content.WINGS[number - 1])
		else:
			game.report_error("%s needs a wing number from 1 to %d (got '%s')" % [WING_FLAG, Content.WINGS.size(), " ".join(args.slice(at + 1, at + 2))])


## Where the play button landed (base units), for the web smoke test's taps.
func _log_layout() -> void:
	print("[Title] Play button at %s" % _play.get_global_rect())

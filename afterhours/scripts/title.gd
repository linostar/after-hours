extends Control
## The title screen (the main scene): a gilded frame on the gallery wall (where the logo
## will hang) holding the play button, which starts wing 1 (until the hub of step 7). A
## wing whose data is broken is reported (log and error badge) and not played.

@onready var _play: Button = $PlayButton


func _ready() -> void:
	var game := get_node(GameState.AUTOLOAD_PATH) as GameState
	_play.pressed.connect(_play_wing.bind(game, Content.WINGS[0]))
	_play.grab_focus()
	game.arrive(GameState.Flow.TITLE)
	_log_layout.call_deferred()


func _play_wing(game: GameState, path: String) -> void:
	var problems: Array[String] = []
	var wing := Content.load_wing(path, problems)
	for problem in problems:
		game.report_error("Wing data: " + problem)
	if wing != null:
		game.play_wing(wing)


## Where the play button landed (base units), for the web smoke test's taps.
func _log_layout() -> void:
	print("[Title] Play button at %s" % _play.get_global_rect())

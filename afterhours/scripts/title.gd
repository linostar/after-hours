extends Control
## The title screen (the main scene): an empty gilded frame on the gallery wall,
## where the logo will hang.


func _ready() -> void:
	(get_node(GameState.AUTOLOAD_PATH) as GameState).arrive(GameState.Flow.TITLE)

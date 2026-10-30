extends Control
## The title screen (the main scene): an empty gilded frame on the gallery wall,
## where the logo will hang.


func _ready() -> void:
	Game.arrive(GameState.Flow.TITLE)

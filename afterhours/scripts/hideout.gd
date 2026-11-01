class_name Hideout
extends Node2D
## The mime's hideout, wordless: one frame per wing along the back wall, in play order.
## A stolen original (its wing escaped from) hangs alive through its style shader, in a
## gilt frame when its best escape earned all three stars and in plain wood otherwise; a
## wing not yet robbed leaves its frame empty. Under each stolen original a replay button
## (Game.replay_ghost) shows the ghost mime's escape from its wing. The home button goes back
## to the hub.

const FIRST_X := 120.0
const GAP := 144.0
const FRAME_Y := 82.0
const FRAME_SIZE := Vector2(124, 100)
const REPLAY_ICON := preload("res://art/svg/icon_replay.svg")
## A replay button's side, and its centre's drop below its frame's centre.
const REPLAY_SIZE := 48.0
const REPLAY_DROP := 84.0

## Per wing (Content.WINGS order): its painting, or null while it is not stolen.
var originals: Array[FramedPainting] = []

@onready var _home: Button = $HomeButton
@onready var _game := get_node(GameState.AUTOLOAD_PATH) as GameState


func _ready() -> void:
	var ids := Content.wing_ids()
	var hung := 0
	for i in Content.WINGS.size():
		var at := Vector2(FIRST_X + i * GAP, FRAME_Y)
		var wing := load(Content.WINGS[i]) as WingData if Save.finished(_game.save, ids[i]) else null
		if wing == null:
			originals.append(null)
			_add_empty_frame(at)
			continue
		var original := FramedPainting.new()
		original.name = "Original%d" % (i + 1)
		original.size = FRAME_SIZE
		original.position = at
		original.gilded = Save.stars_of(_game.save, ids[i]) == 3
		original.painting = wing.painting
		$Originals.add_child(original)
		originals.append(original)
		_add_replay_button(i, at)
		hung += 1
	_home.pressed.connect(_game.goto.bind(GameState.Flow.HUB))
	_home.grab_focus()
	_game.arrive(GameState.Flow.HIDEOUT)
	print("[Hideout] %d original(s) hung, %d gilded" % [hung, originals.filter(func(each: FramedPainting) -> bool: return each != null and each.gilded).size()])


## The button under wing `index`'s original at `at` that replays the bot's escape from it.
func _add_replay_button(index: int, at: Vector2) -> void:
	var button := Button.new()
	button.name = "Replay%d" % (index + 1)
	button.accessibility_name = "Watch the ghost escape from wing %d" % (index + 1)
	button.icon = REPLAY_ICON
	button.flat = true
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.size = Vector2.ONE * REPLAY_SIZE
	button.position = at + Vector2(0.0, REPLAY_DROP) - button.size / 2.0
	button.pressed.connect(_game.replay_ghost.bind(Content.WINGS[index]))
	add_child(button)


## An empty frame's outline where a wing's original will hang.
func _add_empty_frame(at: Vector2) -> void:
	var outline := ReferenceRect.new()
	outline.border_color = Color(0.5, 0.42, 0.3, 0.6)
	outline.border_width = 3.0
	outline.editor_only = false
	outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outline.position = at - FRAME_SIZE / 2.0
	outline.size = FRAME_SIZE
	$Originals.add_child(outline)

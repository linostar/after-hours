class_name Hideout
extends Node2D
## The mime's hideout, wordless: one frame per wing along the back wall, in play order.
## A stolen original (its wing escaped from) hangs alive through its style shader, in a
## gilt frame when its best escape earned all three stars and in plain wood otherwise; a
## wing not yet robbed leaves its frame empty. Under each stolen original a replay button
## (Game.replay_ghost) shows the ghost mime's escape from its wing. The home button goes back
## to the hub. A wing's hidden sketch, once found (Save.has_sketch), is pinned to the wall
## at its frame's top corner, robbed or not. The lair is drawn by HideoutDecor (each replay
## button on its frame's plaque). Once every wing is finished, a clapperboard button beside
## home plays the finale again (Game.play_finale, back to the hideout). The mime stands about, alive at rest (CharacterRig: breathing, blinking, its
## invisible-wall gag).

const FIRST_X := 120.0
const GAP := 144.0
const FRAME_Y := 82.0
const FRAME_SIZE := Vector2(124, 100)
const REPLAY_ICON := preload("res://art/svg/icon_replay.svg")
## A replay button's side, and its centre's drop below its frame's centre.
const REPLAY_SIZE := 48.0
const REPLAY_DROP := 84.0
## A found sketch: its size on the wall, its centre from its frame's centre, its slant, and
## the pin through its top.
const SKETCH_SIZE := Vector2(34, 42)
const SKETCH_OFFSET := Vector2(58, -38)
const SKETCH_SLANT := 0.16
const PIN := Color(0.78, 0.16, 0.14)
## Once every wing is finished, the button that plays the finale again (beside home).
const FINALE_ICON := preload("res://art/svg/icon_finale.svg")
const FINALE_RECT := Rect2(100, 440, 64, 64)

## Per wing (Content.WINGS order): its painting, or null while it is not stolen.
var originals: Array[FramedPainting] = []

@onready var _home: Button = $HomeButton
@onready var _mime: CharacterRig = $Mime
@onready var _game := get_node(GameState.AUTOLOAD_PATH) as GameState


func _ready() -> void:
	var ids := Content.wing_ids()
	var hung := 0
	for i in Content.WINGS.size():
		var at := Vector2(FIRST_X + i * GAP, FRAME_Y)
		if Save.has_sketch(_game.save, ids[i]):
			_pin_sketch(i, StringName((load(Content.WINGS[i]) as WingData).painting))
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
		_add_replay_button(i)
		hung += 1
	($Decor as HideoutDecor).stolen.assign(originals.map(func(each: FramedPainting) -> bool: return each != null))
	_home.pressed.connect(_game.goto.bind(GameState.Flow.HUB))
	if _game.all_wings_finished():
		_add_finale_button()
	_home.grab_focus()
	_game.arrive(GameState.Flow.HIDEOUT)
	print("[Hideout] %d original(s) hung, %d gilded" % [hung, originals.filter(func(each: FramedPainting) -> bool: return each != null and each.gilded).size()])


func _physics_process(delta: float) -> void:
	_mime.walk(0.0, delta)


## Wing `index`'s found sketch of `painting`, pinned at its frame's top corner over the frame.
func _pin_sketch(index: int, painting: StringName) -> void:
	var texture: Texture2D = Paintings.SKETCHES.get(painting)
	if texture == null:
		_game.report_error("Hideout: no sketch for painting '%s' (wing %d)" % [painting, index + 1])
		return
	var paper := Sprite2D.new()
	paper.name = "Sketch%d" % (index + 1)
	paper.texture = texture
	paper.scale = SKETCH_SIZE / texture.get_size()
	paper.position = Vector2(FIRST_X + index * GAP, FRAME_Y) + SKETCH_OFFSET
	paper.rotation = SKETCH_SLANT
	paper.z_index = 1
	paper.draw.connect(func() -> void: paper.draw_circle(Vector2(0, -texture.get_height() * 0.5 + 5.0), 3.0 / paper.scale.x, PIN))
	$Originals.add_child(paper)


## The button on wing `index`'s plaque that replays the bot's escape from it.
func _add_replay_button(index: int) -> void:
	var button := Button.new()
	button.name = "Replay%d" % (index + 1)
	button.accessibility_name = "Watch the ghost escape from wing %d" % (index + 1)
	button.icon = REPLAY_ICON
	button.flat = true
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.size = Vector2.ONE * REPLAY_SIZE
	button.position = HideoutDecor.plaque_rect(index).get_center() - button.size / 2.0
	button.pressed.connect(_game.replay_ghost.bind(Content.WINGS[index]))
	add_child(button)


## The clapperboard button that plays the finale again, ending back in the hideout.
func _add_finale_button() -> void:
	var button := Button.new()
	button.name = "FinaleButton"
	button.accessibility_name = "Watch the ending again"
	button.icon = FINALE_ICON
	button.flat = true
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.position = FINALE_RECT.position
	button.size = FINALE_RECT.size
	button.pressed.connect(_game.play_finale.bind(GameState.Flow.HIDEOUT))
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

class_name Hub
extends Node2D
## The museum lobby, the level select, walked like a room: the wings' doors (WingDoor) line
## the back wall in play order. A tap on an open door walks the mime there and through it
## into the wing (Game.play_wing_file); a tap on a locked one rattles its chain; a tap on
## the floor walks the mime there. Wing 1 is open from the start, each other wing once the
## one before it was escaped from (Save.unlocked). The keyboard walks the mime and E uses
## the nearest door within Room.INTERACT_REACH. The HideoutDoor in the left wall (glowing
## once an original was stolen) leads to the hideout. The mime starts at Entrance, in front
## of the door of the wing it comes back from, or inside the hideout door.

const FIRST_DOOR_X := 120.0
const DOOR_GAP := 144.0
const DOOR_Y := 196.0
## Where a mime coming back from a wing stands, from that wing's door.
const BACK_FROM_WING := Vector2(0, 70)

var wing_doors: Array[WingDoor] = []
## The door the mime is walking to (a WingDoor or the hideout's Door).
var _target: Node2D

@onready var mime: Mime = $Actors/Mime
@onready var hideout_door: Door = $HideoutDoor
@onready var _floor: FloorInput = $FloorInput
@onready var _keys: KeyboardInput = $KeyboardInput
@onready var _game := get_node(GameState.AUTOLOAD_PATH) as GameState


func _ready() -> void:
	($Navigation as NavigationRegion2D).bake_navigation_polygon(false)
	var ids := Content.wing_ids()
	var came_from := -1
	for i in Content.WINGS.size():
		var door := WingDoor.new()
		door.name = "WingDoor%d" % (i + 1)
		door.index = i
		door.position = Vector2(FIRST_DOOR_X + i * DOOR_GAP, DOOR_Y)
		var problems: Array[String] = []
		var wing := Content.load_wing(Content.WINGS[i], problems)
		for problem in problems:
			_game.report_error("Wing data: " + problem)
		door.broken = wing == null
		door.painting = wing.painting if wing != null else ""
		door.open = wing != null and Save.unlocked(_game.save, ids, i)
		door.finished = Save.finished(_game.save, ids[i])
		door.stars = Save.stars_of(_game.save, ids[i])
		$Doors.add_child(door)
		wing_doors.append(door)
		if _game.run != null and _game.run.wing.resource_path == Content.WINGS[i]:
			came_from = i
	hideout_door.glowing = not _game.save["wings"].is_empty()
	var start := ($Entrance as Node2D).position
	if _game.state == GameState.Flow.HIDEOUT:
		start = hideout_door.arrival_point()
	elif came_from >= 0:
		start = wing_doors[came_from].position + BACK_FROM_WING
	mime.place_at(start)
	_floor.tapped.connect(_on_floor_tapped)
	_keys.interacted.connect(_on_interacted)
	_game.arrive(GameState.Flow.HUB)
	# The layout, for the web smoke test's taps.
	for door in wing_doors:
		print("[Hub] Wing door %d at %s (%s, %d star(s))" % [door.index + 1, door.position, "broken" if door.broken else "open" if door.open else "locked", door.stars])
	print("[Hub] Hideout door at %s" % hideout_door.position)


func _physics_process(delta: float) -> void:
	if _game.is_transitioning():
		return
	var walk := _keys.direction()
	if walk != Vector2.ZERO:
		_target = null
		mime.nudge(walk, delta)
	if _target != null and not mime.walking and mime.position.distance_to(_target.position) <= Door.REACH:
		var door := _target
		_target = null
		if door == hideout_door:
			print("[Hub] Into the hideout")
			_game.goto(GameState.Flow.HIDEOUT)
			return
		print("[Hub] Through wing door %d" % ((door as WingDoor).index + 1))
		_game.play_wing_file(Content.WINGS[(door as WingDoor).index])


func _on_floor_tapped(at: Vector2) -> void:
	if _game.is_transitioning():
		return
	_target = null
	for door in wing_doors:
		if door.rect().has_point(at):
			if door.open:
				_target = door
				mime.walk_to(door.position)
			else:
				door.rattle()
				print("[Hub] Wing door %d is %s" % [door.index + 1, "broken" if door.broken else "locked"])
			return
	if hideout_door.rect().has_point(at):
		_target = hideout_door
		mime.walk_to(hideout_door.position)
		return
	mime.walk_to(at)


## E: uses the nearest door within Room.INTERACT_REACH.
func _on_interacted() -> void:
	var best: Node2D
	var best_distance := Room.INTERACT_REACH
	var doors: Array[Node2D] = [hideout_door]
	doors.append_array(wing_doors)
	for door in doors:
		var distance := mime.position.distance_to(door.position)
		if distance <= best_distance:
			best = door
			best_distance = distance
	if best != null:
		_on_floor_tapped(best.position)

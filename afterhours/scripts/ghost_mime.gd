class_name GhostMime
extends Node2D
## The ghost mime, the wordless tutorial: a see-through mime replaying the playtest bot's
## escape (its ghost replay, data/ghosts/<wing id>.ghost.json: a [room, x, y, hidden]
## sample every gap_frames physics frames of room time) through the room it is in, a step
## ahead of the player, while the wing has never been escaped from. It walks the bot's
## route at the bot's pace, fades out while the bot hid in a portrait, and fades away at
## the end of its visit. The room plays the samples of the matching visit (the n-th time
## the mime comes into this room, the bot's n-th stay there) and restarts it after a toss.

## Where the bot keeps the ghost replays of the wings in WINGS_DIR (a wing elsewhere, a test
## fixture, keeps its own beside it).
const DIR := "res://data/ghosts/"
const WINGS_DIR := "res://data/wings/"
const TINT := Color(0.72, 0.86, 1.0, 0.5)
## How fast the ghost fades in and out (alpha per second).
const FADE_RATE := 3.0

## The samples of this visit, as [x, y, hidden], and the seconds between two of them.
var samples: Array[Array] = []
var period := 0.1
## Seconds into the visit.
var time := 0.0

@onready var _sprite: Sprite2D = $Sprite


## The ghost replay's path for the wing at `wing_path` (where tools/bot.gd records it).
static func path_for(wing_path: String) -> String:
	var dir := DIR if wing_path.get_base_dir() + "/" == WINGS_DIR else wing_path.get_base_dir() + "/"
	return dir + wing_path.get_file().get_basename() + ".ghost.json"


## Reads the ghost replay at `path`: {"period": seconds, "trail": [[room, x, y, hidden], ...]},
## or {} with a problem appended to `problems` (missing, not JSON, or a bad sample).
static func load_replay(path: String, problems: Array[String]) -> Dictionary:
	if not FileAccess.file_exists(path):
		problems.append("ghost replay '%s' does not exist" % path)
		return {}
	# JSON.new().parse reports bad JSON here, where JSON.parse_string would log an engine error.
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		problems.append("ghost replay '%s' is not JSON (line %d: %s)" % [path, json.get_error_line(), json.get_error_message()])
		return {}
	var parsed: Variant = json.data
	if not parsed is Dictionary or not parsed.get("trail") is Array or not parsed.get("gap_frames") is float:
		problems.append("ghost replay '%s' is not {gap_frames, trail} JSON" % path)
		return {}
	var trail: Array = parsed["trail"]
	for i in trail.size():
		var sample: Variant = trail[i]
		if not sample is Array or sample.size() != 4 or not sample[0] is float or not sample[1] is float or not sample[2] is float or not sample[3] is bool:
			problems.append("ghost replay '%s': sample %d is not [room, x, y, hidden]" % [path, i])
			return {}
	return {"period": parsed["gap_frames"] / 60.0, "trail": trail}


## The samples ([x, y, hidden]) of the bot's `visit`-th stay (from 0) in room `room`: the
## visit-th run of consecutive samples in that room; empty when it stayed fewer times.
static func visit_samples(trail: Array, room: int, visit: int) -> Array[Array]:
	var found: Array[Array] = []
	var seen := -1
	var previous := -1
	for sample: Array in trail:
		var in_room := int(sample[0]) == room
		if in_room and previous != room:
			seen += 1
		previous = int(sample[0])
		if in_room and seen == visit:
			found.append([float(sample[1]), float(sample[2]), sample[3]])
		elif seen > visit:
			break
	return found


## The room the bot went to after its `visit`-th stay (from 0) in room `room`, or -1 when
## that stay ended the trail (the escape) or never happened.
static func room_after(trail: Array, room: int, visit: int) -> int:
	var seen := -1
	var previous := -1
	for sample: Array in trail:
		var at := int(sample[0])
		if at == room and previous != room:
			seen += 1
		elif at != room and previous == room and seen == visit:
			return at
		previous = at
	return -1


func _ready() -> void:
	_sprite.modulate = TINT
	_sprite.modulate.a = 0.0
	restart()


## Starts the visit again from its first sample.
func restart() -> void:
	time = 0.0
	if not samples.is_empty():
		position = Vector2(samples[0][0], samples[0][1])


## Whether the visit's samples have all played.
func is_done() -> bool:
	return time >= (samples.size() - 1) * period


## Moves along the samples by `delta` seconds of room time (the room calls it, so it stops
## when the room's timer does).
func advance(delta: float) -> void:
	if samples.is_empty():
		return
	time += delta
	var at := time / period
	var index := mini(floori(at), samples.size() - 1)
	var next := mini(index + 1, samples.size() - 1)
	var from := Vector2(samples[index][0], samples[index][1])
	position = from.lerp(Vector2(samples[next][0], samples[next][1]), clampf(at - index, 0.0, 1.0))
	var shown: bool = not is_done() and not samples[index][2]
	_sprite.modulate.a = move_toward(_sprite.modulate.a, TINT.a if shown else 0.0, FADE_RATE * delta)

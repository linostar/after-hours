class_name EscapeBeat
extends RefCounted
## The escape's curtain call before the results (a part of Room, which plays it once the
## escape is recorded): the mime turns to the room and tips its beret (Room.ESCAPE_TIP), slips
## into the exit's doorway fading out (Room.ESCAPE_SLIP), the door swings shut, and after
## Room.ESCAPE_HOLD it ends (Room.escape_beat_time in all). skip (a tap or E) ends it at once.

## Emitted once when the beat ends, played out or skipped: time for the results.
signal ended

## Whether the beat plays (started, not ended yet).
var playing := false
var _room: Room
var _game: GameState
var _beat: Tween
## The tweens the beat started (the slip, the fade, the door's swing).
var _parts: Array[Tween] = []


func _init(of: Room) -> void:
	_room = of
	_game = of.get_node(GameState.AUTOLOAD_PATH) as GameState


func play() -> void:
	var mime := _room.mime
	var door := _room.exit_door
	playing = true
	mime.face(Vector2.DOWN)
	mime.rig.start_fidget(CharacterRig.Fidget.TIP, Room.ESCAPE_TIP)
	var doorway := door.position + door.opening.get_center()
	_beat = _room.create_tween()
	_beat.tween_interval(Room.ESCAPE_TIP)
	_beat.tween_callback(func() -> void: _parts.append_array([mime.glide(doorway, Room.ESCAPE_SLIP), mime.fade_out(Room.ESCAPE_SLIP)]))
	_beat.tween_interval(Room.ESCAPE_SLIP)
	_beat.tween_callback(func() -> void: _parts.append(door.swing_shut()))
	_beat.tween_interval(Door.SHUT_TIME + Room.ESCAPE_HOLD)
	_beat.tween_callback(_end)
	print("[Room] Escape beat")


## Skips the rest of the beat (its slip, fade and swing too): the mime gone, the door shut
## (its thud, unless it already sounded), the results now.
func skip() -> void:
	var door := _room.exit_door
	_beat.kill()
	for part in _parts:
		part.kill()
	_room.mime.rig.modulate.a = 0.0
	if door.shut < 1.0:
		_game.audio.play(&"door")
	door.shut = 1.0
	door.glowing = false
	print("[Room] Escape beat skipped")
	_end()


func _end() -> void:
	if not playing:
		return
	playing = false
	ended.emit()

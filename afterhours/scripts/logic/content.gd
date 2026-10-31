class_name Content
extends RefCounted
## The museum's wings, in play order, and the check every wing's data must pass before it
## is played: validate lists what is wrong with a WingData (empty when nothing is), each
## problem naming the file and the field.

## The wings' data files, wing 1 first.
const WINGS: Array[String] = []
## The forgery canvas's paper size, in canvas units (scenes/forgery_canvas.tscn's Pad):
## every ghost point must lie on it, edges included.
const CANVAS := Vector2(320, 240)


## What is wrong with `wing`, loaded from `path` (one line per problem; empty when valid).
static func validate(wing: WingData, path: String) -> Array[String]:
	if wing == null:
		return ["%s: is not a WingData" % path]
	var problems: Array[String] = []
	if StringName(wing.painting) not in Paintings.IDS:
		problems.append("%s: painting '%s' is not one of %s" % [path, wing.painting, Paintings.IDS])
	if wing.rooms.is_empty():
		problems.append("%s: rooms is empty" % path)
	for i in wing.rooms.size():
		var room := wing.rooms[i]
		if not room.ends_with(".tscn") or not ResourceLoader.exists(room):
			problems.append("%s: rooms[%d] '%s' is not a scene that exists" % [path, i, room])
	if wing.par_time <= 0.0:
		problems.append("%s: par_time %.1f is not above 0" % [path, wing.par_time])
	if wing.ghosts.is_empty():
		problems.append("%s: ghosts is empty" % path)
	for i in wing.ghosts.size():
		var ghost := wing.ghosts[i]
		if ghost.is_empty():
			problems.append("%s: ghosts[%d] has no points" % [path, i])
		for point in ghost:
			if point.x < 0.0 or point.y < 0.0 or point.x > CANVAS.x or point.y > CANVAS.y:
				problems.append("%s: ghosts[%d] point %s is off the canvas %s" % [path, i, point, CANVAS])
				break
	return problems


## The wing at `path`, or null with its problems (validate, or a failed load) in `problems`.
static func load_wing(path: String, problems: Array[String]) -> WingData:
	var wing := load(path) as WingData if ResourceLoader.exists(path) else null
	problems.append_array(validate(wing, path))
	return wing if problems.is_empty() else null

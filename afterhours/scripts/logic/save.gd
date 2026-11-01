class_name Save
extends RefCounted
## The save's shape, pure (Game reads and writes the file): a versioned JSON object with
## the progress per wing (its id, the wing file's name: the best stars of one escape and
## the best escape time) and the settings. parse() turns a save's text back into that data
## or names what is wrong with it; record() keeps a wing's best; unlocked() tells which
## wings the hub opens: the first, and each one after a wing that was escaped from.

const VERSION := 1
## The settings and their defaults.
const SETTINGS := {"music": true, "sound": true, "reduce_motion": false, "assist": false}


## A fresh save: no wing finished, default settings.
static func defaults() -> Dictionary:
	return {"version": VERSION, "wings": {}, "settings": SETTINGS.duplicate()}


static func to_json(data: Dictionary) -> String:
	return JSON.stringify(data, "  ")


## The save in `text`, or {} with what is wrong appended to `problems`. A setting the save
## lacks takes its default (an older save, a newer setting); anything else that is missing
## or of the wrong kind makes the whole save corrupt.
static func parse(text: String, problems: Array[String]) -> Dictionary:
	var json := JSON.new()
	if json.parse(text) != OK:
		problems.append("not JSON (line %d: %s)" % [json.get_error_line(), json.get_error_message()])
		return {}
	if not json.data is Dictionary:
		problems.append("not a JSON object")
		return {}
	var raw: Dictionary = json.data
	if not _is_whole(raw.get("version")) or int(raw["version"]) != VERSION:
		problems.append("version is %s, expected %d" % [raw.get("version"), VERSION])
		return {}
	var data := defaults()
	if not raw.get("wings") is Dictionary:
		problems.append("wings is not an object")
		return {}
	for id: Variant in raw["wings"]:
		var entry: Variant = raw["wings"][id]
		if not entry is Dictionary or not _is_whole(entry.get("stars")) or entry["stars"] < 0 or entry["stars"] > 3 \
				or not (entry.get("time") is float or entry.get("time") is int) or entry["time"] < 0.0:
			problems.append("wing '%s' is %s, expected {stars: 0 to 3, time: seconds}" % [id, entry])
			return {}
		data["wings"][id] = {"stars": int(entry["stars"]), "time": float(entry["time"])}
	var settings: Variant = raw.get("settings", {})
	if not settings is Dictionary:
		problems.append("settings is not an object")
		return {}
	for key: String in SETTINGS:
		var value: Variant = settings.get(key, SETTINGS[key])
		if not value is bool:
			problems.append("setting '%s' is %s, expected true or false" % [key, value])
			return {}
		data["settings"][key] = value
	return data


## Keeps an escape from wing `id` with `stars` (Stars.Star order) after `time` seconds:
## the best star count and the best time, each on its own. Returns whether either improved.
static func record(data: Dictionary, id: String, stars: Array[bool], time: float) -> bool:
	var count := Stars.count(stars)
	var best: Dictionary = data["wings"].get(id, {})
	if not best.is_empty() and best["stars"] >= count and best["time"] <= time:
		return false
	data["wings"][id] = {
		"stars": maxi(count, best.get("stars", 0)),
		"time": minf(time, best.get("time", INF)),
	}
	return true


## Whether the hub opens the wing at `index` of `ids` (the wings in play order).
static func unlocked(data: Dictionary, ids: Array[String], index: int) -> bool:
	return index == 0 or (index > 0 and index < ids.size() and data["wings"].has(ids[index - 1]))


## The best stars of wing `id` (0 if never escaped from), and whether it was escaped from.
static func stars_of(data: Dictionary, id: String) -> int:
	return data["wings"].get(id, {}).get("stars", 0)


static func finished(data: Dictionary, id: String) -> bool:
	return data["wings"].has(id)


## JSON numbers load as floats: a whole number only, and only one a float holds exactly.
static func _is_whole(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value) and value == floorf(value) and absf(value) <= 9007199254740992.0)

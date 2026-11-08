class_name SaveFile
extends RefCounted
## The save on disk (static, no nodes): reads and writes Save's shape as JSON at a path.
## Problems come back as messages in `problems` for Game.report_error, so this class never
## names the autoload. Logs keep Game's "[Game]" prefix (the save is Game's).


## Where a corrupt save at `path` is kept (one backup: the latest corrupt save replaces it).
static func backup_path(path: String) -> String:
	return path.get_basename() + ".corrupt.json"


## Reads the save at `path`: defaults when there is none. A corrupt one is moved to
## backup_path(path), one message is appended to `problems` and defaults come back (the
## caller writes them over it).
static func read(path: String, problems: Array[String]) -> Dictionary:
	if not FileAccess.file_exists(path):
		print("[Game] No save at %s; starting fresh" % path)
		return Save.defaults()
	var found: Array[String] = []
	var loaded := Save.parse(FileAccess.get_file_as_string(path), found)
	if loaded.is_empty():
		var backup := backup_path(path)
		var moved := DirAccess.rename_absolute(path, backup)
		problems.append("Save '%s' is corrupt (%s); %s, and a fresh save replaces it" % [path, "; ".join(found), "it was moved to '%s'" % backup if moved == OK else "it could not be moved to '%s' (%s)" % [backup, error_string(moved)]])
		return Save.defaults()
	print("[Game] Loaded the save from %s: %d wing(s) finished, settings %s" % [path, loaded["wings"].size(), loaded["settings"]])
	return loaded


## Writes `save` to `path` through a temporary file, so a failed write leaves the last good
## save; returns whether it worked (a failure appends one message to `problems`).
static func write(path: String, save: Dictionary, problems: Array[String]) -> bool:
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		problems.append("Cannot open '%s' to write the save: %s; '%s' is unchanged" % [temp, error_string(FileAccess.get_open_error()), path])
		return false
	var written := file.store_string(Save.to_json(save))
	file.close()
	var replaced := DirAccess.rename_absolute(temp, path) if written else FAILED
	if replaced != OK:
		DirAccess.remove_absolute(temp)
		problems.append("Cannot write the save to '%s' (%s); it is unchanged" % [path, error_string(replaced)])
		return false
	print("[Game] Saved to %s: %d wing(s) finished, settings %s" % [path, save["wings"].size(), save["settings"]])
	return true

extends SceneTree
## Project gate for the No Text restriction and the touch-first, landscape rules:
## - No Text (the mandatory jam restriction): no script, scene or resource names a text
##   class (TEXT_CLASSES: labels, text editors, SpinBox, menus, lists, tabs, dialogs,
##   fonts, text meshes and lines) or a text call or property (TEXT_TOKENS: draw_string
##   and its kin, tooltips, placeholders, theme fonts, OS.alert); no script sets a
##   Control's text (`.text = ...`, `set_text(`); no Button in a saved scene shows text;
##   the project holds no font file (FONT_EXTENSIONS) and no binary scene or resource
##   (BINARY_EXTENSIONS, unreadable to these scans). The logo and key labels are art.
## - public domain scans: every image in SCANS_DIR has a complete SOURCES.json entry
##   (SCAN_FIELDS, a year before PUBLIC_DOMAIN_BEFORE, an https source_url, a sha256),
##   and every entry's file exists,
## - project.godot defines no input actions besides the built-in ui_* ones,
## - no script (standalone or embedded in .tscn/.tres) reads mouse events at all
##   (emulate_touch_from_mouse turns the mouse into touches), and none outside
##   res://scripts/ui/ handles raw input: touch, drag, gesture, key or joypad events,
##   input callbacks (_input, _gui_input, ...) or gui_input/input_event signal
##   connections, action, key or joypad polling,
## - no script filters on touch index 0 (a web build's index is the browser's
##   Touch.identifier, which iOS Safari makes large and never 0),
## - every interactive Control in a saved scene is at least MIN_TARGET base units on
##   both axes; every BaseButton can take keyboard focus; an icon-only Button (no
##   text) and every TextureButton carry an accessibility_name,
## - in screen scenes (a root Control that fills the screen, or a root that is not a
##   Control: a CanvasLayer HUD, a Node2D game scene), every interactive Control lies
##   inside the screen (the 960x540 base, which is the whole safe area there: one that
##   leaves it leaves the safe area of every screen).
## Also compiles every script: project.godot raises GDScript warnings to errors,
## so any warning fails here.
## Usage (from repo root): "$GODOT" --headless --path afterhours --script "$PWD/tools/check_project.gd"
## Prints "check_project: OK" on success; exits 1 and prints every violation otherwise
## (SCRIPT ERROR lines above them give compile details).
##
## Limits: this is a text and saved-scene scan. It does not see Controls created at
## runtime (Button.new()), input read through indirection (a variable holding an event
## class name), an index-0 filter written another way (a match on the index, the index
## copied into a variable first; only member `.index` and `*touch_index`/`*finger_index`
## names are matched, so an `index` from find() is fine), or layouts that only exist
## after a script moves nodes. Scenes are measured in a 960x540 window after two frames,
## so a Control sized by its script's _ready() is measured as the script leaves it.
## Control-rooted scenes that do not fill the screen are parts, checked for size only.
## A custom action named ui_something is indistinguishable from a built-in one here.
## The No Text scan matches names anywhere in a file, comments included (write "text
## node" rather than a class name in a comment); it cannot see words drawn into an
## image, or text set through indirection (`set("text", ...)`, `text = ...` on self inside
## a Button script) or a scan stored outside SCANS_DIR.

const UI_INPUT_PATH := "res://scripts/ui/"
## Mouse input: forbidden everywhere, scripts/ui/ included.
## "mouse_position" also covers get_global_mouse_position and get_local_mouse_position;
## the DisplayServer reads and the CollisionObject mouse virtuals and signals are listed
## by name (emulate_touch_from_mouse does not turn them into touches).
const MOUSE_TOKENS: Array[String] = [
	"InputEventMouse", "mouse_position", "get_last_mouse_velocity", "get_last_mouse_screen_velocity",
	"is_mouse_button_pressed", "get_mouse_button_mask", "mouse_entered", "mouse_exited",
	"mouse_get_position", "mouse_get_button_state", "_mouse_enter", "_mouse_exit",
	"_mouse_shape_enter", "_mouse_shape_exit", "mouse_shape_entered", "mouse_shape_exited",
]
## Raw input reads, input callbacks and polling: only scripts/ui/ may use them.
const RAW_INPUT_TOKENS: Array[String] = [
	"InputEventScreenTouch", "InputEventScreenDrag", "InputEventKey", "InputEventJoypad",
	"InputEventGesture", "InputEventMagnifyGesture", "InputEventPanGesture",
	"func _input", "func _unhandled_input", "func _unhandled_key_input", "func _shortcut_input", "func _gui_input",
	"gui_input.connect", "signal=\"gui_input\"", "input_event.connect", "signal=\"input_event\"",
	"is_key_pressed", "is_physical_key_pressed", "is_key_label_pressed", "is_joy_button_pressed", "get_joy_axis",
	"is_action", "get_action_strength", "get_action_raw_strength", "get_axis", "get_vector", "is_anything_pressed",
]
## Classes that show or edit text (SpinBox shows its number as text), matched as whole words.
const TEXT_CLASSES: Array[String] = [
	"Label", "Label3D", "LabelSettings", "RichTextLabel", "LineEdit", "TextEdit", "CodeEdit", "SpinBox",
	"LinkButton", "OptionButton", "MenuButton", "MenuBar", "PopupMenu", "ItemList", "Tree", "TabBar",
	"TabContainer", "AcceptDialog", "ConfirmationDialog", "FileDialog", "Font", "FontFile", "FontVariation",
	"SystemFont", "TextMesh", "TextLine", "TextParagraph", "TextServer", "TextServerManager",
]
## Text drawing calls and text-bearing properties, matched as substrings.
const TEXT_TOKENS: Array[String] = [
	"draw_string", "draw_multiline_string", "draw_char", "tooltip_text", "set_tooltip", "placeholder_text",
	"fallback_font", "get_theme_font", "get_theme_default_font", "theme_override_fonts", "OS.alert",
]
## A script that sets a Control's text.
const TEXT_SET_PATTERN := "\\.text\\s*\\+?=(?!=)|\\bset_text\\s*\\("
## Binary scenes and resources: the text scans cannot read them.
const BINARY_EXTENSIONS: Array[String] = ["scn", "res"]
const FONT_EXTENSIONS: Array[String] = ["ttf", "otf", "ttc", "woff", "woff2", "fnt", "pfb", "pfm"]
const SCANS_DIR := "res://art/scans/"
const SOURCES_PATH := "res://art/scans/SOURCES.json"
const SCAN_EXTENSIONS: Array[String] = ["png", "jpg", "jpeg", "webp"]
## Every SOURCES.json entry's fields (all non-empty).
const SCAN_FIELDS: Array[String] = ["id", "file", "artist", "title", "year", "source_url", "licence", "sha256"]
## Jam rule: an artwork used directly must be made before this year.
const PUBLIC_DOMAIN_BEFORE := 1923
## A touch index (a member `.index`, or a `*touch_index`/`*finger_index` name) compared
## with 0 (either side), or "below 1".
const INDEX_ZERO_PATTERN := "(?:\\.index|\\b\\w*(?:touch|finger)_index)\\s*(==|!=|<=|>=|<|>)\\s*0\\b|\\b0\\s*(==|!=|<=|>=|<|>)\\s*(?:[\\w.]*\\.index|\\w*(?:touch|finger)_index)\\b|(?:\\.index|\\b\\w*(?:touch|finger)_index)\\s*<\\s*1\\b"
const SOURCE_EXTENSIONS: Array[String] = ["gd", "tscn", "tres"]
const BASE_SIZE := Vector2i(960, 540)
const MIN_TARGET := 44.0
## How far (base units) a Control's rect may round past the screen's edge.
const SCREEN_TOLERANCE := 0.5

var _violations: Array[String] = []
var _index_zero := RegEx.create_from_string(INDEX_ZERO_PATTERN)
var _text_set := RegEx.create_from_string(TEXT_SET_PATTERN)
var _text_class := RegEx.create_from_string("\\b(%s)\\b" % "|".join(TEXT_CLASSES))
var _sha256 := RegEx.create_from_string("^[0-9a-f]{64}$")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = BASE_SIZE
	_check_actions()
	var files: Array[String] = []
	_collect_files("res://", files)
	for path in files:
		if path.ends_with(".gd"):
			_check_compiles(path)
		if path.get_extension() in SOURCE_EXTENSIONS:
			_check_source(path)
		if path.get_extension().to_lower() in FONT_EXTENSIONS:
			_violations.append("%s: is a font file (No Text: the game ships no fonts; draw the logo and key labels as art)" % path)
		if path.get_extension() in BINARY_EXTENSIONS:
			_violations.append("%s: is a binary scene or resource (save it as .tscn/.tres so the gates can read it)" % path)
	_check_scans(files)
	for path in files:
		if path.ends_with(".tscn"):
			await _check_scene(path)
	if _violations.is_empty():
		print("check_project: OK (%d files scanned)" % files.size())
		quit(0)
		return
	for violation in _violations:
		printerr("check_project: " + violation)
	printerr("check_project: FAILED with %d violation(s)" % _violations.size())
	quit(1)


## Only the built-in ui_* actions may exist (overriding their events is allowed).
func _check_actions() -> void:
	for property in ProjectSettings.get_property_list():
		var name: String = property["name"]
		if name.begins_with("input/") and not name.begins_with("input/ui_"):
			_violations.append("project.godot defines input action '%s' (only built-in ui_* actions are allowed)" % name.trim_prefix("input/"))


func _check_compiles(path: String) -> void:
	var script := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as GDScript
	if script == null or not script.can_instantiate():
		_violations.append("%s: fails to compile (warnings count as errors)" % path)


func _check_source(path: String) -> void:
	var source := _read_text(path)
	for token in MOUSE_TOKENS:
		if token in source:
			_violations.append("%s: uses '%s' (mouse input arrives as touch; read InputEventScreenTouch/Drag in scripts/ui/)" % [path, token])
	if not path.begins_with(UI_INPUT_PATH):
		for token in RAW_INPUT_TOKENS:
			if token in source:
				_violations.append("%s: uses '%s' (raw input handling belongs in scripts/ui/)" % [path, token])
	var text_classes: Array[String] = []
	for found in _text_class.search_all(source):
		if found.get_string() not in text_classes:
			text_classes.append(found.get_string())
	for name in text_classes:
		_violations.append("%s: uses '%s' (No Text: the game shows no written words; draw it as art)" % [path, name])
	for token in TEXT_TOKENS:
		if token in source:
			_violations.append("%s: uses '%s' (No Text: the game shows no written words; draw it as art)" % [path, token])
	var lines := source.split("\n")
	for i in lines.size():
		if _index_zero.search(lines[i]) != null:
			_violations.append("%s:%d: filters on touch index 0 (iOS Safari touch indices are large, never 0)" % [path, i + 1])
		if path.ends_with(".gd") and _text_set.search(lines[i]) != null:
			_violations.append("%s:%d: sets a Control's text (No Text: the game shows no written words)" % [path, i + 1])


func _read_text(path: String) -> String:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty() and FileAccess.get_open_error() != OK:
		_violations.append("%s: cannot read file (error %d)" % [path, FileAccess.get_open_error()])
	return text


## Every scan in SCANS_DIR has a complete, public-domain SOURCES.json entry, and every
## entry's file exists.
func _check_scans(files: Array[String]) -> void:
	var scans: Array[String] = []
	for path in files:
		if path.begins_with(SCANS_DIR) and path.get_extension().to_lower() in SCAN_EXTENSIONS:
			scans.append(path.trim_prefix(SCANS_DIR))
	if not FileAccess.file_exists(SOURCES_PATH):
		for scan in scans:
			_violations.append("%s%s: scan has no entry in %s (the file does not exist)" % [SCANS_DIR, scan, SOURCES_PATH])
		return
	var parsed: Variant = JSON.parse_string(_read_text(SOURCES_PATH))
	if not parsed is Array:
		_violations.append("%s: is not a JSON array of scan entries" % SOURCES_PATH)
		return
	var credited: Array[String] = []
	var entries: Array = parsed
	for i in entries.size():
		if not entries[i] is Dictionary:
			_violations.append("%s: entry %d is not an object" % [SOURCES_PATH, i])
			continue
		var entry: Dictionary = entries[i]
		var which := "%s: entry %d ('%s')" % [SOURCES_PATH, i, str(entry.get("id", ""))]
		for field in SCAN_FIELDS:
			if str(entry.get(field, "")).strip_edges().is_empty():
				_violations.append("%s is missing '%s'" % [which, field])
		var year: Variant = entry.get("year")
		var is_number := year is float or year is int
		if year != null and (not is_number or int(year) >= PUBLIC_DOMAIN_BEFORE):
			_violations.append("%s year %s is not a number before %d (jam rule: public domain only)" % [which, str(int(year)) if is_number else str(year), PUBLIC_DOMAIN_BEFORE])
		var url := str(entry.get("source_url", ""))
		if not url.is_empty() and not url.begins_with("https://"):
			_violations.append("%s source_url '%s' is not https" % [which, url])
		var sha := str(entry.get("sha256", ""))
		if not sha.is_empty() and _sha256.search(sha) == null:
			_violations.append("%s sha256 is not 64 lowercase hex digits" % which)
		var file := str(entry.get("file", ""))
		if not file.is_empty():
			credited.append(file)
			if not FileAccess.file_exists(SCANS_DIR + file):
				_violations.append("%s file '%s' does not exist in %s" % [which, file, SCANS_DIR])
	for scan in scans:
		if scan not in credited:
			_violations.append("%s%s: scan has no entry in %s" % [SCANS_DIR, scan, SOURCES_PATH])


## Instantiates the scene in the base-size window, lets containers and anchors settle,
## then measures every interactive Control.
func _check_scene(path: String) -> void:
	var packed := load(path) as PackedScene
	if packed == null:
		_violations.append("%s: failed to load scene" % path)
		return
	var scene_root := packed.instantiate()
	if scene_root == null:
		_violations.append("%s: failed to instantiate scene" % path)
		return
	root.add_child(scene_root)
	await process_frame
	await process_frame
	var root_control := scene_root as Control
	var full_screen := root_control == null or root_control.get_global_rect().size.is_equal_approx(root.get_visible_rect().size)
	_check_node(path, scene_root, full_screen)
	scene_root.queue_free()
	await process_frame


func _check_node(path: String, node: Node, full_screen: bool) -> void:
	var button := node as Button
	if button != null and not button.text.strip_edges().is_empty():
		_violations.append("%s: Button '%s' shows text '%s' (No Text: use an icon and an accessibility_name)" % [path, _scene_path_of(button), button.text])
	var control := node as Control
	if control != null and _is_interactive(control):
		var rect := control.get_global_rect()
		var which := "%s: interactive Control '%s'" % [path, _scene_path_of(control)]
		if rect.size.x < MIN_TARGET or rect.size.y < MIN_TARGET:
			_violations.append("%s is %s, smaller than %dx%d" % [which, rect.size, int(MIN_TARGET), int(MIN_TARGET)])
		if full_screen and not Rect2(Vector2.ZERO, Vector2(BASE_SIZE)).grow(SCREEN_TOLERANCE).encloses(rect):
			_violations.append("%s at %s leaves the %dx%d screen (every interactive Control lies inside the safe area)" % [which, rect, BASE_SIZE.x, BASE_SIZE.y])
		if control is BaseButton and control.focus_mode == Control.FOCUS_NONE:
			_violations.append("%s cannot take keyboard focus (focus_mode none)" % which)
		var icon_only := control is TextureButton or (control is Button and (control as Button).text.strip_edges().is_empty())
		if icon_only and control.accessibility_name.strip_edges().is_empty():
			_violations.append("%s has no text and no accessibility_name" % which)
	for child in node.get_children():
		_check_node(path, child, full_screen)


## Built-in input Controls, and scripted Controls that handle _gui_input and receive
## touches (mouse_filter STOP or PASS; PASS still delivers _gui_input).
func _is_interactive(control: Control) -> bool:
	# Range covers Slider and ScrollBar; the progress bars only display a value.
	var takes_input_range := control is Range and not (control is ProgressBar or control is TextureProgressBar)
	if takes_input_range or control is BaseButton or control is ScrollContainer or control is ColorPicker or control is GraphEdit:
		return true
	var script := control.get_script() as Script
	if control.mouse_filter == Control.MOUSE_FILTER_IGNORE or script == null:
		return false
	return script.get_script_method_list().any(func(method: Dictionary) -> bool: return method["name"] == "_gui_input")


func _scene_path_of(node: Node) -> String:
	var owner_node := node.owner if node.owner != null else node
	return str(owner_node.get_path_to(node))


func _collect_files(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		_violations.append("%s: cannot open directory (error %d)" % [dir_path, DirAccess.get_open_error()])
		return
	for file in dir.get_files():
		out.append(dir_path.path_join(file))
	for sub in dir.get_directories():
		# A .gdignore keeps a directory out of the project, as in Godot's import.
		if not sub.begins_with(".") and not FileAccess.file_exists(dir_path.path_join(sub).path_join(".gdignore")):
			_collect_files(dir_path.path_join(sub), out)

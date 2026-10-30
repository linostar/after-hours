extends Control
## Violation: draws text, sets a tooltip and a placeholder, and opens a native alert.


func _ready() -> void:
	tooltip_text = "Hide here"
	OS.alert("Caught!")


func _draw() -> void:
	draw_string(get_theme_default_font(), Vector2(10, 10), "Score")
	draw_char(get_theme_default_font(), Vector2(10, 30), "7")


func hint(line: LineEdit) -> void:
	line.placeholder_text = "Name"

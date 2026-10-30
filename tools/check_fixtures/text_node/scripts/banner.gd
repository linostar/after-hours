extends Node
## Violation: creates a text node and a text style in code, and asks for a font.


func make_banner() -> Node:
	var banner := Label.new()
	banner.label_settings = LabelSettings.new()
	return banner


func default_font() -> Font:
	return ThemeDB.fallback_font

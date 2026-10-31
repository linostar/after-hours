class_name Paintings
extends RefCounted
## The six masterpieces by id: each one's public-domain scan (art/scans, credited in
## SOURCES.json) and its style shader (shaders/style_<id>.gdshader), which brings the scan
## alive on the wall and, read from the screen, paints the room in its style.

## Ids in wing order; scenes pick one with @export_enum over these names.
const IDS: Array[StringName] = [&"pearl_earring", &"great_wave", &"grande_jatte", &"starry_night", &"earthly_delights", &"mona_lisa"]

const SCANS: Dictionary[StringName, Texture2D] = {
	&"pearl_earring": preload("res://art/scans/pearl_earring.webp"),
	&"great_wave": preload("res://art/scans/great_wave.webp"),
	&"grande_jatte": preload("res://art/scans/grande_jatte.webp"),
	&"starry_night": preload("res://art/scans/starry_night.webp"),
	&"earthly_delights": preload("res://art/scans/earthly_delights.webp"),
	&"mona_lisa": preload("res://art/scans/mona_lisa.webp"),
}

const STYLES: Dictionary[StringName, Shader] = {
	&"pearl_earring": preload("res://shaders/style_pearl_earring.gdshader"),
	&"great_wave": preload("res://shaders/style_great_wave.gdshader"),
	&"grande_jatte": preload("res://shaders/style_grande_jatte.gdshader"),
	&"starry_night": preload("res://shaders/style_starry_night.gdshader"),
	&"earthly_delights": preload("res://shaders/style_earthly_delights.gdshader"),
	&"mona_lisa": preload("res://shaders/style_mona_lisa.gdshader"),
}


## A new material drawing `id`'s style: over the node's own texture, or with `on_screen`
## over the screen behind it (for a full-screen rect). Null for an unknown id (callers
## report it).
static func style(id: StringName, on_screen := false) -> ShaderMaterial:
	if not STYLES.has(id):
		return null
	var material := ShaderMaterial.new()
	material.shader = STYLES[id]
	material.set_shader_parameter(&"use_screen", on_screen)
	return material

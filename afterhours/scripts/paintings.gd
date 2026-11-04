class_name Paintings
extends RefCounted
## The six masterpieces by id: each one's public-domain scan (art/scans, credited in
## SOURCES.json) and its style shader (shaders/style_<id>.gdshader), which brings the scan
## alive on the wall and, read from the screen, paints the room in its style. The decoys
## (DECOYS: hung as tilt frames and hiding portraits, never a wing's masterpiece) have their
## scans too and borrow the nearest masterpiece's style.

## Ids in wing order; scenes pick one with @export_enum over these names.
const IDS: Array[StringName] = [&"pearl_earring", &"great_wave", &"grande_jatte", &"starry_night", &"earthly_delights", &"mona_lisa"]
const DECOYS: Array[StringName] = [&"madame_x", &"van_gogh_self", &"castiglione", &"fighting_temeraire", &"impression_sunrise"]
## Every painting a frame can hold: the masterpieces, then the decoys (the order of
## SOURCES.json and of the scenes' @export_enum).
const ALL: Array[StringName] = [&"pearl_earring", &"great_wave", &"grande_jatte", &"starry_night", &"earthly_delights", &"mona_lisa", &"madame_x", &"van_gogh_self", &"castiglione", &"fighting_temeraire", &"impression_sunrise"]

const SCANS: Dictionary[StringName, Texture2D] = {
	&"pearl_earring": preload("res://art/scans/pearl_earring.webp"),
	&"great_wave": preload("res://art/scans/great_wave.webp"),
	&"grande_jatte": preload("res://art/scans/grande_jatte.webp"),
	&"starry_night": preload("res://art/scans/starry_night.webp"),
	&"earthly_delights": preload("res://art/scans/earthly_delights.webp"),
	&"mona_lisa": preload("res://art/scans/mona_lisa.webp"),
	&"madame_x": preload("res://art/scans/madame_x.webp"),
	&"van_gogh_self": preload("res://art/scans/van_gogh_self.webp"),
	&"castiglione": preload("res://art/scans/castiglione.webp"),
	&"fighting_temeraire": preload("res://art/scans/fighting_temeraire.webp"),
	&"impression_sunrise": preload("res://art/scans/impression_sunrise.webp"),
}

const STYLES: Dictionary[StringName, Shader] = {
	&"pearl_earring": preload("res://shaders/style_pearl_earring.gdshader"),
	&"great_wave": preload("res://shaders/style_great_wave.gdshader"),
	&"grande_jatte": preload("res://shaders/style_grande_jatte.gdshader"),
	&"starry_night": preload("res://shaders/style_starry_night.gdshader"),
	&"earthly_delights": preload("res://shaders/style_earthly_delights.gdshader"),
	&"mona_lisa": preload("res://shaders/style_mona_lisa.gdshader"),
	# The decoys in the nearest masterpiece's style: Sargent's and Turner's glowing light as
	# Vermeer's, Van Gogh's own swirl, Raphael's soft modelling as Leonardo's sfumato, Monet's
	# broken touch as Seurat's dots.
	&"madame_x": preload("res://shaders/style_pearl_earring.gdshader"),
	&"van_gogh_self": preload("res://shaders/style_starry_night.gdshader"),
	&"castiglione": preload("res://shaders/style_mona_lisa.gdshader"),
	&"fighting_temeraire": preload("res://shaders/style_pearl_earring.gdshader"),
	&"impression_sunrise": preload("res://shaders/style_grande_jatte.gdshader"),
}
## Each wing's hidden sketch: a red chalk study of its masterpiece, drawn by Claude (no scan,
## no credit needed).
const SKETCHES: Dictionary[StringName, Texture2D] = {
	&"pearl_earring": preload("res://art/svg/sketch_pearl_earring.svg"),
	&"great_wave": preload("res://art/svg/sketch_great_wave.svg"),
	&"grande_jatte": preload("res://art/svg/sketch_grande_jatte.svg"),
	&"starry_night": preload("res://art/svg/sketch_starry_night.svg"),
	&"earthly_delights": preload("res://art/svg/sketch_earthly_delights.svg"),
	&"mona_lisa": preload("res://art/svg/sketch_mona_lisa.svg"),
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

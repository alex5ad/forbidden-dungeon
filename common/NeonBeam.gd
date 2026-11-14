@tool
class_name NeonBeam
extends ColorRect
## Fascicul vertical neon (Tomb of the Mask). Pune-l în scenă și setează size/culoarea.

const SHADER := preload("res://shaders/neon_beam.gdshader")

@export var beam_color := Color("#ff00ff"):
	set(v):
		beam_color = v
		_sync()
@export var intensity := 1.4:
	set(v):
		intensity = v
		_sync()
@export_range(0.0, 1.0) var core_width := 0.18:
	set(v):
		core_width = v
		_sync()
@export_range(0.0, 1.0) var bottom_fade := 0.0:
	set(v):
		bottom_fade = v
		_sync()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not material is ShaderMaterial:
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		material = mat
	_sync()


func _sync() -> void:
	var mat := material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("beam_color", beam_color)
	mat.set_shader_parameter("intensity", intensity)
	mat.set_shader_parameter("core_width", core_width)
	mat.set_shader_parameter("bottom_fade", bottom_fade)

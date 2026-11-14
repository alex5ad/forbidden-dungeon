@tool
class_name CheckerFloor
extends ColorRect
## Podea în tablă de șah albastră (FNaF 4). Un singur quad + shader -> ieftin pe Web.

const SHADER := preload("res://shaders/checkerboard.gdshader")

@export var tile_size := 32.0:
	set(v):
		tile_size = v
		_sync()
@export var color_a := Color("#0e1b33"):
	set(v):
		color_a = v
		_sync()
@export var color_b := Color("#152647"):
	set(v):
		color_b = v
		_sync()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not material is ShaderMaterial:
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		material = mat
	resized.connect(_sync)
	_sync()


func _sync() -> void:
	var mat := material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("rect_size", size)
	mat.set_shader_parameter("tile_size", tile_size)
	mat.set_shader_parameter("color_a", color_a)
	mat.set_shader_parameter("color_b", color_b)

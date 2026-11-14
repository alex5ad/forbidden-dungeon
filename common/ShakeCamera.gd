class_name ShakeCamera
extends Camera2D
## Cameră cu screen shake. GameState.shake(px) o găsește prin get_viewport().get_camera_2d().

@export var decay := 32.0   # pixeli de shake pierduți pe secundă

var _strength := 0.0


func shake(amount: float) -> void:
	_strength = maxf(_strength, amount)


func _process(delta: float) -> void:
	if _strength <= 0.0:
		offset = Vector2.ZERO
		return
	_strength = maxf(_strength - decay * delta, 0.0)
	offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _strength

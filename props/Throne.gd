class_name Throne
extends Node2D
## Tronul Regal (desenat). Originea = mijlocul șezutului.

var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var gold := GameState.COL_GOLD
	var purple := Color("#3b0d4a")
	var pulse := 0.5 + 0.5 * sin(_t * 2.0)
	draw_circle(Vector2(0, -60), 110.0, Color(GameState.COL_MAGENTA, 0.06 + 0.04 * pulse))
	# spătar
	var back := Rect2(-44, -130, 88, 120)
	draw_rect(back, purple)
	draw_rect(back.grow(-10.0), Color("#5a1670"))
	draw_rect(back, gold, false, 4.0)
	# creasta (coroană) de sus
	var t := back.position.y
	draw_colored_polygon(PackedVector2Array([
		Vector2(-44, t), Vector2(-34, t - 26), Vector2(-18, t - 8), Vector2(0, t - 36),
		Vector2(18, t - 8), Vector2(34, t - 26), Vector2(44, t)]), gold)
	draw_circle(Vector2(0, t - 38), 5.0, GameState.COL_RED)
	# șezut + brațe + picioare
	draw_rect(Rect2(-54, -14, 108, 24), gold)
	draw_rect(Rect2(-50, -10, 100, 14), Color("#b8000f"))
	draw_rect(Rect2(-62, -46, 14, 52), purple)
	draw_rect(Rect2(-62, -46, 14, 52), gold, false, 3.0)
	draw_rect(Rect2(48, -46, 14, 52), purple)
	draw_rect(Rect2(48, -46, 14, 52), gold, false, 3.0)
	draw_rect(Rect2(-50, 10, 10, 22), gold)
	draw_rect(Rect2(40, 10, 10, 22), gold)

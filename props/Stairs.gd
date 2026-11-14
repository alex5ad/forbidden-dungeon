class_name Stairs
extends Node2D
## Scările spre etajele superioare (+1, +2). Originea = treapta de jos.

@export var steps := 7
@export var step_size := Vector2(30, 22)
@export var caption := "SUS  +1 / +2"


func _draw() -> void:
	var gold := GameState.COL_GOLD
	for i in steps:
		var r := Rect2(Vector2(i * step_size.x * 0.5, -i * step_size.y), Vector2(step_size.x * 3.0, step_size.y))
		draw_rect(r, Color("#1c1030").lightened(i * 0.03))
		draw_rect(r, Color(gold, 0.85), false, 2.0)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(0, -steps * step_size.y - 14.0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, gold)

class_name GateDoor
extends Node2D
## Un canat al porții castelului. Originea = balamaua (jos). Se deschide cu tween pe scale.x.

@export var width := 64.0
@export var height := 132.0
@export var hinge_left := true
@export_range(0.0, 1.0) var highlight := 0.0:
	set(v):
		highlight = v
		queue_redraw()


func _draw() -> void:
	var r := Rect2(0, -height, width, height) if hinge_left else Rect2(-width, -height, width, height)
	var gold := GameState.COL_GOLD
	draw_rect(r, Color("#24112b"))
	# scânduri
	var x := r.position.x + 12.0
	while x < r.end.x - 4.0:
		draw_line(Vector2(x, r.position.y + 4), Vector2(x, r.end.y - 4), Color(0, 0, 0, 0.45), 2.0)
		x += 12.0
	# benzi metalice + ținte aurii
	for yy in [r.position.y + 26.0, r.end.y - 30.0]:
		var y: float = yy
		draw_rect(Rect2(r.position.x, y - 4.0, r.size.x, 8.0), Color("#4a3a52"))
		var sx := r.position.x + 8.0
		while sx < r.end.x - 4.0:
			draw_rect(Rect2(sx - 2.0, y - 2.0, 4.0, 4.0), gold)
			sx += 14.0
	# inel
	var ring_x := r.end.x - 14.0 if hinge_left else r.position.x + 14.0
	draw_arc(Vector2(ring_x, r.position.y + height * 0.55), 6.0, 0.0, TAU, 12, gold, 2.0)
	# contur neon
	draw_rect(r, gold, false, 2.0)
	if highlight > 0.0:
		draw_rect(r.grow(4.0), Color(gold, 0.5 * highlight), false, 6.0)

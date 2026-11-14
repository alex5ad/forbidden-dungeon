class_name NeonWall
extends StaticBody2D
## Zid StaticBody2D pe layer-ul de pereți (layer 3), desenat ca bloc neon magenta.
## Proiectilele reflectate ricoșează din el (Projectile.gd face raycast pe LAYER_WALLS).

@export var size := Vector2(32, 32)
@export var neon_color := Color("#ff00ff")
@export var fill_color := Color("#140a22")


static func create(rect: Rect2) -> NeonWall:
	var w := NeonWall.new()
	w.position = rect.get_center()
	w.size = rect.size
	return w


func _ready() -> void:
	collision_layer = GameState.LAYER_WALLS
	collision_mask = 0
	var shape := RectangleShape2D.new()
	shape.size = size
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)
	queue_redraw()


func _draw() -> void:
	var r := Rect2(-size * 0.5, size)
	draw_rect(r, fill_color)
	# strălucire exterioară + linie neon + punct auriu în colțuri (Tomb of the Mask)
	draw_rect(r.grow(3.0), Color(neon_color, 0.18), false, 6.0)
	draw_rect(r, neon_color, false, 2.0)
	draw_rect(r.grow(-5.0), Color(neon_color, 0.25), false, 1.0)
	var dot := Vector2(2, 2)
	for c: Vector2 in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		draw_rect(Rect2(c - dot, dot * 2.0), GameState.COL_GOLD)

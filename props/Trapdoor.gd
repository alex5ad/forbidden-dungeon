class_name Trapdoor
extends Area2D
## Trapă / Puț Abisal auriu. Se deschide animat; când e activă și jucătorul calcă pe ea -> `entered`.

signal entered

@export var size := Vector2(72, 72)
@export var caption := ""

var open_amount := 0.0:
	set(v):
		open_amount = v
		queue_redraw()
var active := false
var _t := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = GameState.LAYER_PLAYER
	monitorable = false
	var shape := RectangleShape2D.new()
	shape.size = size * 0.6
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)


func open_door(duration: float = 0.7) -> Tween:
	visible = true
	GameState.play_sfx("magic", false, -10.0)
	var t := create_tween()
	t.tween_property(self, "open_amount", 1.0, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_callback(func(): active = true)
	return t


func _physics_process(_delta: float) -> void:
	# get_overlapping_bodies() prinde și jucătorul care stătea deja pe trapă.
	if not active:
		return
	for body in get_overlapping_bodies():
		if body is Player:
			active = false
			entered.emit()
			return


func _process(delta: float) -> void:
	_t += delta
	if open_amount > 0.0:
		queue_redraw()


func _draw() -> void:
	var r := Rect2(-size * 0.5, size)
	var pulse := 0.6 + 0.4 * sin(_t * 5.0)
	# strălucire aurie
	draw_rect(r.grow(8.0), Color(GameState.COL_GOLD, 0.12 * pulse * maxf(open_amount, 0.3)), false, 10.0)
	# gaura (abisul) cu strălucire magenta
	draw_rect(r, Color(0, 0, 0))
	draw_rect(r.grow(-8.0), Color(GameState.COL_MAGENTA, 0.35 * open_amount * pulse))
	draw_rect(r.grow(-20.0), Color(1.0, 0.6, 1.0, 0.35 * open_amount * pulse))
	# cele două uși glisante
	var half := size.x * 0.5 * (1.0 - open_amount)
	if half > 0.5:
		var wood := Color("#3a2414")
		var left := Rect2(r.position, Vector2(half, size.y))
		var right := Rect2(Vector2(r.end.x - half, r.position.y), Vector2(half, size.y))
		for door in [left, right]:
			var d: Rect2 = door
			draw_rect(d, wood)
			draw_rect(d, Color(GameState.COL_GOLD, 0.7), false, 2.0)
			draw_line(d.position + Vector2(0, d.size.y * 0.33), Vector2(d.end.x, d.position.y + d.size.y * 0.33), Color(0, 0, 0, 0.5), 2.0)
			draw_line(d.position + Vector2(0, d.size.y * 0.66), Vector2(d.end.x, d.position.y + d.size.y * 0.66), Color(0, 0, 0, 0.5), 2.0)
	# rama
	draw_rect(r, GameState.COL_GOLD, false, 3.0)
	if caption != "" and open_amount > 0.9:
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(-120, r.position.y - 14.0), caption, HORIZONTAL_ALIGNMENT_CENTER, 240, 16,
				Color(GameState.COL_GOLD, pulse))

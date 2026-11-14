class_name MagicMirror
extends Node2D
## Oglinda Blestemată de la Parter. Originea = baza oglinzii (centru jos).

const W := 150.0
const H := 210.0

@export var cracked := true:
	set(v):
		cracked = v
		queue_redraw()
@export_range(0.0, 1.0) var glow := 0.0:
	set(v):
		glow = v
		queue_redraw()

var _t := 0.0
var _cracks: Array[PackedVector2Array] = []


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var impact := Vector2(22, -H * 0.62)
	for i in 7:
		var pts := PackedVector2Array([impact])
		var ang := TAU * i / 7.0 + rng.randf_range(-0.3, 0.3)
		var p := impact
		for s in 4:
			p += Vector2.RIGHT.rotated(ang + rng.randf_range(-0.5, 0.5)) * rng.randf_range(14.0, 26.0)
			p = p.clamp(Vector2(-W * 0.5, -H), Vector2(W * 0.5, 0))
			pts.append(p)
		_cracks.append(pts)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var glass := Rect2(-W * 0.5, -H, W, H)
	var frame := glass.grow(16.0)
	var gold := GameState.COL_GOLD
	# aură magenta în spate
	draw_rect(frame.grow(10.0), Color(GameState.COL_MAGENTA, 0.10 + 0.05 * sin(_t * 2.0)), false, 14.0)
	# rama
	draw_rect(frame, Color("#2a1c05"))
	draw_rect(frame, gold, false, 4.0)
	draw_rect(glass.grow(5.0), Color(gold, 0.6), false, 2.0)
	# ornament (mică coroană) deasupra
	var top := frame.position.y
	draw_colored_polygon(PackedVector2Array([
		Vector2(-30, top), Vector2(-22, top - 22), Vector2(-10, top - 8), Vector2(0, top - 28),
		Vector2(10, top - 8), Vector2(22, top - 22), Vector2(30, top)]), gold)
	draw_circle(Vector2(0, top - 30), 4.0, GameState.COL_MAGENTA)
	# sticla + reflexie care se plimbă
	draw_rect(glass, Color("#0b1430"))
	var band_x := fmod(_t * 50.0, W * 2.0) - W * 0.5
	var col_w := 6.0
	var x := glass.position.x
	while x < glass.end.x:
		var a := exp(-pow((x - glass.position.x - band_x) / 26.0, 2.0)) * 0.18
		if a > 0.01:
			draw_rect(Rect2(x, glass.position.y, col_w, H), Color(0.7, 0.9, 1.0, a))
		x += col_w
	draw_rect(Rect2(glass.position, Vector2(W, 6)), Color(1, 1, 1, 0.08))
	# crăpături
	if cracked:
		for pts in _cracks:
			draw_polyline(pts, Color(0.85, 0.9, 1.0, 0.55), 1.5)
	# strălucire orbitoare
	if glow > 0.0:
		draw_rect(glass, Color(1, 1, 1, glow))
		for i in 3:
			draw_rect(frame.grow(8.0 + i * 12.0), Color(1.0, 0.85, 1.0, glow * (0.5 - i * 0.15)), false, 8.0)

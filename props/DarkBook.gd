class_name DarkBook
extends Node2D
## Cartea Întunericului, în prim-plan la final.
## open_amount 1 = deschisă, 0 = trântită; lock_amount = lanțurile + lacătul;
## vortex = vârtejul de lumină care absoarbe întunericul; title_label = titlul auriu de pe copertă.

const W := 200.0
const H := 260.0

@export_range(0.0, 1.0) var open_amount := 1.0
@export_range(0.0, 1.0) var lock_amount := 0.0
@export_range(0.0, 1.0) var vortex := 0.0

var title_label: Label
var _t := 0.0


func _ready() -> void:
	title_label = Label.new()
	title_label.text = "FORBIDDEN\nREDEMPTION"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 30)
	title_label.add_theme_color_override("font_color", GameState.COL_GOLD)
	title_label.add_theme_color_override("font_outline_color", Color("#3a2400"))
	title_label.add_theme_constant_override("outline_size", 8)
	title_label.size = Vector2(W, 100)
	title_label.position = Vector2(-W * 0.5, -H * 0.5 + 24.0)
	title_label.visible_ratio = 0.0
	add_child(title_label)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var gold := GameState.COL_GOLD
	# --- vârtejul de lumină ---
	if vortex > 0.0:
		for i in 18:
			var ang := TAU * i / 18.0 + _t * 1.8
			var dir := Vector2.RIGHT.rotated(ang)
			var dir2 := Vector2.RIGHT.rotated(ang + 0.5)
			draw_line(dir * 40.0, dir2 * 900.0 * vortex, Color(1.0, 0.9, 1.0, 0.07 * vortex), 26.0)
		for i in 4:
			var rr := fmod(_t * 220.0 + i * 120.0, 480.0)
			draw_arc(Vector2.ZERO, 480.0 - rr, 0.0, TAU, 48, Color(GameState.COL_MAGENTA, 0.35 * vortex * (rr / 480.0)), 3.0)
	var half_w := lerpf(W * 0.5, W, open_amount)
	# --- pagini (când e deschisă) ---
	if open_amount > 0.05:
		var cover := Color("#1a0b24")
		draw_rect(Rect2(-half_w - 8.0, -H * 0.5 - 8.0, half_w * 2.0 + 16.0, H + 16.0), cover)
		var page := Color("#d9cba6").darkened(0.15)
		draw_rect(Rect2(-half_w, -H * 0.5, half_w - 4.0, H), page)
		draw_rect(Rect2(4.0, -H * 0.5, half_w - 4.0, H), page)
		# rânduri de text „interzis”
		var y := -H * 0.5 + 24.0
		while y < H * 0.5 - 20.0:
			draw_line(Vector2(-half_w + 18.0, y), Vector2(-22.0, y), Color(0.25, 0.05, 0.3, 0.6), 2.0)
			draw_line(Vector2(22.0, y), Vector2(half_w - 18.0, y), Color(0.25, 0.05, 0.3, 0.6), 2.0)
			y += 16.0
		draw_line(Vector2(0, -H * 0.5), Vector2(0, H * 0.5), Color(0, 0, 0, 0.7), 4.0)
		draw_circle(Vector2(0, 0), 26.0 + 6.0 * sin(_t * 5.0), Color(GameState.COL_MAGENTA, 0.35 * open_amount))
	# --- coperta (apare pe măsură ce se închide) ---
	var cover_a := clampf(1.0 - open_amount / 0.2, 0.0, 1.0)
	if cover_a > 0.0:
		var r := Rect2(-half_w, -H * 0.5, half_w * 2.0, H)
		draw_rect(r, Color(0.1, 0.04, 0.14, cover_a))
		draw_rect(r, Color(gold, cover_a), false, 4.0)
		draw_rect(r.grow(-10.0), Color(gold, 0.6 * cover_a), false, 2.0)
		# ochi/emblemă
		draw_circle(Vector2(0, 20), 18.0, Color(GameState.COL_MAGENTA, 0.6 * cover_a))
		draw_circle(Vector2(0, 20), 7.0, Color(0, 0, 0, cover_a))
	title_label.modulate.a = cover_a
	# --- lanțuri + lacăt ---
	if lock_amount > 0.0:
		var span := half_w + 18.0
		for cy in [44.0, 86.0]:
			var chain_y: float = cy
			var x := -span
			var end_x := lerpf(-span, span, lock_amount)
			var i := 0
			while x < end_x:
				if i % 2 == 0:
					draw_rect(Rect2(x, chain_y - 4.0, 14.0, 8.0), Color("#c9a400"), false, 2.0)
				else:
					draw_rect(Rect2(x, chain_y - 2.0, 14.0, 4.0), Color("#c9a400"))
				x += 12.0
				i += 1
		if lock_amount > 0.95:
			var lock_pos := Vector2(0, 66)
			draw_arc(lock_pos + Vector2(0, -12), 12.0, PI, TAU, 16, gold, 4.0)
			draw_rect(Rect2(lock_pos + Vector2(-16, -12), Vector2(32, 26)), gold)
			draw_circle(lock_pos, 4.0, Color.BLACK)

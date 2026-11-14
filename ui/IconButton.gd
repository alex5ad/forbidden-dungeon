class_name IconButton
extends Button
## Buton cu iconiță desenată pixel-art (fără font de simboluri): play, pause, home, shop, coin, tips.

@export_enum("none", "play", "pause", "home", "shop", "tips", "new", "levels") var icon_kind := "none":
	set(v):
		icon_kind = v
		queue_redraw()
@export var icon_color := Color("#ffe600")

const ICON_SIZE := 18.0


static func make(text_value: String, kind: String, accent: Color = GameState.COL_MAGENTA, font_size: int = 20) -> IconButton:
	var b := IconButton.new()
	b.text = text_value
	b.icon_kind = kind
	UiKit.style_button(b, accent, font_size)
	if kind != "none":
		# loc pentru iconiță în stânga textului
		for state in ["normal", "hover", "focus", "pressed", "disabled"]:
			var sb := b.get_theme_stylebox(state) as StyleBoxFlat
			if sb:
				sb.content_margin_left = 16.0 + ICON_SIZE + 10.0
	return b


func _draw() -> void:
	if icon_kind == "none":
		return
	var col := icon_color if not disabled else Color(0.45, 0.4, 0.5)
	var h := ICON_SIZE
	var o := Vector2(14.0, (size.y - h) * 0.5)
	match icon_kind:
		"play":
			draw_colored_polygon(PackedVector2Array([o + Vector2(2, 0), o + Vector2(h, h * 0.5), o + Vector2(2, h)]), col)
		"pause":
			draw_rect(Rect2(o + Vector2(2, 0), Vector2(5, h)), col)
			draw_rect(Rect2(o + Vector2(h - 7, 0), Vector2(5, h)), col)
		"home":
			draw_colored_polygon(PackedVector2Array([o + Vector2(0, h * 0.5), o + Vector2(h * 0.5, 0), o + Vector2(h, h * 0.5)]), col)
			draw_rect(Rect2(o + Vector2(3, h * 0.5), Vector2(h - 6, h * 0.5)), col)
			draw_rect(Rect2(o + Vector2(h * 0.5 - 2, h * 0.68), Vector2(4, h * 0.32)), Color(0, 0, 0, 0.8))
		"shop":
			draw_circle(o + Vector2(h * 0.5, h * 0.5), h * 0.5, col)
			draw_circle(o + Vector2(h * 0.5, h * 0.5), h * 0.3, Color(0, 0, 0, 0.35))
			draw_rect(Rect2(o + Vector2(h * 0.5 - 1.5, h * 0.25), Vector2(3, h * 0.5)), col)
		"tips":
			draw_circle(o + Vector2(h * 0.5, h * 0.45), h * 0.45, col)
			draw_rect(Rect2(o + Vector2(h * 0.5 - 1.5, h * 0.2), Vector2(3, h * 0.35)), Color(0, 0, 0, 0.7))
			draw_rect(Rect2(o + Vector2(h * 0.5 - 1.5, h * 0.62), Vector2(3, 3)), Color(0, 0, 0, 0.7))
		"new":
			draw_rect(Rect2(o + Vector2(h * 0.5 - 2, 0), Vector2(4, h)), col)
			draw_rect(Rect2(o + Vector2(0, h * 0.5 - 2), Vector2(h, 4)), col)
		"levels":
			for gy in 3:
				for gx in 3:
					draw_rect(Rect2(o + Vector2(gx * 6.5, gy * 6.5), Vector2(5, 5)), col)

class_name UiKit
extends RefCounted
## Stiluri comune pentru UI (butoane neon, panouri, etichete) – folosite de MainMenu, magazin, pauză.


static func style_button(btn: Button, accent: Color = GameState.COL_MAGENTA, font_size: int = 20) -> void:
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", GameState.COL_TEXT)
	btn.add_theme_color_override("font_hover_color", GameState.COL_GOLD)
	btn.add_theme_color_override("font_focus_color", GameState.COL_GOLD)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", Color(0.5, 0.45, 0.6))
	btn.add_theme_stylebox_override("normal", _box(Color(0.05, 0.02, 0.09, 0.92), Color(accent, 0.75), 2))
	btn.add_theme_stylebox_override("hover", _box(Color(0.12, 0.03, 0.16, 0.95), GameState.COL_GOLD, 3))
	btn.add_theme_stylebox_override("focus", _box(Color(0, 0, 0, 0), GameState.COL_GOLD, 2))
	btn.add_theme_stylebox_override("pressed", _box(Color(0.25, 0.05, 0.3, 0.95), Color.WHITE, 3))
	btn.add_theme_stylebox_override("disabled", _box(Color(0.04, 0.03, 0.06, 0.8), Color(0.3, 0.25, 0.35), 2))


static func panel_style(border: Color = GameState.COL_MAGENTA, bg_alpha: float = 0.95) -> StyleBoxFlat:
	var sb := _box(Color(0.02, 0.01, 0.05, bg_alpha), border, 3)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	sb.shadow_color = Color(border, 0.25)
	sb.shadow_size = 12
	return sb


static func label(text: String, font_size: int, color: Color, outline: int = 5) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func _box(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

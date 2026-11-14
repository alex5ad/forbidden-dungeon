class_name HUD
extends CanvasLayer
## HUD-ul arenei: inimi, etaj/zonă, statistici parry, bara boss-ului,
## bannere („CAMERĂ CURĂȚATĂ”), indiciu de zonă și panoul de Game Over.

signal retry_pressed

const HEART_FULL := preload("res://assets/sprites/0x72/ui_heart_full.png")
const HEART_EMPTY := preload("res://assets/sprites/0x72/ui_heart_empty.png")

var _hearts: Array[TextureRect] = []
var _floor_label: Label
var _zone_label: Label
var _stats_label: Label
var _boss_box: VBoxContainer
var _boss_name: Label
var _boss_bar: ProgressBar
var _banner: Label
var _hint: Label
var _game_over: PanelContainer
var _game_over_title: Label
var _game_over_tip: Label


func _ready() -> void:
	layer = 20
	_build()
	GameState.hp_changed.connect(_on_hp_changed)
	_on_hp_changed(GameState.player_hp, GameState.max_hp)


func _process(_delta: float) -> void:
	_stats_label.text = "PARRY %d   PERFECT %d   KILLS %d" % [
		GameState.parries, GameState.perfect_parries, GameState.kills]


func set_floor(floor_num: int) -> void:
	_floor_label.text = GameState.floor_short(floor_num)
	if floor_num < 0:
		var chapter := GameState.chapter_number(floor_num)
		if GameState.is_boss_floor(floor_num):
			_zone_label.text = "Chapter %d  ·  %s" % [chapter, GameState.floor_name(floor_num)]
		else:
			_zone_label.text = "Chapter %d  ·  %s  ·  floor %d/10" % [
				chapter, GameState.floor_name(floor_num), GameState.chapter_floor(floor_num)]
	else:
		_zone_label.text = GameState.floor_name(floor_num)


func show_boss_bar(boss_name: String, max_hp: int) -> void:
	_boss_box.visible = true
	_boss_name.text = boss_name
	_boss_bar.max_value = max_hp
	_boss_bar.value = max_hp


func update_boss_bar(hp: int, _max_hp: int) -> void:
	var t := create_tween()
	t.tween_property(_boss_bar, "value", float(hp), 0.15)
	if hp <= 0:
		t.tween_interval(0.4)
		t.tween_property(_boss_box, "modulate:a", 0.0, 0.5)


func show_banner(text: String, color: Color = GameState.COL_GOLD, hold: float = 1.4) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner.modulate.a = 0.0
	_banner.scale = Vector2(1.4, 1.4)
	var t := create_tween()
	t.tween_property(_banner, "modulate:a", 1.0, 0.15)
	t.parallel().tween_property(_banner, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(hold)
	t.tween_property(_banner, "modulate:a", 0.0, 0.4)


func show_hint(text: String, duration: float = 7.0) -> void:
	_hint.text = text
	_hint.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(_hint, "modulate:a", 1.0, 0.3)
	t.tween_interval(duration)
	t.tween_property(_hint, "modulate:a", 0.0, 0.6)


func show_game_over(floor_num: int, tip: String = "") -> void:
	_game_over_title.text = "YOU FELL ON %s" % GameState.floor_short(floor_num)
	_game_over_tip.text = "The King's Tip: %s" % tip if tip != "" else ""
	_game_over_tip.visible = tip != ""
	_game_over.visible = true
	_game_over.modulate.a = 0.0
	create_tween().tween_property(_game_over, "modulate:a", 1.0, 0.3)


func _on_hp_changed(hp: int, max_hp: int) -> void:
	for i in _hearts.size():
		_hearts[i].visible = i < max_hp
		_hearts[i].texture = HEART_FULL if i < hp else HEART_EMPTY
	if hp > 0 and hp < max_hp and _hearts.size() > hp - 1:
		var h := _hearts[hp - 1]
		h.pivot_offset = h.size * 0.5
		var t := create_tween()
		t.tween_property(h, "scale", Vector2(1.4, 1.4), 0.08)
		t.tween_property(h, "scale", Vector2.ONE, 0.15)


# -----------------------------------------------------------------------------
func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Bara de sus
	var top := ColorRect.new()
	top.color = Color(0.02, 0.01, 0.05, 0.85)
	top.position = Vector2.ZERO
	top.size = Vector2(1152, 60)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	var line := ColorRect.new()
	line.color = GameState.COL_MAGENTA
	line.position = Vector2(0, 60)
	line.size = Vector2(1152, 2)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(line)

	var hearts := HBoxContainer.new()
	hearts.position = Vector2(20, 12)
	hearts.add_theme_constant_override("separation", 6)
	hearts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hearts)
	for i in 5:
		var tr := TextureRect.new()
		tr.texture = HEART_FULL
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(39, 36)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hearts.add_child(tr)
		_hearts.append(tr)

	_floor_label = _label(30, GameState.COL_GOLD)
	_floor_label.position = Vector2(376, 0)
	_floor_label.size = Vector2(400, 36)
	_floor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_floor_label)
	_zone_label = _label(16, Color(GameState.COL_MAGENTA, 0.95))
	_zone_label.position = Vector2(326, 34)
	_zone_label.size = Vector2(500, 24)
	_zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_zone_label)

	_stats_label = _label(14, Color(GameState.COL_TEXT, 0.8))
	_stats_label.position = Vector2(812, 20)
	_stats_label.size = Vector2(320, 24)
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_stats_label)

	# Bara boss-ului (jos)
	_boss_box = VBoxContainer.new()
	_boss_box.position = Vector2(226, 590)
	_boss_box.size = Vector2(700, 50)
	_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_box.visible = false
	root.add_child(_boss_box)
	_boss_name = _label(18, GameState.COL_MAGENTA)
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_box.add_child(_boss_name)
	_boss_bar = ProgressBar.new()
	_boss_bar.show_percentage = false
	_boss_bar.custom_minimum_size = Vector2(700, 16)
	_boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.02, 0.1, 0.9)
	bg.border_color = GameState.COL_MAGENTA
	bg.set_border_width_all(2)
	var fill := StyleBoxFlat.new()
	fill.bg_color = GameState.COL_MAGENTA
	_boss_bar.add_theme_stylebox_override("background", bg)
	_boss_bar.add_theme_stylebox_override("fill", fill)
	_boss_box.add_child(_boss_bar)

	# Banner central
	_banner = _label(54, GameState.COL_GOLD)
	_banner.position = Vector2(0, 210)
	_banner.size = Vector2(1152, 160)
	_banner.pivot_offset = Vector2(576, 80)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.add_theme_constant_override("outline_size", 10)
	_banner.modulate.a = 0.0
	root.add_child(_banner)

	# Indiciu de zonă (sub bara de sus)
	_hint = _label(17, GameState.COL_TEXT)
	_hint.position = Vector2(0, 68)
	_hint.size = Vector2(1152, 28)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.modulate.a = 0.0
	root.add_child(_hint)

	# Game Over
	_game_over = PanelContainer.new()
	_game_over.position = Vector2(326, 190)
	_game_over.size = Vector2(500, 260)
	_game_over.visible = false
	var gs := StyleBoxFlat.new()
	gs.bg_color = Color(0.03, 0.01, 0.06, 0.95)
	gs.border_color = GameState.COL_RED
	gs.set_border_width_all(3)
	gs.content_margin_left = 24
	gs.content_margin_right = 24
	gs.content_margin_top = 20
	gs.content_margin_bottom = 20
	_game_over.add_theme_stylebox_override("panel", gs)
	root.add_child(_game_over)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	_game_over.add_child(vb)
	_game_over_title = _label(28, GameState.COL_RED)
	_game_over_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_game_over_title)
	var sub := _label(16, GameState.COL_TEXT)
	sub.text = "The shadows laugh. But a Knight always rises."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)
	_game_over_tip = _label(15, Color("#7ff3ff"))
	_game_over_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_game_over_tip.custom_minimum_size = Vector2(440, 0)
	_game_over_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_game_over_tip)
	var btn := Button.new()
	btn.text = "BOUNCE BACK  (Retry floor)  [R]"
	btn.add_theme_font_size_override("font_size", 18)
	btn.custom_minimum_size = Vector2(0, 48)
	btn.pressed.connect(func(): retry_pressed.emit())
	vb.add_child(btn)


func _label(font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

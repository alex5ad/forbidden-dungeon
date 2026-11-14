class_name LevelSelect
extends PanelContainer
## Meniul LEVELS (de pe ecranul de acasă): rejoacă orice subsol deja atins.
## 5 capitole × 10 etaje; etajul 10 din fiecare capitol e boss-ul.
## Rejucarea nu schimbă tura salvată; aduce monede (jumătate dacă etajul era deja terminat).

signal closed

const BTN_SIZE := Vector2(66, 40)

var _buttons: Dictionary = {}   # adâncime (1..50) -> Button
var _info: Label
var _reached_label: Label


func _ready() -> void:
	position = Vector2(36, 30)
	size = Vector2(1080, 588)
	add_theme_stylebox_override("panel", UiKit.panel_style(GameState.COL_CYAN, 0.97))
	_build()
	visible = false


func open() -> void:
	_refresh()
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.15)
	var focus_depth := clampi(GameState.deepest_reached, 1, 50)
	var b: Button = _buttons.get(focus_depth)
	if b:
		b.grab_focus()


func close() -> void:
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		get_viewport().set_input_as_handled()
		close()


func _build() -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	var title := UiKit.label("LEVELS", 34, GameState.COL_CYAN, 8)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_reached_label = UiKit.label("", 18, GameState.COL_GOLD, 5)
	header.add_child(_reached_label)

	var sub := UiKit.label("Replay any floor you have reached. Your saved journey stays as it is.  "
			+ "First clear pays full coins, replays of cleared floors pay half.", 14, Color(GameState.COL_TEXT, 0.8), 3)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(sub)

	for ch in 5:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		root.add_child(row)
		var zone: Dictionary = GameState.ZONES[ch]
		var info := VBoxContainer.new()
		info.custom_minimum_size = Vector2(250, 0)
		info.add_theme_constant_override("separation", -2)
		info.add_child(UiKit.label("%d · %s" % [ch + 1, zone["name"]], 16, GameState.COL_TEXT, 3))
		info.add_child(UiKit.label("%s · %d coins/floor · boss %d" % [zone["enemies"],
				GameState.COINS_FLOOR * (ch + 1), GameState.COINS_BOSS * (ch + 1)], 12, Color(GameState.COL_TEXT, 0.55), 2))
		row.add_child(info)
		for i in 10:
			var depth := ch * 10 + i + 1
			var b := Button.new()
			b.custom_minimum_size = BTN_SIZE
			b.text = "BOSS" if i == 9 else "-%d" % depth
			b.pressed.connect(_on_floor_pressed.bind(depth))
			b.focus_entered.connect(_on_floor_hover.bind(depth))
			b.mouse_entered.connect(_on_floor_hover.bind(depth))
			row.add_child(b)
			_buttons[depth] = b

	_info = UiKit.label("", 15, GameState.COL_GOLD, 3)
	_info.custom_minimum_size = Vector2(0, 24)
	root.add_child(_info)

	var back := IconButton.make("BACK", "home", GameState.COL_MAGENTA, 18)
	back.custom_minimum_size = Vector2(180, 44)
	back.size_flags_horizontal = Control.SIZE_SHRINK_END
	back.pressed.connect(close)
	root.add_child(back)


func _refresh() -> void:
	_reached_label.text = "Deepest reached: %s" % GameState.floor_short(-GameState.deepest_reached)
	var journey := absi(GameState.resume_floor) if GameState.run_active and GameState.resume_floor < 0 else -1
	for depth: int in _buttons:
		var b: Button = _buttons[depth]
		var unlocked := GameState.is_unlocked(-depth)
		var cleared := GameState.is_cleared(-depth)
		var boss := depth % 10 == 0
		var accent := GameState.COL_MAGENTA if boss else (GameState.COL_GOLD if cleared else GameState.COL_CYAN)
		UiKit.style_button(b, accent, 14)
		b.disabled = not unlocked
		if not unlocked:
			b.text = "· · ·"
		else:
			# „»” marchează etajul de unde continuă tura salvată
			b.text = ("»" if depth == journey else "") + ("BOSS" if boss else "-%d" % depth)
			if cleared:
				b.add_theme_color_override("font_color", GameState.COL_GOLD)


func _on_floor_hover(depth: int) -> void:
	var f := -depth
	if not GameState.is_unlocked(f):
		_info.text = "%s is locked. Reach it in your journey first." % GameState.floor_short(f)
		return
	var full := GameState.clear_reward(f, 0, false, false)["total"] as int
	var pay := full if not GameState.is_cleared(f) else ceili(full * GameState.REPLAY_REPEAT_FACTOR)
	var state := "cleared · replay pays %d+" % pay if GameState.is_cleared(f) else "not cleared yet · pays %d+" % pay
	_info.text = "%s  ·  %s  ·  %s" % [GameState.floor_short(f), GameState.floor_name(f), state]


func _on_floor_pressed(depth: int) -> void:
	if not GameState.is_unlocked(-depth):
		GameState.play_sfx("hit", false, -12.0)
		return
	GameState.play_sfx("magic", false, -8.0)
	GameState.start_replay(-depth)

extends Node2D
## Ecranul de acasă: CONTINUE (tura salvată), LEVELS (rejoacă etaje), NEW GAME, SHOP, TIPS ON/OFF.
## Progresul se salvează automat la începutul fiecărui etaj (GameState.checkpoint).

@onready var knight: Actor = $Knight
@onready var ghost: Actor = $KingGhost
@onready var ui: CanvasLayer = $UI
@onready var coins_label: Label = $UI/Coins/Amount

var _continue_btn: IconButton
var _continue_info: Label
var _new_btn: IconButton
var _shop_btn: IconButton
var _tips_btn: IconButton
var _shop: ShopPanel
var _levels: LevelSelect
var _levels_btn: IconButton
var _confirm_new := false
var _t := 0.0
var _stars := PackedVector2Array()


func _ready() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 80:
		_stars.append(Vector2(rng.randf_range(0, 1152), rng.randf_range(0, 470)))
	_build_menu()
	_levels = LevelSelect.new()
	ui.add_child(_levels)
	_levels.closed.connect(func():
		coins_label.get_parent().visible = true
		_levels_btn.grab_focus()
	)
	_shop = ShopPanel.new()
	ui.add_child(_shop)
	_shop.closed.connect(_on_shop_closed)
	_shop.equipped_changed.connect(_refresh_knight)
	GameState.coins_changed.connect(func(_c: int): _refresh())
	_refresh()
	_refresh_knight()
	(_continue_btn if not _continue_btn.disabled else _new_btn).grab_focus()
	if GameState.open_levels_on_menu:
		# înapoi dintr-o rejucare -> direct în meniul de nivele
		GameState.open_levels_on_menu = false
		coins_label.get_parent().visible = false
		_levels.open()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _build_menu() -> void:
	var box := VBoxContainer.new()
	box.position = Vector2(426, 230)
	box.size = Vector2(300, 300)
	box.add_theme_constant_override("separation", 12)
	ui.add_child(box)

	_continue_btn = IconButton.make("CONTINUE", "play", GameState.COL_GOLD, 22)
	_continue_btn.custom_minimum_size = Vector2(300, 50)
	_continue_btn.pressed.connect(_on_continue)
	box.add_child(_continue_btn)
	_continue_info = UiKit.label("", 14, Color(GameState.COL_TEXT, 0.75), 3)
	_continue_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_continue_info)

	_levels_btn = IconButton.make("LEVELS", "levels", GameState.COL_CYAN, 20)
	_levels_btn.custom_minimum_size = Vector2(300, 46)
	_levels_btn.pressed.connect(_on_levels)
	box.add_child(_levels_btn)

	_new_btn = IconButton.make("NEW GAME", "new", GameState.COL_MAGENTA, 20)
	_new_btn.custom_minimum_size = Vector2(300, 46)
	_new_btn.pressed.connect(_on_new_game)
	box.add_child(_new_btn)

	_shop_btn = IconButton.make("SHOP", "shop", GameState.COL_MAGENTA, 20)
	_shop_btn.custom_minimum_size = Vector2(300, 46)
	_shop_btn.pressed.connect(_on_shop)
	box.add_child(_shop_btn)

	_tips_btn = IconButton.make("", "tips", GameState.COL_MAGENTA, 18)
	_tips_btn.custom_minimum_size = Vector2(300, 42)
	_tips_btn.pressed.connect(_on_tips)
	box.add_child(_tips_btn)


func _refresh() -> void:
	coins_label.text = str(GameState.coins)
	var has_run := GameState.run_active
	_continue_btn.disabled = not has_run
	if has_run:
		_continue_info.text = "Resume: %s" % GameState.floor_title(GameState.resume_floor)
	else:
		_continue_info.text = "No saved journey yet"
	_tips_btn.text = "KING'S TIPS: %s" % ("ON" if GameState.tips_enabled else "OFF")


func _refresh_knight() -> void:
	knight.set_character("knight")


func _on_continue() -> void:
	if not GameState.run_active:
		return
	GameState.play_sfx("magic", false, -8.0)
	GameState.continue_run()


func _on_new_game() -> void:
	if GameState.run_active and not _confirm_new:
		# confirmare: tura salvată se pierde (monedele și obiectele rămân)
		_confirm_new = true
		_new_btn.text = "START OVER? CLICK AGAIN"
		get_tree().create_timer(3.0).timeout.connect(func():
			if is_instance_valid(_new_btn):
				_confirm_new = false
				_new_btn.text = "NEW GAME"
		)
		return
	GameState.play_sfx("gate", false, -8.0)
	GameState.new_run()


func _on_shop() -> void:
	GameState.play_sfx("blip", false, -10.0)
	coins_label.get_parent().visible = false   # magazinul își arată propriile monede
	_shop.open()


func _on_levels() -> void:
	GameState.play_sfx("blip", false, -10.0)
	coins_label.get_parent().visible = false
	_levels.open()


func _on_shop_closed() -> void:
	coins_label.get_parent().visible = true
	_refresh()
	_shop_btn.grab_focus()


func _on_tips() -> void:
	GameState.set_tips_enabled(not GameState.tips_enabled)
	GameState.play_sfx("blip", false, -10.0)
	_refresh()


# -----------------------------------------------------------------------------
#  Decor: cer cu stele, castelul în depărtare, podeaua în carouri jos
# -----------------------------------------------------------------------------
func _draw() -> void:
	var mag := GameState.COL_MAGENTA
	for i in _stars.size():
		var tw := 0.4 + 0.6 * absf(sin(_t * 1.2 + i))
		draw_rect(Rect2(_stars[i], Vector2(2, 2)), Color(1, 1, 1, 0.45 * tw))
	# silueta castelului în spate
	var wall := Color("#120a1f")
	var base_y := 520.0
	draw_rect(Rect2(780, 330, 260, base_y - 330), wall)
	draw_rect(Rect2(760, 270, 60, base_y - 270), wall)
	draw_rect(Rect2(1000, 290, 60, base_y - 290), wall)
	for r: Rect2 in [Rect2(780, 330, 260, base_y - 330), Rect2(760, 270, 60, base_y - 270), Rect2(1000, 290, 60, base_y - 290)]:
		draw_rect(r, Color(mag, 0.6), false, 2.0)
	var x := 780.0
	while x < 1030.0:
		draw_rect(Rect2(x, 314, 16, 16), wall)
		draw_rect(Rect2(x, 314, 16, 16), Color(mag, 0.6), false, 2.0)
		x += 30.0
	draw_rect(Rect2(885, 440, 50, 80), Color(mag, 0.25 + 0.15 * sin(_t * 3.0)))
	draw_rect(Rect2(885, 440, 50, 80), GameState.COL_GOLD, false, 2.0)
	# orizont + linia podelei
	draw_line(Vector2(0, base_y), Vector2(1152, base_y), mag, 2.0)

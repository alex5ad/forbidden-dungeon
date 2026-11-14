class_name ShopPanel
extends PanelContainer
## Magazinul Regal (de pe ecranul de acasă).
##  - SCUTURI: țin ridicate mai mult (fereastră de parry mai lungă, cooldown mai scurt)
##  - ARMURI: doar cosmetice
## Monedele se câștigă după fiecare etaj curățat (GameState.floor_reward).

signal closed
signal equipped_changed

var _coins_label: Label
var _rows: Dictionary = {}   # id -> Button


func _ready() -> void:
	position = Vector2(76, 40)
	size = Vector2(1000, 568)
	add_theme_stylebox_override("panel", UiKit.panel_style(GameState.COL_GOLD, 0.97))
	_build()
	visible = false
	GameState.coins_changed.connect(func(_c: int): _refresh())


func open() -> void:
	_refresh()
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.15)
	var first: Button = _rows.get(GameState.equipped_shield)
	if first:
		first.grab_focus()


func close() -> void:
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		get_viewport().set_input_as_handled()
		close()


func _build() -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	var title := UiKit.label("ROYAL SHOP", 34, GameState.COL_GOLD, 8)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(_coin_icon())
	_coins_label = UiKit.label("0", 26, GameState.COL_GOLD, 6)
	header.add_child(_coins_label)

	var sub := UiKit.label("Floors pay 10 × chapter, bosses 100 × chapter, +2 per PERFECT, +50% if you take no hit. "
			+ "Shields hold longer; armors only change your look.",
			15, Color(GameState.COL_TEXT, 0.8), 3)
	root.add_child(sub)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 28)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)
	cols.add_child(_column("SHIELDS  ·  hold longer", GameState.SHIELDS, true))
	cols.add_child(_column("ARMORS  ·  cosmetic", GameState.ARMORS, false))

	var back := IconButton.make("BACK", "home", GameState.COL_MAGENTA, 18)
	back.custom_minimum_size = Vector2(180, 44)
	back.size_flags_horizontal = Control.SIZE_SHRINK_END
	back.pressed.connect(close)
	root.add_child(back)


func _column(title: String, items: Array[Dictionary], shields: bool) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	col.add_child(UiKit.label(title, 18, GameState.COL_MAGENTA, 4))
	for it in items:
		col.add_child(_row(it, shields))
	return col


func _row(it: Dictionary, shield: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.custom_minimum_size = Vector2(0, 58)
	# previzualizare
	var preview: Control
	if shield:
		var si := ShieldIcon.new()
		si.color = it["color"]
		preview = si
	else:
		var tr := TextureRect.new()
		var frames := SpriteLib.frames(String(it["look"]))
		tr.texture = frames.get_frame_texture("idle", 0)
		tr.self_modulate = it["tint"]
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview = tr
	preview.custom_minimum_size = Vector2(40, 54)
	row.add_child(preview)
	# nume + descriere
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 0)
	info.add_child(UiKit.label(String(it["name"]), 18, GameState.COL_TEXT, 3))
	var desc := UiKit.label(String(it["desc"]), 13, Color(GameState.COL_TEXT, 0.65), 2)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(desc)
	row.add_child(info)
	# buton: BUY / EQUIP / EQUIPPED
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(132, 42)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiKit.style_button(btn, GameState.COL_GOLD, 15)
	var id := String(it["id"])
	btn.pressed.connect(_on_item_pressed.bind(id))
	row.add_child(btn)
	_rows[id] = btn
	return row


func _on_item_pressed(id: String) -> void:
	if GameState.owns(id):
		GameState.equip(id)
		GameState.play_sfx("blip", false, -10.0)
	elif not GameState.buy(id):
		GameState.play_sfx("hit", false, -12.0)
		return
	_refresh()
	equipped_changed.emit()


func _refresh() -> void:
	_coins_label.text = str(GameState.coins)
	for id: String in _rows:
		var btn: Button = _rows[id]
		var it := GameState.item_data(id)
		if GameState.is_equipped(id):
			btn.text = "EQUIPPED"
			btn.disabled = true
		elif GameState.owns(id):
			btn.text = "EQUIP"
			btn.disabled = false
		else:
			btn.text = "BUY  %d" % int(it["price"])
			btn.disabled = GameState.coins < int(it["price"])


func _coin_icon() -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = SpriteLib.texture("0x72/coin_anim_f0.png")
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(32, 32)
	return tr


## Iconiță de scut desenată (culoarea scutului din catalog).
class ShieldIcon extends Control:
	var color := Color.WHITE

	func _draw() -> void:
		var c := size * 0.5
		var w := 30.0
		var h := 38.0
		var pts := PackedVector2Array([
			c + Vector2(-w * 0.5, -h * 0.5), c + Vector2(w * 0.5, -h * 0.5),
			c + Vector2(w * 0.5, h * 0.05), c + Vector2(0, h * 0.5), c + Vector2(-w * 0.5, h * 0.05)])
		draw_colored_polygon(pts, color.darkened(0.35))
		var inner := PackedVector2Array()
		for p in pts:
			inner.append(c + (p - c) * 0.72)
		draw_colored_polygon(inner, color)
		pts.append(pts[0])
		draw_polyline(pts, Color.BLACK, 2.0)
		draw_rect(Rect2(c + Vector2(-2, -h * 0.32), Vector2(4, h * 0.6)), color.darkened(0.5))

class_name PauseMenu
extends CanvasLayer
## Pauză în timpul nivelului: butonul ⏸ din colțul din dreapta-sus sau Esc.
## PLAY = continuă, HOME = ecranul de acasă (progresul e salvat la începutul fiecărui etaj).

var _pause_btn: IconButton
var _overlay: Control
var _play_btn: IconButton
var _tips_btn: IconButton
var _floor_label: Label
var _note: Label


func _ready() -> void:
	layer = 70
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_overlay.visible = false
	GameState.tips_toggled.connect(func(_on: bool): _refresh())


func is_open() -> bool:
	return _overlay.visible


func toggle() -> void:
	if _overlay.visible:
		resume()
	else:
		pause()


func pause() -> void:
	if get_tree().paused or GameState.is_transitioning():
		return
	get_tree().paused = true
	_refresh()
	_overlay.visible = true
	_play_btn.grab_focus()
	GameState.play_sfx("blip", false, -10.0)


func resume() -> void:
	_overlay.visible = false
	get_tree().paused = false
	_pause_btn.release_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		toggle()


func _refresh() -> void:
	_tips_btn.text = "KING'S TIPS: %s" % ("ON" if GameState.tips_enabled else "OFF")
	_floor_label.text = GameState.floor_title(GameState.current_floor)
	if GameState.replay_mode:
		_floor_label.text = "REPLAY  ·  " + _floor_label.text
		_note.text = "Replay: your saved journey is not affected."
	else:
		_note.text = "Your journey is saved at the start of every floor."


func _build() -> void:
	_pause_btn = IconButton.make("", "pause", GameState.COL_MAGENTA, 16)
	_pause_btn.position = Vector2(1100, 11)
	_pause_btn.custom_minimum_size = Vector2(42, 40)
	_pause_btn.size = Vector2(42, 40)
	_pause_btn.tooltip_text = "Pause (Esc)"
	_pause_btn.focus_mode = Control.FOCUS_NONE
	_pause_btn.pressed.connect(toggle)
	add_child(_pause_btn)

	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)

	var panel := PanelContainer.new()
	panel.position = Vector2(386, 150)
	panel.size = Vector2(380, 340)
	panel.add_theme_stylebox_override("panel", UiKit.panel_style(GameState.COL_MAGENTA))
	_overlay.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)
	var title := UiKit.label("PAUSED", 40, GameState.COL_GOLD, 8)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	_floor_label = UiKit.label("", 15, Color(GameState.COL_TEXT, 0.8), 3)
	_floor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_floor_label)

	_play_btn = IconButton.make("PLAY", "play", GameState.COL_GOLD, 22)
	_play_btn.custom_minimum_size = Vector2(0, 52)
	_play_btn.pressed.connect(resume)
	vb.add_child(_play_btn)
	_tips_btn = IconButton.make("", "tips", GameState.COL_MAGENTA, 17)
	_tips_btn.custom_minimum_size = Vector2(0, 44)
	_tips_btn.pressed.connect(func(): GameState.set_tips_enabled(not GameState.tips_enabled))
	vb.add_child(_tips_btn)
	var home := IconButton.make("HOME", "home", GameState.COL_MAGENTA, 20)
	home.custom_minimum_size = Vector2(0, 48)
	home.pressed.connect(func():
		_overlay.visible = false
		GameState.go_home(GameState.replay_mode)
	)
	vb.add_child(home)
	_note = UiKit.label("", 13, Color(GameState.COL_TEXT, 0.6), 2)
	var note := _note
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(note)

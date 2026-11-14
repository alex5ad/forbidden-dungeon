class_name DialogBox
extends CanvasLayer
## Casetă de dialog cu efect de mașină de scris.
## Folosire:  await dialog.say("Regele", "Ascultă-mă...")
## Click / Space / Enter: primul apăsat completează textul, al doilea trece mai departe.

signal advanced

const CHARS_PER_SEC := 60.0

var _panel: PanelContainer
var _name_label: Label
var _text_label: Label
var _hint: Label
var _tween: Tween
var _typing := false
var _waiting := false


func _ready() -> void:
	layer = 50
	_build()
	_panel.visible = false


func say(speaker: String, text: String, speaker_color: Color = GameState.COL_GOLD) -> void:
	_panel.visible = true
	_name_label.text = speaker
	_name_label.add_theme_color_override("font_color", speaker_color)
	_name_label.visible = speaker != ""
	_text_label.text = text
	_text_label.visible_ratio = 0.0
	_hint.visible = false
	_typing = true
	_waiting = true
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_text_label, "visible_ratio", 1.0, maxf(text.length() / CHARS_PER_SEC, 0.1))
	_tween.tween_callback(_finish_typing)
	await advanced


func close() -> void:
	_panel.visible = false
	_waiting = false


func is_open() -> bool:
	return _panel.visible


func _finish_typing() -> void:
	_typing = false
	_text_label.visible_ratio = 1.0
	_hint.visible = true


func _input(event: InputEvent) -> void:
	if not _waiting:
		return
	var pressed := false
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		pressed = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("parry"):
		pressed = true
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	if _typing:
		if _tween:
			_tween.kill()
		_finish_typing()
	else:
		_waiting = false
		GameState.play_sfx("blip", false, -18.0)
		advanced.emit()


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = 64.0
	_panel.offset_right = -64.0
	_panel.offset_top = -200.0
	_panel.offset_bottom = -28.0
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.02, 0.07, 0.94)
	style.border_color = GameState.COL_MAGENTA
	style.set_border_width_all(3)
	style.shadow_color = Color(1, 0, 1, 0.25)
	style.shadow_size = 10
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(vb)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 22)
	_name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_name_label.add_theme_constant_override("outline_size", 4)
	vb.add_child(_name_label)

	_text_label = Label.new()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_label.add_theme_font_size_override("font_size", 20)
	_text_label.add_theme_color_override("font_color", GameState.COL_TEXT)
	_text_label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	vb.add_child(_text_label)

	_hint = Label.new()
	_hint.text = "[ Click / Space ]"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", Color(GameState.COL_GOLD, 0.8))
	vb.add_child(_hint)

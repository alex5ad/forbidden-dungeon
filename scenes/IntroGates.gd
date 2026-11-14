extends Node2D
## ACTUL I – Porțile castelului (exterior).
## Cavalerul se înfricoșează -> CLICK pe porți -> porțile se deschid, fascicul magenta
## spre cer (Tomb of the Mask), zoom rapid în palat -> MirrorRoom.

const GATE_RECT := Rect2(512, 468, 128, 132)
const GATE_CENTER := Vector2(576, 534)
const GROUND_Y := 600.0

const NARRATION: Array[String] = [
	"A wandering Knight has heard the legend of the cursed castle...",
	"The walls are crumbling. Disembodied eyes watch you from shattered windows.",
	"Your heart pounds. But a Knight never turns back.",
]

@onready var camera: ShakeCamera = $Camera2D
@onready var beam_core: NeonBeam = $Beam/Core
@onready var beam_glow: NeonBeam = $Beam/Glow
@onready var gate_left: GateDoor = $Gates/GateLeft
@onready var gate_right: GateDoor = $Gates/GateRight
@onready var gate_particles: CPUParticles2D = $GateParticles
@onready var knight: Actor = $Knight
@onready var narration: Label = $UI/Narration
@onready var click_prompt: Label = $UI/ClickPrompt

var _can_click := false
var _opening := false
var _hovering := false
var _t := 0.0
var _stars: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	GameState.reset_run()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 90:
		_stars.append(Vector2(rng.randf_range(0, 1152), rng.randf_range(0, 380)))
	beam_core.size = Vector2(beam_core.size.x, 0.0)
	beam_glow.size = Vector2(beam_glow.size.x, 0.0)
	beam_core.position.y = GROUND_Y
	beam_glow.position.y = GROUND_Y
	click_prompt.modulate.a = 0.0
	narration.text = ""
	_intro_sequence()


func _intro_sequence() -> void:
	await knight.walk_to(Vector2(576, 612), 90.0).finished
	knight.set_tremble(1.6)  # se înfricoșează
	_can_click = true
	for i in NARRATION.size():
		if _opening:
			return
		await _type_line(NARRATION[i])
		if i == 0:
			_show_prompt()
		await get_tree().create_timer(1.6).timeout


func _type_line(text: String) -> void:
	narration.text = text
	narration.visible_ratio = 0.0
	var t := create_tween()
	t.tween_property(narration, "visible_ratio", 1.0, text.length() / 45.0)
	await t.finished


func _show_prompt() -> void:
	var t := create_tween().set_loops()
	t.tween_property(click_prompt, "modulate:a", 1.0, 0.5)
	t.tween_property(click_prompt, "modulate:a", 0.35, 0.5)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _opening:
		return
	var over := _can_click and GATE_RECT.grow(16.0).has_point(get_global_mouse_position())
	if over != _hovering:
		_hovering = over
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if over else Input.CURSOR_ARROW)
	var hl := 1.0 if over else 0.35 + 0.25 * sin(_t * 3.0)
	gate_left.highlight = hl
	gate_right.highlight = hl


func _unhandled_input(event: InputEvent) -> void:
	if not _can_click or _opening:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and GATE_RECT.grow(16.0).has_point(get_global_mouse_position()):
			_open_gates()
	elif event.is_action_pressed("ui_accept"):
		_open_gates()


func _open_gates() -> void:
	_opening = true
	GameState.play_music("normal")
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	click_prompt.visible = false
	narration.text = "The gates creak open..."
	narration.visible_ratio = 1.0
	knight.set_tremble(0.0)
	GameState.play_sfx("gate", false, -4.0)
	GameState.shake(6.0)
	# 1) porțile se deschid (canatele se rotesc spre balamale)
	var t := create_tween().set_parallel()
	t.tween_property(gate_left, "scale:x", 0.12, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(gate_right, "scale:x", 0.12, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await t.finished
	# 2) fasciculul magenta țâșnește spre cer
	GameState.play_sfx("magic", false, -2.0)
	gate_particles.emitting = true
	var top := -80.0
	var b := create_tween().set_parallel()
	for beam: NeonBeam in [beam_core, beam_glow]:
		b.tween_property(beam, "position:y", top, 0.45).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		b.tween_property(beam, "size:y", GROUND_Y - top, 0.45).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	GameState.shake(14.0)
	await b.finished
	await get_tree().create_timer(0.7).timeout
	# 3) zoom rapid în interiorul palatului
	var z := create_tween().set_parallel()
	z.tween_property(camera, "position", GATE_CENTER, 0.9).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	z.tween_property(camera, "zoom", Vector2(7, 7), 0.9).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	await get_tree().create_timer(0.6).timeout
	FX.flash_screen(self, Color(1.0, 0.5, 1.0), 0.8)
	GameState.mirror_visit = 1
	GameState.change_scene(GameState.SCENE_MIRROR, 0.25)


func _exit_tree() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


# -----------------------------------------------------------------------------
#  Castelul degradat (desenat procedural: negru + neon magenta + auriu)
# -----------------------------------------------------------------------------
func _draw() -> void:
	var mag := GameState.COL_MAGENTA
	var gold := GameState.COL_GOLD
	var wall := Color("#120a1f")
	# stele
	for i in _stars.size():
		var tw := 0.4 + 0.6 * absf(sin(_t * 1.3 + i))
		draw_rect(Rect2(_stars[i], Vector2(2, 2)), Color(1, 1, 1, 0.5 * tw))
	# orizont magenta
	for i in 6:
		draw_rect(Rect2(0, GROUND_Y - 30.0 - i * 18.0, 1152, 18), Color(mag, 0.025 * (6 - i)))
	# turnuri
	var left_tower := Rect2(236, 150, 100, 450)
	var right_tower := Rect2(816, 190, 100, 410)
	var keep := Rect2(316, 260, 520, 340)
	for r: Rect2 in [left_tower, right_tower, keep]:
		draw_rect(r, wall)
	# creneluri (unele lipsesc -> castel degradat)
	var missing := [2, 5, 6, 11, 14]
	var i := 0
	var x := keep.position.x
	while x < keep.end.x - 4.0:
		if i not in missing:
			draw_rect(Rect2(x, keep.position.y - 22.0, 22, 22), wall)
			draw_rect(Rect2(x, keep.position.y - 22.0, 22, 22), Color(mag, 0.9), false, 2.0)
		x += 34.0
		i += 1
	for r: Rect2 in [left_tower, right_tower]:
		var mx := r.position.x
		while mx < r.end.x - 4.0:
			draw_rect(Rect2(mx, r.position.y - 18.0, 18, 18), wall)
			draw_rect(Rect2(mx, r.position.y - 18.0, 18, 18), Color(mag, 0.9), false, 2.0)
			mx += 28.0
	# acoperiș rupt pe turnul din stânga + steag zdrențuit
	draw_colored_polygon(PackedVector2Array([Vector2(230, 132), Vector2(286, 40), Vector2(318, 96), Vector2(342, 132)]), wall)
	draw_polyline(PackedVector2Array([Vector2(230, 132), Vector2(286, 40), Vector2(318, 96), Vector2(306, 104), Vector2(342, 132)]), mag, 2.0)
	draw_line(Vector2(286, 40), Vector2(286, 4), Color(gold, 0.8), 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(286, 6), Vector2(318, 12 + sin(_t * 3.0) * 3.0), Vector2(300, 18), Vector2(312, 26 + sin(_t * 3.0 + 1.0) * 3.0), Vector2(286, 24)]), Color(mag, 0.7))
	# contururi neon
	for r: Rect2 in [left_tower, right_tower, keep]:
		draw_rect(r, mag, false, 2.0)
	# ferestre: unele luminează slab, una e un „ochi” galben care clipește
	var windows := [Vector2(270, 220), Vector2(270, 330), Vector2(850, 260), Vector2(850, 380),
		Vector2(400, 320), Vector2(720, 320), Vector2(560, 300)]
	for w_i in windows.size():
		var wp: Vector2 = windows[w_i]
		var lit := 0.5 + 0.5 * sin(_t * 2.0 + w_i * 1.7)
		draw_rect(Rect2(wp, Vector2(28, 40)), Color(0.02, 0.0, 0.05))
		draw_rect(Rect2(wp, Vector2(28, 40)), Color(mag, 0.6), false, 2.0)
		if w_i % 3 == 0:
			draw_rect(Rect2(wp + Vector2(8, 16), Vector2(4, 4)), Color(gold, lit))
			draw_rect(Rect2(wp + Vector2(16, 16), Vector2(4, 4)), Color(gold, lit))
	# crăpături
	var cracks := [
		PackedVector2Array([Vector2(360, 262), Vector2(372, 300), Vector2(364, 340), Vector2(380, 390)]),
		PackedVector2Array([Vector2(790, 262), Vector2(776, 320), Vector2(792, 360)]),
		PackedVector2Array([Vector2(250, 420), Vector2(270, 470), Vector2(262, 520)]),
		PackedVector2Array([Vector2(900, 300), Vector2(884, 350), Vector2(896, 400), Vector2(884, 450)]),
	]
	for c: PackedVector2Array in cracks:
		draw_polyline(c, Color(mag, 0.45), 2.0)
	# arcada porții + golul din spate (luminează când se deschid porțile)
	var arch := GATE_RECT.grow(10.0)
	draw_rect(arch, Color("#1b0f2a"))
	draw_rect(GATE_RECT, Color(0.0, 0.0, 0.0))
	if _opening:
		draw_rect(GATE_RECT, Color(mag, 0.5 + 0.2 * sin(_t * 20.0)))
	draw_rect(arch, gold, false, 3.0)
	draw_string(ThemeDB.fallback_font, Vector2(arch.position.x - 40, arch.position.y - 12), "PALATUL REGAL",
			HORIZONTAL_ALIGNMENT_CENTER, arch.size.x + 80, 14, Color(gold, 0.8))
	# sol
	draw_rect(Rect2(0, GROUND_Y, 1152, 48), Color("#0b0614"))
	draw_line(Vector2(0, GROUND_Y), Vector2(1152, GROUND_Y), Color(mag, 0.8), 2.0)
	# pietre căzute
	for p: Vector2 in [Vector2(420, 596), Vector2(700, 594), Vector2(760, 598), Vector2(330, 597)]:
		draw_rect(Rect2(p, Vector2(14, 8)), wall)
		draw_rect(Rect2(p, Vector2(14, 8)), Color(mag, 0.6), false, 1.0)

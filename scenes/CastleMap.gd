extends Node2D
## Secțiunea transversală a castelului (+2 ... 0 ... -50), stil Tomb of the Mask.
## Iconița Cavalerului se deplasează animat de la GameState.current_floor la GameState.target_floor,
## apoi GameState.arrive() intră în scena etajului. Click / Space = grăbește animația.

const TOWER := Rect2(316, 120, 520, 0)   # înălțimea se calculează din rânduri
const TOP_Y := 120.0
const BIG_ROW := 64.0       # +2, +1, 0
const SMALL_ROW := 22.0     # -1 ... -50
const GROUND_GAP := 10.0
const ICON_X := 760.0

@onready var camera: ShakeCamera = $Camera2D
@onready var icon: Actor = $KnightIcon
@onready var king_icon: Actor = $KingIcon
@onready var trail: CPUParticles2D = $KnightIcon/Trail
@onready var floor_label: Label = $UI/FloorLabel
@onready var title_label: Label = $UI/Title
@onready var banner: Label = $UI/Banner
@onready var hint: Label = $UI/Hint

var _from := 0
var _to := -1
var _tween: Tween
var _done := false
var _t := 0.0


func _ready() -> void:
	_from = GameState.current_floor
	_to = GameState.target_floor
	if _from == _to:
		_from = 0 if _to < 0 else _to
	icon.position = Vector2(ICON_X, floor_y(_from))
	king_icon.visible = _to > 0 and _from >= 0   # Regele urcă împreună cu Cavalerul
	king_icon.position = icon.position + Vector2(-26, 0)
	camera.position = Vector2(576, _camera_y(icon.position.y))
	banner.modulate.a = 0.0
	title_label.text = "CASTLE CROSS-SECTION"
	_travel()


func floor_y(f: int) -> float:
	if f >= 0:
		return TOP_Y + (GameState.TOP_FLOOR - f) * BIG_ROW + BIG_ROW * 0.5
	return TOP_Y + 3.0 * BIG_ROW + GROUND_GAP + (absi(f) - 1) * SMALL_ROW + SMALL_ROW * 0.5


func _map_bottom() -> float:
	return floor_y(GameState.DEEPEST_FLOOR) + SMALL_ROW * 0.5 + 40.0


func _camera_y(y: float) -> float:
	return clampf(y, 324.0, _map_bottom() - 324.0)


func _travel() -> void:
	var dist := absi(_to - _from)
	var bounce_back := _from <= GameState.DEEPEST_FLOOR and _to == 0
	var quick := dist == 1 and _to < 0   # etaj după etaj: drum scurt
	var dur := 0.55 if quick else clampf(0.7 + dist * 0.09, 0.9, 2.2)
	await get_tree().create_timer(0.15 if quick else 0.35).timeout
	icon.play("run")
	king_icon.play("run")
	trail.emitting = true
	_tween = create_tween()
	if bounce_back:
		# „BOUNCE BACK!” – urcare fulgerătoare de la -50 la Parter
		_show_banner("BOUNCE BACK!")
		GameState.play_sfx("perfect", false, -4.0)
		_tween.tween_property(icon, "position:y", floor_y(_to), 1.3).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN_OUT)
	else:
		GameState.play_sfx("swing", false, -10.0)
		_tween.tween_property(icon, "position:y", floor_y(_to), dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _tween.finished
	trail.emitting = false
	icon.play("idle")
	king_icon.play("idle")
	GameState.shake(10.0 if bounce_back else 4.0)
	GameState.play_sfx("bounce", false)
	FX.burst(self, icon.position, GameState.COL_GOLD, 24, 180.0, 0.5, 3.0)
	floor_label.text = GameState.floor_title(_to)
	if GameState.is_chapter_start(_to):
		_show_banner("CHAPTER %d" % GameState.chapter_number(_to))
	elif not bounce_back:
		_show_banner(GameState.floor_short(_to))
	await get_tree().create_timer(0.6 if quick and not GameState.is_chapter_start(_to) else 1.1).timeout
	_done = true
	GameState.arrive()


func _show_banner(text: String) -> void:
	banner.text = text
	banner.scale = Vector2(1.5, 1.5)
	var t := create_tween()
	t.tween_property(banner, "modulate:a", 1.0, 0.12)
	t.parallel().tween_property(banner, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.9)
	t.tween_property(banner, "modulate:a", 0.0, 0.4)


func _unhandled_input(event: InputEvent) -> void:
	if _tween and _tween.is_running() and (event.is_action_pressed("shield") or event.is_action_pressed("ui_accept")):
		_tween.set_speed_scale(4.0)


func _process(delta: float) -> void:
	_t += delta
	king_icon.position = king_icon.position.lerp(icon.position + Vector2(-26, 4), minf(delta * 10.0, 1.0))
	camera.position.y = _camera_y(icon.position.y)
	if not _done:
		floor_label.text = GameState.floor_title(_nearest_floor(icon.position.y))
	queue_redraw()


func _nearest_floor(y: float) -> int:
	var best := 0
	var best_d := INF
	for f in range(GameState.TOP_FLOOR, GameState.DEEPEST_FLOOR - 1, -1):
		var d := absf(floor_y(f) - y)
		if d < best_d:
			best_d = d
			best = f
	return best


# -----------------------------------------------------------------------------
#  Desenul secțiunii (o singură dată per frame; ~60 de rânduri, ieftin)
# -----------------------------------------------------------------------------
func _draw() -> void:
	var mag := GameState.COL_MAGENTA
	var gold := GameState.COL_GOLD
	var font := ThemeDB.fallback_font
	var left := TOWER.position.x
	var right := TOWER.end.x
	var bottom := _map_bottom()
	var pulse := 0.5 + 0.5 * sin(_t * 5.0)
	# acoperișul turnului + coroana
	draw_colored_polygon(PackedVector2Array([Vector2(left - 20, TOP_Y), Vector2(576, 30), Vector2(right + 20, TOP_Y)]), Color("#140a22"))
	draw_polyline(PackedVector2Array([Vector2(left - 20, TOP_Y), Vector2(576, 30), Vector2(right + 20, TOP_Y)]), mag, 3.0)
	draw_colored_polygon(PackedVector2Array([Vector2(556, 40), Vector2(560, 22), Vector2(568, 32), Vector2(576, 16),
		Vector2(584, 32), Vector2(592, 22), Vector2(596, 40)]), gold)
	# corpul turnului
	draw_rect(Rect2(left, TOP_Y, right - left, bottom - TOP_Y), Color("#0b0616"))
	# rândurile de deasupra solului
	var above := {2: "Throne Room", 1: "Royal Gallery", 0: "Mirror Hall"}
	for f: int in [2, 1, 0]:
		var y0 := floor_y(f) - BIG_ROW * 0.5
		var r := Rect2(left, y0, right - left, BIG_ROW)
		var is_target := f == _to
		draw_rect(r.grow(-3.0), Color(GameState.COL_FLOOR_B if f == 0 else GameState.COL_FLOOR_A, 0.9))
		if is_target:
			draw_rect(r.grow(-3.0), Color(gold, 0.15 + 0.15 * pulse))
		draw_rect(r, Color(mag, 0.7), false, 2.0)
		var lbl := "+%d" % f if f > 0 else "0"
		draw_string(font, Vector2(left + 14, y0 + 40), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, gold)
		draw_string(font, Vector2(left + 110, y0 + 40), String(above[f]), HORIZONTAL_ALIGNMENT_LEFT, -1, 20,
				gold if is_target else GameState.COL_TEXT)
	# solul și porțile
	var ground := floor_y(0) + BIG_ROW * 0.5
	draw_rect(Rect2(0, ground - 2.0, 1152, 4), gold)
	draw_string(font, Vector2(36, ground - 14.0), "GATES  ->", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, gold)
	draw_rect(Rect2(left - 12, floor_y(0) - 22.0, 12, 44), Color(gold, 0.7))
	# subsolurile -1 ... -50
	var cleared_depth := absi(mini(_from, 0)) if _to < _from else 50
	for d in range(1, 51):
		var f := -d
		var y0 := floor_y(f) - SMALL_ROW * 0.5
		var r := Rect2(left, y0, right - left, SMALL_ROW)
		var z := GameState.zone_index(f)
		var boss := GameState.is_boss_floor(f)
		var base := Color(0.05 + z * 0.012, 0.04, 0.10 + z * 0.015)
		if d % 2 == 0:
			base = base.lightened(0.04)
		draw_rect(r, base)
		if d <= cleared_depth and _to < 0:
			draw_rect(r, Color(gold, 0.05))
		if boss:
			draw_rect(r, Color(mag, 0.22))
			draw_rect(r, Color(mag, 0.8), false, 1.0)
		if f == _to:
			draw_rect(r, Color(gold, 0.18 + 0.2 * pulse))
			draw_rect(r, gold, false, 2.0)
		var txt_col := Color(GameState.COL_TEXT, 0.55)
		if boss:
			txt_col = mag
		if f == _to:
			txt_col = gold
		draw_string(font, Vector2(left + 14, y0 + 16), "%d" % f, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, txt_col)
		if boss:
			draw_string(font, Vector2(left + 110, y0 + 16), "BOSS: %s" % GameState.ZONES[z]["boss"], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, txt_col)
		elif d % 10 == 1:
			draw_string(font, Vector2(left + 110, y0 + 16), String(GameState.ZONES[z]["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(txt_col, 0.9))
		if f == GameState.DEEPEST_FLOOR:
			draw_string(font, Vector2(right + 16, y0 + 16), "<- ROYAL TREASURE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, gold)
	# puțul (shaft) pe care coboară Cavalerul
	draw_line(Vector2(ICON_X, floor_y(0)), Vector2(ICON_X, floor_y(GameState.DEEPEST_FLOOR)), Color(mag, 0.35), 2.0)
	# halou auriu sub iconița Cavalerului
	draw_circle(icon.position, 16.0, Color(gold, 0.18 + 0.12 * pulse))
	draw_arc(icon.position, 16.0, 0.0, TAU, 24, Color(gold, 0.7), 2.0)
	# contur exterior neon
	draw_rect(Rect2(left, TOP_Y, right - left, bottom - TOP_Y), mag, false, 3.0)
	draw_rect(Rect2(left - 6, TOP_Y - 6, right - left + 12, bottom - TOP_Y + 12), Color(mag, 0.2), false, 6.0)

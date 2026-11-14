extends Node
## Autoload global (Project Settings > Autoload, nume: GameState).
## Ține starea poveștii, progresia etajelor (0 -> -1..-50 -> 0 -> +1 -> +2),
## tranzițiile între scene, hitstop, screen shake și efectele sonore procedurale.
## NOTĂ: nu are class_name (ar intra în conflict cu numele autoload-ului).

signal hp_changed(hp: int, max_hp: int)
signal floor_changed(floor_num: int)

# --- Scene -----------------------------------------------------------------
const SCENE_INTRO := "res://scenes/IntroGates.tscn"
const SCENE_MIRROR := "res://scenes/MirrorRoom.tscn"
const SCENE_MAP := "res://scenes/CastleMap.tscn"
const SCENE_DUNGEON := "res://scenes/DungeonFloor.tscn"
const SCENE_THRONE := "res://scenes/ThroneEnding.tscn"

# --- Paletă (Tomb of the Mask + FNaF 4) -------------------------------------
const COL_BG := Color("#07050c")
const COL_MAGENTA := Color("#ff00ff")
const COL_GOLD := Color("#ffe600")
const COL_FLOOR_A := Color("#0e1b33")
const COL_FLOOR_B := Color("#152647")
const COL_WALL := Color("#140a22")
const COL_CYAN := Color("#3df5ff")
const COL_RED := Color("#ff2a4d")
const COL_TEXT := Color("#f2e9ff")

# --- Straturi de fizică (bitmask, vezi Project Settings > Layer Names) ------
const LAYER_PLAYER := 1        # layer 1
const LAYER_ENEMIES := 2       # layer 2
const LAYER_WALLS := 4         # layer 3
const LAYER_PROJECTILES := 8   # layer 4

# --- Etaje -------------------------------------------------------------------
const DEEPEST_FLOOR := -50
const TOP_FLOOR := 2
## Cele 5 capitole (câte 10 subsoluri): 9 etaje cu inamicii capitolului + boss-ul la final.
const ZONES: Array[Dictionary] = [
	{"name": "Ghost Crypt", "enemies": "Ghosts", "boss": "Great Crypt Spirit", "boss_hp": 10},
	{"name": "Spirit Catacombs", "enemies": "Spirits", "boss": "Eyeless Oracle", "boss_hp": 13},
	{"name": "Skeleton Ossuary", "enemies": "Skeleton Archers", "boss": "Bone Commander", "boss_hp": 16},
	{"name": "Corrupted Barracks", "enemies": "Phantom Knights", "boss": "Fallen Royal Guard", "boss_hp": 20},
	{"name": "Book Abyss", "enemies": "All Shadows", "boss": "Book's Dark Avatar", "boss_hp": 25},
]

## 1 = toate cele 50 de subsoluri pe rând (-1, -2, -3 ... -50).
## 5 = „Puțuri Abisale” pentru o sesiune scurtă (-1, -5, -10 ... -50).
var floor_step: int = 1

# --- Starea poveștii ---------------------------------------------------------
var player_name: String = "Knight"
var current_floor: int = 0
var target_floor: int = 0
var max_hp: int = 3
var player_hp: int = 3
var mirror_visit: int = 1          # 1 = prima vizită, 2 = întoarcerea cu Poțiunea
var has_potion: bool = false
var has_crown: bool = false
var seen_tips: Array[String] = []   # sfaturile unice ale fantomei deja spuse în această tură

# --- Statistici (afișate la final) ------------------------------------------
var kills: int = 0
var parries: int = 0
var perfect_parries: int = 0
var bounce_backs: int = 0
var deaths: int = 0
var run_start_msec: int = 0

# --- Intern -------------------------------------------------------------------
var _fade_layer: CanvasLayer
var _fade_rect: ColorRect
var _transitioning := false
var _hitstop_token := 0
var _sfx: Dictionary = {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_index := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()
	_build_fade_layer()
	_build_sfx()
	run_start_msec = Time.get_ticks_msec()


# =============================================================================
#  Etaje și zone
# =============================================================================
func zone_index(floor_num: int) -> int:
	if floor_num >= 0:
		return -1
	return clampi(floori((absi(floor_num) - 1) / 10.0), 0, ZONES.size() - 1)


func is_boss_floor(floor_num: int) -> bool:
	return floor_num < 0 and absi(floor_num) % 10 == 0


func boss_index(floor_num: int) -> int:
	## 1..5 pentru -10, -20, -30, -40, -50; 0 dacă nu e etaj de boss.
	return zone_index(floor_num) + 1 if is_boss_floor(floor_num) else 0


func next_floor_down(from_floor: int) -> int:
	if from_floor >= 0:
		return -1
	var depth := absi(from_floor)
	var next_depth := (floori(depth / float(floor_step)) + 1) * floor_step
	return -mini(next_depth, absi(DEEPEST_FLOOR))


func enemy_types_for_floor(floor_num: int) -> Array[int]:
	## 0 Fantomă, 1 Spirit, 2 Schelet Arcaș, 3 Cavaler Fantomă (vezi Enemy.Type).
	var z := zone_index(floor_num)
	var types: Array[int] = []
	if z >= 4:
		types.assign([0, 1, 2, 3])
	else:
		types.append(maxi(z, 0))
	return types


func chapter_number(floor_num: int) -> int:
	## 1..5 (capitolul = zona de 10 subsoluri)
	return zone_index(floor_num) + 1


func chapter_floor(floor_num: int) -> int:
	## Al câtelea etaj din capitol: 1..10 (10 = boss).
	return (absi(floor_num) - 1) % 10 + 1


func is_chapter_start(floor_num: int) -> bool:
	return floor_num < 0 and chapter_floor(floor_num) == 1


func enemy_count_for_floor(floor_num: int) -> int:
	## Crește în interiorul capitolului: etajele 1-3 / 4-6 / 7-9.
	if floor_num == -1:
		return 1  # primul etaj = tutorial
	var z := zone_index(floor_num)
	var base: int = [1, 2, 2, 2, 3][z]
	var ramp := floori((chapter_floor(floor_num) - 1) / 3.0)
	return mini(base + ramp, 5)


func floor_difficulty(floor_num: int) -> float:
	## Multiplicator de ritm pentru inamici: 1.0 la începutul capitolului, ~1.3 la etajul 9.
	if floor_num >= 0 or is_boss_floor(floor_num):
		return 1.0
	return 1.0 + 0.035 * (chapter_floor(floor_num) - 1)


func floor_short(floor_num: int) -> String:
	if floor_num > 0:
		return "FLOOR +%d" % floor_num
	if floor_num == 0:
		return "GROUND FLOOR 0"
	return "DUNGEON FLOOR %d" % floor_num


func floor_name(floor_num: int) -> String:
	match floor_num:
		2:
			return "Throne Room"
		1:
			return "Royal Gallery"
		0:
			return "Mirror Hall"
	var z := zone_index(floor_num)
	if is_boss_floor(floor_num):
		return "BOSS: %s" % ZONES[z]["boss"]
	return String(ZONES[z]["name"])


func floor_title(floor_num: int) -> String:
	return "%s  ·  %s" % [floor_short(floor_num), floor_name(floor_num)]


# =============================================================================
#  Fluxul poveștii
# =============================================================================
func travel_to(target: int) -> void:
	## Trece prin harta castelului (CastleMap) spre etajul țintă.
	target_floor = target
	change_scene(SCENE_MAP)


func arrive() -> void:
	## Apelată de CastleMap la finalul animației: intră în scena etajului.
	current_floor = target_floor
	floor_changed.emit(current_floor)
	if current_floor < 0:
		change_scene(SCENE_DUNGEON)
	elif current_floor == 0:
		change_scene(SCENE_MIRROR)
	else:
		change_scene(SCENE_THRONE)


func collect_treasure() -> void:
	has_potion = true
	has_crown = true
	mirror_visit = 2


func reset_run() -> void:
	current_floor = 0
	target_floor = 0
	player_hp = max_hp
	mirror_visit = 1
	has_potion = false
	has_crown = false
	seen_tips.clear()
	kills = 0
	parries = 0
	perfect_parries = 0
	bounce_backs = 0
	deaths = 0
	run_start_msec = Time.get_ticks_msec()
	hp_changed.emit(player_hp, max_hp)


@warning_ignore("integer_division")
func run_time_text() -> String:
	var secs := (Time.get_ticks_msec() - run_start_msec) / 1000
	return "%02d:%02d" % [secs / 60, secs % 60]


# =============================================================================
#  Viața jucătorului (sursa unică de adevăr, persistă între etaje)
# =============================================================================
func damage_player(amount: int) -> void:
	player_hp = maxi(player_hp - amount, 0)
	hp_changed.emit(player_hp, max_hp)


func heal_player(amount: int) -> void:
	player_hp = mini(player_hp + amount, max_hp)
	hp_changed.emit(player_hp, max_hp)


func restore_full_hp() -> void:
	player_hp = max_hp
	hp_changed.emit(player_hp, max_hp)


# =============================================================================
#  Juice: hitstop + screen shake
# =============================================================================
func hitstop(duration: float, time_scale: float = 0.05) -> void:
	# Token: doar ultimul hitstop pornit readuce timpul la normal (hitstop-uri suprapuse).
	_hitstop_token += 1
	var token := _hitstop_token
	Engine.time_scale = time_scale
	# ignore_time_scale = true -> timerul curge în timp real
	await get_tree().create_timer(duration, true, false, true).timeout
	if token == _hitstop_token:
		Engine.time_scale = 1.0


func shake(amount: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam and cam.has_method("shake"):
		cam.call("shake", amount)


# =============================================================================
#  Tranziții între scene (fade negru, peste el rămân scanline-urile CRT)
# =============================================================================
func change_scene(path: String, fade_time: float = 0.35) -> void:
	if _transitioning:
		return
	_transitioning = true
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var t := create_tween()
	t.tween_property(_fade_rect, "color:a", 1.0, fade_time)
	await t.finished
	_hitstop_token += 1
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	var t2 := create_tween()
	t2.tween_property(_fade_rect, "color:a", 0.0, fade_time)
	await t2.finished
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transitioning = false


func is_transitioning() -> bool:
	return _transitioning


func _build_fade_layer() -> void:
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 90
	add_child(_fade_layer)
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(COL_BG, 0.0)
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_layer.add_child(_fade_rect)


# =============================================================================
#  SFX procedurale (fără fișiere audio; merg și pe Web după primul click)
# =============================================================================
func play_sfx(sfx_name: String, pitch_variation: bool = true, volume_db: float = -8.0) -> void:
	if not _sfx.has(sfx_name) or _sfx_players.is_empty():
		return
	var p := _sfx_players[_sfx_index]
	_sfx_index = (_sfx_index + 1) % _sfx_players.size()
	p.stream = _sfx[sfx_name]
	p.pitch_scale = randf_range(0.9, 1.2) if pitch_variation else 1.0
	p.volume_db = volume_db
	p.play()


func _build_sfx() -> void:
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx_players.append(p)
	#                     f_start f_end  durată  zgomot  undă
	_sfx["swing"] = _tone(520.0, 300.0, 0.06, 0.55, "square")
	_sfx["parry"] = _tone(900.0, 1400.0, 0.09, 0.05, "square")
	_sfx["perfect"] = _tone(1300.0, 2600.0, 0.16, 0.0, "square")
	_sfx["bounce"] = _tone(700.0, 1100.0, 0.05, 0.0, "sine")
	_sfx["shoot"] = _tone(380.0, 220.0, 0.07, 0.25, "saw")
	_sfx["hit"] = _tone(260.0, 90.0, 0.10, 0.45, "square")
	_sfx["hurt"] = _tone(200.0, 60.0, 0.25, 0.6, "saw")
	_sfx["die"] = _tone(320.0, 40.0, 0.35, 0.7, "square")
	_sfx["heal"] = _tone(600.0, 1500.0, 0.3, 0.0, "sine")
	_sfx["gate"] = _tone(90.0, 40.0, 0.9, 0.8, "saw")
	_sfx["magic"] = _tone(400.0, 1800.0, 0.6, 0.1, "sine")
	_sfx["slam"] = _tone(140.0, 30.0, 0.5, 0.9, "square")
	_sfx["blip"] = _tone(880.0, 880.0, 0.025, 0.0, "square")


func _tone(f0: float, f1: float, duration: float, noise: float, wave: String) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * duration)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := float(i) / float(n)
		phase += lerpf(f0, f1, t) / float(rate)
		var s := 0.0
		match wave:
			"square":
				s = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
			"saw":
				s = fmod(phase, 1.0) * 2.0 - 1.0
			_:
				s = sin(TAU * phase)
		if noise > 0.0:
			s = lerpf(s, randf_range(-1.0, 1.0), noise)
		var env := (1.0 - t) * minf(1.0, t * 60.0)
		data.encode_s16(i * 2, int(clampf(s * env * 0.4, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav
